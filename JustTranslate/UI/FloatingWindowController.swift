import Foundation
import AppKit
import SwiftUI

// MARK: - Floating Window Controller (UI Logic)
class FloatingWindowController: NSObject {
    var window: NSPanel!
    var viewModel = TranslationViewModel()

    override init() {
        super.init()
        setupWindow()
    }

    func setupWindow() {
        let contentView = TranslationPopupView(viewModel: viewModel)
        // 使用 .hudWindow 风格，但在某些系统上可能需要自定义背景
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 400),
            styleMask: [.nonactivatingPanel, .borderless, .hudWindow],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isFloatingPanel = true
        // 设置为 clear 让 SwiftUI 的 VisualEffectView 处理背景
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.contentView = NSHostingView(rootView: contentView)
        window.orderOut(nil)
    }

    func show(text: String, systemDefinition: String?, at point: NSPoint) {
        viewModel.reset()
        viewModel.originalText = text
        // 如果有初始系统词典定义，添加为一个 item
        if let sys = systemDefinition, !sys.isEmpty {
            let item = TranslationItem(name: "系统词典", content: sys, isLoading: false)
            viewModel.setItem(item)
        }

        // 简单的防闪烁处理
        window.alphaValue = 0

        // 重新定位并确保窗口不会跑到屏幕外
        let windowSize = window.frame.size
        // 向上偏移一点，避免遮挡光标
        var desiredX = point.x + 20
        var desiredY = point.y - windowSize.height - 10

        // 找到鼠标所在的屏幕（fallback 到主屏幕）
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let minX = visible.minX
            let maxX = visible.maxX - windowSize.width
            let minY = visible.minY
            let maxY = visible.maxY - windowSize.height

            // 如果窗口比可见区域宽/高，居中显示在可见区域
            if windowSize.width >= visible.width {
                desiredX = visible.minX + (visible.width - windowSize.width) / 2
            } else {
                desiredX = min(max(desiredX, minX), maxX)
            }

            if windowSize.height >= visible.height {
                desiredY = visible.minY + (visible.height - windowSize.height) / 2
            } else {
                desiredY = min(max(desiredY, minY), maxY)
            }
        }

        window.setFrameOrigin(NSPoint(x: desiredX, y: desiredY))

        // 显示窗口
        window.makeKeyAndOrderFront(nil)
        window.animator().alphaValue = 1.0
    }

    func setTranslation(name: String, content: String, isLoading: Bool = false) {
        let item = TranslationItem(name: name, content: content, isLoading: isLoading)
        DispatchQueue.main.async {
            self.viewModel.setItem(item)
        }
    }

    func markLoading(name: String, isLoading: Bool) {
        DispatchQueue.main.async {
            if let idx = self.viewModel.items.firstIndex(where: { $0.name == name }) {
                var existing = self.viewModel.items[idx]
                existing.isLoading = isLoading
                self.viewModel.setItem(existing)
            } else {
                let item = TranslationItem(name: name, content: "", isLoading: isLoading)
                self.viewModel.setItem(item)
            }
        }
    }

    func hideWindow() {
        window.orderOut(nil)
    }
}
