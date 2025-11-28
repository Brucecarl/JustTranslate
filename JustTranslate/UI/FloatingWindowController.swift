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
        // Use .hudWindow style, but may need custom background on some systems
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 400),
            styleMask: [.nonactivatingPanel, .borderless, .hudWindow],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isFloatingPanel = true
        // Set to clear to let SwiftUI's VisualEffectView handle the background
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.contentView = NSHostingView(rootView: contentView)
        window.orderOut(nil)
    }

    func show(text: String, systemDefinition: String?, at point: NSPoint) {
        viewModel.reset()
        viewModel.originalText = text
        // If there is an initial system dictionary definition, add it as an item
        if let sys = systemDefinition, !sys.isEmpty {
            let item = TranslationItem(name: "System Dictionary", content: sys, isLoading: false)
            viewModel.setItem(item)
        }

        // Simple anti-flicker processing
        window.alphaValue = 0

        // Reposition and make sure the window does not go off the screen
        let windowSize = window.frame.size
        // Offset up a little to avoid blocking the cursor
        var desiredX = point.x + 20
        var desiredY = point.y - windowSize.height - 10

        // Find the screen where the mouse is (fallback to the main screen)
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let minX = visible.minX
            let maxX = visible.maxX - windowSize.width
            let minY = visible.minY
            let maxY = visible.maxY - windowSize.height

            // If the window is wider/higher than the visible area, it will be centered in the visible area
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

        // Show window
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
