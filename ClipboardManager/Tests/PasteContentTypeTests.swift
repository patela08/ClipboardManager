// Tests for paste content type behavior in PickerViewModel.
// Validates bug condition exploration (Property 1) and preservation (Property 2).
//
// Property 1 tests encode the EXPECTED behavior after the fix.
// On UNFIXED code, these tests are EXPECTED TO FAIL, confirming the bug exists.
//
// **Validates: Requirements 1.1, 1.2, 1.3**

import AppKit
import Testing
@testable import ClipboardManager

// MARK: - Property 1: Bug Condition Exploration Tests

@Suite("Bug Condition: File and Image Paste Uses Wrong API")
struct PasteBugConditionTests {

    // MARK: - Helpers

    /// Creates a minimal valid TIFF image data (1x1 pixel).
    @MainActor
    private func makeValidTiffData() -> Data {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 1, height: 1))
        image.unlockFocus()
        guard let tiffData = image.tiffRepresentation else {
            fatalError("Failed to create TIFF data for test")
        }
        return tiffData
    }

    // MARK: - File Paste Tests

    @Test("File paste: NSURL readable via readObjects and pasteboard types include .fileURL")
    @MainActor
    func filePasteReadableViaReadObjects() {
        let mockHistory = MockHistoryManager()
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: {})
        let fileURL = URL(fileURLWithPath: "/tmp/test.pdf")
        let entry = ClipboardEntry(
            content: .file(url: fileURL, fileName: "test.pdf")
        )

        vm.paste(entry: entry)

        let pasteboard = NSPasteboard.general
        let types = pasteboard.types ?? []

        #expect(types.contains(.fileURL), "Pasteboard types should include .fileURL")

        // Core validation: NSURL is readable via readObjects — this is what receiving apps use
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]
        #expect(urls != nil && !(urls!.isEmpty), "readObjects(forClasses: [NSURL.self]) should return a non-empty array — unfixed code using setString does not make NSURL readable via readObjects")
        #expect(urls?.first == fileURL, "readObjects should return the original file URL")
    }

    @Test("File paste: pasteboard has exactly one item written via writeObjects with .fileURL type")
    @MainActor
    func filePasteHasSinglePasteboardItem() {
        let mockHistory = MockHistoryManager()
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: {})
        let fileURL = URL(fileURLWithPath: "/tmp/test.pdf")
        let entry = ClipboardEntry(
            content: .file(url: fileURL, fileName: "test.pdf")
        )

        vm.paste(entry: entry)

        let pasteboard = NSPasteboard.general
        let items = pasteboard.pasteboardItems ?? []

        #expect(items.count == 1, "writeObjects should write exactly one pasteboard item")
        // When written via writeObjects with NSURL, the item declares public.file-url
        let itemTypes = items.first?.types ?? []
        #expect(itemTypes.contains(.fileURL), "Pasteboard item types should include .fileURL when written via writeObjects — unfixed code uses setString which doesn't provide full NSURL semantics")
    }

    // MARK: - Image Paste Tests

    @Test("Image paste: NSImage readable via readObjects and pasteboard types include .tiff")
    @MainActor
    func imagePasteReadableViaReadObjects() {
        let mockHistory = MockHistoryManager()
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: {})
        let tiffData = makeValidTiffData()
        let entry = ClipboardEntry(
            content: .image(data: tiffData, dimensions: ImageDimensions(width: 1, height: 1))
        )

        vm.paste(entry: entry)

        let pasteboard = NSPasteboard.general
        let types = pasteboard.types ?? []

        #expect(types.contains(.tiff), "Pasteboard types should include .tiff")

        // Core validation: NSImage is readable via readObjects — this is what receiving apps use
        let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage]
        #expect(images != nil && !(images!.isEmpty), "readObjects(forClasses: [NSImage.self]) should return a non-empty array — unfixed code using setData does not make NSImage readable via readObjects")
    }
}

// MARK: - Property 2: Preservation Tests

@Suite("Preservation — Plain Text and Rich Text Paste Unchanged")
struct PastePreservationTests {

    // MARK: - Plain Text Preservation

    @Test("Plain text paste writes exact string readable via .string type")
    @MainActor
    func plainTextBasicPreservation() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        let entry = ClipboardEntry(content: .plainText("hello"))
        vm.paste(entry: entry)

        let pasteboard = NSPasteboard.general
        #expect(pasteboard.string(forType: .string) == "hello")
    }

    @Test("Plain text paste preserves empty string")
    @MainActor
    func plainTextEmptyString() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        let entry = ClipboardEntry(content: .plainText(""))
        vm.paste(entry: entry)

        let pasteboard = NSPasteboard.general
        #expect(pasteboard.string(forType: .string) == "")
    }

    @Test("Plain text paste preserves single character")
    @MainActor
    func plainTextSingleChar() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        let entry = ClipboardEntry(content: .plainText("X"))
        vm.paste(entry: entry)

        let pasteboard = NSPasteboard.general
        #expect(pasteboard.string(forType: .string) == "X")
    }

    @Test("Plain text paste preserves long string")
    @MainActor
    func plainTextLongString() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        let longText = String(repeating: "abcdefghij", count: 1000)
        let entry = ClipboardEntry(content: .plainText(longText))
        vm.paste(entry: entry)

        let pasteboard = NSPasteboard.general
        #expect(pasteboard.string(forType: .string) == longText)
    }

    @Test("Plain text paste preserves unicode characters")
    @MainActor
    func plainTextUnicode() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        let unicodeText = "Hello 🌍🎉 こんにちは 你好 مرحبا"
        let entry = ClipboardEntry(content: .plainText(unicodeText))
        vm.paste(entry: entry)

        let pasteboard = NSPasteboard.general
        #expect(pasteboard.string(forType: .string) == unicodeText)
    }

    @Test("Plain text paste preserves newlines")
    @MainActor
    func plainTextNewlines() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        let multilineText = "line1\nline2\nline3\n"
        let entry = ClipboardEntry(content: .plainText(multilineText))
        vm.paste(entry: entry)

        let pasteboard = NSPasteboard.general
        #expect(pasteboard.string(forType: .string) == multilineText)
    }

    @Test("Plain text paste preserves tabs and special whitespace")
    @MainActor
    func plainTextSpecialWhitespace() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        let text = "col1\tcol2\tcol3\r\nnextline"
        let entry = ClipboardEntry(content: .plainText(text))
        vm.paste(entry: entry)

        let pasteboard = NSPasteboard.general
        #expect(pasteboard.string(forType: .string) == text)
    }

    // MARK: - Rich Text Preservation

    @Test("Rich text paste writes RTF data readable via .rtf type")
    @MainActor
    func richTextDataPreservation() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        let rtfData = "{\\rtf1\\ansi Hello World}".data(using: .utf8)!
        let entry = ClipboardEntry(content: .richText(data: rtfData, plainFallback: "Hello World"))
        vm.paste(entry: entry)

        let pasteboard = NSPasteboard.general
        #expect(pasteboard.data(forType: .rtf) == rtfData)
    }

    @Test("Rich text paste writes plain fallback readable via .string type")
    @MainActor
    func richTextPlainFallbackPreservation() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        let rtfData = "{\\rtf1\\ansi Formatted}".data(using: .utf8)!
        let entry = ClipboardEntry(content: .richText(data: rtfData, plainFallback: "Formatted"))
        vm.paste(entry: entry)

        let pasteboard = NSPasteboard.general
        #expect(pasteboard.string(forType: .string) == "Formatted")
    }

    @Test("Rich text paste preserves both RTF data and plain fallback simultaneously")
    @MainActor
    func richTextBothTypesPreservation() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        let rtfData = "{\\rtf1\\ansi\\b Bold Text}".data(using: .utf8)!
        let fallback = "Bold Text"
        let entry = ClipboardEntry(content: .richText(data: rtfData, plainFallback: fallback))
        vm.paste(entry: entry)

        let pasteboard = NSPasteboard.general
        #expect(pasteboard.data(forType: .rtf) == rtfData)
        #expect(pasteboard.string(forType: .string) == fallback)
    }

    @Test("Rich text paste preserves unicode plain fallback")
    @MainActor
    func richTextUnicodeFallback() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        let rtfData = "{\\rtf1\\ansi Unicode}".data(using: .utf8)!
        let fallback = "Unicode 🎉 テスト"
        let entry = ClipboardEntry(content: .richText(data: rtfData, plainFallback: fallback))
        vm.paste(entry: entry)

        let pasteboard = NSPasteboard.general
        #expect(pasteboard.string(forType: .string) == fallback)
    }

    // MARK: - Dismiss Call Preservation

    @Test("onDismiss is called exactly once after plain text paste")
    @MainActor
    func dismissCalledOnceForPlainText() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        let entry = ClipboardEntry(content: .plainText("test"))
        vm.paste(entry: entry)

        #expect(dismissCount == 1)
    }

    @Test("onDismiss is called exactly once after rich text paste")
    @MainActor
    func dismissCalledOnceForRichText() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        let rtfData = "{\\rtf1\\ansi test}".data(using: .utf8)!
        let entry = ClipboardEntry(content: .richText(data: rtfData, plainFallback: "test"))
        vm.paste(entry: entry)

        #expect(dismissCount == 1)
    }

    @Test("onDismiss is called exactly once after file paste")
    @MainActor
    func dismissCalledOnceForFile() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        let fileURL = URL(fileURLWithPath: "/tmp/test.pdf")
        let entry = ClipboardEntry(content: .file(url: fileURL, fileName: "test.pdf"))
        vm.paste(entry: entry)

        #expect(dismissCount == 1)
    }

    @Test("onDismiss is called exactly once after image paste")
    @MainActor
    func dismissCalledOnceForImage() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        // Create minimal valid TIFF data (1x1 pixel)
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 1, height: 1))
        image.unlockFocus()
        let tiffData = image.tiffRepresentation!

        let entry = ClipboardEntry(content: .image(data: tiffData, dimensions: ImageDimensions(width: 1, height: 1)))
        vm.paste(entry: entry)

        #expect(dismissCount == 1)
    }

    @Test("onDismiss is not called multiple times for a single paste")
    @MainActor
    func dismissNotCalledMultipleTimes() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        let entry = ClipboardEntry(content: .plainText("once"))
        vm.paste(entry: entry)
        // Do not paste again - verify only one call happened
        #expect(dismissCount == 1)

        // Paste again to verify each paste triggers exactly one dismiss
        vm.paste(entry: entry)
        #expect(dismissCount == 2)
    }

    // MARK: - No Extra Types for Plain Text

    @Test("Plain text paste contains .string type in pasteboard types")
    @MainActor
    func plainTextContainsStringType() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        let entry = ClipboardEntry(content: .plainText("type check"))
        vm.paste(entry: entry)

        let pasteboard = NSPasteboard.general
        let types = pasteboard.types ?? []
        #expect(types.contains(.string))
    }

    @Test("Plain text paste does not contain .rtf type")
    @MainActor
    func plainTextDoesNotContainRtfType() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        let entry = ClipboardEntry(content: .plainText("no rtf"))
        vm.paste(entry: entry)

        let pasteboard = NSPasteboard.general
        let types = pasteboard.types ?? []
        #expect(!types.contains(.rtf))
    }

    @Test("Plain text paste does not contain .tiff type")
    @MainActor
    func plainTextDoesNotContainTiffType() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        let entry = ClipboardEntry(content: .plainText("no tiff"))
        vm.paste(entry: entry)

        let pasteboard = NSPasteboard.general
        let types = pasteboard.types ?? []
        #expect(!types.contains(.tiff))
    }

    @Test("Plain text paste does not contain .fileURL type")
    @MainActor
    func plainTextDoesNotContainFileURLType() {
        let mockHistory = MockHistoryManager()
        var dismissCount = 0
        let vm = PickerViewModel(historyManager: mockHistory, onDismiss: { dismissCount += 1 })

        let entry = ClipboardEntry(content: .plainText("no fileurl"))
        vm.paste(entry: entry)

        let pasteboard = NSPasteboard.general
        let types = pasteboard.types ?? []
        #expect(!types.contains(.fileURL))
    }
}
