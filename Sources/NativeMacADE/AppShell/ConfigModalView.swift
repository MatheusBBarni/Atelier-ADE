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

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ConfigModalAgentProfilesSection(
                        store: store,
                        commandService: commandService
                    )

                    Divider().overlay(theme.border.color)

                    ConfigModalAppearanceAndShortcutsSection(
                        store: store,
                        commandService: commandService
                    )
                }
                .padding(20)
            }

            Divider().overlay(theme.border.color)

            HStack {
                Spacer()
                Button("Done", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 760)
        .frame(minHeight: 620)
        .background(theme.elevatedBackground.color)
        .task {
            commandService.recordSettingsOpened(surface: "config_modal")
        }
    }
}
