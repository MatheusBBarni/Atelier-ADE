import Foundation
import Testing

struct FocusWorkspaceUIContractIntegrationTests {
    @Test
    func configModalComposesDedicatedFocusWorkspaceSectionUsingPreferencesPipeline() throws {
        let configModalSource = try sourceFile("Sources/NativeMacADE/AppShell/ConfigModalView.swift")
        let focusSectionSource = try sourceFile("Sources/NativeMacADE/AppShell/ConfigModalFocusWorkspaceSection.swift")

        #expect(configModalSource.contains("ConfigModalFocusWorkspaceSection("))
        #expect(focusSectionSource.contains("FocusWorkspaceSettingsPresentation(preferences: store.appPreferences)"))
        #expect(focusSectionSource.contains("commandService.loadAppPreferences()"))
        #expect(focusSectionSource.contains("commandService.saveAppPreferences(preferences)"))
        #expect(focusSectionSource.contains("FocusWorkspaceSettingsPresentation.legacyDetail"))
        #expect(focusSectionSource.contains("FocusWorkspaceSettingsPresentation.fileDetail"))
        #expect(focusSectionSource.contains("accessibilityIdentifier(\"focus-workspace-settings-section\")"))
    }

    @Test
    func shellHeaderComposesFocusWorkspaceActiveCueFromAppPreferences() throws {
        let contentViewSource = try sourceFile("Sources/NativeMacADE/AppShell/ContentView.swift")

        #expect(contentViewSource.contains("FocusWorkspaceActiveCuePresentation(preferences: store.appPreferences)"))
        #expect(contentViewSource.contains("if focusWorkspaceCue.isVisible"))
        #expect(contentViewSource.contains("FocusWorkspaceActiveCueView()"))
        #expect(contentViewSource.contains("FocusWorkspaceActiveCuePresentation.helpText"))
    }

    @Test
    func shellGatesTabChromeAndPreservesCommandHandlersWhenFocusRowIsCollapsed() throws {
        let contentViewSource = try sourceFile("Sources/NativeMacADE/AppShell/ContentView.swift")

        #expect(contentViewSource.contains("FocusWorkspacePolicy.shouldShowTabRow("))
        #expect(contentViewSource.contains(".frame(height: shouldShowTabRow ? 42 : 0)"))
        #expect(contentViewSource.contains(".accessibilityHidden(!shouldShowTabRow)"))
        #expect(contentViewSource.contains("FocusWorkspacePolicy.shouldShowTerminalCreationAffordance("))
        #expect(contentViewSource.contains("if shouldShowCreateTabButton"))
        #expect(contentViewSource.contains("createPlainTabFromCommand()"))
        #expect(contentViewSource.contains("createDefaultAgentTabFromCommand()"))
        #expect(contentViewSource.contains("NotificationCenter.default.publisher(for: .closeSelectedTab)"))
    }

    @Test
    func appMenuHidesTerminalCreationCommandsWhenSelectedSessionPolicyBlocksThem() throws {
        let appSource = try sourceFile("Sources/NativeMacADE/NativeMacADEApp.swift")

        #expect(appSource.contains("if shouldShowTerminalCreationCommands"))
        #expect(appSource.contains("FocusWorkspacePolicy.shouldShowTerminalCreationAffordance("))
        #expect(appSource.contains("in: workspaceStore.selectedFocusWorkspaceSessionState"))
        #expect(appSource.contains("Button(\"New Tab\")"))
        #expect(appSource.contains("Button(\"New Agent Tab…\")"))
        #expect(appSource.contains("Button(\"New Default Agent Tab\")"))
    }

    @Test
    func agentPaletteAndPlaceholderEntryPointsUseFocusAffordancePolicy() throws {
        let contentViewSource = try sourceFile("Sources/NativeMacADE/AppShell/ContentView.swift")

        #expect(contentViewSource.contains("private func showAgentTabPalette()"))
        #expect(contentViewSource.contains("WorkspaceCommandError.focusWorkspaceRejected(.additionalTerminalTabBlocked)"))
        #expect(contentViewSource.contains("showsTerminalCreationActions: FocusWorkspacePolicy.shouldShowTerminalCreationAffordance("))
        #expect(contentViewSource.contains("let showsTerminalCreationActions: Bool"))
        #expect(contentViewSource.contains("if selectedSession != nil, showsTerminalCreationActions"))
    }

    @Test
    func blockedTerminalAndFileActionsUseFriendlyFocusWorkspaceAlertMapping() throws {
        let contentViewSource = try sourceFile("Sources/NativeMacADE/AppShell/ContentView.swift")

        #expect(contentViewSource.contains("FocusWorkspaceBlockedActionPresentation(error: commandError)"))
        #expect(contentViewSource.contains("UserMessage.commandFailure(error, fallbackTitle: \"Tab could not be created\")"))
        #expect(contentViewSource.contains("UserMessage.commandFailure(error, fallbackTitle: \"Agent tab could not be created\")"))
        #expect(
            occurrenceCount(
                of: "UserMessage.commandFailure(error, fallbackTitle: \"File could not be opened\")",
                in: contentViewSource
            ) >= 2
        )
    }

    private func sourceFile(_ relativePath: String) throws -> String {
        let fileURL = try packageRoot().appendingPathComponent(relativePath)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    private func occurrenceCount(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
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
