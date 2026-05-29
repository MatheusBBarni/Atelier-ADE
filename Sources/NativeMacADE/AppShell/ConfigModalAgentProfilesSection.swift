import Foundation
import NativeMacADECore
import SwiftUI

struct ConfigModalAgentProfilesSection: View {
    let store: WorkspaceStore
    let commandService: any WorkspaceCommandService

    @Environment(\.shellThemePalette) private var theme
    @State private var profiles: [SessionShortcut] = []
    @State private var isLoading = false
    @State private var isMutating = false
    @State private var feedback: AgentProfileFeedback?
    @State private var editorDraft: AgentProfileEditorDraft?
    @State private var pendingDelete: SessionShortcut?
    @State private var pendingReset: SessionShortcut?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if let feedback {
                AgentProfileFeedbackView(feedback: feedback)
            }

            defaultSelector

            if let currentDraft = editorDraft {
                AgentProfileEditorView(
                    draft: Binding(
                        get: { editorDraft ?? currentDraft },
                        set: { editorDraft = $0 }
                    ),
                    isSaving: isMutating,
                    onCancel: { editorDraft = nil },
                    onSave: {
                        Task { await saveEditorDraft() }
                    }
                )
            }

            profileListHeader

            if isLoading, profiles.isEmpty {
                ProgressView("Loading Agent Profiles…")
                    .foregroundStyle(theme.secondaryText.color)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                VStack(spacing: 10) {
                    ForEach(rowStates) { row in
                        AgentProfileRowView(
                            row: row,
                            isBusy: isMutating,
                            onMakeDefault: {
                                Task { await saveDefaultSelection(row.profile.id.uuidString) }
                            },
                            onEdit: {
                                editorDraft = AgentProfileEditorDraft(profile: row.profile, isDefault: row.isDefault)
                                feedback = nil
                            },
                            onReset: {
                                pendingReset = row.profile
                            },
                            onDelete: {
                                pendingDelete = row.profile
                            }
                        )
                    }
                }
            }
        }
        .task {
            await refreshProfiles(showLoading: true)
        }
        .confirmationDialog(
            "Delete Agent Profile?",
            isPresented: deleteDialogPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Agent Profile", role: .destructive) {
                guard let pendingDelete else { return }
                Task { await deleteProfile(pendingDelete) }
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            if pendingDelete?.id == store.appPreferences.defaultSessionShortcutID {
                Text("Deleting this custom Agent Profile clears the saved default. New sessions will start with Plain Shell.")
            } else {
                Text("This removes the custom Agent Profile from future session choices.")
            }
        }
        .confirmationDialog(
            "Reset Built-In Agent Profile?",
            isPresented: resetDialogPresented,
            titleVisibility: .visible
        ) {
            Button("Reset Agent Profile") {
                guard let pendingReset else { return }
                Task { await resetProfile(pendingReset) }
            }
            Button("Cancel", role: .cancel) { pendingReset = nil }
        } message: {
            Text("The shipped command and arguments will be restored. Existing sessions and restored tabs keep their saved launch behavior.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Agent Profiles", systemImage: "person.crop.circle.badge.gearshape")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.primaryText.color)
            Text("Choose the default for new sessions, edit curated profiles, and add custom launch profiles.")
                .font(.callout)
                .foregroundStyle(theme.secondaryText.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var defaultSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default Agent Profile")
                .font(.headline)
                .foregroundStyle(theme.primaryText.color)

            Picker("Default Agent Profile", selection: defaultSelection) {
                Label("Plain Shell", systemImage: "terminal")
                    .tag(plainDefaultSelectionID)

                ForEach(profiles) { profile in
                    Text(profile.label)
                        .tag(profile.id.uuidString)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .disabled(isLoading || isMutating)
            .frame(maxWidth: 360, alignment: .leading)

            Text(defaultDescription)
                .font(.caption)
                .foregroundStyle(theme.mutedText.color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.contentBackground.color, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.border.color.opacity(0.72), lineWidth: 1)
        }
    }

    private var profileListHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Profiles")
                    .font(.headline)
                    .foregroundStyle(theme.primaryText.color)
                Text("\(profiles.count) available")
                    .font(.caption)
                    .foregroundStyle(theme.mutedText.color)
            }
            Spacer()
            Button {
                editorDraft = AgentProfileEditorDraft()
                feedback = nil
            } label: {
                Label("Add Agent Profile", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isMutating)
        }
    }

    private var rowStates: [AgentProfileRowState] {
        AgentProfileSectionState.rows(
            for: profiles,
            defaultSessionShortcutID: store.appPreferences.defaultSessionShortcutID
        )
    }

    private var defaultSelection: Binding<String> {
        Binding(
            get: { currentDefaultSelectionID },
            set: { newValue in
                Task { await saveDefaultSelection(newValue) }
            }
        )
    }

    private var currentDefaultSelectionID: String {
        guard let defaultProfileID = store.appPreferences.defaultSessionShortcutID,
              profiles.contains(where: { $0.id == defaultProfileID })
        else {
            return plainDefaultSelectionID
        }

        return defaultProfileID.uuidString
    }

    private var defaultDescription: String {
        guard let defaultProfileID = store.appPreferences.defaultSessionShortcutID,
              let profile = profiles.first(where: { $0.id == defaultProfileID })
        else {
            return "New sessions start with a plain shell unless you choose a profile here."
        }

        return "New sessions start with \(profile.label). Existing sessions are unchanged."
    }

    private var deleteDialogPresented: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )
    }

    private var resetDialogPresented: Binding<Bool> {
        Binding(
            get: { pendingReset != nil },
            set: { if !$0 { pendingReset = nil } }
        )
    }

    private func refreshProfiles(showLoading: Bool) async {
        if showLoading {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            let loadedProfiles = try await commandService.availableSessionShortcuts()
            if let staleDefaultID = AgentProfileSectionState.staleDefaultID(
                in: store.appPreferences,
                profiles: loadedProfiles
            ) {
                feedback = AgentProfileFeedback(
                    kind: .warning,
                    message: "The saved default Agent Profile is no longer available, so new sessions will start with Plain Shell."
                )
                if store.appPreferences.defaultSessionShortcutID == staleDefaultID {
                    _ = try await commandService.loadAppPreferences()
                }
            }
            profiles = loadedProfiles
        } catch {
            feedback = AgentProfileFeedback(kind: .error, message: friendlyMessage(for: error))
        }
    }

    private func saveDefaultSelection(_ selection: String) async {
        guard selection != currentDefaultSelectionID else { return }
        isMutating = true
        feedback = nil
        defer { isMutating = false }

        do {
            var preferences = try await commandService.loadAppPreferences()
            if selection == plainDefaultSelectionID {
                preferences.defaultSessionShortcutID = nil
            } else if let profileID = UUID(uuidString: selection),
                      profiles.contains(where: { $0.id == profileID }) {
                preferences.defaultSessionShortcutID = profileID
            } else {
                feedback = AgentProfileFeedback(
                    kind: .error,
                    message: "That Agent Profile is no longer available. The list has been refreshed."
                )
                await refreshProfiles(showLoading: false)
                return
            }

            try await commandService.saveAppPreferences(preferences)
            feedback = AgentProfileFeedback(kind: .success, message: "Default Agent Profile updated.")
            await refreshProfiles(showLoading: false)
        } catch {
            feedback = AgentProfileFeedback(kind: .error, message: friendlyMessage(for: error))
            await refreshProfiles(showLoading: false)
        }
    }

    private func saveEditorDraft() async {
        guard let draft = editorDraft else { return }
        if let validationMessage = draft.validationMessage {
            feedback = AgentProfileFeedback(kind: .error, message: validationMessage)
            return
        }

        isMutating = true
        feedback = nil
        defer { isMutating = false }

        do {
            let savedProfile = try await commandService.saveSessionShortcut(draft.sessionShortcut)
            var preferences = try await commandService.loadAppPreferences()
            let shouldUpdateDefault = draft.makeDefault || preferences.defaultSessionShortcutID == savedProfile.id

            if shouldUpdateDefault {
                preferences.defaultSessionShortcutID = draft.makeDefault ? savedProfile.id : nil
                try await commandService.saveAppPreferences(preferences)
            }

            editorDraft = nil
            feedback = AgentProfileFeedback(kind: .success, message: "\(savedProfile.label) saved.")
            await refreshProfiles(showLoading: false)
        } catch {
            feedback = AgentProfileFeedback(kind: .error, message: friendlyMessage(for: error))
            await refreshProfiles(showLoading: false)
        }
    }

    private func resetProfile(_ profile: SessionShortcut) async {
        pendingReset = nil
        isMutating = true
        feedback = nil
        defer { isMutating = false }

        do {
            let resetProfile = try await commandService.resetBuiltInSessionShortcut(id: profile.id)
            feedback = AgentProfileFeedback(kind: .success, message: "\(resetProfile.label) reset to the built-in profile.")
            await refreshProfiles(showLoading: false)
        } catch {
            feedback = AgentProfileFeedback(kind: .error, message: friendlyMessage(for: error))
            await refreshProfiles(showLoading: false)
        }
    }

    private func deleteProfile(_ profile: SessionShortcut) async {
        pendingDelete = nil
        isMutating = true
        feedback = nil
        defer { isMutating = false }

        do {
            try await commandService.deleteSessionShortcut(id: profile.id)
            feedback = AgentProfileFeedback(kind: .success, message: "\(profile.label) deleted.")
            if editorDraft?.id == profile.id {
                editorDraft = nil
            }
            await refreshProfiles(showLoading: false)
        } catch {
            feedback = AgentProfileFeedback(kind: .error, message: friendlyMessage(for: error))
            await refreshProfiles(showLoading: false)
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        guard let commandError = error as? WorkspaceCommandError else {
            return "The Agent Profile change could not be saved."
        }

        switch commandError {
        case .settingsValidationFailed(let failure):
            switch failure {
            case .malformedLaunchArgumentsJSON:
                return "Launch arguments must be a valid JSON array of strings."
            case .unknownDefaultSessionShortcut:
                return "The selected Agent Profile is no longer available. Choose another default or Plain Shell."
            case .unknownThemeID:
                return "Settings could not be saved because the current theme is no longer available."
            case .duplicateManagedKeybinding, .mismatchedKeybindingCommandID, .emptyKeybinding:
                return "Settings could not be saved because a keyboard binding needs attention."
            }
        case .missingShortcut:
            return "That Agent Profile is no longer available. The list has been refreshed."
        case .builtInShortcutDeletionRejected:
            return "Built-in Agent Profiles cannot be deleted. Use Reset to restore the shipped values."
        case .customShortcutResetRejected:
            return "Custom Agent Profiles do not have built-in values to reset."
        case .persistenceFailed:
            return "The Agent Profile change could not be saved."
        default:
            return "The Agent Profile change could not be saved."
        }
    }
}

private let plainDefaultSelectionID = "__plain_shell__"

private struct AgentProfileFeedback: Equatable {
    enum Kind: Equatable {
        case success
        case warning
        case error
    }

    var kind: Kind
    var message: String
}

private struct AgentProfileFeedbackView: View {
    let feedback: AgentProfileFeedback
    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(feedback.message)
                .font(.callout)
                .foregroundStyle(theme.primaryText.color)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(tint.opacity(0.45), lineWidth: 1)
        }
    }

    private var systemImage: String {
        switch feedback.kind {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch feedback.kind {
        case .success:
            return theme.secondaryAccent.color
        case .warning:
            return theme.warning.color
        case .error:
            return theme.destructive.color
        }
    }
}

private struct AgentProfileRowView: View {
    let row: AgentProfileRowState
    let isBusy: Bool
    let onMakeDefault: () -> Void
    let onEdit: () -> Void
    let onReset: () -> Void
    let onDelete: () -> Void

    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: row.profile.isBuiltIn ? "sparkles" : "terminal")
                .font(.title3)
                .foregroundStyle(row.profile.isBuiltIn ? theme.accent.color : theme.secondaryAccent.color)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.profile.label)
                        .font(.headline)
                        .foregroundStyle(theme.primaryText.color)
                        .lineLimit(1)
                    AgentProfileBadge(title: row.provenance.title, tint: provenanceTint)
                    if row.isDefault {
                        AgentProfileBadge(title: "Default", tint: theme.accent.color)
                    }
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.profile.launchCommand)
                        .font(.callout.monospaced())
                        .foregroundStyle(theme.primaryText.color)
                        .lineLimit(1)
                    if let launchArgumentsJSON = row.profile.launchArgumentsJSON, !launchArgumentsJSON.isEmpty {
                        Text(launchArgumentsJSON)
                            .font(.caption.monospaced())
                            .foregroundStyle(theme.mutedText.color)
                            .lineLimit(2)
                    }
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 6) {
                if row.canMakeDefault {
                    Button(action: onMakeDefault) {
                        Label("Make Default", systemImage: "star")
                    }
                    .help("Use as the default Agent Profile")
                }

                Button(action: onEdit) {
                    Label("Edit Agent Profile", systemImage: "pencil")
                        .labelStyle(.iconOnly)
                }
                .help("Edit Agent Profile")

                if row.canReset {
                    Button(action: onReset) {
                        Label("Reset Agent Profile", systemImage: "arrow.counterclockwise")
                            .labelStyle(.iconOnly)
                    }
                    .help("Reset built-in Agent Profile")
                }

                if row.canDelete {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete Agent Profile", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .help("Delete custom Agent Profile")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isBusy)
        }
        .padding(12)
        .background(theme.contentBackground.color, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(row.isDefault ? theme.activeBorder.color.opacity(0.85) : theme.border.color.opacity(0.68), lineWidth: 1)
        }
    }

    private var provenanceTint: Color {
        switch row.provenance {
        case .builtIn:
            return theme.secondaryAccent.color
        case .customizedBuiltIn:
            return theme.warning.color
        case .custom:
            return theme.accent.color
        }
    }
}

private struct AgentProfileBadge: View {
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

private struct AgentProfileEditorView: View {
    @Binding var draft: AgentProfileEditorDraft
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(draft.isNew ? "Add Agent Profile" : "Edit Agent Profile")
                    .font(.headline)
                    .foregroundStyle(theme.primaryText.color)
                Spacer()
                Button(action: onCancel) {
                    Label("Cancel", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Cancel")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText.color)
                TextField("Agent Profile name", text: $draft.label)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Launch Command")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText.color)
                TextField("codex", text: $draft.launchCommand)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Launch Arguments")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText.color)
                TextEditor(text: $draft.launchArgumentsJSON)
                    .font(.body.monospaced())
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(minHeight: 72)
                    .background(theme.elevatedBackground.color, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(theme.border.color.opacity(0.72), lineWidth: 1)
                    }
                Text("Use a JSON array of strings, or leave empty for no arguments.")
                    .font(.caption)
                    .foregroundStyle(theme.mutedText.color)
            }

            Toggle("Use as default for new sessions", isOn: $draft.makeDefault)
                .toggleStyle(.checkbox)
                .foregroundStyle(theme.primaryText.color)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .disabled(isSaving)
                Button(draft.isNew ? "Add" : "Save", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)
            }
        }
        .padding(12)
        .background(theme.elevatedBackground.color, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.activeBorder.color.opacity(0.6), lineWidth: 1)
        }
    }
}

private struct AgentProfileEditorDraft: Identifiable, Equatable {
    let id: UUID
    var label: String
    var launchCommand: String
    var launchArgumentsJSON: String
    var secretRef: String?
    var isBuiltIn: Bool
    var hasUserOverride: Bool
    var makeDefault: Bool
    var isNew: Bool

    init() {
        id = UUID()
        label = ""
        launchCommand = ""
        launchArgumentsJSON = "[]"
        secretRef = nil
        isBuiltIn = false
        hasUserOverride = false
        makeDefault = false
        isNew = true
    }

    init(profile: SessionShortcut, isDefault: Bool) {
        id = profile.id
        label = profile.label
        launchCommand = profile.launchCommand
        launchArgumentsJSON = profile.launchArgumentsJSON ?? ""
        secretRef = profile.secretRef
        isBuiltIn = profile.isBuiltIn
        hasUserOverride = profile.hasUserOverride
        makeDefault = isDefault
        isNew = false
    }

    var sessionShortcut: SessionShortcut {
        SessionShortcut(
            id: id,
            label: trimmedLabel,
            launchCommand: trimmedLaunchCommand,
            launchArgumentsJSON: normalizedLaunchArgumentsJSON,
            secretRef: secretRef,
            isBuiltIn: isBuiltIn,
            hasUserOverride: hasUserOverride
        )
    }

    var validationMessage: String? {
        if trimmedLabel.isEmpty {
            return "Name is required."
        }
        if trimmedLaunchCommand.isEmpty {
            return "Launch command is required."
        }

        guard let normalizedLaunchArgumentsJSON else {
            return nil
        }
        guard let data = normalizedLaunchArgumentsJSON.data(using: .utf8),
              (try? JSONDecoder().decode([String].self, from: data)) != nil
        else {
            return "Launch arguments must be a valid JSON array of strings."
        }

        return nil
    }

    private var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedLaunchCommand: String {
        launchCommand.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedLaunchArgumentsJSON: String? {
        let trimmedArguments = launchArgumentsJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedArguments.isEmpty ? nil : trimmedArguments
    }
}
