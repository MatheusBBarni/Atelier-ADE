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
    private let now: @MainActor () -> Date
    private var surfacesByTabID: [UUID: GhosttySurfaceHandle] = [:]

    public init(
        store: WorkspaceStore,
        persistenceStore: any WorkspacePersistenceStore,
        restoreCoordinator: RestoreCoordinator,
        terminalSurfaceManager: any WorkspaceTerminalSurfaceManaging,
        fileManager: FileManager = .default,
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        self.store = store
        self.persistenceStore = persistenceStore
        self.restoreCoordinator = restoreCoordinator
        self.terminalSurfaceManager = terminalSurfaceManager
        self.fileManager = fileManager
        self.now = now
    }

    public func openProject(path: String) async throws -> WorkspaceProject {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        guard standardizedPath.hasPrefix("/"), directoryExists(at: standardizedPath) else {
            throw WorkspaceCommandError.invalidProjectPath(path)
        }

        let timestamp = now()
        let project: WorkspaceProject
        if var existing = store.project(matchingPath: standardizedPath) {
            existing.lastOpenedAt = timestamp
            project = existing
        } else if var persistedProject = try await persistedProject(matchingPath: standardizedPath) {
            persistedProject.lastOpenedAt = timestamp
            project = persistedProject
        } else {
            project = WorkspaceProject(
                path: standardizedPath,
                displayName: URL(fileURLWithPath: standardizedPath).lastPathComponent,
                createdAt: timestamp,
                lastOpenedAt: timestamp,
                sortIndex: store.projects.count
            )
        }

        try await persist { try await persistenceStore.save(project: project) }
        store.upsertProject(project)
        try await persistSnapshot()
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

    public func createSession(projectID: UUID, shortcutID: UUID?) async throws -> WorkspaceSession {
        guard store.projects.contains(where: { $0.id == projectID }) else {
            throw WorkspaceCommandError.missingProject(projectID)
        }
        if let shortcutID {
            let shortcuts = try await persist { try await persistenceStore.loadSessionShortcuts() }
            guard shortcuts.contains(where: { $0.id == shortcutID }) else {
                throw WorkspaceCommandError.missingShortcut(shortcutID)
            }
        }

        let timestamp = now()
        let session = WorkspaceSession(
            projectID: projectID,
            shortcutID: shortcutID,
            createdAt: timestamp,
            lastActivatedAt: timestamp
        )
        try await persist { try await persistenceStore.save(session: session) }
        store.upsertSession(session)
        try await persistSnapshot()
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
        guard let session = store.sessions.first(where: { $0.id == sessionID }) else {
            throw WorkspaceCommandError.missingSession(sessionID)
        }
        guard let project = store.projects.first(where: { $0.id == session.projectID }) else {
            throw WorkspaceCommandError.missingProject(session.projectID)
        }

        var launchCommand: String?
        var launchArgumentsJSON: String?
        if let shortcutID = session.shortcutID {
            let shortcuts = try await persist { try await persistenceStore.loadSessionShortcuts() }
            guard let shortcut = shortcuts.first(where: { $0.id == shortcutID }) else {
                throw WorkspaceCommandError.missingShortcut(shortcutID)
            }
            launchCommand = shortcut.launchCommand
            launchArgumentsJSON = shortcut.launchArgumentsJSON
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

        let surface = try await createSurface(for: tab)
        try await persist { try await persistenceStore.save(tab: tab) }
        surfacesByTabID[tab.id] = surface
        store.upsertTab(tab)
        try await persistSnapshot()
        return tab
    }

    @discardableResult
    public func restoreWorkspace() async throws -> RestoreWorkspaceResult {
        var restoreResult = try await persist { try await restoreCoordinator.restoreWorkspace() }
        let restoredStore = restoreResult.store
        store.restore(
            projects: restoredStore.projects,
            sessions: restoredStore.sessions,
            tabs: restoredStore.tabs,
            selection: restoredStore.selection
        )
        surfacesByTabID.removeAll()
        for tab in store.tabs {
            do {
                let surface = try await createSurface(for: tab)
                surfacesByTabID[tab.id] = surface
            } catch {
                restoreResult.diagnostics.append(RestoreDiagnostic(
                    severity: .failure,
                    message: "Terminal for restored tab \(tab.id.uuidString) could not be recreated: \(String(describing: error))"
                ))
            }
        }
        return restoreResult
    }

    public func closeTab(tabID: UUID, force: Bool) async throws {
        guard store.tabs.contains(where: { $0.id == tabID }) else {
            throw WorkspaceCommandError.missingTab(tabID)
        }
        let surface = surfacesByTabID[tabID] ?? terminalSurfaceManager.surface(for: tabID)
        if !force, let surface {
            let canClose = await terminalSurfaceManager.canClose(surface: surface)
            guard canClose else { throw WorkspaceCommandError.closeRejected(tabID) }
        }

        try await persist { try await persistenceStore.deleteTab(id: tabID) }
        surfacesByTabID[tabID] = nil
        terminalSurfaceManager.releaseSurface(for: tabID)
        store.removeTab(id: tabID)
        try await persistSnapshot()
    }

    private func directoryExists(at path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
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
