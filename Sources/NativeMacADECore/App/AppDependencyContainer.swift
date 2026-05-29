import Foundation

@MainActor
public struct AppDependencyContainer {
    public let workspaceStore: WorkspaceStore
    public let persistenceStore: any WorkspacePersistenceStore
    public let restoreCoordinator: RestoreCoordinator
    public let ghosttyAdapter: any GhosttyAdapter
    public let terminalHostController: TerminalHostController
    public let fileAccessService: any WorkspaceFileAccessing
    public let fileBufferController: any WorkspaceFileBufferManaging
    public let externalEditorOpener: any ExternalEditorOpening
    public let workspaceCommandService: any WorkspaceCommandService
    public let workspaceLogger: WorkspaceLogger
    public let performanceMetrics: PerformanceMetrics

    public init(
        workspaceStore: WorkspaceStore,
        persistenceStore: any WorkspacePersistenceStore,
        restoreCoordinator: RestoreCoordinator,
        ghosttyAdapter: any GhosttyAdapter,
        terminalHostController: TerminalHostController,
        fileAccessService: any WorkspaceFileAccessing,
        fileBufferController: any WorkspaceFileBufferManaging,
        externalEditorOpener: any ExternalEditorOpening,
        workspaceCommandService: any WorkspaceCommandService,
        workspaceLogger: WorkspaceLogger,
        performanceMetrics: PerformanceMetrics
    ) {
        self.workspaceStore = workspaceStore
        self.persistenceStore = persistenceStore
        self.restoreCoordinator = restoreCoordinator
        self.ghosttyAdapter = ghosttyAdapter
        self.terminalHostController = terminalHostController
        self.fileAccessService = fileAccessService
        self.fileBufferController = fileBufferController
        self.externalEditorOpener = externalEditorOpener
        self.workspaceCommandService = workspaceCommandService
        self.workspaceLogger = workspaceLogger
        self.performanceMetrics = performanceMetrics
    }

    public static func live() -> AppDependencyContainer {
        let persistenceStore = livePersistenceStore()
        let workspaceStore = WorkspaceStore()
        let restoreCoordinator = RestoreCoordinator(persistenceStore: persistenceStore)
        let ghosttyAdapter = LiveGhosttyAdapter()
        let terminalHostController = TerminalHostController(adapter: ghosttyAdapter)
        let fileAccessService = LocalWorkspaceFileAccess()
        let fileBufferController = WorkspaceFileBufferController(fileAccess: fileAccessService)
        let externalEditorOpener = SystemExternalEditorOpener()
        let workspaceLogger = WorkspaceLogger()
        let performanceMetrics = PerformanceMetrics()
        let workspaceCommandService = DefaultWorkspaceCommandService(
            store: workspaceStore,
            persistenceStore: persistenceStore,
            restoreCoordinator: restoreCoordinator,
            terminalSurfaceManager: terminalHostController,
            fileAccess: fileAccessService,
            fileBufferManager: fileBufferController,
            externalEditorOpener: externalEditorOpener,
            logger: workspaceLogger,
            metrics: performanceMetrics
        )
        terminalHostController.onSurfaceExited = { tabID, exitStatus in
            Task { @MainActor in
                workspaceCommandService.recordTerminalProcessExit(tabID: tabID, exitStatus: exitStatus)
                try? await workspaceCommandService.closeTab(tabID: tabID, force: true)
            }
        }
        return AppDependencyContainer(
            workspaceStore: workspaceStore,
            persistenceStore: persistenceStore,
            restoreCoordinator: restoreCoordinator,
            ghosttyAdapter: ghosttyAdapter,
            terminalHostController: terminalHostController,
            fileAccessService: fileAccessService,
            fileBufferController: fileBufferController,
            externalEditorOpener: externalEditorOpener,
            workspaceCommandService: workspaceCommandService,
            workspaceLogger: workspaceLogger,
            performanceMetrics: performanceMetrics
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
            let appDirectory = applicationSupport.appendingPathComponent("Atelier", isDirectory: true)
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
            return try SQLiteWorkspaceMetadataStore(path: appDirectory.appendingPathComponent("Workspace.sqlite").path)
        } catch {
            preconditionFailure("Atelier requires durable workspace metadata persistence: \(error)")
        }
    }
}
