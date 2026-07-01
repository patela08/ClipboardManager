import AppKit
import Foundation
import os

/// Direction for arrow key navigation in the picker list.
enum Direction: Sendable {
    case up
    case down
}

/// ViewModel for the clipboard picker panel.
/// Manages displayed entries, filtering, navigation, and paste actions.
@MainActor
final class PickerViewModel: ObservableObject {

    // MARK: - Published State

    /// The currently displayed entries (filtered or all).
    @Published var displayedEntries: [ClipboardEntry] = []

    /// The current selection highlight index.
    @Published var selectedIndex: Int = 0

    // MARK: - Dependencies

    private let historyManager: HistoryManaging
    private let onDismiss: () -> Void
    private let logger = Logger(subsystem: "com.clipboardmanager", category: "PickerViewModel")

    // MARK: - Initialization

    init(historyManager: HistoryManaging, onDismiss: @escaping () -> Void) {
        self.historyManager = historyManager
        self.onDismiss = onDismiss
        self.displayedEntries = historyManager.entries
        self.selectedIndex = 0
    }

    // MARK: - Filtering (Req 4.10)

    /// Filter displayed entries by case-insensitive substring match.
    /// Resets selection to the first item.
    func filter(query: String) {
        if query.isEmpty {
            displayedEntries = historyManager.entries
        } else {
            displayedEntries = historyManager.filteredEntries(matching: query)
        }
        selectedIndex = 0
    }

    // MARK: - Navigation (Req 4.2, 4.3)

    /// Move the selection highlight up or down, clamped to [0, N-1].
    /// Does not wrap around.
    func moveSelection(direction: Direction) {
        guard !displayedEntries.isEmpty else { return }

        switch direction {
        case .down:
            selectedIndex = min(selectedIndex + 1, displayedEntries.count - 1)
        case .up:
            selectedIndex = max(selectedIndex - 1, 0)
        }
    }

    // MARK: - Number Key Selection (Req 4.6, 4.7)

    /// Select an entry by 0-based index (key 1 = index 0, key 9 = index 8).
    /// If the index is out of bounds, does nothing.
    func selectEntry(at index: Int) {
        guard index >= 0, index < displayedEntries.count else {
            return
        }

        let entry = displayedEntries[index]
        paste(entry: entry)
    }

    // MARK: - Confirm Selection (Req 4.4, 4.11)

    /// Paste the currently highlighted entry and dismiss.
    /// If displayedEntries is empty, does nothing.
    func confirmSelection() {
        guard !displayedEntries.isEmpty else { return }
        guard selectedIndex >= 0, selectedIndex < displayedEntries.count else { return }

        let entry = displayedEntries[selectedIndex]
        paste(entry: entry)
    }

    // MARK: - Dismiss (Req 4.8)

    /// Dismiss the picker without pasting.
    func dismiss() {
        onDismiss()
    }

    // MARK: - Paste Action (Req 4.4, 4.5, 7.5)

    /// Set the pasteboard content and simulate ⌘V to paste into the active app.
    /// For sensitive entries, pastes the actual unmasked content.
    func paste(entry: ClipboardEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch entry.content {
        case .plainText(let text):
            pasteboard.setString(text, forType: .string)

        case .richText(let data, let plainFallback):
            pasteboard.setData(data, forType: .rtf)
            pasteboard.setString(plainFallback, forType: .string)

        case .image(let data, _):
            if let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            } else {
                pasteboard.setData(data, forType: .tiff)
            }

        case .file(let url, _):
            pasteboard.writeObjects([url as NSURL])
        }

        simulatePaste()
        onDismiss()
    }

    // MARK: - Private

    /// Simulate ⌘V keystroke using CGEvent to paste into the active application.
    private func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)

        // Virtual key 0x09 = V key
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
