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
    func invalidAppearanceSectionDoesNotBlockValidBehaviorProjection() {
        let basePreferences = AppPreferences(
            themeID: "cursor",
            terminalFontSize: 13,
            focusWorkspaceEnabled: false
        )
        let config = PortableSettingsConfig(
            appearance: PortableAppearanceConfig(themeID: "missing-theme", terminalFontSize: 18),
            behavior: PortableBehaviorConfig(focusWorkspaceEnabled: true)
        )

        let projection = config.projectedPreferences(from: basePreferences)

        #expect(projection.preferences.themeID == "cursor")
        #expect(projection.preferences.terminalFontSize == 13)
        #expect(projection.preferences.focusWorkspaceEnabled)
        #expect(projection.result.appliedSections == [.behavior])
        #expect(projection.result.rejectedSections["appearance"] == "unknown_theme_id:missing-theme")
        #expect(projection.result.skippedSections == [.defaultProfile, .keybindings])
    }

    @Test
    func outOfRangePortableTerminalFontSizeRejectsAppearanceSectionInCore() {
        let basePreferences = AppPreferences(themeID: "cursor", terminalFontSize: 13)
        let config = PortableSettingsConfig(
            appearance: PortableAppearanceConfig(themeID: "dracula", terminalFontSize: 30),
            behavior: PortableBehaviorConfig(focusWorkspaceEnabled: true)
        )

        let projection = config.projectedPreferences(from: basePreferences)

        #expect(projection.preferences.themeID == "cursor")
        #expect(projection.preferences.terminalFontSize == 13)
        #expect(projection.preferences.focusWorkspaceEnabled)
        #expect(projection.result.appliedSections == [.behavior])
        #expect(projection.result.rejectedSections["appearance"]?.contains("terminal_font_size_out_of_range:30.0") == true)
    }

    @Test
    func invalidPortableKeybindingSectionsDoNotMutateExistingRuntimeOverrides() {
        let existingOverride = KeybindingOverride(
            commandID: .openSettings,
            keyEquivalent: ".",
            modifiers: [.command, .shift]
        )
        let basePreferences = AppPreferences(keybindings: [.openSettings: existingOverride])
        let duplicateCommandConfig = PortableSettingsConfig(
            keybindings: [
                PortableKeybindingOverride(commandID: AppCommandID.openSettings.rawValue, keyEquivalent: "a"),
                PortableKeybindingOverride(commandID: AppCommandID.openSettings.rawValue, keyEquivalent: "b")
            ],
            keybindingsSectionPresent: true
        )
        let emptyKeyConfig = PortableSettingsConfig(
            keybindings: [
                PortableKeybindingOverride(commandID: AppCommandID.searchSessions.rawValue, keyEquivalent: "  ")
            ],
            keybindingsSectionPresent: true
        )

        let duplicateProjection = duplicateCommandConfig.projectedPreferences(from: basePreferences)
        let emptyProjection = emptyKeyConfig.projectedPreferences(from: basePreferences)

        #expect(duplicateProjection.preferences.keybindings == [.openSettings: existingOverride])
        #expect(duplicateProjection.result.rejectedSections["keybindings"] == "duplicate_command_id:openSettings")
        #expect(emptyProjection.preferences.keybindings == [.openSettings: existingOverride])
        #expect(emptyProjection.result.rejectedSections["keybindings"] == "empty_keybinding:searchSessions")
    }

    @Test
    func portableDefaultProfileProjectionMapsBuiltInsAndRejectsCustomIdentifiers() throws {
        let codex = try #require(PortableDefaultProfileIdentifier.codex.runtimeDefaultSessionShortcutID)
        let basePreferences = AppPreferences(defaultSessionShortcutID: codex)

        let expected: [(PortableDefaultProfileIdentifier, UUID?)] = [
            (.plain, nil),
            (.codex, PortableDefaultProfileIdentifier.codex.runtimeDefaultSessionShortcutID),
            (.claude, PortableDefaultProfileIdentifier.claude.runtimeDefaultSessionShortcutID),
            (.opencode, PortableDefaultProfileIdentifier.opencode.runtimeDefaultSessionShortcutID)
        ]

        for (identifier, shortcutID) in expected {
            let projection = PortableSettingsConfig(defaultProfile: identifier)
                .projectedPreferences(from: basePreferences)

            #expect(projection.preferences.defaultSessionShortcutID == shortcutID)
            #expect(projection.result.appliedSections == [.defaultProfile])
        }

        let customProjection = PortableSettingsConfig(defaultProfile: PortableDefaultProfileIdentifier(rawValue: "local-reviewer"))
            .projectedPreferences(from: basePreferences)

        #expect(customProjection.preferences.defaultSessionShortcutID == codex)
        #expect(customProjection.result.rejectedSections["defaultProfile"] == "unsupported_default_profile:local-reviewer")
    }

    @Test
    func portableExportOmitsCustomDefaultProfileAndLocalOnlyCommandState() throws {
        let customDefaultProfileID = UUID()
        let preferences = AppPreferences(
            themeID: "dracula",
            defaultSessionShortcutID: customDefaultProfileID,
            terminalFontSize: 16,
            focusWorkspaceEnabled: true,
            keybindings: [
                .openSettings: KeybindingOverride(commandID: .openSettings, keyEquivalent: ".", modifiers: [.command])
            ]
        )

        let config = preferences.portableSettingsConfig
        let json = String(decoding: try JSONEncoder().encode(config), as: UTF8.self)

        #expect(config.appearance == PortableAppearanceConfig(themeID: "dracula", terminalFontSize: 16))
        #expect(config.behavior == PortableBehaviorConfig(focusWorkspaceEnabled: true))
        #expect(config.defaultProfile == nil)
        #expect(config.keybindingsSectionPresent)
        #expect(config.keybindings == [
            PortableKeybindingOverride(commandID: AppCommandID.openSettings.rawValue, keyEquivalent: ".", modifiers: [.command])
        ])
        #expect(json.contains("defaultProfile") == false)
        #expect(json.contains(customDefaultProfileID.uuidString) == false)
        #expect(json.contains("launchCommand") == false)
        #expect(json.contains("launchArgumentsJSON") == false)
        #expect(json.contains("secretRef") == false)
    }

    @Test
    func workspaceSettingsValidationFailuresExposeStableDiagnosticReasons() {
        let shortcutID = UUID(uuidString: "99999999-9999-4999-8999-999999999999")!

        #expect(WorkspaceSettingsValidationFailure.unknownThemeID("missing").diagnosticReason == "unknown_theme_id:missing")
        #expect(WorkspaceSettingsValidationFailure.terminalFontSizeOutOfBounds(
            value: 30,
            minimum: AppPreferences.minimumTerminalFontSize,
            maximum: AppPreferences.maximumTerminalFontSize
        ).diagnosticReason == "terminal_font_size_out_of_range:30.0:min:11.0:max:24.0")
        #expect(WorkspaceSettingsValidationFailure.unknownDefaultSessionShortcut(shortcutID).diagnosticReason == "unknown_default_profile:\(shortcutID.uuidString)")
        #expect(WorkspaceSettingsValidationFailure.duplicateManagedKeybinding(
            commandID: .nextTab,
            conflictingCommandID: .previousTab
        ).diagnosticReason == "duplicate_managed_keybinding:nextTab:previousTab")
        #expect(WorkspaceSettingsValidationFailure.mismatchedKeybindingCommandID(
            expected: .openSettings,
            actual: .searchSessions
        ).diagnosticReason == "mismatched_keybinding_command_id:openSettings:searchSessions")
        #expect(WorkspaceSettingsValidationFailure.emptyKeybinding(.openSettings).diagnosticReason == "empty_keybinding:openSettings")
        #expect(WorkspaceSettingsValidationFailure.malformedLaunchArgumentsJSON(shortcutID).diagnosticReason == "malformed_launch_arguments_json:\(shortcutID.uuidString)")
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

    @Test
    func portableScopeLabelsIdentifyV1AppearanceBehaviorAndManagedShortcuts() {
        #expect(PortableSettingsScopeKind.portableV1.badgeTitle == "Portable V1")
        #expect(PortableSettingsScopeKind.localOnlyV1.badgeTitle == "Local-only V1")
        #expect(PortableSettingsScopeKind.mixedV1.badgeTitle == "Mixed scope")
        #expect(PortableSettingsScopeLabel.appearance.kind == .portableV1)
        #expect(PortableSettingsScopeLabel.appearance.detail.contains("Theme"))
        #expect(PortableSettingsScopeLabel.focusWorkspace.kind == .portableV1)
        #expect(PortableSettingsScopeLabel.focusWorkspace.detail.contains("Focus Workspace"))
        #expect(PortableSettingsScopeLabel.managedShortcuts.kind == .portableV1)
        #expect(PortableSettingsScopeLabel.managedShortcuts.detail.contains("Managed app-command keyboard shortcuts"))
        #expect(PortableSettingsScopeLabel.agentProfilesMixed.kind == .mixedV1)
        #expect(PortableSettingsScopeLabel.agentProfileCommandDetails.kind == .localOnlyV1)
        #expect(PortableSettingsScopeLabel.builtInDefaultProfileSelection.kind == .portableV1)
        #expect(PortableSettingsScopeLabel.customDefaultProfileSelection.kind == .localOnlyV1)
        #expect(PortableSettingsSection.appearance.displayTitle == "Appearance")
        #expect(PortableSettingsSection.behavior.displayTitle == "Focus Workspace")
        #expect(PortableSettingsSection.defaultProfile.displayTitle == "Built-in default profile")
        #expect(PortableSettingsSection.keybindings.displayTitle == "Keyboard Shortcuts")
    }

    @Test
    func portableReloadStatusFormattingSurfacesRejectedSectionDetails() {
        let result = PortableSettingsApplyResult(
            appliedSections: [.appearance, .behavior],
            rejectedSections: [
                "defaultProfile": "unsupported_default_profile:local-reviewer",
                "keybindings": "duplicate_command_id:openSettings"
            ]
        )

        let presentation = PortableSettingsApplyStatusPresentation(result: result)

        #expect(presentation.kind == .partial)
        #expect(presentation.title == "Partial reload applied")
        #expect(presentation.appliedSectionDetails == ["Appearance", "Focus Workspace"])
        #expect(presentation.rejectedSectionDetails == [
            "Built-in default profile: unsupported_default_profile:local-reviewer",
            "Keyboard Shortcuts: duplicate_command_id:openSettings"
        ])
    }

    @Test
    func portableReloadStatusFormattingDistinguishesMissingFileAndExplicitFailures() {
        let idle = PortableSettingsApplyStatusPresentation.idle
        let success = PortableSettingsApplyStatusPresentation(result: PortableSettingsApplyResult(
            appliedSections: [.keybindings]
        ))
        let emptySuccess = PortableSettingsApplyStatusPresentation(result: PortableSettingsApplyResult())
        let seeded = PortableSettingsApplyStatusPresentation(result: PortableSettingsApplyResult(
            appliedSections: [.appearance],
            seededFromSQLite: true
        ))
        let missingFile = PortableSettingsApplyStatusPresentation(result: PortableSettingsApplyResult(
            skippedSections: PortableSettingsConfig.supportedTopLevelSections,
            fileMissing: true
        ))
        let unknownRejectedSection = PortableSettingsApplyResult(
            rejectedSections: ["futureSection": "unsupported_section"]
        )
        let failure = PortableSettingsApplyStatusPresentation.failure(message: "decode_failed")

        #expect(idle.kind == .idle)
        #expect(idle.title == "No reload run")
        #expect(success.kind == .success)
        #expect(success.summary == "Applied Keyboard Shortcuts.")
        #expect(emptySuccess.kind == .success)
        #expect(emptySuccess.summary == "Reload finished with no portable sections to apply.")
        #expect(seeded.title == "Portable file seeded")
        #expect(missingFile.kind == .missingFile)
        #expect(missingFile.title == "Portable file not found")
        #expect(missingFile.summary.contains("No portable settings file exists yet"))
        #expect(unknownRejectedSection.rejectedSectionDetails == ["futureSection: unsupported_section"])
        #expect(failure.kind == .failure)
        #expect(failure.rejectedSectionDetails == ["decode_failed"])
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
