import AppKit
@testable import ClipboardManager

/// Mock implementation of SensitivityDetecting for testing.
final class MockSensitivityDetector: SensitivityDetecting {

    // MARK: - Call tracking

    var isSensitiveCallCount = 0

    // MARK: - Captured arguments

    var lastCheckedSourceApp: String?
    var lastCheckedPasteboardTypes: [NSPasteboard.PasteboardType]?

    // MARK: - Configurable return value

    var isSensitiveResult: Bool = false

    /// Apps that should always return sensitive.
    var sensitiveApps: Set<String> = []

    func isSensitive(sourceApp: String?, pasteboardTypes: [NSPasteboard.PasteboardType]) -> Bool {
        isSensitiveCallCount += 1
        lastCheckedSourceApp = sourceApp
        lastCheckedPasteboardTypes = pasteboardTypes

        if let app = sourceApp, sensitiveApps.contains(app) {
            return true
        }
        return isSensitiveResult
    }
}
