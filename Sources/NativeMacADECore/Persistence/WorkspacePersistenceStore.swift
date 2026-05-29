import Foundation

public protocol WorkspacePersistenceStore: Sendable {
    func loadProjects() async throws -> [WorkspaceProject]
    func loadSessions() async throws -> [WorkspaceSession]
    func loadTabs() async throws -> [WorkspaceTab]
    func loadRestoreSnapshot() async throws -> RestoreSnapshot?
    func save(project: WorkspaceProject) async throws
    func save(session: WorkspaceSession) async throws
    func save(tab: WorkspaceTab) async throws
    func save(snapshot: RestoreSnapshot) async throws
}

public actor InMemoryWorkspacePersistenceStore: WorkspacePersistenceStore {
    private var projects: [WorkspaceProject]
    private var sessions: [WorkspaceSession]
    private var tabs: [WorkspaceTab]
    private var restoreSnapshot: RestoreSnapshot?

    public init(
        projects: [WorkspaceProject] = [],
        sessions: [WorkspaceSession] = [],
        tabs: [WorkspaceTab] = [],
        restoreSnapshot: RestoreSnapshot? = nil
    ) {
        self.projects = projects
        self.sessions = sessions
        self.tabs = tabs
        self.restoreSnapshot = restoreSnapshot
    }

    public func loadProjects() async throws -> [WorkspaceProject] { projects }
    public func loadSessions() async throws -> [WorkspaceSession] { sessions }
    public func loadTabs() async throws -> [WorkspaceTab] { tabs }
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

    public func save(snapshot: RestoreSnapshot) async throws {
        restoreSnapshot = snapshot
    }
}
