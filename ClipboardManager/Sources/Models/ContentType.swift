import Foundation

/// Represents the type of content stored in a clipboard entry.
enum ContentType: String, Codable, Sendable {
    case plainText
    case richText
    case image
    case file
}
