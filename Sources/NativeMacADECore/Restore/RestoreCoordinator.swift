import Foundation

@MainActor
public struct RestoreCoordinator {
    private let persistenceStore: any WorkspacePersistenceStore

    public init(persistenceStore: any WorkspacePersistenceStore) {
        self.persistenceStore = persistenceStore
    }

    public func restoreStore() async throws -> WorkspaceStore {
        let projects = try await persistenceStore.loadProjects()
        let sessions = try await persistenceStore.loadSessions()
        let tabs = try await persistenceStore.loadTabs()
        let snapshot = try await persistenceStore.loadRestoreSnapshot()

        return WorkspaceStore(
            projects: projects,
            sessions: sessions,
            tabs: tabs,
            selectedProjectID: snapshot?.selectedProjectID,
            selectedSessionID: snapshot?.selectedSessionID,
            selectedTabID: snapshot?.selectedTabID
        )
    }
}
