import Foundation

/// Configuration for which content types the clipboard monitor should capture.
/// Plain text is always enabled and not user-configurable.
struct CaptureContentTypes: Codable, Equatable, Sendable {
    /// Always true - plain text capture cannot be disabled.
    var plainText: Bool = true
    /// Whether to capture rich text (RTF/HTML) content.
    var richText: Bool = true
    /// Whether to capture image content.
    var images: Bool = true
    /// Whether to capture file references.
    var files: Bool = true
}
