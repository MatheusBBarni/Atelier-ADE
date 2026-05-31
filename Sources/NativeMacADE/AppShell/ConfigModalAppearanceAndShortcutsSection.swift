import NativeMacADECore
import SwiftUI

struct ConfigModalAppearanceAndShortcutsSection: View {
    let store: WorkspaceStore
    let commandService: any WorkspaceCommandService

    @Environment(\.shellThemePalette) private var theme
    @State private var themeDraftID = AppTheme.defaultID
    @State private var terminalFontSizeDraft = AppPreferences.defaultTerminalFontSize
    @State private var shortcutDrafts: [AppCommandID: KeybindingOverride] = [:]
    @State private var feedback: SettingsSectionFeedback?
    @State private var isSavingAppearance = false
    @State private var isSavingShortcuts = false
    @State private var isSyncingAppearanceDrafts = false
    @State private var appearanceSaveTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let feedback {
                SettingsSectionFeedbackView(feedback: feedback) {
                    self.feedback = nil
                }
            }

            appearanceSection

            Divider().overlay(theme.border.color)

            shortcutSection
        }
        .task {
            syncDraftsFromStore()
        }
        .onChange(of: store.appPreferences) { _, _ in
            syncDraftsFromStore()
        }
        .onChange(of: themeDraftID) { _, _ in
            persistAppearanceIfNeeded()
        }
        .onChange(of: terminalFontSizeDraft) { _, _ in
            persistAppearanceIfNeeded()
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Appearance",
                systemImage: "paintpalette",
                detail: "Theme updates the app shell and terminal surfaces immediately. Font size updates the app shell and file editor immediately."
            )

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Font Size")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText.color)

                    HStack(spacing: 10) {
                        TextField(
                            "13",
                            value: $terminalFontSizeDraft,
                            format: .number.precision(.fractionLength(0))
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 72)
                        .disabled(isSavingAppearance)

                        Stepper("", value: $terminalFontSizeDraft, in: 11 ... 24, step: 1)
                            .labelsHidden()
                            .disabled(isSavingAppearance)

                        Text("Applies to the app shell and file editor.")
                            .font(.caption)
                            .foregroundStyle(theme.mutedText.color)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Theme")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText.color)

                    Picker("", selection: $themeDraftID) {
                        Section("Dark") {
                            ForEach(darkThemes) { option in
                                Text(option.displayName).tag(option.id)
                            }
                        }

                        Section("Light") {
                            ForEach(lightThemes) { option in
                                Text(option.displayName).tag(option.id)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .accessibilityLabel("Theme")
                    .disabled(isSavingAppearance)
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
    }

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                sectionHeader(
                    title: "Keyboard Shortcuts",
                    systemImage: "keyboard",
                    detail: "Managed app commands for projects, sessions, tabs, terminal zoom, sidebars, files, and settings."
                )
                Spacer(minLength: 12)
                HStack(spacing: 8) {
                    Button {
                        Task { await resetAllShortcuts() }
                    } label: {
                        Label("Reset All", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isSavingShortcuts || store.appPreferences.keybindings.isEmpty)

                    Button {
                        Task { await saveShortcutDrafts() }
                    } label: {
                        Label("Save Shortcuts", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isSavingShortcuts || !hasShortcutDraftChanges)
                }
            }

            VStack(spacing: 10) {
                ForEach(AppCommandRegistry.managedCommandIDs, id: \.self) { commandID in
                    ShortcutEditorRow(
                        commandID: commandID,
                        draft: shortcutDraftBinding(for: commandID),
                        isDefault: draftKeybinding(for: commandID) == AppCommandRegistry.defaultKeybinding(for: commandID),
                        isSaving: isSavingShortcuts,
                        onReset: {
                            Task { await resetShortcut(commandID) }
                        }
                    )
                }
            }
        }
    }

    private func sectionHeader(title: String, systemImage: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.primaryText.color)
            Text(detail)
                .font(.callout)
                .foregroundStyle(theme.secondaryText.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var selectedTheme: AppTheme {
        AppTheme.resolve(id: themeDraftID)
    }

    private var darkThemes: [AppTheme] {
        AppTheme.catalog.filter { $0.colorScheme == .dark }
    }

    private var lightThemes: [AppTheme] {
        AppTheme.catalog.filter { $0.colorScheme == .light }
    }

    private var hasShortcutDraftChanges: Bool {
        AppCommandRegistry.managedCommandIDs.contains { commandID in
            draftKeybinding(for: commandID) != AppCommandRegistry.resolvedKeybinding(
                for: commandID,
                preferences: store.appPreferences
            )
        }
    }

    private func shortcutDraftBinding(for commandID: AppCommandID) -> Binding<KeybindingOverride> {
        Binding(
            get: { draftKeybinding(for: commandID) },
            set: { shortcutDrafts[commandID] = normalized($0, for: commandID) }
        )
    }

    private func draftKeybinding(for commandID: AppCommandID) -> KeybindingOverride {
        shortcutDrafts[commandID] ?? AppCommandRegistry.resolvedKeybinding(
            for: commandID,
            preferences: store.appPreferences
        )
    }

    private func syncDraftsFromStore() {
        isSyncingAppearanceDrafts = true
        themeDraftID = store.appPreferences.themeID
        terminalFontSizeDraft = store.appPreferences.terminalFontSize
        shortcutDrafts = AppCommandRegistry.managedCommandIDs.reduce(into: [:]) { drafts, commandID in
            drafts[commandID] = AppCommandRegistry.resolvedKeybinding(
                for: commandID,
                preferences: store.appPreferences
            )
        }
        isSyncingAppearanceDrafts = false
    }

    private func persistAppearanceIfNeeded() {
        guard !isSyncingAppearanceDrafts else { return }

        let roundedFontSize = min(max(terminalFontSizeDraft.rounded(), 11), 24)
        if roundedFontSize != terminalFontSizeDraft {
            terminalFontSizeDraft = roundedFontSize
            return
        }

        guard themeDraftID != store.appPreferences.themeID || roundedFontSize != store.appPreferences.terminalFontSize else {
            return
        }

        appearanceSaveTask?.cancel()
        let selectedThemeID = themeDraftID
        appearanceSaveTask = Task {
            isSavingAppearance = true
            defer { isSavingAppearance = false }

            do {
                var preferences = try await commandService.loadAppPreferences()
                preferences.themeID = selectedThemeID
                preferences.terminalFontSize = roundedFontSize
                try await commandService.saveAppPreferences(preferences)
                feedback = nil
            } catch {
                feedback = SettingsSectionFeedback(kind: .error, message: friendlyMessage(for: error))
                syncDraftsFromStore()
            }
        }
    }

    private func saveShortcutDrafts() async {
        isSavingShortcuts = true
        feedback = nil
        defer { isSavingShortcuts = false }

        do {
            var preferences = try await commandService.loadAppPreferences()
            preferences.keybindings = normalizedKeybindingOverridesFromDrafts()
            try await commandService.saveAppPreferences(preferences)
            syncDraftsFromStore()
            feedback = SettingsSectionFeedback(kind: .success, message: "Keyboard Shortcuts saved.")
        } catch {
            feedback = SettingsSectionFeedback(kind: .error, message: friendlyMessage(for: error))
        }
    }

    private func resetShortcut(_ commandID: AppCommandID) async {
        isSavingShortcuts = true
        feedback = nil
        defer { isSavingShortcuts = false }

        do {
            var preferences = try await commandService.loadAppPreferences()
            preferences.keybindings[commandID] = nil
            try await commandService.saveAppPreferences(preferences)
            syncDraftsFromStore()
            feedback = SettingsSectionFeedback(kind: .success, message: "\(commandID.displayTitle) reset.")
        } catch {
            feedback = SettingsSectionFeedback(kind: .error, message: friendlyMessage(for: error))
        }
    }

    private func resetAllShortcuts() async {
        isSavingShortcuts = true
        feedback = nil
        defer { isSavingShortcuts = false }

        do {
            var preferences = try await commandService.loadAppPreferences()
            preferences.keybindings = [:]
            try await commandService.saveAppPreferences(preferences)
            syncDraftsFromStore()
            feedback = SettingsSectionFeedback(kind: .success, message: "Keyboard Shortcuts reset.")
        } catch {
            feedback = SettingsSectionFeedback(kind: .error, message: friendlyMessage(for: error))
        }
    }

    private func normalizedKeybindingOverridesFromDrafts() -> [AppCommandID: KeybindingOverride] {
        AppCommandRegistry.managedCommandIDs.reduce(into: [:]) { overrides, commandID in
            let draft = normalized(draftKeybinding(for: commandID), for: commandID)
            if draft != AppCommandRegistry.defaultKeybinding(for: commandID) {
                overrides[commandID] = draft
            }
        }
    }

    private func normalized(_ keybinding: KeybindingOverride, for commandID: AppCommandID) -> KeybindingOverride {
        KeybindingOverride(
            commandID: commandID,
            keyEquivalent: keybinding.keyEquivalent.trimmingCharacters(in: .whitespacesAndNewlines),
            modifiers: KeyModifier.allCases.filter { keybinding.modifiers.contains($0) }
        )
    }

    private func friendlyMessage(for error: Error) -> String {
        guard let commandError = error as? WorkspaceCommandError else {
            return "Settings could not be saved."
        }

        switch commandError {
        case .settingsValidationFailed(let failure):
            switch failure {
            case .unknownThemeID:
                return "The selected theme is no longer available."
            case .unknownDefaultSessionShortcut:
                return "The selected Agent Profile is no longer available."
            case .duplicateManagedKeybinding:
                return "Two Keyboard Shortcuts use the same binding."
            case .mismatchedKeybindingCommandID, .emptyKeybinding:
                return "One Keyboard Shortcut needs a key before saving."
            case .malformedLaunchArgumentsJSON:
                return "An Agent Profile has invalid launch arguments."
            }
        case .persistenceFailed:
            return "Settings could not be saved."
        default:
            return "Settings could not be saved."
        }
    }
}

private struct ShortcutEditorRow: View {
    let commandID: AppCommandID
    @Binding var draft: KeybindingOverride
    let isDefault: Bool
    let isSaving: Bool
    let onReset: () -> Void

    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 8) {
                    Text(commandID.displayTitle)
                        .font(.headline)
                        .foregroundStyle(theme.primaryText.color)
                        .lineLimit(1)
                    ShortcutStateBadge(title: isDefault ? "Default" : "Changed", tint: isDefault ? theme.secondaryAccent.color : theme.warning.color)
                }
                Spacer(minLength: 8)
                Text(bindingPreview)
                    .font(.caption.monospaced())
                    .foregroundStyle(theme.primaryText.color)
                    .lineLimit(1)
                    .frame(minWidth: 120, alignment: .trailing)
                Button {
                    onReset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Reset Keyboard Shortcut")
                .disabled(isSaving || isDefault)
            }

            HStack(alignment: .center, spacing: 12) {
                Text(commandID.displayGroup)
                    .font(.caption)
                    .foregroundStyle(theme.mutedText.color)
                    .frame(width: 130, alignment: .leading)

                TextField("key", text: $draft.keyEquivalent)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .frame(width: 92)
                    .disabled(isSaving)

                HStack(spacing: 8) {
                    ForEach(KeyModifier.allCases, id: \.self) { modifier in
                        Toggle(modifier.displayTitle, isOn: modifierBinding(modifier))
                            .toggleStyle(.checkbox)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText.color)
                            .disabled(isSaving)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(theme.contentBackground.color, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDefault ? theme.border.color.opacity(0.68) : theme.warning.color.opacity(0.55), lineWidth: 1)
        }
    }

    private var bindingPreview: String {
        let modifiers = KeyModifier.allCases
            .filter { draft.modifiers.contains($0) }
            .map(\.displayTitle)
        return (modifiers + [draft.keyEquivalent.trimmingCharacters(in: .whitespacesAndNewlines)])
            .filter { !$0.isEmpty }
            .joined(separator: "+")
    }

    private func modifierBinding(_ modifier: KeyModifier) -> Binding<Bool> {
        Binding(
            get: { draft.modifiers.contains(modifier) },
            set: { isEnabled in
                var modifiers = KeyModifier.allCases.filter { draft.modifiers.contains($0) }
                if isEnabled, !modifiers.contains(modifier) {
                    modifiers.append(modifier)
                } else if !isEnabled {
                    modifiers.removeAll { $0 == modifier }
                }
                draft.modifiers = KeyModifier.allCases.filter { modifiers.contains($0) }
            }
        )
    }
}

private struct SettingsSectionFeedback: Equatable {
    enum Kind: Equatable {
        case success
        case error
    }

    var kind: Kind
    var message: String
}

private struct SettingsSectionFeedbackView: View {
    let feedback: SettingsSectionFeedback
    let onDismiss: () -> Void
    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: feedback.kind == .success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(feedback.message)
                .font(.callout)
                .foregroundStyle(theme.primaryText.color)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(theme.mutedText.color)
                .help("Dismiss message")
        }
        .padding(10)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(tint.opacity(0.45), lineWidth: 1)
        }
    }

    private var tint: Color {
        switch feedback.kind {
        case .success:
            return theme.secondaryAccent.color
        case .error:
            return theme.destructive.color
        }
    }
}

private struct ShortcutStateBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.13), in: Capsule())
            .overlay {
                Capsule().stroke(tint.opacity(0.4), lineWidth: 1)
            }
            .lineLimit(1)
    }
}

private extension AppCommandID {
    var displayTitle: String {
        switch self {
        case .openProjectSelector:
            return "Open Project"
        case .newPlainTab:
            return "New Plain Tab"
        case .newDefaultAgentTab:
            return "New Default Agent Tab"
        case .newAgentTabWithProfile:
            return "New Agent Tab"
        case .closeSelectedTab:
            return "Close Tab"
        case .renameSelectedSession:
            return "Rename Session"
        case .renameSelectedTab:
            return "Rename Tab"
        case .deleteSelectedSession:
            return "Delete Session"
        case .previousTab:
            return "Previous Tab"
        case .nextTab:
            return "Next Tab"
        case .previousSession:
            return "Previous Session"
        case .nextSession:
            return "Next Session"
        case .searchSessions:
            return "Search Sessions"
        case .saveFile:
            return "Save File"
        case .revertFile:
            return "Revert File"
        case .openFileInExternalEditor:
            return "Open File in External Editor"
        case .zoomInTerminal:
            return "Zoom In Terminal"
        case .zoomOutTerminal:
            return "Zoom Out Terminal"
        case .toggleLeftSidebar:
            return "Toggle Left Sidebar"
        case .toggleRightSidebar:
            return "Toggle Right Sidebar"
        case .openSettings:
            return "Open Settings"
        }
    }

    var displayGroup: String {
        switch self {
        case .openProjectSelector:
            return "Projects"
        case .newPlainTab, .newDefaultAgentTab, .newAgentTabWithProfile, .closeSelectedTab, .renameSelectedTab:
            return "Tab actions"
        case .previousTab, .nextTab:
            return "Tab navigation"
        case .previousSession, .nextSession:
            return "Session navigation"
        case .searchSessions, .renameSelectedSession, .deleteSelectedSession:
            return "Sessions"
        case .saveFile, .revertFile, .openFileInExternalEditor:
            return "File commands"
        case .zoomInTerminal, .zoomOutTerminal:
            return "Terminal"
        case .toggleLeftSidebar, .toggleRightSidebar:
            return "Sidebar"
        case .openSettings:
            return "Settings"
        }
    }
}

private extension KeyModifier {
    var displayTitle: String {
        switch self {
        case .command:
            return "Cmd"
        case .shift:
            return "Shift"
        case .option:
            return "Option"
        case .control:
            return "Control"
        }
    }
}
