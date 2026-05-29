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
    @State private var userMessage: UserMessage?

    var body: some View {
        ZStack {
            NavigationSplitView {
                ProjectSidebarView(store: store, commandService: commandService, userMessage: $userMessage)
            } content: {
                SessionListView(store: store, commandService: commandService, userMessage: $userMessage)
            } detail: {
                WorkspaceDetailView(store: store, commandService: commandService, terminalHostController: terminalHostController, userMessage: $userMessage)
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
        }
        .navigationTitle("Native Mac ADE")
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
            isRestoring = false
        }
        .alert(userMessage?.title ?? "Workspace message", isPresented: userMessagePresented) {
            Button("OK") { userMessage = nil }
        } message: {
            Text(userMessage?.detail ?? "")
        }
    }

    private var userMessagePresented: Binding<Bool> {
        Binding(get: { userMessage != nil }, set: { if !$0 { userMessage = nil } })
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
                List(store.projects, selection: selectedProjectBinding) { project in
                    ProjectRowView(project: project, isActive: project.id == store.selectedProjectID) {
                        pendingRemoval = project
                    }
                        .tag(project.id)
                        .contextMenu {
                            Button("Select") { selectProject(project.id) }
                            Button("Remove Project", role: .destructive) { pendingRemoval = project }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Remove", role: .destructive) { pendingRemoval = project }
                        }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(NordTheme.sidebarBackground.color)
        .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        .confirmationDialog("Remove project?", isPresented: removalDialogBinding, titleVisibility: .visible) {
            Button("Remove Project", role: .destructive) {
                guard let pendingRemoval else { return }
                removeProject(pendingRemoval)
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: {
            Text("Sessions and tabs for this project will be removed from the workspace metadata. This does not delete files from disk.")
        }
    }

    private var selectedProjectBinding: Binding<WorkspaceProject.ID?> {
        Binding(get: { store.selectedProjectID }, set: { selectProject($0) })
    }

    private var removalDialogBinding: Binding<Bool> {
        Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } })
    }

    private func openProject() {
        guard let path = ProjectDirectoryPicker.chooseDirectoryPath() else { return }
        Task {
            do {
                _ = try await commandService.openProject(path: path)
            } catch {
                userMessage = UserMessage(title: "Project could not be opened", detail: String(describing: error))
            }
        }
    }

    private func removeProject(_ project: WorkspaceProject) {
        Task {
            do {
                try await commandService.removeProject(id: project.id)
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
}

struct ProjectRowView: View {
    let project: WorkspaceProject
    let isActive: Bool
    let onRemove: () -> Void

    var body: some View {
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
            if isActive {
                Text("Active")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(NordTheme.activeBorder.color.opacity(0.22), in: Capsule())
                    .foregroundStyle(NordTheme.snowStorm2.color)
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
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(project.displayName)
        .accessibilityValue(isActive ? "Active project" : "Project")
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
                    SessionRowView(session: session, isActive: session.id == store.selectedSessionID) {
                        renameDraft = SessionRenameDraft(session: session)
                    }
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
        guard let selectedProjectID = store.selectedProjectID else { return }
        Task {
            do {
                _ = try await commandService.createSession(projectID: selectedProjectID, shortcutID: nil)
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

struct SessionRowView: View {
    let session: WorkspaceSession
    let isActive: Bool
    let onRename: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isActive ? "rectangle.stack.fill" : "rectangle.stack")
                .foregroundStyle(isActive ? NordTheme.snowStorm2.color : NordTheme.frost0.color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.headline)
                    .foregroundStyle(NordTheme.primaryText.color)
                    .lineLimit(1)
                Text(session.isUserNamed ? "User named • Resume ready" : "Default timestamp title • Resume ready")
                    .font(.caption)
                    .foregroundStyle(NordTheme.mutedText.color)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(NordTheme.auroraGreen.color)
                    .accessibilityHidden(true)
                Button("Rename", systemImage: "pencil", action: onRename)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Rename active session")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(isActive ? NordTheme.activeBackground.color.opacity(0.32) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? NordTheme.activeBorder.color : Color.clear, lineWidth: 1)
        }
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

    var body: some View {
        VStack(spacing: 0) {
            ActiveContextBanner(project: store.selectedProject, session: store.selectedSession)
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
        .toolbar {
            ToolbarItem {
                Button("New Tab", systemImage: "plus") { createTab() }
                    .disabled(store.selectedSessionID == nil)
                    .keyboardShortcut("t", modifiers: [.command])
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

struct ActiveContextBanner: View {
    let project: WorkspaceProject?
    let session: WorkspaceSession?

    var body: some View {
        HStack(spacing: 12) {
            Label(project?.displayName ?? "No project selected", systemImage: project == nil ? "exclamationmark.triangle" : "folder.fill")
                .font(.headline)
            Image(systemName: "chevron.right")
                .foregroundStyle(NordTheme.mutedText.color)
            Label(session?.title ?? "No session selected", systemImage: session == nil ? "rectangle.stack" : "rectangle.stack.fill")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("New tabs inherit this context")
                .font(.caption.weight(.medium))
                .foregroundStyle(NordTheme.mutedText.color)
        }
        .padding(.horizontal, 16)
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
            HStack(spacing: 8) {
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
            }
            .padding(12)
        }
        .frame(height: 56)
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
                userMessage = UserMessage(title: "Tab is still running", detail: "Ghostty reported that this terminal has a live process. Close was cancelled to avoid interrupting work.")
            } catch {
                userMessage = UserMessage(title: "Tab could not be closed", detail: String(describing: error))
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
        .background(isActive ? NordTheme.activeBackground.color.opacity(0.38) : NordTheme.elevatedBackground.color.opacity(0.72), in: Capsule())
        .overlay {
            Capsule().stroke(isActive ? NordTheme.activeBorder.color : NordTheme.polarNight3.color, lineWidth: 1)
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
        .padding(16)
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
        panel.message = "Choose a project folder to keep in the Native Mac ADE sidebar."
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
