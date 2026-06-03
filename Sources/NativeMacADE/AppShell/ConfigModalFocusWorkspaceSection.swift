import NativeMacADECore
import SwiftUI

struct ConfigModalFocusWorkspaceSection: View {
    let store: WorkspaceStore
    let commandService: any WorkspaceCommandService

    @Environment(\.shellThemePalette) private var theme
    @State private var feedback: SettingsSectionFeedback?
    @State private var isSaving = false

    var body: some View {
        let presentation = FocusWorkspaceSettingsPresentation(preferences: store.appPreferences)

        VStack(alignment: .leading, spacing: 14) {
            if let feedback {
                SettingsSectionFeedbackView(feedback: feedback) {
                    self.feedback = nil
                }
            }

            sectionHeader()

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Toggle(isOn: focusWorkspaceBinding) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(FocusWorkspaceSettingsPresentation.toggleTitle)
                                .font(.headline)
                                .foregroundStyle(theme.primaryText.color)
                            Text(presentation.status)
                                .font(.callout)
                                .foregroundStyle(theme.secondaryText.color)
                        }
                    }
                    .toggleStyle(.switch)
                    .disabled(isSaving)
                    .accessibilityIdentifier("focus-workspace-toggle")

                    Spacer(minLength: 12)

                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 20, height: 20)
                            .accessibilityLabel("Saving Focus Workspace")
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.mutedText.color)
                        .frame(width: 18, height: 26)
                        .accessibilityHidden(true)

                    Toggle(isOn: focusWorkspaceContinuityBinding) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(FocusWorkspaceSettingsPresentation.continuityToggleTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.primaryText.color)
                            Text(presentation.continuityStatus)
                                .font(.callout)
                                .foregroundStyle(theme.secondaryText.color)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .toggleStyle(.switch)
                    .disabled(isSaving || !presentation.isContinuityAvailable)
                    .opacity(presentation.isContinuityAvailable ? 1 : 0.62)
                    .accessibilityIdentifier("focus-workspace-continuity-toggle")
                    .accessibilityHint(FocusWorkspaceSettingsPresentation.continuityHelpText)
                }

                Divider().overlay(theme.border.color.opacity(0.72))

                VStack(alignment: .leading, spacing: 10) {
                    focusWorkspaceNote(
                        systemImage: "terminal",
                        title: FocusWorkspaceSettingsPresentation.behaviorTitle,
                        detail: FocusWorkspaceSettingsPresentation.behaviorDetail
                    )
                    focusWorkspaceNote(
                        systemImage: "doc.text",
                        title: "File tabs",
                        detail: FocusWorkspaceSettingsPresentation.fileDetail
                    )
                    focusWorkspaceNote(
                        systemImage: "clock.arrow.circlepath",
                        title: FocusWorkspaceSettingsPresentation.continuityTitle,
                        detail: FocusWorkspaceSettingsPresentation.continuityHelpText
                    )
                    focusWorkspaceNote(
                        systemImage: "rectangle.stack",
                        title: FocusWorkspaceSettingsPresentation.legacyTitle,
                        detail: FocusWorkspaceSettingsPresentation.legacyDetail
                    )
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.contentBackground.color, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.border.color.opacity(0.72), lineWidth: 1)
            }
        }
        .accessibilityIdentifier("focus-workspace-settings-section")
    }

    private var focusWorkspaceBinding: Binding<Bool> {
        Binding(
            get: { store.appPreferences.focusWorkspaceEnabled },
            set: { requestedValue in
                Task { await saveFocusWorkspacePreference(enabled: requestedValue) }
            }
        )
    }

    private var focusWorkspaceContinuityBinding: Binding<Bool> {
        Binding(
            get: {
                store.appPreferences.focusWorkspaceEnabled && store.appPreferences.focusWorkspaceContinuityEnabled
            },
            set: { requestedValue in
                Task { await saveFocusWorkspaceContinuityPreference(enabled: requestedValue) }
            }
        )
    }

    private func sectionHeader() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(FocusWorkspaceSettingsPresentation.title, systemImage: "viewfinder")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.primaryText.color)
            Text(FocusWorkspaceSettingsPresentation.summary)
                .font(.callout)
                .foregroundStyle(theme.secondaryText.color)
                .fixedSize(horizontal: false, vertical: true)
            PortableSettingsScopeBadgeView(label: .focusWorkspace)
        }
    }

    private func focusWorkspaceNote(systemImage: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.accent.color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText.color)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(theme.primaryText.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func saveFocusWorkspacePreference(enabled: Bool) async {
        guard enabled != store.appPreferences.focusWorkspaceEnabled else { return }

        isSaving = true
        feedback = nil
        defer { isSaving = false }

        do {
            var preferences = try await commandService.loadAppPreferences()
            preferences.focusWorkspaceEnabled = enabled
            if !enabled {
                preferences.focusWorkspaceContinuityEnabled = false
            }
            try await commandService.saveAppPreferences(preferences)
            feedback = SettingsSectionFeedback(
                kind: .success,
                message: enabled ? "Focus Workspace enabled." : "Focus Workspace disabled. Continuity is off."
            )
        } catch {
            feedback = SettingsSectionFeedback(kind: .error, message: friendlyMessage(for: error))
        }
    }

    private func saveFocusWorkspaceContinuityPreference(enabled: Bool) async {
        let currentValue = store.appPreferences.focusWorkspaceEnabled && store.appPreferences.focusWorkspaceContinuityEnabled
        guard store.appPreferences.focusWorkspaceEnabled, enabled != currentValue else { return }

        isSaving = true
        feedback = nil
        defer { isSaving = false }

        do {
            var preferences = try await commandService.loadAppPreferences()
            guard preferences.focusWorkspaceEnabled else {
                preferences.focusWorkspaceContinuityEnabled = false
                try await commandService.saveAppPreferences(preferences)
                feedback = SettingsSectionFeedback(
                    kind: .error,
                    message: FocusWorkspaceSettingsPresentation.continuityUnavailableStatus
                )
                return
            }

            preferences.focusWorkspaceContinuityEnabled = enabled
            try await commandService.saveAppPreferences(preferences)
            feedback = SettingsSectionFeedback(
                kind: .success,
                message: enabled ? "Continuity enabled." : "Continuity disabled."
            )
        } catch {
            feedback = SettingsSectionFeedback(kind: .error, message: friendlyMessage(for: error))
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        guard error is WorkspaceCommandError else {
            return "Focus Workspace settings could not be updated."
        }
        return "Focus Workspace settings could not be updated."
    }
}
