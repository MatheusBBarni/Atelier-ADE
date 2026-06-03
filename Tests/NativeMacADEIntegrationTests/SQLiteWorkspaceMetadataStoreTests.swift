import Foundation
import SQLite3
import Testing
@testable import NativeMacADECore

@Suite(.serialized)
struct SQLiteWorkspaceMetadataStoreTests {
    @Test
    func bootstrapCreatesExactlyMetadataTables() async throws {
        let path = temporaryDatabasePath()
        let store = try SQLiteWorkspaceMetadataStore(path: path)

        let tables = try inspectUserTableNames(path: path)
        let preferences = try await store.loadAppPreferences()

        #expect(tables == WorkspaceMigrations.metadataTables)
        #expect(try inspectColumnNames(path: path, tableName: "session_shortcuts").contains("has_user_override"))
        #expect(try inspectColumnNames(path: path, tableName: "tabs").isSuperset(of: ["kind", "file_path", "title", "shortcut_id"]))
        #expect(try inspectColumnNames(path: path, tableName: "app_preferences").isSuperset(of: [
            "terminal_font_size",
            "focus_workspace_enabled",
            "focus_workspace_continuity_enabled"
        ]))
        #expect(WorkspaceMigrations.currentUserVersion == 7)
        #expect(try inspectUserVersion(path: path) == WorkspaceMigrations.currentUserVersion)
        #expect(try inspectAppPreferencesRowCount(path: path) == 1)
        #expect(try inspectAppPreferencesFocusFlag(path: path) == false)
        #expect(try inspectAppPreferencesContinuityFlag(path: path) == false)
        #expect(preferences == .defaults)
        #expect(preferences.themeID == AppTheme.systemSelectionID)
        #expect(preferences.focusWorkspaceEnabled == false)
        #expect(preferences.focusWorkspaceContinuityEnabled == false)
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
            title: "Review",
            shortcutID: shortcut.id,
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
        #expect(loadedTabs.last?.title == "Review")
        #expect(loadedTabs.last?.shortcutID == shortcut.id)
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
    func mixedTabSessionRoundTripPreservesKindFilePathOrdinalAndActivation() async throws {
        let path = temporaryDatabasePath()
        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let project = WorkspaceProject(path: "/Users/example/mixed", displayName: "mixed")
        let session = WorkspaceSession(projectID: project.id, title: "Mixed")
        let terminalTab = WorkspaceTab(
            sessionID: session.id,
            workingDirectory: project.path,
            launchCommand: "codex",
            launchArgumentsJSON: "[]",
            ordinal: 0,
            createdAt: Date(timeIntervalSince1970: 100),
            lastActivatedAt: Date(timeIntervalSince1970: 200)
        )
        let fileReference = WorkspaceFileReference(
            path: "/Users/example/mixed/Sources/App.swift",
            projectRoot: project.path
        )
        let fileTab = WorkspaceTab(
            sessionID: session.id,
            kind: .file,
            workingDirectory: project.path,
            fileReference: fileReference,
            ordinal: 1,
            createdAt: Date(timeIntervalSince1970: 300),
            lastActivatedAt: Date(timeIntervalSince1970: 400)
        )

        try await store.save(project: project)
        try await store.save(session: session)
        try await store.save(tab: fileTab)
        try await store.save(tab: terminalTab)

        let loadedTabs = try await store.loadTabs()

        #expect(loadedTabs.map(\.id) == [terminalTab.id, fileTab.id])
        #expect(loadedTabs.map(\.kind) == [.terminal, .file])
        #expect(loadedTabs.first?.fileReference == nil)
        #expect(loadedTabs.last?.fileReference == fileReference)
        #expect(loadedTabs.last?.ordinal == 1)
        #expect(loadedTabs.last?.lastActivatedAt == Date(timeIntervalSince1970: 400))
    }

    @Test
    func projectBookmarkDataPersistsAlongsideFileTabMetadata() async throws {
        let path = temporaryDatabasePath()
        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let bookmarkData = Data([9, 8, 7, 6])
        let project = WorkspaceProject(
            path: "/Users/example/bookmarked",
            bookmarkData: bookmarkData,
            displayName: "bookmarked"
        )
        let session = WorkspaceSession(projectID: project.id, title: "Bookmarked")
        let fileReference = WorkspaceFileReference(
            path: "/Users/example/bookmarked/Sources/App.swift",
            projectRoot: project.path
        )
        let fileTab = WorkspaceTab(
            sessionID: session.id,
            kind: .file,
            workingDirectory: project.path,
            fileReference: fileReference,
            ordinal: 0
        )

        try await store.save(project: project)
        try await store.save(session: session)
        try await store.save(tab: fileTab)

        let loadedProject = try #require(try await store.loadProjects().first)
        let loadedFileTab = try #require(try await store.loadTabs().first)

        #expect(loadedProject.bookmarkData == bookmarkData)
        #expect(loadedFileTab.kind == .file)
        #expect(loadedFileTab.fileReference == fileReference)
    }

    @Test
    func versionOneDatabaseUpgradesToVersionTwoWithoutMutatingWorkspaceMetadata() async throws {
        let path = temporaryDatabasePath()
        let fixture = try createVersionOneDatabase(path: path)

        let store = try SQLiteWorkspaceMetadataStore(path: path)

        #expect(try inspectUserVersion(path: path) == WorkspaceMigrations.currentUserVersion)
        #expect(try inspectUserTableNames(path: path) == WorkspaceMigrations.metadataTables)
        #expect(try inspectColumnNames(path: path, tableName: "session_shortcuts").contains("has_user_override"))
        #expect(try inspectColumnNames(path: path, tableName: "tabs").isSuperset(of: ["kind", "file_path", "title", "shortcut_id"]))
        #expect(try inspectColumnNames(path: path, tableName: "app_preferences").isSuperset(of: [
            "terminal_font_size",
            "focus_workspace_enabled",
            "focus_workspace_continuity_enabled"
        ]))
        #expect(try inspectAppPreferencesRowCount(path: path) == 1)
        #expect(try inspectAppPreferencesFocusFlag(path: path) == false)
        #expect(try inspectAppPreferencesContinuityFlag(path: path) == false)
        #expect(try await store.loadProjects() == [fixture.project])
        #expect(try await store.loadSessions() == [fixture.session])
        #expect(try await store.loadTabs() == [fixture.tab])
        #expect(try await store.loadSessionShortcuts() == [fixture.shortcut])
        #expect(try await store.loadRestoreSnapshot() == fixture.restoreSnapshot)
        #expect(try await store.loadAppPreferences() == .defaults)
    }

    @Test
    func legacyVersionTwoDatabaseMissingTabMetadataColumnsRepairsWithoutLosingWorkspaceMetadata() async throws {
        let path = temporaryDatabasePath()
        let fixture = try createVersionOneDatabase(path: path)
        try execute(path: path, """
        ALTER TABLE session_shortcuts ADD COLUMN has_user_override INTEGER NOT NULL DEFAULT 0 CHECK (has_user_override IN (0, 1));
        CREATE TABLE app_preferences (
            id INTEGER PRIMARY KEY NOT NULL CHECK (id = 1),
            theme_id TEXT NOT NULL,
            default_session_shortcut_id TEXT REFERENCES session_shortcuts(id) ON DELETE SET NULL,
            keybindings_json TEXT NOT NULL,
            updated_at REAL NOT NULL
        );
        INSERT INTO app_preferences (id, theme_id, default_session_shortcut_id, keybindings_json, updated_at)
        VALUES (1, '\(AppPreferences.defaultThemeID)', NULL, '[]', 0);
        PRAGMA user_version = 2;
        """)

        let store = try SQLiteWorkspaceMetadataStore(path: path)

        #expect(try inspectUserVersion(path: path) == WorkspaceMigrations.currentUserVersion)
        #expect(try inspectColumnNames(path: path, tableName: "tabs").isSuperset(of: ["kind", "file_path", "title", "shortcut_id"]))
        #expect(try inspectColumnNames(path: path, tableName: "app_preferences").isSuperset(of: [
            "terminal_font_size",
            "focus_workspace_enabled",
            "focus_workspace_continuity_enabled"
        ]))
        #expect(try await store.loadTabs() == [fixture.tab])
        #expect(try await store.loadRestoreSnapshot() == fixture.restoreSnapshot)
        #expect(try await store.loadAppPreferences().terminalFontSize == AppPreferences.defaultTerminalFontSize)
        #expect(try await store.loadAppPreferences().focusWorkspaceEnabled == false)
        #expect(try await store.loadAppPreferences().focusWorkspaceContinuityEnabled == false)
    }

    @Test
    func versionFiveDatabaseUpgradesToCurrentPreservingMetadataAndAddingPreferenceDefaults() async throws {
        let path = temporaryDatabasePath()
        let fixture = try createVersionFiveDatabase(path: path)

        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let preferences = try await store.loadAppPreferences()

        #expect(try inspectUserVersion(path: path) == WorkspaceMigrations.currentUserVersion)
        #expect(try inspectColumnNames(path: path, tableName: "app_preferences").contains("focus_workspace_enabled"))
        #expect(try inspectColumnNames(path: path, tableName: "app_preferences").contains("focus_workspace_continuity_enabled"))
        #expect(try inspectAppPreferencesFocusFlag(path: path) == false)
        #expect(try inspectAppPreferencesContinuityFlag(path: path) == false)
        #expect(try await store.loadProjects() == [fixture.project])
        #expect(try await store.loadSessions() == [fixture.session])
        #expect(try await store.loadTabs() == [fixture.tab])
        #expect(try await store.loadSessionShortcuts() == [fixture.shortcut])
        #expect(try await store.loadRestoreSnapshot() == fixture.restoreSnapshot)
        #expect(preferences.themeID == "dracula")
        #expect(preferences.defaultSessionShortcutID == fixture.shortcut.id)
        #expect(preferences.terminalFontSize == 16)
        #expect(preferences.keybindings == [.openSettings: fixture.openSettingsOverride])
        #expect(preferences.focusWorkspaceEnabled == false)
        #expect(preferences.focusWorkspaceContinuityEnabled == false)
        #expect(preferences.updatedAt == Date(timeIntervalSince1970: 80))
    }

    @Test
    func versionSixDatabaseUpgradesToVersionSevenAddingContinuityDefault() async throws {
        let path = temporaryDatabasePath()
        let fixture = try createVersionSixDatabase(path: path)

        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let preferences = try await store.loadAppPreferences()

        #expect(try inspectUserVersion(path: path) == 7)
        #expect(try inspectColumnNames(path: path, tableName: "app_preferences").contains("focus_workspace_continuity_enabled"))
        #expect(try inspectAppPreferencesFocusFlag(path: path) == true)
        #expect(try inspectAppPreferencesContinuityFlag(path: path) == false)
        #expect(try await store.loadProjects() == [fixture.project])
        #expect(try await store.loadSessions() == [fixture.session])
        #expect(try await store.loadTabs() == [fixture.tab])
        #expect(try await store.loadSessionShortcuts() == [fixture.shortcut])
        #expect(try await store.loadRestoreSnapshot() == fixture.restoreSnapshot)
        #expect(preferences.themeID == "dracula")
        #expect(preferences.defaultSessionShortcutID == fixture.shortcut.id)
        #expect(preferences.terminalFontSize == 16)
        #expect(preferences.keybindings == [.openSettings: fixture.openSettingsOverride])
        #expect(preferences.focusWorkspaceEnabled == true)
        #expect(preferences.focusWorkspaceContinuityEnabled == false)
        #expect(preferences.updatedAt == Date(timeIntervalSince1970: 80))
    }

    @Test
    func currentVersionDatabaseMissingFocusWorkspaceColumnRepairsWithoutLosingPreferences() async throws {
        let path = temporaryDatabasePath()
        let override = KeybindingOverride(
            commandID: .openSettings,
            keyEquivalent: ",",
            modifiers: [.command, .shift]
        )
        do {
            var database: OpaquePointer?
            guard sqlite3_open_v2(path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
                throw SQLiteWorkspaceMetadataStoreError.openFailed("Unable to create missing-focus-column fixture database")
            }
            defer { sqlite3_close(database) }
            try execute(database, """
            CREATE TABLE app_preferences (
                id INTEGER PRIMARY KEY NOT NULL CHECK (id = 1),
                theme_id TEXT NOT NULL,
                default_session_shortcut_id TEXT REFERENCES session_shortcuts(id) ON DELETE SET NULL,
                terminal_font_size REAL NOT NULL DEFAULT \(AppPreferences.defaultTerminalFontSize),
                keybindings_json TEXT NOT NULL,
                updated_at REAL NOT NULL
            );
            INSERT INTO app_preferences (id, theme_id, default_session_shortcut_id, terminal_font_size, keybindings_json, updated_at)
            VALUES (1, 'catppuccin', NULL, 19, '[{"commandID":"openSettings","keyEquivalent":",","modifiers":["command","shift"]}]', 90);
            PRAGMA user_version = \(WorkspaceMigrations.currentUserVersion);
            """)
        }

        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let preferences = try await store.loadAppPreferences()

        #expect(try inspectUserVersion(path: path) == WorkspaceMigrations.currentUserVersion)
        #expect(try inspectColumnNames(path: path, tableName: "app_preferences").contains("focus_workspace_enabled"))
        #expect(try inspectColumnNames(path: path, tableName: "app_preferences").contains("focus_workspace_continuity_enabled"))
        #expect(try inspectAppPreferencesFocusFlag(path: path) == false)
        #expect(try inspectAppPreferencesContinuityFlag(path: path) == false)
        #expect(preferences.themeID == "catppuccin")
        #expect(preferences.defaultSessionShortcutID == nil)
        #expect(preferences.terminalFontSize == 19)
        #expect(preferences.keybindings == [.openSettings: override])
        #expect(preferences.focusWorkspaceEnabled == false)
        #expect(preferences.focusWorkspaceContinuityEnabled == false)
        #expect(preferences.updatedAt == Date(timeIntervalSince1970: 90))
    }

    @Test
    func currentVersionDatabaseMissingContinuityColumnRepairsWithoutLosingPreferences() async throws {
        let path = temporaryDatabasePath()
        let override = KeybindingOverride(
            commandID: .openSettings,
            keyEquivalent: ",",
            modifiers: [.command, .shift]
        )
        do {
            var database: OpaquePointer?
            guard sqlite3_open_v2(path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
                throw SQLiteWorkspaceMetadataStoreError.openFailed("Unable to create missing-continuity-column fixture database")
            }
            defer { sqlite3_close(database) }
            try execute(database, """
            CREATE TABLE app_preferences (
                id INTEGER PRIMARY KEY NOT NULL CHECK (id = 1),
                theme_id TEXT NOT NULL,
                default_session_shortcut_id TEXT REFERENCES session_shortcuts(id) ON DELETE SET NULL,
                terminal_font_size REAL NOT NULL DEFAULT \(AppPreferences.defaultTerminalFontSize),
                keybindings_json TEXT NOT NULL,
                focus_workspace_enabled INTEGER NOT NULL DEFAULT 0 CHECK (focus_workspace_enabled IN (0, 1)),
                updated_at REAL NOT NULL
            );
            INSERT INTO app_preferences (id, theme_id, default_session_shortcut_id, terminal_font_size, keybindings_json, focus_workspace_enabled, updated_at)
            VALUES (1, 'catppuccin', NULL, 19, '[{"commandID":"openSettings","keyEquivalent":",","modifiers":["command","shift"]}]', 1, 90);
            PRAGMA user_version = \(WorkspaceMigrations.currentUserVersion);
            """)
        }

        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let preferences = try await store.loadAppPreferences()

        #expect(try inspectUserVersion(path: path) == WorkspaceMigrations.currentUserVersion)
        #expect(try inspectColumnNames(path: path, tableName: "app_preferences").contains("focus_workspace_continuity_enabled"))
        #expect(try inspectAppPreferencesFocusFlag(path: path) == true)
        #expect(try inspectAppPreferencesContinuityFlag(path: path) == false)
        #expect(preferences.themeID == "catppuccin")
        #expect(preferences.defaultSessionShortcutID == nil)
        #expect(preferences.terminalFontSize == 19)
        #expect(preferences.keybindings == [.openSettings: override])
        #expect(preferences.focusWorkspaceEnabled == true)
        #expect(preferences.focusWorkspaceContinuityEnabled == false)
        #expect(preferences.updatedAt == Date(timeIntervalSince1970: 90))
    }

    @Test
    func invalidStoredMixedTabValuesFailWithDescriptivePersistenceError() async throws {
        let path = temporaryDatabasePath()
        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let project = WorkspaceProject(path: "/Users/example/invalid", displayName: "invalid")
        let session = WorkspaceSession(projectID: project.id, title: "Invalid")
        let tabID = UUID()

        try await store.save(project: project)
        try await store.save(session: session)
        try execute(path: path, """
        INSERT INTO tabs (id, session_id, working_directory, launch_command, launch_arguments_json, kind, file_path, ordinal, created_at, last_activated_at)
        VALUES ('\(tabID.uuidString)', '\(session.id.uuidString)', '\(project.path)', NULL, NULL, 'file', NULL, 0, 10, 20)
        """)

        do {
            _ = try await store.loadTabs()
            Issue.record("Expected invalid file tab metadata to fail during load")
        } catch SQLiteWorkspaceMetadataStoreError.invalidStoredValue(let message) {
            #expect(message.contains(tabID.uuidString))
            #expect(message.contains("file_path"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func appPreferencesRoundTripPreservesNilAndNonNilDefaultShortcutReferences() async throws {
        let path = temporaryDatabasePath()
        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let nilDefaultPreferences = AppPreferences(
            themeID: "dracula",
            defaultSessionShortcutID: nil,
            terminalFontSize: 15,
            focusWorkspaceEnabled: false,
            keybindings: [
                .previousTab: KeybindingOverride(commandID: .previousTab, keyEquivalent: "leftArrow", modifiers: [.command, .option])
            ],
            updatedAt: Date(timeIntervalSince1970: 400)
        )
        let shortcut = SessionShortcut(
            label: "Claude",
            launchCommand: "claude",
            launchArgumentsJSON: "[]",
            isBuiltIn: true
        )

        try await store.save(appPreferences: nilDefaultPreferences)
        #expect(try await store.loadAppPreferences() == nilDefaultPreferences)

        try await store.save(shortcut: shortcut)
        let nonNilDefaultPreferences = AppPreferences(
            themeID: "onedark",
            defaultSessionShortcutID: shortcut.id,
            terminalFontSize: 17,
            focusWorkspaceEnabled: true,
            focusWorkspaceContinuityEnabled: true,
            keybindings: [
                .openSettings: KeybindingOverride(commandID: .openSettings, keyEquivalent: ",", modifiers: [.command, .shift]),
                .zoomOutTerminal: KeybindingOverride(commandID: .zoomOutTerminal, keyEquivalent: "-", modifiers: [.command])
            ],
            updatedAt: Date(timeIntervalSince1970: 500)
        )

        try await store.save(appPreferences: nonNilDefaultPreferences)

        #expect(try await store.loadAppPreferences() == nonNilDefaultPreferences)
    }

    @Test
    func appPreferencesRoundTripPreservesSystemThemeSelection() async throws {
        let path = temporaryDatabasePath()
        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let preferences = AppPreferences(
            themeID: AppTheme.systemSelectionID,
            terminalFontSize: 14,
            focusWorkspaceEnabled: true,
            updatedAt: Date(timeIntervalSince1970: 700)
        )

        try await store.save(appPreferences: preferences)

        #expect(try await store.loadAppPreferences() == preferences)
        #expect(try inspectUserVersion(path: path) == WorkspaceMigrations.currentUserVersion)
        #expect(try inspectColumnNames(path: path, tableName: "app_preferences") == [
            "id",
            "theme_id",
            "default_session_shortcut_id",
            "terminal_font_size",
            "keybindings_json",
            "focus_workspace_enabled",
            "focus_workspace_continuity_enabled",
            "updated_at"
        ])
    }

    @Test
    func builtInShortcutOverrideStatePersistsThroughSQLiteRoundTrip() async throws {
        let path = temporaryDatabasePath()
        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let shortcut = SessionShortcut(
            label: "Codex",
            launchCommand: "codex",
            launchArgumentsJSON: "[\"--model\",\"gpt-5.5\"]",
            isBuiltIn: true,
            hasUserOverride: true
        )

        try await store.save(shortcut: shortcut)

        #expect(try await store.loadSessionShortcuts() == [shortcut])
    }

    @Test
    func deletingPersistedShortcutClearsMatchingDefaultSessionShortcutID() async throws {
        let path = temporaryDatabasePath()
        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let shortcut = SessionShortcut(label: "OpenCode", launchCommand: "opencode")
        let project = WorkspaceProject(path: "/Users/example/delete-shortcut", displayName: "delete-shortcut")
        let session = WorkspaceSession(projectID: project.id, title: "OpenCode", shortcutID: shortcut.id)
        let tab = WorkspaceTab(
            sessionID: session.id,
            workingDirectory: project.path,
            shortcutID: shortcut.id,
            launchCommand: "opencode",
            ordinal: 0
        )
        let preferences = AppPreferences(
            themeID: "cursor",
            defaultSessionShortcutID: shortcut.id,
            updatedAt: Date(timeIntervalSince1970: 600)
        )

        try await store.save(shortcut: shortcut)
        try await store.save(project: project)
        try await store.save(session: session)
        try await store.save(tab: tab)
        try await store.save(appPreferences: preferences)
        try await store.deleteShortcut(id: shortcut.id)

        #expect(try await store.loadSessionShortcuts().isEmpty)
        #expect(try await store.loadSessions().first?.shortcutID == nil)
        #expect(try await store.loadTabs().first?.shortcutID == nil)
        #expect(try await store.loadAppPreferences().defaultSessionShortcutID == nil)
    }

    @Test
    func migrationExecuteReportsSQLiteErrors() throws {
        var database: OpaquePointer?
        guard sqlite3_open_v2(":memory:", &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            throw SQLiteWorkspaceMetadataStoreError.openFailed("Unable to open migration error fixture database")
        }
        defer { sqlite3_close(database) }

        #expect(throws: WorkspaceMigrationError.self) {
            try WorkspaceMigrations.execute(database, "CREATE TABLE broken (")
        }
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
    func activationSaveUpdatesTabRecencyWithoutRewritingOrdinal() async throws {
        let path = temporaryDatabasePath()
        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let activatedAt = Date(timeIntervalSince1970: 300)
        let project = WorkspaceProject(path: "/Users/example/reordered", displayName: "reordered")
        let session = WorkspaceSession(projectID: project.id, title: "Reordered")
        let firstTab = WorkspaceTab(
            sessionID: session.id,
            workingDirectory: project.path,
            ordinal: 0,
            lastActivatedAt: Date(timeIntervalSince1970: 40)
        )
        var restoredSecondTab = WorkspaceTab(
            sessionID: session.id,
            workingDirectory: project.path,
            ordinal: 1,
            lastActivatedAt: Date(timeIntervalSince1970: 50)
        )
        try await store.save(project: project)
        try await store.save(session: session)
        try await store.save(tab: firstTab)
        try await store.save(tab: restoredSecondTab)

        restoredSecondTab.ordinal = 0
        restoredSecondTab.lastActivatedAt = activatedAt
        try await store.saveActivation(
            project: project,
            session: session,
            tab: restoredSecondTab,
            snapshot: RestoreSnapshot(
                selectedProjectID: project.id,
                selectedSessionID: session.id,
                selectedTabID: restoredSecondTab.id,
                tabOrder: [restoredSecondTab.id, firstTab.id],
                updatedAt: activatedAt
            )
        )

        let loadedTabs = try await store.loadTabs()
        #expect(loadedTabs.map(\.id) == [firstTab.id, restoredSecondTab.id])
        #expect(loadedTabs.map(\.ordinal) == [0, 1])
        #expect(loadedTabs.first { $0.id == restoredSecondTab.id }?.lastActivatedAt == activatedAt)
        #expect(try await store.loadRestoreSnapshot()?.tabOrder == [restoredSecondTab.id, firstTab.id])
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

    @Test
    func projectOrderSavePersistsDenseSortIndexesAcrossReload() async throws {
        let path = temporaryDatabasePath()
        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let firstProject = WorkspaceProject(
            path: "/Users/example/project-order-first",
            displayName: "first",
            lastOpenedAt: Date(timeIntervalSince1970: 300),
            sortIndex: 30
        )
        let secondProject = WorkspaceProject(
            path: "/Users/example/project-order-second",
            displayName: "second",
            lastOpenedAt: Date(timeIntervalSince1970: 200),
            sortIndex: 20
        )
        let thirdProject = WorkspaceProject(
            path: "/Users/example/project-order-third",
            displayName: "third",
            lastOpenedAt: Date(timeIntervalSince1970: 100),
            sortIndex: 10
        )
        try await store.save(project: firstProject)
        try await store.save(project: secondProject)
        try await store.save(project: thirdProject)

        try await store.saveProjectOrder([secondProject.id, thirdProject.id, firstProject.id])

        let reloadedStore = try SQLiteWorkspaceMetadataStore(path: path)
        let loadedProjects = try await reloadedStore.loadProjects()

        #expect(loadedProjects.map(\.id) == [secondProject.id, thirdProject.id, firstProject.id])
        #expect(loadedProjects.map(\.sortIndex) == [0, 1, 2])
    }

    @Test
    func adjacentTabSwapPersistsWithoutUniqueOrdinalFailure() async throws {
        let path = temporaryDatabasePath()
        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let project = WorkspaceProject(path: "/Users/example/adjacent-swap", displayName: "adjacent-swap")
        let session = WorkspaceSession(projectID: project.id, title: "Adjacent Swap")
        let firstTab = WorkspaceTab(sessionID: session.id, workingDirectory: project.path, ordinal: 0)
        let secondTab = WorkspaceTab(sessionID: session.id, workingDirectory: project.path, ordinal: 1)
        let thirdTab = WorkspaceTab(sessionID: session.id, workingDirectory: project.path, ordinal: 2)
        try await store.save(project: project)
        try await store.save(session: session)
        try await store.save(tab: firstTab)
        try await store.save(tab: secondTab)
        try await store.save(tab: thirdTab)

        try await store.saveTabOrder(
            SessionTabReorderPlan(
                sessionID: session.id,
                visibleTabIDs: [secondTab.id, firstTab.id, thirdTab.id]
            ),
            snapshot: RestoreSnapshot(
                selectedProjectID: project.id,
                selectedSessionID: session.id,
                selectedTabID: secondTab.id,
                tabOrder: [secondTab.id, firstTab.id, thirdTab.id],
                updatedAt: Date(timeIntervalSince1970: 800)
            )
        )

        let loadedTabs = try await store.loadTabs()
        #expect(loadedTabs.map(\.id) == [secondTab.id, firstTab.id, thirdTab.id])
        #expect(loadedTabs.map(\.ordinal) == [0, 1, 2])
        #expect(try await store.loadRestoreSnapshot()?.tabOrder == [secondTab.id, firstTab.id, thirdTab.id])
    }

    @Test
    func firstToEndAndLastToBeginningTabMovesPersistAcrossReload() async throws {
        let path = temporaryDatabasePath()
        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let project = WorkspaceProject(path: "/Users/example/end-moves", displayName: "end-moves")
        let session = WorkspaceSession(projectID: project.id, title: "End Moves")
        let firstTab = WorkspaceTab(sessionID: session.id, workingDirectory: project.path, ordinal: 0)
        let secondTab = WorkspaceTab(sessionID: session.id, workingDirectory: project.path, ordinal: 1)
        let thirdTab = WorkspaceTab(sessionID: session.id, workingDirectory: project.path, ordinal: 2)
        let fourthTab = WorkspaceTab(sessionID: session.id, workingDirectory: project.path, ordinal: 3)
        try await store.save(project: project)
        try await store.save(session: session)
        try await store.save(tab: firstTab)
        try await store.save(tab: secondTab)
        try await store.save(tab: thirdTab)
        try await store.save(tab: fourthTab)

        try await store.saveTabOrder(
            SessionTabReorderPlan(
                sessionID: session.id,
                visibleTabIDs: [secondTab.id, thirdTab.id, fourthTab.id, firstTab.id]
            ),
            snapshot: RestoreSnapshot(
                selectedProjectID: project.id,
                selectedSessionID: session.id,
                selectedTabID: firstTab.id,
                tabOrder: [secondTab.id, thirdTab.id, fourthTab.id, firstTab.id],
                updatedAt: Date(timeIntervalSince1970: 900)
            )
        )

        let afterFirstMoveReload = try SQLiteWorkspaceMetadataStore(path: path)
        #expect(try await afterFirstMoveReload.loadTabs().map(\.id) == [
            secondTab.id,
            thirdTab.id,
            fourthTab.id,
            firstTab.id
        ])

        try await afterFirstMoveReload.saveTabOrder(
            SessionTabReorderPlan(
                sessionID: session.id,
                visibleTabIDs: [firstTab.id, secondTab.id, thirdTab.id, fourthTab.id]
            ),
            snapshot: RestoreSnapshot(
                selectedProjectID: project.id,
                selectedSessionID: session.id,
                selectedTabID: firstTab.id,
                tabOrder: [firstTab.id, secondTab.id, thirdTab.id, fourthTab.id],
                updatedAt: Date(timeIntervalSince1970: 950)
            )
        )

        let afterSecondMoveReload = try SQLiteWorkspaceMetadataStore(path: path)
        let reloadedTabs = try await afterSecondMoveReload.loadTabs()
        #expect(reloadedTabs.map(\.id) == [firstTab.id, secondTab.id, thirdTab.id, fourthTab.id])
        #expect(reloadedTabs.map(\.ordinal) == [0, 1, 2, 3])
        #expect(try await afterSecondMoveReload.loadRestoreSnapshot()?.tabOrder == [
            firstTab.id,
            secondTab.id,
            thirdTab.id,
            fourthTab.id
        ])
    }

    @Test
    func failedTabOrderSaveRollsBackOrdinalsAndRestoreSnapshot() async throws {
        let path = temporaryDatabasePath()
        let store = try SQLiteWorkspaceMetadataStore(path: path)
        let project = WorkspaceProject(path: "/Users/example/reorder-rollback", displayName: "reorder-rollback")
        let session = WorkspaceSession(projectID: project.id, title: "Rollback")
        let firstTab = WorkspaceTab(sessionID: session.id, workingDirectory: project.path, ordinal: 0)
        let secondTab = WorkspaceTab(sessionID: session.id, workingDirectory: project.path, ordinal: 1)
        let thirdTab = WorkspaceTab(sessionID: session.id, workingDirectory: project.path, ordinal: 2)
        let originalSnapshot = RestoreSnapshot(
            selectedProjectID: project.id,
            selectedSessionID: session.id,
            selectedTabID: firstTab.id,
            tabOrder: [firstTab.id, secondTab.id, thirdTab.id],
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        try await store.save(project: project)
        try await store.save(session: session)
        try await store.save(tab: firstTab)
        try await store.save(tab: secondTab)
        try await store.save(tab: thirdTab)
        try await store.save(snapshot: originalSnapshot)

        await #expect(throws: SQLiteWorkspaceMetadataStoreError.self) {
            try await store.saveTabOrder(
                SessionTabReorderPlan(
                    sessionID: session.id,
                    visibleTabIDs: [thirdTab.id, secondTab.id, firstTab.id]
                ),
                snapshot: RestoreSnapshot(
                    selectedProjectID: project.id,
                    selectedSessionID: session.id,
                    selectedTabID: UUID(),
                    tabOrder: [thirdTab.id, secondTab.id, firstTab.id],
                    updatedAt: Date(timeIntervalSince1970: 1_100)
                )
            )
        }

        let loadedTabs = try await store.loadTabs()
        #expect(loadedTabs.map(\.id) == [firstTab.id, secondTab.id, thirdTab.id])
        #expect(loadedTabs.map(\.ordinal) == [0, 1, 2])
        #expect(try await store.loadRestoreSnapshot() == originalSnapshot)
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

    private func inspectAppPreferencesRowCount(path: String) throws -> Int {
        try inspect(path: path, sql: "SELECT COUNT(*) FROM app_preferences") { statement in
            Int(sqlite3_column_int64(statement, 0))
        }.first ?? 0
    }

    private func inspectAppPreferencesFocusFlag(path: String) throws -> Bool {
        try inspect(path: path, sql: "SELECT focus_workspace_enabled FROM app_preferences WHERE id = 1") { statement in
            sqlite3_column_int(statement, 0) != 0
        }.first ?? false
    }

    private func inspectAppPreferencesContinuityFlag(path: String) throws -> Bool {
        try inspect(path: path, sql: "SELECT focus_workspace_continuity_enabled FROM app_preferences WHERE id = 1") { statement in
            sqlite3_column_int(statement, 0) != 0
        }.first ?? false
    }

    private func inspectUserVersion(path: String) throws -> Int32 {
        var database: OpaquePointer?
        guard sqlite3_open_v2(path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            throw SQLiteWorkspaceMetadataStoreError.openFailed("Unable to open inspection database")
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteWorkspaceMetadataStoreError.prepareFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw SQLiteWorkspaceMetadataStoreError.invalidStoredValue("Unable to read user_version")
        }
        return sqlite3_column_int(statement, 0)
    }

    private func inspectColumnNames(path: String, tableName: String) throws -> Set<String> {
        try inspect(path: path, sql: "PRAGMA table_info(\(tableName))") { statement in
            guard let pointer = sqlite3_column_text(statement, 1) else { return nil }
            return String(cString: pointer)
        }
    }

    private func createVersionOneDatabase(path: String) throws -> VersionOneFixture {
        let fixture = VersionOneFixture()
        var database: OpaquePointer?
        guard sqlite3_open_v2(path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            throw SQLiteWorkspaceMetadataStoreError.openFailed("Unable to create v1 fixture database")
        }
        defer { sqlite3_close(database) }

        try execute(database, """
        PRAGMA foreign_keys = ON;
        CREATE TABLE projects (
            id TEXT PRIMARY KEY NOT NULL,
            path TEXT NOT NULL UNIQUE,
            bookmark_data BLOB,
            display_name TEXT NOT NULL,
            created_at REAL NOT NULL,
            last_opened_at REAL NOT NULL,
            sort_index INTEGER NOT NULL
        );
        CREATE TABLE session_shortcuts (
            id TEXT PRIMARY KEY NOT NULL,
            label TEXT NOT NULL,
            launch_command TEXT NOT NULL,
            launch_arguments_json TEXT,
            secret_ref TEXT,
            is_built_in INTEGER NOT NULL CHECK (is_built_in IN (0, 1))
        );
        CREATE TABLE sessions (
            id TEXT PRIMARY KEY NOT NULL,
            project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
            title TEXT NOT NULL,
            is_user_named INTEGER NOT NULL CHECK (is_user_named IN (0, 1)),
            shortcut_id TEXT REFERENCES session_shortcuts(id) ON DELETE SET NULL,
            created_at REAL NOT NULL,
            last_activated_at REAL NOT NULL
        );
        CREATE TABLE tabs (
            id TEXT PRIMARY KEY NOT NULL,
            session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
            working_directory TEXT NOT NULL,
            launch_command TEXT,
            launch_arguments_json TEXT,
            ordinal INTEGER NOT NULL,
            created_at REAL NOT NULL,
            last_activated_at REAL NOT NULL,
            UNIQUE(session_id, ordinal)
        );
        CREATE TABLE restore_snapshot (
            id INTEGER PRIMARY KEY NOT NULL CHECK (id = 1),
            selected_project_id TEXT REFERENCES projects(id) ON DELETE SET NULL,
            selected_session_id TEXT REFERENCES sessions(id) ON DELETE SET NULL,
            selected_tab_id TEXT REFERENCES tabs(id) ON DELETE SET NULL,
            tab_order_json TEXT NOT NULL,
            updated_at REAL NOT NULL
        );
        INSERT INTO projects (id, path, bookmark_data, display_name, created_at, last_opened_at, sort_index)
        VALUES ('\(fixture.project.id.uuidString)', '\(fixture.project.path)', NULL, '\(fixture.project.displayName)', 10, 20, \(fixture.project.sortIndex));
        INSERT INTO session_shortcuts (id, label, launch_command, launch_arguments_json, secret_ref, is_built_in)
        VALUES ('\(fixture.shortcut.id.uuidString)', '\(fixture.shortcut.label)', '\(fixture.shortcut.launchCommand)', '\(fixture.shortcut.launchArgumentsJSON!)', '\(fixture.shortcut.secretRef!)', 1);
        INSERT INTO sessions (id, project_id, title, is_user_named, shortcut_id, created_at, last_activated_at)
        VALUES ('\(fixture.session.id.uuidString)', '\(fixture.project.id.uuidString)', '\(fixture.session.title)', 1, '\(fixture.shortcut.id.uuidString)', 30, 40);
        INSERT INTO tabs (id, session_id, working_directory, launch_command, launch_arguments_json, ordinal, created_at, last_activated_at)
        VALUES ('\(fixture.tab.id.uuidString)', '\(fixture.session.id.uuidString)', '\(fixture.tab.workingDirectory)', '\(fixture.tab.launchCommand!)', '\(fixture.tab.launchArgumentsJSON!)', \(fixture.tab.ordinal), 50, 60);
        INSERT INTO restore_snapshot (id, selected_project_id, selected_session_id, selected_tab_id, tab_order_json, updated_at)
        VALUES (1, '\(fixture.project.id.uuidString)', '\(fixture.session.id.uuidString)', '\(fixture.tab.id.uuidString)', '[\"\(fixture.tab.id.uuidString)\"]', 70);
        PRAGMA user_version = 1;
        """)

        return fixture
    }

    private func createVersionFiveDatabase(path: String) throws -> VersionFiveFixture {
        let fixture = VersionFiveFixture()
        var database: OpaquePointer?
        guard sqlite3_open_v2(path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            throw SQLiteWorkspaceMetadataStoreError.openFailed("Unable to create v5 fixture database")
        }
        defer { sqlite3_close(database) }

        try execute(database, """
        PRAGMA foreign_keys = ON;
        CREATE TABLE projects (
            id TEXT PRIMARY KEY NOT NULL,
            path TEXT NOT NULL UNIQUE,
            bookmark_data BLOB,
            display_name TEXT NOT NULL,
            created_at REAL NOT NULL,
            last_opened_at REAL NOT NULL,
            sort_index INTEGER NOT NULL
        );
        CREATE TABLE session_shortcuts (
            id TEXT PRIMARY KEY NOT NULL,
            label TEXT NOT NULL,
            launch_command TEXT NOT NULL,
            launch_arguments_json TEXT,
            secret_ref TEXT,
            is_built_in INTEGER NOT NULL CHECK (is_built_in IN (0, 1)),
            has_user_override INTEGER NOT NULL DEFAULT 0 CHECK (has_user_override IN (0, 1))
        );
        CREATE TABLE sessions (
            id TEXT PRIMARY KEY NOT NULL,
            project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
            title TEXT NOT NULL,
            is_user_named INTEGER NOT NULL CHECK (is_user_named IN (0, 1)),
            shortcut_id TEXT REFERENCES session_shortcuts(id) ON DELETE SET NULL,
            created_at REAL NOT NULL,
            last_activated_at REAL NOT NULL
        );
        CREATE TABLE tabs (
            id TEXT PRIMARY KEY NOT NULL,
            session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
            working_directory TEXT NOT NULL,
            title TEXT,
            shortcut_id TEXT REFERENCES session_shortcuts(id) ON DELETE SET NULL,
            launch_command TEXT,
            launch_arguments_json TEXT,
            kind TEXT NOT NULL DEFAULT 'terminal' CHECK (kind IN ('terminal', 'file')),
            file_path TEXT,
            ordinal INTEGER NOT NULL,
            created_at REAL NOT NULL,
            last_activated_at REAL NOT NULL,
            UNIQUE(session_id, ordinal)
        );
        CREATE TABLE app_preferences (
            id INTEGER PRIMARY KEY NOT NULL CHECK (id = 1),
            theme_id TEXT NOT NULL,
            default_session_shortcut_id TEXT REFERENCES session_shortcuts(id) ON DELETE SET NULL,
            terminal_font_size REAL NOT NULL DEFAULT \(AppPreferences.defaultTerminalFontSize),
            keybindings_json TEXT NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE TABLE restore_snapshot (
            id INTEGER PRIMARY KEY NOT NULL CHECK (id = 1),
            selected_project_id TEXT REFERENCES projects(id) ON DELETE SET NULL,
            selected_session_id TEXT REFERENCES sessions(id) ON DELETE SET NULL,
            selected_tab_id TEXT REFERENCES tabs(id) ON DELETE SET NULL,
            tab_order_json TEXT NOT NULL,
            updated_at REAL NOT NULL
        );
        INSERT INTO projects (id, path, bookmark_data, display_name, created_at, last_opened_at, sort_index)
        VALUES ('\(fixture.project.id.uuidString)', '\(fixture.project.path)', NULL, '\(fixture.project.displayName)', 10, 20, \(fixture.project.sortIndex));
        INSERT INTO session_shortcuts (id, label, launch_command, launch_arguments_json, secret_ref, is_built_in, has_user_override)
        VALUES ('\(fixture.shortcut.id.uuidString)', '\(fixture.shortcut.label)', '\(fixture.shortcut.launchCommand)', '\(fixture.shortcut.launchArgumentsJSON!)', '\(fixture.shortcut.secretRef!)', 1, 1);
        INSERT INTO sessions (id, project_id, title, is_user_named, shortcut_id, created_at, last_activated_at)
        VALUES ('\(fixture.session.id.uuidString)', '\(fixture.project.id.uuidString)', '\(fixture.session.title)', 1, '\(fixture.shortcut.id.uuidString)', 30, 40);
        INSERT INTO tabs (id, session_id, working_directory, title, shortcut_id, launch_command, launch_arguments_json, kind, file_path, ordinal, created_at, last_activated_at)
        VALUES ('\(fixture.tab.id.uuidString)', '\(fixture.session.id.uuidString)', '\(fixture.tab.workingDirectory)', '\(fixture.tab.title!)', '\(fixture.shortcut.id.uuidString)', '\(fixture.tab.launchCommand!)', '\(fixture.tab.launchArgumentsJSON!)', 'terminal', NULL, \(fixture.tab.ordinal), 50, 60);
        INSERT INTO app_preferences (id, theme_id, default_session_shortcut_id, terminal_font_size, keybindings_json, updated_at)
        VALUES (1, 'dracula', '\(fixture.shortcut.id.uuidString)', 16, '[{"commandID":"openSettings","keyEquivalent":",","modifiers":["command","shift"]}]', 80);
        INSERT INTO restore_snapshot (id, selected_project_id, selected_session_id, selected_tab_id, tab_order_json, updated_at)
        VALUES (1, '\(fixture.project.id.uuidString)', '\(fixture.session.id.uuidString)', '\(fixture.tab.id.uuidString)', '[\"\(fixture.tab.id.uuidString)\"]', 70);
        PRAGMA user_version = 5;
        """)

        return fixture
    }

    private func createVersionSixDatabase(path: String) throws -> VersionFiveFixture {
        let fixture = try createVersionFiveDatabase(path: path)
        try execute(path: path, """
        ALTER TABLE app_preferences ADD COLUMN focus_workspace_enabled INTEGER NOT NULL DEFAULT 0 CHECK (focus_workspace_enabled IN (0, 1));
        UPDATE app_preferences SET focus_workspace_enabled = 1 WHERE id = 1;
        PRAGMA user_version = 6;
        """)
        return fixture
    }

    private func execute(_ database: OpaquePointer?, _ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "Unknown SQLite error"
            sqlite3_free(error)
            throw SQLiteWorkspaceMetadataStoreError.stepFailed(message)
        }
    }

    private func execute(path: String, _ sql: String) throws {
        var database: OpaquePointer?
        guard sqlite3_open_v2(path, &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            throw SQLiteWorkspaceMetadataStoreError.openFailed("Unable to open writable inspection database")
        }
        defer { sqlite3_close(database) }
        try execute(database, sql)
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

private struct VersionOneFixture {
    let project = WorkspaceProject(
        id: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
        path: "/Users/example/v1-project",
        displayName: "v1-project",
        createdAt: Date(timeIntervalSince1970: 10),
        lastOpenedAt: Date(timeIntervalSince1970: 20),
        sortIndex: 3
    )
    let shortcut = SessionShortcut(
        id: UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!,
        label: "Codex",
        launchCommand: "codex",
        launchArgumentsJSON: "[]",
        secretRef: "keychain://native-mac-ade/codex",
        isBuiltIn: true
    )
    let session = WorkspaceSession(
        id: UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!,
        projectID: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
        title: "Restored v1",
        isUserNamed: true,
        shortcutID: UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!,
        createdAt: Date(timeIntervalSince1970: 30),
        lastActivatedAt: Date(timeIntervalSince1970: 40)
    )
    let tab = WorkspaceTab(
        id: UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-dddddddddddd")!,
        sessionID: UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!,
        workingDirectory: "/Users/example/v1-project",
        launchCommand: "codex",
        launchArgumentsJSON: "[]",
        ordinal: 0,
        createdAt: Date(timeIntervalSince1970: 50),
        lastActivatedAt: Date(timeIntervalSince1970: 60)
    )

    var restoreSnapshot: RestoreSnapshot {
        RestoreSnapshot(
            selectedProjectID: project.id,
            selectedSessionID: session.id,
            selectedTabID: tab.id,
            tabOrder: [tab.id],
            updatedAt: Date(timeIntervalSince1970: 70)
        )
    }
}

private struct VersionFiveFixture {
    let project = WorkspaceProject(
        id: UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee")!,
        path: "/Users/example/v5-project",
        displayName: "v5-project",
        createdAt: Date(timeIntervalSince1970: 10),
        lastOpenedAt: Date(timeIntervalSince1970: 20),
        sortIndex: 4
    )
    let shortcut = SessionShortcut(
        id: UUID(uuidString: "ffffffff-ffff-4fff-8fff-ffffffffffff")!,
        label: "Focused Codex",
        launchCommand: "codex",
        launchArgumentsJSON: "[]",
        secretRef: "keychain://native-mac-ade/focused-codex",
        isBuiltIn: true,
        hasUserOverride: true
    )
    let session = WorkspaceSession(
        id: UUID(uuidString: "99999999-9999-4999-8999-999999999999")!,
        projectID: UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee")!,
        title: "Restored v5",
        isUserNamed: true,
        shortcutID: UUID(uuidString: "ffffffff-ffff-4fff-8fff-ffffffffffff")!,
        createdAt: Date(timeIntervalSince1970: 30),
        lastActivatedAt: Date(timeIntervalSince1970: 40)
    )
    let tab = WorkspaceTab(
        id: UUID(uuidString: "88888888-8888-4888-8888-888888888888")!,
        sessionID: UUID(uuidString: "99999999-9999-4999-8999-999999999999")!,
        workingDirectory: "/Users/example/v5-project",
        title: "Focused Tab",
        shortcutID: UUID(uuidString: "ffffffff-ffff-4fff-8fff-ffffffffffff")!,
        launchCommand: "codex",
        launchArgumentsJSON: "[]",
        ordinal: 0,
        createdAt: Date(timeIntervalSince1970: 50),
        lastActivatedAt: Date(timeIntervalSince1970: 60)
    )
    let openSettingsOverride = KeybindingOverride(
        commandID: .openSettings,
        keyEquivalent: ",",
        modifiers: [.command, .shift]
    )

    var restoreSnapshot: RestoreSnapshot {
        RestoreSnapshot(
            selectedProjectID: project.id,
            selectedSessionID: session.id,
            selectedTabID: tab.id,
            tabOrder: [tab.id],
            updatedAt: Date(timeIntervalSince1970: 70)
        )
    }
}
