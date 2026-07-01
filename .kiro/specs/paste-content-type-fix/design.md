# Paste Content Type Fix — Bugfix Design

## Overview

The `PickerViewModel.paste(entry:)` method currently writes clipboard content using low-level `NSPasteboard` setter methods (`setString`, `setData`) that don't provide the semantic type information receiving applications need. Files are written as URL strings rather than `NSURL` pasteboard-writing objects, images are written as raw TIFF data without proper type declarations, and rich text already works correctly. The fix replaces the file and image paste paths with `NSPasteboard.writeObjects(_:)` calls using proper `NSPasteboardWriting`-conformant objects (`NSURL` for files, `NSImage` for images), matching how macOS natively places these content types on the pasteboard.

## Glossary

- **Bug_Condition (C)**: The condition that triggers the bug — pasting an entry whose content type is `.file` or `.image` from the picker
- **Property (P)**: The desired behavior — files are pasteable as file references in Finder and file-aware apps; images are recognized as image content by receiving apps
- **Preservation**: Plain text and rich text paste behavior, ⌘V simulation, and picker dismissal must remain unchanged
- **`paste(entry:)`**: The method in `PickerViewModel.swift` that writes pasteboard content and triggers the simulated paste
- **`NSPasteboardWriting`**: Apple protocol that objects conform to for proper pasteboard serialization — `NSURL` and `NSImage` conform to this
- **`writeObjects(_:)`**: The `NSPasteboard` method that writes `NSPasteboardWriting`-conformant objects with full type declarations

## Bug Details

### Bug Condition

The bug manifests when a user pastes a clipboard entry that contains file or image content. The `paste(entry:)` method uses `setString(_:forType:)` for files and `setData(_:forType:)` for images, which writes raw data without the type metadata that receiving applications rely on to identify the content semantically.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type ClipboardEntry
  OUTPUT: boolean
  
  RETURN input.content IS .file(url, fileName)
         OR input.content IS .image(data, dimensions)
END FUNCTION
```

### Examples

- **File paste into Finder**: User pastes a `.file(url: /Users/x/doc.pdf, fileName: "doc.pdf")` entry → Finder receives only the string `"file:///Users/x/doc.pdf"` as text, not a file reference. Expected: Finder recognizes a file paste and copies/moves the file.
- **Image paste into Preview**: User pastes an `.image(data: <tiffData>, dimensions: 800×600)` entry → Preview may not recognize the paste because the pasteboard item lacks proper type declarations. Expected: Preview opens a new image from the paste.
- **Image paste into Slack**: User pastes an image entry → Slack doesn't detect pasteable image content. Expected: Slack shows the image inline.
- **File paste into Terminal**: User pastes a file entry → Terminal shows the URL string literal. Expected: Terminal shows the file path (as it would from a Finder ⌘C).

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Plain text entries: `pasteboard.setString(text, forType: .string)` continues to work exactly as before
- Rich text entries: Both RTF data and plain text fallback are written to the pasteboard as before
- `simulatePaste()` (⌘V via CGEvent) is called after writing content regardless of type
- `onDismiss()` is called after paste regardless of content type
- The `ClipboardEntry` and `ClipboardContent` model types remain unchanged in structure

**Scope:**
All inputs where `content` is `.plainText` or `.richText` are completely unaffected by this fix. The fix ONLY changes the pasteboard-writing logic for `.file` and `.image` cases.

## Hypothesized Root Cause

Based on the bug description and code analysis, the root cause is:

1. **File case uses `setString` instead of `writeObjects`**: The current code calls `pasteboard.setString(url.absoluteString, forType: .fileURL)` which writes a string value tagged with the `.fileURL` UTI. However, Finder and file-aware applications expect the pasteboard to contain an `NSURL` object written via `writeObjects(_:)`, which declares multiple pasteboard types (`public.file-url`, `public.url`, `NSFilenamesPboardType`) and includes the proper promise/resolution metadata.

2. **Image case uses `setData` without object declaration**: The current code calls `pasteboard.setData(data, forType: .tiff)` which places raw bytes on the pasteboard. Many receiving apps (especially those using `NSPasteboard.readObjects(forClasses:)`) look for `NSImage` objects, not raw TIFF data. Writing via `writeObjects([NSImage(data:)])` ensures proper type advertisement including TIFF, PNG, and other representations.

3. **No data loss in capture** (not a root cause): The `ClipboardMonitor` correctly captures full image data and file URLs — the data is preserved in the `ClipboardContent` enum. The problem is purely in how the data is written back to the pasteboard during paste.

## Correctness Properties

Property 1: Bug Condition — File and Image Paste Fidelity

_For any_ clipboard entry where the content is `.file(url, fileName)` or `.image(data, dimensions)`, the fixed `paste(entry:)` method SHALL write the content to `NSPasteboard` using `writeObjects(_:)` with proper `NSPasteboardWriting`-conformant objects (`NSURL` for files, `NSImage` for images), such that receiving applications recognize the paste as a file operation or image content respectively.

**Validates: Requirements 2.1, 2.2, 2.3**

Property 2: Preservation — Plain Text and Rich Text Paste Unchanged

_For any_ clipboard entry where the content is `.plainText(text)` or `.richText(data, plainFallback)`, the fixed `paste(entry:)` method SHALL produce exactly the same pasteboard state as the original method, preserving `setString` for plain text and `setData`/`setString` for rich text, followed by `simulatePaste()` and `onDismiss()`.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct:

**File**: `ClipboardManager/Sources/UI/PickerViewModel.swift`

**Function**: `paste(entry:)`

**Specific Changes**:

1. **File case — use `writeObjects` with `NSURL`**: Replace `pasteboard.setString(url.absoluteString, forType: .fileURL)` with `pasteboard.writeObjects([url as NSURL])`. This causes `NSURL` to declare all its supported pasteboard types (`public.file-url`, `public.url`) and be recognizable by Finder and file managers.

2. **Image case — use `writeObjects` with `NSImage`**: Replace `pasteboard.setData(data, forType: .tiff)` with:
   ```swift
   if let image = NSImage(data: data) {
       pasteboard.writeObjects([image])
   } else {
       // Fallback: write raw data if NSImage init fails
       pasteboard.setData(data, forType: .tiff)
   }
   ```
   This ensures `NSImage` declares all representations (TIFF, PNG, etc.) and is discoverable by apps using `readObjects(forClasses:)`.

3. **Adjust `clearContents` placement**: The current `pasteboard.clearContents()` call at the top of `paste(entry:)` is correct and remains unchanged. Note that `writeObjects` does NOT implicitly clear the pasteboard, so the explicit clear is required.

4. **Plain text and rich text cases — no changes**: These cases remain exactly as-is. `setString` and `setData` work correctly for text content because receiving apps read text via `string(forType:)`.

5. **No model changes needed**: `ClipboardContent` and `ClipboardEntry` already store the full `URL` and image `Data` needed for the fix. No structural changes to models are required.

### Updated `paste(entry:)` Implementation

```swift
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
```

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bug on unfixed code, then verify the fix works correctly and preserves existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix. Confirm or refute the root cause analysis. If we refute, we will need to re-hypothesize.

**Test Plan**: Write tests that create `ClipboardEntry` instances with file and image content, call the paste method on unfixed code, then inspect the pasteboard to verify the types and objects written. Run on UNFIXED code to observe the deficiency.

**Test Cases**:
1. **File Paste Type Check**: Create a file entry, paste it, then check if `pasteboard.readObjects(forClasses: [NSURL.self])` returns a valid URL (will fail on unfixed code — returns nil because only a string was written)
2. **Image Paste Object Check**: Create an image entry, paste it, then check if `pasteboard.readObjects(forClasses: [NSImage.self])` returns a valid image (will fail on unfixed code — returns nil because only raw data was written)
3. **File Paste Multi-Type Check**: After pasting a file entry, verify that `pasteboard.types` includes both `.fileURL` and `.URL` (will fail on unfixed code — only `.fileURL` string is present)
4. **Image Paste Type Declaration Check**: After pasting an image entry, verify that `pasteboard.types` includes `.tiff` AND `.png` (will fail on unfixed code — only `.tiff` is present)

**Expected Counterexamples**:
- `readObjects(forClasses: [NSURL.self])` returns empty/nil after file paste
- `readObjects(forClasses: [NSImage.self])` returns empty/nil after image paste
- Pasteboard types are incomplete (missing companion types that `writeObjects` would declare)

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed function produces the expected behavior.

**Pseudocode:**
```
FOR ALL entry WHERE isBugCondition(entry) DO
  result := paste_fixed(entry)
  IF entry.content IS .file(url, _) THEN
    ASSERT pasteboard.readObjects(forClasses: [NSURL.self]) CONTAINS url
    ASSERT pasteboard.types CONTAINS .fileURL
  END IF
  IF entry.content IS .image(data, _) THEN
    ASSERT pasteboard.readObjects(forClasses: [NSImage.self]) IS NOT EMPTY
    ASSERT pasteboard.types CONTAINS .tiff
  END IF
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed function produces the same result as the original function.

**Pseudocode:**
```
FOR ALL entry WHERE NOT isBugCondition(entry) DO
  ASSERT paste_original(entry).pasteboardState = paste_fixed(entry).pasteboardState
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many test cases automatically across the plain text / rich text input domain
- It catches edge cases (empty strings, very long strings, RTF with special characters)
- It provides strong guarantees that behavior is unchanged for all non-file/non-image entries

**Test Plan**: Observe behavior on UNFIXED code first for plain text and rich text paste, then write property-based tests capturing that behavior and verify it holds after the fix.

**Test Cases**:
1. **Plain Text Preservation**: Verify that pasting any plain text entry writes exactly the string via `.string` type and no other types are added or removed
2. **Rich Text Preservation**: Verify that pasting any rich text entry writes RTF data via `.rtf` type AND plain fallback via `.string` type
3. **Simulate Paste Call Preservation**: Verify that `simulatePaste()` is called exactly once after every paste regardless of content type
4. **Dismiss Call Preservation**: Verify that `onDismiss()` is called exactly once after every paste regardless of content type

### Unit Tests

- Test `paste(entry:)` with a `.file` entry and verify `readObjects(forClasses: [NSURL.self])` returns the URL
- Test `paste(entry:)` with an `.image` entry and verify `readObjects(forClasses: [NSImage.self])` returns an image
- Test `paste(entry:)` with an `.image` entry where `NSImage(data:)` returns nil (corrupted data) — verify fallback to `setData`
- Test `paste(entry:)` with `.plainText` and `.richText` entries — verify unchanged behavior

### Property-Based Tests

- Generate random strings and verify plain text paste always produces exactly one `.string` pasteboard type with the correct value
- Generate random RTF data with plain fallbacks and verify rich text paste always produces `.rtf` + `.string` types
- Generate random valid file URLs and verify file paste always produces an `NSURL` object readable via `readObjects`
- Generate random valid image data and verify image paste produces an `NSImage` object readable via `readObjects`

### Integration Tests

- Paste a file entry, then open a new `NSPasteboard` reader and verify Finder-style file paste works (types match what Finder produces)
- Paste an image entry, then read via `readObjects` to simulate what apps like Preview or Slack would do
- Paste entries of all four types in sequence, verifying each clears the previous and writes correctly
