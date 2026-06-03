import Foundation
import Testing

struct ConfigModalPortableSettingsUIContractIntegrationTests {
    @Test
    func configModalHostsPortableSettingsControlsAndRoutesActionsThroughCommandService() throws {
        let configModalSource = try sourceFile("Sources/NativeMacADE/AppShell/ConfigModalView.swift")
        let portableSectionSource = try sourceFile("Sources/NativeMacADE/AppShell/ConfigModalPortableSettingsSection.swift")

        #expect(configModalSource.contains("ConfigModalPortableSettingsSection("))
        #expect(portableSectionSource.contains("commandService.portableSettingsConfigURL()"))
        #expect(portableSectionSource.contains("NSWorkspace.shared.activateFileViewerSelecting([configURL])"))
        #expect(portableSectionSource.contains("NSWorkspace.shared.open(configURL)"))
        #expect(portableSectionSource.contains("commandService.reloadPortableSettingsConfig()"))
        #expect(portableSectionSource.contains("PortableSettingsApplyStatusPresentation(result: result)"))
        #expect(portableSectionSource.contains("accessibilityIdentifier(\"portable-settings-section\")"))
        #expect(portableSectionSource.contains("accessibilityIdentifier(\"portable-settings-config-path\")"))
    }

    @Test
    func settingsSectionsExposePortableScopeMessagingForV1SupportedSettings() throws {
        let appearanceSource = try sourceFile("Sources/NativeMacADE/AppShell/ConfigModalAppearanceAndShortcutsSection.swift")
        let focusSource = try sourceFile("Sources/NativeMacADE/AppShell/ConfigModalFocusWorkspaceSection.swift")
        let presentationSource = try sourceFile("Sources/NativeMacADECore/Workspace/PortableSettingsPresentation.swift")

        #expect(appearanceSource.contains("scopeLabel: .appearance"))
        #expect(appearanceSource.contains("scopeLabel: .managedShortcuts"))
        #expect(focusSource.contains("PortableSettingsScopeBadgeView(label: .focusWorkspace)"))
        #expect(presentationSource.contains("Theme and terminal font size are written to the personal settings file."))
        #expect(presentationSource.contains("The Focus Workspace on/off setting is part of the portable V1 config."))
        #expect(presentationSource.contains("Managed app-command keyboard shortcuts are written to the personal settings file."))
    }

    @Test
    func agentProfileSectionExplainsMixedPortableAndLocalOnlyScope() throws {
        let agentProfileSource = try sourceFile("Sources/NativeMacADE/AppShell/ConfigModalAgentProfilesSection.swift")
        let presentationSource = try sourceFile("Sources/NativeMacADECore/Workspace/PortableSettingsPresentation.swift")
        let rowStateSource = try sourceFile("Sources/NativeMacADECore/Workspace/AgentProfilePresentation.swift")

        #expect(agentProfileSource.contains("PortableSettingsScopeBadgeView(label: .agentProfilesMixed)"))
        #expect(agentProfileSource.contains("row.portabilitySummary"))
        #expect(agentProfileSource.contains("PortableSettingsScopeBadgeView(label: .agentProfileCommandDetails)"))
        #expect(agentProfileSource.contains("draft.isBuiltIn ? .builtInDefaultProfileSelection : .customDefaultProfileSelection"))
        #expect(presentationSource.contains("Built-in default selection travels. Custom profiles, custom defaults, launch commands, launch arguments, and secret refs stay local-only."))
        #expect(rowStateSource.contains("Custom profile definitions, custom defaults, and command details stay local-only in V1."))
        #expect(rowStateSource.contains("Built-in default selection is portable; edited command details stay local-only in V1."))
    }

    @Test
    func partialApplyReloadFeedbackRendersRejectedSectionsInsteadOfGenericSuccess() throws {
        let portableSectionSource = try sourceFile("Sources/NativeMacADE/AppShell/ConfigModalPortableSettingsSection.swift")
        let presentationSource = try sourceFile("Sources/NativeMacADECore/Workspace/PortableSettingsPresentation.swift")

        #expect(portableSectionSource.contains("PortableSettingsStatusList("))
        #expect(portableSectionSource.contains("title: \"Rejected sections\""))
        #expect(portableSectionSource.contains("details: status.rejectedSectionDetails"))
        #expect(presentationSource.contains("Partial reload applied"))
        #expect(presentationSource.contains("Rejected sections need edits in settings.json."))
        #expect(presentationSource.contains("PortableSettingsSection(rawValue: sectionKey)?.displayTitle"))
    }

    private func sourceFile(_ relativePath: String) throws -> String {
        let fileURL = try packageRoot().appendingPathComponent(relativePath)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    private func packageRoot() throws -> URL {
        var directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        for _ in 0..<6 {
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("Package.swift").path) {
                return directory
            }
            directory.deleteLastPathComponent()
        }
        throw PackageRootError.notFound
    }

    private enum PackageRootError: Error {
        case notFound
    }
}
