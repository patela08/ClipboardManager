# Requirements Document

## Introduction

A native macOS clipboard manager application that extends the system clipboard with multi-clipboard history functionality. The app monitors clipboard changes, stores a configurable history of copied items, and provides a floating picker UI triggered by a rapid ⌘V+V gesture. The application targets macOS Sequoia 15+ and is built with Swift/SwiftUI for local distribution without App Store sandboxing constraints.

## Glossary

- **Clipboard_Manager**: The macOS application that monitors, stores, and provides access to clipboard history
- **Picker**: The floating panel UI that displays clipboard history entries for selection
- **Clipboard_Monitor**: The component that polls `NSPasteboard.changeCount` on a timer to detect clipboard changes
- **History_Store**: The JSON file-based persistent storage for clipboard history entries
- **Clipboard_Entry**: A single item stored in the clipboard history, containing content, metadata, and sensitivity flag
- **Trigger_Gesture**: The ⌘V+V key sequence (⌘V followed by another V within 1 second) that opens the Picker
- **Sensitive_Entry**: A clipboard entry detected as containing passwords or secrets, displayed masked in the Picker
- **Excluded_App**: An application configured by the user to never have its clipboard content captured
- **Menu_Bar_Toggle**: The menu bar icon control that enables or disables all clipboard monitoring and Picker functionality

## Requirements

### Requirement 1: Clipboard Monitoring

**User Story:** As a user, I want the app to automatically detect when I copy something, so that my clipboard history is built without manual intervention.

#### Acceptance Criteria

1. WHILE the Menu_Bar_Toggle is enabled, THE Clipboard_Monitor SHALL poll `NSPasteboard.changeCount` every 500 milliseconds to detect clipboard changes
2. WHEN the Clipboard_Monitor detects a change in `NSPasteboard.changeCount`, THE Clipboard_Manager SHALL capture the current pasteboard content and create a new Clipboard_Entry within 1 second of the change occurring
3. WHILE the Menu_Bar_Toggle is disabled, THE Clipboard_Monitor SHALL stop polling and THE Clipboard_Manager SHALL not capture any clipboard content
4. WHEN the source application is in the Excluded_App list, THE Clipboard_Manager SHALL discard the clipboard content without storing it
5. THE Clipboard_Monitor SHALL capture plain text content by default
6. WHERE the user has enabled rich text capture, THE Clipboard_Monitor SHALL also capture rich text content
7. WHERE the user has enabled image capture, THE Clipboard_Monitor SHALL also capture image content
8. WHERE the user has enabled file capture, THE Clipboard_Monitor SHALL also capture file reference content
9. IF the Clipboard_Monitor detects a changeCount increment but the pasteboard content is empty or unreadable, THEN THE Clipboard_Manager SHALL skip creating a Clipboard_Entry and continue polling
10. THE Clipboard_Monitor SHALL not create a new Clipboard_Entry if the captured content is identical to the most recent existing Clipboard_Entry
11. IF the captured content exceeds 50 MB in size, THEN THE Clipboard_Manager SHALL discard the content and not create a Clipboard_Entry

### Requirement 2: Trigger Gesture Detection

**User Story:** As a user, I want to open the clipboard picker with a quick ⌘V+V gesture, so that I can access my clipboard history without leaving my workflow.

#### Acceptance Criteria

1. WHEN the user presses ⌘V, THE Clipboard_Manager SHALL pass the keystroke through to the system to perform a normal paste operation within 50 milliseconds
2. WHEN the user presses V within 1 second after a ⌘V keystroke, THE Clipboard_Manager SHALL open the Picker within 8 points of the current text insertion caret, or within 8 points of the mouse pointer if no text caret is available
3. WHEN the user presses ⌘V and no subsequent V is pressed within 1 second, THE Clipboard_Manager SHALL take no additional action beyond the normal paste
4. WHILE the Menu_Bar_Toggle is disabled, THE Clipboard_Manager SHALL not intercept or respond to the Trigger_Gesture
5. IF the Picker is already open when the Trigger_Gesture is detected, THEN THE Clipboard_Manager SHALL bring the existing Picker to focus without opening a second instance

### Requirement 3: Picker UI Display

**User Story:** As a user, I want to see my clipboard history in a floating panel, so that I can browse and select from previously copied items.

#### Acceptance Criteria

1. WHEN the Picker is opened, THE Picker SHALL display as a floating panel positioned adjacent to the current cursor position, offset no more than 8 points from the text insertion caret or mouse pointer
2. THE Picker SHALL display a search/filter text field at the top of the panel with keyboard focus assigned by default
3. THE Picker SHALL display a scrollable list of Clipboard_Entry items below the search field, ordered by most recent capture time first
4. THE Picker SHALL display a truncated plain-text preview showing the first 80 characters of each Clipboard_Entry, appending an ellipsis if the content exceeds 80 characters
5. THE Picker SHALL display Sensitive_Entry items with masked content (obscured characters instead of actual content)
6. THE Picker SHALL display number labels 1-9 next to the first nine entries for quick selection reference
7. IF the History_Store contains no Clipboard_Entry items when the Picker is opened, THEN THE Picker SHALL display an empty-state message indicating that no clipboard history is available
8. WHEN a Clipboard_Entry contains image or file content, THE Picker SHALL display a type indicator label (such as "Image" or "File") along with the file name or image dimensions as the preview instead of truncated text

### Requirement 4: Picker Selection and Dismissal

**User Story:** As a user, I want multiple ways to select an item from the picker, so that I can choose the method that fits my workflow.

#### Acceptance Criteria

1. WHEN the Picker is opened, THE Picker SHALL highlight the first Clipboard_Entry in the list as the default selection
2. WHEN the user presses the down arrow key in the Picker, THE Picker SHALL move the selection highlight to the next entry in the list, stopping at the last entry without wrapping
3. WHEN the user presses the up arrow key in the Picker, THE Picker SHALL move the selection highlight to the previous entry in the list, stopping at the first entry without wrapping
4. WHEN the user presses Enter in the Picker and a Clipboard_Entry is highlighted, THE Clipboard_Manager SHALL paste the highlighted Clipboard_Entry into the active application and close the Picker
5. WHEN the user clicks a Clipboard_Entry in the Picker, THE Clipboard_Manager SHALL paste the clicked entry into the active application and close the Picker
6. WHEN the user presses a number key 1-9 in the Picker and a Clipboard_Entry with that number exists in the displayed list, THE Clipboard_Manager SHALL paste the corresponding numbered Clipboard_Entry into the active application and close the Picker
7. IF the user presses a number key 1-9 in the Picker and no Clipboard_Entry with that number exists in the displayed list, THEN THE Picker SHALL take no action and remain open
8. WHEN the user presses Escape in the Picker, THE Clipboard_Manager SHALL close the Picker without pasting any content
9. WHEN the Picker loses focus due to the user clicking outside the Picker panel, THE Clipboard_Manager SHALL close the Picker without pasting any content
10. WHEN the user types in the search field, THE Picker SHALL filter the displayed entries to those containing the typed text as a case-insensitive substring match and update the selection highlight to the first matching entry
11. IF the search field text matches no Clipboard_Entry items, THEN THE Picker SHALL display an empty list and disable selection actions (Enter and number keys) until a match is found or the search text is cleared

### Requirement 5: History Management

**User Story:** As a user, I want my clipboard history deduplicated and ordered by recency, so that I always see the most relevant items first.

#### Acceptance Criteria

1. THE History_Store SHALL maintain clipboard entries ordered by most recent capture time first
2. WHEN a Clipboard_Entry with byte-identical content and the same content type as an existing entry is captured, THE History_Store SHALL update the existing entry's capture time to the current time and move it to the top of the history rather than creating a duplicate
3. THE History_Store SHALL enforce a maximum entry count equal to the user-configured history size (minimum 1, default 100, maximum 150)
4. WHEN the History_Store reaches the maximum entry count, THE History_Store SHALL remove the oldest Clipboard_Entry to make room for a new capture
5. WHEN the user requests deletion of a single Clipboard_Entry, THE History_Store SHALL remove that entry from the history and persist the updated history to the JSON file
6. WHEN the user requests clearing all history, THE History_Store SHALL remove all Clipboard_Entry items from the history and persist the empty history to the JSON file
7. IF the user requests deletion of a Clipboard_Entry that does not exist in the history, THEN THE History_Store SHALL take no action and leave the history unchanged

### Requirement 6: Persistence

**User Story:** As a user, I want my clipboard history to survive app restarts and reboots, so that I don't lose my copied items.

#### Acceptance Criteria

1. THE History_Store SHALL persist all Clipboard_Entry items to a JSON file on disk
2. WHEN a new Clipboard_Entry is captured, THE History_Store SHALL write the updated history to a temporary file and atomically replace the existing JSON file only after a successful write, so that a crash or power loss does not corrupt the existing history
3. WHEN the Clipboard_Manager launches and the JSON file exists, THE History_Store SHALL load previously stored Clipboard_Entry items from the JSON file within 3 seconds
4. IF the JSON file does not exist on launch, THEN THE History_Store SHALL start with an empty history
5. IF the JSON file contains invalid JSON or cannot be read due to a file-system error, THEN THE History_Store SHALL start with an empty history and log an error message indicating the failure reason
6. IF a write to the JSON file fails due to a file-system error, THEN THE History_Store SHALL retain the current in-memory history unchanged and log an error message indicating the write failure

### Requirement 7: Sensitive Content Detection

**User Story:** As a user, I want passwords and secrets to be detected and masked, so that sensitive information is not easily visible in my clipboard history.

#### Acceptance Criteria

1. WHEN the source application is a known password manager (1Password, Bitwarden, or other configured password managers), THE Clipboard_Manager SHALL mark the Clipboard_Entry as a Sensitive_Entry
2. WHEN the pasteboard content includes the macOS `concealed` pasteboard type flag, THE Clipboard_Manager SHALL mark the Clipboard_Entry as a Sensitive_Entry
3. WHEN the user manually marks a Clipboard_Entry as sensitive, THE Clipboard_Manager SHALL update the entry to be a Sensitive_Entry
4. THE Picker SHALL display Sensitive_Entry content as a fixed-length mask of uniform characters regardless of actual content length
5. WHEN the user selects a Sensitive_Entry for pasting, THE Clipboard_Manager SHALL paste the actual unmasked content into the active application
6. WHEN the user removes the sensitive marking from a Sensitive_Entry, THE Clipboard_Manager SHALL update the entry to a standard Clipboard_Entry and THE Picker SHALL display its content as a normal unmasked preview

### Requirement 8: Menu Bar Control

**User Story:** As a user, I want a menu bar icon to quickly enable or disable the clipboard manager, so that I can control when monitoring is active.

#### Acceptance Criteria

1. THE Clipboard_Manager SHALL display an icon in the macOS menu bar whenever the application is running
2. WHEN the user clicks the menu bar icon, THE Clipboard_Manager SHALL display a menu with a toggle to enable or disable clipboard monitoring
3. WHEN the Menu_Bar_Toggle is set to disabled, THE Clipboard_Manager SHALL stop all clipboard monitoring and disable the Trigger_Gesture
4. WHEN the Menu_Bar_Toggle is set to enabled, THE Clipboard_Manager SHALL resume clipboard monitoring and enable the Trigger_Gesture
5. THE Clipboard_Manager SHALL display a visually distinct menu bar icon for the enabled state versus the disabled state, such that the two states are distinguishable at a glance without opening the menu
6. WHEN the Clipboard_Manager launches, THE Clipboard_Manager SHALL default the Menu_Bar_Toggle to enabled unless the user previously set it to disabled
7. WHEN the user changes the Menu_Bar_Toggle state, THE Clipboard_Manager SHALL persist the state so that it is restored on next application launch

### Requirement 9: Settings and Preferences

**User Story:** As a user, I want to customize the clipboard manager behavior, so that the app fits my personal workflow.

#### Acceptance Criteria

1. THE Clipboard_Manager SHALL provide a settings interface accessible from the menu bar menu
2. THE Clipboard_Manager SHALL allow the user to configure history size between 1 and 150 entries with a default of 100
3. THE Clipboard_Manager SHALL allow the user to toggle capture of rich text, images, and files independently, with all content types enabled by default
4. THE Clipboard_Manager SHALL allow the user to add and remove applications from the Excluded_App list by selecting from installed applications on the system
5. THE Clipboard_Manager SHALL allow the user to customize the Trigger_Gesture keyboard shortcut by recording a new key combination consisting of at least one modifier key and one non-modifier key
6. IF the user attempts to assign a keyboard shortcut that conflicts with a system-reserved shortcut, THEN THE Clipboard_Manager SHALL reject the assignment and display an error message indicating the shortcut is unavailable
7. THE Clipboard_Manager SHALL allow the user to select a theme preference (light, dark, or system) with a default of system
8. THE Clipboard_Manager SHALL allow the user to enable or disable auto-start at login
9. WHEN the user changes a setting, THE Clipboard_Manager SHALL apply the change within 1 second without requiring an app restart
10. THE Clipboard_Manager SHALL persist all user settings to disk and restore them when the application launches
11. IF the settings file is corrupted or unreadable, THEN THE Clipboard_Manager SHALL reset all settings to their default values and continue operation

### Requirement 10: Onboarding and Permissions

**User Story:** As a first-time user, I want guided setup to grant necessary permissions, so that the app works correctly from the start.

#### Acceptance Criteria

1. WHEN the Clipboard_Manager is launched and no Accessibility permissions have been previously granted and onboarding has not been completed, THE Clipboard_Manager SHALL present a guided onboarding flow that includes an explanation of why Accessibility permissions are required and a button that opens the macOS System Settings Accessibility pane
2. IF the user dismisses the onboarding flow without granting Accessibility permissions, THEN THE Clipboard_Manager SHALL display a persistent indicator in the menu bar menu explaining that the Trigger_Gesture will not function until Accessibility permissions are granted
3. WHEN the user grants Accessibility permissions while the Clipboard_Manager is running, THE Clipboard_Manager SHALL detect the permission change within 5 seconds and proceed to normal operation without requiring a restart
4. IF the user relaunches the Clipboard_Manager after previously dismissing onboarding without granting Accessibility permissions, THEN THE Clipboard_Manager SHALL display the permissions-required indicator in the menu bar menu instead of repeating the full onboarding flow
