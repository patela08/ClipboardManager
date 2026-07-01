import Foundation

/// Protocol for system-wide gesture detection.
/// Abstracts CGEvent tap interaction for testability.
protocol GestureDetecting: AnyObject {
    /// Whether gesture detection is currently active.
    var isEnabled: Bool { get }

    /// Begin listening for the trigger gesture (⌘V+V).
    func startListening()

    /// Stop listening for gestures.
    func stopListening()
}
