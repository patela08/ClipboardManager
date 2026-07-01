import Foundation

/// Represents each discrete step in the uninstall pipeline.
enum UninstallStep: String, CaseIterable, Sendable {
    case stopMonitoring = "Stop Clipboard Monitoring"
    case stopGestureDetection = "Stop Gesture Detection"
    case removeLoginItem = "Remove Login Item"
    case resetAccessibility = "Reset Accessibility Permissions"
    case deleteDataDirectory = "Delete Data Directory"
    case deleteAppBundle = "Delete App Bundle"
    case terminateProcess = "Terminate Process"
}

/// The outcome of each uninstall step.
enum UninstallStepResult: Sendable {
    case success
    case skipped(reason: String)
    case failed(error: any Error)
    case timedOut
}

/// A record of each step's execution for diagnostics/logging.
struct UninstallLog: Sendable {
    let step: UninstallStep
    let result: UninstallStepResult
    let duration: TimeInterval
}
