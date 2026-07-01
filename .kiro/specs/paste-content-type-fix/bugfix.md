# Bugfix Requirements Document

## Introduction

When users select a clipboard entry from the picker and confirm with Enter (or use quick-paste via number keys), the paste action in `PickerViewModel.paste(entry:)` only writes a minimal representation to `NSPasteboard`. For file entries, only the URL string is written as `.fileURL` type — but receiving applications (Finder, file managers, etc.) require the URL to be written as a proper `NSURL` pasteboard object to recognize it as a file operation. For image entries, only TIFF data is written, but some apps require the content to also be declared via `NSPasteboard.writeObjects` to properly handle it. The result is that pasted files appear as plain text file names and images may not paste correctly in all contexts.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN a file entry is selected and pasted THEN the system writes only the URL string via `pasteboard.setString(url.absoluteString, forType: .fileURL)`, which receiving apps do not recognize as a valid file paste, resulting in only the file name or path appearing as text

1.2 WHEN an image entry is selected and pasted THEN the system writes only raw TIFF data via `pasteboard.setData(data, forType: .tiff)` without declaring the pasteboard item properly, causing some receiving apps to not recognize the image content and fall back to ignoring the paste or showing nothing

1.3 WHEN a file entry is pasted into Finder or a file-aware application THEN the system does not provide the necessary `NSPasteboardWriting`-conformant object (NSURL), so the file is not pasted as a file reference

### Expected Behavior (Correct)

2.1 WHEN a file entry is selected and pasted THEN the system SHALL write the file URL to the pasteboard using `NSPasteboard.writeObjects([url as NSURL])` (or equivalent) so that receiving applications recognize it as a file paste operation and can move/copy the file

2.2 WHEN an image entry is selected and pasted THEN the system SHALL write the image data to the pasteboard in a way that receiving applications correctly interpret as image content (e.g., writing via `NSImage` pasteboard writing or providing both TIFF and PNG representations alongside proper type declarations)

2.3 WHEN a file entry is pasted into Finder or a file-aware application THEN the system SHALL produce the same paste behavior as if the user had originally copied the file via ⌘C in Finder

### Unchanged Behavior (Regression Prevention)

3.1 WHEN a plain text entry is selected and pasted THEN the system SHALL CONTINUE TO write the text string via `pasteboard.setString(text, forType: .string)` and paste it correctly into any text field

3.2 WHEN a rich text entry is selected and pasted THEN the system SHALL CONTINUE TO write both the RTF data and plain text fallback to the pasteboard so rich text apps receive formatted content and plain text apps receive the fallback

3.3 WHEN any entry is selected and pasted THEN the system SHALL CONTINUE TO simulate ⌘V via CGEvent after writing content to the pasteboard

3.4 WHEN any entry is selected and pasted THEN the system SHALL CONTINUE TO dismiss the picker panel after the paste action completes
