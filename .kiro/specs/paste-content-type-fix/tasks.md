# Implementation Plan

## Overview

Fix the `PickerViewModel.paste(entry:)` method to use `NSPasteboard.writeObjects(_:)` with proper `NSPasteboardWriting`-conformant objects (`NSURL` for files, `NSImage` for images) instead of low-level `setString`/`setData` calls that don't provide semantic type information to receiving applications.

## Tasks

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - File and Image Paste Uses Wrong API
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bug exists in `PickerViewModel.paste(entry:)`
  - **Scoped PBT Approach**: Scope the property to concrete failing cases: file entries with any valid URL, and image entries with valid TIFF data
  - Create test file `ClipboardManager/Tests/PasteContentTypeTests.swift` using swift-testing framework
  - Create a `PickerViewModel` with a `MockHistoryManager` and a no-op `onDismiss` closure
  - **File paste test**: Create a `ClipboardEntry` with `.file(url: fileURL, fileName: "test.pdf")`, call `paste(entry:)`, then assert `NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: nil)` returns a non-empty array containing the URL (will FAIL on unfixed code — `setString` does not make NSURL readable via `readObjects`)
  - **Image paste test**: Create a `ClipboardEntry` with `.image(data: validTiffData, dimensions: ...)`, call `paste(entry:)`, then assert `NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)` returns a non-empty array (will FAIL on unfixed code — `setData` does not make NSImage readable via `readObjects`)
  - **File paste multi-type test**: After pasting a file entry, verify `pasteboard.types` includes both `.fileURL` and `.URL` (will FAIL — unfixed code only writes `.fileURL` string)
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests FAIL (this is correct - it proves the bug exists)
  - Document counterexamples: `readObjects(forClasses: [NSURL.self])` returns nil/empty; `readObjects(forClasses: [NSImage.self])` returns nil/empty
  - Mark task complete when tests are written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Plain Text and Rich Text Paste Unchanged
  - **IMPORTANT**: Follow observation-first methodology
  - Observe on UNFIXED code: `paste(entry:)` with `.plainText("hello")` writes exactly `"hello"` readable via `pasteboard.string(forType: .string)`
  - Observe on UNFIXED code: `paste(entry:)` with `.richText(data: rtfData, plainFallback: "fallback")` writes RTF data readable via `pasteboard.data(forType: .rtf)` AND plain fallback via `pasteboard.string(forType: .string)`
  - Observe on UNFIXED code: `onDismiss` is called exactly once after any paste (track via closure counter)
  - Add tests to `ClipboardManager/Tests/PasteContentTypeTests.swift`
  - **Plain text preservation**: For various plain text strings (empty string, single char, long string, strings with unicode, newlines), verify `pasteboard.string(forType: .string)` equals the input text after paste
  - **Rich text preservation**: For various rich text entries, verify both `pasteboard.data(forType: .rtf)` matches input data AND `pasteboard.string(forType: .string)` matches the plain fallback
  - **Dismiss call preservation**: Verify `onDismiss()` is called exactly once for each paste call across all content types (plain text, rich text, file, image)
  - **No extra types for plain text**: Verify that after pasting plain text, `pasteboard.types` contains `.string` and does not contain `.rtf`, `.tiff`, or `.fileURL`
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 3. Fix for file and image paste content type

  - [x] 3.1 Implement the fix in `PickerViewModel.paste(entry:)`
    - In `ClipboardManager/Sources/UI/PickerViewModel.swift`, modify the `paste(entry:)` method
    - Replace `.file` case: change `pasteboard.setString(url.absoluteString, forType: .fileURL)` to `pasteboard.writeObjects([url as NSURL])`
    - Replace `.image` case: change `pasteboard.setData(data, forType: .tiff)` to use `NSImage(data:)` with `writeObjects`, falling back to `setData` if `NSImage` init fails:
      ```swift
      if let image = NSImage(data: data) {
          pasteboard.writeObjects([image])
      } else {
          pasteboard.setData(data, forType: .tiff)
      }
      ```
    - Leave `.plainText` and `.richText` cases completely unchanged
    - Leave `simulatePaste()` and `onDismiss()` calls unchanged
    - _Bug_Condition: isBugCondition(entry) where entry.content IS .file OR .image_
    - _Expected_Behavior: writeObjects([url as NSURL]) for files; writeObjects([NSImage(data:)]) for images_
    - _Preservation: Plain text uses setString(text, forType: .string); Rich text uses setData + setString unchanged_
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 3.4_

  - [x] 3.2 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - File and Image Paste Uses WriteObjects API
    - **IMPORTANT**: Re-run the SAME tests from task 1 - do NOT write new tests
    - The tests from task 1 encode the expected behavior (NSURL readable via readObjects, NSImage readable via readObjects)
    - When these tests pass, it confirms the expected behavior is satisfied
    - Run bug condition exploration tests from step 1
    - **EXPECTED OUTCOME**: Tests PASS (confirms bug is fixed)
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 3.3 Verify preservation tests still pass
    - **Property 2: Preservation** - Plain Text and Rich Text Paste Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm plain text, rich text, dismiss behavior all unchanged after fix

- [x] 4. Checkpoint - Ensure all tests pass
  - Run full test suite: `swift test` from `ClipboardManager/` directory
  - Ensure all exploration tests (Property 1) pass — confirms bug is fixed
  - Ensure all preservation tests (Property 2) pass — confirms no regressions
  - Ensure existing model tests in `ClipboardManagerTests.swift` still pass
  - Ask the user if questions arise

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2"] },
    { "id": 1, "tasks": ["3.1"] },
    { "id": 2, "tasks": ["3.2", "3.3"] },
    { "id": 3, "tasks": ["4"] }
  ]
}
```

## Notes

- Tests use the swift-testing framework (`import Testing` / `@Test` / `#expect`) not XCTest
- The `MockHistoryManager` from `Tests/Mocks/` can be reused for `PickerViewModel` instantiation
- `NSPasteboard.general` is used directly in tests since this is a macOS app with AppKit access
- The `simulatePaste()` method posts CGEvents — tests may need to avoid triggering it or mock it out to prevent side effects during test execution
- Property-based tests generate diverse inputs (random strings, various URLs, valid image data) for stronger guarantees
