import Foundation
import Testing
@testable import NativeMacADECore

struct WorkspaceModelsTests {
    @Test
    func appPreferencesPreserveTypedValueSemanticFieldsAndManagedKeybindings() throws {
        let shortcutID = UUID()
        let updatedAt = Date(timeIntervalSince1970: 1_234)
        let searchOverride = KeybindingOverride(
            commandID: .searchSessions,
            keyEquivalent: "k",
            modifiers: [.command, .shift]
        )
        let zoomOverride = KeybindingOverride(
            commandID: .zoomInTerminal,
            keyEquivalent: "=",
            modifiers: [.command]
        )
        let preferences = AppPreferences(
            themeID: "dracula",
            defaultSessionShortcutID: shortcutID,
            terminalFontSize: 15,
            focusWorkspaceEnabled: true,
            focusWorkspaceContinuityEnabled: true,
            keybindings: [
                .searchSessions: searchOverride,
                .zoomInTerminal: zoomOverride
            ],
            updatedAt: updatedAt
        )

        var copiedPreferences = preferences
        copiedPreferences.themeID = "onedark"
        let decodedKeybindings = try AppPreferences.decodeKeybindingsJSON(preferences.keybindingsJSON)

        #expect(preferences.id == AppPreferences.fixedID)
        #expect(preferences.themeID == "dracula")
        #expect(preferences.defaultSessionShortcutID == shortcutID)
        #expect(preferences.terminalFontSize == 15)
        #expect(preferences.focusWorkspaceEnabled == true)
        #expect(preferences.focusWorkspaceContinuityEnabled == true)
        #expect(AppPreferences.defaultThemeID == AppTheme.systemSelectionID)
        #expect(AppPreferences.defaults.themeID == AppTheme.systemSelectionID)
        #expect(AppPreferences.defaults.terminalFontSize == TerminalAppearance.cursorDefault.fontSize)
        #expect(AppPreferences.defaults.focusWorkspaceEnabled == false)
        #expect(AppPreferences.defaults.focusWorkspaceContinuityEnabled == false)
        #expect(AppPreferences.supportedSelectionIDs == AppTheme.supportedSelectionIDs)
        #expect(AppPreferences.supportedThemeIDs == AppTheme.supportedSelectionIDs)
        #expect(AppPreferences.isSupportedThemeSelectionID(AppTheme.systemSelectionID))
        #expect(AppPreferences.isSupportedThemeSelectionID("dracula"))
        #expect(!AppPreferences.isSupportedThemeSelectionID("missing-theme"))
        #expect(preferences.keybindings[.searchSessions] == searchOverride)
        #expect(preferences.keybindings[.zoomInTerminal] == zoomOverride)
        #expect(preferences.updatedAt == updatedAt)
        #expect(copiedPreferences.themeID == "onedark")
        #expect(copiedPreferences.focusWorkspaceEnabled == true)
        #expect(copiedPreferences.focusWorkspaceContinuityEnabled == true)
        #expect(preferences.themeID == "dracula")
        #expect(decodedKeybindings == preferences.keybindings)
        #expect(AppCommandID.allCases == [
            .openProjectSelector,
            .newPlainTab,
            .newDefaultAgentTab,
            .newAgentTabWithProfile,
            .closeSelectedTab,
            .renameSelectedSession,
            .renameSelectedTab,
            .deleteSelectedSession,
            .previousTab,
            .nextTab,
            .previousSession,
            .nextSession,
            .searchSessions,
            .saveFile,
            .revertFile,
            .openFileInExternalEditor,
            .zoomInTerminal,
            .zoomOutTerminal,
            .toggleLeftSidebar,
            .toggleRightSidebar,
            .openSettings
        ])
        #expect(AppCommandID.newPlainTab.defaultKeybinding.keyEquivalent == "t")
        #expect(AppCommandID.newDefaultAgentTab.defaultKeybinding.modifiers == [.command, .shift])
        #expect(AppCommandID.newAgentTabWithProfile.defaultKeybinding.keyEquivalent == "p")
        #expect(AppCommandID.newAgentTabWithProfile.defaultKeybinding.modifiers == [.command, .shift])
        #expect(AppCommandID.closeSelectedTab.defaultKeybinding.keyEquivalent == "w")
        #expect(AppCommandID.renameSelectedSession.defaultKeybinding.keyEquivalent == "r")
        #expect(AppCommandID.renameSelectedTab.defaultKeybinding.modifiers == [.command, .shift])
        #expect(AppCommandID.deleteSelectedSession.defaultKeybinding.modifiers == [.command, .shift])
        #expect(AppCommandID.openProjectSelector.defaultKeybinding.keyEquivalent == "o")
        #expect(AppCommandID.toggleLeftSidebar.defaultKeybinding.keyEquivalent == "b")
        #expect(AppCommandID.openSettings.defaultKeybinding.keyEquivalent == ",")
        #expect(AppCommandID.toggleRightSidebar.defaultKeybinding.keyEquivalent == "l")
        #expect(AppCommandID.toggleRightSidebar.defaultKeybinding.modifiers == [.command])
    }

    @Test
    func sessionShortcutHasUserOverridePreservesBuiltInAndCustomState() {
        let builtInShortcut = SessionShortcut(
            label: "Codex",
            launchCommand: "codex",
            launchArgumentsJSON: "[]",
            isBuiltIn: true,
            hasUserOverride: true
        )
        let customShortcut = SessionShortcut(
            label: "Review",
            launchCommand: "claude",
            launchArgumentsJSON: "[\"--continue\"]",
            hasUserOverride: false
        )

        #expect(builtInShortcut.isBuiltIn == true)
        #expect(builtInShortcut.hasUserOverride == true)
        #expect(customShortcut.isBuiltIn == false)
        #expect(customShortcut.hasUserOverride == false)
        #expect(SessionShortcut.builtInDefaults.allSatisfy { $0.isBuiltIn && !$0.hasUserOverride })
    }

    @Test
    func inMemoryPersistencePreservesAppPreferencesAndShortcutOverrideState() async throws {
        let shortcut = SessionShortcut(
            label: "OpenCode",
            launchCommand: "opencode",
            launchArgumentsJSON: "[]",
            isBuiltIn: true,
            hasUserOverride: true
        )
        let preferences = AppPreferences(
            themeID: "catppuccin",
            defaultSessionShortcutID: shortcut.id,
            terminalFontSize: 14,
            focusWorkspaceEnabled: true,
            focusWorkspaceContinuityEnabled: true,
            keybindings: [
                .nextTab: KeybindingOverride(commandID: .nextTab, keyEquivalent: "rightArrow", modifiers: [.command, .option])
            ],
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let store = InMemoryWorkspacePersistenceStore(
            shortcuts: [shortcut],
            appPreferences: preferences
        )

        #expect(try await store.loadAppPreferences() == preferences)
        #expect(try await store.loadSessionShortcuts() == [shortcut])

        var updatedPreferences = preferences
        updatedPreferences.themeID = "cursor"
        updatedPreferences.defaultSessionShortcutID = nil
        updatedPreferences.terminalFontSize = 16
        updatedPreferences.focusWorkspaceEnabled = false
        updatedPreferences.focusWorkspaceContinuityEnabled = false
        try await store.save(appPreferences: updatedPreferences)

        var updatedShortcut = shortcut
        updatedShortcut.hasUserOverride = false
        try await store.save(shortcut: updatedShortcut)

        #expect(try await store.loadAppPreferences() == updatedPreferences)
        #expect(try await store.loadSessionShortcuts() == [updatedShortcut])
    }

    @Test
    func deletingShortcutInMemoryClearsMatchingDefaultSessionShortcutID() async throws {
        let shortcut = SessionShortcut(label: "Codex", launchCommand: "codex")
        let session = WorkspaceSession(projectID: UUID(), title: "Shortcut", shortcutID: shortcut.id)
        let tab = WorkspaceTab(
            sessionID: session.id,
            workingDirectory: "/Users/example/project",
            shortcutID: shortcut.id,
            launchCommand: "codex",
            ordinal: 0
        )
        let preferences = AppPreferences(
            defaultSessionShortcutID: shortcut.id,
            focusWorkspaceEnabled: true,
            focusWorkspaceContinuityEnabled: true,
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )
        let store = InMemoryWorkspacePersistenceStore(
            sessions: [session],
            tabs: [tab],
            shortcuts: [shortcut],
            appPreferences: preferences
        )

        try await store.deleteShortcut(id: shortcut.id)

        #expect(try await store.loadAppPreferences().defaultSessionShortcutID == nil)
        #expect(try await store.loadAppPreferences().focusWorkspaceEnabled == true)
        #expect(try await store.loadAppPreferences().focusWorkspaceContinuityEnabled == true)
        #expect(try await store.loadSessions().first?.shortcutID == nil)
        #expect(try await store.loadTabs().first?.shortcutID == nil)
    }

    @Test
    func inMemoryPersistencePreservesMixedTabMetadata() async throws {
        let sessionID = UUID()
        let projectRoot = "/Users/example/project"
        let terminalTab = WorkspaceTab(
            sessionID: sessionID,
            workingDirectory: projectRoot,
            ordinal: 0
        )
        let fileReference = WorkspaceFileReference(
            path: "/Users/example/project/Package.swift",
            projectRoot: projectRoot
        )
        let fileTab = WorkspaceTab(
            sessionID: sessionID,
            kind: .file,
            workingDirectory: projectRoot,
            fileReference: fileReference,
            ordinal: 1
        )
        let store = InMemoryWorkspacePersistenceStore(tabs: [fileTab, terminalTab])

        let loadedTabs = try await store.loadTabs()

        #expect(loadedTabs.map(\.id) == [terminalTab.id, fileTab.id])
        #expect(loadedTabs.map(\.kind) == [.terminal, .file])
        #expect(loadedTabs.last?.fileReference == fileReference)
    }

    @Test
    func inMemoryProjectOrderSaveRewritesDenseSortIndexes() async throws {
        let firstProject = WorkspaceProject(
            path: "/Users/example/first",
            displayName: "first",
            lastOpenedAt: Date(timeIntervalSince1970: 300),
            sortIndex: 10
        )
        let secondProject = WorkspaceProject(
            path: "/Users/example/second",
            displayName: "second",
            lastOpenedAt: Date(timeIntervalSince1970: 200),
            sortIndex: 20
        )
        let thirdProject = WorkspaceProject(
            path: "/Users/example/third",
            displayName: "third",
            lastOpenedAt: Date(timeIntervalSince1970: 100),
            sortIndex: 30
        )
        let store = InMemoryWorkspacePersistenceStore(projects: [firstProject, secondProject, thirdProject])

        try await store.saveProjectOrder([thirdProject.id, firstProject.id, secondProject.id])

        let loadedProjects = try await store.loadProjects()
        #expect(loadedProjects.map(\.id) == [thirdProject.id, firstProject.id, secondProject.id])
        #expect(loadedProjects.map(\.sortIndex) == [0, 1, 2])
    }

    @Test
    func inMemoryTabOrderSaveRewritesVisibleTabsAndStableHiddenTail() async throws {
        let sessionID = UUID()
        let otherSessionID = UUID()
        let visibleFirst = WorkspaceTab(
            sessionID: sessionID,
            workingDirectory: "/Users/example/project",
            ordinal: 10
        )
        let visibleSecond = WorkspaceTab(
            sessionID: sessionID,
            workingDirectory: "/Users/example/project",
            ordinal: 20
        )
        let hiddenPersisted = WorkspaceTab(
            sessionID: sessionID,
            workingDirectory: "/Users/example/project",
            ordinal: 30
        )
        let otherSessionTab = WorkspaceTab(
            sessionID: otherSessionID,
            workingDirectory: "/Users/example/other",
            ordinal: 0
        )
        let store = InMemoryWorkspacePersistenceStore(tabs: [
            hiddenPersisted,
            visibleFirst,
            visibleSecond,
            otherSessionTab
        ])

        try await store.saveTabOrder(
            SessionTabReorderPlan(
                sessionID: sessionID,
                visibleTabIDs: [visibleSecond.id, visibleFirst.id],
                hiddenPersistedTabIDs: [hiddenPersisted.id]
            ),
            snapshot: RestoreSnapshot(
                selectedProjectID: nil,
                selectedSessionID: sessionID,
                selectedTabID: visibleSecond.id,
                tabOrder: [visibleSecond.id, visibleFirst.id, hiddenPersisted.id],
                updatedAt: Date(timeIntervalSince1970: 500)
            )
        )

        let loadedTabs = try await store.loadTabs()
        let sessionTabs = loadedTabs.filter { $0.sessionID == sessionID }
        let otherSessionTabs = loadedTabs.filter { $0.sessionID == otherSessionID }

        #expect(sessionTabs.map(\.id) == [visibleSecond.id, visibleFirst.id, hiddenPersisted.id])
        #expect(sessionTabs.map(\.ordinal) == [0, 1, 2])
        #expect(otherSessionTabs.map(\.id) == [otherSessionTab.id])
        #expect(otherSessionTabs.map(\.ordinal) == [0])
    }

    @Test
    func inMemoryTabOrderSaveUpdatesRestoreSnapshotOrder() async throws {
        let sessionID = UUID()
        let firstTab = WorkspaceTab(
            sessionID: sessionID,
            workingDirectory: "/Users/example/project",
            ordinal: 0
        )
        let secondTab = WorkspaceTab(
            sessionID: sessionID,
            workingDirectory: "/Users/example/project",
            ordinal: 1
        )
        let originalSnapshot = RestoreSnapshot(
            selectedProjectID: nil,
            selectedSessionID: sessionID,
            selectedTabID: firstTab.id,
            tabOrder: [firstTab.id, secondTab.id],
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let updatedSnapshot = RestoreSnapshot(
            selectedProjectID: nil,
            selectedSessionID: sessionID,
            selectedTabID: secondTab.id,
            tabOrder: [secondTab.id, firstTab.id],
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let store = InMemoryWorkspacePersistenceStore(
            tabs: [firstTab, secondTab],
            restoreSnapshot: originalSnapshot
        )

        try await store.saveTabOrder(
            SessionTabReorderPlan(
                sessionID: sessionID,
                visibleTabIDs: [secondTab.id, firstTab.id]
            ),
            snapshot: updatedSnapshot
        )

        #expect(try await store.loadRestoreSnapshot() == updatedSnapshot)
        #expect(try await store.loadRestoreSnapshot()?.tabOrder == [secondTab.id, firstTab.id])
    }

    @Test
    func defaultSessionNamingUsesMonthDayHourMinuteUntilRename() {
        let date = Date(timeIntervalSince1970: 1_717_393_500) // 2024-06-03 05:45 UTC
        let projectID = UUID()
        var session = WorkspaceSession(
            projectID: projectID,
            title: nil,
            createdAt: date,
            lastActivatedAt: date
        )

        #expect(WorkspaceSession.defaultTitle(for: date, timeZone: TimeZone(secondsFromGMT: 0)!) == "06-03 05:45")
        #expect(session.title == WorkspaceSession.defaultTitle(for: date))
        #expect(session.isUserNamed == false)

        session.rename(to: "Investigate parser")

        #expect(session.title == "Investigate parser")
        #expect(session.isUserNamed == true)
    }

    @Test
    func tabMetadataPreservesRelaunchFieldsAndOrdering() {
        let sessionID = UUID()
        let shortcutID = UUID()
        let createdAt = Date(timeIntervalSince1970: 100)
        let activatedAt = Date(timeIntervalSince1970: 200)

        let tab = WorkspaceTab(
            sessionID: sessionID,
            workingDirectory: "/Users/example/project",
            title: "Review shell",
            shortcutID: shortcutID,
            launchCommand: "codex",
            launchArgumentsJSON: "[\"--ask-for-approval\",\"never\"]",
            ordinal: 2,
            createdAt: createdAt,
            lastActivatedAt: activatedAt
        )

        #expect(tab.sessionID == sessionID)
        #expect(tab.workingDirectory == "/Users/example/project")
        #expect(tab.title == "Review shell")
        #expect(tab.shortcutID == shortcutID)
        #expect(tab.launchCommand == "codex")
        #expect(tab.launchArgumentsJSON == "[\"--ask-for-approval\",\"never\"]")
        #expect(tab.ordinal == 2)
        #expect(tab.createdAt == createdAt)
        #expect(tab.lastActivatedAt == activatedAt)
        #expect(tab.kind == .terminal)
        #expect(tab.fileReference == nil)
    }

    @Test
    func terminalTabCodableRoundTripPreservesShortcutIDAndDefaultsLegacyMissingToNil() throws {
        let shortcutID = UUID()
        let tab = WorkspaceTab(
            sessionID: UUID(),
            workingDirectory: "/Users/example/project",
            shortcutID: shortcutID,
            launchCommand: "claude-dev",
            ordinal: 0,
            createdAt: Date(timeIntervalSince1970: 100),
            lastActivatedAt: Date(timeIntervalSince1970: 200)
        )

        let encoded = try JSONEncoder().encode(tab)
        let decoded = try JSONDecoder().decode(WorkspaceTab.self, from: encoded)
        var legacyPayload = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyPayload.removeValue(forKey: "shortcutID")
        let legacyEncoded = try JSONSerialization.data(withJSONObject: legacyPayload)
        let legacyDecoded = try JSONDecoder().decode(WorkspaceTab.self, from: legacyEncoded)

        #expect(decoded == tab)
        #expect(decoded.shortcutID == shortcutID)
        #expect(legacyDecoded.shortcutID == nil)
    }

    @Test
    func terminalTabCodableRoundTripDefaultsToTerminalKindWithoutFileMetadata() throws {
        let tab = WorkspaceTab(
            sessionID: UUID(),
            workingDirectory: "/Users/example/project",
            launchCommand: "codex",
            launchArgumentsJSON: "[]",
            ordinal: 0,
            createdAt: Date(timeIntervalSince1970: 100),
            lastActivatedAt: Date(timeIntervalSince1970: 200)
        )

        let encoded = try JSONEncoder().encode(tab)
        var legacyPayload = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyPayload.removeValue(forKey: "kind")
        legacyPayload.removeValue(forKey: "fileReference")
        let legacyEncoded = try JSONSerialization.data(withJSONObject: legacyPayload)

        let decoded = try JSONDecoder().decode(WorkspaceTab.self, from: legacyEncoded)

        #expect(decoded == tab)
        #expect(decoded.kind == .terminal)
        #expect(decoded.fileReference == nil)
    }

    @Test
    func fileTabCodableRoundTripPreservesFileReferenceFields() throws {
        let projectRoot = "/Users/example/project"
        let fileReference = WorkspaceFileReference(
            path: "/Users/example/project/Sources/App.swift",
            projectRoot: projectRoot
        )
        let tab = WorkspaceTab(
            sessionID: UUID(),
            kind: .file,
            workingDirectory: projectRoot,
            fileReference: fileReference,
            ordinal: 1,
            createdAt: Date(timeIntervalSince1970: 300),
            lastActivatedAt: Date(timeIntervalSince1970: 400)
        )

        let encoded = try JSONEncoder().encode(tab)
        let decoded = try JSONDecoder().decode(WorkspaceTab.self, from: encoded)

        #expect(decoded == tab)
        #expect(decoded.kind == .file)
        #expect(decoded.fileReference?.path == fileReference.path)
        #expect(decoded.fileReference?.projectRoot == fileReference.projectRoot)
    }

    @Test
    func restoreSnapshotSerializationPreservesSelectionAndTabOrder() throws {
        let projectID = UUID()
        let sessionID = UUID()
        let firstTabID = UUID()
        let secondTabID = UUID()
        let snapshot = RestoreSnapshot(
            selectedProjectID: projectID,
            selectedSessionID: sessionID,
            selectedTabID: secondTabID,
            tabOrder: [firstTabID, secondTabID],
            updatedAt: Date(timeIntervalSince1970: 300)
        )

        let encoded = try snapshot.tabOrderJSON
        let decoded = try RestoreSnapshot.decodeTabOrderJSON(encoded)

        #expect(snapshot.selectedProjectID == projectID)
        #expect(snapshot.selectedSessionID == sessionID)
        #expect(snapshot.selectedTabID == secondTabID)
        #expect(decoded == [firstTabID, secondTabID])
        #expect(snapshot.openTabIDs == [firstTabID, secondTabID])
    }
}
