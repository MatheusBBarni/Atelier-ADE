import Foundation

@MainActor
public struct AppDependencyContainer {
    public let workspaceStore: WorkspaceStore
    public let persistenceStore: any WorkspacePersistenceStore
    public let restoreCoordinator: RestoreCoordinator
    public let ghosttyAdapter: any GhosttyAdapter

    public init(
        workspaceStore: WorkspaceStore,
        persistenceStore: any WorkspacePersistenceStore,
        restoreCoordinator: RestoreCoordinator,
        ghosttyAdapter: any GhosttyAdapter
    ) {
        self.workspaceStore = workspaceStore
        self.persistenceStore = persistenceStore
        self.restoreCoordinator = restoreCoordinator
        self.ghosttyAdapter = ghosttyAdapter
    }

    public static func live() -> AppDependencyContainer {
        let persistenceStore = InMemoryWorkspacePersistenceStore()
        return AppDependencyContainer(
            workspaceStore: WorkspaceStore(),
            persistenceStore: persistenceStore,
            restoreCoordinator: RestoreCoordinator(persistenceStore: persistenceStore),
            ghosttyAdapter: UnavailableGhosttyAdapter()
        )
    }
}
