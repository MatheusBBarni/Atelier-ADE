import Foundation
import Testing
@testable import NativeMacADECore

struct PortableSettingsConfigTests {
    @Test
    func jsonRoundTripPreservesSupportedSectionsAndKeybindingOrder() throws {
        let config = PortableSettingsConfig(
            appearance: PortableAppearanceConfig(themeID: "dracula", terminalFontSize: 16),
            behavior: PortableBehaviorConfig(focusWorkspaceEnabled: true),
            defaultProfile: .claude,
            keybindings: [
                PortableKeybindingOverride(commandID: AppCommandID.openSettings.rawValue, keyEquivalent: ".", modifiers: [.command]),
                PortableKeybindingOverride(commandID: AppCommandID.searchSessions.rawValue, keyEquivalent: "k", modifiers: [.command, .shift])
            ]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]

        let data = try encoder.encode(config)
        let json = String(decoding: data, as: UTF8.self)
        let decoded = try JSONDecoder().decode(PortableSettingsConfig.self, from: data)

        #expect(decoded == config)
        #expect(decoded.keybindings.map(\.commandID) == [
            AppCommandID.openSettings.rawValue,
            AppCommandID.searchSessions.rawValue
        ])
        #expect(PortableSettingsConfig.supportedTopLevelSections == [
            .appearance,
            .behavior,
            .defaultProfile,
            .keybindings
        ])
        #expect(jsonContainsKeys(
            ["\"version\"", "\"appearance\"", "\"behavior\"", "\"defaultProfile\"", "\"keybindings\""],
            in: json
        ))
    }

    @Test
    func symbolicBuiltInIdentifiersMapToCanonicalRuntimeTargetsWithoutSerializingUUIDs() throws {
        let encoder = JSONEncoder()
        let config = PortableSettingsConfig(defaultProfile: .codex)
        let json = String(decoding: try encoder.encode(config), as: UTF8.self)

        #expect(PortableDefaultProfileIdentifier.identifier(forDefaultSessionShortcutID: nil) == .plain)
        #expect(PortableDefaultProfileIdentifier.plain.runtimeDefaultSessionShortcutID == nil)
        #expect(PortableDefaultProfileIdentifier.plain.runtimeTarget == .plain)

        for identifier in PortableDefaultProfileIdentifier.builtInIdentifiers {
            let shortcut = try #require(identifier.canonicalBuiltInShortcut)
            #expect(identifier.runtimeDefaultSessionShortcutID == shortcut.id)
            #expect(identifier.runtimeTarget.shortcut == shortcut)
            #expect(PortableDefaultProfileIdentifier.identifier(forDefaultSessionShortcutID: shortcut.id) == identifier)
            #expect(PortableDefaultProfileIdentifier.identifier(forBuiltInShortcut: shortcut) == identifier)
            #expect(shortcut.portableDefaultProfileIdentifier == identifier)
        }

        #expect(json.contains("\"codex\""))
        #expect(json.contains("defaultSessionShortcutID") == false)
        for shortcut in SessionShortcut.builtInDefaults {
            #expect(json.contains(shortcut.id.uuidString) == false)
        }
    }

    @Test
    func portableKeybindingOverridesAcceptManagedCommandIDsAndRejectUnsupportedCommands() throws {
        let validOverrides = [
            PortableKeybindingOverride(commandID: AppCommandID.openSettings.rawValue, keyEquivalent: ".", modifiers: [.command])
        ]
        let runtimeOverrides = try PortableKeybindingOverride.runtimeOverrides(from: validOverrides)

        #expect(runtimeOverrides == [
            .openSettings: KeybindingOverride(commandID: .openSettings, keyEquivalent: ".", modifiers: [.command])
        ])
        #expect(validOverrides.first?.managedCommandID == .openSettings)

        #expect(throws: PortableSettingsValidationError.unsupportedCommandID("removedCommand")) {
            try PortableKeybindingOverride.runtimeOverrides(from: [
                PortableKeybindingOverride(commandID: "removedCommand", keyEquivalent: "x")
            ])
        }

        #expect(throws: PortableSettingsValidationError.duplicateCommandID(.openSettings)) {
            try PortableKeybindingOverride.runtimeOverrides(from: [
                PortableKeybindingOverride(commandID: AppCommandID.openSettings.rawValue, keyEquivalent: "."),
                PortableKeybindingOverride(commandID: AppCommandID.openSettings.rawValue, keyEquivalent: ",")
            ])
        }
    }

    @Test
    func runtimeOnlyAndLocalOnlyFieldsStayOutOfPortableJSONContract() throws {
        let config = PortableSettingsConfig(
            appearance: PortableAppearanceConfig(themeID: AppTheme.systemSelectionID, terminalFontSize: 13),
            behavior: PortableBehaviorConfig(focusWorkspaceEnabled: false),
            defaultProfile: .opencode,
            keybindings: [
                PortableKeybindingOverride(commandID: AppCommandID.openSettings.rawValue, keyEquivalent: ",")
            ]
        )
        let json = String(decoding: try JSONEncoder().encode(config), as: UTF8.self)

        #expect(PortableSettingsConfig.excludedRuntimeAndLocalFieldNames.isSuperset(of: [
            "id",
            "updatedAt",
            "defaultSessionShortcutID",
            "launchCommand",
            "launchArgumentsJSON",
            "secretRef",
            "hasUserOverride"
        ]))

        for fieldName in PortableSettingsConfig.excludedRuntimeAndLocalFieldNames {
            #expect(json.contains("\"\(fieldName)\"") == false)
        }
    }

    @Test
    func applyResultReportsAppliedRejectedSkippedAndBootstrapStates() throws {
        var result = PortableSettingsApplyResult(seededFromSQLite: true, fileMissing: false)

        result.recordApplied(.appearance)
        result.recordRejected(.keybindings, reason: "duplicate_managed_keybinding")
        result.recordSkipped(.defaultProfile)

        let decoded = try JSONDecoder().decode(
            PortableSettingsApplyResult.self,
            from: try JSONEncoder().encode(result)
        )

        #expect(decoded.appliedSections == [.appearance])
        #expect(decoded.rejectedSections == ["keybindings": "duplicate_managed_keybinding"])
        #expect(decoded.skippedSections == [.defaultProfile])
        #expect(decoded.seededFromSQLite)
        #expect(decoded.fileMissing == false)
        #expect(decoded.hasRejectedSections)
    }
}

private func jsonContainsKeys(_ keys: [String], in json: String) -> Bool {
    for key in keys {
        guard json.range(of: key) != nil else {
            return false
        }
    }
    return true
}
