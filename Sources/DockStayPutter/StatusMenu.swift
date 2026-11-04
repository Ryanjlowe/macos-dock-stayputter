import AppKit

/// The menu bar item and its menu. Holds no fence logic; it reports user
/// actions through closures.
final class StatusMenu: NSObject, NSMenuDelegate {
    static let enabledKey = "fenceEnabled"

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let enabledItem = NSMenuItem(title: "Enabled", action: nil, keyEquivalent: "")
    private let homeItem = NSMenuItem(title: "Keep Dock On", action: nil, keyEquivalent: "")
    private let homeMenu = NSMenu()
    private let loginItem = NSMenuItem(title: "Launch at Login", action: nil, keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(title: "Open Accessibility Settings…", action: nil, keyEquivalent: "")

    private let onEnabledChange: (Bool) -> Void
    private let onHomeDisplayChange: (String?) -> Void
    private let onMenuOpen: () -> Void

    /// Persisted toggle state. Defaults to true on first launch.
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    init(
        onEnabledChange: @escaping (Bool) -> Void,
        onHomeDisplayChange: @escaping (String?) -> Void,
        onMenuOpen: @escaping () -> Void
    ) {
        self.onEnabledChange = onEnabledChange
        self.onHomeDisplayChange = onHomeDisplayChange
        self.onMenuOpen = onMenuOpen
        super.init()
        buildMenu()
        configureButton()
    }

    /// Updates the icon and menu to reflect whether the event tap is running.
    func setTapRunning(_ running: Bool) {
        statusItem.button?.appearsDisabled = !running
        statusItem.button?.toolTip = running
            ? "Dock Stay Putter"
            : "Dock Stay Putter needs Accessibility access. Open the menu to grant it."
        accessibilityItem.isHidden = running
        menu.update()
    }

    /// Rebuilds the "Keep Dock On" submenu from the connected displays.
    ///
    /// - Parameters:
    ///   - displays: Connected displays in the order they should be listed.
    ///   - selectedUUID: The persisted choice, or nil for "main display (automatic)".
    ///   - fallbackActive: True when `selectedUUID` isn't connected and main is being used.
    func setDisplays(_ displays: [DisplayInfo], selectedUUID: String?, fallbackActive: Bool) {
        homeMenu.removeAllItems()

        let automatic = NSMenuItem(title: "Main Display (Automatic)", action: #selector(selectHomeDisplay(_:)), keyEquivalent: "")
        automatic.target = self
        automatic.representedObject = nil
        automatic.state = selectedUUID == nil ? .on : .off
        homeMenu.addItem(automatic)

        if !displays.isEmpty {
            homeMenu.addItem(.separator())
        }
        for display in displays {
            let title = display.isMain ? "\(display.name) (Main)" : display.name
            let item = NSMenuItem(title: title, action: #selector(selectHomeDisplay(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = display.uuid
            item.state = display.uuid == selectedUUID ? .on : .off
            homeMenu.addItem(item)
        }

        if fallbackActive {
            homeMenu.addItem(.separator())
            let note = NSMenuItem(title: "Chosen display not connected, using main display", action: nil, keyEquivalent: "")
            note.isEnabled = false
            homeMenu.addItem(note)
        }
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        if let image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "Dock Stay Putter") {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "⌧"
        }
        statusItem.menu = menu
    }

    private func buildMenu() {
        menu.delegate = self
        menu.autoenablesItems = false
        homeMenu.autoenablesItems = false

        enabledItem.target = self
        enabledItem.action = #selector(toggleEnabled)
        enabledItem.state = isEnabled ? .on : .off
        menu.addItem(enabledItem)

        homeItem.submenu = homeMenu
        menu.addItem(homeItem)

        loginItem.target = self
        loginItem.action = #selector(toggleLaunchAtLogin)
        menu.addItem(loginItem)

        menu.addItem(.separator())

        accessibilityItem.target = self
        accessibilityItem.action = #selector(openAccessibilitySettings)
        menu.addItem(accessibilityItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Dock Stay Putter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    func menuWillOpen(_ menu: NSMenu) {
        loginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        enabledItem.state = isEnabled ? .on : .off
        onMenuOpen()
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        enabledItem.state = isEnabled ? .on : .off
        onEnabledChange(isEnabled)
    }

    @objc private func selectHomeDisplay(_ sender: NSMenuItem) {
        onHomeDisplayChange(sender.representedObject as? String)
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
        loginItem.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    @objc private func openAccessibilitySettings() {
        let urlString = "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
