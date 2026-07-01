import Foundation

/// Result of a launched process execution.
struct ProcessResult: Sendable {
    /// The process exit code.
    let exitCode: Int32
    /// Standard output captured from the process.
    let stdout: String
    /// Standard error captured from the process.
    let stderr: String
}

/// Protocol that wraps `Process` execution for testability.
/// Used to shell out to system utilities like `tccutil`.
@MainActor
protocol ProcessLaunching: AnyObject {
    /// Launch an executable at the given path with arguments and return the result.
    /// - Parameters:
    ///   - executablePath: The full path to the executable (e.g., "/usr/bin/tccutil").
    ///   - arguments: The arguments to pass to the executable.
    /// - Returns: A `ProcessResult` containing exit code, stdout, and stderr.
    func launch(executablePath: String, arguments: [String]) -> ProcessResult
}

/// Default implementation that uses the real `Process` class.
@MainActor
final class DefaultProcessLauncher: ProcessLaunching {

    func launch(executablePath: String, arguments: [String]) -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ProcessResult(
                exitCode: -1,
                stdout: "",
                stderr: error.localizedDescription
            )
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: stdout,
            stderr: stderr
        )
    }
}
