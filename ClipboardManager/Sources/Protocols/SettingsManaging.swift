import Foundation

/// Protocol for managing user-configurable application settings.
/// Handles validation, persistence, and live application of setting changes.
protocol SettingsManaging: AnyObject {
    /// The current application settings.
    var settings: AppSettings { get }

    /// Update the maximum history size. Value must be in range [1, 150].
    func updateHistorySize(_ size: Int)

    /// Update which content types to capture.
    func updateContentTypes(_ types: CaptureContentTypes)

    /// Add an app bundle identifier to the exclusion list.
    func addExcludedApp(_ bundleId: String)

    /// Remove an app bundle identifier from the exclusion list.
    func removeExcludedApp(_ bundleId: String)

    /// Update the trigger gesture configuration.
    func updateTriggerGesture(_ gesture: KeyGesture)

    /// Update the UI theme preference.
    func updateTheme(_ theme: ThemePreference)

    /// Update whether the app auto-starts at login.
    func updateAutoStart(_ enabled: Bool)

    /// Update whether clipboard monitoring is enabled.
    func updateMonitoringEnabled(_ enabled: Bool)

    /// Reset all settings to their default values.
    func resetToDefaults()
}
