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
            TranslatorSettingsView()
        }
    }
}

// MARK: - App Delegate & Logic Controller
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var windowController: FloatingWindowController?
    var settingsWindowController: SettingsWindowController?
    var pollingTimer: Timer?
    var lastSelectedText: String?
    var selected:Bool = false
    // Global mouse-up event monitor token
    var globalMouseUpMonitor: Any?
    // Global single-click monitor token (for closing the popup when clicking outside)
    var globalClickMonitor: Any?
    // 翻译器列表：支持任意数量的 Translator 实现（在 `applicationDidFinishLaunching` 中初始化，以便从配置加载）
    private var translators: [any Translator] = []

    // Expose names and update helper for Settings UI
    func translatorNames() -> [String] {
        return translators.map { $0.name }
    }

    func updateTranslators(with mapping: [String: TranslatorConfig]) {
        for i in translators.indices {
            var t = translators[i]
            if let cfg = mapping[t.name] {
                t.config = cfg
                translators[i] = t
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. 初始化 UI
        setupMenuBar()
        windowController = FloatingWindowController()
        
        // 2. 从配置文件加载每个翻译器的 config（如果存在）并初始化 translators
        let configs = TranslatorConfigLoader.load()

        var loaded: [any Translator] = []

        // 始终包含系统词典
        let sys = SystemDictTranslator()
        loaded.append(sys)

        // 如果以后支持更多翻译器，可在此遍历 `configs` 并根据键名构造对应 Translator
        for (name, _) in configs {
            if name=="System"{
                continue
            }else if name == "DeepSeek" { 
                loaded.append(DeepSeekTranslator(config: configs[name]!))
            }else{
                print("Unknown translator in config: \(name)")
            }
            
        }

        self.translators = loaded

        // 3. 检查权限 (延迟执行以确保 UI 准备好)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkAccessibilityPermissions()
        }
        
        // 4. 开始监听（包括全局点击与基于 Accessibility 的回调）
        startMonitoring()
    }
    
    // Polling-based selection detection (fallback / original behavior)

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "character.book.closed.fill", accessibilityDescription: "Translator")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "JustTranslator 运行中", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        // 打开应用设置（Preferences / Settings）
        let settingsItem = NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
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

    @objc func openSettings() {
        // Show dedicated Settings window (create if needed)
        if let controller = settingsWindowController {
            controller.show()
            return
        }

        let controller = SettingsWindowController()
        settingsWindowController = controller
        controller.show()
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
        
        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            guard let self = self else { return }
            guard let win = self.windowController?.window else { return }

            if win.isVisible {
                let mouseLoc = NSEvent.mouseLocation
                if !win.frame.contains(mouseLoc) {
                    self.windowController?.hideWindow()
                }
            }else{
                self.handleSelection()
            }
            
        }
    }

    // 保留旧的无参入口以兼容（例如双击触发），委托给新的实现
    func handleSelection() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let selectedText = AccessibilityUtils.getSelectedText()?.trimmingCharacters(in: .whitespacesAndNewlines), !selectedText.isEmpty else {
                DispatchQueue.main.async {
                    self.windowController?.hideWindow()
                }
                return
            }
            self.handleSelection(with: selectedText)
        }
    }

    func handleSelection(with selectedText: String) {
        if selectedText.count > 2000 { return }
        print("Select text:\(selectedText)")

        DispatchQueue.main.async {
            let mouseLoc = NSEvent.mouseLocation
            self.windowController?.show(text: selectedText, systemDefinition: nil, at: mouseLoc)

            let localTranslators = self.translators
            for t in localTranslators {
                self.windowController?.markLoading(name: t.name, isLoading: true)
            }

            for translator in localTranslators {
                let localTranslator = translator
                Task {
                    do {
                        let res = try await localTranslator.translate(text: selectedText)
                        if let res = res, !res.isEmpty {
                            print("Translation(\(localTranslator.name)): \(res.prefix(200))...")
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
    
    deinit {
        if let token = globalMouseUpMonitor {
            NSEvent.removeMonitor(token)
            globalMouseUpMonitor = nil
        }
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
}

