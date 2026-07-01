import Foundation

/// Stores the width and height of a captured image.
struct ImageDimensions: Codable, Equatable, Sendable {
    let width: Int
    let height: Int
}
