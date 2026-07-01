import Foundation
@testable import ClipboardManager

/// Mock implementation of ClipboardMonitoring for testing.
/// Records method calls in `callLog` for pipeline order verification.
final class MockClipboardMonitor: ClipboardMonitoring {
    private(set) var isMonitoring: Bool = false

    // MARK: - Call tracking

    var startMonitoringCallCount = 0
    var stopMonitoringCallCount = 0

    /// Ordered log of method calls for pipeline verification.
    var callLog: [String] = []

    func startMonitoring() {
        startMonitoringCallCount += 1
        callLog.append("startMonitoring")
        isMonitoring = true
    }

    func stopMonitoring() {
        stopMonitoringCallCount += 1
        callLog.append("stopMonitoring")
        isMonitoring = false
    }
}
