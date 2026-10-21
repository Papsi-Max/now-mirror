import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let model = AppModel()
    lazy var relay = Relay(model: model)
    lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ n: Notification) {
        UserDefaults.standard.register(defaults: ["showIcon": true])
        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Now Mirror")
        let menu = NSMenu()
        menu.delegate = self
        statusLine.isEnabled = false
        statusLine.isHidden = true
        menu.addItem(statusLine)
        let settings = menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Now Mirror", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        applyIconPreference()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.applyIconPreference()
        }
        relay.start()
        // First launch: open the settings so the user knows where the app lives.
        if !UserDefaults.standard.bool(forKey: "didFirstLaunch") {
            UserDefaults.standard.set(true, forKey: "didFirstLaunch")
            showSettings()
        }
    }

    func applicationWillTerminate(_ n: Notification) { relay.stop() }

    /// Reopening the app (Finder, Spotlight) shows the settings, which matters when the icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    /// `isVisible` writes to UserDefaults itself: without this guard, the change notification
    /// calls this method again in an endless loop (stack overflow).
    func applyIconPreference() {
        let want = UserDefaults.standard.bool(forKey: "showIcon")
        if statusItem.isVisible != want { statusItem.isVisible = want }
    }

    /// A status line only shows in the menu when something is wrong.
    func menuNeedsUpdate(_ menu: NSMenu) {
        statusLine.title = model.error ?? ""
        statusLine.isHidden = model.error == nil
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
                             styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            w.title = "Now Mirror"
            w.contentView = NSHostingView(rootView: SettingsView(model: model))
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
