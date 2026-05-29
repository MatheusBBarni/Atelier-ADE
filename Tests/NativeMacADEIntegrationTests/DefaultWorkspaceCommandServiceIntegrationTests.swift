import Foundation
import SQLite3
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
        #expect(harness.store.selectedTabID == tabsBefore.first?.id)
        #expect(snapshotAfter?.selectedTabID == tabsBefore.first?.id)
        #expect(harness.service.metrics.terminalSurfaceFailureCount == 1)
        #expect(harness.service.metrics.diagnostics().releaseBlockingReasons.contains("terminal surface failure rate above 1%"))
        #expect(harness.service.logger.events.contains { event in
            event.name == "terminal_surface_failed" && event.fields["reason"]?.contains("surface failed") == true
        })
    }

    @Test
    func creatingSessionWithLightweightShortcutLaunchesFirstTabWithShortcutConfiguration() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let project = try await harness.service.openProject(path: projectPath)
        let shortcut = SessionShortcut(
            label: "Codex Resume",
            launchCommand: "codex",
            launchArgumentsJSON: "[\"resume\"]",
            isBuiltIn: true
        )
        try await harness.persistence.save(shortcut: shortcut)

        let session = try await harness.service.createSession(projectID: project.id, shortcutID: shortcut.id)
        let launchedTab = try #require(harness.terminal.createdTabs.first)
        let persistedSessions = try await harness.persistence.loadSessions()
        let persistedTabs = try await harness.persistence.loadTabs()

        #expect(session.shortcutID == shortcut.id)
        #expect(persistedSessions.map(\.id) == [session.id])
        #expect(launchedTab.sessionID == session.id)
        #expect(launchedTab.workingDirectory == project.path)
        #expect(launchedTab.launchCommand == "codex")
        #expect(launchedTab.launchArgumentsJSON == "[\"resume\"]")
        #expect(persistedTabs.map(\.id) == [launchedTab.id])
        #expect(persistedTabs.first?.launchCommand == launchedTab.launchCommand)
        #expect(persistedTabs.first?.launchArgumentsJSON == launchedTab.launchArgumentsJSON)
        #expect(harness.store.selectedTabID == launchedTab.id)
    }

    @Test
    func creatingSessionWithoutExplicitShortcutUsesSavedDefaultProfile() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let project = try await harness.service.openProject(path: projectPath)
        let shortcut = SessionShortcut(
            label: "Claude Default",
            launchCommand: "claude",
            launchArgumentsJSON: "[\"--continue\"]",
            isBuiltIn: true
        )
        try await harness.persistence.save(shortcut: shortcut)
        try await harness.persistence.save(appPreferences: AppPreferences(defaultSessionShortcutID: shortcut.id))

        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let launchedTab = try #require(harness.terminal.createdTabs.first)
        let persistedSessions = try await harness.persistence.loadSessions()
        let persistedTabs = try await harness.persistence.loadTabs()

        #expect(session.shortcutID == shortcut.id)
        #expect(persistedSessions.map(\.id) == [session.id])
        #expect(persistedTabs.map(\.id) == [launchedTab.id])
        #expect(launchedTab.launchCommand == "claude")
        #expect(launchedTab.launchArgumentsJSON == "[\"--continue\"]")
        #expect(harness.store.selectedTabID == launchedTab.id)
    }

    @Test
    func preferencesAndBuiltInOverrideStateRoundTripThroughSQLiteCommandService() async throws {
        let harness = try makeHarness()
        let codex = try #require(SessionShortcut.builtInDefaults.first { $0.label == "Codex" })
        var overriddenCodex = codex
        overriddenCodex.launchArgumentsJSON = "[\"exec\"]"
        let savedCodex = try await harness.service.saveSessionShortcut(overriddenCodex)
        let preferences = AppPreferences(
            themeID: "catppuccin",
            defaultSessionShortcutID: codex.id,
            keybindings: [
                .openSettings: KeybindingOverride(commandID: .openSettings, keyEquivalent: ",", modifiers: [.command, .shift])
            ]
        )

        try await harness.service.saveAppPreferences(preferences)

        let reloadedStore = WorkspaceStore()
        let reloadedTerminal = FakeIntegrationTerminalSurfaceManager()
        let reloadedService = DefaultWorkspaceCommandService(
            store: reloadedStore,
            persistenceStore: harness.persistence,
            restoreCoordinator: RestoreCoordinator(persistenceStore: harness.persistence),
            terminalSurfaceManager: reloadedTerminal
        )
        let loadedPreferences = try await reloadedService.loadAppPreferences()
        let loadedShortcuts = try await reloadedService.availableSessionShortcuts()

        #expect(savedCodex.hasUserOverride == true)
        #expect(loadedPreferences.themeID == "catppuccin")
        #expect(loadedPreferences.defaultSessionShortcutID == codex.id)
        #expect(loadedPreferences.keybindings[.openSettings]?.modifiers == [.command, .shift])
        #expect(reloadedStore.appPreferences == loadedPreferences)
        #expect(loadedShortcuts.first { $0.id == codex.id }?.launchArgumentsJSON == "[\"exec\"]")
        #expect(loadedShortcuts.first { $0.id == codex.id }?.hasUserOverride == true)
    }

    @Test
    func savingBuiltInDefaultPreferenceSeedsSQLiteProfileReference() async throws {
        let harness = try makeHarness()
        let openCode = try #require(SessionShortcut.builtInDefaults.first { $0.label == "OpenCode" })

        try await harness.service.saveAppPreferences(AppPreferences(defaultSessionShortcutID: openCode.id))

        #expect(try await harness.persistence.loadAppPreferences().defaultSessionShortcutID == openCode.id)
        #expect(try await harness.persistence.loadSessionShortcuts().contains(openCode))
        #expect(harness.store.appPreferences.defaultSessionShortcutID == openCode.id)
    }

    @Test
    func explicitProfileBeatsSavedDefaultAndSavedDefaultBeatsPlainSessionCreation() async throws {
        let harness = try makeHarness()
        let project = try await harness.service.openProject(path: makeTemporaryProjectDirectory())
        let explicitShortcut = try await harness.service.saveSessionShortcut(SessionShortcut(
            label: "Explicit Codex",
            launchCommand: "codex",
            launchArgumentsJSON: "[\"exec\"]"
        ))
        let defaultShortcut = try await harness.service.saveSessionShortcut(SessionShortcut(
            label: "Default Claude",
            launchCommand: "claude",
            launchArgumentsJSON: "[\"--continue\"]"
        ))
        try await harness.service.saveAppPreferences(AppPreferences(defaultSessionShortcutID: defaultShortcut.id))

        let explicitSession = try await harness.service.createSession(projectID: project.id, shortcutID: explicitShortcut.id)
        let defaultSession = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        try await harness.service.saveAppPreferences(AppPreferences(defaultSessionShortcutID: nil))
        let plainSession = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let launchedTabs = harness.terminal.createdTabs

        #expect(explicitSession.shortcutID == explicitShortcut.id)
        #expect(defaultSession.shortcutID == defaultShortcut.id)
        #expect(plainSession.shortcutID == nil)
        #expect(launchedTabs.first { $0.sessionID == explicitSession.id }?.launchCommand == "codex")
        #expect(launchedTabs.first { $0.sessionID == defaultSession.id }?.launchCommand == "claude")
        #expect(launchedTabs.first { $0.sessionID == plainSession.id }?.launchCommand == nil)
    }

    @Test
    func loadingPersistedStaleDefaultSelfHealsAndPlainSessionCreationSucceeds() async throws {
        let harness = try makeHarness()
        let staleShortcutID = UUID()
        let project = try await harness.service.openProject(path: makeTemporaryProjectDirectory())
        try writeStaleDefaultShortcutID(staleShortcutID, databasePath: harness.databasePath)

        let loadedPreferences = try await harness.service.loadAppPreferences()
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let tab = try #require(harness.terminal.createdTabs.last)

        #expect(loadedPreferences.defaultSessionShortcutID == nil)
        #expect(try await harness.persistence.loadAppPreferences().defaultSessionShortcutID == nil)
        #expect(harness.store.appPreferences.defaultSessionShortcutID == nil)
        #expect(session.shortcutID == nil)
        #expect(tab.launchCommand == nil)
    }

    @Test
    func repeatedProfileListLoadsDoNotDuplicateBuiltInsAndIncludeOpenCode() async throws {
        let harness = try makeHarness()

        let firstLoad = try await harness.service.availableSessionShortcuts()
        let secondLoad = try await harness.service.availableSessionShortcuts()
        let persistedShortcuts = try await harness.persistence.loadSessionShortcuts()
        let openCode = try #require(secondLoad.first { $0.label == "OpenCode" })

        #expect(firstLoad == secondLoad)
        #expect(persistedShortcuts == secondLoad)
        #expect(openCode.launchCommand == "opencode")
        #expect(openCode.id == UUID(uuidString: "33333333-3333-4333-8333-333333333333"))
        #expect(secondLoad.filter(\.isBuiltIn).count == SessionShortcut.builtInDefaults.count)
        #expect(Set(secondLoad.map(\.id)).count == secondLoad.count)
    }

    @Test
    func creatingTabInShortcutSessionPersistsStoredLaunchIntent() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let project = try await harness.service.openProject(path: projectPath)
        let shortcut = SessionShortcut(
            label: "Claude Continue",
            launchCommand: "claude",
            launchArgumentsJSON: "[\"--continue\"]",
            isBuiltIn: true
        )
        try await harness.persistence.save(shortcut: shortcut)

        let session = try await harness.service.createSession(projectID: project.id, shortcutID: shortcut.id)
        let tab = try await harness.service.createTab(sessionID: session.id)
        let persistedTab = try #require(try await harness.persistence.loadTabs().first { $0.id == tab.id })

        #expect(tab.launchCommand == "claude")
        #expect(tab.launchArgumentsJSON == "[\"--continue\"]")
        #expect(persistedTab.launchCommand == "claude")
        #expect(persistedTab.launchArgumentsJSON == "[\"--continue\"]")
    }

    @Test
    func sessionCreationRollsBackSessionWhenFirstTabSurfaceFails() async throws {
        let harness = try makeHarness()
        let project = try await harness.service.openProject(path: makeTemporaryProjectDirectory())
        harness.terminal.surfaceCreationError = GhosttyAdapterError.surfaceCreationFailed("first tab failed")

        await #expect(throws: WorkspaceCommandError.terminalUnavailable("first tab failed")) {
            _ = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        }

        #expect(harness.store.sessions.isEmpty)
        #expect(harness.store.tabs.isEmpty)
        #expect(try await harness.persistence.loadSessions().isEmpty)
        #expect(try await harness.persistence.loadTabs().isEmpty)
        #expect(harness.store.selectedSessionID == nil)
        #expect(harness.store.selectedTabID == nil)
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
    func restoringShortcutLinkedTabPreservesLaunchIntentForFreshSurface() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let projectID = UUID()
        let shortcut = SessionShortcut(
            label: "Claude Continue",
            launchCommand: "claude",
            launchArgumentsJSON: "[\"--continue\"]",
            isBuiltIn: true
        )
        let sessionID = UUID()
        let tabID = UUID()
        try await harness.persistence.save(project: WorkspaceProject(id: projectID, path: projectPath, displayName: "shortcut"))
        try await harness.persistence.save(shortcut: shortcut)
        try await harness.persistence.save(session: WorkspaceSession(id: sessionID, projectID: projectID, title: "Shortcut", shortcutID: shortcut.id))
        try await harness.persistence.save(tab: WorkspaceTab(
            id: tabID,
            sessionID: sessionID,
            workingDirectory: projectPath,
            launchCommand: shortcut.launchCommand,
            launchArgumentsJSON: shortcut.launchArgumentsJSON,
            ordinal: 0
        ))
        try await harness.persistence.save(snapshot: RestoreSnapshot(
            selectedProjectID: projectID,
            selectedSessionID: sessionID,
            selectedTabID: tabID,
            tabOrder: [tabID]
        ))

        try await harness.service.restoreWorkspace()
        let restoredTab = try #require(harness.terminal.createdTabs.first)

        #expect(restoredTab.id == tabID)
        #expect(restoredTab.launchCommand == "claude")
        #expect(restoredTab.launchArgumentsJSON == "[\"--continue\"]")
    }

    @Test
    func restoringPersistedTabKeepsOriginalLaunchIntentAfterDefaultProfileChanges() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let projectID = UUID()
        let originalShortcut = SessionShortcut(
            label: "Original Codex",
            launchCommand: "codex",
            launchArgumentsJSON: "[\"exec\"]",
            isBuiltIn: true
        )
        let newDefaultShortcut = SessionShortcut(
            label: "New Claude",
            launchCommand: "claude",
            launchArgumentsJSON: "[\"--continue\"]",
            isBuiltIn: true
        )
        let sessionID = UUID()
        let tabID = UUID()
        try await harness.persistence.save(project: WorkspaceProject(id: projectID, path: projectPath, displayName: "restore-default-change"))
        try await harness.persistence.save(shortcut: originalShortcut)
        try await harness.persistence.save(shortcut: newDefaultShortcut)
        try await harness.persistence.save(appPreferences: AppPreferences(defaultSessionShortcutID: newDefaultShortcut.id))
        try await harness.persistence.save(session: WorkspaceSession(id: sessionID, projectID: projectID, title: "Original", shortcutID: originalShortcut.id))
        try await harness.persistence.save(tab: WorkspaceTab(
            id: tabID,
            sessionID: sessionID,
            workingDirectory: projectPath,
            launchCommand: originalShortcut.launchCommand,
            launchArgumentsJSON: originalShortcut.launchArgumentsJSON,
            ordinal: 0
        ))
        try await harness.persistence.save(snapshot: RestoreSnapshot(
            selectedProjectID: projectID,
            selectedSessionID: sessionID,
            selectedTabID: tabID,
            tabOrder: [tabID]
        ))

        try await harness.service.restoreWorkspace()
        let restoredTab = try #require(harness.terminal.createdTabs.first)

        #expect(restoredTab.launchCommand == "codex")
        #expect(restoredTab.launchArgumentsJSON == "[\"exec\"]")
    }

    @Test
    func closingLastTabRemovesPersistenceAndClearsSelectedTab() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let tab = try #require(harness.store.tabs.first)

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
    func forceClosingExitedTerminalLeavesRemainingTabsStable() async throws {
        let harness = try makeHarness()
        let project = try await harness.service.openProject(path: makeTemporaryProjectDirectory())
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let initialTab = try #require(harness.store.tabs.first)
        let exitedTab = try await harness.service.createTab(sessionID: session.id)
        let remainingTab = try await harness.service.createTab(sessionID: session.id)

        try await harness.service.closeTab(tabID: exitedTab.id, force: true)

        #expect(harness.store.tabs.map(\.id) == [initialTab.id, remainingTab.id])
        #expect(harness.store.selectedProjectID == project.id)
        #expect(harness.store.selectedSessionID == session.id)
        #expect(harness.store.selectedTabID == remainingTab.id)
        #expect(try await harness.persistence.loadTabs().map(\.id) == [initialTab.id, remainingTab.id])
        #expect(harness.terminal.closeRequests.isEmpty)
        #expect(harness.terminal.releasedTabIDs == [exitedTab.id])
    }

    @Test
    func removingProjectDeletesDependentGraphAndClearsPersistedSelection() async throws {
        let harness = try makeHarness()
        let project = try await harness.service.openProject(path: makeTemporaryProjectDirectory())
        _ = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let tab = try #require(harness.store.tabs.first)

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

    @Test
    func removingSessionClosesRunningTabsAndDeletesSessionMetadata() async throws {
        let harness = try makeHarness()
        let project = try await harness.service.openProject(path: makeTemporaryProjectDirectory())
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let tab = try #require(harness.store.tabs.first)
        harness.terminal.canCloseResult = false

        try await harness.service.removeSession(id: session.id)

        #expect(harness.store.sessions.isEmpty)
        #expect(harness.store.tabs.isEmpty)
        #expect(try await harness.persistence.loadSessions().isEmpty)
        #expect(try await harness.persistence.loadTabs().isEmpty)
        #expect(harness.terminal.releasedTabIDs == [tab.id])
    }

    private func makeHarness(now: @escaping @MainActor () -> Date = Date.init) throws -> CommandServiceIntegrationHarness {
        let store = WorkspaceStore()
        let databasePath = temporaryDatabasePath()
        let persistence = try SQLiteWorkspaceMetadataStore(path: databasePath)
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
            service: service,
            databasePath: databasePath
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

    private func writeStaleDefaultShortcutID(_ shortcutID: UUID, databasePath: String) throws {
        var database: OpaquePointer?
        guard sqlite3_open_v2(databasePath, &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            throw SQLiteWorkspaceMetadataStoreError.openFailed("Unable to open stale default fixture database")
        }
        defer { sqlite3_close(database) }

        try execute(database, "PRAGMA foreign_keys = OFF")
        try execute(database, """
        UPDATE app_preferences
        SET default_session_shortcut_id = '\(shortcutID.uuidString)'
        WHERE id = 1
        """)
        try execute(database, "PRAGMA foreign_keys = ON")
    }

    private func execute(_ database: OpaquePointer?, _ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "Unknown SQLite error"
            sqlite3_free(error)
            throw SQLiteWorkspaceMetadataStoreError.stepFailed(message)
        }
    }
}

@MainActor
private struct CommandServiceIntegrationHarness {
    let store: WorkspaceStore
    let persistence: SQLiteWorkspaceMetadataStore
    let terminal: FakeIntegrationTerminalSurfaceManager
    let service: DefaultWorkspaceCommandService
    let databasePath: String
}

@MainActor
private final class FakeIntegrationTerminalSurfaceManager: WorkspaceTerminalSurfaceManaging {
    private(set) var createdTabs: [WorkspaceTab] = []
    private(set) var closeRequests: [GhosttySurfaceHandle] = []
    private(set) var focusedTabIDs: [UUID] = []
    private(set) var resizedTabIDs: [UUID] = []
    private(set) var releasedTabIDs: [UUID] = []
    var surfaceCreationError: Error?
    var canCloseResult = true
    var exitedTabIDs: Set<UUID> = []
    private var surfacesByTabID: [UUID: GhosttySurfaceHandle] = [:]

    func createSurface(for tab: WorkspaceTab) async throws -> GhosttySurfaceHandle {
        createdTabs.append(tab)
        if let surfaceCreationError {
            throw surfaceCreationError
        }
        let surface = GhosttySurfaceHandle()
        surfacesByTabID[tab.id] = surface
        return surface
    }

    func surface(for tabID: UUID) -> GhosttySurfaceHandle? {
        surfacesByTabID[tabID]
    }

    func canClose(surface: GhosttySurfaceHandle) async -> Bool {
        closeRequests.append(surface)
        return canCloseResult
    }

    func focus(tabID: UUID) {
        focusedTabIDs.append(tabID)
    }

    func resize(tabID: UUID, columns: Int, rows: Int) {
        resizedTabIDs.append(tabID)
    }

    func hasExited(tabID: UUID) async -> Bool {
        exitedTabIDs.contains(tabID)
    }

    func releaseSurface(for tabID: UUID) {
        releasedTabIDs.append(tabID)
        surfacesByTabID[tabID] = nil
    }
}
