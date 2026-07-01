import Foundation
@testable import ClipboardManager

/// Mock implementation of SettingsManaging for testing.
final class MockSettingsManager: SettingsManaging {
    var settings: AppSettings = AppSettings()

    // MARK: - Call tracking

    var updateHistorySizeCallCount = 0
    var updateContentTypesCallCount = 0
    var addExcludedAppCallCount = 0
    var removeExcludedAppCallCount = 0
    var updateTriggerGestureCallCount = 0
    var updateThemeCallCount = 0
    var updateAutoStartCallCount = 0
    var updateMonitoringEnabledCallCount = 0

    // MARK: - Captured arguments

    var lastHistorySize: Int?
    var lastContentTypes: CaptureContentTypes?
    var lastAddedExcludedApp: String?
    var lastRemovedExcludedApp: String?
    var lastTriggerGesture: KeyGesture?
    var lastTheme: ThemePreference?
    var lastAutoStart: Bool?
    var lastMonitoringEnabled: Bool?

    func updateHistorySize(_ size: Int) {
        updateHistorySizeCallCount += 1
        lastHistorySize = size
        if AppSettings.historySizeRange.contains(size) {
            settings.historySize = size
        }
    }

    func updateContentTypes(_ types: CaptureContentTypes) {
        updateContentTypesCallCount += 1
        lastContentTypes = types
        settings.captureContentTypes = types
    }

    func addExcludedApp(_ bundleId: String) {
        addExcludedAppCallCount += 1
        lastAddedExcludedApp = bundleId
        if !settings.excludedApps.contains(bundleId) {
            settings.excludedApps.append(bundleId)
        }
    }

    func removeExcludedApp(_ bundleId: String) {
        removeExcludedAppCallCount += 1
        lastRemovedExcludedApp = bundleId
        settings.excludedApps.removeAll { $0 == bundleId }
    }

    func updateTriggerGesture(_ gesture: KeyGesture) {
        updateTriggerGestureCallCount += 1
        lastTriggerGesture = gesture
        settings.triggerGesture = gesture
    }

    func updateTheme(_ theme: ThemePreference) {
        updateThemeCallCount += 1
        lastTheme = theme
        settings.theme = theme
    }

    func updateAutoStart(_ enabled: Bool) {
        updateAutoStartCallCount += 1
        lastAutoStart = enabled
        settings.autoStartAtLogin = enabled
    }

    func updateMonitoringEnabled(_ enabled: Bool) {
        updateMonitoringEnabledCallCount += 1
        lastMonitoringEnabled = enabled
        settings.monitoringEnabled = enabled
    }

    func resetToDefaults() {
        settings = AppSettings()
    }
}
