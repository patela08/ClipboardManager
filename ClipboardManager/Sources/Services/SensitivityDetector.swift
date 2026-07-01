import AppKit

/// Detects sensitive clipboard content based on source application or pasteboard type flags.
///
/// Identifies content from known password managers and content marked with the
/// macOS concealed pasteboard type, marking such entries as sensitive.
final class SensitivityDetector: SensitivityDetecting, Sendable {

    /// Bundle identifiers of known password manager applications.
    private let knownPasswordManagers: Set<String> = [
        "com.agilebits.onepassword7",   // 1Password 7
        "com.1password.1password",       // 1Password 8
        "com.bitwarden.desktop",         // Bitwarden
        "com.lastpass.LastPass",         // LastPass
        "com.dashlane.Dashlane",         // Dashlane
        "org.nickvision.keyring",        // Keyring
        "com.enpass.Enpass",             // Enpass
        "com.keepersecurity.keeper",     // Keeper
        "de.heinlein-support.macpass",   // MacPass
        "org.nickvision.passwords"       // Passwords
    ]

    /// The macOS concealed pasteboard type indicating sensitive content.
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    /// Determine if clipboard content should be marked as sensitive.
    ///
    /// Returns `true` if the source application is a known password manager
    /// or the pasteboard types include the concealed type flag.
    ///
    /// - Parameters:
    ///   - sourceApp: The bundle identifier of the app that placed content on the pasteboard.
    ///   - pasteboardTypes: The pasteboard types present in the current pasteboard item.
    /// - Returns: `true` if the content should be treated as sensitive.
    func isSensitive(sourceApp: String?, pasteboardTypes: [NSPasteboard.PasteboardType]) -> Bool {
        // Check if source app is a known password manager
        if let sourceApp, knownPasswordManagers.contains(sourceApp) {
            return true
        }

        // Check if pasteboard types include the concealed type
        if pasteboardTypes.contains(Self.concealedType) {
            return true
        }

        return false
    }
}
