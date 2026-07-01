import Foundation
@testable import ClipboardManager

/// Mock implementation of PersistenceServicing for testing.
final class MockPersistenceService: PersistenceServicing {

    // MARK: - Call tracking

    var loadHistoryCallCount = 0
    var saveHistoryCallCount = 0
    var loadSettingsCallCount = 0
    var saveSettingsCallCount = 0

    // MARK: - Stored state

    var storedEntries: [ClipboardEntry] = []
    var storedSettings: AppSettings = AppSettings()

    // MARK: - Error simulation

    var loadHistoryError: Error?
    var saveHistoryError: Error?
    var loadSettingsError: Error?
    var saveSettingsError: Error?

    // MARK: - Captured arguments

    var lastSavedEntries: [ClipboardEntry]?
    var lastSavedSettings: AppSettings?

    func loadHistory() throws -> [ClipboardEntry] {
        loadHistoryCallCount += 1
        if let error = loadHistoryError {
            throw error
        }
        return storedEntries
    }

    func saveHistory(_ entries: [ClipboardEntry]) throws {
        saveHistoryCallCount += 1
        lastSavedEntries = entries
        if let error = saveHistoryError {
            throw error
        }
        storedEntries = entries
    }

    func loadSettings() throws -> AppSettings {
        loadSettingsCallCount += 1
        if let error = loadSettingsError {
            throw error
        }
        return storedSettings
    }

    func saveSettings(_ settings: AppSettings) throws {
        saveSettingsCallCount += 1
        lastSavedSettings = settings
        if let error = saveSettingsError {
            throw error
        }
        storedSettings = settings
    }
}
