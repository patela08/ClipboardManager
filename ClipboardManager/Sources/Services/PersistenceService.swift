import Foundation

/// Concrete implementation of `PersistenceServicing` that persists clipboard history
/// and app settings to JSON files in ~/Library/Application Support/ClipboardManager/.
///
/// Uses atomic writes (write to .tmp, then rename) to prevent data corruption
/// from crashes or power loss during writes.
final class PersistenceService: PersistenceServicing, @unchecked Sendable {

    // MARK: - Properties

    private(set) var directoryURL: URL
    private let historyFileURL: URL
    private let settingsFileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Initialization

    /// Creates a new PersistenceService.
    /// - Parameter directoryURL: Override for the storage directory (useful for testing).
    ///   Defaults to `~/Library/Application Support/ClipboardManager/`.
    /// - Parameter fileManager: The file manager to use. Defaults to `.default`.
    init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        let baseURL = directoryURL ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("ClipboardManager", isDirectory: true)

        self.directoryURL = baseURL
        self.historyFileURL = baseURL.appendingPathComponent("history.json")
        self.settingsFileURL = baseURL.appendingPathComponent("settings.json")
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: - PersistenceServicing

    func loadHistory() throws -> [ClipboardEntry] {
        guard fileManager.fileExists(atPath: historyFileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: historyFileURL)
            let historyFile = try decoder.decode(HistoryFile.self, from: data)
            return historyFile.entries
        } catch {
            // Corrupt or unreadable file — return empty history per requirements
            return []
        }
    }

    func saveHistory(_ entries: [ClipboardEntry]) throws {
        try ensureDirectoryExists()

        let historyFile = HistoryFile(entries: entries)
        let data = try encoder.encode(historyFile)

        try atomicWrite(data: data, to: historyFileURL)
    }

    func loadSettings() throws -> AppSettings {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else {
            return AppSettings()
        }

        do {
            let data = try Data(contentsOf: settingsFileURL)
            let settings = try decoder.decode(AppSettings.self, from: data)
            return settings
        } catch {
            // Corrupt or unreadable file — return defaults per requirements
            return AppSettings()
        }
    }

    func saveSettings(_ settings: AppSettings) throws {
        try ensureDirectoryExists()

        let data = try encoder.encode(settings)

        try atomicWrite(data: data, to: settingsFileURL)
    }

    // MARK: - Private Helpers

    /// Ensures the storage directory exists, creating it if necessary.
    private func ensureDirectoryExists() throws {
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    /// Writes data atomically by writing to a temporary file and renaming.
    /// This prevents corruption if the app crashes mid-write.
    private func atomicWrite(data: Data, to destinationURL: URL) throws {
        let tempURL = destinationURL.appendingPathExtension("tmp")

        // Write to temporary file
        try data.write(to: tempURL, options: .atomic)

        // Remove existing file if present (rename won't overwrite on all file systems)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        // Rename temp file to final destination
        try fileManager.moveItem(at: tempURL, to: destinationURL)
    }
}
