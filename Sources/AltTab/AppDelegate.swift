import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var permissionMenuItem: NSMenuItem!
    private let switcher = Switcher()
    private var keyboardHook: KeyboardHook?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        requestPermissions()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "rectangle.on.rectangle",
            accessibilityDescription: "AltTab"
        )

        let menu = NSMenu()
        menu.delegate = self
        let title = NSMenuItem(title: "AltTab — hold ⌥, press Tab", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        permissionMenuItem = NSMenuItem(title: "Accessibility: checking…", action: nil, keyEquivalent: "")
        permissionMenuItem.isEnabled = false
        menu.addItem(permissionMenuItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit AltTab", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        let trusted = AXIsProcessTrusted()
        let hooked = keyboardHook != nil
        permissionMenuItem.title = trusted
            ? (hooked ? "Accessibility: ✓ active" : "Accessibility: ✓ (hook failed — relaunch)")
            : "Accessibility: ✗ grant in System Settings"
    }

    private func requestPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            installHook()
        } else {
            // Poll until the user grants Accessibility access, then start.
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard AXIsProcessTrusted() else { return }
                timer.invalidate()
                self?.permissionTimer = nil
                self?.installHook()
            }
        }
    }

    private func installHook() {
        let hook = KeyboardHook(switcher: switcher)
        if hook.start() {
            keyboardHook = hook
            NSLog("AltTab: event tap installed, \u{2325}\u{21E5} is live")
        } else {
            NSLog("AltTab: event tap creation FAILED despite AXIsProcessTrusted")
            let alert = NSAlert()
            alert.messageText = "AltTab could not capture keyboard events"
            alert.informativeText = "Make sure AltTab is allowed under System Settings → Privacy & Security → Accessibility, then relaunch."
            alert.runModal()
        }
    }
}
