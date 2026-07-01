import Foundation
@testable import ClipboardManager

/// Mock implementation of GestureDetecting for testing.
/// Records method calls in `callLog` for pipeline order verification.
final class MockGestureDetector: GestureDetecting {
    private(set) var isEnabled: Bool = false

    // MARK: - Call tracking

    var startListeningCallCount = 0
    var stopListeningCallCount = 0

    /// Ordered log of method calls for pipeline verification.
    var callLog: [String] = []

    func startListening() {
        startListeningCallCount += 1
        callLog.append("startListening")
        isEnabled = true
    }

    func stopListening() {
        stopListeningCallCount += 1
        callLog.append("stopListening")
        isEnabled = false
    }
}
