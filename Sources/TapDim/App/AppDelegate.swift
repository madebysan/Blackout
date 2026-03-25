import AppKit
import SwiftUI
import KeyboardShortcuts
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var enableMenuItem: NSMenuItem!
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private let toggleManager = ToggleManager.shared
    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupKeyboardShortcut()
        observeState()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sun.min.fill", accessibilityDescription: "TapDim")
        }

        let menu = NSMenu()

        statusMenuItem = NSMenuItem(title: "TapDim: Active", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        enableMenuItem = NSMenuItem(title: "Disable", action: #selector(toggleEnabled), keyEquivalent: "")
        enableMenuItem.target = self
        menu.addItem(enableMenuItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: "About TapDim", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func setupKeyboardShortcut() {
        KeyboardShortcuts.onKeyUp(for: .toggleDim) { [weak self] in
            self?.toggleManager.toggle()
        }
    }

    private func observeState() {
        toggleManager.$isDimmed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isDimmed in
                self?.updateMenuIcon(isDimmed: isDimmed)
            }
            .store(in: &cancellables)

        settings.$isEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.updateEnabledState(isEnabled: isEnabled)
            }
            .store(in: &cancellables)
    }

    private func updateMenuIcon(isDimmed: Bool) {
        let symbolName = isDimmed ? "sun.min" : "sun.min.fill"
        statusItem.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "TapDim")
    }

    private func updateEnabledState(isEnabled: Bool) {
        statusMenuItem.title = isEnabled ? "TapDim: Active" : "TapDim: Disabled"
        enableMenuItem.title = isEnabled ? "Disable" : "Enable"
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
    }

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "TapDim Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc private func openAbout() {
        if let window = aboutWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About TapDim"
        window.contentView = NSHostingView(rootView: AboutView())
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow = window
    }
}
