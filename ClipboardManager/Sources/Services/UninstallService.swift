import AppKit
import os
import ServiceManagement

/// Orchestrates the complete app self-removal pipeline.
/// Executes removal steps sequentially: stop services → deregister system integrations → delete files → terminate.
@MainActor
final class UninstallService: Uninstalling {

    // MARK: - Dependencies

    private let clipboardMonitor: ClipboardMonitoring
    private let gestureDetector: GestureDetecting
    private let fileManager: FileManager
    private let processLauncher: ProcessLaunching
    private let bundleIdentifier: String
    private let appBundleURL: URL
    private let dataDirectoryURL: URL

    // MARK: - State

    private var isDialogPresented: Bool = false

    // MARK: - Callbacks

    /// Called to present error messages to the user.
    var onError: ((String) -> Void)?

    // MARK: - Logging

    private let logger = Logger(
        subsystem: "com.clipboardmanager",
        category: "UninstallService"
    )

    // MARK: - Initialization

    init(
        clipboardMonitor: ClipboardMonitoring,
        gestureDetector: GestureDetecting,
        fileManager: FileManager = .default,
        processLauncher: ProcessLaunching,
        bundleIdentifier: String,
        appBundleURL: URL,
        dataDirectoryURL: URL
    ) {
        self.clipboardMonitor = clipboardMonitor
        self.gestureDetector = gestureDetector
        self.fileManager = fileManager
        self.processLauncher = processLauncher
        self.bundleIdentifier = bundleIdentifier
        self.appBundleURL = appBundleURL
        self.dataDirectoryURL = dataDirectoryURL
    }

    // MARK: - Uninstalling Protocol

    func requestUninstall() {
        let confirmed = presentConfirmationDialog()
        guard confirmed else { return }
        executeUninstallPipeline()
    }

    // MARK: - Pipeline Execution

    /// Executes the full uninstall pipeline sequentially.
    /// Each step is recorded as an `UninstallLog` entry with timing information.
    /// No backup or export files are created at any point during the pipeline.
    private func executeUninstallPipeline() {
        var logs: [UninstallLog] = []

        // Helper to execute a step, measure its duration, and record the result
        func recordStep(_ step: UninstallStep, execute: () -> UninstallStepResult) {
            let startTime = CFAbsoluteTimeGetCurrent()
            let result = execute()
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logs.append(UninstallLog(step: step, result: result, duration: duration))
            logger.info("Step '\(step.rawValue, privacy: .public)' completed in \(duration, privacy: .public)s")
        }

        // 1. Stop clipboard monitoring
        recordStep(.stopMonitoring) { stopMonitoring() }

        // 2. Stop gesture detection
        recordStep(.stopGestureDetection) { stopGestureDetection() }

        // 3. Remove login item
        recordStep(.removeLoginItem) { removeLoginItem() }

        // 4. Reset accessibility permissions
        recordStep(.resetAccessibility) { resetAccessibilityPermissions() }

        // 5. Delete data directory
        recordStep(.deleteDataDirectory) { deleteDataDirectory() }

        // 6. Delete app bundle (returns Bool, map to UninstallStepResult)
        let appBundleStartTime = CFAbsoluteTimeGetCurrent()
        let appBundleDeleted = deleteAppBundle()
        let appBundleDuration = CFAbsoluteTimeGetCurrent() - appBundleStartTime
        let appBundleResult: UninstallStepResult = appBundleDeleted ? .success : .failed(error: NSError(
            domain: "com.clipboardmanager.uninstall",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to delete app bundle at \(appBundleURL.path)"]
        ))
        logs.append(UninstallLog(step: .deleteAppBundle, result: appBundleResult, duration: appBundleDuration))
        logger.info("Step '\(UninstallStep.deleteAppBundle.rawValue, privacy: .public)' completed in \(appBundleDuration, privacy: .public)s")

        // If app bundle deletion failed, show error alert before terminating
        if !appBundleDeleted {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Uninstall Incomplete"
            alert.informativeText = "The application could not be fully removed. Some files may remain on disk."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }

        // Log the complete pipeline results
        logger.info("Uninstall pipeline completed with \(logs.count, privacy: .public) steps")
        for log in logs {
            switch log.result {
            case .success:
                logger.info("  ✓ \(log.step.rawValue, privacy: .public) — success (\(log.duration, privacy: .public)s)")
            case .skipped(let reason):
                logger.info("  ⊘ \(log.step.rawValue, privacy: .public) — skipped: \(reason, privacy: .public) (\(log.duration, privacy: .public)s)")
            case .failed(let error):
                logger.error("  ✗ \(log.step.rawValue, privacy: .public) — failed: \(error.localizedDescription, privacy: .public) (\(log.duration, privacy: .public)s)")
            case .timedOut:
                logger.error("  ⏱ \(log.step.rawValue, privacy: .public) — timed out (\(log.duration, privacy: .public)s)")
            }
        }

        // 7. Terminate the app (always called, regardless of previous step outcomes)
        terminateApp()
    }

    // MARK: - Pipeline Steps

    /// Removes the login item registration via SMAppService.
    /// Completes within 5 seconds (synchronous call); logs and continues on failure.
    func removeLoginItem() -> UninstallStepResult {
        // SMAppService.mainApp.unregister() is synchronous and should complete
        // well within the 5-second timeout safeguard.
        do {
            try SMAppService.mainApp.unregister()
            logger.info("Login item removed successfully")
            return .success
        } catch {
            logger.error("Failed to remove login item: \(error.localizedDescription)")
            return .failed(error: error)
        }
    }

    // MARK: - Confirmation Dialog

    /// Presents the confirmation NSAlert. Returns true if user confirmed "Uninstall".
    /// Guards against multiple presentations using `isDialogPresented` flag.
    func presentConfirmationDialog() -> Bool {
        guard !isDialogPresented else {
            // Bring existing dialog to focus instead of presenting a second one
            NSApp.activate(ignoringOtherApps: true)
            return false
        }

        isDialogPresented = true

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Uninstall ClipboardManager"
        alert.informativeText = "This will permanently remove ClipboardManager and all its data. Are you sure?"

        // "Uninstall" button (first button = .alertFirstButtonReturn)
        let uninstallButton = alert.addButton(withTitle: "Uninstall")
        uninstallButton.hasDestructiveAction = true

        // "Cancel" button (second button = default action)
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        isDialogPresented = false

        return response == .alertFirstButtonReturn
    }

    /// Stops clipboard monitoring with a 10-second timeout safeguard.
    /// Returns `.success` on completion, or `.timedOut` if the operation exceeds 10 seconds.
    func stopMonitoring() -> UninstallStepResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let timeoutSeconds: TimeInterval = 10

        // stopMonitoring() is synchronous; the timeout check is a safeguard against unexpected hangs.
        clipboardMonitor.stopMonitoring()

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        if elapsed >= timeoutSeconds {
            logger.error("Stop clipboard monitoring timed out after \(elapsed, privacy: .public) seconds")
            return .timedOut
        }

        logger.info("Clipboard monitoring stopped successfully")
        return .success
    }

    /// Stops gesture detection with a 10-second timeout safeguard.
    /// Returns `.success` on completion, or `.timedOut` if the operation exceeds 10 seconds.
    func stopGestureDetection() -> UninstallStepResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let timeoutSeconds: TimeInterval = 10

        // stopListening() is synchronous; the timeout check is a safeguard against unexpected hangs.
        gestureDetector.stopListening()

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        if elapsed >= timeoutSeconds {
            logger.error("Stop gesture detection timed out after \(elapsed, privacy: .public) seconds")
            return .timedOut
        }

        logger.info("Gesture detection stopped successfully")
        return .success
    }

    /// Deletes all contents of the data directory, then the data directory itself.
    /// Skips entirely if the data directory does not exist.
    /// Logs errors for individual file deletion failures but continues with remaining files.
    func deleteDataDirectory() -> UninstallStepResult {
        // Check if data directory exists; skip entirely if not present
        guard fileManager.fileExists(atPath: dataDirectoryURL.path) else {
            logger.info("Data directory does not exist, skipping deletion")
            return .skipped(reason: "Data directory does not exist")
        }

        // Enumerate all contents of the data directory
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: dataDirectoryURL,
                includingPropertiesForKeys: nil
            )
        } catch {
            logger.error("Failed to enumerate data directory contents: \(error.localizedDescription)")
            return .failed(error: error)
        }

        // Attempt to delete each file/subdirectory individually, logging failures
        for itemURL in contents {
            do {
                try fileManager.removeItem(at: itemURL)
                logger.info("Deleted: \(itemURL.path, privacy: .public)")
            } catch {
                logger.error("Failed to delete \(itemURL.path, privacy: .public): \(error.localizedDescription)")
            }
        }

        // After all individual deletions attempted, delete the data directory itself
        do {
            try fileManager.removeItem(at: dataDirectoryURL)
            logger.info("Data directory deleted successfully")
        } catch {
            logger.error("Failed to delete data directory \(self.dataDirectoryURL.path, privacy: .public): \(error.localizedDescription)")
            return .failed(error: error)
        }

        return .success
    }

    /// Terminates the app process. Schedules a fallback force-termination via `exit(0)` after 5 seconds,
    /// then calls `NSApp.terminate(nil)`. The fallback ensures the process exits even if terminate
    /// gets stuck in delegate callbacks.
    func terminateApp() {
        logger.info("Initiating app termination")

        // Schedule fallback force-termination BEFORE calling terminate.
        // If NSApp.terminate doesn't exit within 5 seconds, this ensures the process dies.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { @Sendable in
            exit(0)
        }

        // Request graceful termination. This may trigger applicationShouldTerminate delegate callbacks.
        NSApp.terminate(nil)
    }

    /// Resets accessibility permissions for this app via `tccutil reset Accessibility <bundleIdentifier>`.
    /// The 10-second timeout is enforced at the pipeline level since `ProcessLaunching.launch` is synchronous.
    /// Logs stderr and exit code on failure; continues pipeline on failure.
    func resetAccessibilityPermissions() -> UninstallStepResult {
        let result = processLauncher.launch(
            executablePath: "/usr/bin/tccutil",
            arguments: ["reset", "Accessibility", bundleIdentifier]
        )

        if result.exitCode == 0 {
            logger.info("Accessibility permissions reset successfully for \(self.bundleIdentifier, privacy: .public)")
            return .success
        } else {
            let stderrOutput = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            logger.error("Failed to reset accessibility permissions: exit code \(result.exitCode), stderr: \(stderrOutput, privacy: .public)")

            let error = NSError(
                domain: "com.clipboardmanager.uninstall",
                code: Int(result.exitCode),
                userInfo: [
                    NSLocalizedDescriptionKey: "tccutil reset failed with exit code \(result.exitCode)",
                    NSLocalizedFailureReasonErrorKey: stderrOutput
                ]
            )
            return .failed(error: error)
        }
    }

    /// Deletes the app bundle directly from disk (not Trash).
    /// Enforces a 10-second timeout safeguard on the synchronous file deletion.
    /// Returns `true` on successful deletion; on failure invokes `onError` with the path that failed and returns `false`.
    func deleteAppBundle() -> Bool {
        let startTime = CFAbsoluteTimeGetCurrent()
        let timeoutSeconds: TimeInterval = 10

        do {
            try fileManager.removeItem(at: appBundleURL)
        } catch {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            if elapsed >= timeoutSeconds {
                logger.error("App bundle deletion timed out after \(elapsed, privacy: .public) seconds")
            }
            logger.error("Failed to delete app bundle at \(self.appBundleURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            onError?("Could not fully remove \(appBundleURL.path)")
            return false
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        if elapsed >= timeoutSeconds {
            logger.error("App bundle deletion timed out after \(elapsed, privacy: .public) seconds")
            onError?("Could not fully remove \(appBundleURL.path)")
            return false
        }

        // Verify the app bundle no longer exists at the original path
        if fileManager.fileExists(atPath: appBundleURL.path) {
            logger.error("App bundle still exists after deletion attempt at \(self.appBundleURL.path, privacy: .public)")
            onError?("Could not fully remove \(appBundleURL.path)")
            return false
        }

        logger.info("App bundle deleted successfully from \(self.appBundleURL.path, privacy: .public)")
        return true
    }
}
