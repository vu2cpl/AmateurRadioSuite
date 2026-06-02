import SwiftUI
import RadioPluginUI

/// First-run welcome. Shown once (gated by `suite.didOnboard`); re-openable from Settings.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.radioTheme) private var theme

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 52)).foregroundStyle(theme.accent)
            Text("Amateur Radio Suite").font(.title.weight(.semibold))
            Text("One window for your radio control apps. Each appears as a plugin you can switch between.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                row("sidebar.left", "Switch layout", "Toggle sidebar ⇄ tabs from the toolbar.")
                row("puzzlepiece.extension", "Manage plugins", "Enable, browse, and install plugins.")
                row("command", "Command palette", "Press ⌘⇧P to jump to a plugin or run a command.")
            }
            .padding().background(theme.surface, in: RoundedRectangle(cornerRadius: theme.cornerRadius))

            Button("Get Started") { dismiss() }
                .buttonStyle(.borderedProminent).tint(theme.accent).keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(width: 460)
    }

    private func row(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).frame(width: 24).foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}
