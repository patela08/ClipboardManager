import Foundation

/// Protocol for file-based persistence of history and settings.
/// Abstracts JSON file I/O for testability.
protocol PersistenceServicing: AnyObject {
    /// Load clipboard history from disk. Returns empty array if file is missing or corrupt.
    func loadHistory() throws -> [ClipboardEntry]

    /// Persist clipboard history to disk atomically.
    func saveHistory(_ entries: [ClipboardEntry]) throws

    /// Load app settings from disk. Returns defaults if file is missing or corrupt.
    func loadSettings() throws -> AppSettings

    /// Persist app settings to disk.
    func saveSettings(_ settings: AppSettings) throws
}
