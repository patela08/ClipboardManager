import Foundation

/// User-configurable application settings.
/// All settings are persisted to disk and restored on launch.
struct AppSettings: Codable, Equatable, Sendable {
    /// Maximum number of entries to keep in history (1...150).
    var historySize: Int = 100
    /// Which content types to capture from the clipboard.
    var captureContentTypes: CaptureContentTypes = CaptureContentTypes()
    /// Bundle identifiers of apps whose clipboard content should be ignored.
    var excludedApps: [String] = []
    /// The keyboard shortcut that triggers the picker (default: ⌘V+V gesture).
    var triggerGesture: KeyGesture = .default
    /// The user's preferred UI theme.
    var theme: ThemePreference = .system
    /// Whether the app should launch at login.
    var autoStartAtLogin: Bool = false
    /// Whether clipboard monitoring is currently enabled.
    var monitoringEnabled: Bool = true

    /// The valid range for history size configuration.
    static let historySizeRange = 1...150
}
