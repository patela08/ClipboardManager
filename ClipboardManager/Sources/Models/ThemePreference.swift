import Foundation

/// The user's preferred appearance theme for the picker UI.
enum ThemePreference: String, Codable, Sendable {
    case light
    case dark
    case system
}
