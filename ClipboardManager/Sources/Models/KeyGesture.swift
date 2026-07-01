import AppKit
import Foundation

/// Represents a keyboard shortcut consisting of modifier keys and a key code.
struct KeyGesture: Codable, Equatable, Sendable {
    /// Raw value of NSEvent.ModifierFlags for Codable conformance.
    let modifierFlagsRawValue: UInt
    /// The virtual key code (e.g., 0x09 for the V key).
    let keyCode: UInt16

    /// The modifier flags for this gesture.
    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRawValue)
    }

    init(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) {
        self.modifierFlagsRawValue = modifiers.rawValue
        self.keyCode = keyCode
    }

    /// The default trigger gesture: ⌘V (Command + V key).
    static let `default` = KeyGesture(
        modifiers: .command,
        keyCode: 0x09 // V key
    )
}
