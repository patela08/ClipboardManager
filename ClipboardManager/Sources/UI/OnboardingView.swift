import SwiftUI

/// Onboarding view shown on first launch when Accessibility permissions are not granted.
/// Explains why the permission is needed and provides a button to open System Settings.
///
/// Requirements: 10.1, 10.2, 10.3, 10.4
struct OnboardingView: View {

    @ObservedObject var permissionsManager: PermissionsManager

    /// Called when the onboarding window should be closed.
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // App icon / header
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text("Clipboard Manager")
                .font(.title)
                .fontWeight(.semibold)

            // Explanation text
            Text("Clipboard Manager needs Accessibility permission to detect the ⌘V+V trigger gesture for opening the clipboard picker")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Permission status indicator
            permissionStatusView

            // Action buttons
            VStack(spacing: 12) {
                Button(action: {
                    permissionsManager.openAccessibilitySettings()
                }) {
                    Label("Open System Settings", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: {
                    permissionsManager.dismissOnboarding()
                    onDismiss()
                }) {
                    Text("Continue Without Permissions")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .foregroundStyle(.secondary)
            }

            // Help text
            Text("You can grant permission later in System Settings > Privacy & Security > Accessibility")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(width: 420)
        .onAppear {
            permissionsManager.startPolling()
        }
        .onDisappear {
            permissionsManager.stopPolling()
        }
        .onChange(of: permissionsManager.isAccessibilityGranted) { _, granted in
            if granted {
                // Auto-close when permission is detected
                onDismiss()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var permissionStatusView: some View {
        if permissionsManager.isAccessibilityGranted {
            Label("Permissions Granted ✓", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.headline)
        } else {
            Label("Permission Not Granted", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.headline)
        }
    }
}
