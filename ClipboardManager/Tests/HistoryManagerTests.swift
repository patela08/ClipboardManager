import Testing
import Foundation
@testable import ClipboardManager

@Suite("HistoryManager")
@MainActor
struct HistoryManagerTests {

    // MARK: - Initialization

    @Test("Loads entries from persistence on init")
    func loadsEntriesFromPersistence() {
        let persistence = MockPersistenceService()
        let entry = ClipboardEntry(
            capturedAt: Date(),
            content: .plainText("Hello"),
            isSensitive: false
        )
        persistence.storedEntries = [entry]

        let manager = HistoryManager(persistenceService: persistence)

        #expect(manager.entries.count == 1)
        #expect(manager.entries[0].id == entry.id)
    }

    @Test("Starts with empty array when persistence throws")
    func startsEmptyOnLoadFailure() {
        let persistence = MockPersistenceService()
        persistence.loadHistoryError = NSError(domain: "test", code: 1)

        let manager = HistoryManager(persistenceService: persistence)

        #expect(manager.entries.isEmpty)
    }

    @Test("Sorts loaded entries by descending capturedAt")
    func sortsLoadedEntries() {
        let persistence = MockPersistenceService()
        let older = ClipboardEntry(
            capturedAt: Date(timeIntervalSinceNow: -100),
            content: .plainText("Old")
        )
        let newer = ClipboardEntry(
            capturedAt: Date(timeIntervalSinceNow: -10),
            content: .plainText("New")
        )
        // Store in wrong order
        persistence.storedEntries = [older, newer]

        let manager = HistoryManager(persistenceService: persistence)

        #expect(manager.entries[0].id == newer.id)
        #expect(manager.entries[1].id == older.id)
    }

    // MARK: - addEntry

    @Test("addEntry inserts at index 0")
    func addEntryInsertsAtFront() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)

        let first = manager.addEntry(.plainText("First"), isSensitive: false)
        let second = manager.addEntry(.plainText("Second"), isSensitive: false)

        #expect(manager.entries[0].id == second.id)
        #expect(manager.entries[1].id == first.id)
    }

    @Test("addEntry persists to storage")
    func addEntryPersists() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)

        _ = manager.addEntry(.plainText("Test"), isSensitive: false)

        #expect(persistence.saveHistoryCallCount == 1)
        #expect(persistence.lastSavedEntries?.count == 1)
    }

    @Test("addEntry returns the created entry with correct content")
    func addEntryReturnsCreatedEntry() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)

        let entry = manager.addEntry(.plainText("Hello"), isSensitive: true)

        #expect(entry.content == .plainText("Hello"))
        #expect(entry.isSensitive == true)
    }

    // MARK: - deleteEntry

    @Test("deleteEntry removes entry with matching ID")
    func deleteEntryRemovesMatch() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)
        let entry = manager.addEntry(.plainText("Delete me"), isSensitive: false)

        let result = manager.deleteEntry(id: entry.id)

        #expect(result == true)
        #expect(manager.entries.isEmpty)
    }

    @Test("deleteEntry returns false when ID not found")
    func deleteEntryReturnsFalseWhenNotFound() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)
        _ = manager.addEntry(.plainText("Keep"), isSensitive: false)

        let result = manager.deleteEntry(id: UUID())

        #expect(result == false)
        #expect(manager.entries.count == 1)
    }

    @Test("deleteEntry persists after removal")
    func deleteEntryPersists() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)
        let entry = manager.addEntry(.plainText("Delete"), isSensitive: false)
        persistence.saveHistoryCallCount = 0

        _ = manager.deleteEntry(id: entry.id)

        #expect(persistence.saveHistoryCallCount == 1)
    }

    // MARK: - clearAll

    @Test("clearAll removes all entries")
    func clearAllRemovesAll() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)
        _ = manager.addEntry(.plainText("One"), isSensitive: false)
        _ = manager.addEntry(.plainText("Two"), isSensitive: false)

        manager.clearAll()

        #expect(manager.entries.isEmpty)
    }

    @Test("clearAll persists empty state")
    func clearAllPersists() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)
        _ = manager.addEntry(.plainText("Entry"), isSensitive: false)
        persistence.saveHistoryCallCount = 0

        manager.clearAll()

        #expect(persistence.saveHistoryCallCount == 1)
        #expect(persistence.lastSavedEntries?.isEmpty == true)
    }

    // MARK: - filteredEntries

    @Test("filteredEntries returns all entries for empty query")
    func filteredEntriesEmptyQuery() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)
        _ = manager.addEntry(.plainText("Hello"), isSensitive: false)
        _ = manager.addEntry(.plainText("World"), isSensitive: false)

        let results = manager.filteredEntries(matching: "")

        #expect(results.count == 2)
    }

    @Test("filteredEntries performs case-insensitive substring match")
    func filteredEntriesCaseInsensitive() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)
        _ = manager.addEntry(.plainText("Hello World"), isSensitive: false)
        _ = manager.addEntry(.plainText("Goodbye"), isSensitive: false)

        let results = manager.filteredEntries(matching: "hello")

        #expect(results.count == 1)
        #expect(results[0].content.plainTextPreview.contains("Hello"))
    }

    @Test("filteredEntries returns empty for non-matching query")
    func filteredEntriesNoMatch() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)
        _ = manager.addEntry(.plainText("Hello"), isSensitive: false)

        let results = manager.filteredEntries(matching: "xyz")

        #expect(results.isEmpty)
    }

    // MARK: - markSensitive

    @Test("markSensitive updates the isSensitive flag")
    func markSensitiveUpdatesFlag() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)
        let entry = manager.addEntry(.plainText("Secret"), isSensitive: false)

        manager.markSensitive(id: entry.id, sensitive: true)

        #expect(manager.entries[0].isSensitive == true)
    }

    @Test("markSensitive persists change")
    func markSensitivePersists() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)
        let entry = manager.addEntry(.plainText("Secret"), isSensitive: false)
        persistence.saveHistoryCallCount = 0

        manager.markSensitive(id: entry.id, sensitive: true)

        #expect(persistence.saveHistoryCallCount == 1)
    }

    @Test("markSensitive no-ops for unknown ID")
    func markSensitiveNoOpForUnknownID() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)
        _ = manager.addEntry(.plainText("Entry"), isSensitive: false)
        persistence.saveHistoryCallCount = 0

        manager.markSensitive(id: UUID(), sensitive: true)

        #expect(persistence.saveHistoryCallCount == 0)
    }

    // MARK: - moveToTop

    @Test("moveToTop moves entry to index 0 with updated timestamp")
    func moveToTopMovesToFront() throws {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)
        let first = manager.addEntry(.plainText("First"), isSensitive: false)
        // Small delay to ensure different timestamps
        let second = manager.addEntry(.plainText("Second"), isSensitive: false)
        // Now second is at [0], first is at [1]
        let originalCapturedAt = first.capturedAt

        manager.moveToTop(id: first.id)

        #expect(manager.entries[0].id == first.id)
        #expect(manager.entries[0].capturedAt > originalCapturedAt)
        #expect(manager.entries[1].id == second.id)
    }

    @Test("moveToTop persists change")
    func moveToTopPersists() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)
        let entry = manager.addEntry(.plainText("Entry"), isSensitive: false)
        persistence.saveHistoryCallCount = 0

        manager.moveToTop(id: entry.id)

        #expect(persistence.saveHistoryCallCount == 1)
    }

    @Test("moveToTop no-ops for unknown ID")
    func moveToTopNoOpForUnknownID() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)
        _ = manager.addEntry(.plainText("Entry"), isSensitive: false)
        persistence.saveHistoryCallCount = 0

        manager.moveToTop(id: UUID())

        #expect(persistence.saveHistoryCallCount == 0)
    }

    // MARK: - Deduplication

    @Test("addEntry deduplicates byte-identical content and moves to top")
    func addEntryDeduplicatesMoveToTop() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)

        let first = manager.addEntry(.plainText("Duplicate"), isSensitive: false)
        _ = manager.addEntry(.plainText("Other"), isSensitive: false)

        // Now add the same content again
        let result = manager.addEntry(.plainText("Duplicate"), isSensitive: false)

        // Should not create a new entry
        #expect(manager.entries.count == 2)
        // The deduplicated entry should be at index 0
        #expect(manager.entries[0].id == first.id)
        #expect(result.id == first.id)
        // Timestamp should be updated
        #expect(manager.entries[0].capturedAt > first.capturedAt)
    }

    @Test("addEntry deduplication does not increase entry count")
    func addEntryDeduplicationKeepsCount() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)

        _ = manager.addEntry(.plainText("A"), isSensitive: false)
        _ = manager.addEntry(.plainText("B"), isSensitive: false)
        _ = manager.addEntry(.plainText("C"), isSensitive: false)

        // Add duplicate of "A"
        _ = manager.addEntry(.plainText("A"), isSensitive: false)

        #expect(manager.entries.count == 3)
        #expect(manager.entries[0].content == .plainText("A"))
    }

    @Test("addEntry deduplication persists changes")
    func addEntryDeduplicationPersists() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)

        _ = manager.addEntry(.plainText("Hello"), isSensitive: false)
        persistence.saveHistoryCallCount = 0

        _ = manager.addEntry(.plainText("Hello"), isSensitive: false)

        #expect(persistence.saveHistoryCallCount == 1)
    }

    @Test("addEntry does not deduplicate different content types")
    func addEntryNoDedupDifferentTypes() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)

        _ = manager.addEntry(.plainText("Hello"), isSensitive: false)
        _ = manager.addEntry(.richText(data: Data("Hello".utf8), plainFallback: "Hello"), isSensitive: false)

        #expect(manager.entries.count == 2)
    }

    @Test("addEntry does not deduplicate different plain text")
    func addEntryNoDedupDifferentText() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)

        _ = manager.addEntry(.plainText("Hello"), isSensitive: false)
        _ = manager.addEntry(.plainText("World"), isSensitive: false)

        #expect(manager.entries.count == 2)
    }

    // MARK: - Capacity Enforcement

    @Test("addEntry evicts oldest entry when at capacity")
    func addEntryEvictsOldestAtCapacity() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)
        manager.maxEntries = 3

        let first = manager.addEntry(.plainText("First"), isSensitive: false)
        _ = manager.addEntry(.plainText("Second"), isSensitive: false)
        _ = manager.addEntry(.plainText("Third"), isSensitive: false)

        // At capacity (3), now add one more
        _ = manager.addEntry(.plainText("Fourth"), isSensitive: false)

        #expect(manager.entries.count == 3)
        // Oldest (first) should be evicted
        #expect(!manager.entries.contains(where: { $0.id == first.id }))
        #expect(manager.entries[0].content == .plainText("Fourth"))
    }

    @Test("addEntry respects maxEntries of 1")
    func addEntryMaxEntriesOne() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)
        manager.maxEntries = 1

        _ = manager.addEntry(.plainText("First"), isSensitive: false)
        let second = manager.addEntry(.plainText("Second"), isSensitive: false)

        #expect(manager.entries.count == 1)
        #expect(manager.entries[0].id == second.id)
    }

    @Test("addEntry respects maxEntries of 150")
    func addEntryMaxEntries150() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)
        manager.maxEntries = 150

        for i in 0..<160 {
            _ = manager.addEntry(.plainText("Entry \(i)"), isSensitive: false)
        }

        #expect(manager.entries.count == 150)
    }

    @Test("addEntry capacity enforcement does not apply to duplicates")
    func addEntryCapacityDoesNotApplyToDuplicates() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)
        manager.maxEntries = 3

        _ = manager.addEntry(.plainText("A"), isSensitive: false)
        _ = manager.addEntry(.plainText("B"), isSensitive: false)
        _ = manager.addEntry(.plainText("C"), isSensitive: false)

        // Re-adding "A" is a duplicate, should not evict anything
        _ = manager.addEntry(.plainText("A"), isSensitive: false)

        #expect(manager.entries.count == 3)
        // All original entries should still be present
        #expect(manager.entries.contains(where: { $0.content == .plainText("A") }))
        #expect(manager.entries.contains(where: { $0.content == .plainText("B") }))
        #expect(manager.entries.contains(where: { $0.content == .plainText("C") }))
    }

    // MARK: - Error handling

    @Test("Keeps in-memory state when save fails during addEntry")
    func keepsStateOnSaveFailure() {
        let persistence = MockPersistenceService()
        let manager = HistoryManager(persistenceService: persistence)
        persistence.saveHistoryError = NSError(domain: "test", code: 1)

        let entry = manager.addEntry(.plainText("Test"), isSensitive: false)

        // In-memory state should still have the entry
        #expect(manager.entries.count == 1)
        #expect(manager.entries[0].id == entry.id)
    }
}
