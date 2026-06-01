import AppKit
@preconcurrency import CodeEditorView
import LanguageSupport
import NativeMacADECore
import SwiftUI
import UniformTypeIdentifiers

struct ShellThemePaletteKey: EnvironmentKey {
    static let defaultValue = AppTheme.defaultTheme.shellPalette
}

struct ShellUIFontSizeKey: EnvironmentKey {
    static let defaultValue = AppPreferences.defaultTerminalFontSize
}

extension EnvironmentValues {
    var shellThemePalette: ShellThemePalette {
        get { self[ShellThemePaletteKey.self] }
        set { self[ShellThemePaletteKey.self] = newValue }
    }

    var shellUIFontSize: Double {
        get { self[ShellUIFontSizeKey.self] }
        set { self[ShellUIFontSizeKey.self] = newValue }
    }
}

private extension ThemeColorScheme {
    var swiftUIColorScheme: ColorScheme {
        switch self {
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }
}

private extension ColorScheme {
    var themeColorScheme: ThemeColorScheme {
        switch self {
        case .dark:
            return .dark
        case .light:
            return .light
        @unknown default:
            return .light
        }
    }
}

private final class ReorderDragLifecycleMonitor: NSObject, ObservableObject {
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var onEnd: (() -> Void)?
    private var shouldFinishOnLocalMouseUp: (() -> Bool)?

    func begin(
        onEnd: @escaping () -> Void,
        shouldFinishOnLocalMouseUp: @escaping () -> Bool = { true }
    ) {
        finish()
        self.onEnd = onEnd
        self.shouldFinishOnLocalMouseUp = shouldFinishOnLocalMouseUp

        let mouseUpEvents: NSEvent.EventTypeMask = [.leftMouseUp, .rightMouseUp, .otherMouseUp]
        let localEvents: NSEvent.EventTypeMask = [mouseUpEvents, .keyDown]

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: localEvents) { [weak self] event in
            if Self.shouldEndDrag(after: event, shouldFinishOnLocalMouseUp: self?.shouldFinishOnLocalMouseUp) {
                Self.requestFinish(for: self)
            }
            return event
        }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseUpEvents) { [weak self] _ in
            Self.requestFinish(for: self)
        }
    }

    func finish() {
        removeEventMonitors()
        let endHandler = onEnd
        onEnd = nil
        shouldFinishOnLocalMouseUp = nil
        endHandler?()
    }

    @objc private func finishAfterCurrentEvent() {
        finish()
    }

    deinit {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
        }
    }

    private func removeEventMonitors() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
    }

    nonisolated private static func shouldEndDrag(
        after event: NSEvent,
        shouldFinishOnLocalMouseUp: (() -> Bool)?
    ) -> Bool {
        switch event.type {
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            return shouldFinishOnLocalMouseUp?() ?? true
        case .keyDown:
            return event.charactersIgnoringModifiers == "\u{1B}"
        default:
            return false
        }
    }

    nonisolated private static func requestFinish(for monitor: ReorderDragLifecycleMonitor?) {
        monitor?.performSelector(
            onMainThread: #selector(finishAfterCurrentEvent),
            with: nil,
            waitUntilDone: false
        )
    }
}

private final class MainThreadUUIDDelivery: NSObject, @unchecked Sendable {
    private let completion: (UUID?) -> Void
    private var value: UUID?

    init(completion: @escaping (UUID?) -> Void) {
        self.completion = completion
    }

    @objc func deliver() {
        completion(value)
    }

    nonisolated func schedule(_ value: UUID?) {
        self.value = value
        self.performSelector(onMainThread: #selector(deliver), with: nil, waitUntilDone: false)
    }
}

struct ContentView: View {
    let shellState: AppShellState
    let store: WorkspaceStore
    let commandService: any WorkspaceCommandService
    let terminalHostController: TerminalHostController
    let terminalExitEvents: TerminalExitEventSource
    let fileAccessService: any WorkspaceFileAccessing
    let fileBufferController: any WorkspaceFileBufferManaging
    @Environment(\.colorScheme) private var runtimeColorScheme
    @State private var didRequestRestore = false
    @State private var isRestoring = true
    @State private var restoreResult: RestoreWorkspaceResult?
    @State private var pilotDiagnostics: PilotDiagnostics?
    @State private var userMessage: UserMessage?
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all
    @State private var sessionCommandPalette: SessionCommandPaletteState?
    @State private var agentTabPalette: AgentTabPaletteState?
    @State private var sessionSearchPalette: SessionSearchPaletteState?

    var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $splitViewVisibility) {
                ProjectSidebarView(
                    store: store,
                    commandService: commandService,
                    terminalExitEvents: terminalExitEvents,
                    userMessage: $userMessage
                )
            } detail: {
                WorkspaceDetailView(
                    store: store,
                    commandService: commandService,
                    terminalHostController: terminalHostController,
                    fileAccessService: fileAccessService,
                    fileBufferController: fileBufferController,
                    userMessage: $userMessage,
                    onOpenSettings: { shellState.presentSettings(source: .visibleEntryPoint) },
                    isSidebarCollapsed: splitViewVisibility == .detailOnly
                )
            }
            .disabled(isRestoring)

            if isRestoring {
                ProgressView("Restoring workspace…")
                    .padding(20)
                    .background(theme.elevatedBackground.color, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(theme.primaryText.color)
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
                    PilotDiagnosticsView(diagnostics: pilotDiagnostics) {
                        self.pilotDiagnostics = nil
                    }
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

            if let agentTabPalette {
                AgentTabPaletteOverlay(
                    state: agentTabPalette,
                    onClose: { self.agentTabPalette = nil },
                    onSelect: openAgentTab(using:)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            if let sessionSearchPalette {
                SessionSearchPaletteOverlay(
                    state: sessionSearchPalette,
                    onClose: { self.sessionSearchPalette = nil },
                    onSelect: selectSessionFromSearch(using:)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .frame(minWidth: 1_040, minHeight: 680)
        .background(theme.shellBackground.color)
        .preferredColorScheme(runtimeAppearance.forcedColorScheme?.swiftUIColorScheme)
        .tint(theme.accent.color)
        .environment(\.shellThemePalette, theme)
        .environment(\.shellUIFontSize, store.appPreferences.terminalFontSize)
        .onAppear(perform: applyActiveTheme)
        .onChange(of: runtimeAppearance) { _, _ in applyActiveTheme() }
        .task {
            guard !didRequestRestore else { return }
            didRequestRestore = true
            let startupResult = await AppShellStartupCoordinator.run(
                commandService: commandService,
                store: store,
                afterPreferencesLoaded: applyActiveTheme
            )
            restoreResult = startupResult.restoreResult
            pilotDiagnostics = startupResult.pilotDiagnostics
            if let restoreErrorDescription = startupResult.restoreErrorDescription {
                userMessage = UserMessage(title: "Restore unavailable", detail: restoreErrorDescription)
            } else if let preferenceLoadErrorDescription = startupResult.preferenceLoadErrorDescription {
                userMessage = UserMessage(title: "Settings unavailable", detail: preferenceLoadErrorDescription)
            }
            isRestoring = false
        }
        .sheet(isPresented: settingsPresentedBinding, onDismiss: shellState.dismissSettings) {
            ConfigModalView(
                store: store,
                commandService: commandService,
                onDismiss: shellState.dismissSettings
            )
            .environment(\.shellThemePalette, theme)
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
        .onReceive(NotificationCenter.default.publisher(for: .showAgentTabPalette)) { _ in
            showAgentTabPalette()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSessionSearchPalette)) { _ in
            showSessionSearchPalette()
        }
        .onReceive(NotificationCenter.default.publisher(for: .performSelectedFileCommand)) { notification in
            guard let commandID = notification.object as? AppCommandID else { return }
            performSelectedFileCommand(commandID)
        }
    }

    private var runtimeAppearance: AppRuntimeAppearance {
        store.runtimeAppearance(systemScheme: runtimeColorScheme.themeColorScheme)
    }

    private var activeTheme: AppTheme {
        runtimeAppearance.effectiveTheme
    }

    private var theme: ShellThemePalette {
        activeTheme.shellPalette
    }

    private var userMessagePresented: Binding<Bool> {
        Binding(get: { userMessage != nil }, set: { if !$0 { userMessage = nil } })
    }

    private var settingsPresentedBinding: Binding<Bool> {
        Binding(
            get: { shellState.isSettingsPresented },
            set: { isPresented in
                if !isPresented {
                    shellState.dismissSettings()
                }
            }
        )
    }

    private func applyActiveTheme() {
        terminalHostController.updateAppearance(activeTheme.terminalAppearance)
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

        agentTabPalette = nil
        sessionSearchPalette = nil
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

    private func showAgentTabPalette() {
        guard let session = store.selectedSession else {
            userMessage = UserMessage(title: "Session required", detail: "Select a session before opening a new agent tab.")
            return
        }
        sessionCommandPalette = nil
        sessionSearchPalette = nil
        guard FocusWorkspacePolicy.shouldShowTerminalCreationAffordance(
            in: store.focusWorkspaceSessionState(in: session.id)
        ) else {
            userMessage = UserMessage.commandFailure(
                WorkspaceCommandError.focusWorkspaceRejected(.additionalTerminalTabBlocked),
                fallbackTitle: "Agent tab could not be created"
            )
            return
        }

        agentTabPalette = AgentTabPaletteState(session: session, isLoading: true)
        Task {
            do {
                let options = try await loadAgentTabOptions()
                await MainActor.run {
                    guard agentTabPalette?.sessionID == session.id else { return }
                    agentTabPalette = AgentTabPaletteState(session: session, options: options, isLoading: false)
                }
            } catch {
                await MainActor.run {
                    agentTabPalette = nil
                    userMessage = UserMessage(title: "Agent tabs unavailable", detail: String(describing: error))
                }
            }
        }
    }

    private func showSessionSearchPalette() {
        let rows = sessionSearchRows()
        guard !rows.isEmpty else {
            userMessage = UserMessage(title: "No sessions available", detail: "Create a session before searching for one.")
            return
        }

        agentTabPalette = nil
        sessionCommandPalette = nil
        sessionSearchPalette = SessionSearchPaletteState(rows: rows)
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

    private func openAgentTab(using option: SessionCommandOption) {
        guard let sessionID = agentTabPalette?.sessionID,
              let shortcutID = option.shortcutID
        else { return }
        agentTabPalette = nil

        Task {
            do {
                _ = try await commandService.createAgentTab(sessionID: sessionID, shortcutID: shortcutID)
            } catch {
                userMessage = UserMessage.commandFailure(error, fallbackTitle: "Agent tab could not be created")
            }
        }
    }

    private func selectSessionFromSearch(using row: SessionSearchRow) {
        sessionSearchPalette = nil

        Task {
            do {
                try await commandService.selectSession(id: row.sessionID)
            } catch {
                userMessage = UserMessage(title: "Session could not be selected", detail: String(describing: error))
            }
        }
    }

    private func loadSessionCommandOptions() async throws -> [SessionCommandOption] {
        let shortcuts = try await commandService.availableSessionShortcuts()
        var options: [SessionCommandOption] = [
            SessionCommandOption(
                title: "Plain Session",
                subtitle: "Start a shell in the selected project",
                shortcut: nil,
                fallbackSystemImage: "terminal"
            )
        ]

        options += shortcuts.map { shortcut in
            SessionCommandOption(
                title: shortcut.label,
                subtitle: shortcutDescription(for: shortcut),
                shortcut: shortcut,
                fallbackSystemImage: nil
            )
        }

        return options
    }

    private func loadAgentTabOptions() async throws -> [SessionCommandOption] {
        try await commandService.availableSessionShortcuts().map { shortcut in
            SessionCommandOption(
                title: shortcut.label,
                subtitle: "Open a new agent tab with the \(shortcut.label) profile",
                shortcut: shortcut,
                fallbackSystemImage: nil
            )
        }
    }

    private func shortcutDescription(for shortcut: SessionShortcut) -> String {
        if shortcut.isBuiltIn {
            return "Start a session with the \(shortcut.label) profile"
        }

        return "Run \(shortcut.launchCommand) in the selected project"
    }

    private func sessionSearchRows() -> [SessionSearchRow] {
        store.projects.flatMap { project in
            store.orderedSessions(for: project.id).map { session in
                SessionSearchRow(
                    sessionID: session.id,
                    sessionTitle: session.title,
                    projectName: project.displayName,
                    projectPath: project.path,
                    isSelected: session.id == store.selectedSessionID
                )
            }
        }
    }

    private func performSelectedFileCommand(_ commandID: AppCommandID) {
        guard let selectedTab = store.selectedTab, selectedTab.kind == .file else { return }
        Task {
            do {
                switch commandID {
                case .saveFile:
                    try await commandService.saveFileTab(tabID: selectedTab.id)
                    NotificationCenter.default.post(name: .fileBufferDirtyStateChanged, object: selectedTab.id)
                case .revertFile:
                    try await commandService.revertFileTab(tabID: selectedTab.id)
                    NotificationCenter.default.post(name: .fileBufferDirtyStateChanged, object: selectedTab.id)
                case .openFileInExternalEditor:
                    try await commandService.openFileInExternalEditor(tabID: selectedTab.id)
                case .openProjectSelector,
                     .newPlainTab,
                     .newDefaultAgentTab,
                     .newAgentTabWithProfile,
                     .closeSelectedTab,
                     .renameSelectedSession,
                     .renameSelectedTab,
                     .deleteSelectedSession,
                     .previousTab,
                     .nextTab,
                     .previousSession,
                     .nextSession,
                     .searchSessions,
                     .zoomInTerminal,
                     .zoomOutTerminal,
                     .toggleLeftSidebar,
                     .toggleRightSidebar,
                     .openSettings:
                    return
                }
            } catch {
                userMessage = UserMessage(title: fileCommandFailureTitle(for: commandID), detail: String(describing: error))
            }
        }
    }

    private func fileCommandFailureTitle(for commandID: AppCommandID) -> String {
        switch commandID {
        case .saveFile:
            return "File could not be saved"
        case .revertFile:
            return "File could not be reverted"
        case .openFileInExternalEditor:
            return "File could not be opened"
        case .openProjectSelector,
             .newPlainTab,
             .newDefaultAgentTab,
             .newAgentTabWithProfile,
             .closeSelectedTab,
             .renameSelectedSession,
             .renameSelectedTab,
             .deleteSelectedSession,
             .previousTab,
             .nextTab,
             .previousSession,
             .nextSession,
             .searchSessions,
             .zoomInTerminal,
             .zoomOutTerminal,
             .toggleLeftSidebar,
             .toggleRightSidebar,
             .openSettings:
            return "File command failed"
        }
    }
}

struct PilotDiagnosticsView: View {
    let diagnostics: PilotDiagnostics
    let onDismiss: () -> Void
    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Label("Pilot diagnostics need attention", systemImage: "waveform.path.ecg.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.warning.color)
                Spacer(minLength: 8)
                Button("Dismiss", systemImage: "xmark", action: onDismiss)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(theme.mutedText.color)
                    .help("Dismiss diagnostics")
            }
            Text(diagnostics.releaseBlockingReasons.joined(separator: " • "))
                .font(.caption)
                .foregroundStyle(theme.secondaryText.color)
            Text("Restore failures: \(percent(diagnostics.restoreFailureRate)) · Terminal failures: \(percent(diagnostics.terminalSurfaceFailureRate)) · File save failures: \(percent(diagnostics.fileSaveFailureRate))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(theme.mutedText.color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.elevatedBackground.color.opacity(0.96), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).stroke(theme.activeBorder.color.opacity(0.35), lineWidth: 1)
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
    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(theme.warning.color)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Workspace restored with recovery notes")
                        .font(.headline)
                        .foregroundStyle(theme.primaryText.color)
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(theme.secondaryText.color)
                }
                Spacer(minLength: 12)
                Button("Dismiss", action: dismiss)
                    .buttonStyle(.bordered)
            }

            ForEach(result.skippedProjects) { project in
                VStack(alignment: .leading, spacing: 3) {
                    Text("Skipped \(project.displayName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText.color)
                    Text(project.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(theme.mutedText.color)
                        .lineLimit(1)
                    Text(project.reason)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText.color)
                    HStack {
                        Button("Forget this project") {
                            forget(project)
                        }
                        .buttonStyle(.bordered)
                        Text("To restore it later, choose Open Project again after the folder is available.")
                            .font(.caption2)
                            .foregroundStyle(theme.mutedText.color)
                    }
                }
                .padding(10)
                .background(theme.shellBackground.color.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
            }

            ForEach(Array(visibleDiagnostics.enumerated()), id: \.offset) { _, diagnostic in
                VStack(alignment: .leading, spacing: 3) {
                    Text(diagnosticTitle(for: diagnostic))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText.color)
                    Text(diagnostic.message)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText.color)
                        .textSelection(.enabled)
                }
                .padding(10)
                .background(theme.shellBackground.color.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .background(theme.elevatedBackground.color.opacity(0.96), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.warning.color.opacity(0.65), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workspace restore recovery")
    }

    private var summary: String {
        if !visibleDiagnostics.isEmpty, result.skippedProjects.isEmpty {
            return "Some restored tabs could not be reopened. The available workspace metadata remains available."
        }
        if !visibleDiagnostics.isEmpty {
            return "\(result.skippedProjects.count) project folder(s) and some restored tabs need attention. Available workspace metadata remains available."
        }
        if result.skippedProjects.isEmpty {
            return "Some restored tabs could not be reopened. The workspace metadata remains available."
        }
        return "\(result.skippedProjects.count) project folder(s) could not be accessed. Reopen them from the Projects sidebar when available."
    }

    private var visibleDiagnostics: [RestoreDiagnostic] {
        result.diagnostics.filter { diagnostic in
            diagnostic.severity != .info &&
                diagnostic.message.hasPrefix("Skipped inaccessible restored project:") == false
        }
    }

    private func diagnosticTitle(for diagnostic: RestoreDiagnostic) -> String {
        if diagnostic.fileTabID != nil {
            return "Skipped restored file tab"
        }
        switch diagnostic.severity {
        case .failure:
            return "Restore failure"
        case .warning:
            return "Restore warning"
        case .info:
            return "Restore note"
        }
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

private enum SessionShortcutCatalogReloadReason {
    case initialLoad
    case profileMutation
}

struct ProjectSidebarView: View {
    let store: WorkspaceStore
    let commandService: any WorkspaceCommandService
    let terminalExitEvents: TerminalExitEventSource
    @Binding var userMessage: UserMessage?
    @Environment(\.shellThemePalette) private var theme
    @Environment(\.shellUIFontSize) private var uiFontSize
    @State private var pendingRemoval: WorkspaceProject?
    @State private var renameDraft: SessionRenameDraft?
    @State private var expandedProjectIDs: Set<UUID> = []
    @State private var hoveredSessionID: UUID?
    @State private var shortcutCatalog = SessionShortcutCatalog()
    @State private var terminalExitSnapshotsByTabID: [UUID: TerminalExitObservation] = [:]
    @State private var terminalExitUnsubscribe: TerminalExitEventSource.Unsubscribe?
    @State private var draggedProjectID: UUID?
    @State private var activeProjectInsertion: ProjectOrderInsertion?
    @StateObject private var projectDragLifecycle = ReorderDragLifecycleMonitor()

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
                    LazyVStack(alignment: .leading, spacing: 10) {
                        let projectIDs = store.projects.map(\.id)
                        ForEach(store.projects) { project in
                            let projectSessions = sessions(for: project.id)
                            let isExpanded = expandedProjectIDs.contains(project.id)
                            VStack(alignment: .leading, spacing: 10) {
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
                                .onDrag {
                                    beginDraggingProject(project.id)
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
                                                        terminalSummaries: terminalSummaries(for: session),
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
                                                            .overlay(theme.border.color.opacity(0.65))
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(10)
                            .background(theme.elevatedBackground.color.opacity(0.82), in: RoundedRectangle(cornerRadius: 18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(project.id == store.selectedProjectID ? theme.activeBorder.color.opacity(0.85) : theme.border.color.opacity(0.65), lineWidth: 1)
                            }
                            .modifier(ProjectSidebarDropTargetModifier(
                                targetProjectID: project.id,
                                currentProjectIDs: projectIDs,
                                draggedProjectID: $draggedProjectID,
                                activeInsertion: $activeProjectInsertion,
                                onDragEnded: endDraggingProject,
                                onCommit: submitProjectReorder
                            ))
                            .overlay(alignment: .top) {
                                projectInsertionIndicator(for: project.id, edge: .before)
                            }
                            .overlay(alignment: .bottom) {
                                projectInsertionIndicator(for: project.id, edge: .after)
                            }
                            .opacity(draggedProjectID == project.id ? 0.62 : 1)
                            .animation(.easeInOut(duration: 0.12), value: draggedProjectID)
                            .animation(.easeInOut(duration: 0.12), value: activeProjectInsertion)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(theme.sidebarBackground.color)
        .font(.system(size: uiFontSize))
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
        .onReceive(NotificationCenter.default.publisher(for: .showProjectSelector)) { _ in
            openProject()
        }
        .onReceive(NotificationCenter.default.publisher(for: .renameSelectedSession)) { _ in
            guard let selectedSession = store.selectedSession else { return }
            renameDraft = SessionRenameDraft(session: selectedSession)
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteSelectedSession)) { _ in
            guard let selectedSessionID = store.selectedSessionID else { return }
            removeSession(selectedSessionID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionShortcutCatalogDidChange)) { _ in
            Task { await reloadShortcutCatalog(reason: .profileMutation) }
        }
        .task {
            await reloadShortcutCatalog(reason: .initialLoad)
        }
        .onAppear(perform: startTerminalExitObservation)
        .onDisappear(perform: endDraggingProject)
        .onDisappear(perform: stopTerminalExitObservation)
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
            } catch WorkspaceCommandError.dirtyFileTabCloseRejected {
                userMessage = UserMessage(
                    title: "Project has unsaved file tabs",
                    detail: "Save or revert unsaved file tabs in this project before removing it from the workspace."
                )
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
            } catch WorkspaceCommandError.dirtyFileTabCloseRejected {
                userMessage = UserMessage(
                    title: "Session has unsaved file tabs",
                    detail: "Save or revert unsaved file tabs in this session before removing it."
                )
            } catch {
                userMessage = UserMessage(title: "Session could not be removed", detail: String(describing: error))
            }
        }
    }

    private func sessions(for projectID: UUID) -> [WorkspaceSession] {
        store.orderedSessions(for: projectID)
    }

    private func terminalSummaries(for session: WorkspaceSession) -> [SessionTerminalSummary] {
        SessionTerminalSummaryBuilder(
            store: store,
            shortcutCatalog: shortcutCatalog,
            exitSnapshot: { tabID in
                terminalExitSnapshotsByTabID[tabID] ?? terminalExitEvents.snapshot(tabID: tabID)
            }
        )
        .summaries(for: session)
    }

    private func reloadShortcutCatalog(reason: SessionShortcutCatalogReloadReason) async {
        do {
            let shortcuts = try await commandService.availableSessionShortcuts()
            shortcutCatalog = SessionShortcutCatalog(shortcuts: shortcuts)
        } catch {
            let title: String
            switch reason {
            case .initialLoad:
                title = "Agent profiles unavailable"
            case .profileMutation:
                title = "Agent profile refresh failed"
            }
            userMessage = UserMessage(title: title, detail: String(describing: error))
        }
    }

    private func startTerminalExitObservation() {
        guard terminalExitUnsubscribe == nil else { return }
        terminalExitUnsubscribe = terminalExitEvents.subscribe { observation in
            terminalExitSnapshotsByTabID[observation.tabID] = observation
        }
    }

    private func stopTerminalExitObservation() {
        terminalExitUnsubscribe?()
        terminalExitUnsubscribe = nil
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

    private func beginDraggingProject(_ id: UUID) -> NSItemProvider {
        let activeInsertion = $activeProjectInsertion
        projectDragLifecycle.begin(
            onEnd: clearProjectDragState,
            shouldFinishOnLocalMouseUp: { activeInsertion.wrappedValue == nil }
        )
        draggedProjectID = id
        activeProjectInsertion = nil
        return ProjectSidebarDrag.itemProvider(for: id)
    }

    private func endDraggingProject() {
        projectDragLifecycle.finish()
        clearProjectDragState()
    }

    private func clearProjectDragState() {
        draggedProjectID = nil
        activeProjectInsertion = nil
    }

    private func submitProjectReorder(moving movedProjectID: UUID, to insertion: ProjectOrderInsertion) {
        guard let orderedProjectIDs = ProjectReorderPayload.orderedProjectIDs(
            moving: movedProjectID,
            to: insertion,
            in: store.projects.map(\.id)
        ) else {
            return
        }

        Task {
            do {
                try await commandService.reorderProjects(orderedProjectIDs)
            } catch {
                userMessage = UserMessage(title: "Project order could not be saved", detail: String(describing: error))
            }
        }
    }

    @ViewBuilder
    private func projectInsertionIndicator(for projectID: UUID, edge: ProjectOrderInsertionEdge) -> some View {
        if activeProjectInsertion == ProjectOrderInsertion(targetProjectID: projectID, edge: edge) {
            ProjectInsertionIndicator(edge: edge)
        }
    }
}

private struct ProjectSidebarDropTargetModifier: ViewModifier {
    let targetProjectID: UUID
    let currentProjectIDs: [UUID]
    @Binding var draggedProjectID: UUID?
    @Binding var activeInsertion: ProjectOrderInsertion?
    let onDragEnded: () -> Void
    let onCommit: (UUID, ProjectOrderInsertion) -> Void
    @State private var targetHeight: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ProjectDropTargetHeightPreferenceKey.self,
                        value: max(proxy.size.height, 1)
                    )
                }
            }
            .onPreferenceChange(ProjectDropTargetHeightPreferenceKey.self) { height in
                targetHeight = max(height, 1)
            }
            .onDrop(
                of: [.text],
                delegate: ProjectSidebarDropDelegate(
                    targetProjectID: targetProjectID,
                    targetHeight: targetHeight,
                    currentProjectIDs: currentProjectIDs,
                    draggedProjectID: $draggedProjectID,
                    activeInsertion: $activeInsertion,
                    onDragEnded: onDragEnded,
                    onCommit: onCommit
                )
            )
    }
}

private enum ProjectSidebarDrag {
    static func itemProvider(for projectID: UUID) -> NSItemProvider {
        NSItemProvider(object: projectID.uuidString as NSString)
    }

    static func loadProjectID(from info: DropInfo, completion: @escaping (UUID?) -> Void) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.text.identifier]).first else {
            return false
        }

        let delivery = MainThreadUUIDDelivery(completion: completion)
        provider.loadObject(ofClass: NSString.self) { object, _ in
            let projectID = (object as? NSString)
                .map(String.init)
                .flatMap(UUID.init(uuidString:))

            delivery.schedule(projectID)
        }

        return true
    }
}

private struct ProjectDropTargetHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 1

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ProjectSidebarDropDelegate: DropDelegate {
    let targetProjectID: UUID
    let targetHeight: CGFloat
    let currentProjectIDs: [UUID]
    @Binding var draggedProjectID: UUID?
    @Binding var activeInsertion: ProjectOrderInsertion?
    let onDragEnded: () -> Void
    let onCommit: (UUID, ProjectOrderInsertion) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        proposedInsertion(for: info) != nil
    }

    func dropEntered(info: DropInfo) {
        updateActiveInsertion(for: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard updateActiveInsertion(for: info) else {
            return DropProposal(operation: .cancel)
        }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if activeInsertion?.targetProjectID == targetProjectID {
            activeInsertion = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        let didCommitDrop: Bool
        defer {
            onDragEnded()
        }

        guard let insertion = proposedInsertion(for: info) else {
            return false
        }

        didCommitDrop = ProjectSidebarDrag.loadProjectID(from: info) { movedProjectID in
            guard let movedProjectID else { return }
            onCommit(movedProjectID, insertion)
        }

        return didCommitDrop
    }

    @discardableResult
    private func updateActiveInsertion(for info: DropInfo) -> Bool {
        guard let insertion = proposedInsertion(for: info) else {
            if activeInsertion?.targetProjectID == targetProjectID {
                activeInsertion = nil
            }
            return false
        }

        activeInsertion = insertion
        return true
    }

    private func proposedInsertion(for info: DropInfo) -> ProjectOrderInsertion? {
        guard let draggedProjectID,
              draggedProjectID != targetProjectID,
              currentProjectIDs.contains(draggedProjectID),
              currentProjectIDs.contains(targetProjectID)
        else {
            return nil
        }

        let edge: ProjectOrderInsertionEdge = info.location.y < targetHeight / 2 ? .before : .after
        return ProjectOrderInsertion(targetProjectID: targetProjectID, edge: edge)
    }
}

private struct ProjectInsertionIndicator: View {
    let edge: ProjectOrderInsertionEdge
    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(theme.accent.color)
                .frame(width: 7, height: 7)
            Rectangle()
                .fill(theme.accent.color)
                .frame(height: 2)
        }
        .shadow(color: theme.accent.color.opacity(0.32), radius: 3, y: 1)
        .padding(.horizontal, 8)
        .offset(y: edge == .before ? -6 : 6)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ProjectRowView: View {
    let project: WorkspaceProject
    let isActive: Bool
    let isExpanded: Bool
    let onToggleDisclosure: () -> Void
    let onSelectProject: () -> Void
    let onRemove: () -> Void
    @Environment(\.shellThemePalette) private var theme
    @Environment(\.shellUIFontSize) private var uiFontSize

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggleDisclosure) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.mutedText.color)
                    .frame(width: 12)
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Collapse sessions" : "Expand sessions")

            Button(action: onSelectProject) {
                HStack(spacing: 10) {
                    Image(systemName: isActive ? "folder.fill" : "folder")
                        .foregroundStyle(isActive ? theme.selectedText.color : theme.accent.color)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.displayName)
                            .font(.system(size: uiFontSize + 1, weight: .semibold))
                            .foregroundStyle(theme.primaryText.color)
                            .lineLimit(1)
                        Text(project.path)
                            .font(.system(size: max(uiFontSize - 2, 10), design: .monospaced))
                            .foregroundStyle(theme.mutedText.color)
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
                    .foregroundStyle(theme.destructive.color)
                    .help("Remove selected project")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(isActive ? theme.activeBackground.color.opacity(0.42) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? theme.activeBorder.color : Color.clear, lineWidth: 1)
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
    @Environment(\.shellThemePalette) private var theme
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
        .background(theme.shellBackground.color)
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
    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText.color)
            Text(message)
                .font(.caption)
                .foregroundStyle(theme.secondaryText.color)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.shellBackground.color.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct SessionCommandOption: Identifiable, Equatable {
    let title: String
    let subtitle: String
    let shortcut: SessionShortcut?
    let fallbackSystemImage: String?

    var shortcutID: UUID? {
        shortcut?.id
    }

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

struct AgentTabPaletteState: Equatable {
    let sessionID: UUID
    let sessionTitle: String
    let options: [SessionCommandOption]
    let isLoading: Bool

    init(session: WorkspaceSession, options: [SessionCommandOption] = [], isLoading: Bool = true) {
        sessionID = session.id
        sessionTitle = session.title
        self.options = options
        self.isLoading = isLoading
    }
}

struct SessionCommandPaletteOverlay: View {
    let state: SessionCommandPaletteState
    let onClose: () -> Void
    let onSelect: (SessionCommandOption) -> Void
    @Environment(\.shellThemePalette) private var theme
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
                        .foregroundStyle(theme.mutedText.color)
                    TextField("Start session…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .foregroundStyle(theme.primaryText.color)
                        .focused($isSearchFocused)
                        .onSubmit {
                            if let first = filteredOptions.first {
                                onSelect(first)
                            }
                        }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)

                Divider().overlay(theme.border.color)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Commands for \(state.projectName)")
                        .font(.caption)
                        .foregroundStyle(theme.mutedText.color)

                    if state.isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Loading session commands…")
                                .foregroundStyle(theme.secondaryText.color)
                        }
                        .padding(.vertical, 16)
                    } else if filteredOptions.isEmpty {
                        Text("No matching commands")
                            .foregroundStyle(theme.secondaryText.color)
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

                Divider().overlay(theme.border.color)

                HStack {
                    Text("↩︎ Start first match")
                        .font(.caption2)
                        .foregroundStyle(theme.mutedText.color)
                    Spacer()
                    Button("Cancel", action: onClose)
                        .buttonStyle(.plain)
                        .keyboardShortcut(.cancelAction)
                        .foregroundStyle(theme.secondaryText.color)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(width: 720)
            .background(theme.shellBackground.color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(theme.border.color, lineWidth: 1)
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
    var isHighlighted: Bool = false
    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        HStack(spacing: 14) {
            AgentProfileIconView(shortcut: option.shortcut, fallbackSystemImage: option.fallbackSystemImage, size: 18)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(option.title)
                    .font(.headline)
                    .foregroundStyle(theme.primaryText.color)
                Text(option.subtitle)
                    .font(.callout)
                    .foregroundStyle(theme.secondaryText.color)
            }

            Spacer(minLength: 12)
            Image(systemName: "arrow.turn.down.left")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.mutedText.color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.elevatedBackground.color.opacity(0.92), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isHighlighted ? theme.activeBorder.color.opacity(0.9) : theme.border.color, lineWidth: 1)
        }
    }
}

struct AgentTabPaletteOverlay: View {
    let state: AgentTabPaletteState
    let onClose: () -> Void
    let onSelect: (SessionCommandOption) -> Void
    @Environment(\.shellThemePalette) private var theme
    @State private var query = ""
    @State private var highlightedIndex = 0

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
                        .foregroundStyle(theme.mutedText.color)
                    PaletteSearchField(
                        placeholder: "Open agent tab…",
                        text: $query,
                        onSubmit: {
                            if let option = selectedOption {
                                onSelect(option)
                            }
                        },
                        onMoveUp: { handleMoveCommand(.up) },
                        onMoveDown: { handleMoveCommand(.down) },
                        textColor: NSColor(theme.primaryText.color),
                        placeholderColor: NSColor(theme.mutedText.color)
                    )
                    .frame(height: 28)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)

                Divider().overlay(theme.border.color)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Profiles for \(state.sessionTitle)")
                        .font(.caption)
                        .foregroundStyle(theme.mutedText.color)

                    if state.isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Loading agent profiles…")
                                .foregroundStyle(theme.secondaryText.color)
                        }
                        .padding(.vertical, 16)
                    } else if filteredOptions.isEmpty {
                        Text("No matching profiles")
                            .foregroundStyle(theme.secondaryText.color)
                            .padding(.vertical, 16)
                    } else {
                        ForEach(Array(filteredOptions.enumerated()), id: \.element.id) { index, option in
                            Button(action: { onSelect(option) }) {
                                SessionCommandPaletteRow(option: option, isHighlighted: index == highlightedIndex)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)

                Divider().overlay(theme.border.color)

                HStack {
                    Text("↩︎ Open first match")
                        .font(.caption2)
                        .foregroundStyle(theme.mutedText.color)
                    Spacer()
                    Button("Cancel", action: onClose)
                        .buttonStyle(.plain)
                        .keyboardShortcut(.cancelAction)
                        .foregroundStyle(theme.secondaryText.color)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(width: 720)
            .background(theme.shellBackground.color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(theme.border.color, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 30, y: 12)
        }
        .onChange(of: query) { _, _ in
            highlightedIndex = 0
        }
        .onChange(of: state.options) { _, _ in
            highlightedIndex = 0
        }
    }

    private var selectedOption: SessionCommandOption? {
        guard !filteredOptions.isEmpty else { return nil }
        return filteredOptions[min(max(highlightedIndex, 0), filteredOptions.count - 1)]
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        guard !filteredOptions.isEmpty else { return }
        switch direction {
        case .down:
            highlightedIndex = (highlightedIndex + 1) % filteredOptions.count
        case .up:
            highlightedIndex = (highlightedIndex - 1 + filteredOptions.count) % filteredOptions.count
        default:
            return
        }
    }

}

struct SessionSearchRow: Identifiable, Equatable {
    let sessionID: UUID
    let sessionTitle: String
    let projectName: String
    let projectPath: String
    let isSelected: Bool

    var id: UUID { sessionID }
}

struct SessionSearchPaletteState: Equatable {
    let rows: [SessionSearchRow]
}

struct SessionSearchPaletteOverlay: View {
    let state: SessionSearchPaletteState
    let onClose: () -> Void
    let onSelect: (SessionSearchRow) -> Void
    @Environment(\.shellThemePalette) private var theme
    @State private var query = ""
    @State private var highlightedIndex = 0

    private var filteredRows: [SessionSearchRow] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return state.rows }

        return state.rows.filter { row in
            row.sessionTitle.localizedCaseInsensitiveContains(trimmedQuery) ||
                row.projectName.localizedCaseInsensitiveContains(trimmedQuery) ||
                row.projectPath.localizedCaseInsensitiveContains(trimmedQuery)
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
                        .foregroundStyle(theme.mutedText.color)
                    PaletteSearchField(
                        placeholder: "Search sessions…",
                        text: $query,
                        onSubmit: {
                            if let row = selectedRow {
                                onSelect(row)
                            }
                        },
                        onMoveUp: { handleMoveCommand(.up) },
                        onMoveDown: { handleMoveCommand(.down) },
                        textColor: NSColor(theme.primaryText.color),
                        placeholderColor: NSColor(theme.mutedText.color)
                    )
                    .frame(height: 28)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)

                Divider().overlay(theme.border.color)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Search across all project sessions")
                        .font(.caption)
                        .foregroundStyle(theme.mutedText.color)

                    if filteredRows.isEmpty {
                        Text("No matching sessions")
                            .foregroundStyle(theme.secondaryText.color)
                            .padding(.vertical, 16)
                    } else {
                        ForEach(Array(filteredRows.enumerated()), id: \.element.id) { index, row in
                            Button(action: { onSelect(row) }) {
                                SessionSearchPaletteRow(row: row, isHighlighted: index == highlightedIndex)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)

                Divider().overlay(theme.border.color)

                HStack {
                    Text("↩︎ Select first match")
                        .font(.caption2)
                        .foregroundStyle(theme.mutedText.color)
                    Spacer()
                    Button("Cancel", action: onClose)
                        .buttonStyle(.plain)
                        .keyboardShortcut(.cancelAction)
                        .foregroundStyle(theme.secondaryText.color)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(width: 720)
            .background(theme.shellBackground.color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(theme.border.color, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 30, y: 12)
        }
        .onChange(of: query) { _, _ in
            highlightedIndex = 0
        }
        .onChange(of: state.rows) { _, _ in
            highlightedIndex = 0
        }
    }

    private var selectedRow: SessionSearchRow? {
        guard !filteredRows.isEmpty else { return nil }
        return filteredRows[min(max(highlightedIndex, 0), filteredRows.count - 1)]
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        guard !filteredRows.isEmpty else { return }
        switch direction {
        case .down:
            highlightedIndex = (highlightedIndex + 1) % filteredRows.count
        case .up:
            highlightedIndex = (highlightedIndex - 1 + filteredRows.count) % filteredRows.count
        default:
            return
        }
    }

}

private struct PaletteSearchField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let onSubmit: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let textColor: NSColor
    let placeholderColor: NSColor

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            onSubmit: onSubmit,
            onMoveUp: onMoveUp,
            onMoveDown: onMoveDown
        )
    }

    func makeNSView(context: Context) -> PaletteTextField {
        let field = PaletteTextField(frame: .zero)
        field.isBordered = false
        field.focusRingType = .none
        field.drawsBackground = false
        field.font = .systemFont(ofSize: NSFont.preferredFont(forTextStyle: .title3).pointSize)
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.stringValue = text
        field.textColor = textColor
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: placeholderColor]
        )
        field.onSubmit = onSubmit
        field.onMoveUp = onMoveUp
        field.onMoveDown = onMoveDown
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ nsView: PaletteTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.textColor = textColor
        nsView.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: placeholderColor]
        )
        nsView.onSubmit = onSubmit
        nsView.onMoveUp = onMoveUp
        nsView.onMoveDown = onMoveDown
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onMoveUp = onMoveUp
        context.coordinator.onMoveDown = onMoveDown
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        var onSubmit: () -> Void
        var onMoveUp: () -> Void
        var onMoveDown: () -> Void

        init(
            text: Binding<String>,
            onSubmit: @escaping () -> Void,
            onMoveUp: @escaping () -> Void,
            onMoveDown: @escaping () -> Void
        ) {
            _text = text
            self.onSubmit = onSubmit
            self.onMoveUp = onMoveUp
            self.onMoveDown = onMoveDown
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                onSubmit()
                return true
            case #selector(NSResponder.moveUp(_:)):
                onMoveUp()
                return true
            case #selector(NSResponder.moveDown(_:)):
                onMoveDown()
                return true
            default:
                return false
            }
        }
    }
}

private final class PaletteTextField: NSTextField {
    var onSubmit: () -> Void = {}
    var onMoveUp: () -> Void = {}
    var onMoveDown: () -> Void = {}

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126:
            onMoveUp()
        case 125:
            onMoveDown()
        case 36, 76:
            onSubmit()
        default:
            super.keyDown(with: event)
        }
    }
}

struct SessionSearchPaletteRow: View {
    let row: SessionSearchRow
    var isHighlighted: Bool = false
    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: row.isSelected ? "rectangle.stack.fill" : "rectangle.stack")
                .font(.headline)
                .foregroundStyle(row.isSelected ? theme.selectedText.color : theme.secondaryAccent.color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(row.sessionTitle)
                        .font(.headline)
                        .foregroundStyle(theme.primaryText.color)
                    if row.isSelected {
                        Text("Current")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.accent.color)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(theme.accent.color.opacity(0.12), in: Capsule())
                    }
                }
                Text("\(row.projectName) · \(row.projectPath)")
                    .font(.callout)
                    .foregroundStyle(theme.secondaryText.color)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)
            Image(systemName: "arrow.turn.down.left")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.mutedText.color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.elevatedBackground.color.opacity(0.92), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke((row.isSelected || isHighlighted) ? theme.activeBorder.color.opacity(0.9) : theme.border.color, lineWidth: 1)
        }
    }
}

struct SessionRowView: View {
    let session: WorkspaceSession
    var terminalSummaries: [SessionTerminalSummary] = []
    let isActive: Bool
    let showsMenu: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    @Environment(\.shellThemePalette) private var theme
    @Environment(\.shellUIFontSize) private var uiFontSize

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    Image(systemName: isActive ? "rectangle.stack.fill" : "rectangle.stack")
                        .foregroundStyle(isActive ? theme.selectedText.color : theme.secondaryAccent.color)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(session.title)
                            .font(.system(size: uiFontSize, weight: .semibold))
                            .foregroundStyle(theme.primaryText.color)
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
                        .background(theme.shellBackground.color.opacity(0.85), in: Circle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Session actions")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(isActive ? theme.activeBackground.color.opacity(0.32) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? theme.activeBorder.color : Color.clear, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(session.title)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        let sessionState = isActive ? "Active session" : "Session"
        guard !terminalSummaries.isEmpty else {
            return sessionState
        }

        return "\(sessionState), \(terminalSummaries.count) terminal tab\(terminalSummaries.count == 1 ? "" : "s")"
    }
}

struct SessionRenameView: View {
    let draft: SessionRenameDraft
    let onSave: (UUID, String) -> Void
    let onCancel: () -> Void
    @Environment(\.shellThemePalette) private var theme
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
                .foregroundStyle(theme.primaryText.color)
            Text("Give this project session a clear purpose so it is easy to resume later.")
                .foregroundStyle(theme.secondaryText.color)
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
        .background(theme.elevatedBackground.color)
        .onAppear { focusedField = true }
    }

    private func save() {
        onSave(draft.id, title)
    }
}

struct TabRenameView: View {
    let draft: TabRenameDraft
    let onSave: (UUID, String?) -> Void
    let onCancel: () -> Void
    @Environment(\.shellThemePalette) private var theme
    @State private var title: String
    @FocusState private var focusedField: Bool

    init(draft: TabRenameDraft, onSave: @escaping (UUID, String?) -> Void, onCancel: @escaping () -> Void) {
        self.draft = draft
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: draft.currentTitle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename Tab")
                .font(.title2.weight(.semibold))
                .foregroundStyle(theme.primaryText.color)
            Text("Change this tab title without renaming anything on disk.")
                .foregroundStyle(theme.secondaryText.color)
            TextField(draft.placeholderTitle, text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField)
                .onSubmit(save)
            Text("Leave empty to restore the default title.")
                .font(.caption)
                .foregroundStyle(theme.mutedText.color)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(theme.elevatedBackground.color)
        .onAppear { focusedField = true }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(draft.id, trimmedTitle.isEmpty ? nil : trimmedTitle)
    }
}

struct WorkspaceDetailView: View {
    let store: WorkspaceStore
    let commandService: any WorkspaceCommandService
    let terminalHostController: TerminalHostController
    let fileAccessService: any WorkspaceFileAccessing
    let fileBufferController: any WorkspaceFileBufferManaging
    @Binding var userMessage: UserMessage?
    let onOpenSettings: () -> Void
    let isSidebarCollapsed: Bool
    @Environment(\.shellThemePalette) private var theme
    @State private var isFileWorkspaceSidebarVisible = true

    var body: some View {
        let shouldShowTabRow = FocusWorkspacePolicy.shouldShowTabRow(
            in: store.selectedFocusWorkspaceSessionState
        )
        VStack(spacing: 0) {
            ActiveContextBanner(
                project: store.selectedProject,
                session: store.selectedSession,
                focusWorkspaceCue: FocusWorkspaceActiveCuePresentation(preferences: store.appPreferences),
                onShowSessionCommands: showSessionCommandPalette,
                onOpenSettings: onOpenSettings,
                isSidebarCollapsed: isSidebarCollapsed
            )
            TabChromeView(
                store: store,
                commandService: commandService,
                fileBufferController: fileBufferController,
                userMessage: $userMessage
            )
            .frame(height: shouldShowTabRow ? 42 : 0)
            .opacity(shouldShowTabRow ? 1 : 0)
            .accessibilityHidden(!shouldShowTabRow)
            .clipped()
            Divider().overlay(theme.border.color)
            HStack(spacing: 0) {
                WorkspacePrimaryHostAreaView(
                    store: store,
                    commandService: commandService,
                    terminalHostController: terminalHostController,
                    fileBufferController: fileBufferController,
                    userMessage: $userMessage
                )
                .frame(minWidth: 420)

                if isFileWorkspaceSidebarVisible {
                    FileWorkspaceSidebarView(
                        store: store,
                        commandService: commandService,
                        fileAccessService: fileAccessService,
                        userMessage: $userMessage
                    )
                    .frame(width: 340)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .background(theme.contentBackground.color)
        .ignoresSafeArea(.container, edges: .top)
        .onReceive(NotificationCenter.default.publisher(for: .toggleFileWorkspaceSidebar)) { _ in
            toggleFileWorkspaceSidebar()
        }
        .onReceive(NotificationCenter.default.publisher(for: .createPlainTab)) { _ in
            createPlainTabFromCommand()
        }
        .onReceive(NotificationCenter.default.publisher(for: .createDefaultAgentTab)) { _ in
            createDefaultAgentTabFromCommand()
        }
    }

    private func showSessionCommandPalette() {
        NotificationCenter.default.post(name: .showSessionCommandPalette, object: nil)
    }

    private func toggleFileWorkspaceSidebar() {
        withAnimation(.easeInOut(duration: 0.16)) {
            isFileWorkspaceSidebarVisible.toggle()
        }
    }

    private func createPlainTabFromCommand() {
        guard let selectedSessionID = store.selectedSessionID else {
            userMessage = UserMessage(title: "Session required", detail: "Select a session before creating a new tab.")
            return
        }
        Task {
            do {
                _ = try await commandService.createPlainTab(sessionID: selectedSessionID)
            } catch {
                userMessage = UserMessage.commandFailure(error, fallbackTitle: "Tab could not be created")
            }
        }
    }

    private func createDefaultAgentTabFromCommand() {
        guard let selectedSessionID = store.selectedSessionID else {
            userMessage = UserMessage(title: "Session required", detail: "Select a session before creating a new agent tab.")
            return
        }
        Task {
            do {
                _ = try await commandService.createDefaultAgentTab(sessionID: selectedSessionID)
            } catch {
                userMessage = UserMessage.commandFailure(error, fallbackTitle: "Agent tab could not be created")
            }
        }
    }
}

struct ActiveContextBanner: View {
    let project: WorkspaceProject?
    let session: WorkspaceSession?
    let focusWorkspaceCue: FocusWorkspaceActiveCuePresentation
    let onShowSessionCommands: () -> Void
    let onOpenSettings: () -> Void
    let isSidebarCollapsed: Bool
    @Environment(\.shellThemePalette) private var theme
    @Environment(\.shellUIFontSize) private var uiFontSize

    var body: some View {
        HStack(spacing: 12) {
            Label(project?.displayName ?? "No project selected", systemImage: project == nil ? "exclamationmark.triangle" : "folder.fill")
                .font(.system(size: uiFontSize + 1, weight: .semibold))
            Image(systemName: "chevron.right")
                .foregroundStyle(theme.mutedText.color)
            Label(session?.title ?? "No session selected", systemImage: session == nil ? "rectangle.stack" : "rectangle.stack.fill")
                .font(.system(size: uiFontSize, weight: .semibold))
            Spacer()
            if focusWorkspaceCue.isVisible {
                FocusWorkspaceActiveCueView()
            }
            Button(action: onShowSessionCommands) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(theme.shellBackground.color.opacity(0.7), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.primaryText.color)
            .help("Start session commands")

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(theme.shellBackground.color.opacity(0.7), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.primaryText.color)
            .help("Settings")
        }
        .padding(.leading, isSidebarCollapsed ? 150 : 16)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
        .foregroundStyle(theme.primaryText.color)
        .background(theme.elevatedBackground.color)
    }
}

private struct FocusWorkspaceActiveCueView: View {
    @Environment(\.shellThemePalette) private var theme
    @Environment(\.shellUIFontSize) private var uiFontSize

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "viewfinder.circle.fill")
                .font(.system(size: uiFontSize - 1, weight: .semibold))
            Text(FocusWorkspaceActiveCuePresentation.label)
                .font(.system(size: max(uiFontSize - 2, 11.0), weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(theme.accent.color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(theme.accent.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(theme.accent.color.opacity(0.32), lineWidth: 1)
        }
        .accessibilityLabel(FocusWorkspaceActiveCuePresentation.accessibilityLabel)
        .help(FocusWorkspaceActiveCuePresentation.helpText)
    }
}

struct TabChromeView: View {
    let store: WorkspaceStore
    let commandService: any WorkspaceCommandService
    let fileBufferController: any WorkspaceFileBufferManaging
    @Binding var userMessage: UserMessage?
    @Environment(\.shellThemePalette) private var theme
    @State private var dirtyRefreshToken = 0
    @State private var pendingCloseConfirmation: TabCloseConfirmation?
    @State private var renameDraft: TabRenameDraft?
    @State private var draggedTabID: UUID?
    @State private var activeTabInsertion: TabOrderInsertion?
    @StateObject private var tabDragLifecycle = ReorderDragLifecycleMonitor()

    var body: some View {
        let _ = dirtyRefreshToken
        let visibleTabs = store.tabsForSelectedSession
        let visibleTabIDs = visibleTabs.map(\.id)
        let shouldShowCreateTabButton = FocusWorkspacePolicy.shouldShowTerminalCreationAffordance(
            in: store.selectedFocusWorkspaceSessionState
        )
        ScrollView(.horizontal) {
            HStack(spacing: 1) {
                if visibleTabs.isEmpty {
                    Text(store.selectedSessionID == nil ? "Select a session to see tabs" : "No tabs in this session yet")
                        .font(.callout)
                        .foregroundStyle(theme.mutedText.color)
                } else {
                    ForEach(visibleTabs) { tab in
                        ZStack {
                            TabItemView(
                                tab: tab,
                                legacySessionShortcutID: store.selectedSession?.shortcutID,
                                isActive: tab.id == store.selectedTabID,
                                isDirty: tab.kind == .file && fileBufferController.isDirty(tabID: tab.id),
                                isReordering: draggedTabID != nil,
                                onSelect: { selectTab(tab.id) },
                                onDragStarted: { beginDraggingTab(tab.id) },
                                onRename: {
                                    renameDraft = TabRenameDraft(
                                        tab: tab,
                                        legacySessionShortcutID: store.selectedSession?.shortcutID
                                    )
                                },
                                onClose: { closeTab(tab.id) }
                            )
                        }
                        .contentShape(Rectangle())
                        .modifier(TabChromeDropTargetModifier(
                            targetTabID: tab.id,
                            currentTabIDs: visibleTabIDs,
                            draggedTabID: $draggedTabID,
                            activeInsertion: $activeTabInsertion,
                            onDragEnded: endDraggingTab,
                            onCommit: submitTabReorder
                        ))
                        .overlay(alignment: .leading) {
                            tabInsertionIndicator(for: tab.id, edge: .before)
                        }
                        .overlay(alignment: .trailing) {
                            tabInsertionIndicator(for: tab.id, edge: .after)
                        }
                        .opacity(draggedTabID == tab.id ? 0.62 : 1)
                        .animation(.easeInOut(duration: 0.12), value: draggedTabID)
                        .animation(.easeInOut(duration: 0.12), value: activeTabInsertion)
                    }
                }

                if shouldShowCreateTabButton {
                    Button(action: createPlainTab) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(theme.elevatedBackground.color.opacity(store.selectedSessionID == nil ? 0.3 : 0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(theme.border.color.opacity(0.85), lineWidth: 1)
                            }
                        }
                    .buttonStyle(.plain)
                    .disabled(store.selectedSessionID == nil)
                    .help("New tab (⌘T)")
                    .padding(.leading, 4)
                    .padding(.trailing, 12)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 0)
        }
        .frame(height: 42)
        .background(theme.tabBarBackground.color)
        .alert(
            pendingCloseConfirmation?.title ?? "Close tab?",
            isPresented: closeConfirmationPresented,
            presenting: pendingCloseConfirmation
        ) { confirmation in
            Button("Cancel", role: .cancel) {
                pendingCloseConfirmation = nil
            }
            Button("Force Close", role: .destructive) {
                forceCloseTab(confirmation.tabID)
            }
        } message: { confirmation in
            Text(confirmation.detail)
        }
        .onReceive(NotificationCenter.default.publisher(for: .fileBufferDirtyStateChanged)) { _ in
            dirtyRefreshToken += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeSelectedTab)) { _ in
            closeSelectedTab()
        }
        .onReceive(NotificationCenter.default.publisher(for: .renameSelectedTab)) { _ in
            guard let selectedTab = store.selectedTab else { return }
            renameDraft = TabRenameDraft(
                tab: selectedTab,
                legacySessionShortcutID: store.selectedSession?.shortcutID
            )
        }
        .onChange(of: visibleTabIDs) { _, updatedTabIDs in
            if let draggedTabID, !updatedTabIDs.contains(draggedTabID) {
                endDraggingTab()
            }
            if let activeTabInsertion, !updatedTabIDs.contains(activeTabInsertion.targetTabID) {
                self.activeTabInsertion = nil
            }
        }
        .onDisappear(perform: endDraggingTab)
        .sheet(item: $renameDraft) { draft in
            TabRenameView(draft: draft) { tabID, title in
                Task {
                    do {
                        _ = try await commandService.renameTab(tabID: tabID, title: title)
                        renameDraft = nil
                    } catch {
                        userMessage = UserMessage(title: "Tab could not be renamed", detail: String(describing: error))
                    }
                }
            } onCancel: {
                renameDraft = nil
            }
        }
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
        let forceClose = store.tab(id: id)?.kind == .terminal
        Task {
            do {
                try await commandService.closeTab(tabID: id, force: forceClose)
            } catch WorkspaceCommandError.dirtyFileTabCloseRejected {
                pendingCloseConfirmation = TabCloseConfirmation(
                    tabID: id,
                    title: "File has unsaved changes",
                    detail: "Closing this file will discard its unsaved changes."
                )
            } catch {
                userMessage = UserMessage(title: "Tab could not be closed", detail: String(describing: error))
            }
        }
    }

    private func forceCloseTab(_ id: UUID) {
        pendingCloseConfirmation = nil
        Task {
            do {
                try await commandService.closeTab(tabID: id, force: true)
            } catch {
                userMessage = UserMessage(title: "Tab could not be closed", detail: String(describing: error))
            }
        }
    }

    private func createPlainTab() {
        guard let selectedSessionID = store.selectedSessionID else {
            userMessage = UserMessage(title: "Session required", detail: "Select a session before creating a new tab.")
            return
        }
        Task {
            do {
                _ = try await commandService.createPlainTab(sessionID: selectedSessionID)
            } catch {
                userMessage = UserMessage.commandFailure(error, fallbackTitle: "Tab could not be created")
            }
        }
    }

    private func closeSelectedTab() {
        guard let selectedTabID = store.selectedTabID else { return }
        closeTab(selectedTabID)
    }

    private func beginDraggingTab(_ id: UUID) -> NSItemProvider {
        let activeInsertion = $activeTabInsertion
        tabDragLifecycle.begin(
            onEnd: clearTabDragState,
            shouldFinishOnLocalMouseUp: { activeInsertion.wrappedValue == nil }
        )
        draggedTabID = id
        activeTabInsertion = nil
        return TabChromeDrag.itemProvider(for: id)
    }

    private func endDraggingTab() {
        tabDragLifecycle.finish()
        clearTabDragState()
    }

    private func clearTabDragState() {
        draggedTabID = nil
        activeTabInsertion = nil
    }

    private func submitTabReorder(moving movedTabID: UUID, to insertion: TabOrderInsertion) {
        guard let selectedSessionID = store.selectedSessionID,
              let orderedVisibleTabIDs = TabReorderPayload.orderedVisibleTabIDs(
                moving: movedTabID,
                to: insertion,
                in: store.tabsForSelectedSession.map(\.id)
              )
        else {
            return
        }

        Task {
            do {
                try await commandService.reorderTabs(
                    sessionID: selectedSessionID,
                    orderedVisibleTabIDs: orderedVisibleTabIDs
                )
            } catch {
                userMessage = UserMessage(title: "Tab order could not be saved", detail: String(describing: error))
            }
        }
    }

    @ViewBuilder
    private func tabInsertionIndicator(for tabID: UUID, edge: TabOrderInsertionEdge) -> some View {
        if activeTabInsertion == TabOrderInsertion(targetTabID: tabID, edge: edge) {
            TabInsertionIndicator(edge: edge)
        }
    }

    private var closeConfirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingCloseConfirmation != nil },
            set: { isPresented in
                if !isPresented {
                    pendingCloseConfirmation = nil
                }
            }
        )
    }
}

private struct TabChromeDropTargetModifier: ViewModifier {
    let targetTabID: UUID
    let currentTabIDs: [UUID]
    @Binding var draggedTabID: UUID?
    @Binding var activeInsertion: TabOrderInsertion?
    let onDragEnded: () -> Void
    let onCommit: (UUID, TabOrderInsertion) -> Void
    @State private var targetWidth: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: TabDropTargetWidthPreferenceKey.self,
                        value: max(proxy.size.width, 1)
                    )
                }
            }
            .onPreferenceChange(TabDropTargetWidthPreferenceKey.self) { width in
                targetWidth = max(width, 1)
            }
            .onDrop(
                of: [.text],
                delegate: TabChromeDropDelegate(
                    targetTabID: targetTabID,
                    targetWidth: targetWidth,
                    currentTabIDs: currentTabIDs,
                    draggedTabID: $draggedTabID,
                    activeInsertion: $activeInsertion,
                    onDragEnded: onDragEnded,
                    onCommit: onCommit
                )
            )
    }
}

private enum TabChromeDrag {
    static func itemProvider(for tabID: UUID) -> NSItemProvider {
        NSItemProvider(object: tabID.uuidString as NSString)
    }

    static func loadTabID(from info: DropInfo, completion: @escaping (UUID?) -> Void) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.text.identifier]).first else {
            return false
        }

        let delivery = MainThreadUUIDDelivery(completion: completion)
        provider.loadObject(ofClass: NSString.self) { object, _ in
            let tabID = (object as? NSString)
                .map(String.init)
                .flatMap(UUID.init(uuidString:))

            delivery.schedule(tabID)
        }

        return true
    }
}

private struct TabDropTargetWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 1

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct TabChromeDropDelegate: DropDelegate {
    let targetTabID: UUID
    let targetWidth: CGFloat
    let currentTabIDs: [UUID]
    @Binding var draggedTabID: UUID?
    @Binding var activeInsertion: TabOrderInsertion?
    let onDragEnded: () -> Void
    let onCommit: (UUID, TabOrderInsertion) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        proposedInsertion(for: info) != nil
    }

    func dropEntered(info: DropInfo) {
        updateActiveInsertion(for: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard updateActiveInsertion(for: info) else {
            return DropProposal(operation: .cancel)
        }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if activeInsertion?.targetTabID == targetTabID {
            activeInsertion = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        let didCommitDrop: Bool
        defer {
            onDragEnded()
        }

        guard let insertion = proposedInsertion(for: info) else {
            return false
        }

        didCommitDrop = TabChromeDrag.loadTabID(from: info) { movedTabID in
            guard let movedTabID else { return }
            onCommit(movedTabID, insertion)
        }

        return didCommitDrop
    }

    @discardableResult
    private func updateActiveInsertion(for info: DropInfo) -> Bool {
        guard let insertion = proposedInsertion(for: info) else {
            if activeInsertion?.targetTabID == targetTabID {
                activeInsertion = nil
            }
            return false
        }

        activeInsertion = insertion
        return true
    }

    private func proposedInsertion(for info: DropInfo) -> TabOrderInsertion? {
        guard let draggedTabID,
              draggedTabID != targetTabID,
              currentTabIDs.contains(draggedTabID),
              currentTabIDs.contains(targetTabID)
        else {
            return nil
        }

        let edge: TabOrderInsertionEdge = info.location.x < targetWidth / 2 ? .before : .after
        return TabOrderInsertion(targetTabID: targetTabID, edge: edge)
    }
}

private struct TabInsertionIndicator: View {
    let edge: TabOrderInsertionEdge
    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(theme.accent.color)
                .frame(width: 7, height: 7)
            Rectangle()
                .fill(theme.accent.color)
                .frame(width: 2, height: 30)
        }
        .shadow(color: theme.accent.color.opacity(0.32), radius: 3, y: 1)
        .offset(x: edge == .before ? -5 : 5)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct TabCloseConfirmation: Identifiable {
    let tabID: UUID
    let title: String
    let detail: String

    var id: UUID { tabID }
}

struct TabItemView: View {
    let tab: WorkspaceTab
    let legacySessionShortcutID: UUID?
    let isActive: Bool
    let isDirty: Bool
    let isReordering: Bool
    let onSelect: () -> Void
    let onDragStarted: () -> NSItemProvider
    let onRename: () -> Void
    let onClose: () -> Void
    private let terminalPresentationResolver = SessionTerminalPresentationResolver()
    @Environment(\.shellThemePalette) private var theme
    @State private var isHovered = false

    init(
        tab: WorkspaceTab,
        legacySessionShortcutID: UUID?,
        isActive: Bool,
        isDirty: Bool,
        isReordering: Bool,
        onSelect: @escaping () -> Void,
        onDragStarted: @escaping () -> NSItemProvider,
        onRename: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.tab = tab
        self.legacySessionShortcutID = legacySessionShortcutID
        self.isActive = isActive
        self.isDirty = isDirty
        self.isReordering = isReordering
        self.onSelect = onSelect
        self.onDragStarted = onDragStarted
        self.onRename = onRename
        self.onClose = onClose
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 8) {
                tabIcon
                Text(resolvedTitle)
                    .lineLimit(1)
                if isDirty {
                    Circle()
                        .fill(theme.warning.color)
                        .frame(width: 6, height: 6)
                        .accessibilityLabel("Unsaved changes")
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .foregroundStyle(isActive ? theme.primaryText.color : theme.secondaryText.color)
            .onTapGesture(perform: onSelect)
            .onDrag {
                onDragStarted()
            }

            if !isReordering && (isActive || isHovered) {
                Button("Close tab", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isActive ? theme.secondaryText.color : theme.mutedText.color)
                    .frame(width: 18, height: 18)
                    .background(theme.elevatedBackground.color.opacity(0.65), in: Circle())
                    .help(closeHelp)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.top, 9)
        .padding(.bottom, 8)
        .frame(minWidth: 140, idealWidth: 180, maxWidth: 220)
        .background(tabBackground, in: tabShape)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isActive ? theme.contentBackground.color : theme.border.color.opacity(0.25))
                .frame(height: isActive ? 2 : 1)
                .offset(y: 1)
        }
        .overlay {
            tabShape.stroke(tabBorderColor, lineWidth: isActive ? 1.2 : 1)
        }
        .overlay(alignment: .leading) {
            if !isActive {
                Rectangle()
                    .fill(theme.border.color.opacity(0.4))
                    .frame(width: 1)
                    .padding(.vertical, 8)
            }
        }
        .contentShape(tabShape)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Rename Tab", systemImage: "pencil", action: onRename)
            Button("Close Tab", systemImage: "xmark", action: onClose)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isActive ? "Active tab" : "Tab")
    }

    var resolvedTitle: String {
        if let customTitle = tab.title?.trimmingCharacters(in: .whitespacesAndNewlines), !customTitle.isEmpty {
            return customTitle
        }

        return defaultTabTitle
    }

    private var defaultTabTitle: String {
        if tab.kind == .file, let filePath = tab.fileReference?.path {
            let fileName = URL(fileURLWithPath: filePath).lastPathComponent
            return fileName.isEmpty ? filePath : fileName
        }

        if tab.kind == .terminal {
            return terminalPresentation?.title ?? "Terminal"
        }

        let directoryName = URL(fileURLWithPath: tab.workingDirectory).lastPathComponent
        return directoryName.isEmpty ? tab.workingDirectory : directoryName
    }

    private var iconName: String {
        switch tab.kind {
        case .terminal:
            return terminalPresentation?.fallbackSystemImage(isActive: isActive) ?? (isActive ? "terminal.fill" : "terminal")
        case .file:
            return isActive ? "doc.text.fill" : "doc.text"
        }
    }

    @ViewBuilder
    private var tabIcon: some View {
        if tab.kind == .terminal,
           let iconShortcut = terminalPresentation?.iconShortcut {
            AgentProfileIconView(
                shortcut: iconShortcut,
                fallbackSystemImage: nil,
                size: 18
            )
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
        }
    }

    private var terminalPresentation: SessionTerminalPresentation? {
        terminalPresentationResolver.resolve(tab: tab, legacySessionShortcutID: legacySessionShortcutID)
    }

    private var closeHelp: String {
        switch tab.kind {
        case .terminal:
            return "Close terminal tab"
        case .file:
            return isDirty ? "Close file tab with unsaved changes" : "Close file tab"
        }
    }

    private var accessibilityLabel: String {
        switch tab.kind {
        case .terminal:
            return "Terminal tab \(resolvedTitle) in \(tab.workingDirectory)"
        case .file:
            return isDirty ? "Unsaved file tab \(resolvedTitle)" : "File tab \(resolvedTitle)"
        }
    }

    private var tabShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 8,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 8,
            style: .continuous
        )
    }

    private var tabBackground: Color {
        isActive ? theme.contentBackground.color : theme.elevatedBackground.color.opacity(0.22)
    }

    private var tabBorderColor: Color {
        isActive ? theme.activeBorder.color.opacity(0.9) : theme.border.color.opacity(0.55)
    }
}

struct WorkspacePrimaryHostAreaView: View {
    let store: WorkspaceStore
    let commandService: any WorkspaceCommandService
    let terminalHostController: TerminalHostController
    let fileBufferController: any WorkspaceFileBufferManaging
    @Binding var userMessage: UserMessage?
    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        ZStack {
            theme.contentBackground.color
            if let selectedTab = store.selectedTab, selectedTab.kind == .terminal {
                TerminalHostView(
                    tab: selectedTab,
                    isActive: selectedTab.id == store.selectedTabID,
                    controller: terminalHostController,
                    onError: { error in userMessage = UserMessage(title: "Terminal unavailable", detail: String(describing: error)) }
                )
                .id(selectedTab.id)
                .padding(12)
            } else if let selectedTab = store.selectedTab, selectedTab.kind == .file {
                FileEditorHostView(
                    tab: selectedTab,
                    commandService: commandService,
                    fileBufferController: fileBufferController,
                    fontSize: store.appPreferences.terminalFontSize,
                    userMessage: $userMessage
                )
            } else {
                TerminalPlaceholderView(
                    selectedProject: store.selectedProject,
                    selectedSession: store.selectedSession,
                    showsTerminalCreationActions: FocusWorkspacePolicy.shouldShowTerminalCreationAffordance(
                        in: store.selectedFocusWorkspaceSessionState
                    ),
                    onCreatePlainTab: createPlainTabIfPossible,
                    onCreateAgentTab: createAgentTabIfPossible
                )
            }
        }
        .task(id: store.tabsForSelectedSession.map { "\($0.id.uuidString):\($0.kind.rawValue)" }) {
            await ensureVisibleSessionSurfaces()
        }
    }

    private func ensureVisibleSessionSurfaces() async {
        for tab in store.tabsForSelectedSession where tab.kind == .terminal {
            do {
                try await terminalHostController.createSurface(for: tab)
            } catch {
                userMessage = UserMessage(title: "Terminal unavailable", detail: String(describing: error))
                return
            }
        }
    }

    private func createPlainTabIfPossible() {
        guard let selectedSessionID = store.selectedSessionID else { return }
        Task {
            do {
                _ = try await commandService.createPlainTab(sessionID: selectedSessionID)
            } catch {
                userMessage = UserMessage.commandFailure(error, fallbackTitle: "Tab could not be created")
            }
        }
    }

    private func createAgentTabIfPossible() {
        NotificationCenter.default.post(name: .showAgentTabPalette, object: nil)
    }
}

struct FileEditorHostView: View {
    let tab: WorkspaceTab
    let commandService: any WorkspaceCommandService
    let fileBufferController: any WorkspaceFileBufferManaging
    let fontSize: Double
    @Binding var userMessage: UserMessage?
    @Environment(\.shellThemePalette) private var theme
    @Environment(\.shellUIFontSize) private var uiFontSize
    @Environment(\.colorScheme) private var colorScheme
    @State private var editorText = ""
    @State private var editorPosition = CodeEditor.Position()
    @State private var messages = Set<TextLocated<Message>>()
    @State private var bufferSnapshot: FileEditorBuffer?
    @State private var loadError: String?
    @State private var isLoading = false

    private var presentation: FileEditorPresentation? {
        FileEditorPresentation(tab: tab, buffer: bufferSnapshot)
    }

    private var isDirty: Bool {
        guard let savedText = bufferSnapshot?.savedText else { return false }
        return savedText != editorText
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            Divider().overlay(theme.border.color)
            ZStack {
                theme.contentBackground.color
                if isLoading {
                    ProgressView("Loading file...")
                        .foregroundStyle(theme.secondaryText.color)
                } else if let loadError {
                    FileEditorUnavailableView(title: title, message: loadError)
                } else if presentation != nil {
                    CodeEditor(
                        text: editorTextBinding,
                        position: $editorPosition,
                        messages: $messages,
                        language: languageConfiguration
                    )
                    .environment(\.codeEditorTheme, codeEditorTheme)
                    .environment(\.codeEditorLayoutConfiguration, CodeEditor.LayoutConfiguration(showMinimap: false, wrapText: false))
                    .font(.system(size: max(fontSize, 11), design: .monospaced))
                    .onChange(of: editorPosition) { _, newPosition in
                        updateEditorPosition(newPosition)
                    }
                } else {
                    FileEditorUnavailableView(title: "File unavailable", message: tab.fileReference?.path ?? tab.workingDirectory)
                }
            }
        }
        .background(theme.contentBackground.color)
        .task(id: tab.id) {
            await loadBuffer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fileBufferDirtyStateChanged)) { notification in
            guard notification.object as? UUID == tab.id else { return }
            if let buffer = fileBufferController.buffer(for: tab.id) {
                applyBuffer(buffer)
            } else {
                refreshBufferSnapshot()
            }
        }
    }

    private var editorHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: isDirty ? "doc.text.fill" : "doc.text")
                .foregroundStyle(isDirty ? theme.warning.color : theme.accent.color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: uiFontSize + 1, weight: .semibold))
                    .foregroundStyle(theme.primaryText.color)
                    .lineLimit(1)
                    .textSelection(.enabled)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: max(uiFontSize - 2, 10), design: .monospaced))
                        .foregroundStyle(theme.mutedText.color)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 12)
            if isDirty {
                Text("Unsaved")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.warning.color)
            }
            Button("Revert", systemImage: "arrow.uturn.backward", action: revert)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(bufferSnapshot == nil || isLoading)
                .help("Revert file")
            Button("Save", systemImage: "square.and.arrow.down", action: save)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(!isDirty || isLoading)
                .help("Save file")
            Button("Open Externally", systemImage: "arrow.up.forward.square", action: openExternally)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(bufferSnapshot == nil || isLoading)
                .help("Open in external editor")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(theme.elevatedBackground.color.opacity(0.92))
    }

    private var title: String {
        if let fileReference = tab.fileReference {
            return FileEditorPresentation.relativePath(for: fileReference.path, projectRoot: fileReference.projectRoot)
        }

        return presentation?.path ?? tab.workingDirectory
    }

    private var subtitle: String {
        if let fileReference = tab.fileReference {
            return fileReference.path
        }
        return presentation?.subtitle ?? tab.workingDirectory
    }

    private var editorTextBinding: Binding<String> {
        Binding(
            get: { editorText },
            set: { newText in
                editorText = newText
                fileBufferController.updateBuffer(tabID: tab.id, text: newText)
                refreshBufferSnapshot()
                notifyFileBufferChanged()
            }
        )
    }

    private var languageConfiguration: LanguageConfiguration {
        LanguageConfiguration.atelierConfiguration(for: presentation?.languageConfigurationKey ?? "plaintext")
    }

    private var codeEditorTheme: Theme {
        switch colorScheme.themeColorScheme.editorSyntaxThemeKind {
        case .dark:
            return Theme.defaultDark
        case .light:
            return Theme.defaultLight
        }
    }

    private func loadBuffer() async {
        if let buffer = fileBufferController.buffer(for: tab.id) {
            applyBuffer(buffer)
            loadError = nil
            isLoading = false
            notifyFileBufferChanged()
            return
        }

        isLoading = true
        loadError = nil
        do {
            try await fileBufferController.loadBuffer(for: tab)
            guard let buffer = fileBufferController.buffer(for: tab.id) else {
                throw WorkspaceFileBufferError.missingBuffer(tab.id)
            }
            applyBuffer(buffer)
        } catch {
            loadError = String(describing: error)
            userMessage = UserMessage(title: "File unavailable", detail: String(describing: error))
        }
        isLoading = false
        notifyFileBufferChanged()
    }

    private func save() {
        Task {
            do {
                try await commandService.saveFileTab(tabID: tab.id)
                refreshBufferSnapshot()
                notifyFileBufferChanged()
            } catch {
                userMessage = UserMessage(title: "File could not be saved", detail: String(describing: error))
            }
        }
    }

    private func revert() {
        Task {
            do {
                try await commandService.revertFileTab(tabID: tab.id)
                refreshBufferSnapshot()
                editorText = bufferSnapshot?.text ?? editorText
                notifyFileBufferChanged()
            } catch {
                userMessage = UserMessage(title: "File could not be reverted", detail: String(describing: error))
            }
        }
    }

    private func openExternally() {
        Task {
            do {
                try await commandService.openFileInExternalEditor(tabID: tab.id)
            } catch {
                userMessage = UserMessage(title: "File could not be opened", detail: String(describing: error))
            }
        }
    }

    private func updateEditorPosition(_ position: CodeEditor.Position) {
        let selection = position.selections.first ?? .zero
        fileBufferController.updateEditorPosition(
            tabID: tab.id,
            position: FileEditorPosition(
                cursorOffset: max(selection.location, 0),
                selectionLength: max(selection.length, 0),
                firstVisibleLine: max(Int(position.verticalScrollPosition), 0)
            )
        )
    }

    private func refreshBufferSnapshot() {
        bufferSnapshot = fileBufferController.buffer(for: tab.id)
    }

    private func applyBuffer(_ buffer: FileEditorBuffer) {
        bufferSnapshot = buffer
        editorText = buffer.text
        editorPosition = CodeEditor.Position(
            selections: [NSRange(location: buffer.editorPosition.cursorOffset, length: buffer.editorPosition.selectionLength)],
            verticalScrollPosition: CGFloat(buffer.editorPosition.firstVisibleLine)
        )
    }

    private func notifyFileBufferChanged() {
        NotificationCenter.default.post(name: .fileBufferDirtyStateChanged, object: tab.id)
    }
}

struct FileEditorUnavailableView: View {
    let title: String
    let message: String
    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(theme.warning.color)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.primaryText.color)
                .lineLimit(1)
            Text(message)
                .font(.callout.monospaced())
                .foregroundStyle(theme.secondaryText.color)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }
}

struct FileWorkspaceSidebarView: View {
    let store: WorkspaceStore
    let commandService: any WorkspaceCommandService
    let fileAccessService: any WorkspaceFileAccessing
    @Binding var userMessage: UserMessage?
    @Environment(\.shellThemePalette) private var theme
    @Environment(\.shellUIFontSize) private var uiFontSize
    @State private var repositoryNodes: [WorkspaceFileNode] = []
    @State private var repositoryTreeIndex: WorkspaceFileTreeIndex?
    @State private var repositoryEntries: [FileWorkspaceTreeEntry] = []
    @State private var expandedDirectoryPaths: Set<String> = []
    @State private var repositoryError: String?
    @State private var isRepositoryLoading = false
    @State private var searchQuery = ""
    @State private var searchResults: [RepositorySearchResult] = []
    @State private var repositorySearchIndex: [RepositorySearchIndexEntry] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var creationDraft: ProjectItemCreationDraft?
    @State private var repositoryRenameDraft: RepositoryItemRenameDraft?
    @State private var pendingRepositoryItemDeletion: RepositoryItemContext?
    @State private var contextMenuSelectionPath: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                repositorySection
            }
            .padding(12)
        }
        .background(theme.sidebarBackground.color)
        .font(.system(size: uiFontSize))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(theme.border.color)
                .frame(width: 1)
        }
        .task(id: repositoryTaskID) {
            await loadRepositoryNodes()
        }
        .onChange(of: store.selectedTabID) { _, _ in
            expandSelectedFileAncestors()
        }
        .onChange(of: searchQuery) { _, newQuery in
            scheduleSearch(for: newQuery)
        }
        .sheet(item: $creationDraft) { draft in
            ProjectItemCreationView(draft: draft) { updatedDraft in
                Task {
                    await createProjectItem(from: updatedDraft)
                }
            } onCancel: {
                creationDraft = nil
            }
        }
        .sheet(item: $repositoryRenameDraft) { draft in
            RepositoryItemRenameView(draft: draft) { updatedDraft in
                Task {
                    await renameRepositoryItem(from: updatedDraft)
                }
            } onCancel: {
                repositoryRenameDraft = nil
            }
        }
        .confirmationDialog("Delete item?", isPresented: pendingRepositoryItemDeletionBinding, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let pendingRepositoryItemDeletion else { return }
                Task {
                    await deleteRepositoryItem(pendingRepositoryItemDeletion)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingRepositoryItemDeletion = nil
            }
        } message: {
            if let pendingRepositoryItemDeletion {
                Text("Delete \(pendingRepositoryItemDeletion.relativePath)? This removes it from disk.")
            }
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private var repositorySection: some View {
        FileWorkspaceSection(
            title: repositorySectionTitle,
            systemImage: "folder",
            actions: repositorySectionActions
        ) {
            if store.selectedProject == nil {
                FileWorkspaceInlineEmptyState(title: "No project selected")
            } else if isRepositoryLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading files")
                        .font(.system(size: max(uiFontSize - 2, 10)))
                        .foregroundStyle(theme.secondaryText.color)
                }
                .padding(.vertical, 8)
            } else if let repositoryError {
                FileWorkspaceInlineEmptyState(title: repositoryError)
            } else if repositoryEntries.isEmpty {
                FileWorkspaceInlineEmptyState(title: "No files")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(theme.mutedText.color)
                        TextField("Search project files…", text: $searchQuery)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                if let first = searchResults.first {
                                    handleSearchResult(first)
                                }
                            }
                    }

                    if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if searchResults.isEmpty {
                            FileWorkspaceInlineEmptyState(title: "No matching files")
                        } else {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(searchResults) { result in
                                    RepositorySearchResultRow(
                                        result: result,
                                        isHighlighted: contextMenuSelectionPath == result.path
                                    ) {
                                        handleSearchResult(result)
                                    }
                                    .contextMenu {
                                        if let item = repositoryItemContext(for: result) {
                                            repositoryItemContextMenu(for: item)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        LazyVStack(alignment: .leading, spacing: 3) {
                            ForEach(repositoryEntries) { entry in
                                RepositoryTreeRow(
                                    entry: entry,
                                    isHighlighted: contextMenuSelectionPath == entry.path
                                ) {
                                    handleRepositoryEntry(entry)
                                }
                                .contextMenu {
                                    repositoryItemContextMenu(for: repositoryItemContext(for: entry))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var repositorySectionActions: [FileWorkspaceSectionAction] {
        [
            FileWorkspaceSectionAction(
                label: "Reload files",
                systemImage: "arrow.clockwise",
                isDisabled: store.selectedProject == nil,
                action: reloadRepository
            ),
            FileWorkspaceSectionAction(
                label: "Create folder",
                systemImage: "folder.badge.plus",
                isDisabled: store.selectedProject == nil,
                action: showCreateFolderPrompt
            ),
            FileWorkspaceSectionAction(
                label: "Create file",
                systemImage: "doc.badge.plus",
                isDisabled: store.selectedProject == nil,
                action: showCreateFilePrompt
            )
        ]
    }

    private var repositorySectionTitle: String {
        store.selectedProject?.displayName ?? "Repository"
    }

    private var repositoryTaskID: String {
        store.selectedProject?.path ?? "no-project"
    }

    private func loadRepositoryNodes() async {
        guard let project = store.selectedProject else {
            searchTask?.cancel()
            repositoryNodes = []
            repositoryTreeIndex = nil
            repositoryEntries = []
            repositorySearchIndex = []
            searchResults = []
            repositoryError = nil
            searchQuery = ""
            isRepositoryLoading = false
            return
        }

        isRepositoryLoading = true
        repositoryError = nil
        do {
            repositoryNodes = try await fileAccessService.enumerateProjectFiles(projectRoot: project.path)
            repositoryTreeIndex = WorkspaceFileTreeBuilder.makeIndex(projectRoot: project.path, nodes: repositoryNodes)
            repositorySearchIndex = repositoryNodes
                .filter { !$0.isDirectory }
                .map { node in
                    let title = FileEditorPresentation.fileName(for: node.reference.path)
                    let subtitle = FileEditorPresentation.relativePath(for: node.reference.path, projectRoot: project.path)
                    return RepositorySearchIndexEntry(
                        path: node.reference.path,
                        title: title,
                        subtitle: subtitle,
                        normalizedTitle: title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current),
                        normalizedSubtitle: subtitle.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    )
                }
                .sorted { lhs, rhs in
                    lhs.subtitle.localizedStandardCompare(rhs.subtitle) == .orderedAscending
                }
            expandSelectedFileAncestors()
            rebuildRepositoryEntries()
            scheduleSearch(for: searchQuery, immediately: true)
        } catch {
            searchTask?.cancel()
            repositoryNodes = []
            repositoryTreeIndex = nil
            repositoryEntries = []
            repositorySearchIndex = []
            searchResults = []
            repositoryError = "Files unavailable"
            userMessage = UserMessage(title: "Repository files unavailable", detail: String(describing: error))
        }
        isRepositoryLoading = false
    }

    private func reloadRepository() {
        Task {
            await loadRepositoryNodes()
        }
    }

    private func showCreateFolderPrompt() {
        guard let project = store.selectedProject else { return }
        creationDraft = ProjectItemCreationDraft(projectRoot: project.path, kind: .folder)
    }

    private func showCreateFilePrompt() {
        guard let project = store.selectedProject else { return }
        creationDraft = ProjectItemCreationDraft(projectRoot: project.path, kind: .file)
    }

    private func showCreateFilePrompt(in directoryPath: String) {
        guard let project = store.selectedProject else { return }
        let relativeDirectory = FileEditorPresentation.relativePath(for: directoryPath, projectRoot: project.path)
        creationDraft = ProjectItemCreationDraft(
            projectRoot: project.path,
            kind: .file,
            relativePath: relativeDirectory.isEmpty ? "" : "\(relativeDirectory)/"
        )
    }

    private func scheduleSearch(for query: String, immediately: Bool = false) {
        searchTask?.cancel()
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            searchResults = []
            return
        }

        let normalizedQuery = trimmedQuery.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let index = repositorySearchIndex
        searchTask = Task {
            if !immediately {
                try? await Task.sleep(for: .milliseconds(75))
            }
            guard !Task.isCancelled else { return }
            let results = index.lazy
                .filter { entry in
                    entry.normalizedTitle.contains(normalizedQuery) ||
                        entry.normalizedSubtitle.contains(normalizedQuery)
                }
                .prefix(250)
                .map { entry in
                    RepositorySearchResult(path: entry.path, title: entry.title, subtitle: entry.subtitle)
                }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                searchResults = Array(results)
            }
        }
    }

    private var pendingRepositoryItemDeletionBinding: Binding<Bool> {
        Binding(
            get: { pendingRepositoryItemDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    pendingRepositoryItemDeletion = nil
                }
            }
        )
    }

    private func handleRepositoryEntry(_ entry: FileWorkspaceTreeEntry) {
        contextMenuSelectionPath = nil
        if entry.isDirectory {
            toggleDirectory(entry.path)
            return
        }

        guard let sessionID = store.selectedSessionID else {
            userMessage = UserMessage(title: "Session required", detail: "Select a session before opening a file.")
            return
        }

        Task {
            do {
                _ = try await commandService.openFileTab(sessionID: sessionID, path: entry.path)
                expandAncestors(of: entry.path)
            } catch {
                userMessage = UserMessage.commandFailure(error, fallbackTitle: "File could not be opened")
            }
        }
    }

    private func handleSearchResult(_ result: RepositorySearchResult) {
        handleRepositoryFile(at: result.path)
    }

    private func repositoryItemContext(for entry: FileWorkspaceTreeEntry) -> RepositoryItemContext {
        RepositoryItemContext(
            path: entry.path,
            relativePath: entry.relativePath,
            isDirectory: entry.isDirectory
        )
    }

    private func repositoryItemContext(for result: RepositorySearchResult) -> RepositoryItemContext? {
        guard store.selectedProject != nil else { return nil }
        return RepositoryItemContext(path: result.path, relativePath: result.subtitle, isDirectory: false)
    }

    @ViewBuilder
    private func repositoryItemContextMenu(for item: RepositoryItemContext) -> some View {
        if item.isDirectory {
            Button("Create File", systemImage: "doc.badge.plus") {
                showCreateFilePrompt(in: item.path)
                clearContextMenuSelection(item.path)
            }
        }
        Button("Open in Finder", systemImage: "folder") {
            revealInFinder(item.path)
            clearContextMenuSelection(item.path)
        }
        .onAppear {
            contextMenuSelectionPath = item.path
        }
        .onDisappear {
            clearContextMenuSelection(item.path)
        }
        Button("Copy Path", systemImage: "doc.on.doc") {
            copyToPasteboard(item.path)
            clearContextMenuSelection(item.path)
        }
        Button("Copy Relative Path", systemImage: "doc.on.doc") {
            copyToPasteboard(item.relativePath)
            clearContextMenuSelection(item.path)
        }
        Button("Rename", systemImage: "pencil") {
            showRenamePrompt(for: item)
            clearContextMenuSelection(item.path)
        }
        Button("Delete", systemImage: "trash", role: .destructive) {
            pendingRepositoryItemDeletion = item
            clearContextMenuSelection(item.path)
        }
    }

    private func clearContextMenuSelection(_ path: String) {
        if contextMenuSelectionPath == path {
            contextMenuSelectionPath = nil
        }
    }

    private func revealInFinder(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func showRenamePrompt(for item: RepositoryItemContext) {
        repositoryRenameDraft = RepositoryItemRenameDraft(item: item)
    }

    private func renameRepositoryItem(from draft: RepositoryItemRenameDraft) async {
        guard let project = store.selectedProject else { return }
        let trimmedName = draft.updatedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            userMessage = UserMessage(title: "Item could not be renamed", detail: "Enter a new name before saving.")
            return
        }

        let destinationPath = URL(fileURLWithPath: draft.item.path)
            .deletingLastPathComponent()
            .appendingPathComponent(trimmedName, isDirectory: draft.item.isDirectory)
            .path

        if destinationPath == draft.item.path {
            repositoryRenameDraft = nil
            return
        }

        do {
            try await commandService.renameWorkspaceItem(projectID: project.id, path: draft.item.path, to: destinationPath)
            repositoryRenameDraft = nil
            await loadRepositoryNodes()
            expandAncestors(of: destinationPath)
        } catch WorkspaceCommandError.dirtyFileTabCloseRejected {
            userMessage = UserMessage(
                title: "Item has unsaved file tabs",
                detail: "Save or revert open files inside this item before renaming it."
            )
        } catch {
            userMessage = UserMessage(title: "Item could not be renamed", detail: String(describing: error))
        }
    }

    private func deleteRepositoryItem(_ item: RepositoryItemContext) async {
        guard let project = store.selectedProject else { return }
        pendingRepositoryItemDeletion = nil

        do {
            try await commandService.deleteWorkspaceItem(projectID: project.id, path: item.path)
            await loadRepositoryNodes()
        } catch WorkspaceCommandError.dirtyFileTabCloseRejected {
            userMessage = UserMessage(
                title: "Item has unsaved file tabs",
                detail: "Save or revert open files inside this item before deleting it."
            )
        } catch {
            userMessage = UserMessage(title: "Item could not be deleted", detail: String(describing: error))
        }
    }

    private func handleRepositoryFile(at path: String) {
        contextMenuSelectionPath = nil
        guard let sessionID = store.selectedSessionID else {
            userMessage = UserMessage(title: "Session required", detail: "Select a session before opening a file.")
            return
        }

        Task {
            do {
                _ = try await commandService.openFileTab(sessionID: sessionID, path: path)
                expandAncestors(of: path)
            } catch {
                userMessage = UserMessage.commandFailure(error, fallbackTitle: "File could not be opened")
            }
        }
    }

    private func toggleDirectory(_ path: String) {
        if expandedDirectoryPaths.contains(path) {
            expandedDirectoryPaths.remove(path)
        } else {
            expandedDirectoryPaths.insert(path)
        }
        rebuildRepositoryEntries()
    }

    private func expandSelectedFileAncestors() {
        guard let filePath = store.selectedTab?.fileReference?.path else { return }
        expandAncestors(of: filePath)
    }

    private func expandAncestors(of path: String) {
        var url = URL(fileURLWithPath: path).deletingLastPathComponent()
        let rootPath = store.selectedProject?.path
        var didChange = false
        while !url.path.isEmpty, url.path != "/" {
            if expandedDirectoryPaths.insert(url.path).inserted {
                didChange = true
            }
            if let rootPath, URL(fileURLWithPath: rootPath, isDirectory: true).standardizedFileURL.path == url.standardizedFileURL.path {
                break
            }
            url.deleteLastPathComponent()
        }
        if didChange {
            rebuildRepositoryEntries()
        }
    }

    private func rebuildRepositoryEntries() {
        guard let project = store.selectedProject else {
            repositoryEntries = []
            return
        }
        repositoryEntries = (repositoryTreeIndex ?? WorkspaceFileTreeBuilder.makeIndex(projectRoot: project.path, nodes: repositoryNodes))
            .visibleEntries(expandedDirectoryPaths: expandedDirectoryPaths)
    }

    private func createProjectItem(from draft: ProjectItemCreationDraft) async {
        let trimmedRelativePath = draft.relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRelativePath.isEmpty else {
            userMessage = UserMessage(title: draft.kind.failureTitle, detail: "Enter a relative path inside the selected project.")
            return
        }

        let absolutePath = URL(fileURLWithPath: draft.projectRoot, isDirectory: true)
            .appendingPathComponent(trimmedRelativePath, isDirectory: draft.kind == .folder)
            .path

        do {
            switch draft.kind {
            case .file:
                let fileReference = try await fileAccessService.createTextFile(path: absolutePath, projectRoot: draft.projectRoot, contents: draft.initialContents)
                creationDraft = nil
                await loadRepositoryNodes()
                expandAncestors(of: fileReference.path)
                handleRepositoryFile(at: fileReference.path)
            case .folder:
                let directoryPath = try await fileAccessService.createDirectory(path: absolutePath, projectRoot: draft.projectRoot)
                creationDraft = nil
                await loadRepositoryNodes()
                expandAncestors(of: directoryPath)
            }
        } catch {
            userMessage = UserMessage(title: draft.kind.failureTitle, detail: String(describing: error))
        }
    }
}

struct FileWorkspaceSection<Content: View>: View {
    let title: String
    let systemImage: String
    let actions: [FileWorkspaceSectionAction]
    @ViewBuilder let content: Content
    @Environment(\.shellThemePalette) private var theme
    @Environment(\.shellUIFontSize) private var uiFontSize

    init(
        title: String,
        systemImage: String,
        actions: [FileWorkspaceSectionAction] = [],
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.actions = actions
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.system(size: max(uiFontSize - 1, 10), weight: .semibold))
                    .foregroundStyle(theme.secondaryText.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    ForEach(actions) { action in
                        Button(action.label, systemImage: action.systemImage, action: action.action)
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                            .foregroundStyle(theme.secondaryText.color)
                            .frame(width: 24, height: 24)
                            .disabled(action.isDisabled)
                            .help(action.label)
                    }
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FileWorkspaceSectionAction: Identifiable {
    let label: String
    let systemImage: String
    let isDisabled: Bool
    let action: () -> Void

    var id: String { "\(label)-\(systemImage)" }
}

struct FileWorkingSetRow: View {
    let entry: FileWorkspaceWorkingSetEntry
    let action: () -> Void
    @Environment(\.shellThemePalette) private var theme
    @Environment(\.shellUIFontSize) private var uiFontSize

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: entry.isSelected ? "doc.text.fill" : "doc.text")
                    .foregroundStyle(entry.isSelected ? theme.selectedText.color : theme.accent.color)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(entry.title)
                            .font(.system(size: uiFontSize, weight: .semibold))
                            .foregroundStyle(theme.primaryText.color)
                            .lineLimit(1)
                        if entry.isDirty {
                            Circle()
                                .fill(theme.warning.color)
                                .frame(width: 6, height: 6)
                        }
                    }
                    if !entry.subtitle.isEmpty {
                        Text(entry.subtitle)
                            .font(.system(size: max(uiFontSize - 2, 10), design: .monospaced))
                            .foregroundStyle(theme.mutedText.color)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(entry.isSelected ? theme.activeBackground.color.opacity(0.34) : theme.elevatedBackground.color.opacity(0.52), in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(entry.isSelected ? theme.activeBorder.color : theme.border.color.opacity(0.55), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help(entry.path)
    }
}

struct RepositoryTreeRow: View {
    let entry: FileWorkspaceTreeEntry
    let isHighlighted: Bool
    let action: () -> Void
    @Environment(\.shellThemePalette) private var theme
    @Environment(\.shellUIFontSize) private var uiFontSize
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if entry.isDirectory {
                    Image(systemName: entry.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.mutedText.color)
                        .frame(width: 10)
                    Image(systemName: entry.isExpanded ? "folder.fill" : "folder")
                        .foregroundStyle(theme.secondaryAccent.color)
                        .frame(width: 16)
                } else {
                    Color.clear
                        .frame(width: 10)
                    Image(systemName: "doc.text")
                        .foregroundStyle(theme.accent.color)
                        .frame(width: 16)
                }
                Text(entry.name)
                    .font(.system(size: max(uiFontSize - 1, 10)))
                    .foregroundStyle(theme.primaryText.color)
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            .padding(.leading, CGFloat(entry.depth * 14))
            .padding(.trailing, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                rowBackground,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHighlighted ? theme.activeBorder.color.opacity(0.9) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help(entry.path)
        .onHover { isHovered = $0 }
    }

    private var rowBackground: Color {
        if isHighlighted {
            return theme.activeBackground.color.opacity(0.24)
        }

        if isHovered {
            return theme.elevatedBackground.color.opacity(0.52)
        }

        return .clear
    }
}

struct RepositorySearchResult: Identifiable, Equatable {
    let path: String
    let title: String
    let subtitle: String

    var id: String { path }
}

struct RepositorySearchResultRow: View {
    let result: RepositorySearchResult
    let isHighlighted: Bool
    let action: () -> Void
    @Environment(\.shellThemePalette) private var theme
    @Environment(\.shellUIFontSize) private var uiFontSize
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .foregroundStyle(theme.accent.color)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.system(size: max(uiFontSize - 1, 10), weight: .semibold))
                        .foregroundStyle(theme.primaryText.color)
                        .lineLimit(1)
                    Text(result.subtitle)
                        .font(.system(size: max(uiFontSize - 2, 10), design: .monospaced))
                        .foregroundStyle(theme.mutedText.color)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                rowBackground,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHighlighted ? theme.activeBorder.color.opacity(0.9) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help(result.path)
        .onHover { isHovered = $0 }
    }

    private var rowBackground: Color {
        if isHighlighted {
            return theme.activeBackground.color.opacity(0.28)
        }

        if isHovered {
            return theme.elevatedBackground.color.opacity(0.68)
        }

        return theme.elevatedBackground.color.opacity(0.5)
    }
}

struct FileWorkspaceInlineEmptyState: View {
    let title: String
    @Environment(\.shellThemePalette) private var theme
    @Environment(\.shellUIFontSize) private var uiFontSize

    var body: some View {
        Text(title)
            .font(.system(size: max(uiFontSize - 1, 10)))
            .foregroundStyle(theme.mutedText.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.elevatedBackground.color.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }
}

private extension LanguageConfiguration {
    static func atelierConfiguration(for key: String) -> LanguageConfiguration {
        switch key {
        case "swift":
            return .swift()
        case "sqlite":
            return .sqlite()
        case "haskell":
            return .haskell()
        case "agda":
            return .agda()
        case "cabal":
            return .cabal()
        case "cypher":
            return .cypher()
        case "javascript":
            return .atelierJavaScript()
        case "typescript":
            return .atelierTypeScript()
        case "json":
            return .atelierJSON()
        case "markdown":
            return .atelierMarkdown()
        case "java":
            return .atelierJava()
        case "kotlin", "kts":
            return .atelierKotlin()
        case "rust":
            return .atelierRust()
        case "go":
            return .atelierGo()
        case "ocaml":
            return .atelierOCaml()
        case "reasonml":
            return .atelierReasonML()
        case "rescript":
            return .atelierReScript()
        case "opam":
            return .atelierOPAM()
        case "maven":
            return .atelierMaven()
        case "makefile":
            return .atelierMakefile()
        case "xml":
            return .atelierXML()
        case "yaml":
            return .atelierYAML()
        case "shell":
            return .atelierShell()
        default:
            return .none
        }
    }
}

extension Notification.Name {
    static let fileBufferDirtyStateChanged = Notification.Name("Atelier.fileBufferDirtyStateChanged")
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
    let showsTerminalCreationActions: Bool
    let onCreatePlainTab: () -> Void
    let onCreateAgentTab: () -> Void
    @Environment(\.shellThemePalette) private var theme
    @Environment(\.shellUIFontSize) private var uiFontSize

    var body: some View {
        ZStack {
            theme.contentBackground.color
            VStack(spacing: 12) {
                Image(systemName: "terminal")
                    .font(.system(size: 44))
                    .foregroundStyle(theme.accent.color)
                Text(title)
                    .font(.system(size: uiFontSize + 3, weight: .semibold))
                    .foregroundStyle(theme.primaryText.color)
                Text(message)
                    .font(.system(size: uiFontSize, design: .monospaced))
                    .foregroundStyle(theme.secondaryText.color)
                    .multilineTextAlignment(.center)
                if selectedSession != nil, showsTerminalCreationActions {
                    HStack(spacing: 10) {
                        Button("New Tab", action: onCreatePlainTab)
                            .buttonStyle(.bordered)
                        Button("New Agent Tab…", action: onCreateAgentTab)
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(28)
            .background(theme.elevatedBackground.color.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(theme.border.color, lineWidth: 1)
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
    @Environment(\.shellThemePalette) private var theme
    @Environment(\.shellUIFontSize) private var uiFontSize

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: uiFontSize + 5, weight: .bold))
                    .foregroundStyle(theme.primaryText.color)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: max(uiFontSize - 2, 10)))
                    .foregroundStyle(theme.mutedText.color)
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
        .padding(.bottom, 6)
        .background(theme.tabBarBackground.color)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    @Environment(\.shellThemePalette) private var theme
    @Environment(\.shellUIFontSize) private var uiFontSize

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(theme.accent.color)
            Text(title)
                .font(.system(size: uiFontSize + 2, weight: .semibold))
                .foregroundStyle(theme.primaryText.color)
            Text(message)
                .font(.system(size: uiFontSize))
                .foregroundStyle(theme.secondaryText.color)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(theme.shellBackground.color)
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

struct TabRenameDraft: Identifiable, Equatable {
    let id: UUID
    let currentTitle: String
    let placeholderTitle: String

    init(
        tab: WorkspaceTab,
        legacySessionShortcutID: UUID? = nil,
        terminalPresentationResolver: SessionTerminalPresentationResolver = SessionTerminalPresentationResolver()
    ) {
        id = tab.id
        currentTitle = tab.title ?? ""
        if tab.kind == .file, let filePath = tab.fileReference?.path {
            let fileName = URL(fileURLWithPath: filePath).lastPathComponent
            placeholderTitle = fileName.isEmpty ? filePath : fileName
        } else if let terminalPresentation = terminalPresentationResolver.resolve(
            tab: tab,
            legacySessionShortcutID: legacySessionShortcutID
        ) {
            placeholderTitle = terminalPresentation.fallbackTitle
        } else {
            placeholderTitle = "Terminal"
        }
    }
}

enum ProjectItemKind: String, Identifiable {
    case file
    case folder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .file:
            return "Create File"
        case .folder:
            return "Create Folder"
        }
    }

    var failureTitle: String {
        switch self {
        case .file:
            return "File could not be created"
        case .folder:
            return "Folder could not be created"
        }
    }

    var relativePathPlaceholder: String {
        switch self {
        case .file:
            return "src/NewFile.swift"
        case .folder:
            return "src/NewFolder"
        }
    }
}

struct ProjectItemCreationDraft: Identifiable, Equatable {
    let id = UUID()
    let projectRoot: String
    let kind: ProjectItemKind
    var relativePath: String = ""
    var initialContents: String = ""
}

struct ProjectItemCreationView: View {
    @State private var draft: ProjectItemCreationDraft
    @State private var fileName: String
    let onSave: (ProjectItemCreationDraft) -> Void
    let onCancel: () -> Void
    @Environment(\.shellThemePalette) private var theme
    @FocusState private var focusedField: Bool

    init(draft: ProjectItemCreationDraft, onSave: @escaping (ProjectItemCreationDraft) -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        _fileName = State(initialValue: Self.initialFileName(for: draft))
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.kind.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(theme.primaryText.color)
            Text("Create a new item inside the selected project.")
                .foregroundStyle(theme.secondaryText.color)
            if draft.kind == .file {
                if !fileParentRelativePath.isEmpty {
                    Text("Create inside: \(fileParentRelativePath)")
                        .font(.caption.monospaced())
                        .foregroundStyle(theme.mutedText.color)
                        .textSelection(.enabled)
                }
                TextField("NewFile.swift", text: $fileName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField)
            } else {
                TextField(draft.kind.relativePathPlaceholder, text: $draft.relativePath)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField)
            }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
                    onSave(resolvedDraft())
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(theme.elevatedBackground.color)
        .onAppear { focusedField = true }
    }

    private var fileParentRelativePath: String {
        let normalized = draft.relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }
        if normalized.hasSuffix("/") {
            return String(normalized.dropLast())
        }

        let parent = (normalized as NSString).deletingLastPathComponent
        return parent == "." ? "" : parent
    }

    private func resolvedDraft() -> ProjectItemCreationDraft {
        guard draft.kind == .file else { return draft }
        var updatedDraft = draft
        let trimmedName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if fileParentRelativePath.isEmpty {
            updatedDraft.relativePath = trimmedName
        } else {
            updatedDraft.relativePath = "\(fileParentRelativePath)/\(trimmedName)"
        }
        return updatedDraft
    }

    private static func initialFileName(for draft: ProjectItemCreationDraft) -> String {
        guard draft.kind == .file else { return "" }
        let normalized = draft.relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, !normalized.hasSuffix("/") else { return "" }
        let name = (normalized as NSString).lastPathComponent
        return name == "/" ? "" : name
    }
}

private struct RepositorySearchIndexEntry: Sendable {
    let path: String
    let title: String
    let subtitle: String
    let normalizedTitle: String
    let normalizedSubtitle: String
}

private struct RepositoryItemContext: Identifiable, Equatable {
    let path: String
    let relativePath: String
    let isDirectory: Bool

    var id: String { path }

    var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}

private struct RepositoryItemRenameDraft: Identifiable, Equatable {
    let item: RepositoryItemContext
    var updatedName: String

    var id: String { item.id }

    init(item: RepositoryItemContext) {
        self.item = item
        updatedName = item.displayName
    }
}

private struct RepositoryItemRenameView: View {
    @State private var draft: RepositoryItemRenameDraft
    let onSave: (RepositoryItemRenameDraft) -> Void
    let onCancel: () -> Void
    @Environment(\.shellThemePalette) private var theme
    @FocusState private var focusedField: Bool

    init(
        draft: RepositoryItemRenameDraft,
        onSave: @escaping (RepositoryItemRenameDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename \(draft.item.isDirectory ? "Folder" : "File")")
                .font(.title2.weight(.semibold))
                .foregroundStyle(theme.primaryText.color)
            Text(draft.item.relativePath)
                .font(.caption.monospaced())
                .foregroundStyle(theme.mutedText.color)
                .textSelection(.enabled)
            TextField("New name", text: $draft.updatedName)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField)
                .onSubmit {
                    onSave(draft)
                }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Rename") {
                    onSave(draft)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(theme.elevatedBackground.color)
        .onAppear { focusedField = true }
    }
}

struct UserMessage: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String

    init(title: String, detail: String) {
        self.title = title
        self.detail = detail
    }

    init(focusWorkspacePresentation presentation: FocusWorkspaceBlockedActionPresentation) {
        title = presentation.title
        detail = presentation.detail
    }

    static func commandFailure(_ error: Error, fallbackTitle: String) -> UserMessage {
        if let commandError = error as? WorkspaceCommandError,
           let presentation = FocusWorkspaceBlockedActionPresentation(error: commandError) {
            return UserMessage(focusWorkspacePresentation: presentation)
        }

        return UserMessage(title: fallbackTitle, detail: String(describing: error))
    }
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

extension NordColorToken {
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

#Preview {
    let store = WorkspaceStore.preview()
    let persistence = InMemoryWorkspacePersistenceStore()
    let restoreCoordinator = RestoreCoordinator(persistenceStore: persistence)
    let terminalHostController = TerminalHostController()
    let terminalExitEvents = TerminalExitEventSource()
    let fileAccessService = LocalWorkspaceFileAccess()
    let fileBufferController = WorkspaceFileBufferController(fileAccess: fileAccessService)
    ContentView(
        shellState: AppShellState(),
        store: store,
        commandService: DefaultWorkspaceCommandService(
            store: store,
            persistenceStore: persistence,
            restoreCoordinator: restoreCoordinator,
            terminalSurfaceManager: terminalHostController,
            fileAccess: fileAccessService,
            fileBufferManager: fileBufferController
        ),
        terminalHostController: terminalHostController,
        terminalExitEvents: terminalExitEvents,
        fileAccessService: fileAccessService,
        fileBufferController: fileBufferController
    )
}
