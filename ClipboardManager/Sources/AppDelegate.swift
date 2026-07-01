import AppKit
import SwiftUI
import os

/// The application delegate responsible for initializing all services with dependency injection
/// and wiring together the clipboard monitoring, gesture detection, picker UI, menu bar, and settings.
///
/// Requirements: 1.1, 1.3, 2.4, 6.3, 8.3, 8.4, 8.6, 8.7
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Services

    private var persistenceService: PersistenceService!
    private var settingsManager: SettingsManager!
    private var historyManager: HistoryManager!
    private var sensitivityDetector: SensitivityDetector!
    private var clipboardMonitor: ClipboardMonitor!
    private var permissionsManager: PermissionsManager!
    private var gestureDetector: GestureDetector!
    private var pickerPanel: PickerPanel!
    private var menuBarController: MenuBarController!
    private var uninstallService: UninstallService!

    // MARK: - Windows

    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?

    private let logger = Logger(subsystem: "com.clipboardmanager", category: "AppDelegate")

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        initializeServices()
        wireCallbacks()
        configureOnLaunch()
    }

    // MARK: - Service Initialization

    private func initializeServices() {
        // 1. PersistenceService
        persistenceService = PersistenceService()

        // 2. SettingsManager (depends on PersistenceService)
        settingsManager = SettingsManager(persistenceService: persistenceService)

        // 3. HistoryManager (depends on PersistenceService)
        historyManager = HistoryManager(persistenceService: persistenceService)

        // 4. SensitivityDetector
        sensitivityDetector = SensitivityDetector()

        // 5. ClipboardMonitor (depends on HistoryManager, SensitivityDetector, SettingsManager)
        clipboardMonitor = ClipboardMonitor(
            historyManager: historyManager,
            sensitivityDetector: sensitivityDetector,
            settingsManager: settingsManager
        )

        // 6. PermissionsManager
        permissionsManager = PermissionsManager()

        // 7. GestureDetector (onTrigger opens the PickerPanel)
        gestureDetector = GestureDetector(settingsManager: settingsManager, onTrigger: { [weak self] position in
            self?.showPicker(near: position)
        })

        // 8. PickerPanel
        pickerPanel = PickerPanel()

        // 9. MenuBarController (depends on SettingsManager)
        menuBarController = MenuBarController(settingsManager: settingsManager)

        // 10. UninstallService (depends on ClipboardMonitor, GestureDetector, PersistenceService)
        uninstallService = UninstallService(
            clipboardMonitor: clipboardMonitor,
            gestureDetector: gestureDetector,
            fileManager: .default,
            processLauncher: DefaultProcessLauncher(),
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "com.clipboardmanager",
            appBundleURL: Bundle.main.bundleURL,
            dataDirectoryURL: persistenceService.directoryURL
        )
    }

    // MARK: - Callback Wiring

    private func wireCallbacks() {
        // MenuBarController: toggle monitoring
        menuBarController.onToggleMonitoring = { [weak self] in
            self?.toggleMonitoring()
        }

        // MenuBarController: open settings
        menuBarController.onOpenSettings = { [weak self] in
            self?.openSettings()
        }

        // MenuBarController: quit
        menuBarController.onQuit = {
            NSApp.terminate(nil)
        }

        // MenuBarController: uninstall
        menuBarController.onUninstall = { [weak self] in
            self?.uninstallService.requestUninstall()
        }
    }

    // MARK: - Launch Configuration

    private func configureOnLaunch() {
        // Set HistoryManager.maxEntries from settings
        historyManager.maxEntries = settingsManager.settings.historySize

        // Start monitoring and gesture detection if enabled (Req 8.6)
        if settingsManager.settings.monitoringEnabled {
            clipboardMonitor.startMonitoring()
            gestureDetector.startListening()
        }

        // Update menu bar icon based on monitoring state
        menuBarController.updateIcon(isEnabled: settingsManager.settings.monitoringEnabled)

        // Check if onboarding should show (Req 10.1)
        if permissionsManager.shouldShowOnboarding {
            showOnboarding()
        }

        logger.info("App launched — monitoring: \(self.settingsManager.settings.monitoringEnabled)")
    }

    // MARK: - Monitoring Toggle (Req 8.3, 8.4, 8.7)

    private func toggleMonitoring() {
        let currentlyEnabled = settingsManager.settings.monitoringEnabled
        let newState = !currentlyEnabled

        // Update persisted setting (Req 8.7)
        settingsManager.updateMonitoringEnabled(newState)

        // Start or stop ClipboardMonitor and GestureDetector together (Req 1.3, 2.4)
        if newState {
            clipboardMonitor.startMonitoring()
            gestureDetector.startListening()
        } else {
            clipboardMonitor.stopMonitoring()
            gestureDetector.stopListening()
        }

        // Update menu bar icon (Req 8.5)
        menuBarController.updateIcon(isEnabled: newState)

        logger.info("Monitoring toggled: \(newState ? "enabled" : "disabled")")
    }

    // MARK: - Picker

    private func showPicker(near position: CGPoint) {
        // Create PickerViewModel with historyManager and dismiss callback
        let viewModel = PickerViewModel(
            historyManager: historyManager,
            onDismiss: { [weak self] in
                self?.pickerPanel.dismiss()
            }
        )

        // Set PickerView as content of panel
        let pickerView = PickerView(viewModel: viewModel)
        pickerPanel.setContentView(pickerView)

        // Show panel near the trigger position
        pickerPanel.show(near: position)
    }

    // MARK: - Settings Window

    private func openSettings() {
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(settingsManager: settingsManager, onUninstall: { [weak self] in
            self?.uninstallService.requestUninstall()
        })
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Clipboard Manager Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 500, height: 550))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    // MARK: - Onboarding Window

    private func showOnboarding() {
        let onboardingView = OnboardingView(
            permissionsManager: permissionsManager,
            onDismiss: { [weak self] in
                self?.dismissOnboarding()
            }
        )

        let hostingController = NSHostingController(rootView: onboardingView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to Clipboard Manager"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 420, height: 450))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        onboardingWindow = window
    }

    private func dismissOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil

        // After onboarding, check permissions and update menu bar
        menuBarController.checkPermissions()
    }
}
