import Foundation
import Testing
@testable import NativeMacADECore

@MainActor
struct RestoreCoordinatorTests {
    @Test
    func validSnapshotRestoresExpectedSelectionAndTabOrder() async throws {
        let projectPath = try makeTemporaryProjectDirectory()
        let projectID = UUID()
        let sessionID = UUID()
        let firstTabID = UUID()
        let selectedTabID = UUID()
        let project = WorkspaceProject(id: projectID, path: projectPath, displayName: "ade")
        let session = WorkspaceSession(id: sessionID, projectID: projectID, title: "Restore")
        let firstTab = WorkspaceTab(id: firstTabID, sessionID: sessionID, workingDirectory: projectPath, ordinal: 0)
        let selectedTab = WorkspaceTab(id: selectedTabID, sessionID: sessionID, workingDirectory: projectPath, ordinal: 1)
        let persistence = InMemoryWorkspacePersistenceStore(
            projects: [project],
            sessions: [session],
            tabs: [firstTab, selectedTab],
            restoreSnapshot: RestoreSnapshot(
                selectedProjectID: projectID,
                selectedSessionID: sessionID,
                selectedTabID: selectedTabID,
                tabOrder: [selectedTabID, firstTabID]
            )
        )
        let coordinator = RestoreCoordinator(persistenceStore: persistence)

        let result = try await coordinator.restoreWorkspace()

        #expect(result.store.selectedProjectID == projectID)
        #expect(result.store.selectedSessionID == sessionID)
        #expect(result.store.selectedTabID == selectedTabID)
        #expect(result.store.tabsForSelectedSession.map(\.id) == [selectedTabID, firstTabID])
        #expect(result.skippedProjects.isEmpty)
        #expect(result.diagnostics.contains { $0.severity == .info })
    }

    @Test
    func restoreSkipsInaccessibleProjectAndKeepsRemainingContext() async throws {
        let validProjectPath = try makeTemporaryProjectDirectory()
        let missingProjectPath = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("native-mac-ade-missing-\(UUID().uuidString)", isDirectory: true)
            .path
        let validProjectID = UUID()
        let missingProjectID = UUID()
        let validSessionID = UUID()
        let missingSessionID = UUID()
        let validTabID = UUID()
        let missingTabID = UUID()
        let validProject = WorkspaceProject(id: validProjectID, path: validProjectPath, displayName: "valid")
        let missingProject = WorkspaceProject(id: missingProjectID, path: missingProjectPath, displayName: "missing")
        let validSession = WorkspaceSession(id: validSessionID, projectID: validProjectID, title: "Valid")
        let missingSession = WorkspaceSession(id: missingSessionID, projectID: missingProjectID, title: "Missing")
        let validTab = WorkspaceTab(id: validTabID, sessionID: validSessionID, workingDirectory: validProjectPath, ordinal: 0)
        let missingTab = WorkspaceTab(id: missingTabID, sessionID: missingSessionID, workingDirectory: missingProjectPath, ordinal: 0)
        let persistence = InMemoryWorkspacePersistenceStore(
            projects: [missingProject, validProject],
            sessions: [missingSession, validSession],
            tabs: [missingTab, validTab],
            restoreSnapshot: RestoreSnapshot(
                selectedProjectID: missingProjectID,
                selectedSessionID: missingSessionID,
                selectedTabID: missingTabID,
                tabOrder: [missingTabID, validTabID]
            )
        )
        let coordinator = RestoreCoordinator(persistenceStore: persistence)

        let result = try await coordinator.restoreWorkspace()

        #expect(result.store.projects.map(\.id) == [validProjectID])
        #expect(result.store.sessions.map(\.id) == [validSessionID])
        #expect(result.store.tabs.map(\.id) == [validTabID])
        #expect(result.store.selectedProjectID == nil)
        #expect(result.store.selectedSessionID == nil)
        #expect(result.store.selectedTabID == nil)
        #expect(result.skippedProjects.map(\.id) == [missingProjectID])
        #expect(result.hasRecoveryItems)
        #expect(result.diagnostics.contains { $0.severity == .warning })
    }

    @Test
    func unreadableSnapshotFallsBackToAvailableMetadataWithoutCrashing() async throws {
        let projectPath = try makeTemporaryProjectDirectory()
        let projectID = UUID()
        let sessionID = UUID()
        let tabID = UUID()
        let persistence = SnapshotFailingPersistenceStore(
            project: WorkspaceProject(id: projectID, path: projectPath, displayName: "ade"),
            session: WorkspaceSession(id: sessionID, projectID: projectID, title: "Fallback"),
            tab: WorkspaceTab(id: tabID, sessionID: sessionID, workingDirectory: projectPath, ordinal: 0)
        )
        let coordinator = RestoreCoordinator(persistenceStore: persistence)

        let result = try await coordinator.restoreWorkspace()

        #expect(result.store.projects.map(\.id) == [projectID])
        #expect(result.store.sessions.map(\.id) == [sessionID])
        #expect(result.store.tabs.map(\.id) == [tabID])
        #expect(result.store.selectedProjectID == nil)
        #expect(result.diagnostics.contains { $0.severity == .failure })
        #expect(result.hasRecoveryItems)
    }

    @Test
    func duplicateIncompleteSnapshotTabOrderDoesNotTrapAndRenumbersTabsStably() async throws {
        let projectPath = try makeTemporaryProjectDirectory()
        let projectID = UUID()
        let sessionID = UUID()
        let firstTabID = UUID()
        let secondTabID = UUID()
        let thirdTabID = UUID()
        let project = WorkspaceProject(id: projectID, path: projectPath, displayName: "ade")
        let session = WorkspaceSession(id: sessionID, projectID: projectID, title: "Restore")
        let firstTab = WorkspaceTab(id: firstTabID, sessionID: sessionID, workingDirectory: projectPath, ordinal: 0)
        let secondTab = WorkspaceTab(id: secondTabID, sessionID: sessionID, workingDirectory: projectPath, ordinal: 1)
        let thirdTab = WorkspaceTab(id: thirdTabID, sessionID: sessionID, workingDirectory: projectPath, ordinal: 2)
        let persistence = InMemoryWorkspacePersistenceStore(
            projects: [project],
            sessions: [session],
            tabs: [firstTab, secondTab, thirdTab],
            restoreSnapshot: RestoreSnapshot(
                selectedProjectID: projectID,
                selectedSessionID: sessionID,
                selectedTabID: secondTabID,
                tabOrder: [secondTabID, secondTabID]
            )
        )
        let coordinator = RestoreCoordinator(persistenceStore: persistence)

        let result = try await coordinator.restoreWorkspace()

        #expect(result.store.tabsForSelectedSession.map(\.id) == [secondTabID, firstTabID, thirdTabID])
        #expect(result.store.tabsForSelectedSession.map(\.ordinal) == [0, 1, 2])
        #expect(result.store.selectedTabID == secondTabID)
    }

    @Test
    func mixedFileTabRestorePreservesSnapshotOrderAndSkipsUnreadableFiles() async throws {
        let projectPath = try makeTemporaryProjectDirectory()
        let sourceDirectory = URL(fileURLWithPath: projectPath, isDirectory: true)
            .appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        let readableFile = sourceDirectory.appendingPathComponent("App.swift")
        try "let app = 1\n".write(to: readableFile, atomically: true, encoding: .utf8)
        let missingFile = sourceDirectory.appendingPathComponent("Missing.swift")
        let projectID = UUID()
        let sessionID = UUID()
        let terminalTabID = UUID()
        let readableFileTabID = UUID()
        let missingFileTabID = UUID()
        let project = WorkspaceProject(id: projectID, path: projectPath, displayName: "ade")
        let session = WorkspaceSession(id: sessionID, projectID: projectID, title: "Mixed")
        let terminalTab = WorkspaceTab(id: terminalTabID, sessionID: sessionID, workingDirectory: projectPath, ordinal: 0)
        let readableFileTab = WorkspaceTab(
            id: readableFileTabID,
            sessionID: sessionID,
            kind: .file,
            workingDirectory: projectPath,
            fileReference: WorkspaceFileReference(path: readableFile.path, projectRoot: projectPath),
            ordinal: 1
        )
        let missingFileTab = WorkspaceTab(
            id: missingFileTabID,
            sessionID: sessionID,
            kind: .file,
            workingDirectory: projectPath,
            fileReference: WorkspaceFileReference(path: missingFile.path, projectRoot: projectPath),
            ordinal: 2
        )
        let persistence = InMemoryWorkspacePersistenceStore(
            projects: [project],
            sessions: [session],
            tabs: [terminalTab, missingFileTab, readableFileTab],
            restoreSnapshot: RestoreSnapshot(
                selectedProjectID: projectID,
                selectedSessionID: sessionID,
                selectedTabID: readableFileTabID,
                tabOrder: [readableFileTabID, terminalTabID, missingFileTabID]
            )
        )
        let coordinator = RestoreCoordinator(persistenceStore: persistence)

        let result = try await coordinator.restoreWorkspace()

        #expect(result.store.selectedProjectID == projectID)
        #expect(result.store.selectedSessionID == sessionID)
        #expect(result.store.selectedTabID == readableFileTabID)
        #expect(result.store.tabsForSelectedSession.map(\.id) == [readableFileTabID, terminalTabID])
        #expect(result.store.tabsForSelectedSession.map(\.kind) == [.file, .terminal])
        #expect(result.store.tabsForSelectedSession.map(\.ordinal) == [0, 1])
        #expect(result.diagnostics.contains { diagnostic in
            diagnostic.severity == .warning &&
                diagnostic.message.contains(missingFileTabID.uuidString) &&
                diagnostic.message.contains("missing or unreadable")
        })
        #expect(result.hasRecoveryItems)
    }

    private func makeTemporaryProjectDirectory() throws -> String {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("native-mac-ade-restore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url.path
    }
}

private actor SnapshotFailingPersistenceStore: WorkspacePersistenceStore {
    let project: WorkspaceProject
    let session: WorkspaceSession
    let tab: WorkspaceTab

    init(project: WorkspaceProject, session: WorkspaceSession, tab: WorkspaceTab) {
        self.project = project
        self.session = session
        self.tab = tab
    }

    func loadProjects() async throws -> [WorkspaceProject] { [project] }
    func loadSessions() async throws -> [WorkspaceSession] { [session] }
    func loadTabs() async throws -> [WorkspaceTab] { [tab] }
    func loadSessionShortcuts() async throws -> [SessionShortcut] { [] }
    func loadAppPreferences() async throws -> AppPreferences { .defaults }
    func loadRestoreSnapshot() async throws -> RestoreSnapshot? { throw SnapshotFailure.unreadable }
    func save(project: WorkspaceProject) async throws {}
    func save(session: WorkspaceSession) async throws {}
    func save(tab: WorkspaceTab) async throws {}
    func save(session: WorkspaceSession, firstTab: WorkspaceTab) async throws {}
    func saveActivation(project: WorkspaceProject?, session: WorkspaceSession?, tab: WorkspaceTab?, snapshot: RestoreSnapshot) async throws {}
    func save(shortcut: SessionShortcut) async throws {}
    func save(appPreferences: AppPreferences) async throws {}
    func save(snapshot: RestoreSnapshot) async throws {}
    func deleteProject(id: UUID) async throws {}
    func deleteSession(id: UUID) async throws {}
    func deleteTab(id: UUID) async throws {}
    func deleteShortcut(id: UUID) async throws {}

    enum SnapshotFailure: Error {
        case unreadable
    }
}
