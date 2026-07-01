import Foundation

/// The top-level structure for the persisted clipboard history JSON file.
/// Includes a version number for future migration support.
struct HistoryFile: Codable, Sendable {
    let version: Int
    let entries: [ClipboardEntry]

    /// Current file format version.
    static let currentVersion = 1

    init(entries: [ClipboardEntry], version: Int = HistoryFile.currentVersion) {
        self.version = version
        self.entries = entries
    }
}
