import Foundation
@testable import ClipboardManager

/// Mock implementation of ProcessLaunching for testing.
/// Records method calls in `callLog` for pipeline order verification.
/// Supports configurable success/failure via `stubbedResult`.
@MainActor
final class MockProcessLauncher: ProcessLaunching {

    // MARK: - Call tracking

    /// Ordered log of method calls for pipeline verification.
    var callLog: [String] = []

    var launchCallCount = 0

    // MARK: - Captured arguments

    var lastExecutablePath: String?
    var lastArguments: [String]?

    // MARK: - Configurable behavior

    /// The result to return from `launch`. Defaults to success (exit code 0).
    var stubbedResult = ProcessResult(exitCode: 0, stdout: "", stderr: "")

    // MARK: - ProcessLaunching

    func launch(executablePath: String, arguments: [String]) -> ProcessResult {
        launchCallCount += 1
        lastExecutablePath = executablePath
        lastArguments = arguments
        callLog.append("launch:\(executablePath) \(arguments.joined(separator: " "))")
        return stubbedResult
    }
}
