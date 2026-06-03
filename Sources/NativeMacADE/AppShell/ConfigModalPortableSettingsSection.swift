import AppKit
import NativeMacADECore
import SwiftUI

struct ConfigModalPortableSettingsSection: View {
    let commandService: any WorkspaceCommandService

    @Environment(\.shellThemePalette) private var theme
    @State private var status = PortableSettingsApplyStatusPresentation.idle
    @State private var actionFeedback: SettingsSectionFeedback?
    @State private var isReloading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader

            if let actionFeedback {
                SettingsSectionFeedbackView(feedback: actionFeedback) {
                    self.actionFeedback = nil
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                configPathRow

                HStack(alignment: .center, spacing: 8) {
                    Button("Reveal in Finder", systemImage: "folder", action: revealPortableConfig)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Reveal portable settings file")

                    Button("Open File", systemImage: "doc.text", action: openPortableConfig)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Open portable settings file")

                    Spacer(minLength: 12)

                    Button {
                        Task { await reloadPortableConfig() }
                    } label: {
                        Label(isReloading ? "Reloading" : "Reload", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isReloading)
                    .help("Reload portable settings")
                }

                PortableSettingsApplyStatusView(status: status)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.contentBackground.color, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.border.color.opacity(0.72), lineWidth: 1)
            }
        }
        .accessibilityIdentifier("portable-settings-section")
    }

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Portable Settings", systemImage: "externaldrive.connected.to.line.below")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.primaryText.color)
            Text("Personal settings file for supported cross-machine preferences.")
                .font(.callout)
                .foregroundStyle(theme.secondaryText.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var configPathRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Config Path")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText.color)
            Text(configURL.path)
                .font(.caption.monospaced())
                .foregroundStyle(theme.primaryText.color)
                .textSelection(.enabled)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(theme.elevatedBackground.color, in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.border.color.opacity(0.6), lineWidth: 1)
                }
                .accessibilityIdentifier("portable-settings-config-path")
        }
    }

    private var configURL: URL {
        commandService.portableSettingsConfigURL()
    }

    private func revealPortableConfig() {
        actionFeedback = nil
        NSWorkspace.shared.activateFileViewerSelecting([configURL])
    }

    private func openPortableConfig() {
        actionFeedback = nil
        guard NSWorkspace.shared.open(configURL) else {
            actionFeedback = SettingsSectionFeedback(
                kind: .error,
                message: "Portable settings file could not be opened."
            )
            return
        }
    }

    private func reloadPortableConfig() async {
        isReloading = true
        actionFeedback = nil
        defer { isReloading = false }

        do {
            let result = try await commandService.reloadPortableSettingsConfig()
            status = PortableSettingsApplyStatusPresentation(result: result)
        } catch {
            status = .failure(message: "Portable settings could not be reloaded: \(String(describing: error))")
        }
    }
}

struct PortableSettingsScopeBadgeView: View {
    let label: PortableSettingsScopeLabel
    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label.kind.badgeTitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(tint.opacity(0.13), in: Capsule())
                .overlay {
                    Capsule().stroke(tint.opacity(0.4), lineWidth: 1)
                }
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 2) {
                Text(label.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText.color)
                Text(label.detail)
                    .font(.caption)
                    .foregroundStyle(theme.mutedText.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch label.kind {
        case .portableV1:
            return theme.secondaryAccent.color
        case .localOnlyV1:
            return theme.warning.color
        case .mixedV1:
            return theme.accent.color
        }
    }
}

private struct PortableSettingsApplyStatusView: View {
    let status: PortableSettingsApplyStatusPresentation
    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Last Apply Status")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText.color)
                Text(status.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Spacer(minLength: 0)
            }

            Text(status.summary)
                .font(.callout)
                .foregroundStyle(theme.primaryText.color)
                .fixedSize(horizontal: false, vertical: true)

            if !status.appliedSectionDetails.isEmpty {
                PortableSettingsStatusList(
                    title: "Applied sections",
                    details: status.appliedSectionDetails,
                    tint: theme.secondaryAccent.color
                )
            }

            if !status.rejectedSectionDetails.isEmpty {
                PortableSettingsStatusList(
                    title: "Rejected sections",
                    details: status.rejectedSectionDetails,
                    tint: theme.destructive.color
                )
            }
        }
        .padding(10)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(tint.opacity(0.38), lineWidth: 1)
        }
        .accessibilityIdentifier("portable-settings-apply-status")
    }

    private var tint: Color {
        switch status.kind {
        case .idle:
            return theme.mutedText.color
        case .success:
            return theme.secondaryAccent.color
        case .partial, .missingFile:
            return theme.warning.color
        case .failure:
            return theme.destructive.color
        }
    }
}

private struct PortableSettingsStatusList: View {
    let title: String
    let details: [String]
    let tint: Color
    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            ForEach(details, id: \.self) { detail in
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(tint)
                        .frame(width: 4, height: 4)
                        .padding(.top, 7)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
