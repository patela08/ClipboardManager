# Implementation Plan: macOS Clipboard Manager

## Overview

Build the macOS Clipboard Manager incrementally in Swift/SwiftUI, starting with data models and protocols, then implementing core services (persistence, history, sensitivity detection), followed by system integration (clipboard monitoring, gesture detection), UI components (picker panel, menu bar), settings, and finally wiring everything together in the app lifecycle.

## Tasks

- [x] 1. Set up project structure, data models, and protocols
  - [x] 1.1 Create Xcode project structure and core data models
    - Create the macOS app target with SwiftUI lifecycle (LSUIElement enabled)
    - Implement `ClipboardEntry`, `ClipboardContent`, `ContentType`, `ImageDimensions`, `HistoryFile` structs/enums with Codable conformance
    - Implement `AppSettings`, `CaptureContentTypes`, `KeyGesture`, `ThemePreference` models
    - _Requirements: 6.1, 9.10_

  - [x] 1.2 Define all protocols for dependency injection
    - Create `ClipboardMonitoring`, `GestureDetecting`, `HistoryManaging`, `PersistenceServicing`, `SensitivityDetecting`, `SettingsManaging` protocols
    - Create mock implementations for each protocol for testing
    - _Requirements: All (testability infrastructure)_

- [x] 2. Implement PersistenceService
  - [x] 2.1 Implement JSON file persistence with atomic writes
    - Implement `PersistenceService` conforming to `PersistenceServicing`
    - Create `~/Library/Application Support/ClipboardManager/` directory on first use
    - Implement `loadHistory()` with error handling for missing/corrupt files
    - Implement `saveHistory()` with atomic write via temporary file + rename
    - Implement `loadSettings()` and `saveSettings()` with same error handling
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 9.10, 9.11_

  - [ ]* 2.2 Write property test for history serialization round-trip
    - **Property 14: History serialization round-trip**
    - **Validates: Requirements 6.1**

  - [ ]* 2.3 Write property test for settings serialization round-trip
    - **Property 15: Settings serialization round-trip**
    - **Validates: Requirements 9.10**

  - [ ]* 2.4 Write unit tests for PersistenceService
    - Test file creation on first use
    - Test atomic write mechanics (verify temp file strategy)
    - Test corrupt file handling (returns empty history)
    - Test missing file handling (returns empty history)
    - _Requirements: 6.2, 6.4, 6.5, 6.6_

- [x] 3. Implement HistoryManager
  - [x] 3.1 Implement core history CRUD operations
    - Implement `HistoryManager` conforming to `HistoryManaging` and `ObservableObject`
    - Implement `addEntry()` with ordering by descending `capturedAt`
    - Implement `deleteEntry()` and `clearAll()` with persistence calls
    - Implement `filteredEntries(matching:)` with case-insensitive substring matching
    - Implement `markSensitive()` and `moveToTop()`
    - _Requirements: 5.1, 5.5, 5.6, 5.7, 4.10_

  - [x] 3.2 Implement deduplication and capacity enforcement
    - Implement byte-identical duplicate detection (same content type + same bytes)
    - When duplicate detected: update `capturedAt`, move to top, don't increase count
    - Enforce `maxEntries` (1–150), evict oldest entry when at capacity
    - _Requirements: 5.2, 5.3, 5.4, 1.10_

  - [ ]* 3.3 Write property test for history ordering invariant
    - **Property 6: History ordering invariant**
    - **Validates: Requirements 3.3, 5.1**

  - [ ]* 3.4 Write property test for no consecutive duplicate entries
    - **Property 3: No consecutive duplicate entries**
    - **Validates: Requirements 1.10**

  - [ ]* 3.5 Write property test for deduplication moves to top
    - **Property 11: Deduplication moves to top with updated timestamp**
    - **Validates: Requirements 5.2**

  - [ ]* 3.6 Write property test for history size invariant
    - **Property 12: History size invariant**
    - **Validates: Requirements 5.3, 5.4**

  - [ ]* 3.7 Write property test for delete removes exactly the target
    - **Property 13: Delete removes exactly the target entry**
    - **Validates: Requirements 5.5**

  - [ ]* 3.8 Write property test for search filter correctness
    - **Property 10: Search filter correctness**
    - **Validates: Requirements 4.10**

- [x] 4. Checkpoint
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement SensitivityDetector
  - [x] 5.1 Implement sensitivity detection logic
    - Implement `SensitivityDetector` conforming to `SensitivityDetecting`
    - Detect known password manager bundle IDs (1Password, Bitwarden, etc.)
    - Detect macOS `concealed` pasteboard type flag
    - _Requirements: 7.1, 7.2_

  - [ ]* 5.2 Write property test for sensitivity detection from known sources
    - **Property 16: Sensitivity detection from known sources**
    - **Validates: Requirements 7.1, 7.2**

- [x] 6. Implement SettingsManager
  - [x] 6.1 Implement settings management with validation
    - Implement `SettingsManager` conforming to `SettingsManaging`
    - Validate history size bounds [1, 150], reject out-of-range values
    - Apply settings changes immediately without restart
    - Load settings on init from PersistenceService, reset to defaults if corrupt
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.7, 9.8, 9.9, 9.10, 9.11_

  - [ ]* 6.2 Write property test for history size configuration bounds
    - **Property 18: History size configuration bounds**
    - **Validates: Requirements 9.2**

- [x] 7. Implement ClipboardMonitor
  - [x] 7.1 Implement pasteboard polling and content capture
    - Implement `ClipboardMonitor` conforming to `ClipboardMonitoring` and `ObservableObject`
    - Poll `NSPasteboard.changeCount` every 500ms using a Timer
    - Capture content based on configured content types (plain text, rich text, image, file)
    - Implement `shouldCapture()` to check excluded apps
    - Implement `isDuplicate()` to check byte-identical content
    - Implement `exceedsMaxSize()` for 50 MB limit
    - Start/stop monitoring based on Menu_Bar_Toggle state
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11_

  - [ ]* 7.2 Write property test for excluded apps produce no entries
    - **Property 2: Excluded apps produce no entries**
    - **Validates: Requirements 1.4**

  - [ ]* 7.3 Write property test for oversized content is discarded
    - **Property 4: Oversized content is discarded**
    - **Validates: Requirements 1.11**

  - [ ]* 7.4 Write property test for disabled state blocks all activity
    - **Property 1: Disabled state blocks all activity**
    - **Validates: Requirements 1.3, 2.4, 8.3**

- [x] 8. Checkpoint
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Implement GestureDetector
  - [x] 9.1 Implement CGEvent tap for ⌘V+V gesture detection
    - Implement `GestureDetector` conforming to `GestureDetecting`
    - Create CGEvent tap for system-wide key event interception
    - Implement state machine: detect ⌘V, start 1s timer, detect V within window
    - Pass ⌘V through to system immediately for normal paste
    - Call `onTrigger` callback with cursor/caret position when gesture completes
    - Handle Accessibility permission checks and retry logic (max 3 retries, 5s apart)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [ ]* 9.2 Write property test for gesture timing window
    - **Property 5: Gesture timing window**
    - **Validates: Requirements 2.2, 2.3**

- [x] 10. Implement PickerPanel and PickerView
  - [x] 10.1 Implement PickerPanel (NSPanel)
    - Create `PickerPanel` subclass of `NSPanel` with `.nonactivatingPanel` style
    - Configure `canBecomeKey = true`, dismiss on `resignKey()`
    - Implement `show(near:)` positioning within 8 points of caret/cursor
    - Implement `dismiss()` to hide the panel
    - _Requirements: 3.1, 4.8, 4.9_

  - [x] 10.2 Implement PickerViewModel
    - Create `PickerViewModel` as `ObservableObject`
    - Implement `filter(query:)` for case-insensitive substring matching
    - Implement navigation: `moveSelection(direction:)` clamped to [0, N-1]
    - Implement `selectEntry(at:)` for number key 1-9 selection
    - Implement `confirmSelection()` to paste and dismiss
    - Implement paste action: set pasteboard content then simulate ⌘V
    - For sensitive entries, paste actual unmasked content
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.10, 4.11, 7.5_

  - [x] 10.3 Implement PickerView (SwiftUI)
    - Create `PickerView` with search field (focused by default) and scrollable entry list
    - Display truncated preview (first 80 chars + ellipsis if longer)
    - Display sensitive entries with fixed-length uniform mask characters
    - Display number labels 1-9 for first nine entries
    - Display type indicators for image/file entries
    - Display empty-state message when no entries exist
    - Handle keyboard events (arrows, Enter, Escape, number keys, typing)
    - _Requirements: 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_

  - [ ]* 10.4 Write property test for preview truncation
    - **Property 7: Preview truncation**
    - **Validates: Requirements 3.4**

  - [ ]* 10.5 Write property test for sensitive entry masking
    - **Property 8: Sensitive entry masking is fixed-length and content-independent**
    - **Validates: Requirements 3.5, 7.4**

  - [ ]* 10.6 Write property test for navigation stays in bounds
    - **Property 9: Navigation stays in bounds**
    - **Validates: Requirements 4.2, 4.3**

  - [ ]* 10.7 Write property test for sensitive paste uses actual content
    - **Property 17: Sensitive paste uses actual content**
    - **Validates: Requirements 7.5**

- [x] 11. Checkpoint
  - Ensure all tests pass, ask the user if questions arise.

- [x] 12. Implement MenuBarController and Settings UI
  - [x] 12.1 Implement MenuBarController
    - Create `MenuBarController` with `NSStatusItem`
    - Display visually distinct icons for enabled vs disabled states
    - Show menu with enable/disable toggle, settings option, quit option
    - Show permissions-required indicator when Accessibility not granted
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 10.2, 10.4_

  - [x] 12.2 Implement SettingsView (SwiftUI)
    - Create settings window with controls for history size, content types, excluded apps, trigger gesture, theme, auto-start
    - Implement keyboard shortcut recording for custom trigger gesture
    - Validate shortcut conflicts with system-reserved shortcuts
    - Changes apply immediately without restart
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9_

- [x] 13. Implement onboarding and permissions flow
  - [x] 13.1 Implement onboarding and Accessibility permission handling
    - Create onboarding view explaining Accessibility permission requirement
    - Provide button to open System Settings > Accessibility pane
    - Detect permission grant within 5 seconds (polling `AXIsProcessTrusted()`)
    - Show persistent indicator in menu if permissions not granted
    - Skip full onboarding on subsequent launches if previously dismissed
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

- [x] 14. Wire everything together in AppDelegate
  - [x] 14.1 Implement AppDelegate and app lifecycle
    - Create `AppDelegate` that initializes all services with dependency injection
    - Wire ClipboardMonitor → HistoryManager → PersistenceService
    - Wire GestureDetector → PickerPanel → PickerViewModel → HistoryManager
    - Wire MenuBarController → toggle enable/disable for Monitor + GestureDetector
    - Wire SettingsManager → all components that depend on settings
    - Handle app launch: load history, load settings, start monitoring, start gesture detection
    - Handle toggling: start/stop monitoring and gesture detection together
    - Persist Menu_Bar_Toggle state across launches
    - _Requirements: 1.1, 1.3, 2.4, 6.3, 8.3, 8.4, 8.6, 8.7_

  - [ ]* 14.2 Write integration tests for end-to-end flows
    - Test clipboard monitoring: write to pasteboard, verify entry in history
    - Test toggle disable: verify monitoring and gesture detection stop
    - Test app lifecycle: launch, capture entries, quit, relaunch, verify history loaded
    - _Requirements: 1.1, 1.3, 6.3, 8.3_

- [x] 15. Final checkpoint
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- All system interfaces (NSPasteboard, FileManager, CGEvent) use protocol-based DI for testability
- The app targets macOS Sequoia 15+ with no App Store sandboxing
- Swift Testing framework or SwiftCheck can be used for property-based tests

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2"] },
    { "id": 2, "tasks": ["2.1", "5.1", "6.1"] },
    { "id": 3, "tasks": ["2.2", "2.3", "2.4", "5.2", "6.2", "3.1"] },
    { "id": 4, "tasks": ["3.2"] },
    { "id": 5, "tasks": ["3.3", "3.4", "3.5", "3.6", "3.7", "3.8", "7.1"] },
    { "id": 6, "tasks": ["7.2", "7.3", "7.4", "9.1"] },
    { "id": 7, "tasks": ["9.2", "10.1", "10.2"] },
    { "id": 8, "tasks": ["10.3"] },
    { "id": 9, "tasks": ["10.4", "10.5", "10.6", "10.7", "12.1", "12.2"] },
    { "id": 10, "tasks": ["13.1"] },
    { "id": 11, "tasks": ["14.1"] },
    { "id": 12, "tasks": ["14.2"] }
  ]
}
```
