import Foundation
import Testing
@testable import NativeMacADECore

struct AppCommandRegistryTests {
    @Test
    func defaultsResolveForEveryManagedCommand() {
        let defaults = AppCommandRegistry.defaultKeybindings

        #expect(AppCommandRegistry.managedCommandIDs == [
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
            .toggleRightSidebar,
            .openSettings
        ])
        #expect(defaults[.previousTab] == KeybindingOverride(commandID: .previousTab, keyEquivalent: "["))
        #expect(defaults[.nextTab] == KeybindingOverride(commandID: .nextTab, keyEquivalent: "]"))
        #expect(defaults[.previousSession] == KeybindingOverride(commandID: .previousSession, keyEquivalent: "upArrow"))
        #expect(defaults[.nextSession] == KeybindingOverride(commandID: .nextSession, keyEquivalent: "downArrow"))
        #expect(defaults[.searchSessions] == KeybindingOverride(commandID: .searchSessions, keyEquivalent: "p"))
        #expect(defaults[.saveFile] == KeybindingOverride(commandID: .saveFile, keyEquivalent: "s"))
        #expect(defaults[.revertFile] == KeybindingOverride(commandID: .revertFile, keyEquivalent: "r", modifiers: [.command, .option]))
        #expect(defaults[.openFileInExternalEditor] == KeybindingOverride(commandID: .openFileInExternalEditor, keyEquivalent: "o", modifiers: [.command, .shift]))
        #expect(defaults[.zoomInTerminal] == KeybindingOverride(commandID: .zoomInTerminal, keyEquivalent: "+"))
        #expect(defaults[.zoomOutTerminal] == KeybindingOverride(commandID: .zoomOutTerminal, keyEquivalent: "-"))
        #expect(defaults[.toggleRightSidebar] == KeybindingOverride(commandID: .toggleRightSidebar, keyEquivalent: "b"))
        #expect(defaults[.openSettings] == KeybindingOverride(commandID: .openSettings, keyEquivalent: ","))
        #expect(AppCommandRegistry.resolvedKeybindings(for: .defaults) == defaults)
    }

    @Test
    func fileCommandEnablementFollowsSelectedFileTabAndDirtyState() {
        let sessionID = UUID()
        let terminalTab = WorkspaceTab(sessionID: sessionID, workingDirectory: "/tmp/project", ordinal: 0)
        let fileTab = WorkspaceTab(
            sessionID: sessionID,
            kind: .file,
            workingDirectory: "/tmp/project",
            fileReference: WorkspaceFileReference(path: "/tmp/project/Sources/App.swift", projectRoot: "/tmp/project"),
            ordinal: 1
        )

        #expect(AppCommandRegistry.isEnabled(.saveFile, selectedTab: nil, selectedFileIsDirty: true) == false)
        #expect(AppCommandRegistry.isEnabled(.saveFile, selectedTab: terminalTab, selectedFileIsDirty: true) == false)
        #expect(AppCommandRegistry.isEnabled(.saveFile, selectedTab: fileTab, selectedFileIsDirty: false) == false)
        #expect(AppCommandRegistry.isEnabled(.saveFile, selectedTab: fileTab, selectedFileIsDirty: true))
        #expect(AppCommandRegistry.isEnabled(.revertFile, selectedTab: fileTab, selectedFileIsDirty: false))
        #expect(AppCommandRegistry.isEnabled(.openFileInExternalEditor, selectedTab: fileTab, selectedFileIsDirty: false))
        #expect(AppCommandRegistry.isEnabled(.revertFile, selectedTab: terminalTab, selectedFileIsDirty: true) == false)
        #expect(AppCommandRegistry.isEnabled(.openFileInExternalEditor, selectedTab: terminalTab, selectedFileIsDirty: true) == false)
    }

    @Test
    func persistedOverridesReplaceOnlyTargetedCommandsAndResetToDefaults() {
        let searchOverride = KeybindingOverride(commandID: .searchSessions, keyEquivalent: "k", modifiers: [.command, .shift])
        let preferences = AppPreferences(keybindings: [.searchSessions: searchOverride])

        let resolved = AppCommandRegistry.resolvedKeybindings(for: preferences)
        let resetPreferences = AppCommandRegistry.resettingOverride(for: .searchSessions, in: preferences)

        #expect(resolved[.searchSessions] == searchOverride)
        #expect(resolved[.nextTab] == AppCommandRegistry.defaultKeybinding(for: .nextTab))
        #expect(resetPreferences.keybindings[.searchSessions] == nil)
        #expect(AppCommandRegistry.resolvedKeybinding(for: .searchSessions, preferences: resetPreferences) == AppCommandRegistry.defaultKeybinding(for: .searchSessions))
    }

    @Test
    func duplicateOverrideSignaturesAreRejectedPredictably() {
        let preferences = AppPreferences(keybindings: [
            .nextTab: KeybindingOverride(commandID: .nextTab, keyEquivalent: "[")
        ])

        #expect(throws: WorkspaceCommandError.settingsValidationFailed(.duplicateManagedKeybinding(
            commandID: .nextTab,
            conflictingCommandID: .previousTab
        ))) {
            try AppCommandRegistry.validate(preferences.keybindings)
        }
    }

    @Test
    func unknownPersistedOverrideEntriesAreIgnoredAndDuplicateKnownEntriesThrow() throws {
        let jsonWithUnknown = """
        [
          {"commandID":"openSettings","keyEquivalent":",","modifiers":["command","shift"]},
          {"commandID":"removedCommand","keyEquivalent":"x","modifiers":["command"]}
        ]
        """
        let decoded = try AppPreferences.decodeKeybindingsJSON(jsonWithUnknown)

        #expect(decoded == [
            .openSettings: KeybindingOverride(commandID: .openSettings, keyEquivalent: ",", modifiers: [.command, .shift])
        ])

        let duplicateJSON = """
        [
          {"commandID":"nextTab","keyEquivalent":"]","modifiers":["command"]},
          {"commandID":"nextTab","keyEquivalent":"rightArrow","modifiers":["command","option"]}
        ]
        """
        #expect(throws: AppPreferencesSerializationError.duplicateCommandID(.nextTab)) {
            try AppPreferences.decodeKeybindingsJSON(duplicateJSON)
        }
    }
}
