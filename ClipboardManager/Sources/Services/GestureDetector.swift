import AppKit
import ApplicationServices
import os

/// Intercepts system-wide key events via CGEvent tap to detect the trigger gesture.
///
/// Supports two modes:
/// 1. **Default (⌘V+V)**: Two-stroke gesture — press ⌘V (pastes normally), then V within 1s opens picker.
/// 2. **Custom shortcut**: Single keypress (e.g., ⌥⌘V) directly opens the picker.
///
/// The mode is determined by the configured `KeyGesture` in settings.
/// If the gesture matches the default (⌘V, keyCode 0x09), uses two-stroke mode.
/// Otherwise, uses single-press mode for the configured shortcut.
final class GestureDetector: GestureDetecting, @unchecked Sendable {

    // MARK: - State Machine (for two-stroke mode)

    private enum State {
        case idle
        case waitingForV
    }

    // MARK: - Properties

    private(set) var isEnabled: Bool = false

    private let onTrigger: (CGPoint) -> Void
    private let settingsManager: SettingsManaging
    private let triggerWindow: TimeInterval = 1.0

    private var state: State = .idle
    private var lastCmdVTime: Date?
    private var timeoutWorkItem: DispatchWorkItem?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var retryCount: Int = 0
    private static let maxRetries = 3
    private static let retryDelay: TimeInterval = 5.0

    /// V key virtual keycode.
    private static let vKeyCode: UInt16 = 0x09

    private let logger = Logger(subsystem: "com.clipboardmanager", category: "GestureDetector")

    // MARK: - Initialization

    init(settingsManager: SettingsManaging, onTrigger: @escaping (CGPoint) -> Void) {
        self.settingsManager = settingsManager
        self.onTrigger = onTrigger
    }

    // MARK: - Computed Properties

    /// Whether the current gesture is the default two-stroke ⌘V+V.
    private var isDefaultGesture: Bool {
        let gesture = settingsManager.settings.triggerGesture
        return gesture == KeyGesture.default
    }

    /// The configured trigger gesture from settings.
    private var configuredGesture: KeyGesture {
        return settingsManager.settings.triggerGesture
    }

    // MARK: - GestureDetecting

    func startListening() {
        guard !isEnabled else { return }

        // Check Accessibility permission
        guard AXIsProcessTrusted() else {
            logger.warning("Accessibility permission not granted. Gesture detection disabled.")
            return
        }

        if createEventTap() {
            isEnabled = true
            retryCount = 0
            logger.info("Gesture detection started (default gesture: \(self.isDefaultGesture))")
        } else {
            scheduleRetry()
        }
    }

    func stopListening() {
        guard isEnabled else { return }
        disableEventTap()
        resetState()
        isEnabled = false
        logger.info("Gesture detection stopped")
    }

    // MARK: - Event Tap Setup

    private func createEventTap() -> Bool {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let eventsOfInterest = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)
        )

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventsOfInterest,
            callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard let userInfo else {
                    return Unmanaged.passUnretained(event)
                }

                let detector = Unmanaged<GestureDetector>.fromOpaque(userInfo).takeUnretainedValue()

                // Handle tap being disabled by the system
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = detector.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

                if type == .keyDown {
                    return detector.handleKeyDown(event)
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            logger.error("Failed to create CGEvent tap")
            return false
        }

        eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        return true
    }

    private func disableEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        if let tap = eventTap {
            CFMachPortInvalidate(tap)
        }

        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Retry Logic

    private func scheduleRetry() {
        retryCount += 1
        guard retryCount <= Self.maxRetries else {
            logger.error("Failed to create event tap after \(Self.maxRetries) retries")
            return
        }

        logger.info("Retrying event tap creation (attempt \(self.retryCount)/\(Self.maxRetries)) in \(Self.retryDelay)s")

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryDelay) { [weak self] in
            guard let self else { return }
            guard !self.isEnabled else { return }

            if self.createEventTap() {
                self.isEnabled = true
                self.retryCount = 0
                self.logger.info("Gesture detection started after retry")
            } else {
                self.scheduleRetry()
            }
        }
    }

    // MARK: - Key Event Handling

    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        if isDefaultGesture {
            return handleTwoStrokeMode(keyCode: keyCode, flags: flags, event: event)
        } else {
            return handleSinglePressMode(keyCode: keyCode, flags: flags, event: event)
        }
    }

    // MARK: - Single Press Mode (custom shortcut)

    /// In single-press mode, detect the exact configured key combination and open the picker.
    private func handleSinglePressMode(keyCode: UInt16, flags: CGEventFlags, event: CGEvent) -> Unmanaged<CGEvent>? {
        let gesture = configuredGesture

        // Check if this keypress matches the configured gesture
        guard keyCode == gesture.keyCode else {
            return Unmanaged.passUnretained(event)
        }

        // Check modifiers — compare the relevant modifier bits
        let requiredModifiers = gesture.modifiers
        let eventModifiers = NSEvent.ModifierFlags(rawValue: UInt(flags.rawValue))

        let relevantMask: NSEvent.ModifierFlags = [.command, .option, .shift, .control]
        let eventRelevant = eventModifiers.intersection(relevantMask)
        let requiredRelevant = requiredModifiers.intersection(relevantMask)

        guard eventRelevant == requiredRelevant else {
            return Unmanaged.passUnretained(event)
        }

        // Gesture matched — trigger the picker
        let position = getCursorPosition()

        DispatchQueue.main.async { [weak self] in
            self?.onTrigger(position)
        }

        // Consume the keystroke
        return nil
    }

    // MARK: - Two-Stroke Mode (default ⌘V+V)

    private func handleTwoStrokeMode(keyCode: UInt16, flags: CGEventFlags, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Check for ⌘V (Command + V key)
        if keyCode == Self.vKeyCode && flags.contains(.maskCommand) {
            return handleCmdV(event)
        }

        // Check for V key while in waitingForV state (with or without ⌘ still held)
        if keyCode == Self.vKeyCode && state == .waitingForV {
            return handleSecondV(event)
        }

        // Any other key resets the state if we're waiting
        if state == .waitingForV {
            resetState()
        }

        return Unmanaged.passUnretained(event)
    }

    /// Handle ⌘V: pass through immediately, record timestamp, transition to waitingForV.
    private func handleCmdV(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        lastCmdVTime = Date()
        state = .waitingForV

        startTimeout()

        // Pass ⌘V through to the system for normal paste
        return Unmanaged.passUnretained(event)
    }

    /// Handle the second V press while in waitingForV state.
    private func handleSecondV(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let cmdVTime = lastCmdVTime else {
            resetState()
            return Unmanaged.passUnretained(event)
        }

        let elapsed = Date().timeIntervalSince(cmdVTime)

        if elapsed < triggerWindow {
            // Within the timing window — trigger the gesture
            cancelTimeout()

            let position = getCursorPosition()
            state = .idle
            lastCmdVTime = nil

            DispatchQueue.main.async { [weak self] in
                self?.onTrigger(position)
            }

            // Consume the V keystroke
            return nil
        } else {
            // Outside the timing window — reset and pass through
            resetState()
            return Unmanaged.passUnretained(event)
        }
    }

    // MARK: - Timer Management

    private func startTimeout() {
        cancelTimeout()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.resetState()
        }

        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + triggerWindow, execute: workItem)
    }

    private func cancelTimeout() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
    }

    // MARK: - State Reset

    private func resetState() {
        state = .idle
        lastCmdVTime = nil
        cancelTimeout()
    }

    // MARK: - Cursor Position

    private func getCursorPosition() -> CGPoint {
        if let caretPosition = getCaretPosition() {
            return caretPosition
        }
        return getMousePosition()
    }

    private func getCaretPosition() -> CGPoint? {
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(focusedApp.processIdentifier)

        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusResult == .success, let element = focusedElement else {
            return nil
        }

        var selectedRangeValue: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeValue
        )

        guard rangeResult == .success, let rangeValue = selectedRangeValue else {
            return nil
        }

        var boundsValue: AnyObject?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            element as! AXUIElement,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsValue
        )

        guard boundsResult == .success, let bounds = boundsValue else {
            return nil
        }

        var rect = CGRect.zero
        if AXValueGetValue(bounds as! AXValue, .cgRect, &rect) {
            return CGPoint(x: rect.origin.x, y: rect.origin.y + rect.size.height)
        }

        return nil
    }

    private func getMousePosition() -> CGPoint {
        return NSEvent.mouseLocation
    }
}
