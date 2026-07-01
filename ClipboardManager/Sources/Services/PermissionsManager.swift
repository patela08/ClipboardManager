import AppKit
import os

/// Manages Accessibility permission state and polling.
/// Handles onboarding flow state and detects when the user grants permission at runtime.
///
/// Requirements: 10.1, 10.2, 10.3, 10.4
@MainActor
final class PermissionsManager: ObservableObject {

    // MARK: - Published Properties

    /// Whether Accessibility permission is currently granted.
    @Published private(set) var isAccessibilityGranted: Bool

    /// Whether the onboarding flow has been completed (dismissed or permission granted).
    /// Persisted via UserDefaults so onboarding is not repeated on relaunch.
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: Self.onboardingKey)
        }
    }

    // MARK: - Private Properties

    private static let onboardingKey = "hasCompletedOnboarding"
    private var pollingTimer: Timer?
    private let logger = Logger(subsystem: "com.clipboardmanager", category: "PermissionsManager")

    // MARK: - Initialization

    init() {
        let granted = AXIsProcessTrusted()
        self.isAccessibilityGranted = granted
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingKey)

        logger.info("PermissionsManager init — accessibility: \(granted), onboarding completed: \(self.hasCompletedOnboarding)")
    }

    // MARK: - Public API

    /// Whether onboarding should be shown on this launch.
    /// True only when permission is not granted AND onboarding has not been previously completed.
    var shouldShowOnboarding: Bool {
        !isAccessibilityGranted && !hasCompletedOnboarding
    }

    /// Starts polling `AXIsProcessTrusted()` every 1 second to detect permission grant.
    /// Requirement 10.3: detect within 5 seconds — polling at 1s satisfies this.
    func startPolling() {
        guard pollingTimer == nil else { return }
        logger.info("Starting accessibility permission polling.")

        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermission()
            }
        }
    }

    /// Stops the polling timer.
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        logger.info("Stopped accessibility permission polling.")
    }

    /// Opens the macOS System Settings > Accessibility pane.
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        logger.info("Opened System Settings > Accessibility pane.")
    }

    /// Marks onboarding as completed (user dismissed without granting permission).
    func dismissOnboarding() {
        hasCompletedOnboarding = true
        stopPolling()
        logger.info("Onboarding dismissed without permission grant.")
    }

    /// Rechecks the current permission state. Useful for external callers.
    func recheckPermission() {
        checkPermission()
    }

    // MARK: - Private

    private func checkPermission() {
        let granted = AXIsProcessTrusted()

        if granted && !isAccessibilityGranted {
            // Permission transitioned from false → true
            logger.info("Accessibility permission granted.")
            isAccessibilityGranted = true
            hasCompletedOnboarding = true
            stopPolling()
        } else if !granted && isAccessibilityGranted {
            // Permission was revoked
            logger.info("Accessibility permission revoked.")
            isAccessibilityGranted = false
        }
    }
}
