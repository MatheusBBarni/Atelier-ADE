import AppKit
import NativeMacADECore
import SwiftUI

struct ContentView: View {
    let store: WorkspaceStore
    let commandService: any WorkspaceCommandService
    let terminalHostController: TerminalHostController
    @State private var didRequestRestore = false
    @State private var isRestoring = true
    @State private var restoreResult: RestoreWorkspaceResult?
    @State private var pilotDiagnostics: PilotDiagnostics?
    @State private var userMessage: UserMessage?
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all
    @State private var sessionCommandPalette: SessionCommandPaletteState?

    var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $splitViewVisibility) {
                ProjectSidebarView(store: store, commandService: commandService, userMessage: $userMessage)
            } detail: {
                WorkspaceDetailView(
                    store: store,
                    commandService: commandService,
                    terminalHostController: terminalHostController,
                    userMessage: $userMessage,
                    isSidebarCollapsed: splitViewVisibility == .detailOnly
                )
            }
            .disabled(isRestoring)

            if isRestoring {
                ProgressView("Restoring workspace…")
                    .padding(20)
                    .background(NordTheme.elevatedBackground.color, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(NordTheme.primaryText.color)
            }

            if !isRestoring, let restoreResult, restoreResult.hasRecoveryItems {
                VStack {
                    RestoreRecoveryView(
                        result: restoreResult,
                        commandService: commandService,
                        userMessage: $userMessage
                    ) {
                        self.restoreResult = nil
                    }
                    .padding(.top, 18)
                    .padding(.horizontal, 20)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if !isRestoring, let pilotDiagnostics, !pilotDiagnostics.releaseBlockingReasons.isEmpty {
                VStack {
                    Spacer()
                    PilotDiagnosticsView(diagnostics: pilotDiagnostics)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 18)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let sessionCommandPalette {
                SessionCommandPaletteOverlay(
                    state: sessionCommandPalette,
                    onClose: { self.sessionCommandPalette = nil },
                    onSelect: startSession(using:)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .frame(minWidth: 1_040, minHeight: 680)
        .background(NordTheme.shellBackground.color)
        .preferredColorScheme(.dark)
        .tint(NordTheme.frost1.color)
        .task {
            guard !didRequestRestore else { return }
            didRequestRestore = true
            do {
                restoreResult = try await commandService.restoreWorkspace()
            } catch {
                userMessage = UserMessage(title: "Restore unavailable", detail: String(describing: error))
            }
            pilotDiagnostics = commandService.pilotDiagnostics()
            isRestoring = false
        }
        .alert(userMessage?.title ?? "Workspace message", isPresented: userMessagePresented) {
            Button("OK") { userMessage = nil }
        } message: {
            Text(userMessage?.detail ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleWorkspaceSidebar)) { _ in
            toggleSidebar()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSessionCommandPalette)) { _ in
            showSessionCommandPalette()
        }
    }

    private var userMessagePresented: Binding<Bool> {
        Binding(get: { userMessage != nil }, set: { if !$0 { userMessage = nil } })
    }

    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.16)) {
            splitViewVisibility = splitViewVisibility == .detailOnly ? .all : .detailOnly
        }
    }

    private func showSessionCommandPalette() {
        guard let project = store.selectedProject else {
            userMessage = UserMessage(title: "Project required", detail: "Select a project before starting a session.")
            return
        }

        sessionCommandPalette = SessionCommandPaletteState(project: project, isLoading: true)
        Task {
            do {
                let options = try await loadSessionCommandOptions()
                await MainActor.run {
                    guard sessionCommandPalette?.projectID == project.id else { return }
                    sessionCommandPalette = SessionCommandPaletteState(project: project, options: options, isLoading: false)
                }
            } catch {
                await MainActor.run {
                    sessionCommandPalette = nil
                    userMessage = UserMessage(title: "Session commands unavailable", detail: String(describing: error))
                }
            }
        }
    }

    private func startSession(using option: SessionCommandOption) {
        guard let projectID = sessionCommandPalette?.projectID else { return }
        sessionCommandPalette = nil

        Task {
            do {
                _ = try await commandService.createSession(projectID: projectID, shortcutID: option.shortcutID)
            } catch {
                userMessage = UserMessage(title: "Session could not be created", detail: String(describing: error))
            }
        }
    }

    private func loadSessionCommandOptions() async throws -> [SessionCommandOption] {
        let shortcuts = try await commandService.availableSessionShortcuts()
        var options: [SessionCommandOption] = [
            SessionCommandOption(
                title: "Plain Session",
                subtitle: "Start a shell in the selected project",
                systemImage: "terminal",
                shortcutID: nil
            )
        ]

        if let codexShortcut = shortcuts.first(where: { $0.label.caseInsensitiveCompare("Codex") == .orderedSame || $0.launchCommand.caseInsensitiveCompare("codex") == .orderedSame }) {
            options.append(
                SessionCommandOption(
                    title: "Codex",
                    subtitle: "Start a session with the Codex profile",
                    systemImage: "sparkles",
                    shortcutID: codexShortcut.id
                )
            )
        }

        if let claudeShortcut = shortcuts.first(where: { $0.label.caseInsensitiveCompare("Claude") == .orderedSame || $0.launchCommand.caseInsensitiveCompare("claude") == .orderedSame }) {
            options.append(
                SessionCommandOption(
                    title: "Claude",
                    subtitle: "Start a session with the Claude profile",
                    systemImage: "bubble.left.and.bubble.right",
                    shortcutID: claudeShortcut.id
                )
            )
        }

        return options
    }
}

struct PilotDiagnosticsView: View {
    let diagnostics: PilotDiagnostics

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Pilot diagnostics need attention", systemImage: "waveform.path.ecg.rectangle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NordTheme.auroraYellow.color)
            Text(diagnostics.releaseBlockingReasons.joined(separator: " • "))
                .font(.caption)
                .foregroundStyle(NordTheme.secondaryText.color)
            Text("Restore failures: \(percent(diagnostics.restoreFailureRate)) · Terminal failures: \(percent(diagnostics.terminalSurfaceFailureRate))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(NordTheme.mutedText.color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NordTheme.elevatedBackground.color.opacity(0.96), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).stroke(NordTheme.activeBorder.color.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0...2)))
    }
}

struct RestoreRecoveryView: View {
    let result: RestoreWorkspaceResult
    let commandService: any WorkspaceCommandService
    @Binding var userMessage: UserMessage?
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(NordTheme.auroraYellow.color)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Workspace restored with recovery notes")
                        .font(.headline)
                        .foregroundStyle(NordTheme.primaryText.color)
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(NordTheme.secondaryText.color)
                }
                Spacer(minLength: 12)
                Button("Dismiss", action: dismiss)
                    .buttonStyle(.bordered)
            }

            ForEach(result.skippedProjects) { project in
                VStack(alignment: .leading, spacing: 3) {
                    Text("Skipped \(project.displayName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NordTheme.primaryText.color)
                    Text(project.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(NordTheme.mutedText.color)
                        .lineLimit(1)
                    Text(project.reason)
                        .font(.caption)
                        .foregroundStyle(NordTheme.secondaryText.color)
                    HStack {
                        Button("Forget this project") {
                            forget(project)
                        }
                        .buttonStyle(.bordered)
                        Text("To restore it later, choose Open Project again after the folder is available.")
                            .font(.caption2)
                            .foregroundStyle(NordTheme.mutedText.color)
                    }
                }
                .padding(10)
                .background(NordTheme.shellBackground.color.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .background(NordTheme.elevatedBackground.color.opacity(0.96), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(NordTheme.auroraYellow.color.opacity(0.65), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workspace restore recovery")
    }

    private var summary: String {
        if result.skippedProjects.isEmpty {
            return "Some restored terminal surfaces could not be reopened. The workspace metadata remains available."
        }
        return "\(result.skippedProjects.count) project folder(s) could not be accessed. Reopen them from the Projects sidebar when available."
    }

    private func forget(_ project: SkippedRestoredProject) {
        Task {
            do {
                try await commandService.removeProject(id: project.id)
                userMessage = UserMessage(title: "Project forgotten", detail: "Removed \(project.displayName) from restore metadata.")
                dismiss()
            } catch {
                userMessage = UserMessage(title: "Project could not be forgotten", detail: String(describing: error))
            }
        }
    }
}

struct ProjectSidebarView: View {
    let store: WorkspaceStore
    let commandService: any WorkspaceCommandService
    @Binding var userMessage: UserMessage?
    @State private var pendingRemoval: WorkspaceProject?
    @State private var renameDraft: SessionRenameDraft?
    @State private var expandedProjectIDs: Set<UUID> = []
    @State private var hoveredSessionID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SidebarHeader(
                title: "Projects",
                subtitle: "Persistent repository contexts",
                actionTitle: "Open Project",
                systemImage: "folder.badge.plus",
                action: openProject
            )

            if store.projects.isEmpty {
                EmptyStateView(
                    systemImage: "folder",
                    title: "Open your first project",
                    message: "Projects stay here so sessions and tabs always start in the right folder.",
                    actionTitle: "Open Project",
                    action: openProject
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(store.projects) { project in
                            let projectSessions = sessions(for: project.id)
                            let isExpanded = expandedProjectIDs.contains(project.id)
                            VStack(alignment: .leading, spacing: 12) {
                                ProjectRowView(
                                    project: project,
                                    isActive: project.id == store.selectedProjectID,
                                    isExpanded: isExpanded,
                                    onToggleDisclosure: {
                                        toggleProjectExpansion(project.id)
                                    },
                                    onSelectProject: {
                                        handleProjectSelection(project.id, isExpanded: isExpanded)
                                    }
                                ) {
                                    pendingRemoval = project
                                }

                                if isExpanded {
                                    VStack(alignment: .leading, spacing: 12) {
                                        if projectSessions.isEmpty {
                                            SidebarInlineEmptyState(
                                                title: "No sessions yet",
                                                message: "Create a session and its first terminal tab will start in this project.",
                                                actionTitle: "New Session",
                                                action: {
                                                    createSession(projectID: project.id)
                                                }
                                            )
                                        } else {
                                            VStack(alignment: .leading, spacing: 8) {
                                                ForEach(projectSessions) { session in
                                                    SessionRowView(
                                                        session: session,
                                                        isActive: session.id == store.selectedSessionID,
                                                        showsMenu: hoveredSessionID == session.id || session.id == store.selectedSessionID,
                                                        onSelect: {
                                                            selectSession(session.id)
                                                        },
                                                        onRename: {
                                                            renameDraft = SessionRenameDraft(session: session)
                                                        },
                                                        onDelete: {
                                                            removeSession(session.id)
                                                        }
                                                    )
                                                    .onHover { isHovering in
                                                        if isHovering {
                                                            hoveredSessionID = session.id
                                                        } else if hoveredSessionID == session.id {
                                                            hoveredSessionID = nil
                                                        }
                                                    }
                                                    if session.id != projectSessions.last?.id {
                                                        Divider()
                                                            .overlay(NordTheme.polarNight3.color.opacity(0.65))
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(12)
                            .background(NordTheme.elevatedBackground.color.opacity(0.82), in: RoundedRectangle(cornerRadius: 18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(project.id == store.selectedProjectID ? NordTheme.activeBorder.color.opacity(0.85) : NordTheme.polarNight3.color.opacity(0.65), lineWidth: 1)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(NordTheme.sidebarBackground.color)
        .navigationSplitViewColumnWidth(min: 280, ideal: 360)
        .confirmationDialog("Remove project?", isPresented: removalDialogBinding, titleVisibility: .visible) {
            Button("Remove Project", role: .destructive) {
                guard let pendingRemoval else { return }
                removeProject(pendingRemoval)
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: {
            Text("Sessions and tabs for this project will be removed from the workspace metadata. This does not delete files from disk.")
        }
        .sheet(item: $renameDraft) { draft in
            SessionRenameView(draft: draft) { sessionID, title in
                Task {
                    do {
                        try await commandService.renameSession(sessionID: sessionID, title: title)
                        renameDraft = nil
                    } catch {
                        userMessage = UserMessage(title: "Session could not be renamed", detail: String(describing: error))
                    }
                }
            } onCancel: {
                renameDraft = nil
            }
        }
    }

    private var removalDialogBinding: Binding<Bool> {
        Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } })
    }

    private func openProject() {
        guard let path = ProjectDirectoryPicker.chooseDirectoryPath() else { return }
        Task {
            do {
                let project = try await commandService.openProject(path: path)
                expandProject(project.id)
            } catch {
                userMessage = UserMessage(title: "Project could not be opened", detail: String(describing: error))
            }
        }
    }

    private func removeProject(_ project: WorkspaceProject) {
        Task {
            do {
                try await commandService.removeProject(id: project.id)
                expandedProjectIDs.remove(project.id)
                pendingRemoval = nil
            } catch {
                userMessage = UserMessage(title: "Project could not be removed", detail: String(describing: error))
            }
        }
    }

    private func selectProject(_ id: UUID?) {
        Task {
            do {
                try await commandService.selectProject(id: id)
            } catch {
                userMessage = UserMessage(title: "Project selection could not be saved", detail: String(describing: error))
            }
        }
    }

    private func createSession() {
        guard let selectedProjectID = store.selectedProjectID else { return }
        createSession(projectID: selectedProjectID, shortcutID: nil)
    }

    private func createSession(projectID: UUID, shortcutID: UUID? = nil) {
        Task {
            do {
                expandProject(projectID)
                _ = try await commandService.createSession(projectID: projectID, shortcutID: shortcutID)
            } catch {
                userMessage = UserMessage(title: "Session could not be created", detail: String(describing: error))
            }
        }
    }

    private func selectSession(_ id: UUID?) {
        Task {
            do {
                try await commandService.selectSession(id: id)
            } catch {
                userMessage = UserMessage(title: "Session selection could not be saved", detail: String(describing: error))
            }
        }
    }

    private func removeSession(_ id: UUID) {
        Task {
            do {
                try await commandService.removeSession(id: id)
            } catch {
                userMessage = UserMessage(title: "Session could not be removed", detail: String(describing: error))
            }
        }
    }

    private func sessions(for projectID: UUID) -> [WorkspaceSession] {
        store.orderedSessions(for: projectID)
    }

    private func expandProject(_ id: UUID) {
        expandedProjectIDs.insert(id)
    }

    private func toggleProjectExpansion(_ id: UUID) {
        if expandedProjectIDs.contains(id) {
            expandedProjectIDs.remove(id)
        } else {
            expandedProjectIDs.insert(id)
        }
    }

    private func handleProjectSelection(_ id: UUID, isExpanded: Bool) {
        if isExpanded {
            expandedProjectIDs.remove(id)
        } else {
            expandedProjectIDs.insert(id)
        }
        selectProject(id)
    }
}

struct ProjectRowView: View {
    let project: WorkspaceProject
    let isActive: Bool
    let isExpanded: Bool
    let onToggleDisclosure: () -> Void
    let onSelectProject: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggleDisclosure) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NordTheme.mutedText.color)
                    .frame(width: 12)
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Collapse sessions" : "Expand sessions")

            Button(action: onSelectProject) {
                HStack(spacing: 10) {
                    Image(systemName: isActive ? "folder.fill" : "folder")
                        .foregroundStyle(isActive ? NordTheme.snowStorm2.color : NordTheme.frost1.color)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.displayName)
                            .font(.headline)
                            .foregroundStyle(NordTheme.primaryText.color)
                            .lineLimit(1)
                        Text(project.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(NordTheme.mutedText.color)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(project.displayName)
            .accessibilityValue(projectAccessibilityValue)

            if isActive {
                Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(NordTheme.destructive.color)
                    .help("Remove selected project")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(isActive ? NordTheme.activeBackground.color.opacity(0.42) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? NordTheme.activeBorder.color : Color.clear, lineWidth: 1)
        }
    }

    private var projectAccessibilityValue: String {
        switch (isActive, isExpanded) {
        case (true, true):
            return "Active project, expanded"
        case (true, false):
            return "Active project, collapsed"
        case (false, true):
            return "Project, expanded"
        case (false, false):
            return "Project, collapsed"
        }
    }
}

struct SessionListView: View {
    let store: WorkspaceStore
    let commandService: any WorkspaceCommandService
    @Binding var userMessage: UserMessage?
    @State private var renameDraft: SessionRenameDraft?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SidebarHeader(
                title: store.selectedProject?.displayName ?? "Sessions",
                subtitle: store.selectedProject == nil ? "Select a project to see sessions" : "Project-scoped sessions",
                actionTitle: "New Session",
                systemImage: "plus.rectangle.on.folder",
                action: createSession
            )
            .disabled(store.selectedProjectID == nil)

            if store.selectedProjectID == nil {
                EmptyStateView(
                    systemImage: "sidebar.left",
                    title: "No project selected",
                    message: "Choose a project from the sidebar before creating or resuming sessions."
                )
            } else if store.sessionsForSelectedProject.isEmpty {
                EmptyStateView(
                    systemImage: "rectangle.stack.badge.plus",
                    title: "No sessions yet",
                    message: "Create a lightweight session for this project. New sessions use a timestamp title until renamed.",
                    actionTitle: "New Session",
                    action: createSession
                )
            } else {
                List(store.sessionsForSelectedProject, selection: selectedSessionBinding) { session in
                    SessionRowView(
                        session: session,
                        isActive: session.id == store.selectedSessionID,
                        showsMenu: true,
                        onSelect: { selectSession(session.id) },
                        onRename: { renameDraft = SessionRenameDraft(session: session) },
                        onDelete: { }
                    )
                        .tag(session.id)
                        .contextMenu {
                            Button("Resume") { selectSession(session.id) }
                            Button("Rename") { renameDraft = SessionRenameDraft(session: session) }
                        }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(NordTheme.shellBackground.color)
        .navigationSplitViewColumnWidth(min: 240, ideal: 300)
        .sheet(item: $renameDraft) { draft in
            SessionRenameView(draft: draft) { sessionID, title in
                Task {
                    do {
                        try await commandService.renameSession(sessionID: sessionID, title: title)
                        renameDraft = nil
                    } catch {
                        userMessage = UserMessage(title: "Session could not be renamed", detail: String(describing: error))
                    }
                }
            } onCancel: {
                renameDraft = nil
            }
        }
    }

    private var selectedSessionBinding: Binding<WorkspaceSession.ID?> {
        Binding(get: { store.selectedSessionID }, set: { selectSession($0) })
    }

    private func createSession() {
        createSession(shortcutID: nil)
    }

    private func createSession(shortcutID: UUID?) {
        guard let selectedProjectID = store.selectedProjectID else { return }
        Task {
            do {
                _ = try await commandService.createSession(projectID: selectedProjectID, shortcutID: shortcutID)
            } catch {
                userMessage = UserMessage(title: "Session could not be created", detail: String(describing: error))
            }
        }
    }

    private func selectSession(_ id: UUID?) {
        Task {
            do {
                try await commandService.selectSession(id: id)
            } catch {
                userMessage = UserMessage(title: "Session selection could not be saved", detail: String(describing: error))
            }
        }
    }
}

struct SidebarInlineEmptyState: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NordTheme.primaryText.color)
            Text(message)
                .font(.caption)
                .foregroundStyle(NordTheme.secondaryText.color)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NordTheme.shellBackground.color.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct SessionCommandOption: Identifiable, Equatable {
    let title: String
    let subtitle: String
    let systemImage: String
    let shortcutID: UUID?

    var id: String {
        shortcutID?.uuidString ?? "plain-session"
    }
}

struct SessionCommandPaletteState: Equatable {
    let projectID: UUID
    let projectName: String
    let options: [SessionCommandOption]
    let isLoading: Bool

    init(project: WorkspaceProject, options: [SessionCommandOption] = [], isLoading: Bool = true) {
        self.projectID = project.id
        self.projectName = project.displayName
        self.options = options
        self.isLoading = isLoading
    }
}

struct SessionCommandPaletteOverlay: View {
    let state: SessionCommandPaletteState
    let onClose: () -> Void
    let onSelect: (SessionCommandOption) -> Void
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredOptions: [SessionCommandOption] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return state.options }
        return state.options.filter {
            $0.title.localizedCaseInsensitiveContains(trimmedQuery) ||
            $0.subtitle.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(NordTheme.mutedText.color)
                    TextField("Start session…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .foregroundStyle(NordTheme.primaryText.color)
                        .focused($isSearchFocused)
                        .onSubmit {
                            if let first = filteredOptions.first {
                                onSelect(first)
                            }
                        }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)

                Divider().overlay(NordTheme.polarNight3.color)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Commands for \(state.projectName)")
                        .font(.caption)
                        .foregroundStyle(NordTheme.mutedText.color)

                    if state.isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Loading session commands…")
                                .foregroundStyle(NordTheme.secondaryText.color)
                        }
                        .padding(.vertical, 16)
                    } else if filteredOptions.isEmpty {
                        Text("No matching commands")
                            .foregroundStyle(NordTheme.secondaryText.color)
                            .padding(.vertical, 16)
                    } else {
                        ForEach(filteredOptions) { option in
                            Button(action: { onSelect(option) }) {
                                SessionCommandPaletteRow(option: option)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)

                Divider().overlay(NordTheme.polarNight3.color)

                HStack {
                    Text("↩︎ Start first match")
                        .font(.caption2)
                        .foregroundStyle(NordTheme.mutedText.color)
                    Spacer()
                    Button("Cancel", action: onClose)
                        .buttonStyle(.plain)
                        .keyboardShortcut(.cancelAction)
                        .foregroundStyle(NordTheme.secondaryText.color)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(width: 720)
            .background(NordTheme.shellBackground.color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(NordTheme.polarNight3.color, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 30, y: 12)
        }
        .task {
            isSearchFocused = true
        }
    }
}

struct SessionCommandPaletteRow: View {
    let option: SessionCommandOption

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: option.systemImage)
                .font(.headline)
                .foregroundStyle(NordTheme.snowStorm2.color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(option.title)
                    .font(.headline)
                    .foregroundStyle(NordTheme.primaryText.color)
                Text(option.subtitle)
                    .font(.callout)
                    .foregroundStyle(NordTheme.secondaryText.color)
            }

            Spacer(minLength: 12)
            Image(systemName: "arrow.turn.down.left")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NordTheme.mutedText.color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NordTheme.elevatedBackground.color.opacity(0.92), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NordTheme.polarNight3.color, lineWidth: 1)
        }
    }
}

struct SessionRowView: View {
    let session: WorkspaceSession
    let isActive: Bool
    let showsMenu: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    Image(systemName: isActive ? "rectangle.stack.fill" : "rectangle.stack")
                        .foregroundStyle(isActive ? NordTheme.snowStorm2.color : NordTheme.frost0.color)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(session.title)
                            .font(.headline)
                            .foregroundStyle(NordTheme.primaryText.color)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showsMenu {
                Menu {
                    Button("Rename", systemImage: "pencil", action: onRename)
                    Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.callout.weight(.semibold))
                        .frame(width: 28, height: 28)
                        .background(NordTheme.shellBackground.color.opacity(0.85), in: Circle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Session actions")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(isActive ? NordTheme.activeBackground.color.opacity(0.32) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? NordTheme.activeBorder.color : Color.clear, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(session.title)
        .accessibilityValue(isActive ? "Active session" : "Session")
    }
}

struct SessionRenameView: View {
    let draft: SessionRenameDraft
    let onSave: (UUID, String) -> Void
    let onCancel: () -> Void
    @State private var title: String
    @FocusState private var focusedField: Bool

    init(draft: SessionRenameDraft, onSave: @escaping (UUID, String) -> Void, onCancel: @escaping () -> Void) {
        self.draft = draft
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: draft.title)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename Session")
                .font(.title2.weight(.semibold))
                .foregroundStyle(NordTheme.primaryText.color)
            Text("Give this project session a clear purpose so it is easy to resume later.")
                .foregroundStyle(NordTheme.secondaryText.color)
            TextField("Session title", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField)
                .onSubmit(save)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(NordTheme.elevatedBackground.color)
        .onAppear { focusedField = true }
    }

    private func save() {
        onSave(draft.id, title)
    }
}

struct WorkspaceDetailView: View {
    let store: WorkspaceStore
    let commandService: any WorkspaceCommandService
    let terminalHostController: TerminalHostController
    @Binding var userMessage: UserMessage?
    let isSidebarCollapsed: Bool

    var body: some View {
        VStack(spacing: 0) {
            ActiveContextBanner(
                project: store.selectedProject,
                session: store.selectedSession,
                onShowSessionCommands: showSessionCommandPalette,
                isSidebarCollapsed: isSidebarCollapsed
            )
            TabChromeView(store: store, commandService: commandService, userMessage: $userMessage)
            Divider().overlay(NordTheme.polarNight3.color)
            TerminalHostAreaView(
                store: store,
                commandService: commandService,
                terminalHostController: terminalHostController,
                userMessage: $userMessage
            )
        }
        .background(NordTheme.contentBackground.color)
        .ignoresSafeArea(.container, edges: .top)
    }

    private func showSessionCommandPalette() {
        NotificationCenter.default.post(name: .showSessionCommandPalette, object: nil)
    }
}

struct ActiveContextBanner: View {
    let project: WorkspaceProject?
    let session: WorkspaceSession?
    let onShowSessionCommands: () -> Void
    let isSidebarCollapsed: Bool

    var body: some View {
        HStack(spacing: 12) {
            Label(project?.displayName ?? "No project selected", systemImage: project == nil ? "exclamationmark.triangle" : "folder.fill")
                .font(.headline)
            Image(systemName: "chevron.right")
                .foregroundStyle(NordTheme.mutedText.color)
            Label(session?.title ?? "No session selected", systemImage: session == nil ? "rectangle.stack" : "rectangle.stack.fill")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("⌘T opens a plain shell • ⌘⇧P starts session commands")
                .font(.caption.weight(.medium))
                .foregroundStyle(NordTheme.mutedText.color)
                .lineLimit(1)
            Button(action: onShowSessionCommands) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(NordTheme.shellBackground.color.opacity(0.7), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(NordTheme.primaryText.color)
            .help("Start session commands (⌘⇧P)")
        }
        .padding(.leading, isSidebarCollapsed ? 150 : 16)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
        .foregroundStyle(NordTheme.primaryText.color)
        .background(NordTheme.elevatedBackground.color)
    }
}

struct TabChromeView: View {
    let store: WorkspaceStore
    let commandService: any WorkspaceCommandService
    @Binding var userMessage: UserMessage?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                if store.tabsForSelectedSession.isEmpty {
                    Text(store.selectedSessionID == nil ? "Select a session to see tabs" : "No tabs in this session yet")
                        .font(.callout)
                        .foregroundStyle(NordTheme.mutedText.color)
                } else {
                    ForEach(store.tabsForSelectedSession) { tab in
                        TabItemView(
                            tab: tab,
                            isActive: tab.id == store.selectedTabID,
                            onSelect: { selectTab(tab.id) },
                            onClose: { closeTab(tab.id) }
                        )
                    }
                }

                Button(action: createTab) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .background(NordTheme.elevatedBackground.color.opacity(store.selectedSessionID == nil ? 0.38 : 0.9), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(NordTheme.polarNight3.color, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(store.selectedSessionID == nil)
                .help("New tab (⌘T)")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .frame(height: 38)
        .background(NordTheme.polarNight1.color)
    }

    private func selectTab(_ id: UUID?) {
        Task {
            do {
                try await commandService.selectTab(id: id)
            } catch {
                userMessage = UserMessage(title: "Tab selection could not be saved", detail: String(describing: error))
            }
        }
    }

    private func closeTab(_ id: UUID) {
        Task {
            do {
                try await commandService.closeTab(tabID: id, force: false)
            } catch WorkspaceCommandError.closeRejected {
                userMessage = UserMessage(title: "Tab is still running", detail: "This terminal still has a live process. Close was cancelled to avoid interrupting work.")
            } catch {
                userMessage = UserMessage(title: "Tab could not be closed", detail: String(describing: error))
            }
        }
    }

    private func createTab() {
        guard let selectedSessionID = store.selectedSessionID else { return }
        Task {
            do {
                _ = try await commandService.createTab(sessionID: selectedSessionID)
            } catch {
                userMessage = UserMessage(title: "Tab could not be created", detail: String(describing: error))
            }
        }
    }
}

struct TabItemView: View {
    let tab: WorkspaceTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onSelect) {
                Label(title, systemImage: isActive ? "terminal.fill" : "terminal")
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isActive ? NordTheme.primaryText.color : NordTheme.secondaryText.color)

            Button("Close tab", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(isActive ? NordTheme.snowStorm2.color : NordTheme.mutedText.color)
                .help("Close terminal tab")
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(isActive ? NordTheme.contentBackground.color : NordTheme.elevatedBackground.color.opacity(0.8), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isActive ? NordTheme.activeBorder.color : NordTheme.polarNight3.color, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Terminal tab in \(tab.workingDirectory)")
        .accessibilityValue(isActive ? "Active tab" : "Tab")
    }

    private var title: String {
        let directoryName = URL(fileURLWithPath: tab.workingDirectory).lastPathComponent
        return directoryName.isEmpty ? tab.workingDirectory : directoryName
    }
}

struct TerminalHostAreaView: View {
    let store: WorkspaceStore
    let commandService: any WorkspaceCommandService
    let terminalHostController: TerminalHostController
    @Binding var userMessage: UserMessage?

    var body: some View {
        ZStack {
            NordTheme.contentBackground.color
            if let selectedTab = store.selectedTab {
                TerminalHostView(
                    tab: selectedTab,
                    isActive: selectedTab.id == store.selectedTabID,
                    controller: terminalHostController,
                    onError: { error in userMessage = UserMessage(title: "Terminal unavailable", detail: String(describing: error)) }
                )
                .id(selectedTab.id)
                .padding(12)
            } else {
                TerminalPlaceholderView(selectedProject: store.selectedProject, selectedSession: store.selectedSession)
            }
        }
        .task(id: store.tabsForSelectedSession.map(\.id)) {
            await ensureVisibleSessionSurfaces()
        }
    }

    private func ensureVisibleSessionSurfaces() async {
        for tab in store.tabsForSelectedSession {
            do {
                try await terminalHostController.createSurface(for: tab)
            } catch {
                userMessage = UserMessage(title: "Terminal unavailable", detail: String(describing: error))
                return
            }
        }
    }
}

struct TerminalHostView: NSViewRepresentable {
    let tab: WorkspaceTab
    let isActive: Bool
    let controller: TerminalHostController
    let onError: (any Error) -> Void

    func makeNSView(context: Context) -> NSView {
        controller.makeHostView(for: tab, isActive: isActive)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        controller.updateHostView(nsView, tab: tab, isActive: isActive)
        Task { @MainActor in
            do {
                try await controller.createSurface(for: tab)
                controller.focus(tabID: tab.id)
            } catch {
                onError(error)
            }
        }
    }
}

struct TerminalPlaceholderView: View {
    let selectedProject: WorkspaceProject?
    let selectedSession: WorkspaceSession?

    var body: some View {
        ZStack {
            NordTheme.contentBackground.color
            VStack(spacing: 12) {
                Image(systemName: "terminal")
                    .font(.system(size: 44))
                    .foregroundStyle(NordTheme.frost1.color)
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(NordTheme.primaryText.color)
                Text(message)
                    .font(.callout.monospaced())
                    .foregroundStyle(NordTheme.secondaryText.color)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .background(NordTheme.elevatedBackground.color.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(NordTheme.polarNight3.color, lineWidth: 1)
            }
        }
    }

    private var title: String {
        if selectedProject == nil { return "Choose a project" }
        if selectedSession == nil { return "Create or select a session" }
        return "Create a tab"
    }

    private var message: String {
        if let selectedProject { return selectedProject.path }
        return "Open a project to start a project-scoped workflow."
    }
}

struct SidebarHeader: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(NordTheme.primaryText.color)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(NordTheme.mutedText.color)
                    .lineLimit(2)
            }
            Spacer()
            Button(actionTitle, systemImage: systemImage, action: action)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel(actionTitle)
        }
        .padding(.horizontal, 16)
        .padding(.top, 0)
        .padding(.bottom, 10)
        .background(NordTheme.polarNight1.color)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(NordTheme.frost1.color)
            Text(title)
                .font(.headline)
                .foregroundStyle(NordTheme.primaryText.color)
            Text(message)
                .font(.callout)
                .foregroundStyle(NordTheme.secondaryText.color)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(NordTheme.shellBackground.color)
    }
}

struct SessionRenameDraft: Identifiable, Equatable {
    let id: UUID
    let title: String

    init(session: WorkspaceSession) {
        id = session.id
        title = session.title
    }
}

struct UserMessage: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String
}

enum ProjectDirectoryPicker {
    @MainActor
    static func chooseDirectoryPath() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Project"
        panel.message = "Choose a project folder to keep in the Atelier sidebar."
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}

private extension NordColorToken {
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

#Preview {
    let store = WorkspaceStore.preview()
    let persistence = InMemoryWorkspacePersistenceStore()
    let restoreCoordinator = RestoreCoordinator(persistenceStore: persistence)
    let terminalHostController = TerminalHostController()
    ContentView(
        store: store,
        commandService: DefaultWorkspaceCommandService(
            store: store,
            persistenceStore: persistence,
            restoreCoordinator: restoreCoordinator,
            terminalSurfaceManager: terminalHostController
        ),
        terminalHostController: terminalHostController
    )
}
