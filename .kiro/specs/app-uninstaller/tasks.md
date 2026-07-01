# Implementation Plan: App Uninstaller

## Overview

Implement a complete self-uninstall capability for the ClipboardManager macOS menu bar app. The implementation adds a single `UninstallService` class that orchestrates a 7-step sequential removal pipeline, exposed via two entry points (menu bar item and settings button) with an NSAlert confirmation dialog. Protocol-based dependency injection enables full testability of the pipeline logic.

## Tasks

- [x] 1. Define protocols, data models, and UninstallService skeleton
  - [x] 1.1 Create the Uninstalling protocol and ProcessLaunching protocol
    - Create `Sources/Protocols/Uninstalling.swift` with the `Uninstalling` protocol defining `requestUninstall()`
    - Create `Sources/Protocols/ProcessLaunching.swift` with a `ProcessLaunching` protocol that wraps `Process` execution for tccutil shell-out (enables mocking)
    - _Requirements: 9.1_

  - [x] 1.2 Create UninstallStep enum and result models
    - Create `Sources/Models/UninstallStep.swift` with the `UninstallStep` enum (all 7 cases), `UninstallStepResult` enum (success, skipped, failed, timedOut), and `UninstallLog` struct
    - _Requirements: 9.1, 9.4_

  - [x] 1.3 Create UninstallService class with initializer and dependency injection
    - Create `Sources/Services/UninstallService.swift` with the `@MainActor final class UninstallService: Uninstalling`
    - Define all stored properties: `clipboardMonitor`, `gestureDetector`, `fileManager`, `processLauncher`, `bundleIdentifier`, `appBundleURL`, `dataDirectoryURL`, `isDialogPresented` flag
    - Implement the initializer accepting all dependencies
    - Add `os.Logger` with subsystem `"com.clipboardmanager"` and category `"UninstallService"`
    - _Requirements: 9.1, 9.2_

- [x] 2. Implement confirmation dialog and entry point guard
  - [x] 2.1 Implement presentConfirmationDialog() method
    - Create the NSAlert with `.critical` style, message text "This will permanently remove ClipboardManager and all its data. Are you sure?", informative text matching requirement
    - Add "Uninstall" button with `hasDestructiveAction = true` as first button
    - Add "Cancel" button as second button (default action)
    - Return `true` if user clicked Uninstall (`.alertFirstButtonReturn`), `false` otherwise (handles Cancel and Escape)
    - Guard against multiple presentations using `isDialogPresented` flag; bring existing dialog to focus via `NSApp.activate(ignoringOtherApps: true)` if already showing
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 1.3, 2.3, 2.4_

  - [x] 2.2 Implement requestUninstall() entry point method
    - Call `presentConfirmationDialog()`, if confirmed call `executeUninstallPipeline()`
    - If dialog was already presented (guard triggered), return without action
    - _Requirements: 1.2, 2.2, 10.1, 10.2_

- [x] 3. Implement pipeline steps 1-4 (service stops and system deregistration)
  - [x] 3.1 Implement stopMonitoring() and stopGestureDetection() methods
    - Call `clipboardMonitor.stopMonitoring()` and `gestureDetector.stopListening()`
    - Wrap each in timeout logic (10 seconds max)
    - Log success/failure, continue on failure
    - _Requirements: 9.1, 9.2, 9.3_

  - [x] 3.2 Implement removeLoginItem() method
    - Call `SMAppService.mainApp.unregister()` within a 5-second timeout
    - Catch and log any errors; continue pipeline on failure
    - _Requirements: 4.1, 4.2, 4.3_

  - [x] 3.3 Implement resetAccessibilityPermissions() method
    - Use the `ProcessLaunching` protocol to execute `tccutil reset Accessibility <bundleIdentifier>`
    - Enforce 10-second timeout on the process
    - Log stderr/exit code on failure; continue pipeline on failure
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [x] 4. Implement pipeline steps 5-7 (file deletion and termination)
  - [x] 4.1 Implement deleteDataDirectory() method
    - Check if data directory exists via `fileManager.fileExists`; skip entirely if not present
    - Enumerate all contents of the data directory
    - Attempt to delete each file/subdirectory individually, logging failures for each
    - After all individual deletions attempted, attempt to delete the data directory itself
    - Log error if directory deletion fails; continue pipeline
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

  - [x] 4.2 Implement deleteAppBundle() method
    - Use `fileManager.removeItem(at: appBundleURL)` to delete the app bundle directly (not Trash)
    - Verify deletion by checking `fileManager.fileExists(atPath:)` returns false
    - Return `true` on success; on failure, invoke `onError` callback with the path that failed
    - Enforce 10-second timeout
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 4.3 Implement terminateApp() method
    - Call `NSApp.terminate(nil)`
    - Schedule a fallback `DispatchQueue.main.asyncAfter(deadline: .now() + 5)` that calls `exit(0)` if process is still alive
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

  - [x] 4.4 Implement executeUninstallPipeline() orchestrator method
    - Call each step sequentially in order: stopMonitoring → stopGestureDetection → removeLoginItem → resetAccessibilityPermissions → deleteDataDirectory → deleteAppBundle → terminateApp
    - Record each step result in an array of `UninstallLog` entries
    - If deleteAppBundle returns false, show error alert before terminating
    - Ensure no subsequent step is called until current step completes or times out
    - Ensure no backup/export files are created at any point
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 10.1, 10.2, 10.3_

- [x] 5. Checkpoint - Ensure core service compiles
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Integrate with MenuBarController
  - [x] 6.1 Add uninstall menu item to MenuBarController
    - Add `var onUninstall: (() -> Void)?` callback property
    - In `setupMenuBar()`, insert a separator and "Uninstall ClipboardManager..." menu item immediately before the existing Quit item
    - Add `@objc` action method that invokes `onUninstall?()`
    - _Requirements: 1.1, 1.2_

- [x] 7. Integrate with SettingsView
  - [x] 7.1 Add uninstall button to SettingsView
    - Add `onUninstall: () -> Void` parameter to SettingsView (or closure property)
    - Add a `Button(role: .destructive)` with title "Uninstall ClipboardManager..." in the About section
    - Wire button action to call `onUninstall()`
    - _Requirements: 2.1, 2.2_

- [x] 8. Wire UninstallService in AppDelegate
  - [x] 8.1 Create and wire UninstallService in AppDelegate
    - Add `private var uninstallService: UninstallService!` property
    - Instantiate in `initializeServices()` with all dependencies (clipboardMonitor, gestureDetector, .default FileManager, DefaultProcessLauncher, bundle identifier, bundle URL, persistence directory URL)
    - Wire `menuBarController.onUninstall` to call `uninstallService.requestUninstall()`
    - Pass `onUninstall` closure to SettingsView that calls `uninstallService.requestUninstall()`
    - _Requirements: 1.2, 2.2, 9.1_

- [x] 9. Checkpoint - Ensure full integration compiles and basic flow works
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Create test infrastructure and unit tests
  - [x] 10.1 Create mock implementations for testing
    - Create `Tests/Mocks/MockClipboardMonitor.swift` conforming to `ClipboardMonitoring` with spy recording
    - Create `Tests/Mocks/MockGestureDetector.swift` conforming to `GestureDetecting` with spy recording
    - Create `Tests/Mocks/MockProcessLauncher.swift` conforming to `ProcessLaunching` with configurable success/failure
    - Create `Tests/Mocks/MockFileManager.swift` (or use protocol wrapper) to track file operations
    - Each mock should record method call order for pipeline verification
    - _Requirements: 9.1, 9.2_

  - [ ]* 10.2 Write property test for sequential operation order (Property 1)
    - **Property 1: Sequential operation order**
    - **Validates: Requirements 9.1, 9.2**
    - Generate random combinations of step success/failure/timeout outcomes
    - Assert that regardless of outcomes, steps are always invoked in exact order: stopMonitoring → stopGestureDetection → removeLoginItem → resetAccessibility → deleteDataDirectory → deleteAppBundle → terminateApp
    - Use spy pattern to record invocation timestamps/indices
    - Minimum 100 iterations

  - [ ]* 10.3 Write property test for error resilience (Property 2)
    - **Property 2: Error resilience for non-critical steps**
    - **Validates: Requirements 4.2, 5.2, 5.3, 6.5, 6.7, 9.3**
    - Generate random subsets of steps that fail (excluding app bundle deletion)
    - Assert that all subsequent steps are still attempted regardless of prior failures
    - Assert that only app bundle deletion failure produces user-visible error
    - Minimum 100 iterations

  - [ ]* 10.4 Write property test for data directory complete cleanup (Property 3)
    - **Property 3: Data directory complete cleanup**
    - **Validates: Requirements 6.3, 6.4, 6.5**
    - Generate random directory structures with varying file counts, nesting depths, and failure sets
    - Assert that every file/subdirectory has a deletion attempt made
    - Assert that directory deletion is attempted after all individual file deletions
    - Minimum 100 iterations

  - [ ]* 10.5 Write property test for no file creation during uninstall (Property 4)
    - **Property 4: No file creation during uninstall**
    - **Validates: Requirements 10.3**
    - Instrument mock FileManager to track all filesystem write/create operations
    - Generate random pipeline execution states
    - Assert that no new files, backup files, or copies are created at any path during the entire uninstall execution
    - Minimum 100 iterations

  - [ ]* 10.6 Write unit tests for UninstallService
    - Test confirmation dialog message text and button configuration
    - Test single-instance guard (isDialogPresented flag)
    - Test timeout enforcement for each step
    - Test deleteDataDirectory skips when directory doesn't exist
    - Test deleteAppBundle returns false and invokes onError on failure
    - Test terminateApp fallback to exit(0) after 5 seconds
    - _Requirements: 3.1, 3.7, 4.3, 5.2, 6.6, 7.4, 8.4_

- [x] 11. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- The project uses Swift 6.1 with swift-testing framework and targets macOS 15+
- All mocks should use the spy pattern to record method invocations for pipeline order verification
- `ProcessLaunching` protocol abstracts the shell-out to `tccutil` for testability

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["1.3"] },
    { "id": 2, "tasks": ["2.1", "3.1", "3.2", "3.3"] },
    { "id": 3, "tasks": ["2.2", "4.1", "4.2", "4.3"] },
    { "id": 4, "tasks": ["4.4", "6.1", "7.1"] },
    { "id": 5, "tasks": ["8.1"] },
    { "id": 6, "tasks": ["10.1"] },
    { "id": 7, "tasks": ["10.2", "10.3", "10.4", "10.5", "10.6"] }
  ]
}
```
