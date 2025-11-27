//
//  JustTranslateApp.swift
//  JustTranslate
//
//  Created by charlie on 2025/11/27.
//
import SwiftUI
import AppKit
import ApplicationServices
import Carbon
import Combine
import Foundation
import CoreServices

// MARK: - Entry Point
@main
struct JustTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate & Logic Controller
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var windowController: FloatingWindowController?
    var monitor: Any?
    // 翻译器列表：支持任意数量的 Translator 实现
    private let translators: [any Translator] = [
        SystemDictTranslator(),
        DeepSeekTranslator()
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. 初始化 UI
        setupMenuBar()
        windowController = FloatingWindowController()
        
        // 2. 检查权限 (延迟执行以确保 UI 准备好)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkAccessibilityPermissions()
        }

        // 3. 开始监听
        startMonitoring()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "character.book.closed.fill", accessibilityDescription: "Translator")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "JustTranslator 运行中", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "打开辅助功能设置...", action: #selector(openSystemSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    
    @objc func openSystemSettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            let alert = NSAlert()
            alert.messageText = "缺少辅助功能权限"
            alert.informativeText = "本应用需要【辅助功能】权限才能读取您选中的文本进行翻译。\n\n1. 点击“打开设置”\n2. 在列表中勾选此应用\n3. 重启应用"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "打开设置")
            alert.addButton(withTitle: "忽略")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                openSystemSettings()
            }
        }
    }

    func startMonitoring() {
        // 监听全局鼠标抬起事件
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            guard let self = self else { return }
            
            // 关键修复：检查点击位置是否在当前悬浮窗范围内
            // 如果窗口正在显示，且鼠标在窗口矩形内，视为对弹窗的操作（如复制文本），不应该隐藏窗口
            if let window = self.windowController?.window, window.isVisible {
                let mouseLocation = NSEvent.mouseLocation
                if window.frame.contains(mouseLocation) {
                    return // 直接返回，忽略此次“外部”点击处理
                }
            }
            
            // 单击外部 (clickCount == 1) 且不在窗口内时，隐藏窗口
            if event.clickCount == 1 {
                DispatchQueue.main.async {
                    self.windowController?.hideWindow()
                }
            }
            
            // 双击 (clickCount == 2) 时触发翻译
            if event.clickCount == 2 {
                self.handleSelection()
            }
        }
    }

    func handleSelection() {
        // 在后台线程获取文本，避免阻塞 UI
        DispatchQueue.global(qos: .userInitiated).async {
            // 获取文本
            guard let selectedText = AccessibilityUtils.getSelectedText(),
                  !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                // 如果没有选中文本，或者点击了空白处，隐藏窗口
                DispatchQueue.main.async {
                    self.windowController?.hideWindow()
                }
                return
            }
            
            // 过滤掉过长的文本 (防止误触或API崩溃)
            if selectedText.count > 2000 { return }
            print("selected:\(selectedText)")

            DispatchQueue.main.async {
                // 显示窗口（先不传系统词典结果，后续通过 translator 回填）
                let mouseLoc = NSEvent.mouseLocation
                self.windowController?.show(text: selectedText, systemDefinition: nil, at: mouseLoc)

                // 并行触发所有翻译器请求：先将所有译者标记为 loading，再为每个译者创建独立 Task
                let localTranslators = self.translators
                // 在主线程一次性标记全部为 loading，避免 UI 抖动
                for t in localTranslators {
                    self.windowController?.markLoading(name: t.name, isLoading: true)
                }

                // 为每个翻译器并发创建任务，完成后立即回填 UI（不需要等待其他译者）
                for translator in localTranslators {
                    let localTranslator = translator
                    Task {
                        do {
                            let res = try await localTranslator.translate(text: selectedText)
                            if let res = res, !res.isEmpty {
                                await MainActor.run {
                                    self.windowController?.setTranslation(name: localTranslator.name, content: res, isLoading: false)
                                }
                            } else {
                                await MainActor.run {
                                    self.windowController?.markLoading(name: localTranslator.name, isLoading: false)
                                }
                            }
                        } catch {
                            await MainActor.run {
                                let err = "错误：\(error.localizedDescription)"
                                self.windowController?.setTranslation(name: localTranslator.name, content: err, isLoading: false)
                            }
                        }
                    }
                }
            }
        }
    }
    
    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

