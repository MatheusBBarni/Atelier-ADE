import Foundation

@MainActor
public protocol WorkspaceTerminalSurfaceManaging: AnyObject {
    func createSurface(for tab: WorkspaceTab) async throws -> GhosttySurfaceHandle
    func surface(for tabID: UUID) -> GhosttySurfaceHandle?
    func canClose(surface: GhosttySurfaceHandle) async -> Bool
    func focus(tabID: UUID)
    func resize(tabID: UUID, columns: Int, rows: Int)
    func hasExited(tabID: UUID) async -> Bool
    func releaseSurface(for tabID: UUID)
}

@MainActor
public final class DefaultWorkspaceCommandService: WorkspaceCommandService {
    private let store: WorkspaceStore
    private let persistenceStore: any WorkspacePersistenceStore
    private let restoreCoordinator: RestoreCoordinator
    private let terminalSurfaceManager: any WorkspaceTerminalSurfaceManaging
    private let fileManager: FileManager
    public let logger: WorkspaceLogger
    public let metrics: PerformanceMetrics
    private let now: @MainActor () -> Date
    private var surfacesByTabID: [UUID: GhosttySurfaceHandle] = [:]

    public init(
        store: WorkspaceStore,
        persistenceStore: any WorkspacePersistenceStore,
        restoreCoordinator: RestoreCoordinator,
        terminalSurfaceManager: any WorkspaceTerminalSurfaceManaging,
        fileManager: FileManager = .default,
        logger: WorkspaceLogger = WorkspaceLogger(),
        metrics: PerformanceMetrics = PerformanceMetrics(),
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        self.store = store
        self.persistenceStore = persistenceStore
        self.restoreCoordinator = restoreCoordinator
        self.terminalSurfaceManager = terminalSurfaceManager
        self.fileManager = fileManager
        self.logger = logger
        self.metrics = metrics
        self.now = now
    }

    public func openProject(path: String) async throws -> WorkspaceProject {
        let startedAt = now()
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        guard standardizedPath.hasPrefix("/"), directoryExists(at: standardizedPath) else {
            throw WorkspaceCommandError.invalidProjectPath(path)
        }

        let timestamp = now()
        let project: WorkspaceProject
        let reusedProject: Bool
        if var existing = store.project(matchingPath: standardizedPath) {
            existing.lastOpenedAt = timestamp
            project = existing
            reusedProject = true
        } else if var persistedProject = try await persistedProject(matchingPath: standardizedPath) {
            persistedProject.lastOpenedAt = timestamp
            project = persistedProject
            reusedProject = true
        } else {
            project = WorkspaceProject(
                path: standardizedPath,
                displayName: URL(fileURLWithPath: standardizedPath).lastPathComponent,
                createdAt: timestamp,
                lastOpenedAt: timestamp,
                sortIndex: store.projects.count
            )
            reusedProject = false
        }

        try await persist { try await persistenceStore.save(project: project) }
        store.upsertProject(project)
        try await persistSnapshot()
        metrics.recordProjectOpen(duration: now().timeIntervalSince(startedAt))
        logger.emit("project_opened", fields: [
            "project_id": project.id.uuidString,
            "hashed_path": WorkspacePrivacy.hashIdentifier(project.path),
            "reused_project": String(reusedProject)
        ])
        return project
    }

    public func removeProject(id: UUID) async throws {
        guard store.projects.contains(where: { $0.id == id }) else {
            let persistedProjects = try await persist { try await persistenceStore.loadProjects() }
            guard persistedProjects.contains(where: { $0.id == id }) else {
                throw WorkspaceCommandError.missingProject(id)
            }
            try await persist { try await persistenceStore.deleteProject(id: id) }
            try await persistSnapshot()
            return
        }

        let removedSessionIDs = Set(store.sessions.filter { $0.projectID == id }.map(\.id))
        let removedTabs = store.tabs.filter { removedSessionIDs.contains($0.sessionID) }
        for tab in removedTabs {
            if let surface = surfacesByTabID[tab.id] ?? terminalSurfaceManager.surface(for: tab.id) {
                guard await terminalSurfaceManager.canClose(surface: surface) else {
                    throw WorkspaceCommandError.closeRejected(tab.id)
                }
            }
        }
        let removedTabIDs = Set(removedTabs.map(\.id))

        try await persist { try await persistenceStore.deleteProject(id: id) }
        for tabID in removedTabIDs {
            terminalSurfaceManager.releaseSurface(for: tabID)
        }
        surfacesByTabID = surfacesByTabID.filter { tabID, _ in !removedTabIDs.contains(tabID) }
        store.removeProject(id: id)
        try await persistSnapshot()
    }

    public func selectProject(id: UUID?) async throws {
        store.selectProject(id: id)
        try await persistSnapshot()
    }

    public func selectSession(id: UUID?) async throws {
        store.selectSession(id: id)
        try await persistSnapshot()
    }

    public func selectTab(id: UUID?) async throws {
        store.selectTab(id: id)
        try await persistSnapshot()
    }

    public func availableSessionShortcuts() async throws -> [SessionShortcut] {
        try await loadSessionShortcutsIncludingBuiltIns()
    }

    public func createSession(projectID: UUID, shortcutID: UUID?) async throws -> WorkspaceSession {
        guard store.projects.contains(where: { $0.id == projectID }) else {
            throw WorkspaceCommandError.missingProject(projectID)
        }
        let selectedShortcut: SessionShortcut?
        if let shortcutID {
            let shortcuts = try await loadSessionShortcutsIncludingBuiltIns()
            guard let shortcut = shortcuts.first(where: { $0.id == shortcutID }) else {
                throw WorkspaceCommandError.missingShortcut(shortcutID)
            }
            selectedShortcut = shortcut
        } else {
            selectedShortcut = nil
        }

        let timestamp = now()
        let session = WorkspaceSession(
            projectID: projectID,
            shortcutID: shortcutID,
            createdAt: timestamp,
            lastActivatedAt: timestamp
        )
        var fields = [
            "project_id": projectID.uuidString,
            "session_id": session.id.uuidString
        ]
        if let selectedShortcut {
            fields["shortcut_id"] = selectedShortcut.id.uuidString
            fields["launch_profile_label"] = selectedShortcut.label
            let project = try requireProject(id: projectID)
            let tab = WorkspaceTab(
                sessionID: session.id,
                workingDirectory: project.path,
                launchCommand: selectedShortcut.launchCommand,
                launchArgumentsJSON: selectedShortcut.launchArgumentsJSON,
                ordinal: 0,
                createdAt: timestamp,
                lastActivatedAt: timestamp
            )
            let surface: GhosttySurfaceHandle
            do {
                surface = try await createSurface(for: tab)
            } catch {
                metrics.recordTerminalSurfaceFailure()
                logger.emit("terminal_surface_failed", fields: [
                    "tab_id": tab.id.uuidString,
                    "session_id": session.id.uuidString,
                    "reason": String(describing: error)
                ])
                throw error
            }
            do {
                try await persist { try await persistenceStore.save(session: session, firstTab: tab) }
            } catch {
                terminalSurfaceManager.releaseSurface(for: tab.id)
                throw error
            }
            surfacesByTabID[tab.id] = surface
            store.upsertSession(session)
            store.upsertTab(tab)
            try await persistSnapshot()
            metrics.recordTabCreation(duration: now().timeIntervalSince(timestamp))
            logger.emit("tab_created", fields: [
                "project_id": project.id.uuidString,
                "session_id": session.id.uuidString,
                "tab_id": tab.id.uuidString,
                "launch_profile_label": selectedShortcut.label,
                "duration_ms": String(Int((now().timeIntervalSince(timestamp) * 1_000).rounded()))
            ])
        } else {
            try await persist { try await persistenceStore.save(session: session) }
            store.upsertSession(session)
            try await persistSnapshot()
        }
        metrics.recordSessionCreate()
        logger.emit("session_created", fields: fields)
        return session
    }

    public func renameSession(sessionID: UUID, title: String) async throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw WorkspaceCommandError.invalidSessionTitle(title)
        }
        guard var session = store.sessions.first(where: { $0.id == sessionID }) else {
            throw WorkspaceCommandError.missingSession(sessionID)
        }

        session.rename(to: trimmedTitle)
        try await persist { try await persistenceStore.save(session: session) }
        store.upsertSession(session, select: store.selectedSessionID == sessionID)
        try await persistSnapshot()
    }

    public func createTab(sessionID: UUID) async throws -> WorkspaceTab {
        let startedAt = now()
        guard let session = store.sessions.first(where: { $0.id == sessionID }) else {
            throw WorkspaceCommandError.missingSession(sessionID)
        }
        guard let project = store.projects.first(where: { $0.id == session.projectID }) else {
            throw WorkspaceCommandError.missingProject(session.projectID)
        }

        var launchCommand: String?
        var launchArgumentsJSON: String?
        var launchProfileLabel = "default"
        if let shortcutID = session.shortcutID {
            let shortcuts = try await loadSessionShortcutsIncludingBuiltIns()
            guard let shortcut = shortcuts.first(where: { $0.id == shortcutID }) else {
                throw WorkspaceCommandError.missingShortcut(shortcutID)
            }
            launchCommand = shortcut.launchCommand
            launchArgumentsJSON = shortcut.launchArgumentsJSON
            launchProfileLabel = shortcut.label
        }

        let timestamp = now()
        let tab = WorkspaceTab(
            sessionID: session.id,
            workingDirectory: project.path,
            launchCommand: launchCommand,
            launchArgumentsJSON: launchArgumentsJSON,
            ordinal: store.nextTabOrdinal(for: session.id),
            createdAt: timestamp,
            lastActivatedAt: timestamp
        )

        let surface: GhosttySurfaceHandle
        do {
            surface = try await createSurface(for: tab)
        } catch {
            metrics.recordTerminalSurfaceFailure()
            logger.emit("terminal_surface_failed", fields: [
                "tab_id": tab.id.uuidString,
                "session_id": session.id.uuidString,
                "reason": String(describing: error)
            ])
            throw error
        }
        do {
            try await persist { try await persistenceStore.save(tab: tab) }
        } catch {
            terminalSurfaceManager.releaseSurface(for: tab.id)
            throw error
        }
        surfacesByTabID[tab.id] = surface
        store.upsertTab(tab)
        try await persistSnapshot()
        metrics.recordTabCreation(duration: now().timeIntervalSince(startedAt))
        logger.emit("tab_created", fields: [
            "project_id": project.id.uuidString,
            "session_id": session.id.uuidString,
            "tab_id": tab.id.uuidString,
            "launch_profile_label": launchProfileLabel,
            "duration_ms": String(Int((now().timeIntervalSince(startedAt) * 1_000).rounded()))
        ])
        return tab
    }

    @discardableResult
    public func restoreWorkspace() async throws -> RestoreWorkspaceResult {
        let startedAt = now()
        logger.emit("restore_started", fields: [:])
        let restoreResultFromCoordinator: RestoreWorkspaceResult
        do {
            restoreResultFromCoordinator = try await persist { try await restoreCoordinator.restoreWorkspace() }
        } catch {
            metrics.recordRestore(duration: now().timeIntervalSince(startedAt), succeeded: false, skippedProjectCount: 0)
            logger.emit("restore_completed", fields: [
                "project_count": "0",
                "session_count": "0",
                "tab_count": "0",
                "skipped_project_count": "0",
                "duration_ms": String(Int((now().timeIntervalSince(startedAt) * 1_000).rounded())),
                "succeeded": "false",
                "reason": String(describing: error)
            ])
            throw error
        }
        var restoreResult = restoreResultFromCoordinator
        let restoredStore = restoreResult.store
        store.restore(
            projects: restoredStore.projects,
            sessions: restoredStore.sessions,
            tabs: restoredStore.tabs,
            selection: restoredStore.selection
        )
        surfacesByTabID.removeAll()
        for tab in store.tabs {
            let surfaceStartedAt = now()
            do {
                let surface = try await createSurface(for: tab)
                surfacesByTabID[tab.id] = surface
                metrics.recordTabCreation(duration: now().timeIntervalSince(surfaceStartedAt))
            } catch {
                metrics.recordTerminalSurfaceFailure()
                logger.emit("terminal_surface_failed", fields: [
                    "tab_id": tab.id.uuidString,
                    "session_id": tab.sessionID.uuidString,
                    "reason": String(describing: error)
                ])
                restoreResult.diagnostics.append(RestoreDiagnostic(
                    severity: .failure,
                    message: "Terminal for restored tab \(tab.id.uuidString) could not be recreated: \(String(describing: error))"
                ))
            }
        }
        for skippedProject in restoreResult.skippedProjects {
            logger.emit("restore_skipped_project", fields: [
                "project_id": skippedProject.id.uuidString,
                "hashed_path": WorkspacePrivacy.hashIdentifier(skippedProject.path),
                "reason": skippedProject.reason
            ])
        }
        let duration = now().timeIntervalSince(startedAt)
        let hasFailure = restoreResult.diagnostics.contains { $0.severity == .failure }
        metrics.recordRestore(
            duration: duration,
            succeeded: !hasFailure,
            skippedProjectCount: restoreResult.skippedProjects.count
        )
        metrics.recordLaunchToReady(duration: duration)
        logger.emit("restore_completed", fields: [
            "project_count": String(store.projects.count),
            "session_count": String(store.sessions.count),
            "tab_count": String(store.tabs.count),
            "skipped_project_count": String(restoreResult.skippedProjects.count),
            "duration_ms": String(Int((duration * 1_000).rounded())),
            "succeeded": String(!hasFailure)
        ])
        return restoreResult
    }

    public func closeTab(tabID: UUID, force: Bool) async throws {
        guard store.tabs.contains(where: { $0.id == tabID }) else {
            throw WorkspaceCommandError.missingTab(tabID)
        }
        let surface = surfacesByTabID[tabID] ?? terminalSurfaceManager.surface(for: tabID)
        if !force, let surface {
            let canClose = await terminalSurfaceManager.canClose(surface: surface)
            metrics.recordCloseConfirmation(accepted: canClose)
            guard canClose else { throw WorkspaceCommandError.closeRejected(tabID) }
        }

        try await persist { try await persistenceStore.deleteTab(id: tabID) }
        surfacesByTabID[tabID] = nil
        terminalSurfaceManager.releaseSurface(for: tabID)
        store.removeTab(id: tabID)
        try await persistSnapshot()
    }

    public func recordTerminalProcessExit(tabID: UUID, exitStatus: Int32? = nil) {
        metrics.recordTerminalProcessExit()
        var fields = [
            "tab_id": tabID.uuidString,
            "exit_status": exitStatus.map(String.init) ?? "unknown"
        ]
        if let tab = store.tabs.first(where: { $0.id == tabID }) {
            fields["session_id"] = tab.sessionID.uuidString
        }
        logger.emit("terminal_process_exited", fields: fields)
    }

    public func recentWorkspaceEvents() -> [WorkspaceLogEvent] {
        logger.events
    }

    public func pilotDiagnostics() -> PilotDiagnostics {
        metrics.diagnostics()
    }

    private func loadSessionShortcutsIncludingBuiltIns() async throws -> [SessionShortcut] {
        var shortcuts = try await persist { try await persistenceStore.loadSessionShortcuts() }
        let existingIDs = Set(shortcuts.map(\.id))
        for shortcut in SessionShortcut.builtInDefaults where !existingIDs.contains(shortcut.id) {
            try await persist { try await persistenceStore.save(shortcut: shortcut) }
            shortcuts.append(shortcut)
        }
        return shortcuts.sorted { $0.label < $1.label }
    }

    private func directoryExists(at path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func requireProject(id: UUID) throws -> WorkspaceProject {
        guard let project = store.projects.first(where: { $0.id == id }) else {
            throw WorkspaceCommandError.missingProject(id)
        }
        return project
    }

    private func persistedProject(matchingPath path: String) async throws -> WorkspaceProject? {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        let persistedProjects = try await persist { try await persistenceStore.loadProjects() }
        return persistedProjects.first {
            URL(fileURLWithPath: $0.path).standardizedFileURL.path == standardizedPath
        }
    }

    private func createSurface(for tab: WorkspaceTab) async throws -> GhosttySurfaceHandle {
        do {
            return try await terminalSurfaceManager.createSurface(for: tab)
        } catch let error as GhosttyAdapterError {
            throw error.workspaceCommandError
        } catch let error as WorkspaceCommandError {
            throw error
        } catch {
            throw WorkspaceCommandError.terminalUnavailable(String(describing: error))
        }
    }

    private func persist<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as WorkspaceCommandError {
            throw error
        } catch {
            throw WorkspaceCommandError.persistenceFailed(String(describing: error))
        }
    }

    private func persistSnapshot() async throws {
        let snapshot = store.snapshot(updatedAt: now())
        try await persist { try await persistenceStore.save(snapshot: snapshot) }
    }
}
