import AppKit
import SwiftUI

/// A floating NSPanel that hosts the clipboard history picker.
/// Uses `.nonactivatingPanel` style to avoid stealing focus from the active application.
/// Dismisses automatically when it loses key status (user clicks outside).
@MainActor
final class PickerPanel: NSPanel {

    // MARK: - Constants

    private static let panelWidth: CGFloat = 320
    private static let panelHeight: CGFloat = 400
    private static let positionOffset: CGFloat = 8

    // MARK: - Initialization

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.panelHeight),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
    }

    // MARK: - Key Window

    override var canBecomeKey: Bool { true }

    override func resignKey() {
        super.resignKey()
        dismiss()
    }

    // MARK: - Public API

    /// Shows the panel near the given screen position, offset by up to 8 points.
    /// Ensures the panel remains fully visible within screen bounds.
    func show(near position: CGPoint) {
        let panelSize = NSSize(width: Self.panelWidth, height: Self.panelHeight)

        // Compute target origin (below and to the right of the position, offset by 8pt)
        var origin = NSPoint(
            x: position.x + Self.positionOffset,
            y: position.y - panelSize.height - Self.positionOffset
        )

        // Clamp to visible screen bounds
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let visibleFrame = screen.visibleFrame

            // Prevent going off the right edge
            if origin.x + panelSize.width > visibleFrame.maxX {
                origin.x = visibleFrame.maxX - panelSize.width
            }

            // Prevent going off the left edge
            if origin.x < visibleFrame.minX {
                origin.x = visibleFrame.minX
            }

            // Prevent going below the bottom edge
            if origin.y < visibleFrame.minY {
                origin.y = visibleFrame.minY
            }

            // Prevent going above the top edge
            if origin.y + panelSize.height > visibleFrame.maxY {
                origin.y = visibleFrame.maxY - panelSize.height
            }
        }

        setFrame(NSRect(origin: origin, size: panelSize), display: true)
        makeKeyAndOrderFront(nil)
    }

    /// Hides the panel and resets state.
    func dismiss() {
        orderOut(nil)
    }

    /// Sets the SwiftUI content view for the panel.
    /// Call this to provide the PickerView once it is available.
    func setContentView<V: View>(_ view: V) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.panelHeight)
        contentView = hostingView
    }
}
