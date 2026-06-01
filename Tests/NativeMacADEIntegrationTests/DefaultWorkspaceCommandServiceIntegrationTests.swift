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
        #expect(launchedTab.shortcutID == shortcut.id)
        #expect(launchedTab.launchCommand == "codex")
        #expect(launchedTab.launchArgumentsJSON == "[\"resume\"]")
        #expect(persistedTabs.map(\.id) == [launchedTab.id])
        #expect(persistedTabs.first?.shortcutID == shortcut.id)
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
        #expect(launchedTab.shortcutID == shortcut.id)
        #expect(persistedTabs.first?.shortcutID == shortcut.id)
        #expect(launchedTab.launchCommand == "claude")
        #expect(launchedTab.launchArgumentsJSON == "[\"--continue\"]")
        #expect(harness.store.selectedTabID == launchedTab.id)
    }

    @Test
    func clearingOrDeletingCurrentDefaultProfileFallsBackToPlainShell() async throws {
        let harness = try makeHarness()
        let project = try await harness.service.openProject(path: makeTemporaryProjectDirectory())
        let profile = try await harness.service.saveSessionShortcut(SessionShortcut(
            label: "Default Local",
            launchCommand: "local-agent",
            launchArgumentsJSON: "[\"run\"]"
        ))
        try await harness.service.saveAppPreferences(AppPreferences(defaultSessionShortcutID: profile.id))

        let defaultSession = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        try await harness.service.saveAppPreferences(AppPreferences(defaultSessionShortcutID: nil))
        let clearedSession = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        try await harness.service.saveAppPreferences(AppPreferences(defaultSessionShortcutID: profile.id))
        try await harness.service.deleteSessionShortcut(id: profile.id)
        let deletedDefaultSession = try await harness.service.createSession(projectID: project.id, shortcutID: nil)

        let defaultTab = try #require(harness.terminal.createdTabs.first { $0.sessionID == defaultSession.id })
        let clearedTab = try #require(harness.terminal.createdTabs.first { $0.sessionID == clearedSession.id })
        let deletedDefaultTab = try #require(harness.terminal.createdTabs.first { $0.sessionID == deletedDefaultSession.id })

        #expect(defaultSession.shortcutID == profile.id)
        #expect(defaultTab.shortcutID == profile.id)
        #expect(defaultTab.launchCommand == "local-agent")
        #expect(defaultTab.launchArgumentsJSON == "[\"run\"]")
        #expect(clearedSession.shortcutID == nil)
        #expect(clearedTab.shortcutID == nil)
        #expect(clearedTab.launchCommand == nil)
        #expect(clearedTab.launchArgumentsJSON == nil)
        #expect(try await harness.persistence.loadAppPreferences().defaultSessionShortcutID == nil)
        #expect(deletedDefaultSession.shortcutID == nil)
        #expect(deletedDefaultTab.shortcutID == nil)
        #expect(deletedDefaultTab.launchCommand == nil)
        #expect(deletedDefaultTab.launchArgumentsJSON == nil)
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
    func systemThemeSelectionRoundTripsThroughSQLiteCommandService() async throws {
        let harness = try makeHarness()

        try await harness.service.saveAppPreferences(AppPreferences(
            themeID: AppTheme.systemSelectionID,
            terminalFontSize: 15
        ))

        let reloadedStore = WorkspaceStore()
        let reloadedService = DefaultWorkspaceCommandService(
            store: reloadedStore,
            persistenceStore: harness.persistence,
            restoreCoordinator: RestoreCoordinator(persistenceStore: harness.persistence),
            terminalSurfaceManager: FakeIntegrationTerminalSurfaceManager()
        )
        let loadedPreferences = try await reloadedService.loadAppPreferences()

        #expect(loadedPreferences.themeID == AppTheme.systemSelectionID)
        #expect(loadedPreferences.terminalFontSize == 15)
        #expect(try await harness.persistence.loadAppPreferences().themeID == AppTheme.systemSelectionID)
        #expect(reloadedStore.appPreferences.themeID == AppTheme.systemSelectionID)
    }

    @Test
    func loadedKeybindingOverridesResolveAtRuntimeAndResetToDefaults() async throws {
        let harness = try makeHarness()
        let overrides = managedKeybindingOverrides()

        try await harness.service.saveAppPreferences(AppPreferences(keybindings: overrides))

        let loadedPreferences = try await harness.service.loadAppPreferences()
        for commandID in AppCommandRegistry.managedCommandIDs {
            #expect(AppCommandRegistry.resolvedKeybinding(for: commandID, preferences: loadedPreferences) == overrides[commandID])
        }

        var resetPreferences = loadedPreferences
        resetPreferences.keybindings = [:]
        try await harness.service.saveAppPreferences(resetPreferences)
        let reloadedPreferences = try await harness.service.loadAppPreferences()

        #expect(reloadedPreferences.keybindings.isEmpty)
        for commandID in AppCommandRegistry.managedCommandIDs {
            #expect(AppCommandRegistry.resolvedKeybinding(for: commandID, preferences: reloadedPreferences) == AppCommandRegistry.defaultKeybinding(for: commandID))
        }
    }

    @Test
    func loadingSavedConcreteThemesUpdatesObservedStoreActiveTheme() async throws {
        let harness = try makeHarness()
        var observedSchemes: Set<ThemeColorScheme> = []

        for theme in AppTheme.catalog {
            try await harness.persistence.save(appPreferences: AppPreferences(themeID: theme.id))

            let loadedPreferences = try await harness.service.loadAppPreferences()

            #expect(loadedPreferences.themeID == theme.id)
            #expect(harness.store.effectiveTheme(systemScheme: .dark) == theme)
            observedSchemes.insert(harness.store.effectiveTheme(systemScheme: .dark).colorScheme)
        }

        #expect(observedSchemes.contains(.dark))
        #expect(observedSchemes.contains(.light))
    }

    @Test
    func startupLoadRepairsStaleThemeToSystemWithoutMutatingOtherPreferenceFields() async throws {
        let now = Date(timeIntervalSince1970: 1_717_394_000)
        let harness = try makeHarness(now: { now })
        let shortcut = SessionShortcut(
            label: "Valid Default",
            launchCommand: "codex",
            launchArgumentsJSON: "[]",
            isBuiltIn: true
        )
        let override = KeybindingOverride(
            commandID: .openSettings,
            keyEquivalent: ",",
            modifiers: [.command, .shift]
        )
        try await harness.persistence.save(shortcut: shortcut)
        try await harness.persistence.save(appPreferences: AppPreferences(
            themeID: "retired-theme",
            defaultSessionShortcutID: shortcut.id,
            terminalFontSize: 17,
            keybindings: [.openSettings: override],
            updatedAt: Date(timeIntervalSince1970: 400)
        ))

        let startupResult = await AppShellStartupCoordinator.run(commandService: harness.service, store: harness.store)
        let persistedPreferences = try await harness.persistence.loadAppPreferences()

        #expect(startupResult.preferenceLoadErrorDescription == nil)
        #expect(startupResult.restoreErrorDescription == nil)
        #expect(harness.store.appPreferences.themeID == AppTheme.systemSelectionID)
        #expect(harness.store.appPreferences.defaultSessionShortcutID == shortcut.id)
        #expect(harness.store.appPreferences.terminalFontSize == 17)
        #expect(harness.store.appPreferences.keybindings == [.openSettings: override])
        #expect(harness.store.appPreferences.updatedAt == now)
        #expect(persistedPreferences == harness.store.appPreferences)
        #expect(harness.service.metrics.themeRepairCount == 1)
        #expect(harness.service.logger.events.contains { event in
            event.name == "theme_repaired" &&
                event.fields["invalid_theme_id"] == "retired-theme" &&
                event.fields["fallback_theme_id"] == AppTheme.systemSelectionID
        })
    }

    @Test
    func startupWithUnknownThemeAndStaleDefaultProfileRestoresExistingTabsWithoutDuplication() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let project = WorkspaceProject(path: projectPath, displayName: "Startup")
        let session = WorkspaceSession(projectID: project.id, title: "Restored")
        let tab = WorkspaceTab(sessionID: session.id, workingDirectory: projectPath, ordinal: 0)
        let staleShortcutID = UUID()

        try await harness.persistence.save(project: project)
        try await harness.persistence.save(session: session)
        try await harness.persistence.save(tab: tab)
        try await harness.persistence.save(snapshot: RestoreSnapshot(
            selectedProjectID: project.id,
            selectedSessionID: session.id,
            selectedTabID: tab.id,
            openTabIDs: [tab.id]
        ))
        try await harness.persistence.save(appPreferences: AppPreferences(themeID: "missing-theme"))
        try writeStaleDefaultShortcutID(staleShortcutID, databasePath: harness.databasePath)

        let startupResult = await AppShellStartupCoordinator.run(commandService: harness.service, store: harness.store)

        #expect(startupResult.preferenceLoadErrorDescription == nil)
        #expect(startupResult.restoreErrorDescription == nil)
        #expect(harness.store.appPreferences.themeID == AppPreferences.defaultThemeID)
        #expect(harness.store.appPreferences.defaultSessionShortcutID == nil)
        #expect(harness.store.tabs.map(\.id) == [tab.id])
        #expect(harness.terminal.createdTabs.map(\.id) == [tab.id])
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
        #expect(launchedTabs.first { $0.sessionID == explicitSession.id }?.shortcutID == explicitShortcut.id)
        #expect(launchedTabs.first { $0.sessionID == defaultSession.id }?.shortcutID == defaultShortcut.id)
        #expect(launchedTabs.first { $0.sessionID == plainSession.id }?.shortcutID == nil)
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
        #expect(tab.shortcutID == nil)
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

        #expect(tab.shortcutID == shortcut.id)
        #expect(tab.launchCommand == "claude")
        #expect(tab.launchArgumentsJSON == "[\"--continue\"]")
        #expect(persistedTab.shortcutID == shortcut.id)
        #expect(persistedTab.launchCommand == "claude")
        #expect(persistedTab.launchArgumentsJSON == "[\"--continue\"]")
    }

    @Test
    func creatingTerminalTabUsesPersistedMaxOrdinalWhenStoreHasRestoredSubset() async throws {
        let harness = try makeHarness()
        let project = try await harness.service.openProject(path: makeTemporaryProjectDirectory())
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let initialTab = try #require(harness.store.tabs.first)
        let persistedOnlyTab = WorkspaceTab(
            sessionID: session.id,
            workingDirectory: project.path,
            ordinal: 1
        )
        try await harness.persistence.save(tab: persistedOnlyTab)

        let createdTab = try await harness.service.createTab(sessionID: session.id)
        let persistedTabs = try await harness.persistence.loadTabs()

        #expect(createdTab.ordinal == 2)
        #expect(harness.store.tabsForSelectedSession.map(\.id) == [initialTab.id, createdTab.id])
        #expect(persistedTabs.map(\.id) == [initialTab.id, persistedOnlyTab.id, createdTab.id])
        #expect(persistedTabs.map(\.ordinal) == [0, 1, 2])
    }

    @Test
    func savingThemePreferenceDoesNotMutatePersistedSessionOrTabLaunchIntent() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let project = try await harness.service.openProject(path: projectPath)
        let shortcut = SessionShortcut(
            label: "Codex Exec",
            launchCommand: "codex",
            launchArgumentsJSON: "[\"exec\"]",
            isBuiltIn: true
        )
        try await harness.persistence.save(shortcut: shortcut)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: shortcut.id)
        let originalSession = try #require(try await harness.persistence.loadSessions().first { $0.id == session.id })
        let originalTab = try #require(try await harness.persistence.loadTabs().first { $0.sessionID == session.id })

        try await harness.service.saveAppPreferences(AppPreferences(themeID: "catppuccin"))

        let updatedSession = try #require(try await harness.persistence.loadSessions().first { $0.id == session.id })
        let updatedTab = try #require(try await harness.persistence.loadTabs().first { $0.id == originalTab.id })

        #expect(updatedSession.shortcutID == originalSession.shortcutID)
        #expect(updatedSession.title == originalSession.title)
        #expect(updatedTab.shortcutID == originalTab.shortcutID)
        #expect(updatedTab.launchCommand == originalTab.launchCommand)
        #expect(updatedTab.launchArgumentsJSON == originalTab.launchArgumentsJSON)
        #expect(updatedTab.workingDirectory == originalTab.workingDirectory)
    }

    @Test
    func failedSettingsSaveKeepsPriorPreferencesAndDoesNotBlockLaterSuccessfulSave() async throws {
        let harness = try makeHarness()
        let originalOverride = KeybindingOverride(commandID: .openSettings, keyEquivalent: ",", modifiers: [.command, .shift])
        let originalPreferences = AppPreferences(themeID: "dracula", keybindings: [.openSettings: originalOverride])
        try await harness.service.saveAppPreferences(originalPreferences)
        harness.service.logger.clear()

        await #expect(throws: WorkspaceCommandError.settingsValidationFailed(.duplicateManagedKeybinding(
            commandID: .nextTab,
            conflictingCommandID: .previousTab
        ))) {
            try await harness.service.saveAppPreferences(AppPreferences(
                themeID: "catppuccin",
                keybindings: [
                    .nextTab: KeybindingOverride(commandID: .nextTab, keyEquivalent: "[")
                ]
            ))
        }

        let preferencesAfterFailure = try await harness.persistence.loadAppPreferences()
        #expect(preferencesAfterFailure.themeID == "dracula")
        #expect(preferencesAfterFailure.keybindings == [.openSettings: originalOverride])
        #expect(harness.store.appPreferences.themeID == "dracula")
        #expect(harness.store.appPreferences.keybindings == [.openSettings: originalOverride])
        #expect(harness.service.metrics.settingsSaveFailureCount == 1)
        #expect(harness.service.logger.events.contains { $0.name == "settings_save_failed" })

        let laterPreferences = AppPreferences(themeID: "catppuccin", keybindings: [.previousTab: KeybindingOverride(commandID: .previousTab, keyEquivalent: "1", modifiers: [.command, .option])])
        try await harness.service.saveAppPreferences(laterPreferences)

        #expect(try await harness.persistence.loadAppPreferences().themeID == "catppuccin")
        #expect(try await harness.persistence.loadAppPreferences().keybindings == laterPreferences.keybindings)
        #expect(harness.store.appPreferences.themeID == "catppuccin")
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
    func resettingCustomizedBuiltInChangesFutureBootstrapAndRestoredTabsKeepLaunchIntent() async throws {
        let harness = try makeHarness()
        let project = try await harness.service.openProject(path: makeTemporaryProjectDirectory())
        let codex = try #require(SessionShortcut.builtInDefaults.first { $0.label == "Codex" })
        var customizedCodex = codex
        customizedCodex.launchArgumentsJSON = "[\"exec\"]"

        let savedCodex = try await harness.service.saveSessionShortcut(customizedCodex)
        try await harness.service.saveAppPreferences(AppPreferences(defaultSessionShortcutID: codex.id))
        let customizedSession = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let customizedTab = try #require(harness.terminal.createdTabs.first { $0.sessionID == customizedSession.id })

        let resetCodex = try await harness.service.resetBuiltInSessionShortcut(id: codex.id)
        let resetSession = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let resetTab = try #require(harness.terminal.createdTabs.first { $0.sessionID == resetSession.id })

        let restoredStore = WorkspaceStore()
        let restoredTerminal = FakeIntegrationTerminalSurfaceManager()
        let restoredService = DefaultWorkspaceCommandService(
            store: restoredStore,
            persistenceStore: harness.persistence,
            restoreCoordinator: RestoreCoordinator(persistenceStore: harness.persistence),
            terminalSurfaceManager: restoredTerminal
        )
        try await restoredService.restoreWorkspace()
        let restoredCustomizedTab = try #require(restoredTerminal.createdTabs.first { $0.id == customizedTab.id })

        #expect(savedCodex.hasUserOverride)
        #expect(customizedSession.shortcutID == codex.id)
        #expect(customizedTab.launchCommand == "codex")
        #expect(customizedTab.launchArgumentsJSON == "[\"exec\"]")
        #expect(resetCodex == codex)
        #expect(resetSession.shortcutID == codex.id)
        #expect(resetTab.launchCommand == "codex")
        #expect(resetTab.launchArgumentsJSON == "[]")
        #expect(restoredCustomizedTab.launchCommand == "codex")
        #expect(restoredCustomizedTab.launchArgumentsJSON == "[\"exec\"]")
        #expect(restoredStore.tabs.first { $0.id == customizedTab.id }?.launchArgumentsJSON == "[\"exec\"]")
    }

    @Test
    func mixedFileTabMetadataPersistsThroughSelectionRestoreAndCloseSnapshotUpdates() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let terminalTab = try #require(harness.store.tabs.first)

        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)
        try await harness.service.selectTab(id: terminalTab.id)
        let snapshotAfterSelection = try #require(try await harness.persistence.loadRestoreSnapshot())
        let persistedFileTab = try #require(try await harness.persistence.loadTabs().first { $0.id == fileTab.id })

        #expect(persistedFileTab.kind == .file)
        #expect(persistedFileTab.fileReference?.path == fileURL.path)
        #expect(snapshotAfterSelection.selectedTabID == terminalTab.id)
        #expect(snapshotAfterSelection.tabOrder == [terminalTab.id, fileTab.id])
        #expect(harness.terminal.createdTabs.map(\.id) == [terminalTab.id])

        let restoredStore = WorkspaceStore()
        let restoredTerminal = FakeIntegrationTerminalSurfaceManager()
        let restoredService = DefaultWorkspaceCommandService(
            store: restoredStore,
            persistenceStore: harness.persistence,
            restoreCoordinator: RestoreCoordinator(persistenceStore: harness.persistence),
            terminalSurfaceManager: restoredTerminal
        )
        try await restoredService.restoreWorkspace()

        #expect(restoredStore.tabsForSelectedSession.map(\.id) == [terminalTab.id, fileTab.id])
        #expect(restoredStore.tabsForSelectedSession.map(\.kind) == [.terminal, .file])
        #expect(restoredStore.selectedTabID == terminalTab.id)
        #expect(restoredTerminal.createdTabs.map(\.id) == [terminalTab.id])

        try await restoredService.closeTab(tabID: fileTab.id, force: false)
        let snapshotAfterClose = try #require(try await harness.persistence.loadRestoreSnapshot())

        #expect(try await harness.persistence.loadTabs().map(\.id) == [terminalTab.id])
        #expect(snapshotAfterClose.selectedTabID == terminalTab.id)
        #expect(snapshotAfterClose.tabOrder == [terminalTab.id])
        #expect(restoredTerminal.closeRequests.isEmpty)
        #expect(restoredTerminal.releasedTabIDs.isEmpty)
    }

    @Test
    func mixedTabReorderPersistsAndReloadsAfterRelaunch() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let firstTerminalTab = try #require(harness.store.tabs.first)
        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)
        let secondTerminalTab = try await harness.service.createTab(sessionID: session.id)

        try await harness.service.reorderTabs(
            sessionID: session.id,
            orderedVisibleTabIDs: [fileTab.id, secondTerminalTab.id, firstTerminalTab.id]
        )

        #expect(try await harness.persistence.loadTabs().map(\.id) == [fileTab.id, secondTerminalTab.id, firstTerminalTab.id])
        #expect(try await harness.persistence.loadTabs().map(\.ordinal) == [0, 1, 2])
        #expect(try await harness.persistence.loadRestoreSnapshot()?.tabOrder == [fileTab.id, secondTerminalTab.id, firstTerminalTab.id])

        let reloadedStore = WorkspaceStore()
        let reloadedTerminal = FakeIntegrationTerminalSurfaceManager()
        let reloadedService = DefaultWorkspaceCommandService(
            store: reloadedStore,
            persistenceStore: harness.persistence,
            restoreCoordinator: RestoreCoordinator(persistenceStore: harness.persistence),
            terminalSurfaceManager: reloadedTerminal
        )

        try await reloadedService.restoreWorkspace()

        #expect(reloadedStore.tabsForSelectedSession.map(\.id) == [fileTab.id, secondTerminalTab.id, firstTerminalTab.id])
        #expect(reloadedStore.tabsForSelectedSession.map(\.kind) == [.file, .terminal, .terminal])
        #expect(reloadedStore.selectedTabID == secondTerminalTab.id)
        #expect(reloadedTerminal.createdTabs.map(\.id) == [secondTerminalTab.id, firstTerminalTab.id])
    }

    @Test
    func reorderingAfterAddingFileTabRestoresSelectedTabAndVisibleOrder() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let initialTerminalTab = try #require(harness.store.tabs.first)
        let secondTerminalTab = try await harness.service.createTab(sessionID: session.id)
        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)

        try await harness.service.reorderTabs(
            sessionID: session.id,
            orderedVisibleTabIDs: [secondTerminalTab.id, fileTab.id, initialTerminalTab.id]
        )

        #expect(harness.store.selectedTabID == fileTab.id)
        #expect(harness.store.tabsForSelectedSession.map(\.id) == [secondTerminalTab.id, fileTab.id, initialTerminalTab.id])

        let reloadedStore = WorkspaceStore()
        let reloadedService = DefaultWorkspaceCommandService(
            store: reloadedStore,
            persistenceStore: harness.persistence,
            restoreCoordinator: RestoreCoordinator(persistenceStore: harness.persistence),
            terminalSurfaceManager: FakeIntegrationTerminalSurfaceManager()
        )

        try await reloadedService.restoreWorkspace()

        #expect(reloadedStore.selectedTabID == fileTab.id)
        #expect(reloadedStore.tabsForSelectedSession.map(\.id) == [secondTerminalTab.id, fileTab.id, initialTerminalTab.id])
        #expect(reloadedStore.tabsForSelectedSession.map(\.kind) == [.terminal, .file, .terminal])
    }

    @Test
    func edgeTabMovesSurviveReloadWithoutOrdinalDrift() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let firstTerminalTab = try #require(harness.store.tabs.first)
        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)
        let secondTerminalTab = try await harness.service.createTab(sessionID: session.id)
        let thirdTerminalTab = try await harness.service.createTab(sessionID: session.id)

        try await harness.service.reorderTabs(
            sessionID: session.id,
            orderedVisibleTabIDs: [fileTab.id, secondTerminalTab.id, thirdTerminalTab.id, firstTerminalTab.id]
        )

        let firstReloadStore = WorkspaceStore()
        let firstReloadService = DefaultWorkspaceCommandService(
            store: firstReloadStore,
            persistenceStore: harness.persistence,
            restoreCoordinator: RestoreCoordinator(persistenceStore: harness.persistence),
            terminalSurfaceManager: FakeIntegrationTerminalSurfaceManager()
        )

        try await firstReloadService.restoreWorkspace()

        #expect(firstReloadStore.tabsForSelectedSession.map(\.id) == [fileTab.id, secondTerminalTab.id, thirdTerminalTab.id, firstTerminalTab.id])
        #expect(firstReloadStore.tabsForSelectedSession.map(\.ordinal) == [0, 1, 2, 3])

        try await firstReloadService.reorderTabs(
            sessionID: session.id,
            orderedVisibleTabIDs: [firstTerminalTab.id, fileTab.id, secondTerminalTab.id, thirdTerminalTab.id]
        )

        let secondReloadStore = WorkspaceStore()
        let secondReloadService = DefaultWorkspaceCommandService(
            store: secondReloadStore,
            persistenceStore: harness.persistence,
            restoreCoordinator: RestoreCoordinator(persistenceStore: harness.persistence),
            terminalSurfaceManager: FakeIntegrationTerminalSurfaceManager()
        )

        try await secondReloadService.restoreWorkspace()

        #expect(secondReloadStore.tabsForSelectedSession.map(\.id) == [firstTerminalTab.id, fileTab.id, secondTerminalTab.id, thirdTerminalTab.id])
        #expect(secondReloadStore.tabsForSelectedSession.map(\.ordinal) == [0, 1, 2, 3])
        #expect(try await harness.persistence.loadTabs().map(\.id) == [firstTerminalTab.id, fileTab.id, secondTerminalTab.id, thirdTerminalTab.id])
        #expect(try await harness.persistence.loadTabs().map(\.ordinal) == [0, 1, 2, 3])
    }

    @Test
    func projectReorderPersistsAndKeepsSelectionStableAfterRestore() async throws {
        let harness = try makeHarness()
        let firstProject = try await harness.service.openProject(path: makeTemporaryProjectDirectory(named: "first"))
        let secondProject = try await harness.service.openProject(path: makeTemporaryProjectDirectory(named: "second"))
        let thirdProject = try await harness.service.openProject(path: makeTemporaryProjectDirectory(named: "third"))
        try await harness.service.selectProject(id: secondProject.id)

        try await harness.service.reorderProjects([thirdProject.id, secondProject.id, firstProject.id])

        #expect(try await harness.persistence.loadProjects().map(\.id) == [thirdProject.id, secondProject.id, firstProject.id])
        #expect(try await harness.persistence.loadProjects().map(\.sortIndex) == [0, 1, 2])
        #expect(harness.service.metrics.projectReorderCount == 1)
        #expect(harness.service.logger.events.contains { event in
            event.name == "project_reordered" &&
                event.fields["project_count"] == "3" &&
                event.fields["hidden_persisted_project_count"] == "0"
        })

        let reloadedStore = WorkspaceStore()
        let reloadedService = DefaultWorkspaceCommandService(
            store: reloadedStore,
            persistenceStore: harness.persistence,
            restoreCoordinator: RestoreCoordinator(persistenceStore: harness.persistence),
            terminalSurfaceManager: FakeIntegrationTerminalSurfaceManager()
        )

        try await reloadedService.restoreWorkspace()

        #expect(reloadedStore.projects.map(\.id) == [thirdProject.id, secondProject.id, firstProject.id])
        #expect(reloadedStore.projects.map(\.sortIndex) == [0, 1, 2])
        #expect(reloadedStore.selectedProjectID == secondProject.id)
    }

    @Test
    func reorderAfterFilteredRestoreKeepsSnapshotAlignedForNextLaunch() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let readableFile = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/App.swift")
        let missingFile = URL(fileURLWithPath: projectPath, isDirectory: true)
            .appendingPathComponent("Sources/Missing.swift")
        let project = WorkspaceProject(path: projectPath, displayName: "filtered")
        let session = WorkspaceSession(projectID: project.id, title: "Filtered")
        let terminalTab = WorkspaceTab(sessionID: session.id, workingDirectory: projectPath, ordinal: 0)
        let readableFileTab = WorkspaceTab(
            sessionID: session.id,
            kind: .file,
            workingDirectory: projectPath,
            fileReference: WorkspaceFileReference(path: readableFile.path, projectRoot: projectPath),
            ordinal: 1
        )
        let missingFileTab = WorkspaceTab(
            sessionID: session.id,
            kind: .file,
            workingDirectory: projectPath,
            fileReference: WorkspaceFileReference(path: missingFile.path, projectRoot: projectPath),
            ordinal: 2
        )
        try await harness.persistence.save(project: project)
        try await harness.persistence.save(session: session)
        try await harness.persistence.save(tab: terminalTab)
        try await harness.persistence.save(tab: readableFileTab)
        try await harness.persistence.save(tab: missingFileTab)
        try await harness.persistence.save(snapshot: RestoreSnapshot(
            selectedProjectID: project.id,
            selectedSessionID: session.id,
            selectedTabID: readableFileTab.id,
            tabOrder: [terminalTab.id, readableFileTab.id, missingFileTab.id]
        ))

        try await harness.service.restoreWorkspace()
        try await harness.service.reorderTabs(
            sessionID: session.id,
            orderedVisibleTabIDs: [readableFileTab.id, terminalTab.id]
        )

        let persistedSessionTabs = try await harness.persistence.loadTabs().filter { $0.sessionID == session.id }
        let snapshot = try #require(try await harness.persistence.loadRestoreSnapshot())
        #expect(harness.store.tabsForSelectedSession.map(\.id) == [readableFileTab.id, terminalTab.id])
        #expect(persistedSessionTabs.map(\.id) == [readableFileTab.id, terminalTab.id, missingFileTab.id])
        #expect(persistedSessionTabs.map(\.ordinal) == [0, 1, 2])
        #expect(snapshot.tabOrder == [readableFileTab.id, terminalTab.id, missingFileTab.id])
        #expect(harness.service.metrics.fileRestoreFailureCount == 1)
        #expect(harness.service.metrics.tabReorderCount == 1)
        #expect(harness.service.logger.events.contains { event in
            event.name == "tab_reordered" &&
                event.fields["session_id"] == session.id.uuidString &&
                event.fields["visible_tab_count"] == "2" &&
                event.fields["hidden_persisted_tab_count"] == "1"
        })

        let reloadedStore = WorkspaceStore()
        let reloadedTerminal = FakeIntegrationTerminalSurfaceManager()
        let reloadedFileBuffers = WorkspaceFileBufferController(fileAccess: LocalWorkspaceFileAccess())
        let reloadedService = DefaultWorkspaceCommandService(
            store: reloadedStore,
            persistenceStore: harness.persistence,
            restoreCoordinator: RestoreCoordinator(persistenceStore: harness.persistence),
            terminalSurfaceManager: reloadedTerminal,
            fileAccess: LocalWorkspaceFileAccess(),
            fileBufferManager: reloadedFileBuffers,
            externalEditorOpener: FakeIntegrationExternalEditorOpener()
        )

        try await reloadedService.restoreWorkspace()

        #expect(reloadedStore.tabsForSelectedSession.map(\.id) == [readableFileTab.id, terminalTab.id])
        #expect(reloadedStore.selectedTabID == readableFileTab.id)
        #expect(reloadedTerminal.createdTabs.map(\.id) == [terminalTab.id])
    }

    @Test
    func openingFileTabProducesEditorPresentationAndKeepsTerminalSurfaceIsolated() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let terminalTab = try #require(harness.store.tabs.first)

        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)
        let presentation = FileEditorPresentation(tab: fileTab, buffer: harness.fileBuffers.buffer(for: fileTab.id))

        #expect(harness.store.selectedTabID == fileTab.id)
        #expect(harness.store.tabsForSelectedSession.map(\.kind) == [.terminal, .file])
        #expect(presentation?.title == "File.swift")
        #expect(presentation?.languageConfigurationKey == "swift")
        #expect(presentation?.isDirty == false)
        #expect(harness.terminal.createdTabs.map(\.id) == [terminalTab.id])
    }

    @Test
    func openingFileTabUsesPersistedMaxOrdinalWhenStoreHasRestoredSubset() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let initialTab = try #require(harness.store.tabs.first)
        let persistedOnlyTab = WorkspaceTab(
            sessionID: session.id,
            workingDirectory: project.path,
            ordinal: 1
        )
        try await harness.persistence.save(tab: persistedOnlyTab)

        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)
        let persistedTabs = try await harness.persistence.loadTabs()

        #expect(fileTab.kind == .file)
        #expect(fileTab.ordinal == 2)
        #expect(harness.store.tabsForSelectedSession.map(\.id) == [initialTab.id, fileTab.id])
        #expect(persistedTabs.map(\.id) == [initialTab.id, persistedOnlyTab.id, fileTab.id])
        #expect(persistedTabs.map(\.ordinal) == [0, 1, 2])
    }

    @Test
    func fileOpenEditSavePersistsMetadataAndWritesSavedContentsToDisk() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)

        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)
        harness.fileBuffers.updateBuffer(tabID: fileTab.id, text: "let saved = true\n")
        try await harness.service.saveFileTab(tabID: fileTab.id)
        let persistedTabs = try await harness.persistence.loadTabs()
        let persistedFileTab = try #require(persistedTabs.first { $0.id == fileTab.id })

        #expect(try String(contentsOf: fileURL, encoding: .utf8) == "let saved = true\n")
        #expect(harness.fileBuffers.isDirty(tabID: fileTab.id) == false)
        #expect(persistedFileTab.kind == .file)
        #expect(persistedFileTab.fileReference?.path == fileURL.standardizedFileURL.resolvingSymlinksInPath().path)
        #expect(try await harness.persistence.loadRestoreSnapshot()?.tabOrder.contains(fileTab.id) == true)
    }

    @Test
    func savedFileContentsRestoreAfterRelaunchWhileUnsavedRuntimeChangesDoNot() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)

        harness.fileBuffers.updateBuffer(tabID: fileTab.id, text: "let saved = true\n")
        try await harness.service.saveFileTab(tabID: fileTab.id)
        harness.fileBuffers.updateBuffer(tabID: fileTab.id, text: "let unsaved = true\n")

        let restoredStore = WorkspaceStore()
        let restoredTerminal = FakeIntegrationTerminalSurfaceManager()
        let restoredFileAccess = LocalWorkspaceFileAccess()
        let restoredFileBuffers = WorkspaceFileBufferController(fileAccess: restoredFileAccess)
        let restoredService = DefaultWorkspaceCommandService(
            store: restoredStore,
            persistenceStore: harness.persistence,
            restoreCoordinator: RestoreCoordinator(persistenceStore: harness.persistence),
            terminalSurfaceManager: restoredTerminal,
            fileAccess: restoredFileAccess,
            fileBufferManager: restoredFileBuffers,
            externalEditorOpener: FakeIntegrationExternalEditorOpener()
        )

        try await restoredService.restoreWorkspace()

        #expect(try String(contentsOf: fileURL, encoding: .utf8) == "let saved = true\n")
        #expect(restoredStore.tabsForSelectedSession.map(\.id).contains(fileTab.id))
        #expect(restoredFileBuffers.bufferText(for: fileTab.id) == "let saved = true\n")
        #expect(restoredFileBuffers.isDirty(tabID: fileTab.id) == false)
    }

    @Test
    func selectedFileTabCommandEnablementTracksRealStoreSelectionAndDirtyState() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let terminalTab = try #require(harness.store.tabs.first)

        #expect(AppCommandRegistry.isEnabled(.saveFile, selectedTab: harness.store.selectedTab, selectedFileIsDirty: false) == false)
        #expect(AppCommandRegistry.isEnabled(.openFileInExternalEditor, selectedTab: harness.store.selectedTab, selectedFileIsDirty: false) == false)

        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)

        #expect(harness.store.selectedTabID == fileTab.id)
        #expect(AppCommandRegistry.isEnabled(.saveFile, selectedTab: harness.store.selectedTab, selectedFileIsDirty: false) == false)
        #expect(AppCommandRegistry.isEnabled(.revertFile, selectedTab: harness.store.selectedTab, selectedFileIsDirty: false))
        #expect(AppCommandRegistry.isEnabled(.openFileInExternalEditor, selectedTab: harness.store.selectedTab, selectedFileIsDirty: false))

        harness.fileBuffers.updateBuffer(tabID: fileTab.id, text: "let dirty = true\n")

        #expect(AppCommandRegistry.isEnabled(.saveFile, selectedTab: harness.store.selectedTab, selectedFileIsDirty: harness.fileBuffers.isDirty(tabID: fileTab.id)))

        try await harness.service.selectTab(id: terminalTab.id)

        #expect(AppCommandRegistry.isEnabled(.saveFile, selectedTab: harness.store.selectedTab, selectedFileIsDirty: true) == false)
        #expect(AppCommandRegistry.isEnabled(.revertFile, selectedTab: harness.store.selectedTab, selectedFileIsDirty: true) == false)
        #expect(AppCommandRegistry.isEnabled(.openFileInExternalEditor, selectedTab: harness.store.selectedTab, selectedFileIsDirty: true) == false)
    }

    @Test
    func openingOutsideProjectRejectsThroughSQLiteBackedCommandService() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let outsideProjectPath = try makeTemporaryProjectDirectory(named: "outside")
        let outsideFile = try makeTemporaryProjectFile(in: outsideProjectPath, relativePath: "Outside.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let terminalTab = try #require(harness.store.tabs.first)
        let standardizedOutsideFile = outsideFile.standardizedFileURL.resolvingSymlinksInPath().path
        let standardizedProjectPath = URL(fileURLWithPath: projectPath, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath().path

        await #expect(throws: WorkspaceCommandError.filePathOutsideProject(
            filePath: standardizedOutsideFile,
            projectRoot: standardizedProjectPath
        )) {
            _ = try await harness.service.openFileTab(sessionID: session.id, path: outsideFile.path)
        }

        #expect(try await harness.persistence.loadTabs().map(\.id) == [terminalTab.id])
        #expect(harness.store.tabs.map(\.id) == [terminalTab.id])
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
    func dirtyFileCloseRejectsUntilForcedAndRecordsDecisionTelemetry() async throws {
        let harness = try makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let terminalTab = try #require(harness.store.tabs.first)
        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)
        harness.fileBuffers.updateBuffer(tabID: fileTab.id, text: "let dirty = true\n")

        await #expect(throws: WorkspaceCommandError.dirtyFileTabCloseRejected(fileTab.id)) {
            try await harness.service.closeTab(tabID: fileTab.id, force: false)
        }

        #expect(try await harness.persistence.loadTabs().map(\.id) == [terminalTab.id, fileTab.id])
        #expect(harness.service.metrics.dirtyFileCloseConfirmationRejectCount == 1)

        try await harness.service.closeTab(tabID: fileTab.id, force: true)

        #expect(try await harness.persistence.loadTabs().map(\.id) == [terminalTab.id])
        #expect(harness.service.metrics.dirtyFileCloseConfirmationAcceptCount == 1)
        #expect(harness.service.logger.events.contains { event in
            event.name == "file_tab_dirty_close_decision" &&
                event.fields["tab_id"] == fileTab.id.uuidString &&
                event.fields["accepted"] == "true"
        })
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
        let fileAccess = LocalWorkspaceFileAccess()
        let fileBuffers = WorkspaceFileBufferController(fileAccess: fileAccess, now: now)
        let externalEditor = FakeIntegrationExternalEditorOpener()
        let service = DefaultWorkspaceCommandService(
            store: store,
            persistenceStore: persistence,
            restoreCoordinator: coordinator,
            terminalSurfaceManager: terminal,
            fileAccess: fileAccess,
            fileBufferManager: fileBuffers,
            externalEditorOpener: externalEditor,
            now: now
        )

        return CommandServiceIntegrationHarness(
            store: store,
            persistence: persistence,
            terminal: terminal,
            fileBuffers: fileBuffers,
            externalEditor: externalEditor,
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

    private func makeTemporaryProjectFile(in projectPath: String, relativePath: String) throws -> URL {
        let fileURL = URL(fileURLWithPath: projectPath, isDirectory: true)
            .appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "let value = 1\n".write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func managedKeybindingOverrides() -> [AppCommandID: KeybindingOverride] {
        AppCommandRegistry.managedCommandIDs.enumerated().reduce(into: [:]) { overrides, pair in
            let index = pair.offset + 1
            let commandID = pair.element
            overrides[commandID] = KeybindingOverride(
                commandID: commandID,
                keyEquivalent: String(index),
                modifiers: [.command, .option]
            )
        }
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
    let fileBuffers: WorkspaceFileBufferController
    let externalEditor: FakeIntegrationExternalEditorOpener
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

@MainActor
private final class FakeIntegrationExternalEditorOpener: ExternalEditorOpening {
    private(set) var openedPaths: [String] = []

    func openFile(at path: String) async throws {
        openedPaths.append(path)
    }
}
