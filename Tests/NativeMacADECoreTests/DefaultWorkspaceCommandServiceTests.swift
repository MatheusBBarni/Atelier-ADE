import Foundation
import Testing
@testable import NativeMacADECore

// Suite: Default workspace command service unit behavior
// Invariant: command-service mutations keep project, session, tab, and selection state coherent.
// Boundary IN: DefaultWorkspaceCommandService with in-memory persistence and a fake terminal surface manager.
// Boundary OUT: SQLite persistence and live Ghostty surfaces, covered by integration tests.
@Suite(.serialized)
@MainActor
struct DefaultWorkspaceCommandServiceTests {
    @Test
    func openingNewProjectAddsProjectAndSelectsIt() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()

        let project = try await harness.service.openProject(path: projectPath)
        let snapshot = try await harness.persistence.loadRestoreSnapshot()

        #expect(harness.store.projects == [project])
        #expect(harness.store.selectedProjectID == project.id)
        #expect(harness.store.selectedProject == project)
        #expect(try await harness.persistence.loadProjects() == [project])
        #expect(snapshot?.selectedProjectID == project.id)
    }

    @Test
    func openingAlreadyKnownProjectReselectsExistingProjectInsteadOfDuplicatingIt() async throws {
        let harness = makeHarness()
        let firstProjectPath = try makeTemporaryProjectDirectory(named: "first-project")
        let secondProjectPath = try makeTemporaryProjectDirectory(named: "second-project")

        let firstOpen = try await harness.service.openProject(path: firstProjectPath)
        _ = try await harness.service.openProject(path: secondProjectPath)

        let reopened = try await harness.service.openProject(path: firstProjectPath)

        #expect(reopened.id == firstOpen.id)
        #expect(harness.store.projects.count == 2)
        #expect(harness.store.selectedProjectID == firstOpen.id)
    }

    @Test
    func creatingSessionAssignsDefaultTitleAndSelectsItsProject() async throws {
        let now = Date(timeIntervalSince1970: 1_717_393_500)
        let harness = makeHarness(now: { now })
        let projectPath = try makeTemporaryProjectDirectory()
        let project = try await harness.service.openProject(path: projectPath)

        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let firstTab = try #require(harness.store.tabs.first)

        #expect(session.projectID == project.id)
        #expect(session.title == WorkspaceSession.defaultTitle(for: now))
        #expect(session.isUserNamed == false)
        #expect(session.shortcutID == nil)
        #expect(firstTab.sessionID == session.id)
        #expect(firstTab.workingDirectory == project.path)
        #expect(firstTab.launchCommand == nil)
        #expect(firstTab.launchArgumentsJSON == nil)
        #expect(firstTab.ordinal == 0)
        #expect(harness.store.sessions.count == 1)
        #expect(harness.store.tabs.count == 1)
        #expect(harness.store.selectedProjectID == project.id)
        #expect(harness.store.selectedSessionID == session.id)
        #expect(harness.store.selectedTabID == firstTab.id)
    }

    @Test
    func creatingSessionWithShortcutStoresShortcutAndLaunchesFirstTab() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let project = try await harness.service.openProject(path: projectPath)
        let shortcut = SessionShortcut(
            label: "Codex Plan",
            launchCommand: "codex",
            launchArgumentsJSON: "[\"--model\",\"gpt-5.5\"]",
            secretRef: "keychain://native-mac-ade/codex",
            isBuiltIn: true
        )
        try await harness.persistence.save(shortcut: shortcut)

        let session = try await harness.service.createSession(projectID: project.id, shortcutID: shortcut.id)
        let tab = try #require(harness.store.tabs.first)

        #expect(session.shortcutID == shortcut.id)
        #expect(try await harness.persistence.loadSessions().first?.shortcutID == shortcut.id)
        #expect(try await harness.persistence.loadSessions().count == 1)
        #expect(try await harness.persistence.loadTabs().count == 1)
        #expect(tab.sessionID == session.id)
        #expect(tab.workingDirectory == project.path)
        #expect(tab.launchCommand == "codex")
        #expect(tab.launchArgumentsJSON == "[\"--model\",\"gpt-5.5\"]")
        #expect(harness.terminal.createdTabs == [tab])
        #expect(harness.service.logger.events.contains { event in
            event.name == "session_created" &&
            event.fields["shortcut_id"] == shortcut.id.uuidString &&
            event.fields["launch_profile_label"] == "Codex Plan" &&
            event.fields["launch_profile_source"] == "explicit"
        })
        #expect(harness.service.logger.events.contains { event in
            event.name == "tab_created" &&
            event.fields["launch_profile_label"] == "Codex Plan" &&
            event.fields["launch_profile_source"] == "explicit"
        })
    }

    @Test
    func creatingSessionWithoutExplicitShortcutUsesSavedDefaultProfile() async throws {
        let harness = makeHarness()
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
        let tab = try #require(harness.store.tabs.first)

        #expect(session.shortcutID == shortcut.id)
        #expect(tab.sessionID == session.id)
        #expect(tab.launchCommand == "claude")
        #expect(tab.launchArgumentsJSON == "[\"--continue\"]")
        #expect(harness.store.sessions.count == 1)
        #expect(harness.store.tabs.count == 1)
        #expect(harness.service.logger.events.contains { event in
            event.name == "session_created" &&
            event.fields["shortcut_id"] == shortcut.id.uuidString &&
            event.fields["launch_profile_source"] == "default"
        })
    }

    @Test
    func creatingSessionWithMissingExplicitShortcutDoesNotMutateWorkspace() async throws {
        let harness = makeHarness()
        let project = try await harness.service.openProject(path: makeTemporaryProjectDirectory())
        let sessionsBefore = try await harness.persistence.loadSessions()
        let tabsBefore = try await harness.persistence.loadTabs()
        let shortcutsBefore = try await harness.persistence.loadSessionShortcuts()
        let preferencesBefore = try await harness.persistence.loadAppPreferences()
        let snapshotBefore = try await harness.persistence.loadRestoreSnapshot()
        let missingShortcutID = UUID()

        await #expect(throws: WorkspaceCommandError.missingShortcut(missingShortcutID)) {
            _ = try await harness.service.createSession(projectID: project.id, shortcutID: missingShortcutID)
        }

        #expect(harness.store.sessions.isEmpty)
        #expect(harness.store.tabs.isEmpty)
        #expect(try await harness.persistence.loadSessions() == sessionsBefore)
        #expect(try await harness.persistence.loadTabs() == tabsBefore)
        #expect(try await harness.persistence.loadSessionShortcuts() == shortcutsBefore)
        #expect(try await harness.persistence.loadAppPreferences() == preferencesBefore)
        #expect(try await harness.persistence.loadRestoreSnapshot() == snapshotBefore)
    }

    @Test
    func creatingSessionWithStaleSavedDefaultFallsBackToPlainFirstTab() async throws {
        let harness = makeHarness()
        let project = try await harness.service.openProject(path: makeTemporaryProjectDirectory())
        let staleShortcutID = UUID()
        try await harness.persistence.save(appPreferences: AppPreferences(defaultSessionShortcutID: staleShortcutID))

        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let tab = try #require(harness.store.tabs.first)

        #expect(session.shortcutID == nil)
        #expect(tab.launchCommand == nil)
        #expect(tab.launchArgumentsJSON == nil)
        #expect(harness.store.sessions.count == 1)
        #expect(harness.store.tabs.count == 1)
        #expect(harness.service.logger.events.contains { event in
            event.name == "default_profile_resolution_failed" &&
            event.fields["shortcut_id"] == staleShortcutID.uuidString
        })
    }

    @Test
    func creatingSessionWithBuiltInShortcutPersistsShortcutBeforeSessionReference() async throws {
        let harness = makeHarness()
        let project = try await harness.service.openProject(path: makeTemporaryProjectDirectory())
        let builtInShortcut = try #require(SessionShortcut.builtInDefaults.first)

        let session = try await harness.service.createSession(projectID: project.id, shortcutID: builtInShortcut.id)
        let tab = try #require(harness.store.tabs.first)

        #expect(session.shortcutID == builtInShortcut.id)
        #expect(tab.launchCommand == builtInShortcut.launchCommand)
        #expect(try await harness.persistence.loadSessionShortcuts().contains(builtInShortcut))
        #expect(try await harness.persistence.loadSessions().first?.shortcutID == builtInShortcut.id)
    }

    @Test
    func availableSessionShortcutsSeedsBuiltInProfiles() async throws {
        let harness = makeHarness()

        let shortcuts = try await harness.service.availableSessionShortcuts()

        #expect(Set(shortcuts.map(\.id)) == Set(SessionShortcut.builtInDefaults.map(\.id)))
        #expect(try await harness.persistence.loadSessionShortcuts() == shortcuts)
    }

    @Test
    func creatingTabInShortcutSessionInheritsStoredLaunchIntent() async throws {
        let harness = makeHarness()
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

        #expect(tab.launchCommand == "claude")
        #expect(tab.launchArgumentsJSON == "[\"--continue\"]")
        #expect(harness.terminal.createdTabs.last == tab)
        #expect(harness.store.selectedTabID == tab.id)
        #expect(harness.service.logger.events.contains { event in
            event.name == "tab_created" &&
            event.fields["tab_id"] == tab.id.uuidString &&
            event.fields["launch_profile_label"] == "Claude Continue" &&
            event.fields["launch_profile_source"] == "session"
        })
    }

    @Test
    func creatingLaterTabUsesSessionShortcutInsteadOfCurrentDefaultPreference() async throws {
        let harness = makeHarness()
        let project = try await harness.service.openProject(path: makeTemporaryProjectDirectory())
        let originalShortcut = SessionShortcut(
            label: "Original",
            launchCommand: "codex",
            launchArgumentsJSON: "[\"exec\"]",
            isBuiltIn: true
        )
        let newDefaultShortcut = SessionShortcut(
            label: "New Default",
            launchCommand: "claude",
            launchArgumentsJSON: "[\"--continue\"]",
            isBuiltIn: true
        )
        try await harness.persistence.save(shortcut: originalShortcut)
        try await harness.persistence.save(shortcut: newDefaultShortcut)
        try await harness.persistence.save(appPreferences: AppPreferences(defaultSessionShortcutID: originalShortcut.id))
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        try await harness.persistence.save(appPreferences: AppPreferences(defaultSessionShortcutID: newDefaultShortcut.id))

        let laterTab = try await harness.service.createTab(sessionID: session.id)

        #expect(session.shortcutID == originalShortcut.id)
        #expect(laterTab.launchCommand == "codex")
        #expect(laterTab.launchArgumentsJSON == "[\"exec\"]")
    }

    @Test
    func creatingTabWithMissingStoredShortcutDoesNotCreateSurface() async throws {
        let missingShortcutID = UUID()
        let project = WorkspaceProject(path: "/tmp/native-mac-ade-missing-stored-shortcut", displayName: "missing-shortcut")
        let session = WorkspaceSession(projectID: project.id, title: "Missing shortcut", shortcutID: missingShortcutID)
        let store = WorkspaceStore(projects: [project], sessions: [session], tabs: [])
        let persistence = InMemoryWorkspacePersistenceStore(projects: [project], sessions: [session])
        let terminal = FakeTerminalSurfaceManager()
        let service = DefaultWorkspaceCommandService(
            store: store,
            persistenceStore: persistence,
            restoreCoordinator: RestoreCoordinator(persistenceStore: persistence),
            terminalSurfaceManager: terminal
        )

        await #expect(throws: WorkspaceCommandError.missingShortcut(missingShortcutID)) {
            _ = try await service.createTab(sessionID: session.id)
        }

        #expect(terminal.createdTabs.isEmpty)
        #expect(store.tabs.isEmpty)
    }

    @Test
    func shortcutLaunchMappingProducesExpectedGhosttyLaunchConfiguration() throws {
        let shortcut = SessionShortcut(
            label: "Claude",
            launchCommand: "claude",
            launchArgumentsJSON: "[\"--dangerously-skip-permissions\"]",
            isBuiltIn: true
        )
        let tab = WorkspaceTab(
            sessionID: UUID(),
            workingDirectory: "/Users/example/project",
            launchCommand: shortcut.launchCommand,
            launchArgumentsJSON: shortcut.launchArgumentsJSON,
            ordinal: 0
        )

        let configuration = GhosttyLaunchConfiguration(tab: tab)

        #expect(configuration.workingDirectory == "/Users/example/project")
        #expect(configuration.command == "claude")
        #expect(configuration.arguments == ["--dangerously-skip-permissions"])
        #expect(configuration.appearance == .nordDefault)
    }

    @Test
    func projectOpenStructuredLogUsesHashedPathAndRequiredFields() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()

        let project = try await harness.service.openProject(path: projectPath)
        let event = try #require(harness.service.logger.events.first { $0.name == "project_opened" })

        #expect(event.fields["project_id"] == project.id.uuidString)
        #expect(event.fields["hashed_path"] == WorkspacePrivacy.hashIdentifier(project.path))
        #expect(event.fields["hashed_path"] != project.path)
        #expect(event.fields.values.contains(project.path) == false)
        #expect(event.fields["reused_project"] == "false")
    }

    @Test
    func renamingSessionUpdatesTitleAndMarksItUserNamed() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)

        try await harness.service.renameSession(sessionID: session.id, title: "  Investigate parser  \n")

        #expect(harness.store.selectedSession?.title == "Investigate parser")
        #expect(harness.store.selectedSession?.isUserNamed == true)
    }

    @Test
    func renamingSessionPreservesProjectOwnershipAndRecencyOrdering() async throws {
        let clock = DateSequence([
            Date(timeIntervalSince1970: 10),
            Date(timeIntervalSince1970: 11),
            Date(timeIntervalSince1970: 20),
            Date(timeIntervalSince1970: 21),
            Date(timeIntervalSince1970: 30),
            Date(timeIntervalSince1970: 31),
            Date(timeIntervalSince1970: 40),
            Date(timeIntervalSince1970: 41),
            Date(timeIntervalSince1970: 50),
            Date(timeIntervalSince1970: 51),
            Date(timeIntervalSince1970: 60),
            Date(timeIntervalSince1970: 61)
        ])
        let harness = makeHarness(now: clock.next)
        let firstProject = try await harness.service.openProject(path: makeTemporaryProjectDirectory(named: "first"))
        let secondProject = try await harness.service.openProject(path: makeTemporaryProjectDirectory(named: "second"))
        let olderFirstSession = try await harness.service.createSession(projectID: firstProject.id, shortcutID: nil)
        let newerFirstSession = try await harness.service.createSession(projectID: firstProject.id, shortcutID: nil)
        let secondSession = try await harness.service.createSession(projectID: secondProject.id, shortcutID: nil)

        try await harness.service.renameSession(sessionID: olderFirstSession.id, title: "Renamed first")
        let renamedSession = try #require(harness.store.sessions.first { $0.id == olderFirstSession.id })

        #expect(renamedSession.projectID == firstProject.id)
        #expect(harness.store.selectedProjectID == secondProject.id)
        #expect(harness.store.sessionsForSelectedProject.map(\.id) == [secondSession.id])

        harness.store.selectProject(id: firstProject.id)

        #expect(harness.store.sessionsForSelectedProject.map(\.id) == [newerFirstSession.id, olderFirstSession.id])
        #expect(try await harness.persistence.loadSessions().first?.id == secondSession.id)
    }

    @Test
    func creatingTabInheritsProjectSessionContextAndUpdatesSelection() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let firstTab = try #require(harness.store.tabs.first)

        let tab = try await harness.service.createTab(sessionID: session.id)

        #expect(tab.sessionID == session.id)
        #expect(tab.workingDirectory == project.path)
        #expect(tab.ordinal == 1)
        #expect(harness.store.selectedProjectID == project.id)
        #expect(harness.store.selectedSessionID == session.id)
        #expect(harness.store.selectedTabID == tab.id)
        #expect(harness.terminal.createdTabs == [firstTab, tab])
        #expect(harness.service.metrics.terminalSurfaceCreationCount == 2)
    }

    @Test
    func creatingTabReleasesSurfaceWhenPersistenceFails() async throws {
        let project = WorkspaceProject(path: "/tmp/native-mac-ade-persist-fail", displayName: "persist-fail")
        let session = WorkspaceSession(projectID: project.id, title: "Persistence failure")
        let store = WorkspaceStore()
        store.upsertProject(project)
        store.upsertSession(session)
        let persistence = TabSaveFailingPersistenceStore(project: project, session: session)
        let terminal = FakeTerminalSurfaceManager()
        let service = DefaultWorkspaceCommandService(
            store: store,
            persistenceStore: persistence,
            restoreCoordinator: RestoreCoordinator(persistenceStore: persistence),
            terminalSurfaceManager: terminal
        )

        await #expect(throws: WorkspaceCommandError.persistenceFailed("tab save failed")) {
            _ = try await service.createTab(sessionID: session.id)
        }

        let createdTab = try #require(terminal.createdTabs.first)
        #expect(terminal.releasedTabIDs == [createdTab.id])
        #expect(store.tabs.isEmpty)
    }

    @Test
    func creatingSessionReleasesFirstTabSurfaceWhenPersistenceFails() async throws {
        let project = WorkspaceProject(path: "/tmp/native-mac-ade-session-persist-fail", displayName: "session-persist-fail")
        let store = WorkspaceStore(projects: [project])
        let persistence = SessionFirstTabSaveFailingPersistenceStore(project: project)
        let terminal = FakeTerminalSurfaceManager()
        let service = DefaultWorkspaceCommandService(
            store: store,
            persistenceStore: persistence,
            restoreCoordinator: RestoreCoordinator(persistenceStore: persistence),
            terminalSurfaceManager: terminal
        )

        await #expect(throws: WorkspaceCommandError.persistenceFailed("session first tab save failed")) {
            _ = try await service.createSession(projectID: project.id, shortcutID: nil)
        }

        let createdTab = try #require(terminal.createdTabs.first)
        #expect(terminal.releasedTabIDs == [createdTab.id])
        #expect(store.sessions.isEmpty)
        #expect(store.tabs.isEmpty)
        #expect(try await persistence.loadSessions().isEmpty)
        #expect(try await persistence.loadTabs().isEmpty)
    }

    @Test
    func terminalProcessExitEmitsStructuredLocalEvent() async throws {
        let harness = makeHarness()
        let project = try await harness.service.openProject(path: makeTemporaryProjectDirectory())
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let tab = try await harness.service.createTab(sessionID: session.id)

        harness.service.recordTerminalProcessExit(tabID: tab.id, exitStatus: 0)

        let event = try #require(harness.service.logger.events.first { $0.name == "terminal_process_exited" })
        #expect(event.fields["tab_id"] == tab.id.uuidString)
        #expect(event.fields["session_id"] == session.id.uuidString)
        #expect(event.fields["exit_status"] == "0")
    }

    @Test
    func closingLiveTabHonorsConfirmQuitBeforeRemovingMetadata() async throws {
        let harness = makeHarness()
        let project = try await harness.service.openProject(path: makeTemporaryProjectDirectory())
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let tabsBefore = harness.store.tabs
        let tab = try await harness.service.createTab(sessionID: session.id)
        harness.terminal.canCloseResult = false

        await #expect(throws: WorkspaceCommandError.closeRejected(tab.id)) {
            try await harness.service.closeTab(tabID: tab.id, force: false)
        }

        #expect(harness.store.tabs == tabsBefore + [tab])
        #expect(harness.store.selectedTabID == tab.id)
        #expect(try await harness.persistence.loadTabs() == tabsBefore + [tab])
    }

    @Test
    func removingSessionForceClosesTabsAndClearsSelection() async throws {
        let harness = makeHarness()
        let project = try await harness.service.openProject(path: makeTemporaryProjectDirectory())
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let firstTab = try #require(harness.store.tabs.first)
        let tab = try await harness.service.createTab(sessionID: session.id)
        harness.terminal.canCloseResult = false

        try await harness.service.removeSession(id: session.id)

        #expect(harness.store.sessions.isEmpty)
        #expect(harness.store.tabs.isEmpty)
        #expect(harness.store.selectedSessionID == nil)
        #expect(harness.store.selectedTabID == nil)
        #expect(Set(harness.terminal.releasedTabIDs) == Set([firstTab.id, tab.id]))
    }

    @Test
    func selectingTabKeepsSelectedSessionContextStable() async throws {
        let harness = makeHarness()
        let project = try await harness.service.openProject(path: makeTemporaryProjectDirectory())
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let initialTab = try #require(harness.store.tabs.first)
        let firstTab = try await harness.service.createTab(sessionID: session.id)
        let secondTab = try await harness.service.createTab(sessionID: session.id)

        try await harness.service.selectTab(id: firstTab.id)

        #expect(harness.store.selectedProjectID == project.id)
        #expect(harness.store.selectedSessionID == session.id)
        #expect(harness.store.selectedTabID == firstTab.id)
        #expect(harness.store.tabsForSelectedSession.map(\.id) == [initialTab.id, firstTab.id, secondTab.id])
    }

    @Test
    func selectingTabPersistsProjectSessionAndTabRecency() async throws {
        let activatedAt = Date(timeIntervalSince1970: 2_000)
        let project = WorkspaceProject(
            path: "/tmp/native-mac-ade-recency",
            displayName: "recency",
            createdAt: Date(timeIntervalSince1970: 10),
            lastOpenedAt: Date(timeIntervalSince1970: 20)
        )
        let session = WorkspaceSession(
            projectID: project.id,
            title: "Recency",
            createdAt: Date(timeIntervalSince1970: 30),
            lastActivatedAt: Date(timeIntervalSince1970: 40)
        )
        let tab = WorkspaceTab(
            sessionID: session.id,
            workingDirectory: project.path,
            ordinal: 0,
            createdAt: Date(timeIntervalSince1970: 50),
            lastActivatedAt: Date(timeIntervalSince1970: 60)
        )
        let store = WorkspaceStore(projects: [project], sessions: [session], tabs: [tab])
        let persistence = InMemoryWorkspacePersistenceStore(projects: [project], sessions: [session], tabs: [tab])
        let terminal = FakeTerminalSurfaceManager()
        let service = DefaultWorkspaceCommandService(
            store: store,
            persistenceStore: persistence,
            restoreCoordinator: RestoreCoordinator(persistenceStore: persistence),
            terminalSurfaceManager: terminal,
            now: { activatedAt }
        )

        try await service.selectTab(id: tab.id)

        #expect(store.selectedProjectID == project.id)
        #expect(store.selectedSessionID == session.id)
        #expect(store.selectedTabID == tab.id)
        #expect(store.selectedProject?.lastOpenedAt == activatedAt)
        #expect(store.selectedSession?.lastActivatedAt == activatedAt)
        #expect(store.selectedTab?.lastActivatedAt == activatedAt)
        #expect(try await persistence.loadProjects().first?.lastOpenedAt == activatedAt)
        #expect(try await persistence.loadSessions().first?.lastActivatedAt == activatedAt)
        #expect(try await persistence.loadTabs().first?.lastActivatedAt == activatedAt)
        #expect(try await persistence.loadRestoreSnapshot()?.selectedTabID == tab.id)
    }

    @Test
    func selectingTabDoesNotMutateStoreWhenActivationPersistenceFails() async throws {
        let project = WorkspaceProject(path: "/tmp/native-mac-ade-activation-fail", displayName: "activation-fail")
        let session = WorkspaceSession(projectID: project.id, title: "Activation failure")
        let tab = WorkspaceTab(sessionID: session.id, workingDirectory: project.path, ordinal: 0)
        let store = WorkspaceStore(projects: [project], sessions: [session], tabs: [tab])
        let persistence = ActivationFailingPersistenceStore(project: project, session: session, tab: tab)
        let terminal = FakeTerminalSurfaceManager()
        let service = DefaultWorkspaceCommandService(
            store: store,
            persistenceStore: persistence,
            restoreCoordinator: RestoreCoordinator(persistenceStore: persistence),
            terminalSurfaceManager: terminal
        )

        await #expect(throws: WorkspaceCommandError.persistenceFailed("activation save failed")) {
            try await service.selectTab(id: tab.id)
        }

        #expect(store.selectedProjectID == nil)
        #expect(store.selectedSessionID == nil)
        #expect(store.selectedTabID == nil)
        #expect(store.projects == [project])
        #expect(store.sessions == [session])
        #expect(store.tabs == [tab])
    }

    private func makeHarness(now: @escaping @MainActor () -> Date = Date.init) -> CommandServiceHarness<InMemoryWorkspacePersistenceStore> {
        let store = WorkspaceStore()
        let persistence = InMemoryWorkspacePersistenceStore()
        let terminal = FakeTerminalSurfaceManager()
        let coordinator = RestoreCoordinator(persistenceStore: persistence)
        let service = DefaultWorkspaceCommandService(
            store: store,
            persistenceStore: persistence,
            restoreCoordinator: coordinator,
            terminalSurfaceManager: terminal,
            now: now
        )

        return CommandServiceHarness(
            store: store,
            persistence: persistence,
            terminal: terminal,
            service: service
        )
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
private struct CommandServiceHarness<Persistence: WorkspacePersistenceStore> {
    let store: WorkspaceStore
    let persistence: Persistence
    let terminal: FakeTerminalSurfaceManager
    let service: DefaultWorkspaceCommandService
}

@MainActor
private final class FakeTerminalSurfaceManager: WorkspaceTerminalSurfaceManaging {
    private(set) var createdTabs: [WorkspaceTab] = []
    private(set) var focusedTabIDs: [UUID] = []
    private(set) var resizedTabIDs: [UUID] = []
    private(set) var releasedTabIDs: [UUID] = []
    var surfaceCreationError: Error?
    var surfacesByTabID: [UUID: GhosttySurfaceHandle] = [:]
    var canCloseResult = true
    var exitedTabIDs: Set<UUID> = []

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
        canCloseResult
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

@MainActor
private final class DateSequence {
    private var dates: [Date]
    private var fallbackTimeInterval: TimeInterval

    init(_ dates: [Date]) {
        self.dates = dates
        fallbackTimeInterval = dates.last?.timeIntervalSince1970 ?? 998
    }

    func next() -> Date {
        guard dates.isEmpty else { return dates.removeFirst() }
        fallbackTimeInterval += 1
        return Date(timeIntervalSince1970: fallbackTimeInterval)
    }
}

private actor TabSaveFailingPersistenceStore: WorkspacePersistenceStore {
    let project: WorkspaceProject
    let session: WorkspaceSession

    init(project: WorkspaceProject, session: WorkspaceSession) {
        self.project = project
        self.session = session
    }

    func loadProjects() async throws -> [WorkspaceProject] { [project] }
    func loadSessions() async throws -> [WorkspaceSession] { [session] }
    func loadTabs() async throws -> [WorkspaceTab] { [] }
    func loadSessionShortcuts() async throws -> [SessionShortcut] { [] }
    func loadAppPreferences() async throws -> AppPreferences { .defaults }
    func loadRestoreSnapshot() async throws -> RestoreSnapshot? { nil }
    func save(project: WorkspaceProject) async throws {}
    func save(session: WorkspaceSession) async throws {}
    func save(tab: WorkspaceTab) async throws { throw Failure.tabSave }
    func save(session: WorkspaceSession, firstTab: WorkspaceTab) async throws { throw Failure.tabSave }
    func saveActivation(project: WorkspaceProject?, session: WorkspaceSession?, tab: WorkspaceTab?, snapshot: RestoreSnapshot) async throws {}
    func save(shortcut: SessionShortcut) async throws {}
    func save(appPreferences: AppPreferences) async throws {}
    func save(snapshot: RestoreSnapshot) async throws {}
    func deleteProject(id: UUID) async throws {}
    func deleteSession(id: UUID) async throws {}
    func deleteTab(id: UUID) async throws {}
    func deleteShortcut(id: UUID) async throws {}

    enum Failure: Error, CustomStringConvertible {
        case tabSave

        var description: String { "tab save failed" }
    }
}

private actor SessionFirstTabSaveFailingPersistenceStore: WorkspacePersistenceStore {
    let project: WorkspaceProject

    init(project: WorkspaceProject) {
        self.project = project
    }

    func loadProjects() async throws -> [WorkspaceProject] { [project] }
    func loadSessions() async throws -> [WorkspaceSession] { [] }
    func loadTabs() async throws -> [WorkspaceTab] { [] }
    func loadSessionShortcuts() async throws -> [SessionShortcut] { [] }
    func loadAppPreferences() async throws -> AppPreferences { .defaults }
    func loadRestoreSnapshot() async throws -> RestoreSnapshot? { nil }
    func save(project: WorkspaceProject) async throws {}
    func save(session: WorkspaceSession) async throws {}
    func save(tab: WorkspaceTab) async throws {}
    func save(session: WorkspaceSession, firstTab: WorkspaceTab) async throws { throw Failure.sessionFirstTabSave }
    func saveActivation(project: WorkspaceProject?, session: WorkspaceSession?, tab: WorkspaceTab?, snapshot: RestoreSnapshot) async throws {}
    func save(shortcut: SessionShortcut) async throws {}
    func save(appPreferences: AppPreferences) async throws {}
    func save(snapshot: RestoreSnapshot) async throws {}
    func deleteProject(id: UUID) async throws {}
    func deleteSession(id: UUID) async throws {}
    func deleteTab(id: UUID) async throws {}
    func deleteShortcut(id: UUID) async throws {}

    enum Failure: Error, CustomStringConvertible {
        case sessionFirstTabSave

        var description: String { "session first tab save failed" }
    }
}

private actor ActivationFailingPersistenceStore: WorkspacePersistenceStore {
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
    func loadRestoreSnapshot() async throws -> RestoreSnapshot? { nil }
    func save(project: WorkspaceProject) async throws {}
    func save(session: WorkspaceSession) async throws {}
    func save(tab: WorkspaceTab) async throws {}
    func save(session: WorkspaceSession, firstTab: WorkspaceTab) async throws {}
    func saveActivation(project: WorkspaceProject?, session: WorkspaceSession?, tab: WorkspaceTab?, snapshot: RestoreSnapshot) async throws {
        throw Failure.activationSave
    }
    func save(shortcut: SessionShortcut) async throws {}
    func save(appPreferences: AppPreferences) async throws {}
    func save(snapshot: RestoreSnapshot) async throws {}
    func deleteProject(id: UUID) async throws {}
    func deleteSession(id: UUID) async throws {}
    func deleteTab(id: UUID) async throws {}
    func deleteShortcut(id: UUID) async throws {}

    enum Failure: Error, CustomStringConvertible {
        case activationSave

        var description: String { "activation save failed" }
    }
}
