import Foundation

/// Protocol for clipboard monitoring services.
/// Abstracts system pasteboard polling for testability.
protocol ClipboardMonitoring: AnyObject {
    /// Whether clipboard monitoring is currently active.
    var isMonitoring: Bool { get }

    /// Begin polling the system pasteboard for changes.
    func startMonitoring()

    /// Stop polling the system pasteboard.
    func stopMonitoring()
}
