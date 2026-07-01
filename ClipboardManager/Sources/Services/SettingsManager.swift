import Foundation
import os

/// Manages user-configurable application settings with validation,
/// persistence, and SwiftUI reactivity via @Published.
@MainActor
final class SettingsManager: ObservableObject, @preconcurrency SettingsManaging {

    @Published private(set) var settings: AppSettings

    private let persistenceService: PersistenceServicing
    private let logger = Logger(subsystem: "com.clipboardmanager", category: "SettingsManager")

    init(persistenceService: PersistenceServicing) {
        self.persistenceService = persistenceService

        // Load settings from persistence; reset to defaults if corrupt/missing.
        do {
            self.settings = try persistenceService.loadSettings()
        } catch {
            logger.warning("Failed to load settings, using defaults: \(error.localizedDescription)")
            self.settings = AppSettings()
        }
    }

    // MARK: - SettingsManaging

    func updateHistorySize(_ size: Int) {
        guard AppSettings.historySizeRange.contains(size) else { return }
        settings.historySize = size
        persist()
    }

    func updateContentTypes(_ types: CaptureContentTypes) {
        // Always keep plainText enabled regardless of input.
        var sanitized = types
        sanitized.plainText = true
        settings.captureContentTypes = sanitized
        persist()
    }

    func addExcludedApp(_ bundleId: String) {
        guard !settings.excludedApps.contains(bundleId) else { return }
        settings.excludedApps.append(bundleId)
        persist()
    }

    func removeExcludedApp(_ bundleId: String) {
        guard settings.excludedApps.contains(bundleId) else { return }
        settings.excludedApps.removeAll { $0 == bundleId }
        persist()
    }

    func updateTriggerGesture(_ gesture: KeyGesture) {
        settings.triggerGesture = gesture
        persist()
    }

    func updateTheme(_ theme: ThemePreference) {
        settings.theme = theme
        persist()
    }

    func updateAutoStart(_ enabled: Bool) {
        settings.autoStartAtLogin = enabled
        persist()
    }

    func updateMonitoringEnabled(_ enabled: Bool) {
        settings.monitoringEnabled = enabled
        persist()
    }

    func resetToDefaults() {
        settings = AppSettings()
        persist()
        logger.info("Settings reset to defaults")
    }

    // MARK: - Private

    private func persist() {
        do {
            try persistenceService.saveSettings(settings)
        } catch {
            // Keep in-memory state; log the failure (requirement 6.6 pattern).
            logger.error("Failed to persist settings: \(error.localizedDescription)")
        }
    }
}
