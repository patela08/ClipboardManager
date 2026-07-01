import Foundation
import os

/// Manages the in-memory clipboard history with persistence.
/// Provides CRUD operations, filtering, and ordering by descending `capturedAt`.
@MainActor
final class HistoryManager: ObservableObject, @preconcurrency HistoryManaging {

    // MARK: - Published State

    @Published private(set) var entries: [ClipboardEntry] = []

    // MARK: - Properties

    var maxEntries: Int = 100

    private let persistenceService: PersistenceServicing
    private let logger = Logger(subsystem: "com.clipboardmanager", category: "HistoryManager")

    // MARK: - Initialization

    init(persistenceService: PersistenceServicing) {
        self.persistenceService = persistenceService

        // Load entries from persistence. If load throws, start with empty array.
        do {
            let loaded = try persistenceService.loadHistory()
            // Ensure ordering invariant: descending capturedAt
            self.entries = loaded.sorted { $0.capturedAt > $1.capturedAt }
        } catch {
            logger.warning("Failed to load history, starting empty: \(error.localizedDescription)")
            self.entries = []
        }
    }

    // MARK: - HistoryManaging

    @discardableResult
    func addEntry(_ content: ClipboardContent, isSensitive: Bool) -> ClipboardEntry {
        // Deduplication: check for byte-identical content in existing entries
        if let existingIndex = entries.firstIndex(where: { $0.content == content }) {
            var existingEntry = entries.remove(at: existingIndex)
            existingEntry.capturedAt = Date()
            entries.insert(existingEntry, at: 0)
            persist()
            return existingEntry
        }

        // Create new entry
        let entry = ClipboardEntry(
            content: content,
            isSensitive: isSensitive
        )

        // Insert at index 0 (most recent first)
        entries.insert(entry, at: 0)

        // Capacity enforcement: evict oldest entries when over maxEntries
        let clampedMax = max(1, min(150, maxEntries))
        while entries.count > clampedMax {
            entries.removeLast()
        }

        persist()
        return entry
    }

    @discardableResult
    func deleteEntry(id: UUID) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return false
        }

        entries.remove(at: index)
        persist()
        return true
    }

    func clearAll() {
        entries.removeAll()
        persist()
    }

    func filteredEntries(matching query: String) -> [ClipboardEntry] {
        guard !query.isEmpty else {
            return entries
        }

        let lowercasedQuery = query.lowercased()
        return entries.filter { entry in
            entry.content.plainTextPreview.lowercased().contains(lowercasedQuery)
        }
    }

    func markSensitive(id: UUID, sensitive: Bool) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return
        }

        entries[index].isSensitive = sensitive
        persist()
    }

    func moveToTop(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return
        }

        var entry = entries.remove(at: index)
        entry.capturedAt = Date()
        entries.insert(entry, at: 0)
        persist()
    }

    // MARK: - Private

    private func persist() {
        do {
            try persistenceService.saveHistory(entries)
        } catch {
            // Keep in-memory state; log the failure per requirement 6.6.
            logger.error("Failed to persist history: \(error.localizedDescription)")
        }
    }
}
