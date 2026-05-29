import Foundation

@MainActor
public struct AppDependencyContainer {
    public let workspaceStore: WorkspaceStore
    public let persistenceStore: any WorkspacePersistenceStore
    public let restoreCoordinator: RestoreCoordinator
    public let ghosttyAdapter: any GhosttyAdapter
    public let terminalHostController: TerminalHostController
    public let workspaceCommandService: any WorkspaceCommandService

    public init(
        workspaceStore: WorkspaceStore,
        persistenceStore: any WorkspacePersistenceStore,
        restoreCoordinator: RestoreCoordinator,
        ghosttyAdapter: any GhosttyAdapter,
        terminalHostController: TerminalHostController,
        workspaceCommandService: any WorkspaceCommandService
    ) {
        self.workspaceStore = workspaceStore
        self.persistenceStore = persistenceStore
        self.restoreCoordinator = restoreCoordinator
        self.ghosttyAdapter = ghosttyAdapter
        self.terminalHostController = terminalHostController
        self.workspaceCommandService = workspaceCommandService
    }

    public static func live() -> AppDependencyContainer {
        let persistenceStore = livePersistenceStore()
        let workspaceStore = WorkspaceStore()
        let restoreCoordinator = RestoreCoordinator(persistenceStore: persistenceStore)
        let ghosttyAdapter = LiveGhosttyAdapter()
        let terminalHostController = TerminalHostController(adapter: ghosttyAdapter)
        let workspaceCommandService = DefaultWorkspaceCommandService(
            store: workspaceStore,
            persistenceStore: persistenceStore,
            restoreCoordinator: restoreCoordinator,
            terminalSurfaceManager: terminalHostController
        )
        terminalHostController.onSurfaceExited = { tabID in
            Task { @MainActor in
                try? await workspaceCommandService.closeTab(tabID: tabID, force: true)
            }
        }
        return AppDependencyContainer(
            workspaceStore: workspaceStore,
            persistenceStore: persistenceStore,
            restoreCoordinator: restoreCoordinator,
            ghosttyAdapter: ghosttyAdapter,
            terminalHostController: terminalHostController,
            workspaceCommandService: workspaceCommandService
        )
    }

    private static func livePersistenceStore() -> any WorkspacePersistenceStore {
        do {
            let applicationSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let appDirectory = applicationSupport.appendingPathComponent("NativeMacADE", isDirectory: true)
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
            return try SQLiteWorkspaceMetadataStore(path: appDirectory.appendingPathComponent("Workspace.sqlite").path)
        } catch {
            preconditionFailure("Native Mac ADE requires durable workspace metadata persistence: \(error)")
        }
    }
}
