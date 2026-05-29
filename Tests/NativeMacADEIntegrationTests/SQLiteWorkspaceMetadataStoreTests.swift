import Foundation
import SQLite3
import Testing
@testable import NativeMacADECore

@Suite(.serialized)
struct SQLiteWorkspaceMetadataStoreTests {
    @Test
    func bootstrapCreatesExactlyMetadataTables() async throws {
        let path = temporaryDatabasePath()
        _ = try SQLiteWorkspaceMetadataStore(path: path)

        let tables = try inspectUserTableNames(path: path)

        #expect(tables == ["projects", "sessions", "tabs", "session_shortcuts", "restore_snapshot"])
    }

    @Test
    func replacingActiveRestoreSnapshotOverwritesSingleRow() async throws {
        let path = temporaryDatabasePath()
        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let projectID = UUID()
        let sessionID = UUID()
        let firstTabID = UUID()
        let secondTabID = UUID()

        try await store.save(project: WorkspaceProject(id: projectID, path: "/tmp/ade", displayName: "ade"))
        try await store.save(session: WorkspaceSession(id: sessionID, projectID: projectID, title: "Restore"))
        try await store.save(tab: WorkspaceTab(id: firstTabID, sessionID: sessionID, workingDirectory: "/tmp/ade", ordinal: 0))
        try await store.save(tab: WorkspaceTab(id: secondTabID, sessionID: sessionID, workingDirectory: "/tmp/ade", ordinal: 1))

        try await store.save(snapshot: RestoreSnapshot(
            selectedProjectID: projectID,
            selectedSessionID: sessionID,
            selectedTabID: firstTabID,
            tabOrder: [firstTabID],
            updatedAt: Date(timeIntervalSince1970: 100)
        ))
        try await store.save(snapshot: RestoreSnapshot(
            selectedProjectID: projectID,
            selectedSessionID: sessionID,
            selectedTabID: secondTabID,
            tabOrder: [firstTabID, secondTabID],
            updatedAt: Date(timeIntervalSince1970: 200)
        ))

        let snapshot = try await store.loadRestoreSnapshot()

        #expect(try inspectRestoreSnapshotRowCount(path: path) == 1)
        #expect(snapshot?.selectedTabID == secondTabID)
        #expect(snapshot?.tabOrder == [firstTabID, secondTabID])
        #expect(snapshot?.updatedAt == Date(timeIntervalSince1970: 200))
    }

    @Test
    func persistedGraphLoadsExpectedOrderingRecencyAndMetadataOnlyTables() async throws {
        let path = temporaryDatabasePath()
        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let projectID = UUID()
        let olderSessionID = UUID()
        let newerSessionID = UUID()
        let firstTabID = UUID()
        let secondTabID = UUID()
        let shortcut = SessionShortcut(
            label: "Codex",
            launchCommand: "codex",
            launchArgumentsJSON: "[\"--model\",\"gpt-5.5\"]",
            secretRef: "keychain://native-mac-ade/codex",
            isBuiltIn: true
        )
        let project = WorkspaceProject(
            id: projectID,
            path: "/Users/example/ade",
            bookmarkData: Data([1, 2, 3]),
            displayName: "ade",
            createdAt: Date(timeIntervalSince1970: 10),
            lastOpenedAt: Date(timeIntervalSince1970: 20),
            sortIndex: 4
        )
        let olderSession = WorkspaceSession(
            id: olderSessionID,
            projectID: projectID,
            title: "Old",
            createdAt: Date(timeIntervalSince1970: 30),
            lastActivatedAt: Date(timeIntervalSince1970: 40)
        )
        let newerSession = WorkspaceSession(
            id: newerSessionID,
            projectID: projectID,
            title: "New",
            isUserNamed: true,
            shortcutID: shortcut.id,
            createdAt: Date(timeIntervalSince1970: 50),
            lastActivatedAt: Date(timeIntervalSince1970: 60)
        )
        let secondTab = WorkspaceTab(
            id: secondTabID,
            sessionID: newerSessionID,
            workingDirectory: project.path,
            launchCommand: "codex",
            launchArgumentsJSON: "[\"resume\"]",
            ordinal: 1,
            createdAt: Date(timeIntervalSince1970: 70),
            lastActivatedAt: Date(timeIntervalSince1970: 80)
        )
        let firstTab = WorkspaceTab(
            id: firstTabID,
            sessionID: newerSessionID,
            workingDirectory: project.path,
            launchCommand: nil,
            launchArgumentsJSON: nil,
            ordinal: 0,
            createdAt: Date(timeIntervalSince1970: 65),
            lastActivatedAt: Date(timeIntervalSince1970: 75)
        )

        try await store.save(project: project)
        try await store.save(shortcut: shortcut)
        try await store.save(session: olderSession)
        try await store.save(session: newerSession)
        try await store.save(tab: secondTab)
        try await store.save(tab: firstTab)
        try await store.save(snapshot: RestoreSnapshot(
            selectedProjectID: projectID,
            selectedSessionID: newerSessionID,
            selectedTabID: firstTabID,
            tabOrder: [firstTabID, secondTabID],
            updatedAt: Date(timeIntervalSince1970: 90)
        ))

        let loadedProjects = try await store.loadProjects()
        let loadedSessions = try await store.loadSessions()
        let loadedTabs = try await store.loadTabs()
        let loadedShortcuts = try await store.loadSessionShortcuts()
        let snapshot = try await store.loadRestoreSnapshot()

        #expect(loadedProjects == [project])
        #expect(loadedSessions.map(\.id) == [newerSessionID, olderSessionID])
        #expect(loadedSessions.first?.isUserNamed == true)
        #expect(loadedSessions.first?.shortcutID == shortcut.id)
        #expect(loadedSessions.first?.lastActivatedAt == Date(timeIntervalSince1970: 60))
        #expect(loadedTabs.map(\.id) == [firstTabID, secondTabID])
        #expect(loadedTabs.first?.workingDirectory == project.path)
        #expect(loadedTabs.first?.ordinal == 0)
        #expect(loadedTabs.last?.launchCommand == "codex")
        #expect(loadedTabs.last?.launchArgumentsJSON == "[\"resume\"]")
        #expect(loadedShortcuts == [shortcut])
        #expect(snapshot?.selectedProjectID == projectID)
        #expect(snapshot?.selectedSessionID == newerSessionID)
        #expect(snapshot?.selectedTabID == firstTabID)
        #expect(snapshot?.tabOrder == [firstTabID, secondTabID])
        #expect(loadedShortcuts.first?.secretRef == "keychain://native-mac-ade/codex")
        #expect(try inspectUserTableNames(path: path).isDisjoint(with: ["scrollback", "pty_sessions", "checkpoints", "workspaces"]))
    }

    @Test
    func activationSavePersistsRecencyAndSnapshotAtomically() async throws {
        let path = temporaryDatabasePath()
        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let activatedAt = Date(timeIntervalSince1970: 200)
        var project = WorkspaceProject(
            path: "/Users/example/activation",
            displayName: "activation",
            lastOpenedAt: Date(timeIntervalSince1970: 20)
        )
        var session = WorkspaceSession(
            projectID: project.id,
            title: "Activation",
            lastActivatedAt: Date(timeIntervalSince1970: 30)
        )
        var tab = WorkspaceTab(
            sessionID: session.id,
            workingDirectory: project.path,
            ordinal: 0,
            lastActivatedAt: Date(timeIntervalSince1970: 40)
        )
        try await store.save(project: project)
        try await store.save(session: session)
        try await store.save(tab: tab)

        project.lastOpenedAt = activatedAt
        session.lastActivatedAt = activatedAt
        tab.lastActivatedAt = activatedAt
        try await store.saveActivation(
            project: project,
            session: session,
            tab: tab,
            snapshot: RestoreSnapshot(
                selectedProjectID: project.id,
                selectedSessionID: session.id,
                selectedTabID: tab.id,
                tabOrder: [tab.id],
                updatedAt: activatedAt
            )
        )

        #expect(try await store.loadProjects().first?.lastOpenedAt == activatedAt)
        #expect(try await store.loadSessions().first?.lastActivatedAt == activatedAt)
        #expect(try await store.loadTabs().first?.lastActivatedAt == activatedAt)
        #expect(try await store.loadRestoreSnapshot()?.selectedTabID == tab.id)
        #expect(try await store.loadRestoreSnapshot()?.updatedAt == activatedAt)
    }

    @Test
    func activationSaveRollsBackWhenMidTransactionWriteFails() async throws {
        let path = temporaryDatabasePath()
        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let originalProject = WorkspaceProject(
            path: "/Users/example/rollback",
            displayName: "rollback",
            createdAt: Date(timeIntervalSince1970: 10),
            lastOpenedAt: Date(timeIntervalSince1970: 20)
        )
        let originalSession = WorkspaceSession(
            projectID: originalProject.id,
            title: "Rollback",
            createdAt: Date(timeIntervalSince1970: 25),
            lastActivatedAt: Date(timeIntervalSince1970: 30)
        )
        try await store.save(project: originalProject)
        try await store.save(session: originalSession)

        var updatedProject = originalProject
        var updatedSession = originalSession
        updatedProject.lastOpenedAt = Date(timeIntervalSince1970: 200)
        updatedSession.lastActivatedAt = Date(timeIntervalSince1970: 200)
        let invalidTab = WorkspaceTab(
            sessionID: UUID(),
            workingDirectory: originalProject.path,
            ordinal: 0,
            lastActivatedAt: Date(timeIntervalSince1970: 200)
        )

        await #expect(throws: SQLiteWorkspaceMetadataStoreError.self) {
            try await store.saveActivation(
                project: updatedProject,
                session: updatedSession,
                tab: invalidTab,
                snapshot: RestoreSnapshot(
                    selectedProjectID: updatedProject.id,
                    selectedSessionID: updatedSession.id,
                    selectedTabID: invalidTab.id,
                    tabOrder: [invalidTab.id]
                )
            )
        }

        #expect(try await store.loadProjects() == [originalProject])
        #expect(try await store.loadSessions() == [originalSession])
        #expect(try await store.loadTabs().isEmpty)
        #expect(try await store.loadRestoreSnapshot() == nil)
    }

    private func temporaryDatabasePath() -> String {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("native-mac-ade-\(UUID().uuidString).sqlite")
            .path
    }

    private func inspectUserTableNames(path: String) throws -> Set<String> {
        try inspect(path: path, sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'") { statement in
            guard let pointer = sqlite3_column_text(statement, 0) else { return nil }
            return String(cString: pointer)
        }
    }

    private func inspectRestoreSnapshotRowCount(path: String) throws -> Int {
        try inspect(path: path, sql: "SELECT COUNT(*) FROM restore_snapshot") { statement in
            Int(sqlite3_column_int64(statement, 0))
        }.first ?? 0
    }

    private func inspect<T>(path: String, sql: String, map: (OpaquePointer?) throws -> T?) throws -> Set<T> where T: Hashable {
        var database: OpaquePointer?
        guard sqlite3_open_v2(path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            throw SQLiteWorkspaceMetadataStoreError.openFailed("Unable to open inspection database")
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteWorkspaceMetadataStoreError.prepareFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }

        var values: Set<T> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let value = try map(statement) {
                values.insert(value)
            }
        }
        return values
    }
}
