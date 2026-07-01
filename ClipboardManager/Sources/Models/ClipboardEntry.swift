import Foundation

/// A single item stored in the clipboard history.
/// Contains the captured content, metadata, and sensitivity flag.
struct ClipboardEntry: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var capturedAt: Date
    let content: ClipboardContent
    var isSensitive: Bool
    let sourceAppBundleId: String?

    init(
        id: UUID = UUID(),
        capturedAt: Date = Date(),
        content: ClipboardContent,
        isSensitive: Bool = false,
        sourceAppBundleId: String? = nil
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.content = content
        self.isSensitive = isSensitive
        self.sourceAppBundleId = sourceAppBundleId
    }
}
