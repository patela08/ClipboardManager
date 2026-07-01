import Foundation

/// Protocol for the uninstall orchestrator.
/// Abstracts the uninstall entry point for testability.
@MainActor
protocol Uninstalling: AnyObject {
    /// Present the confirmation dialog and, if confirmed, execute the uninstall pipeline.
    func requestUninstall()
}
