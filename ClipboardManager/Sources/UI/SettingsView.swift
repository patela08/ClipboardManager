import AppKit
import SwiftUI

/// The settings window view providing controls for all user-configurable preferences.
/// Changes are applied immediately through the SettingsManager without requiring restart.
@MainActor
struct SettingsView: View {

    // MARK: - Properties

    @ObservedObject var settingsManager: SettingsManager
    var onUninstall: () -> Void

    // MARK: - State

    @State private var isRecordingShortcut: Bool = false
    @State private var shortcutErrorMessage: String?

    // MARK: - Constants

    /// System-reserved shortcuts that cannot be assigned as trigger gesture.
    private static let reservedShortcuts: Set<ReservedShortcut> = [
        ReservedShortcut(modifiers: .command, keyCode: 0x0C), // ⌘Q
        ReservedShortcut(modifiers: .command, keyCode: 0x0D), // ⌘W
        ReservedShortcut(modifiers: .command, keyCode: 0x04), // ⌘H
        ReservedShortcut(modifiers: .command, keyCode: 0x2E), // ⌘M
        ReservedShortcut(modifiers: .command, keyCode: 0x30), // ⌘Tab
    ]

    // MARK: - Body

    var body: some View {
        Form {
            generalSection
            contentTypesSection
            excludedAppsSection
            triggerGestureSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 450, minHeight: 500)
        .padding()
    }

    // MARK: - General Section

    private var generalSection: some View {
        Section("General") {
            historySizeSetting
            themeSetting
            autoStartSetting
        }
    }

    private var historySizeSetting: some View {
        HStack {
            Text("History size:")
            TextField(
                "",
                value: Binding(
                    get: { settingsManager.settings.historySize },
                    set: { settingsManager.updateHistorySize($0) }
                ),
                format: .number
            )
            .frame(width: 60)
            .textFieldStyle(.roundedBorder)

            Stepper(
                "",
                value: Binding(
                    get: { settingsManager.settings.historySize },
                    set: { settingsManager.updateHistorySize($0) }
                ),
                in: AppSettings.historySizeRange
            )
            .labelsHidden()

            Text("(1–150)")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }

    private var themeSetting: some View {
        Picker("Theme:", selection: Binding(
            get: { settingsManager.settings.theme },
            set: { settingsManager.updateTheme($0) }
        )) {
            Text("Light").tag(ThemePreference.light)
            Text("Dark").tag(ThemePreference.dark)
            Text("System").tag(ThemePreference.system)
        }
        .pickerStyle(.segmented)
    }

    private var autoStartSetting: some View {
        Toggle("Launch at login", isOn: Binding(
            get: { settingsManager.settings.autoStartAtLogin },
            set: { settingsManager.updateAutoStart($0) }
        ))
    }

    // MARK: - Content Types Section

    private var contentTypesSection: some View {
        Section("Content Types") {
            Toggle("Plain text", isOn: .constant(true))
                .disabled(true)

            Toggle("Rich text", isOn: Binding(
                get: { settingsManager.settings.captureContentTypes.richText },
                set: { newValue in
                    var types = settingsManager.settings.captureContentTypes
                    types.richText = newValue
                    settingsManager.updateContentTypes(types)
                }
            ))

            Toggle("Images", isOn: Binding(
                get: { settingsManager.settings.captureContentTypes.images },
                set: { newValue in
                    var types = settingsManager.settings.captureContentTypes
                    types.images = newValue
                    settingsManager.updateContentTypes(types)
                }
            ))

            Toggle("Files", isOn: Binding(
                get: { settingsManager.settings.captureContentTypes.files },
                set: { newValue in
                    var types = settingsManager.settings.captureContentTypes
                    types.files = newValue
                    settingsManager.updateContentTypes(types)
                }
            ))
        }
    }

    // MARK: - Excluded Apps Section

    private var excludedAppsSection: some View {
        Section("Excluded Apps") {
            if settingsManager.settings.excludedApps.isEmpty {
                Text("No excluded apps")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(settingsManager.settings.excludedApps, id: \.self) { bundleId in
                    HStack {
                        Text(bundleId)
                            .font(.system(size: 12, design: .monospaced))
                        Spacer()
                        Button(role: .destructive) {
                            settingsManager.removeExcludedApp(bundleId)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button("Add App…") {
                addExcludedApp()
            }
        }
    }

    // MARK: - Trigger Gesture Section

    private var triggerGestureSection: some View {
        Section("Trigger Gesture") {
            HStack {
                Text("Current shortcut:")
                Text(shortcutDisplayString(for: settingsManager.settings.triggerGesture))
                    .font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.05))
                    )
            }

            if isRecordingShortcut {
                HStack {
                    Text("Press a key combination…")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Spacer()
                    Button("Cancel") {
                        isRecordingShortcut = false
                        shortcutErrorMessage = nil
                    }
                }
                .background(
                    ShortcutRecorderView { gesture in
                        handleRecordedShortcut(gesture)
                    }
                    .frame(width: 0, height: 0)
                )
            } else {
                Button("Record Shortcut") {
                    shortcutErrorMessage = nil
                    isRecordingShortcut = true
                }
            }

            if let errorMessage = shortcutErrorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("ClipboardManager")
                    .font(.headline)
                Spacer()
                Text("Version \(appVersion)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Button(role: .destructive) {
                settingsManager.resetToDefaults()
            } label: {
                Text("Reset All Settings to Defaults")
            }

            Button(role: .destructive) {
                onUninstall()
            } label: {
                Text("Uninstall ClipboardManager...")
            }
        }
    }

    // MARK: - Helpers

    /// App version string from the bundle, falling back to "1.0.0".
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Formats a KeyGesture into a human-readable shortcut string (e.g., "⌘V").
    private func shortcutDisplayString(for gesture: KeyGesture) -> String {
        var parts: [String] = []
        let mods = gesture.modifiers

        if mods.contains(.control) { parts.append("⌃") }
        if mods.contains(.option) { parts.append("⌥") }
        if mods.contains(.shift) { parts.append("⇧") }
        if mods.contains(.command) { parts.append("⌘") }

        parts.append(keyCodeToString(gesture.keyCode))
        return parts.joined()
    }

    /// Converts a virtual key code to a displayable key name.
    private func keyCodeToString(_ keyCode: UInt16) -> String {
        // Common key codes mapped to display strings.
        let keyMap: [UInt16: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0A: "§", 0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E",
            0x0F: "R", 0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2",
            0x14: "3", 0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=",
            0x19: "9", 0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0",
            0x1E: "]", 0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I",
            0x23: "P", 0x24: "↩", 0x25: "L", 0x26: "J", 0x27: "'",
            0x28: "K", 0x29: ";", 0x2A: "\\", 0x2B: ",", 0x2C: "/",
            0x2D: "N", 0x2E: "M", 0x2F: ".", 0x30: "⇥", 0x31: "Space",
            0x33: "⌫", 0x35: "⎋", 0x7A: "F1", 0x78: "F2", 0x63: "F3",
            0x76: "F4", 0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
            0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        ]
        return keyMap[keyCode] ?? "Key(\(keyCode))"
    }

    /// Opens a file panel to select .app bundles, extracting their bundle identifiers.
    private func addExcludedApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Select Application to Exclude"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        if let bundle = Bundle(url: url),
           let bundleId = bundle.bundleIdentifier {
            settingsManager.addExcludedApp(bundleId)
        }
    }

    /// Validates and applies a recorded shortcut.
    private func handleRecordedShortcut(_ gesture: KeyGesture) {
        isRecordingShortcut = false

        // Validate: must have at least one modifier key.
        guard !gesture.modifiers.isEmpty else {
            shortcutErrorMessage = "Shortcut must include at least one modifier key (⌘, ⌥, ⌃, ⇧)."
            return
        }

        // Check against system-reserved shortcuts.
        if isReservedShortcut(gesture) {
            shortcutErrorMessage = "This shortcut is reserved by the system and cannot be used."
            return
        }

        shortcutErrorMessage = nil
        settingsManager.updateTriggerGesture(gesture)
    }

    /// Checks if a gesture conflicts with system-reserved shortcuts.
    private func isReservedShortcut(_ gesture: KeyGesture) -> Bool {
        let normalized = gesture.modifiers.intersection(
            [.command, .option, .shift, .control]
        )
        return Self.reservedShortcuts.contains(
            ReservedShortcut(modifiers: normalized, keyCode: gesture.keyCode)
        )
    }
}

// MARK: - Reserved Shortcut Type

/// A simple value type for storing reserved shortcut definitions.
private struct ReservedShortcut: Hashable {
    let modifiers: NSEvent.ModifierFlags
    let keyCode: UInt16

    func hash(into hasher: inout Hasher) {
        hasher.combine(modifiers.rawValue)
        hasher.combine(keyCode)
    }

    static func == (lhs: ReservedShortcut, rhs: ReservedShortcut) -> Bool {
        lhs.modifiers == rhs.modifiers && lhs.keyCode == rhs.keyCode
    }
}

// MARK: - Shortcut Recorder View

/// An NSViewRepresentable that captures the next key combination for shortcut recording.
/// When a key-down event with at least one modifier + one non-modifier key is detected,
/// it calls the completion handler with the resulting KeyGesture.
private struct ShortcutRecorderView: NSViewRepresentable {

    let onShortcutRecorded: @MainActor (KeyGesture) -> Void

    func makeNSView(context: Context) -> ShortcutCaptureView {
        let view = ShortcutCaptureView()
        view.onShortcutRecorded = onShortcutRecorded
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureView, context: Context) {
        nsView.onShortcutRecorded = onShortcutRecorded
    }
}

/// An NSView subclass that intercepts key events for shortcut recording.
@MainActor
private final class ShortcutCaptureView: NSView {

    var onShortcutRecorded: (@MainActor (KeyGesture) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(
            [.command, .option, .shift, .control]
        )

        // Must have at least one modifier and a non-modifier key.
        guard !modifiers.isEmpty else { return }

        let gesture = KeyGesture(modifiers: modifiers, keyCode: event.keyCode)
        onShortcutRecorded?(gesture)
    }
}
