import AppKit

/// Protocol for detecting sensitive clipboard content.
/// Identifies password manager sources and concealed pasteboard types.
protocol SensitivityDetecting {
    /// Determine if clipboard content should be marked as sensitive.
    /// - Parameters:
    ///   - sourceApp: The bundle identifier of the app that placed content on the pasteboard.
    ///   - pasteboardTypes: The pasteboard types present in the current pasteboard item.
    /// - Returns: `true` if the content should be treated as sensitive.
    func isSensitive(sourceApp: String?, pasteboardTypes: [NSPasteboard.PasteboardType]) -> Bool
}
