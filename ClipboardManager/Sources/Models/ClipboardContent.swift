import Foundation

/// Represents the content of a clipboard entry.
/// Each case corresponds to a different type of pasteboard data.
enum ClipboardContent: Codable, Equatable, Sendable {
    case plainText(String)
    case richText(data: Data, plainFallback: String)
    case image(data: Data, dimensions: ImageDimensions)
    case file(url: URL, fileName: String)

    /// Returns a plain text preview suitable for display in the picker.
    var plainTextPreview: String {
        switch self {
        case .plainText(let text):
            return text
        case .richText(_, let plainFallback):
            return plainFallback
        case .image(_, let dimensions):
            return "Image (\(dimensions.width)×\(dimensions.height))"
        case .file(_, let fileName):
            return "File: \(fileName)"
        }
    }

    /// The content type classification for this content.
    var contentType: ContentType {
        switch self {
        case .plainText: return .plainText
        case .richText: return .richText
        case .image: return .image
        case .file: return .file
        }
    }

    /// The approximate byte size of this content.
    var byteSize: Int {
        switch self {
        case .plainText(let text):
            return text.utf8.count
        case .richText(let data, _):
            return data.count
        case .image(let data, _):
            return data.count
        case .file(_, _):
            // File references are just URLs, minimal size
            return 0
        }
    }
}
