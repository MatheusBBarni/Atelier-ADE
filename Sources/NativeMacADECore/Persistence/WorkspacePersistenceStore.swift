import Foundation

public protocol WorkspacePersistenceStore: Sendable {
    func loadProjects() async throws -> [WorkspaceProject]
    func loadSessions() async throws -> [WorkspaceSession]
    func loadTabs() async throws -> [WorkspaceTab]
    func loadSessionShortcuts() async throws -> [SessionShortcut]
    func loadRestoreSnapshot() async throws -> RestoreSnapshot?
    func save(project: WorkspaceProject) async throws
    func save(session: WorkspaceSession) async throws
    func save(tab: WorkspaceTab) async throws
    func save(shortcut: SessionShortcut) async throws
    func save(snapshot: RestoreSnapshot) async throws
    func deleteProject(id: UUID) async throws
    func deleteSession(id: UUID) async throws
    func deleteTab(id: UUID) async throws
    func deleteShortcut(id: UUID) async throws
}

public actor InMemoryWorkspacePersistenceStore: WorkspacePersistenceStore {
    private var projects: [WorkspaceProject]
    private var sessions: [WorkspaceSession]
    private var tabs: [WorkspaceTab]
    private var shortcuts: [SessionShortcut]
    private var restoreSnapshot: RestoreSnapshot?

    public init(
        projects: [WorkspaceProject] = [],
        sessions: [WorkspaceSession] = [],
        tabs: [WorkspaceTab] = [],
        shortcuts: [SessionShortcut] = [],
        restoreSnapshot: RestoreSnapshot? = nil
    ) {
        self.projects = projects
        self.sessions = sessions
        self.tabs = tabs
        self.shortcuts = shortcuts
        self.restoreSnapshot = restoreSnapshot
    }

    public func loadProjects() async throws -> [WorkspaceProject] {
        projects.sorted {
            if $0.sortIndex == $1.sortIndex { return $0.lastOpenedAt > $1.lastOpenedAt }
            return $0.sortIndex < $1.sortIndex
        }
    }

    public func loadSessions() async throws -> [WorkspaceSession] {
        sessions.sorted {
            if $0.lastActivatedAt == $1.lastActivatedAt { return $0.createdAt > $1.createdAt }
            return $0.lastActivatedAt > $1.lastActivatedAt
        }
    }

    public func loadTabs() async throws -> [WorkspaceTab] {
        tabs.sorted {
            if $0.sessionID == $1.sessionID { return $0.ordinal < $1.ordinal }
            return $0.sessionID.uuidString < $1.sessionID.uuidString
        }
    }

    public func loadSessionShortcuts() async throws -> [SessionShortcut] {
        shortcuts.sorted { $0.label < $1.label }
    }
    public func loadRestoreSnapshot() async throws -> RestoreSnapshot? { restoreSnapshot }

    public func save(project: WorkspaceProject) async throws {
        projects.removeAll { $0.id == project.id }
        projects.append(project)
    }

    public func save(session: WorkspaceSession) async throws {
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
    }

    public func save(tab: WorkspaceTab) async throws {
        tabs.removeAll { $0.id == tab.id }
        tabs.append(tab)
    }

    public func save(shortcut: SessionShortcut) async throws {
        shortcuts.removeAll { $0.id == shortcut.id }
        shortcuts.append(shortcut)
    }

    public func save(snapshot: RestoreSnapshot) async throws {
        restoreSnapshot = snapshot
    }

    public func deleteProject(id: UUID) async throws {
        projects.removeAll { $0.id == id }
        sessions.removeAll { $0.projectID == id }
        tabs.removeAll { tab in !sessions.contains { $0.id == tab.sessionID } }
    }

    public func deleteSession(id: UUID) async throws {
        sessions.removeAll { $0.id == id }
        tabs.removeAll { $0.sessionID == id }
    }

    public func deleteTab(id: UUID) async throws {
        tabs.removeAll { $0.id == id }
    }

    public func deleteShortcut(id: UUID) async throws {
        shortcuts.removeAll { $0.id == id }
        for index in sessions.indices where sessions[index].shortcutID == id {
            sessions[index].shortcutID = nil
        }
    }
}
