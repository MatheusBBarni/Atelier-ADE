import Foundation
import Testing
@testable import NativeMacADECore

// Suite: Default workspace command service persistence integration
// Invariant: command-service persistence and restore operations keep the selected workspace graph coherent.
// Boundary IN: DefaultWorkspaceCommandService, SQLiteWorkspaceMetadataStore, RestoreCoordinator, and WorkspaceStore.
// Boundary OUT: live Ghostty surfaces, replaced with a fake terminal surface manager.
@Suite(.serialized)
@MainActor
struct DefaultWorkspaceCommandServiceIntegrationTests {
    @Test
    func failedTerminalSurfaceCreationLeavesPersistenceAndMemoryTabStateUnchanged() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let tabsBefore = harness.store.tabs
        let persistedTabsBefore = try await harness.persistence.loadTabs()

        harness.terminal.surfaceCreationError = GhosttyAdapterError.surfaceCreationFailed("surface failed")

        await #expect(throws: WorkspaceCommandError.terminalUnavailable("surface failed")) {
            _ = try await harness.service.createTab(sessionID: session.id)
        }
        let persistedTabsAfter = try await harness.persistence.loadTabs()
        let snapshotAfter = try await harness.persistence.loadRestoreSnapshot()

        #expect(harness.store.tabs == tabsBefore)
        #expect(persistedTabsAfter == persistedTabsBefore)
        #expect(harness.store.selectedTabID == nil)
        #expect(snapshotAfter?.selectedTabID == nil)
    }

    @Test
    func restoringSavedProjectSessionTabGraphReconstructsSelectedContext() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let projectID = UUID()
        let olderSessionID = UUID()
        let selectedSessionID = UUID()
        let backgroundTabID = UUID()
        let selectedTabID = UUID()
        let project = WorkspaceProject(
            id: projectID,
            path: projectPath,
            displayName: URL(fileURLWithPath: projectPath).lastPathComponent,
            createdAt: Date(timeIntervalSince1970: 10),
            lastOpenedAt: Date(timeIntervalSince1970: 20),
            sortIndex: 0
        )
        let olderSession = WorkspaceSession(
            id: olderSessionID,
            projectID: projectID,
            title: "Older",
            createdAt: Date(timeIntervalSince1970: 30),
            lastActivatedAt: Date(timeIntervalSince1970: 40)
        )
        let selectedSession = WorkspaceSession(
            id: selectedSessionID,
            projectID: projectID,
            title: "Selected",
            createdAt: Date(timeIntervalSince1970: 50),
            lastActivatedAt: Date(timeIntervalSince1970: 60)
        )
        let backgroundTab = WorkspaceTab(
            id: backgroundTabID,
            sessionID: selectedSessionID,
            workingDirectory: projectPath,
            ordinal: 0,
            createdAt: Date(timeIntervalSince1970: 70),
            lastActivatedAt: Date(timeIntervalSince1970: 80)
        )
        let selectedTab = WorkspaceTab(
            id: selectedTabID,
            sessionID: selectedSessionID,
            workingDirectory: projectPath,
            ordinal: 1,
            createdAt: Date(timeIntervalSince1970: 90),
            lastActivatedAt: Date(timeIntervalSince1970: 100)
        )

        try await harness.persistence.save(project: project)
        try await harness.persistence.save(session: olderSession)
        try await harness.persistence.save(session: selectedSession)
        try await harness.persistence.save(tab: backgroundTab)
        try await harness.persistence.save(tab: selectedTab)
        try await harness.persistence.save(snapshot: RestoreSnapshot(
            selectedProjectID: projectID,
            selectedSessionID: selectedSessionID,
            selectedTabID: selectedTabID,
            tabOrder: [backgroundTabID, selectedTabID],
            updatedAt: Date(timeIntervalSince1970: 110)
        ))

        try await harness.service.restoreWorkspace()

        #expect(harness.store.selectedProjectID == projectID)
        #expect(harness.store.selectedSessionID == selectedSessionID)
        #expect(harness.store.selectedTabID == selectedTabID)
        #expect(harness.store.selectedProject == project)
        #expect(harness.store.selectedSession == selectedSession)
        #expect(harness.store.selectedTab == selectedTab)
        #expect(harness.store.tabsForSelectedSession.map(\.id) == [backgroundTabID, selectedTabID])
    }

    @Test
    func closingLastTabRemovesPersistenceAndClearsSelectedTab() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let tab = try await harness.service.createTab(sessionID: session.id)

        try await harness.service.closeTab(tabID: tab.id, force: false)
        let persistedTabs = try await harness.persistence.loadTabs()
        let snapshot = try await harness.persistence.loadRestoreSnapshot()

        #expect(harness.store.tabs.isEmpty)
        #expect(harness.store.selectedProjectID == project.id)
        #expect(harness.store.selectedSessionID == session.id)
        #expect(harness.store.selectedTabID == nil)
        #expect(persistedTabs.isEmpty)
        #expect(snapshot?.selectedTabID == nil)
        #expect(snapshot?.tabOrder.isEmpty == true)
        #expect(harness.terminal.closeRequests.count == 1)
    }

    @Test
    func removingProjectDeletesDependentGraphAndClearsPersistedSelection() async throws {
        let harness = try makeHarness()
        let project = try await harness.service.openProject(path: makeTemporaryProjectDirectory())
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let tab = try await harness.service.createTab(sessionID: session.id)

        try await harness.service.removeProject(id: project.id)
        let persistedProjects = try await harness.persistence.loadProjects()
        let persistedSessions = try await harness.persistence.loadSessions()
        let persistedTabs = try await harness.persistence.loadTabs()
        let snapshot = try await harness.persistence.loadRestoreSnapshot()

        #expect(harness.store.projects.isEmpty)
        #expect(harness.store.sessions.isEmpty)
        #expect(harness.store.tabs.isEmpty)
        #expect(harness.store.selectedProjectID == nil)
        #expect(harness.store.selectedSessionID == nil)
        #expect(harness.store.selectedTabID == nil)
        #expect(persistedProjects.isEmpty)
        #expect(persistedSessions.isEmpty)
        #expect(persistedTabs.isEmpty)
        #expect(snapshot?.selectedProjectID == nil)
        #expect(snapshot?.selectedSessionID == nil)
        #expect(snapshot?.selectedTabID == nil)
        #expect(snapshot?.tabOrder.isEmpty == true)
        #expect(harness.terminal.createdTabs == [tab])
    }

    private func makeHarness(now: @escaping @MainActor () -> Date = Date.init) throws -> CommandServiceIntegrationHarness {
        let store = WorkspaceStore()
        let persistence = try SQLiteWorkspaceMetadataStore(path: temporaryDatabasePath())
        let terminal = FakeIntegrationTerminalSurfaceManager()
        let coordinator = RestoreCoordinator(persistenceStore: persistence)
        let service = DefaultWorkspaceCommandService(
            store: store,
            persistenceStore: persistence,
            restoreCoordinator: coordinator,
            terminalSurfaceManager: terminal,
            now: now
        )

        return CommandServiceIntegrationHarness(
            store: store,
            persistence: persistence,
            terminal: terminal,
            service: service
        )
    }

    private func temporaryDatabasePath() -> String {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("native-mac-ade-command-service-\(UUID().uuidString).sqlite")
            .path
    }

    private func makeTemporaryProjectDirectory(named name: String = UUID().uuidString) throws -> String {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("native-mac-ade-command-service-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url.path
    }
}

@MainActor
private struct CommandServiceIntegrationHarness {
    let store: WorkspaceStore
    let persistence: SQLiteWorkspaceMetadataStore
    let terminal: FakeIntegrationTerminalSurfaceManager
    let service: DefaultWorkspaceCommandService
}

@MainActor
private final class FakeIntegrationTerminalSurfaceManager: WorkspaceTerminalSurfaceManaging {
    private(set) var createdTabs: [WorkspaceTab] = []
    private(set) var closeRequests: [GhosttySurfaceHandle] = []
    var surfaceCreationError: Error?
    var canCloseResult = true

    func createSurface(for tab: WorkspaceTab) async throws -> GhosttySurfaceHandle {
        createdTabs.append(tab)
        if let surfaceCreationError {
            throw surfaceCreationError
        }
        return GhosttySurfaceHandle()
    }

    func canClose(surface: GhosttySurfaceHandle) async -> Bool {
        closeRequests.append(surface)
        return canCloseResult
    }
}
