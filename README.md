# Clipboard Manager for macOS

A native macOS clipboard manager that extends the system clipboard with persistent history. Access your clipboard history with a quick **⌘V+V** gesture — press ⌘V to paste as normal, then tap V again within 1 second to open the picker.

## Features

- **Clipboard history** — Automatically captures text, rich text, images, and files
- **⌘V+V trigger gesture** — Opens a floating picker near your cursor without disrupting your workflow
- **Keyboard-driven picker** — Arrow keys to navigate, Enter to paste, number keys 1–9 for quick selection, type to search
- **Deduplication** — Identical copies are merged, not duplicated
- **Sensitive content detection** — Passwords from 1Password, Bitwarden, and other managers are automatically masked
- **Configurable** — History size (1–150), excluded apps, custom trigger shortcut, theme, content types
- **Persistent** — History and settings survive restarts (JSON file storage with atomic writes)
- **Menu bar control** — Enable/disable monitoring with a single click

## Requirements

- macOS 15.0 (Sequoia) or later
- Accessibility permission (required for gesture detection)
- Swift 6.1+ toolchain for building
- Optional: [SwiftLint](https://github.com/realm/SwiftLint), [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) for code quality

## Development Setup

### Prerequisites

- macOS 15.0+ with Swift 6.1+ toolchain
- Optional but recommended:

```bash
brew install swiftlint swiftformat
```

### Quick Start

```bash
make build       # Compile the project
make test        # Run all tests
make run         # Build and launch (debug)
```

### Available Make Commands

| Command | Description |
|---------|-------------|
| `make build` | Compile the project via Swift PM |
| `make test` | Run the full test suite |
| `make run` | Build and run the executable (debug) |
| `make clean` | Remove all build artifacts |
| `make lint` | Run SwiftLint static analysis |
| `make lint-fix` | Auto-fix lint issues |
| `make format` | Format code with SwiftFormat |
| `make format-check` | Check formatting without modifying files |
| `make app` | Build the .app bundle |
| `make check` | Run all quality gates (lint → format-check → build → test) |

### Code Quality Tools

- **SwiftLint** (`.swiftlint.yml`) — Static analysis with rules for line length, force unwrapping, code complexity, etc.
- **SwiftFormat** (`.swiftformat`) — Consistent code formatting (4-space indent, 120-char max width, Swift 6.1)

Run `make check` before committing to ensure code passes all quality gates.

## Building & Running

The app must be run as a `.app` bundle (not a bare executable) for the menu bar icon and system integrations to work.

### Option 1: Make (recommended)

```bash
make app
open ClipboardManager/.build/ClipboardManager.app
```

To install permanently:

```bash
cp -r ClipboardManager/.build/ClipboardManager.app /Applications/
```

### Option 2: Build script

```bash
cd ClipboardManager
./build-app.sh
open .build/ClipboardManager.app
```

### Option 3: Xcode

```bash
open ClipboardManager/Package.swift
```

Then run the `ClipboardManager` scheme (⌘R). Xcode handles the app bundle automatically.

### Why not `swift run`?

`swift run` produces a bare executable without an `.app` bundle. macOS requires a proper bundle with `Info.plist` for:
- Menu bar icon (`NSStatusItem`)
- LSUIElement (no Dock icon)
- Accessibility permission registration

## First Launch

1. The app appears as a menu bar icon (no Dock icon)
2. An onboarding window guides you through granting **Accessibility permissions**
3. Click "Open System Settings" → enable Clipboard Manager in Privacy & Security → Accessibility
4. The app detects the permission grant automatically — no restart needed

## Usage

| Action | How |
|--------|-----|
| Copy something | ⌘C as usual — it's captured automatically |
| Open clipboard picker | Press ⌘V (pastes normally), then tap V within 1 second |
| Navigate entries | ↑/↓ arrow keys |
| Paste selected entry | Enter |
| Quick paste (1–9) | Press the number key shown next to the entry |
| Search history | Just start typing in the picker |
| Dismiss picker | Escape or click outside |
| Disable monitoring | Click menu bar icon → "Disable Monitoring" |
| Open settings | Click menu bar icon → "Settings..." |
| Quit | Click menu bar icon → "Quit Clipboard Manager" |

## Settings

Access via the menu bar icon → Settings:

- **History size** — 1 to 150 entries (default: 100)
- **Content types** — Toggle capture of rich text, images, and files
- **Excluded apps** — Apps whose clipboard content is never captured
- **Trigger gesture** — Customize the keyboard shortcut (default: ⌘V+V)
- **Theme** — Light, Dark, or System
- **Launch at login** — Auto-start with macOS

All settings take effect immediately without restarting.

## Project Structure

```
ClipboardManager/
├── Package.swift
├── Sources/
│   ├── ClipboardManagerApp.swift    # SwiftUI app entry point
│   ├── AppDelegate.swift            # Service initialization and wiring
│   ├── Info.plist                   # LSUIElement, permissions
│   ├── Models/                      # Data models (ClipboardEntry, AppSettings, etc.)
│   ├── Protocols/                   # Protocol definitions for DI
│   ├── Services/                    # Core logic (monitoring, persistence, etc.)
│   └── UI/                          # SwiftUI views and AppKit controllers
└── Tests/
    ├── Mocks/                       # Mock implementations for testing
    ├── HistoryManagerTests.swift
    ├── SettingsManagerTests.swift
    └── ClipboardManagerTests.swift

# Root tooling
.gitignore                           # Git ignore rules
.swiftlint.yml                       # SwiftLint configuration
.swiftformat                         # SwiftFormat configuration
Makefile                             # Development commands
```

## Architecture

- **ClipboardMonitor** — Polls `NSPasteboard.changeCount` every 500ms
- **GestureDetector** — CGEvent tap state machine for ⌘V+V detection
- **HistoryManager** — In-memory history with deduplication and capacity enforcement
- **PersistenceService** — Atomic JSON file writes to `~/Library/Application Support/ClipboardManager/`
- **SensitivityDetector** — Identifies password manager content and concealed types
- **PickerPanel** — Non-activating NSPanel that doesn't steal focus
- **SettingsManager** — Validated settings with immediate application

All services use protocol-based dependency injection for testability.

## Privacy

This app is **100% local**. No data ever leaves your computer.

- No network connections — the app has zero networking code and no network entitlements
- No analytics, telemetry, or tracking of any kind
- No cloud sync (no iCloud, no remote servers)
- No third-party SDKs — the only dependency is Apple's swift-testing (test-only, not shipped in the app)
- All clipboard history and settings are stored as plain JSON files on your local disk

Your clipboard data stays on your machine, period.

## Data Storage

Files are stored at:

```
~/Library/Application Support/ClipboardManager/
├── history.json      # Clipboard history entries
└── settings.json     # User preferences
```

## License

MIT
