# Requirements Document

## Introduction

This feature adds a complete self-uninstall capability to the ClipboardManager macOS menu bar app. The uninstaller permanently removes the application binary, all stored data, login item registration, and accessibility permissions. The user triggers uninstall from either the menu bar menu or the Settings view, confirms via a dialog, and the app performs a clean removal before quitting.

## Glossary

- **Uninstaller**: The module responsible for orchestrating the complete removal of ClipboardManager from the system
- **App_Bundle**: The ClipboardManager.app directory containing the application binary and resources
- **Data_Directory**: The `~/Library/Application Support/ClipboardManager/` directory containing history and settings files
- **History_File**: The `history.json` file within the Data_Directory that stores clipboard entries
- **Settings_File**: The `settings.json` file within the Data_Directory that stores user preferences
- **Login_Item**: The macOS login item registration that enables ClipboardManager to auto-start at login
- **Accessibility_Entry**: The entry in macOS Accessibility permissions (TCC database) that grants ClipboardManager CGEvent tap access
- **Confirmation_Dialog**: A modal alert presented to the user before uninstall proceeds, requiring explicit confirmation
- **Menu_Bar_Menu**: The NSMenu dropdown presented when the user clicks the ClipboardManager status item
- **Settings_View**: The SwiftUI settings window accessible from the Menu_Bar_Menu

## Requirements

### Requirement 1: Uninstall Entry Point in Menu Bar

**User Story:** As a user, I want to access the uninstall option from the menu bar menu, so that I can remove the app without opening a separate window.

#### Acceptance Criteria

1. THE Menu_Bar_Menu SHALL display an "Uninstall ClipboardManager..." menu item positioned after a menu item separator and immediately before the "Quit" menu item
2. WHEN the user selects the "Uninstall ClipboardManager..." menu item, THE Uninstaller SHALL present the Confirmation_Dialog
3. IF the Confirmation_Dialog is already presented, THEN THE Uninstaller SHALL bring the existing Confirmation_Dialog to focus instead of presenting a second dialog

### Requirement 2: Uninstall Entry Point in Settings View

**User Story:** As a user, I want to access the uninstall option from the Settings view, so that I can remove the app while managing preferences.

#### Acceptance Criteria

1. THE Settings_View SHALL display an "Uninstall ClipboardManager..." button within the About section of the settings interface
2. WHEN the user clicks the "Uninstall ClipboardManager..." button in the Settings_View, THE Uninstaller SHALL present the Confirmation_Dialog within 500 milliseconds, containing a warning message indicating that the application and its data will be removed, along with a confirm button and a cancel button
3. WHEN the user clicks the cancel button in the Confirmation_Dialog, THE Uninstaller SHALL dismiss the Confirmation_Dialog and return the user to the Settings_View without performing any uninstall actions
4. IF the Confirmation_Dialog is dismissed by pressing Escape or clicking outside the dialog, THEN THE Uninstaller SHALL treat it as a cancellation and return the user to the Settings_View without performing any uninstall actions

### Requirement 3: Confirmation Dialog

**User Story:** As a user, I want to confirm before uninstalling, so that I do not accidentally remove the app and all its data.

#### Acceptance Criteria

1. THE Confirmation_Dialog SHALL display the message "This will permanently remove ClipboardManager and all its data. Are you sure?"
2. THE Confirmation_Dialog SHALL provide a "Cancel" button that dismisses the dialog without taking action
3. THE Confirmation_Dialog SHALL provide an "Uninstall" button that initiates the uninstall process
4. WHEN the user clicks "Cancel" on the Confirmation_Dialog, THE Uninstaller SHALL dismiss the dialog and take no further action
5. WHEN the user clicks "Uninstall" on the Confirmation_Dialog, THE Uninstaller SHALL begin the removal process
6. WHEN the user presses the Escape key while the Confirmation_Dialog is displayed, THE Uninstaller SHALL dismiss the dialog and take no further action
7. THE Confirmation_Dialog SHALL present the "Uninstall" button with a destructive role and the "Cancel" button as the default action

### Requirement 4: Login Item Removal

**User Story:** As a user, I want the uninstaller to remove the login item registration, so that macOS does not attempt to launch a deleted app at login.

#### Acceptance Criteria

1. WHEN the uninstall process begins, THE Uninstaller SHALL remove the ClipboardManager Login_Item registration from macOS
2. IF the Login_Item removal fails due to a system error or the Login_Item does not exist, THEN THE Uninstaller SHALL log the failure and proceed with the remaining removal steps without interruption
3. THE Uninstaller SHALL complete the Login_Item removal step within 5 seconds, proceeding to the next removal step if the operation exceeds this duration

### Requirement 5: Accessibility Permission Removal

**User Story:** As a user, I want the uninstaller to reset accessibility permissions, so that the app does not remain in my trusted apps list after removal.

#### Acceptance Criteria

1. WHEN the uninstall process begins, THE Uninstaller SHALL reset the ClipboardManager Accessibility_Entry from the TCC database using the application's bundle identifier
2. IF the Accessibility_Entry does not exist in the TCC database at the time of removal, THEN THE Uninstaller SHALL skip the removal step and continue the uninstall process without interruption
3. IF the Accessibility_Entry removal fails due to insufficient privileges, System Integrity Protection enforcement, or the TCC database being locked, THEN THE Uninstaller SHALL log the failure reason and continue the uninstall process without interruption
4. WHEN the Accessibility_Entry removal completes or is skipped, THE Uninstaller SHALL proceed to the next removal step within 5 seconds of initiating the attempt

### Requirement 6: Data Directory Removal

**User Story:** As a user, I want the uninstaller to remove all stored data, so that no personal clipboard history remains on disk after uninstall.

#### Acceptance Criteria

1. WHEN the uninstall process begins, THE Uninstaller SHALL delete the History_File from the Data_Directory
2. WHEN the uninstall process begins, THE Uninstaller SHALL delete the Settings_File from the Data_Directory
3. WHEN the uninstall process begins, THE Uninstaller SHALL delete all other files and subdirectories within the Data_Directory
4. WHEN deletion of all Data_Directory contents has been attempted, THE Uninstaller SHALL attempt to delete the Data_Directory itself regardless of whether all individual file deletions succeeded
5. IF a file or subdirectory within the Data_Directory cannot be deleted, THEN THE Uninstaller SHALL log an error message identifying the file path that failed and continue deleting the remaining files
6. IF the Data_Directory does not exist when the uninstall process begins, THEN THE Uninstaller SHALL skip data deletion and proceed to the next uninstall step without error
7. IF the Data_Directory itself cannot be deleted, THEN THE Uninstaller SHALL log an error message identifying the directory and continue with the remaining uninstall steps

### Requirement 7: App Bundle Deletion

**User Story:** As a user, I want the app to permanently delete itself from disk, so that no traces of the application remain after uninstall.

#### Acceptance Criteria

1. WHEN the data and registration removal steps complete, THE Uninstaller SHALL delete the App_Bundle directory and all of its contents from disk within 10 seconds
2. THE Uninstaller SHALL delete the App_Bundle directly from the file system without moving the App_Bundle to Trash
3. WHEN the App_Bundle deletion completes, THE Uninstaller SHALL verify that the App_Bundle directory no longer exists at the original file-system path before reporting success to the user
4. IF the App_Bundle deletion fails due to a file-system error or insufficient permissions, THEN THE Uninstaller SHALL display an error message to the user indicating the app could not be fully removed and SHALL report which path could not be deleted
5. IF a partial deletion occurs where some files within the App_Bundle are removed but the App_Bundle directory cannot be fully deleted, THEN THE Uninstaller SHALL leave the remaining files in place and display an error message indicating the app was only partially removed

### Requirement 8: App Termination After Uninstall

**User Story:** As a user, I want the app to quit after uninstalling itself, so that no orphan processes remain running.

#### Acceptance Criteria

1. WHEN the App_Bundle has been successfully deleted, THE Uninstaller SHALL terminate the ClipboardManager process within 1 second
2. THE Uninstaller SHALL complete all file deletion operations before initiating process termination
3. IF the App_Bundle deletion fails, THEN THE Uninstaller SHALL still terminate the ClipboardManager process after displaying the error message to the user
4. IF the ClipboardManager process does not terminate within 5 seconds of initiating termination, THEN THE Uninstaller SHALL force-terminate the process

### Requirement 9: Uninstall Operation Order

**User Story:** As a developer, I want the uninstall steps to execute in a specific order, so that the app remains functional long enough to complete all cleanup tasks.

#### Acceptance Criteria

1. THE Uninstaller SHALL execute removal steps sequentially in the following order: stop clipboard monitoring, stop gesture detection, remove Login_Item, attempt Accessibility_Entry removal, delete Data_Directory contents, delete App_Bundle, terminate process
2. THE Uninstaller SHALL complete the stop of clipboard monitoring and gesture detection before beginning the Login_Item removal or any file deletion operations
3. IF any step other than App_Bundle deletion fails or encounters an error, THEN THE Uninstaller SHALL proceed to the next step in the sequence without halting
4. THE Uninstaller SHALL not initiate a subsequent step until the current step has either completed successfully or failed within 10 seconds

### Requirement 10: No Data Export or Backup

**User Story:** As a user, I want a clean uninstall without export prompts, so that the removal process is straightforward and complete.

#### Acceptance Criteria

1. THE Uninstaller SHALL perform the removal without presenting any data export, backup, or save prompts to the user at any point during the uninstall flow
2. THE Confirmation_Dialog SHALL serve as the sole user interaction point during the uninstall flow, with no additional confirmation prompts, consent screens, or dialogs requiring user input appearing after the user clicks "Uninstall"
3. THE Uninstaller SHALL NOT create any backup files, export files, or copies of user data on disk during the uninstall process
