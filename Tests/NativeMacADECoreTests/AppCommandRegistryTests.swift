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
        #expect(defaults[.zoomInTerminal] == KeybindingOverride(commandID: .zoomInTerminal, keyEquivalent: "+"))
        #expect(defaults[.zoomOutTerminal] == KeybindingOverride(commandID: .zoomOutTerminal, keyEquivalent: "-"))
        #expect(defaults[.toggleRightSidebar] == KeybindingOverride(commandID: .toggleRightSidebar, keyEquivalent: "l"))
        #expect(defaults[.openSettings] == KeybindingOverride(commandID: .openSettings, keyEquivalent: ","))
        #expect(AppCommandRegistry.resolvedKeybindings(for: .defaults) == defaults)
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
