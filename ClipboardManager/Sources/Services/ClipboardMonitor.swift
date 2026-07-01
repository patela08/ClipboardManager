import AppKit
import os

/// Monitors the system pasteboard for changes by polling `NSPasteboard.changeCount`
/// every 500ms. Captures clipboard content based on configured content types and
/// filters out excluded apps, duplicates, and oversized content.
@MainActor
final class ClipboardMonitor: ObservableObject, @preconcurrency ClipboardMonitoring {

    // MARK: - Published State

    @Published private(set) var isMonitoring: Bool = false

    // MARK: - Dependencies

    private let historyManager: HistoryManaging
    private let sensitivityDetector: SensitivityDetecting
    private let settingsManager: SettingsManaging
    private let pasteboard: NSPasteboard

    // MARK: - Internal State

    private var lastChangeCount: Int
    private var timer: Timer?
    private let logger = Logger(subsystem: "com.clipboardmanager", category: "ClipboardMonitor")

    /// Maximum content size in bytes (50 MB).
    private static let maxContentSize = 50 * 1024 * 1024

    /// Poll interval in seconds.
    private static let pollInterval: TimeInterval = 0.5

    // MARK: - Initialization

    init(
        historyManager: HistoryManaging,
        sensitivityDetector: SensitivityDetecting,
        settingsManager: SettingsManaging,
        pasteboard: NSPasteboard = .general
    ) {
        self.historyManager = historyManager
        self.sensitivityDetector = sensitivityDetector
        self.settingsManager = settingsManager
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    // MARK: - ClipboardMonitoring

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        lastChangeCount = pasteboard.changeCount

        timer = Timer.scheduledTimer(
            withTimeInterval: Self.pollInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.pollClipboard()
            }
        }

        logger.info("Clipboard monitoring started")
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        timer?.invalidate()
        timer = nil
        isMonitoring = false
        logger.info("Clipboard monitoring stopped")
    }

    // MARK: - Polling

    private func pollClipboard() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // Check if monitoring is enabled in settings
        guard settingsManager.settings.monitoringEnabled else { return }

        // Determine source app
        let sourceApp = getSourceApp()

        // Check excluded apps
        guard shouldCapture(from: sourceApp) else {
            logger.debug("Skipping capture from excluded app: \(sourceApp ?? "unknown")")
            return
        }

        // Capture content based on settings
        guard let content = captureContent() else {
            // Empty or unreadable pasteboard — skip silently (Req 1.9)
            return
        }

        // Check size limit (Req 1.11)
        guard !exceedsMaxSize(content) else {
            logger.debug("Skipping oversized content: \(content.byteSize) bytes")
            return
        }

        // Check for duplicates (Req 1.10)
        guard !isDuplicate(content) else {
            return
        }

        // Detect sensitivity
        let pasteboardTypes = pasteboard.types ?? []
        let isSensitive = sensitivityDetector.isSensitive(
            sourceApp: sourceApp,
            pasteboardTypes: pasteboardTypes
        )

        // Add entry to history
        historyManager.addEntry(content, isSensitive: isSensitive)
        logger.debug("Captured new clipboard entry (sensitive: \(isSensitive))")
    }

    // MARK: - Source App Detection

    private func getSourceApp() -> String? {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    // MARK: - Filtering

    /// Check if content should be captured based on excluded apps list.
    func shouldCapture(from sourceApp: String?) -> Bool {
        guard let bundleId = sourceApp else { return true }
        return !settingsManager.settings.excludedApps.contains(bundleId)
    }

    /// Check if content is byte-identical to the most recent entry.
    func isDuplicate(_ content: ClipboardContent) -> Bool {
        guard let mostRecent = historyManager.entries.first else { return false }
        return mostRecent.content == content
    }

    /// Check if content exceeds the 50 MB size limit.
    func exceedsMaxSize(_ content: ClipboardContent) -> Bool {
        return content.byteSize > Self.maxContentSize
    }

    // MARK: - Content Capture

    /// Capture content from the pasteboard based on configured content types.
    /// Priority: richText > plainText > image > file
    private func captureContent() -> ClipboardContent? {
        let types = settingsManager.settings.captureContentTypes

        // Try rich text first (if enabled)
        if types.richText, let richContent = captureRichText() {
            return richContent
        }

        // Then plain text (always enabled)
        if types.plainText, let plainContent = capturePlainText() {
            return plainContent
        }

        // Then image (if enabled)
        if types.images, let imageContent = captureImage() {
            return imageContent
        }

        // Then file (if enabled)
        if types.files, let fileContent = captureFile() {
            return fileContent
        }

        return nil
    }

    private func capturePlainText() -> ClipboardContent? {
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            return nil
        }
        return .plainText(text)
    }

    private func captureRichText() -> ClipboardContent? {
        guard let rtfData = pasteboard.data(forType: .rtf) else {
            return nil
        }
        // Get plain text fallback
        let plainFallback = pasteboard.string(forType: .string) ?? ""
        return .richText(data: rtfData, plainFallback: plainFallback)
    }

    private func captureImage() -> ClipboardContent? {
        // Try TIFF first, then PNG
        let imageData: Data?
        if let tiffData = pasteboard.data(forType: .tiff) {
            imageData = tiffData
        } else if let pngData = pasteboard.data(forType: .png) {
            imageData = pngData
        } else {
            return nil
        }

        guard let data = imageData else { return nil }

        // Extract dimensions from image data
        let dimensions = extractImageDimensions(from: data)
        return .image(data: data, dimensions: dimensions)
    }

    private func captureFile() -> ClipboardContent? {
        guard let urlString = pasteboard.string(forType: .fileURL),
              let url = URL(string: urlString) else {
            return nil
        }
        let fileName = url.lastPathComponent
        return .file(url: url, fileName: fileName)
    }

    // MARK: - Helpers

    private func extractImageDimensions(from data: Data) -> ImageDimensions {
        if let image = NSImage(data: data),
           let rep = image.representations.first {
            return ImageDimensions(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        return ImageDimensions(width: 0, height: 0)
    }
}
