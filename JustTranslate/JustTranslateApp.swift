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
    // Translator list: Supports any number of Translator implementations (initialized in `applicationDidFinishLaunching` to load from configuration)
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
        // 1. Initialize UI
        setupMenuBar()
        windowController = FloatingWindowController()
        
        // 2. Load the config for each translator from the configuration file (if it exists) and initialize the translators
        let configs = TranslatorConfigLoader.load()

        var loaded: [any Translator] = []

        // Always include the system dictionary
        let sys = SystemDictTranslator()
        loaded.append(sys)

        // If more translators are supported in the future, you can iterate through `configs` here and construct the corresponding Translator based on the key name
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

        // 3. Check permissions (delay execution to ensure UI is ready)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkAccessibilityPermissions()
        }
        
        // 4. Start monitoring (including global clicks and Accessibility-based callbacks)
        startMonitoring()
    }
    
    // Polling-based selection detection (fallback / original behavior)

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "character.book.closed.fill", accessibilityDescription: "Translator")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "JustTranslator is running", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        // Open application settings (Preferences / Settings)
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open Accessibility Settings...", action: #selector(openSystemSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Exit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
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
            alert.messageText = "Missing Accessibility Permissions"
            alert.informativeText = "This application requires [Accessibility] permission to read the text you have selected for translation.\n\n1. Click 'Open Settings'\n2. Check this application in the list\n3. Restart the application"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Ignore")
            
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

    // Keep the old parameterless entry for compatibility (e.g., triggered by double-click), delegate to the new implementation
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
                            let err = "Error: \(error.localizedDescription)"
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

