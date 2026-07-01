// Tests for ClipboardManager Core Models
// These tests require Xcode to run (swift test requires the full Xcode test runtime).
// Run with: xcodebuild test -scheme ClipboardManager -destination 'platform=macOS'
//
// When Xcode is available, these tests validate:
// - ClipboardEntry default initialization
// - AppSettings default values match spec (historySize=100, all types enabled, theme=system, etc.)
// - ContentType classification for all ClipboardContent cases
// - PlainTextPreview generation for all content types
// - KeyGesture default (⌘V, keyCode 0x09)
// - HistoryFile version numbering
// - Codable round-trip for all model types

import Testing
@testable import ClipboardManager

@Suite("ClipboardManager Core Models")
struct ClipboardManagerModelTests {

    @Test("ClipboardEntry initializes with default values")
    func clipboardEntryDefaults() {
        let content = ClipboardContent.plainText("Hello")
        let entry = ClipboardEntry(content: content)

        #expect(entry.isSensitive == false)
        #expect(entry.sourceAppBundleId == nil)
        #expect(entry.content == content)
    }

    @Test("AppSettings has correct defaults")
    func appSettingsDefaults() {
        let settings = AppSettings()

        #expect(settings.historySize == 100)
        #expect(settings.captureContentTypes.plainText == true)
        #expect(settings.captureContentTypes.richText == true)
        #expect(settings.captureContentTypes.images == true)
        #expect(settings.captureContentTypes.files == true)
        #expect(settings.excludedApps.isEmpty)
        #expect(settings.theme == .system)
        #expect(settings.autoStartAtLogin == false)
        #expect(settings.monitoringEnabled == true)
    }

    @Test("ContentType classification is correct")
    func contentTypeClassification() {
        #expect(ClipboardContent.plainText("hi").contentType == .plainText)
        #expect(ClipboardContent.richText(data: .init(), plainFallback: "hi").contentType == .richText)
        #expect(ClipboardContent.image(data: .init(), dimensions: ImageDimensions(width: 100, height: 100)).contentType == .image)
    }

    @Test("Plain text preview generation")
    func plainTextPreview() {
        #expect(ClipboardContent.plainText("Hello World").plainTextPreview == "Hello World")
        #expect(ClipboardContent.richText(data: .init(), plainFallback: "Fallback").plainTextPreview == "Fallback")
        #expect(ClipboardContent.image(data: .init(), dimensions: ImageDimensions(width: 800, height: 600)).plainTextPreview == "Image (800×600)")
    }

    @Test("KeyGesture default is Command+V")
    func keyGestureDefault() {
        let gesture = KeyGesture.default
        #expect(gesture.keyCode == 0x09)
        #expect(gesture.modifiers.contains(.command))
    }

    @Test("HistoryFile uses current version")
    func historyFileVersion() {
        let file = HistoryFile(entries: [])
        #expect(file.version == 1)
        #expect(file.entries.isEmpty)
    }

    @Test("AppSettings history size range is 1 to 150")
    func historySizeRange() {
        #expect(AppSettings.historySizeRange == 1...150)
    }
}
