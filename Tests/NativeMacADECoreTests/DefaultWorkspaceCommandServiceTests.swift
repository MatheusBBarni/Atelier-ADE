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
        #expect(project.bookmarkData?.isEmpty == false)
        #expect(try await harness.persistence.loadProjects() == [project])
        #expect(try await harness.persistence.loadProjects().first?.bookmarkData?.isEmpty == false)
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
    func savingPreferencesRejectsUnknownThemeAndLeavesPersistenceUnchanged() async throws {
        let harness = makeHarness()
        let originalPreferences = AppPreferences(
            themeID: "cursor",
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        try await harness.persistence.save(appPreferences: originalPreferences)

        await #expect(throws: WorkspaceCommandError.settingsValidationFailed(.unknownThemeID("unknown-theme"))) {
            try await harness.service.saveAppPreferences(AppPreferences(themeID: "unknown-theme"))
        }

        #expect(try await harness.persistence.loadAppPreferences() == originalPreferences)
        #expect(harness.store.appPreferences == .defaults)
    }

    @Test
    func savingPreferencesRejectsUnknownDefaultProfileReferenceAndLeavesPersistenceUnchanged() async throws {
        let harness = makeHarness()
        let originalPreferences = AppPreferences(themeID: "cursor", updatedAt: Date(timeIntervalSince1970: 101))
        let missingShortcutID = UUID()
        try await harness.persistence.save(appPreferences: originalPreferences)

        await #expect(throws: WorkspaceCommandError.settingsValidationFailed(.unknownDefaultSessionShortcut(missingShortcutID))) {
            try await harness.service.saveAppPreferences(AppPreferences(defaultSessionShortcutID: missingShortcutID))
        }

        #expect(try await harness.persistence.loadAppPreferences() == originalPreferences)
    }

    @Test
    func savingPreferencesRejectsDuplicateManagedKeybindingsWithTypedFailure() async throws {
        let harness = makeHarness()
        let preferences = AppPreferences(
            keybindings: [
                .nextTab: KeybindingOverride(commandID: .nextTab, keyEquivalent: "[")
            ]
        )

        await #expect(throws: WorkspaceCommandError.settingsValidationFailed(.duplicateManagedKeybinding(
            commandID: .nextTab,
            conflictingCommandID: .previousTab
        ))) {
            try await harness.service.saveAppPreferences(preferences)
        }
    }

    @Test
    func savingThemeOnlyChangeRecordsSaveAndThemeChangeObservations() async throws {
        let harness = makeHarness()

        try await harness.service.saveAppPreferences(AppPreferences(themeID: "dracula"))

        #expect(harness.service.metrics.settingsSavedCount == 1)
        #expect(harness.service.metrics.themeChangedCount == 1)
        #expect(harness.service.metrics.keybindingChangedCount == 0)
        #expect(harness.service.metrics.lastSavedChangedKeybindingCount == 0)
        #expect(harness.service.logger.events.contains { event in
            event.name == "settings_saved" &&
                event.fields["theme_id"] == "dracula" &&
                event.fields["changed_keybinding_count"] == "0"
        })
        #expect(harness.service.logger.events.contains { event in
            event.name == "theme_applied" && event.fields["theme_id"] == "dracula"
        })
        #expect(harness.service.logger.events.contains { $0.name == "keybinding_changed" } == false)
    }

    @Test
    func savingManagedKeybindingsRecordsChangedCountsAndResetClearsOnlyOneOverride() async throws {
        let harness = makeHarness()
        let overrides = managedKeybindingOverrides()

        try await harness.service.saveAppPreferences(AppPreferences(keybindings: overrides))

        #expect(try await harness.persistence.loadAppPreferences().keybindings == overrides)
        #expect(harness.service.metrics.settingsSavedCount == 1)
        #expect(harness.service.metrics.keybindingChangedCount == AppCommandRegistry.managedCommandIDs.count)
        #expect(harness.service.metrics.lastSavedChangedKeybindingCount == AppCommandRegistry.managedCommandIDs.count)
        #expect(harness.service.logger.events.contains { event in
            event.name == "settings_saved" &&
                event.fields["changed_keybinding_count"] == String(AppCommandRegistry.managedCommandIDs.count)
        })
        #expect(harness.service.logger.events.contains { event in
            event.name == "keybinding_changed" &&
                event.fields["changed_keybinding_count"] == String(AppCommandRegistry.managedCommandIDs.count)
        })

        let savedPreferences = try await harness.service.loadAppPreferences()
        let resetPreferences = AppCommandRegistry.resettingOverride(for: .zoomOutTerminal, in: savedPreferences)
        try await harness.service.saveAppPreferences(resetPreferences)
        let reloadedPreferences = try await harness.persistence.loadAppPreferences()

        #expect(reloadedPreferences.keybindings[.zoomOutTerminal] == nil)
        #expect(reloadedPreferences.keybindings[.previousTab] == overrides[.previousTab])
        #expect(reloadedPreferences.keybindings[.openSettings] == overrides[.openSettings])
        #expect(reloadedPreferences.keybindings.count == AppCommandRegistry.managedCommandIDs.count - 1)
        #expect(harness.service.metrics.settingsSavedCount == 2)
        #expect(harness.service.metrics.keybindingChangedCount == AppCommandRegistry.managedCommandIDs.count + 1)
        #expect(harness.service.metrics.lastSavedChangedKeybindingCount == AppCommandRegistry.managedCommandIDs.count - 1)
        let lastSettingsSaved = try #require(harness.service.logger.events.last { $0.name == "settings_saved" })
        let lastKeybindingChanged = try #require(harness.service.logger.events.last { $0.name == "keybinding_changed" })
        #expect(lastSettingsSaved.fields["changed_keybinding_count"] == String(AppCommandRegistry.managedCommandIDs.count - 1))
        #expect(lastKeybindingChanged.fields["changed_keybinding_count"] == "1")
        #expect(lastKeybindingChanged.fields["command_ids"] == AppCommandID.zoomOutTerminal.rawValue)
    }

    @Test
    func invalidManagedKeybindingsRecordFailureObservationAndPreserveSavedPreferences() async throws {
        let harness = makeHarness()
        let originalOverride = KeybindingOverride(commandID: .openSettings, keyEquivalent: ",", modifiers: [.command, .shift])
        let originalPreferences = AppPreferences(themeID: "catppuccin", keybindings: [.openSettings: originalOverride])
        try await harness.service.saveAppPreferences(originalPreferences)
        harness.service.logger.clear()

        let invalidPreferences = AppPreferences(
            themeID: "dracula",
            keybindings: [
                .nextTab: KeybindingOverride(commandID: .nextTab, keyEquivalent: "[")
            ]
        )

        await #expect(throws: WorkspaceCommandError.settingsValidationFailed(.duplicateManagedKeybinding(
            commandID: .nextTab,
            conflictingCommandID: .previousTab
        ))) {
            try await harness.service.saveAppPreferences(invalidPreferences)
        }

        #expect(try await harness.persistence.loadAppPreferences() == harness.store.appPreferences)
        #expect(try await harness.persistence.loadAppPreferences().themeID == "catppuccin")
        #expect(try await harness.persistence.loadAppPreferences().keybindings == [.openSettings: originalOverride])
        #expect(harness.service.metrics.settingsSaveFailureCount == 1)
        #expect(harness.service.logger.events.contains { event in
            event.name == "settings_save_failed" &&
                event.fields["field"] == "keybindings" &&
                event.fields["reason"]?.contains("duplicate_managed_keybinding") == true
        })
        #expect(harness.service.logger.events.contains { event in
            event.name == "keybinding_conflict_rejected" &&
                event.fields["command_id"] == AppCommandID.nextTab.rawValue &&
                event.fields["conflicting_command_id"] == AppCommandID.previousTab.rawValue
        })
    }

    @Test
    func emptyManagedKeybindingRecordsFailureObservationAndPreservesSavedPreferences() async throws {
        let harness = makeHarness()
        let originalPreferences = AppPreferences(themeID: "onedark")
        try await harness.service.saveAppPreferences(originalPreferences)
        harness.service.logger.clear()

        await #expect(throws: WorkspaceCommandError.settingsValidationFailed(.emptyKeybinding(.openSettings))) {
            try await harness.service.saveAppPreferences(AppPreferences(
                themeID: "dracula",
                keybindings: [
                    .openSettings: KeybindingOverride(commandID: .openSettings, keyEquivalent: "   ")
                ]
            ))
        }

        #expect(try await harness.persistence.loadAppPreferences() == harness.store.appPreferences)
        #expect(try await harness.persistence.loadAppPreferences().themeID == "onedark")
        #expect(harness.service.metrics.settingsSaveFailureCount == 1)
        #expect(harness.service.logger.events.contains { event in
            event.name == "settings_save_failed" &&
                event.fields["field"] == "keybindings" &&
                event.fields["reason"] == "empty_keybinding:openSettings"
        })
        #expect(harness.service.logger.events.contains { $0.name == "keybinding_conflict_rejected" } == false)
    }

    @Test
    func openingSettingsRecordsLocalObservationWithProjectSelectionContext() async throws {
        let harness = makeHarness()

        harness.service.recordSettingsOpened(surface: "config_modal")
        let project = try await harness.service.openProject(path: makeTemporaryProjectDirectory())
        harness.service.recordSettingsOpened(surface: "config_modal")

        let settingsEvents = harness.service.logger.events.filter { $0.name == "settings_opened" }
        #expect(project.id == harness.store.selectedProjectID)
        #expect(harness.service.metrics.settingsOpenedCount == 2)
        #expect(settingsEvents.count == 2)
        #expect(settingsEvents.first?.fields["surface"] == "config_modal")
        #expect(settingsEvents.first?.fields["selected_project_id_present"] == "false")
        #expect(settingsEvents.last?.fields["selected_project_id_present"] == "true")
    }

    @Test
    func savingProfileRejectsMalformedLaunchArgumentsAndPreservesPreviousState() async throws {
        let harness = makeHarness()
        let shortcut = SessionShortcut(
            label: "Custom Codex",
            launchCommand: "codex",
            launchArgumentsJSON: "[\"exec\"]"
        )
        let savedShortcut = try await harness.service.saveSessionShortcut(shortcut)
        var malformedShortcut = savedShortcut
        malformedShortcut.launchArgumentsJSON = "{\"not\":\"an-array\"}"

        await #expect(throws: WorkspaceCommandError.settingsValidationFailed(.malformedLaunchArgumentsJSON(savedShortcut.id))) {
            _ = try await harness.service.saveSessionShortcut(malformedShortcut)
        }

        #expect(try await harness.persistence.loadSessionShortcuts() == [savedShortcut])
    }

    @Test
    func editingBuiltInProfileMarksOverrideAndResetRestoresCanonicalValues() async throws {
        let harness = makeHarness()
        let canonicalShortcut = try #require(SessionShortcut.builtInDefaults.first { $0.label == "Codex" })
        var editedShortcut = canonicalShortcut
        editedShortcut.launchArgumentsJSON = "[\"exec\"]"

        let savedShortcut = try await harness.service.saveSessionShortcut(editedShortcut)
        let resetShortcut = try await harness.service.resetBuiltInSessionShortcut(id: canonicalShortcut.id)

        #expect(savedShortcut.id == canonicalShortcut.id)
        #expect(savedShortcut.isBuiltIn == true)
        #expect(savedShortcut.hasUserOverride == true)
        #expect(savedShortcut.launchArgumentsJSON == "[\"exec\"]")
        #expect(resetShortcut == canonicalShortcut)
        #expect(try await harness.persistence.loadSessionShortcuts().first { $0.id == canonicalShortcut.id } == canonicalShortcut)
    }

    @Test
    func deletingCustomProfileClearsDefaultSessionShortcutInPersistenceAndStore() async throws {
        let harness = makeHarness()
        let shortcut = try await harness.service.saveSessionShortcut(SessionShortcut(
            label: "Review",
            launchCommand: "claude",
            launchArgumentsJSON: "[\"--continue\"]"
        ))
        try await harness.service.saveAppPreferences(AppPreferences(defaultSessionShortcutID: shortcut.id))

        try await harness.service.deleteSessionShortcut(id: shortcut.id)

        #expect(try await harness.persistence.loadSessionShortcuts().isEmpty)
        #expect(try await harness.persistence.loadAppPreferences().defaultSessionShortcutID == nil)
        #expect(harness.store.appPreferences.defaultSessionShortcutID == nil)
    }

    @Test
    func deletingBuiltInProfileFailsWithoutMutatingPersistence() async throws {
        let harness = makeHarness()
        let shortcuts = try await harness.service.availableSessionShortcuts()
        let preferences = AppPreferences(themeID: "dracula", updatedAt: Date(timeIntervalSince1970: 200))
        try await harness.persistence.save(appPreferences: preferences)
        let builtInShortcut = try #require(shortcuts.first { $0.label == "Claude" })

        await #expect(throws: WorkspaceCommandError.builtInShortcutDeletionRejected(builtInShortcut.id)) {
            try await harness.service.deleteSessionShortcut(id: builtInShortcut.id)
        }

        #expect(try await harness.persistence.loadSessionShortcuts() == shortcuts)
        #expect(try await harness.persistence.loadAppPreferences() == preferences)
    }

    @Test
    func addingEditingAndDeletingCustomProfileWorks() async throws {
        let harness = makeHarness()
        let createdProfile = try await harness.service.saveSessionShortcut(SessionShortcut(
            label: "Local Reviewer",
            launchCommand: "local-review",
            launchArgumentsJSON: "[]",
            isBuiltIn: true,
            hasUserOverride: true
        ))
        var editedProfile = createdProfile
        editedProfile.label = "Local Reviewer Fast"
        editedProfile.launchArgumentsJSON = "[\"--fast\"]"

        let savedEdit = try await harness.service.saveSessionShortcut(editedProfile)

        #expect(createdProfile.isBuiltIn == false)
        #expect(createdProfile.hasUserOverride == false)
        #expect(savedEdit.id == createdProfile.id)
        #expect(savedEdit.label == "Local Reviewer Fast")
        #expect(savedEdit.launchArgumentsJSON == "[\"--fast\"]")
        #expect(savedEdit.isBuiltIn == false)
        #expect(savedEdit.hasUserOverride == false)
        #expect(try await harness.persistence.loadSessionShortcuts() == [savedEdit])

        try await harness.service.deleteSessionShortcut(id: savedEdit.id)

        #expect(try await harness.persistence.loadSessionShortcuts().isEmpty)
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
        #expect(configuration.appearance == AppTheme.defaultTheme.terminalAppearance)
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
    func openingFileTabCreatesMetadataAndLoadsInitialBufferWithoutLaunchingTerminalSurface() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let terminalTab = try #require(harness.store.tabs.first)

        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)

        #expect(fileTab.kind == .file)
        #expect(fileTab.fileReference?.path == fileURL.standardizedFileURL.resolvingSymlinksInPath().path)
        #expect(fileTab.fileReference?.projectRoot == URL(fileURLWithPath: projectPath, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath().path)
        #expect(harness.store.tabsForSelectedSession.map(\.id) == [terminalTab.id, fileTab.id])
        #expect(harness.store.selectedTabID == fileTab.id)
        #expect(harness.fileBuffers.bufferText(for: fileTab.id) == "let value = 1\n")
        #expect(harness.fileBuffers.isDirty(tabID: fileTab.id) == false)
        #expect(harness.terminal.createdTabs.map(\.id) == [terminalTab.id])
    }

    @Test
    func selectingFileTabUpdatesSharedSelectionWithoutTerminalSideEffects() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let terminalTab = try #require(harness.store.tabs.first)
        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)
        try await harness.service.selectTab(id: terminalTab.id)
        let terminalCreatedBeforeSelection = harness.terminal.createdTabs
        let terminalCloseRequestsBeforeSelection = harness.terminal.canCloseRequestCount

        try await harness.service.selectTab(id: fileTab.id)

        #expect(harness.store.selectedProjectID == project.id)
        #expect(harness.store.selectedSessionID == session.id)
        #expect(harness.store.selectedTabID == fileTab.id)
        #expect(harness.terminal.createdTabs == terminalCreatedBeforeSelection)
        #expect(harness.terminal.canCloseRequestCount == terminalCloseRequestsBeforeSelection)
        #expect(harness.terminal.releasedTabIDs.isEmpty)
    }

    @Test
    func openingFileOutsideProjectRejectsWithoutAddingFileTab() async throws {
        let harness = makeHarness()
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

        #expect(harness.store.tabs.map(\.id) == [terminalTab.id])
        #expect(try await harness.persistence.loadTabs().map(\.id) == [terminalTab.id])
    }

    @Test
    func savingFileTabOutsideProjectRejectsBeforeWriting() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let outsideProjectPath = try makeTemporaryProjectDirectory(named: "outside-save")
        let outsideFile = try makeTemporaryProjectFile(in: outsideProjectPath, relativePath: "Outside.swift")
        let project = WorkspaceProject(path: projectPath, displayName: "Project")
        let session = WorkspaceSession(projectID: project.id, title: "Session")
        let fileTab = WorkspaceTab(
            sessionID: session.id,
            kind: .file,
            workingDirectory: projectPath,
            fileReference: WorkspaceFileReference(path: outsideFile.path, projectRoot: projectPath),
            ordinal: 0
        )
        let standardizedOutsideFile = outsideFile.standardizedFileURL.resolvingSymlinksInPath().path
        let standardizedProjectPath = URL(fileURLWithPath: projectPath, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath().path
        harness.store.upsertProject(project)
        harness.store.upsertSession(session)
        harness.store.upsertTab(fileTab)

        await #expect(throws: WorkspaceCommandError.filePathOutsideProject(
            filePath: standardizedOutsideFile,
            projectRoot: standardizedProjectPath
        )) {
            try await harness.service.saveFileTab(tabID: fileTab.id)
        }

        #expect(try String(contentsOf: outsideFile, encoding: .utf8) == "let value = 1\n")
    }

    @Test
    func saveAndRevertFileTabUseRuntimeBufferAndExplicitDiskWrites() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)

        harness.fileBuffers.updateBuffer(tabID: fileTab.id, text: "let value = 2\n")
        #expect(harness.fileBuffers.isDirty(tabID: fileTab.id))

        try await harness.service.saveFileTab(tabID: fileTab.id)

        #expect(try String(contentsOf: fileURL, encoding: .utf8) == "let value = 2\n")
        #expect(harness.fileBuffers.isDirty(tabID: fileTab.id) == false)

        try "let value = 3\n".write(to: fileURL, atomically: true, encoding: .utf8)
        harness.fileBuffers.updateBuffer(tabID: fileTab.id, text: "let unsaved = true\n")

        try await harness.service.revertFileTab(tabID: fileTab.id)

        #expect(harness.fileBuffers.bufferText(for: fileTab.id) == "let value = 3\n")
        #expect(harness.fileBuffers.isDirty(tabID: fileTab.id) == false)
    }

    @Test
    func fileWorkflowTelemetryUsesHashedPathsWithoutRawFileLocations() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let standardizedPath = fileURL.standardizedFileURL.resolvingSymlinksInPath().path

        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)
        harness.fileBuffers.updateBuffer(tabID: fileTab.id, text: "let value = 2\n")
        try await harness.service.saveFileTab(tabID: fileTab.id)
        try await harness.service.revertFileTab(tabID: fileTab.id)
        try await harness.service.openFileInExternalEditor(tabID: fileTab.id)

        let fileEvents = harness.service.logger.events.filter {
            [
                "file_tab_opened",
                "file_tab_saved",
                "file_tab_reverted",
                "external_editor_opened"
            ].contains($0.name)
        }

        #expect(harness.service.metrics.fileOpenDurations.count == 1)
        #expect(harness.service.metrics.fileSaveSuccessCount == 1)
        #expect(harness.service.metrics.fileRevertSuccessCount == 1)
        #expect(harness.service.metrics.externalEditorEscalationCount == 1)
        #expect(fileEvents.count == 4)
        #expect(fileEvents.allSatisfy { event in
            event.fields["hashed_path"] == WorkspacePrivacy.hashIdentifier(standardizedPath) &&
                event.fields.values.contains(standardizedPath) == false &&
                event.fields.values.contains(fileURL.path) == false
        })
    }

    @Test
    func fileWorkflowFailureLogsUsePrivacySafeReasonsWithoutRawFileLocations() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let outsideProjectPath = try makeTemporaryProjectDirectory(named: "outside-save")
        let outsideFile = try makeTemporaryProjectFile(in: outsideProjectPath, relativePath: "Outside.swift")
        let project = WorkspaceProject(path: projectPath, displayName: "Project")
        let session = WorkspaceSession(projectID: project.id, title: "Session")
        let fileTab = WorkspaceTab(
            sessionID: session.id,
            kind: .file,
            workingDirectory: projectPath,
            fileReference: WorkspaceFileReference(path: outsideFile.path, projectRoot: projectPath),
            ordinal: 0
        )
        harness.store.upsertProject(project)
        harness.store.upsertSession(session)
        harness.store.upsertTab(fileTab)
        let standardizedOutsideFile = outsideFile.standardizedFileURL.resolvingSymlinksInPath().path
        let standardizedProjectPath = URL(fileURLWithPath: projectPath, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath().path

        await #expect(throws: WorkspaceCommandError.filePathOutsideProject(
            filePath: standardizedOutsideFile,
            projectRoot: standardizedProjectPath
        )) {
            try await harness.service.saveFileTab(tabID: fileTab.id)
        }

        let event = try #require(harness.service.logger.events.first { $0.name == "file_tab_save_failed" })
        #expect(event.fields["reason"] == "file_path_outside_project")
        #expect(event.fields.values.contains(outsideFile.path) == false)
        #expect(event.fields.values.contains(projectPath) == false)
        #expect(harness.service.metrics.fileSaveFailureCount == 1)
    }

    @Test
    func openingFileInExternalEditorUsesDedicatedBoundary() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)

        try await harness.service.openFileInExternalEditor(tabID: fileTab.id)

        #expect(harness.externalEditor.openedPaths == [fileURL.standardizedFileURL.resolvingSymlinksInPath().path])
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
    func restoringMixedSessionCreatesTerminalSurfacesOnlyForTerminalTabs() async throws {
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/App.swift")
        let projectID = UUID()
        let sessionID = UUID()
        let terminalTabID = UUID()
        let fileTabID = UUID()
        let project = WorkspaceProject(id: projectID, path: projectPath, displayName: "mixed")
        let session = WorkspaceSession(id: sessionID, projectID: projectID, title: "Mixed")
        let terminalTab = WorkspaceTab(id: terminalTabID, sessionID: sessionID, workingDirectory: projectPath, ordinal: 0)
        let fileTab = WorkspaceTab(
            id: fileTabID,
            sessionID: sessionID,
            kind: .file,
            workingDirectory: projectPath,
            fileReference: WorkspaceFileReference(path: fileURL.path, projectRoot: projectPath),
            ordinal: 1
        )
        let store = WorkspaceStore()
        let persistence = InMemoryWorkspacePersistenceStore(
            projects: [project],
            sessions: [session],
            tabs: [terminalTab, fileTab],
            restoreSnapshot: RestoreSnapshot(
                selectedProjectID: projectID,
                selectedSessionID: sessionID,
                selectedTabID: fileTabID,
                tabOrder: [terminalTabID, fileTabID]
            )
        )
        let terminal = FakeTerminalSurfaceManager()
        let service = DefaultWorkspaceCommandService(
            store: store,
            persistenceStore: persistence,
            restoreCoordinator: RestoreCoordinator(persistenceStore: persistence),
            terminalSurfaceManager: terminal
        )

        let result = try await service.restoreWorkspace()

        #expect(store.tabsForSelectedSession.map(\.id) == [terminalTabID, fileTabID])
        #expect(store.selectedTabID == fileTabID)
        #expect(result.store.tabsForSelectedSession.map(\.kind) == [.terminal, .file])
        #expect(terminal.createdTabs.map(\.id) == [terminalTabID])
        #expect(service.metrics.terminalSurfaceCreationCount == 1)
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
    func closingFileTabBypassesTerminalCloseProtectionAndRemovesMetadata() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let terminalTab = try #require(harness.store.tabs.first)
        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)
        harness.terminal.canCloseResult = false
        harness.terminal.surfacesByTabID[fileTab.id] = GhosttySurfaceHandle()

        try await harness.service.closeTab(tabID: fileTab.id, force: false)

        #expect(harness.store.tabs.map(\.id) == [terminalTab.id])
        #expect(harness.store.selectedTabID == terminalTab.id)
        #expect(try await harness.persistence.loadTabs().map(\.id) == [terminalTab.id])
        #expect(harness.terminal.canCloseRequestCount == 0)
        #expect(harness.terminal.releasedTabIDs.isEmpty)
    }

    @Test
    func closingDirtyFileTabRejectsWithFileSpecificErrorAndKeepsMetadata() async throws {
        let harness = makeHarness()
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

        #expect(harness.store.tabs.map(\.id) == [terminalTab.id, fileTab.id])
        #expect(try await harness.persistence.loadTabs().map(\.id) == [terminalTab.id, fileTab.id])
        #expect(harness.service.metrics.dirtyFileCloseConfirmationRejectCount == 1)
        #expect(harness.terminal.canCloseRequestCount == 0)
        #expect(harness.service.logger.events.contains { event in
            event.name == "file_tab_dirty_close_decision" &&
                event.fields["tab_id"] == fileTab.id.uuidString &&
                event.fields["accepted"] == "false" &&
                event.fields["reason"] == "unsaved_changes"
        })
    }

    @Test
    func forceClosingDirtyFileTabRecordsAcceptedDiscardDecision() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let terminalTab = try #require(harness.store.tabs.first)
        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)
        harness.fileBuffers.updateBuffer(tabID: fileTab.id, text: "let dirty = true\n")

        try await harness.service.closeTab(tabID: fileTab.id, force: true)

        #expect(harness.store.tabs.map(\.id) == [terminalTab.id])
        #expect(harness.service.metrics.dirtyFileCloseConfirmationAcceptCount == 1)
        #expect(harness.fileBuffers.buffer(for: fileTab.id) == nil)
        #expect(harness.service.logger.events.contains { event in
            event.name == "file_tab_dirty_close_decision" &&
                event.fields["tab_id"] == fileTab.id.uuidString &&
                event.fields["accepted"] == "true" &&
                event.fields["reason"] == "discarded_unsaved_changes"
        })
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
    func removingSessionWithMixedTabsReleasesOnlyTerminalSurfaces() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let terminalTab = try #require(harness.store.tabs.first)
        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)
        harness.terminal.surfacesByTabID[fileTab.id] = GhosttySurfaceHandle()

        try await harness.service.removeSession(id: session.id)

        #expect(harness.store.sessions.isEmpty)
        #expect(harness.store.tabs.isEmpty)
        #expect(harness.store.selectedSessionID == nil)
        #expect(harness.store.selectedTabID == nil)
        #expect(harness.terminal.releasedTabIDs == [terminalTab.id])
    }

    @Test
    func removingSessionRejectsDirtyFileTabsBeforeDeletingMetadata() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let terminalTab = try #require(harness.store.tabs.first)
        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)
        harness.fileBuffers.updateBuffer(tabID: fileTab.id, text: "let dirty = true\n")

        await #expect(throws: WorkspaceCommandError.dirtyFileTabCloseRejected(fileTab.id)) {
            try await harness.service.removeSession(id: session.id)
        }

        #expect(harness.store.sessions.map(\.id) == [session.id])
        #expect(harness.store.tabs.map(\.id) == [terminalTab.id, fileTab.id])
        #expect(try await harness.persistence.loadTabs().map(\.id) == [terminalTab.id, fileTab.id])
        #expect(harness.service.metrics.dirtyFileCloseConfirmationRejectCount == 1)
        #expect(harness.terminal.releasedTabIDs.isEmpty)
    }

    @Test
    func removingProjectRejectsDirtyFileTabsBeforeDeletingMetadata() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let terminalTab = try #require(harness.store.tabs.first)
        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)
        harness.fileBuffers.updateBuffer(tabID: fileTab.id, text: "let dirty = true\n")

        await #expect(throws: WorkspaceCommandError.dirtyFileTabCloseRejected(fileTab.id)) {
            try await harness.service.removeProject(id: project.id)
        }

        #expect(harness.store.projects.map(\.id) == [project.id])
        #expect(harness.store.sessions.map(\.id) == [session.id])
        #expect(harness.store.tabs.map(\.id) == [terminalTab.id, fileTab.id])
        #expect(try await harness.persistence.loadTabs().map(\.id) == [terminalTab.id, fileTab.id])
        #expect(harness.service.metrics.dirtyFileCloseConfirmationRejectCount == 1)
        #expect(harness.terminal.releasedTabIDs.isEmpty)
    }

    @Test
    func removingProjectWithMixedTabsChecksAndReleasesOnlyTerminalSurfaces() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/File.swift")
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)
        let terminalTab = try #require(harness.store.tabs.first)
        let fileTab = try await harness.service.openFileTab(sessionID: session.id, path: fileURL.path)
        harness.terminal.surfacesByTabID[fileTab.id] = GhosttySurfaceHandle()

        try await harness.service.removeProject(id: project.id)

        #expect(harness.store.projects.isEmpty)
        #expect(harness.store.sessions.isEmpty)
        #expect(harness.store.tabs.isEmpty)
        #expect(harness.terminal.canCloseRequestCount == 1)
        #expect(harness.terminal.releasedTabIDs == [terminalTab.id])
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
        let fileAccess = LocalWorkspaceFileAccess()
        let fileBuffers = WorkspaceFileBufferController(fileAccess: fileAccess, now: now)
        let externalEditor = FakeExternalEditorOpener()
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

        return CommandServiceHarness(
            store: store,
            persistence: persistence,
            terminal: terminal,
            fileBuffers: fileBuffers,
            externalEditor: externalEditor,
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
}

@MainActor
private struct CommandServiceHarness<Persistence: WorkspacePersistenceStore> {
    let store: WorkspaceStore
    let persistence: Persistence
    let terminal: FakeTerminalSurfaceManager
    let fileBuffers: WorkspaceFileBufferController
    let externalEditor: FakeExternalEditorOpener
    let service: DefaultWorkspaceCommandService
}

@MainActor
private final class FakeTerminalSurfaceManager: WorkspaceTerminalSurfaceManaging {
    private(set) var createdTabs: [WorkspaceTab] = []
    private(set) var focusedTabIDs: [UUID] = []
    private(set) var resizedTabIDs: [UUID] = []
    private(set) var releasedTabIDs: [UUID] = []
    private(set) var canCloseRequestCount = 0
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
        canCloseRequestCount += 1
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
private final class FakeExternalEditorOpener: ExternalEditorOpening {
    private(set) var openedPaths: [String] = []
    var openError: (any Error)?

    func openFile(at path: String) async throws {
        if let openError { throw openError }
        openedPaths.append(path)
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
