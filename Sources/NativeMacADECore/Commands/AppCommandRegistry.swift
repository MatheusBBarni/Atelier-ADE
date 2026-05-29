import Foundation

public enum AppCommandRegistry {
    public static let managedCommandIDs: [AppCommandID] = [
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
    ]

    public static let defaultKeybindings: [AppCommandID: KeybindingOverride] = [
        .previousTab: KeybindingOverride(commandID: .previousTab, keyEquivalent: "["),
        .nextTab: KeybindingOverride(commandID: .nextTab, keyEquivalent: "]"),
        .previousSession: KeybindingOverride(commandID: .previousSession, keyEquivalent: "upArrow"),
        .nextSession: KeybindingOverride(commandID: .nextSession, keyEquivalent: "downArrow"),
        .searchSessions: KeybindingOverride(commandID: .searchSessions, keyEquivalent: "p"),
        .saveFile: KeybindingOverride(commandID: .saveFile, keyEquivalent: "s"),
        .revertFile: KeybindingOverride(commandID: .revertFile, keyEquivalent: "r", modifiers: [.command, .option]),
        .openFileInExternalEditor: KeybindingOverride(commandID: .openFileInExternalEditor, keyEquivalent: "o", modifiers: [.command, .shift]),
        .zoomInTerminal: KeybindingOverride(commandID: .zoomInTerminal, keyEquivalent: "+"),
        .zoomOutTerminal: KeybindingOverride(commandID: .zoomOutTerminal, keyEquivalent: "-"),
        .toggleRightSidebar: KeybindingOverride(commandID: .toggleRightSidebar, keyEquivalent: "l"),
        .openSettings: KeybindingOverride(commandID: .openSettings, keyEquivalent: ",")
    ]

    public static func defaultKeybinding(for commandID: AppCommandID) -> KeybindingOverride {
        guard let keybinding = defaultKeybindings[commandID] else {
            preconditionFailure("Missing default keybinding for managed command \(commandID.rawValue)")
        }
        return keybinding
    }

    public static func resolvedKeybindings(for preferences: AppPreferences) -> [AppCommandID: KeybindingOverride] {
        managedCommandIDs.reduce(into: [:]) { resolvedKeybindings, commandID in
            resolvedKeybindings[commandID] = resolvedKeybinding(for: commandID, preferences: preferences)
        }
    }

    public static func resolvedKeybinding(for commandID: AppCommandID, preferences: AppPreferences) -> KeybindingOverride {
        normalized(preferences.keybindings[commandID] ?? defaultKeybinding(for: commandID), for: commandID)
    }

    public static func resettingOverride(for commandID: AppCommandID, in preferences: AppPreferences) -> AppPreferences {
        var updatedPreferences = preferences
        updatedPreferences.keybindings[commandID] = nil
        return updatedPreferences
    }

    public static func isEnabled(
        _ commandID: AppCommandID,
        selectedTab: WorkspaceTab?,
        selectedFileIsDirty: Bool
    ) -> Bool {
        switch commandID {
        case .saveFile:
            return selectedTab?.kind == .file && selectedFileIsDirty
        case .revertFile, .openFileInExternalEditor:
            return selectedTab?.kind == .file
        case .previousTab,
             .nextTab,
             .previousSession,
             .nextSession,
             .searchSessions,
             .zoomInTerminal,
             .zoomOutTerminal,
             .toggleRightSidebar,
             .openSettings:
            return true
        }
    }

    public static func validate(_ keybindings: [AppCommandID: KeybindingOverride]) throws {
        for (commandID, override) in keybindings where override.commandID != commandID {
            throw WorkspaceCommandError.settingsValidationFailed(.mismatchedKeybindingCommandID(
                expected: commandID,
                actual: override.commandID
            ))
        }

        var signaturesByCommand: [KeybindingSignature: AppCommandID] = [:]
        for commandID in managedCommandIDs {
            let keybinding = keybindings[commandID] ?? defaultKeybinding(for: commandID)
            let signature = try KeybindingSignature(commandID: commandID, keybinding: keybinding)
            if let conflictingCommandID = signaturesByCommand[signature] {
                throw WorkspaceCommandError.settingsValidationFailed(.duplicateManagedKeybinding(
                    commandID: commandID,
                    conflictingCommandID: conflictingCommandID
                ))
            }
            signaturesByCommand[signature] = commandID
        }
    }

    private static func normalized(_ keybinding: KeybindingOverride, for commandID: AppCommandID) -> KeybindingOverride {
        var normalizedKeybinding = keybinding
        normalizedKeybinding.commandID = commandID
        return normalizedKeybinding
    }
}

private struct KeybindingSignature: Hashable {
    let keyEquivalent: String
    let modifiers: Set<KeyModifier>

    init(commandID: AppCommandID, keybinding: KeybindingOverride) throws {
        let trimmedKeyEquivalent = keybinding.keyEquivalent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyEquivalent.isEmpty else {
            throw WorkspaceCommandError.settingsValidationFailed(.emptyKeybinding(commandID))
        }
        keyEquivalent = trimmedKeyEquivalent.lowercased()
        modifiers = Set(keybinding.modifiers)
    }
}
