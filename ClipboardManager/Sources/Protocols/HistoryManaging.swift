import Foundation

/// Protocol for clipboard history management.
/// Handles CRUD operations, deduplication, ordering, and capacity enforcement.
protocol HistoryManaging: AnyObject {
    /// The current ordered list of clipboard entries (most recent first).
    var entries: [ClipboardEntry] { get }

    /// The maximum number of entries to retain (1–150).
    var maxEntries: Int { get set }

    /// Add new clipboard content to history.
    /// Returns the created entry, or updates an existing duplicate.
    @discardableResult
    func addEntry(_ content: ClipboardContent, isSensitive: Bool) -> ClipboardEntry

    /// Delete a specific entry by ID. Returns true if found and deleted.
    @discardableResult
    func deleteEntry(id: UUID) -> Bool

    /// Remove all entries from history.
    func clearAll()

    /// Return entries whose plain text preview contains the query (case-insensitive).
    func filteredEntries(matching query: String) -> [ClipboardEntry]

    /// Mark or unmark an entry as sensitive.
    func markSensitive(id: UUID, sensitive: Bool)

    /// Move an entry to the top of history (index 0) with updated timestamp.
    func moveToTop(id: UUID)
}
