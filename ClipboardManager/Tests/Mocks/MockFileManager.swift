import Foundation
@testable import ClipboardManager

/// Mock subclass of FileManager for testing.
/// Records method calls in `callLog` for pipeline order verification.
/// Allows configuring which files "exist" and which deletions "fail".
final class MockFileManager: FileManager {

    // MARK: - Call tracking

    /// Ordered log of method calls for pipeline verification.
    var callLog: [String] = []

    var fileExistsCallCount = 0
    var contentsOfDirectoryCallCount = 0
    var removeItemCallCount = 0

    // MARK: - Configurable behavior

    /// Set of paths that should report as existing. If nil, all paths report as existing.
    var existingPaths: Set<String>?

    /// Contents to return from `contentsOfDirectory(at:...)`. Keyed by directory path.
    var stubbedDirectoryContents: [String: [URL]] = [:]

    /// Set of paths that should fail when `removeItem` is called.
    var pathsToFailOnRemove: Set<String> = []

    /// The error to throw when a removal fails. Defaults to a generic file-not-found error.
    var removeItemError: Error = NSError(
        domain: NSCocoaErrorDomain,
        code: NSFileNoSuchFileError,
        userInfo: [NSLocalizedDescriptionKey: "Mock removal failure"]
    )

    // MARK: - FileManager overrides

    override func fileExists(atPath path: String) -> Bool {
        fileExistsCallCount += 1
        callLog.append("fileExists:\(path)")

        if let existingPaths = existingPaths {
            return existingPaths.contains(path)
        }
        return true
    }

    override func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: FileManager.DirectoryEnumerationOptions = []
    ) throws -> [URL] {
        contentsOfDirectoryCallCount += 1
        callLog.append("contentsOfDirectory:\(url.path)")

        if let contents = stubbedDirectoryContents[url.path] {
            return contents
        }
        return []
    }

    override func removeItem(at url: URL) throws {
        removeItemCallCount += 1
        callLog.append("removeItem:\(url.path)")

        if pathsToFailOnRemove.contains(url.path) {
            throw removeItemError
        }
    }
}
