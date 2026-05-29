import NativeMacADECore
import SwiftUI

struct ConfigModalView: View {
    let store: WorkspaceStore
    let commandService: any WorkspaceCommandService
    let onDismiss: () -> Void
    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Label("Settings", systemImage: "gearshape.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.primaryText.color)
                Spacer()
                Button("Close", systemImage: "xmark", action: onDismiss)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(theme.secondaryText.color)
                    .keyboardShortcut(.cancelAction)
                    .help("Close settings")
            }
            .padding(20)

            Divider().overlay(theme.border.color)

            VStack(alignment: .leading, spacing: 14) {
                ConfigSummaryRow(
                    systemImage: "person.2",
                    title: "Agent Profiles",
                    value: store.appPreferences.defaultSessionShortcutID == nil ? "Plain session" : "Saved default"
                )
                ConfigSummaryRow(
                    systemImage: "paintpalette",
                    title: "Appearance",
                    value: store.activeTheme.displayName
                )
                ConfigSummaryRow(
                    systemImage: "keyboard",
                    title: "Shortcuts",
                    value: "\(AppCommandRegistry.resolvedKeybindings(for: store.appPreferences).count) managed"
                )
            }
            .padding(20)

            Divider().overlay(theme.border.color)

            HStack {
                Spacer()
                Button("Done", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 560)
        .background(theme.elevatedBackground.color)
    }
}

private struct ConfigSummaryRow: View {
    let systemImage: String
    let title: String
    let value: String
    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(theme.accent.color)
                .frame(width: 24)

            Text(title)
                .font(.headline)
                .foregroundStyle(theme.primaryText.color)

            Spacer(minLength: 12)

            Text(value)
                .font(.callout)
                .foregroundStyle(theme.secondaryText.color)
        }
        .padding(.vertical, 4)
    }
}
