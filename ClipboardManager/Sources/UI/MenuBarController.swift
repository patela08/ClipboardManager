import AppKit
import os

/// Controls the macOS menu bar status item and its dropdown menu.
/// Displays visually distinct icons for enabled vs disabled monitoring states,
/// and provides toggle, settings, permissions indicator, and quit menu items.
///
/// Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 10.2, 10.4
@MainActor
final class MenuBarController {

    // MARK: - Public Callbacks

    /// Called when the user toggles monitoring on/off via the menu.
    var onToggleMonitoring: (() -> Void)?

    /// Called when the user selects the Settings menu item.
    var onOpenSettings: (() -> Void)?

    /// Called when the user selects the Quit menu item.
    var onQuit: (() -> Void)?

    /// Called when the user selects the Uninstall menu item.
    var onUninstall: (() -> Void)?

    // MARK: - Private Properties

    private var statusItem: NSStatusItem
    private let settingsManager: SettingsManaging
    private let logger = Logger(subsystem: "com.clipboardmanager", category: "MenuBarController")

    /// Whether Accessibility permissions are currently granted.
    private var accessibilityGranted: Bool = true

    // MARK: - Menu Items

    private var toggleMenuItem: NSMenuItem?
    private var permissionsMenuItem: NSMenuItem?
    private var permissionsSeparator: NSMenuItem?

    // MARK: - Initialization

    /// Creates the menu bar controller and sets up the status item.
    /// - Parameter settingsManager: The settings manager for reading monitoring state.
    init(settingsManager: SettingsManaging) {
        self.settingsManager = settingsManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupMenuBar()
    }

    // MARK: - Public API

    /// Updates the status item icon based on the current monitoring state.
    /// - Parameter isEnabled: Whether clipboard monitoring is currently enabled.
    func updateIcon(isEnabled: Bool) {
        guard let button = statusItem.button else { return }

        let symbolName = isEnabled ? "doc.on.clipboard.fill" : "doc.on.clipboard"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Clipboard Manager")
        // Template images adapt to menu bar appearance (light/dark mode)
        image?.isTemplate = true
        button.image = image
        button.toolTip = isEnabled ? "Clipboard Manager — Monitoring" : "Clipboard Manager — Disabled"

        // Update the toggle menu item text
        toggleMenuItem?.title = isEnabled ? "Disable Monitoring" : "Enable Monitoring"
    }

    /// Checks whether Accessibility permissions are granted and shows/hides the indicator.
    func checkPermissions() {
        let trusted = AXIsProcessTrusted()
        accessibilityGranted = trusted

        permissionsMenuItem?.isHidden = trusted
        permissionsSeparator?.isHidden = trusted

        if !trusted {
            logger.info("Accessibility permissions not granted — showing indicator in menu.")
        }
    }

    // MARK: - Private Setup

    private func setupMenuBar() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // 1. Toggle monitoring item
        let isEnabled = settingsManager.settings.monitoringEnabled
        let toggleTitle = isEnabled ? "Disable Monitoring" : "Enable Monitoring"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleMonitoringAction(_:)), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        self.toggleMenuItem = toggleItem

        // 2. Separator
        menu.addItem(.separator())

        // 3. Settings item
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettingsAction(_:)), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // 4. Separator
        menu.addItem(.separator())

        // 5. Permissions indicator (hidden by default, shown when Accessibility not granted)
        let permItem = NSMenuItem(title: "⚠️ Accessibility Required", action: nil, keyEquivalent: "")
        permItem.isEnabled = false
        permItem.isHidden = true
        menu.addItem(permItem)
        self.permissionsMenuItem = permItem

        // 6. Separator for permissions (hidden by default)
        let permSeparator = NSMenuItem.separator()
        permSeparator.isHidden = true
        menu.addItem(permSeparator)
        self.permissionsSeparator = permSeparator

        // 7. Separator before uninstall
        menu.addItem(.separator())

        // 8. Uninstall item
        let uninstallItem = NSMenuItem(title: "Uninstall ClipboardManager...", action: #selector(uninstallAction(_:)), keyEquivalent: "")
        uninstallItem.target = self
        menu.addItem(uninstallItem)

        // 9. Quit item
        let quitItem = NSMenuItem(title: "Quit Clipboard Manager", action: #selector(quitAction(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        // Set initial icon state
        updateIcon(isEnabled: isEnabled)

        // Check permissions on setup
        checkPermissions()
    }

    // MARK: - Actions

    @objc private func toggleMonitoringAction(_ sender: NSMenuItem) {
        onToggleMonitoring?()
    }

    @objc private func openSettingsAction(_ sender: NSMenuItem) {
        onOpenSettings?()
    }

    @objc private func quitAction(_ sender: NSMenuItem) {
        onQuit?()
    }

    @objc private func uninstallAction(_ sender: Any?) {
        onUninstall?()
    }
}
