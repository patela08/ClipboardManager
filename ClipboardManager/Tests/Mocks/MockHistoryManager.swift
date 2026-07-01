import Foundation
@testable import ClipboardManager

/// Mock implementation of HistoryManaging for testing.
final class MockHistoryManager: HistoryManaging {
    var entries: [ClipboardEntry] = []
    var maxEntries: Int = 100

    // MARK: - Call tracking

    var addEntryCallCount = 0
    var deleteEntryCallCount = 0
    var clearAllCallCount = 0
    var filteredEntriesCallCount = 0
    var markSensitiveCallCount = 0
    var moveToTopCallCount = 0

    // MARK: - Captured arguments

    var lastAddedContent: ClipboardContent?
    var lastAddedSensitivity: Bool?
    var lastDeletedId: UUID?
    var lastFilterQuery: String?
    var lastMarkedSensitiveId: UUID?
    var lastMarkedSensitiveValue: Bool?
    var lastMovedToTopId: UUID?

    // MARK: - Configurable return values

    var filteredEntriesResult: [ClipboardEntry] = []
    var deleteEntryResult: Bool = true

    @discardableResult
    func addEntry(_ content: ClipboardContent, isSensitive: Bool) -> ClipboardEntry {
        addEntryCallCount += 1
        lastAddedContent = content
        lastAddedSensitivity = isSensitive
        let entry = ClipboardEntry(content: content, isSensitive: isSensitive)
        entries.insert(entry, at: 0)
        return entry
    }

    @discardableResult
    func deleteEntry(id: UUID) -> Bool {
        deleteEntryCallCount += 1
        lastDeletedId = id
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries.remove(at: index)
            return true
        }
        return deleteEntryResult
    }

    func clearAll() {
        clearAllCallCount += 1
        entries.removeAll()
    }

    func filteredEntries(matching query: String) -> [ClipboardEntry] {
        filteredEntriesCallCount += 1
        lastFilterQuery = query
        if !filteredEntriesResult.isEmpty {
            return filteredEntriesResult
        }
        return entries.filter {
            $0.content.plainTextPreview.localizedCaseInsensitiveContains(query)
        }
    }

    func markSensitive(id: UUID, sensitive: Bool) {
        markSensitiveCallCount += 1
        lastMarkedSensitiveId = id
        lastMarkedSensitiveValue = sensitive
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].isSensitive = sensitive
        }
    }

    func moveToTop(id: UUID) {
        moveToTopCallCount += 1
        lastMovedToTopId = id
        if let index = entries.firstIndex(where: { $0.id == id }) {
            var entry = entries.remove(at: index)
            entry.capturedAt = Date()
            entries.insert(entry, at: 0)
        }
    }
}
