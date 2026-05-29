import Foundation
import SQLite3
import Testing
@testable import NativeMacADECore

@Suite(.serialized)
@MainActor
struct RestoreCoordinatorIntegrationTests {
    @Test
    func relaunchRestoreReconstructsVisibleLayoutAndCreatesFreshSurfaces() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let projectID = UUID()
        let sessionID = UUID()
        let firstTabID = UUID()
        let selectedTabID = UUID()
        let project = WorkspaceProject(id: projectID, path: projectPath, displayName: "restore")
        let session = WorkspaceSession(id: sessionID, projectID: projectID, title: "Relaunch")
        let firstTab = WorkspaceTab(id: firstTabID, sessionID: sessionID, workingDirectory: projectPath, ordinal: 0)
        let selectedTab = WorkspaceTab(id: selectedTabID, sessionID: sessionID, workingDirectory: projectPath, ordinal: 1)
        try await harness.persistence.save(project: project)
        try await harness.persistence.save(session: session)
        try await harness.persistence.save(tab: firstTab)
        try await harness.persistence.save(tab: selectedTab)
        try await harness.persistence.save(snapshot: RestoreSnapshot(
            selectedProjectID: projectID,
            selectedSessionID: sessionID,
            selectedTabID: selectedTabID,
            tabOrder: [firstTabID, selectedTabID]
        ))

        let result = try await harness.service.restoreWorkspace()

        #expect(harness.store.selectedProjectID == projectID)
        #expect(harness.store.selectedSessionID == sessionID)
        #expect(harness.store.selectedTabID == selectedTabID)
        #expect(harness.store.tabsForSelectedSession.map(\.id) == [firstTabID, selectedTabID])
        #expect(harness.terminal.createdTabs.map(\.id) == [firstTabID, selectedTabID])
        #expect(harness.terminal.createdTabs.allSatisfy { $0.workingDirectory == projectPath })
        #expect(result.skippedProjects.isEmpty)
    }

    @Test
    func missingProjectPathRestoresRemainingContextAndReportsRecovery() async throws {
        let harness = try makeHarness()
        let validPath = try makeTemporaryProjectDirectory()
        let missingPath = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("native-mac-ade-missing-\(UUID().uuidString)", isDirectory: true)
            .path
        let validProjectID = UUID()
        let missingProjectID = UUID()
        let validSessionID = UUID()
        let missingSessionID = UUID()
        let validTabID = UUID()
        let missingTabID = UUID()
        try await harness.persistence.save(project: WorkspaceProject(id: validProjectID, path: validPath, displayName: "valid"))
        try await harness.persistence.save(project: WorkspaceProject(id: missingProjectID, path: missingPath, displayName: "missing"))
        try await harness.persistence.save(session: WorkspaceSession(id: validSessionID, projectID: validProjectID, title: "Valid"))
        try await harness.persistence.save(session: WorkspaceSession(id: missingSessionID, projectID: missingProjectID, title: "Missing"))
        try await harness.persistence.save(tab: WorkspaceTab(id: validTabID, sessionID: validSessionID, workingDirectory: validPath, ordinal: 0))
        try await harness.persistence.save(tab: WorkspaceTab(id: missingTabID, sessionID: missingSessionID, workingDirectory: missingPath, ordinal: 0))
        try await harness.persistence.save(snapshot: RestoreSnapshot(
            selectedProjectID: validProjectID,
            selectedSessionID: validSessionID,
            selectedTabID: validTabID,
            tabOrder: [missingTabID, validTabID]
        ))

        let result = try await harness.service.restoreWorkspace()

        #expect(harness.store.projects.map(\.id) == [validProjectID])
        #expect(harness.store.sessions.map(\.id) == [validSessionID])
        #expect(harness.store.tabs.map(\.id) == [validTabID])
        #expect(harness.store.selectedProjectID == validProjectID)
        #expect(harness.store.selectedSessionID == validSessionID)
        #expect(harness.store.selectedTabID == validTabID)
        #expect(result.skippedProjects.map(\.id) == [missingProjectID])
        #expect(result.hasRecoveryItems)
        #expect(harness.terminal.createdTabs.map(\.id) == [validTabID])
        #expect(harness.service.logger.events.contains { event in
            event.name == "restore_skipped_project" &&
            event.fields["project_id"] == missingProjectID.uuidString &&
            event.fields["hashed_path"] == WorkspacePrivacy.hashIdentifier(missingPath) &&
            event.fields.values.contains(missingPath) == false
        })
        #expect(harness.service.metrics.inaccessibleRestoredProjectCount == 1)
    }

    @Test
    func terminalSurfaceFailureDuringRestoreEmitsPilotDiagnostics() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let projectID = UUID()
        let sessionID = UUID()
        let tabID = UUID()
        try await harness.persistence.save(project: WorkspaceProject(id: projectID, path: projectPath, displayName: "restore-failure"))
        try await harness.persistence.save(session: WorkspaceSession(id: sessionID, projectID: projectID, title: "Restore Failure"))
        try await harness.persistence.save(tab: WorkspaceTab(id: tabID, sessionID: sessionID, workingDirectory: projectPath, ordinal: 0))
        try await harness.persistence.save(snapshot: RestoreSnapshot(
            selectedProjectID: projectID,
            selectedSessionID: sessionID,
            selectedTabID: tabID,
            tabOrder: [tabID]
        ))
        harness.terminal.surfaceCreationError = GhosttyAdapterError.surfaceCreationFailed("restore surface failed")

        let result = try await harness.service.restoreWorkspace()

        #expect(result.diagnostics.contains { $0.severity == .failure })
        #expect(harness.service.metrics.terminalSurfaceFailureCount == 1)
        #expect(harness.service.metrics.diagnostics().releaseBlockingReasons.contains("terminal surface failure rate above 1%"))
        #expect(harness.service.logger.events.contains { event in
            event.name == "terminal_surface_failed" &&
            event.fields["tab_id"] == tabID.uuidString &&
            event.fields["reason"]?.contains("restore surface failed") == true
        })
        #expect(harness.service.logger.events.contains { event in
            event.name == "restore_completed" && event.fields["succeeded"] == "false"
        })
    }

    @Test
    func reopeningPreviouslySkippedProjectReusesPersistedProjectRecord() async throws {
        let harness = try makeHarness()
        let missingPath = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("native-mac-ade-reopened-\(UUID().uuidString)", isDirectory: true)
            .path
        let skippedProjectID = UUID()
        try await harness.persistence.save(project: WorkspaceProject(id: skippedProjectID, path: missingPath, displayName: "reopened"))
        try await harness.persistence.save(snapshot: RestoreSnapshot(
            selectedProjectID: skippedProjectID,
            selectedSessionID: nil,
            selectedTabID: nil,
            tabOrder: []
        ))

        let result = try await harness.service.restoreWorkspace()
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: missingPath, isDirectory: true), withIntermediateDirectories: true)
        let reopenedProject = try await harness.service.openProject(path: missingPath)
        let persistedProjects = try await harness.persistence.loadProjects()

        #expect(result.skippedProjects.map(\.id) == [skippedProjectID])
        #expect(reopenedProject.id == skippedProjectID)
        #expect(persistedProjects.filter { URL(fileURLWithPath: $0.path).standardizedFileURL.path == URL(fileURLWithPath: missingPath).standardizedFileURL.path }.count == 1)
    }

    @Test
    func skippedProjectCanBeForgottenFromPersistedRestoreMetadata() async throws {
        let harness = try makeHarness()
        let missingPath = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("native-mac-ade-forgotten-\(UUID().uuidString)", isDirectory: true)
            .path
        let skippedProjectID = UUID()
        try await harness.persistence.save(project: WorkspaceProject(id: skippedProjectID, path: missingPath, displayName: "forgotten"))
        try await harness.persistence.save(snapshot: RestoreSnapshot(
            selectedProjectID: skippedProjectID,
            selectedSessionID: nil,
            selectedTabID: nil,
            tabOrder: []
        ))

        let result = try await harness.service.restoreWorkspace()
        try await harness.service.removeProject(id: skippedProjectID)
        let persistedProjects = try await harness.persistence.loadProjects()
        let persistedSnapshot = try await harness.persistence.loadRestoreSnapshot()

        #expect(result.skippedProjects.map(\.id) == [skippedProjectID])
        #expect(persistedProjects.isEmpty)
        #expect(persistedSnapshot?.selectedProjectID == nil)
    }

    @Test
    func corruptedSnapshotDataFailsSafelyWithoutCrashing() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let projectID = UUID()
        let sessionID = UUID()
        let tabID = UUID()
        try await harness.persistence.save(project: WorkspaceProject(id: projectID, path: projectPath, displayName: "safe"))
        try await harness.persistence.save(session: WorkspaceSession(id: sessionID, projectID: projectID, title: "Safe"))
        try await harness.persistence.save(tab: WorkspaceTab(id: tabID, sessionID: sessionID, workingDirectory: projectPath, ordinal: 0))
        try corruptRestoreSnapshot(at: harness.databasePath)

        let result = try await harness.service.restoreWorkspace()

        #expect(harness.store.projects.map(\.id) == [projectID])
        #expect(harness.store.sessions.map(\.id) == [sessionID])
        #expect(harness.store.tabs.map(\.id) == [tabID])
        #expect(harness.store.selectedProjectID == nil)
        #expect(harness.store.selectedSessionID == nil)
        #expect(harness.store.selectedTabID == nil)
        #expect(result.diagnostics.contains { $0.severity == .failure })
        #expect(result.hasRecoveryItems)
        #expect(harness.terminal.createdTabs.map(\.id) == [tabID])
    }

    private func makeHarness() throws -> RestoreIntegrationHarness {
        let databasePath = temporaryDatabasePath()
        let store = WorkspaceStore()
        let persistence = try SQLiteWorkspaceMetadataStore(path: databasePath)
        let terminal = RestoreIntegrationTerminalSurfaceManager()
        let coordinator = RestoreCoordinator(persistenceStore: persistence)
        let service = DefaultWorkspaceCommandService(
            store: store,
            persistenceStore: persistence,
            restoreCoordinator: coordinator,
            terminalSurfaceManager: terminal
        )
        return RestoreIntegrationHarness(
            databasePath: databasePath,
            store: store,
            persistence: persistence,
            terminal: terminal,
            service: service
        )
    }

    private func temporaryDatabasePath() -> String {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("native-mac-ade-restore-\(UUID().uuidString).sqlite")
            .path
    }

    private func makeTemporaryProjectDirectory() throws -> String {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("native-mac-ade-restore-project-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url.path
    }

    private func corruptRestoreSnapshot(at path: String) throws {
        var database: OpaquePointer?
        guard sqlite3_open_v2(path, &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            throw SQLiteWorkspaceMetadataStoreError.openFailed("Unable to open test database for corruption")
        }
        defer { sqlite3_close(database) }
        let sql = "INSERT INTO restore_snapshot (id, selected_project_id, selected_session_id, selected_tab_id, tab_order_json, updated_at) VALUES (1, NULL, NULL, NULL, 'not-json', 0) ON CONFLICT(id) DO UPDATE SET tab_order_json = excluded.tab_order_json"
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteWorkspaceMetadataStoreError.stepFailed("Unable to corrupt restore snapshot")
        }
    }
}

@MainActor
private struct RestoreIntegrationHarness {
    let databasePath: String
    let store: WorkspaceStore
    let persistence: SQLiteWorkspaceMetadataStore
    let terminal: RestoreIntegrationTerminalSurfaceManager
    let service: DefaultWorkspaceCommandService
}

@MainActor
private final class RestoreIntegrationTerminalSurfaceManager: WorkspaceTerminalSurfaceManaging {
    private(set) var createdTabs: [WorkspaceTab] = []
    private var surfacesByTabID: [UUID: GhosttySurfaceHandle] = [:]
    var surfaceCreationError: Error?

    func createSurface(for tab: WorkspaceTab) async throws -> GhosttySurfaceHandle {
        createdTabs.append(tab)
        if let surfaceCreationError { throw surfaceCreationError }
        let surface = GhosttySurfaceHandle()
        surfacesByTabID[tab.id] = surface
        return surface
    }

    func surface(for tabID: UUID) -> GhosttySurfaceHandle? { surfacesByTabID[tabID] }
    func canClose(surface: GhosttySurfaceHandle) async -> Bool { true }
    func focus(tabID: UUID) {}
    func resize(tabID: UUID, columns: Int, rows: Int) {}
    func hasExited(tabID: UUID) async -> Bool { false }
    func releaseSurface(for tabID: UUID) { surfacesByTabID[tabID] = nil }
}
