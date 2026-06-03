import Foundation
import Testing
@testable import NativeMacADE
import NativeMacADECore

struct FocusWorkspaceUIContractIntegrationTests {
    @Test
    @MainActor
    func focusWorkspaceSettingsSectionBodyBuildsForParentAndContinuityStates() {
        let parentOffStore = WorkspaceStore(
            appPreferences: AppPreferences(
                focusWorkspaceEnabled: false,
                focusWorkspaceContinuityEnabled: true
            )
        )
        let parentOnStore = WorkspaceStore(
            appPreferences: AppPreferences(
                focusWorkspaceEnabled: true,
                focusWorkspaceContinuityEnabled: true
            )
        )
        let parentOffSection = ConfigModalFocusWorkspaceSection(
            store: parentOffStore,
            commandService: makeCommandService(store: parentOffStore)
        )
        let parentOnSection = ConfigModalFocusWorkspaceSection(
            store: parentOnStore,
            commandService: makeCommandService(store: parentOnStore)
        )

        #expect(FocusWorkspaceSettingsPresentation(preferences: parentOffStore.appPreferences).isContinuityEnabled == false)
        #expect(FocusWorkspaceSettingsPresentation(preferences: parentOnStore.appPreferences).isContinuityEnabled)
        _ = parentOffSection.body
        _ = parentOnSection.body
    }

    @Test
    func configModalComposesDedicatedFocusWorkspaceSectionUsingPreferencesPipeline() throws {
        let configModalSource = try sourceFile("Sources/NativeMacADE/AppShell/ConfigModalView.swift")
        let focusSectionSource = try sourceFile("Sources/NativeMacADE/AppShell/ConfigModalFocusWorkspaceSection.swift")

        #expect(configModalSource.contains("ConfigModalFocusWorkspaceSection("))
        #expect(focusSectionSource.contains("FocusWorkspaceSettingsPresentation(preferences: store.appPreferences)"))
        #expect(focusSectionSource.contains("commandService.loadAppPreferences()"))
        #expect(focusSectionSource.contains("commandService.saveAppPreferences(preferences)"))
        #expect(focusSectionSource.contains("focusWorkspaceContinuityBinding"))
        #expect(focusSectionSource.contains("saveFocusWorkspaceContinuityPreference(enabled: requestedValue)"))
        #expect(focusSectionSource.contains("FocusWorkspaceSettingsPresentation.continuityToggleTitle"))
        #expect(focusSectionSource.contains("presentation.continuityStatus"))
        #expect(focusSectionSource.contains("FocusWorkspaceSettingsPresentation.continuityHelpText"))
        #expect(focusSectionSource.contains("FocusWorkspaceSettingsPresentation.legacyDetail"))
        #expect(focusSectionSource.contains("FocusWorkspaceSettingsPresentation.fileDetail"))
        #expect(focusSectionSource.contains("accessibilityIdentifier(\"focus-workspace-settings-section\")"))
        #expect(focusSectionSource.contains("accessibilityIdentifier(\"focus-workspace-continuity-toggle\")"))
        #expect(focusSectionSource.contains(".disabled(isSaving || !presentation.isContinuityAvailable)"))
        #expect(focusSectionSource.contains("preferences.focusWorkspaceContinuityEnabled = false"))
    }

    @Test
    func shellHeaderComposesFocusWorkspaceActiveCueFromAppPreferences() throws {
        let contentViewSource = try sourceFile("Sources/NativeMacADE/AppShell/ContentView.swift")

        #expect(contentViewSource.contains("FocusWorkspaceActiveCuePresentation(preferences: store.appPreferences)"))
        #expect(contentViewSource.contains("if focusWorkspaceCue.isVisible"))
        #expect(contentViewSource.contains("FocusWorkspaceActiveCueView(presentation: focusWorkspaceCue)"))
        #expect(contentViewSource.contains("Text(presentation.labelText)"))
        #expect(contentViewSource.contains(".accessibilityLabel(presentation.accessibilityLabelText)"))
        #expect(contentViewSource.contains(".help(presentation.activeHelpText)"))
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
    func fileEditorHeaderExposesSelectedFileTabRenameAndCloseAffordances() throws {
        let contentViewSource = try sourceFile("Sources/NativeMacADE/AppShell/ContentView.swift")

        #expect(contentViewSource.contains("Button(\"Rename Tab\", systemImage: \"pencil\", action: renameTab)"))
        #expect(contentViewSource.contains("Button(\"Close Tab\", systemImage: \"xmark\", action: closeTab)"))
        #expect(contentViewSource.contains("private func renameTab()"))
        #expect(contentViewSource.contains("NotificationCenter.default.post(name: .renameSelectedTab, object: nil)"))
        #expect(contentViewSource.contains("private func closeTab()"))
        #expect(contentViewSource.contains("NotificationCenter.default.post(name: .closeSelectedTab, object: nil)"))
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

    @Test
    func continuityCorrectionUsesExistingSessionSearchAndRowsWithoutNewTopLevelSurface() throws {
        let contentViewSource = try sourceFile("Sources/NativeMacADE/AppShell/ContentView.swift")
        let appCommandsSource = try sourceFile("Sources/NativeMacADECore/Commands/AppCommandRegistry.swift")

        #expect(contentViewSource.contains("NotificationCenter.default.publisher(for: .showSessionSearchPalette)"))
        #expect(contentViewSource.contains("SessionSearchPaletteOverlay("))
        #expect(contentViewSource.contains("SessionRowView("))
        #expect(contentViewSource.contains("SessionTerminalChildRowView("))
        #expect(appCommandsSource.contains(".searchSessions"))
        #expect(appCommandsSource.contains("returnToFocus") == false)
        #expect(appCommandsSource.contains("continuity") == false)
        #expect(contentViewSource.contains("ContinuityCommand") == false)
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

    @MainActor
    private func makeCommandService(store: WorkspaceStore) -> DefaultWorkspaceCommandService {
        let persistence = InMemoryWorkspacePersistenceStore(appPreferences: store.appPreferences)
        return DefaultWorkspaceCommandService(
            store: store,
            persistenceStore: persistence,
            restoreCoordinator: RestoreCoordinator(persistenceStore: persistence),
            terminalSurfaceManager: FocusWorkspaceUITerminalSurfaceManager()
        )
    }
}

@MainActor
private final class FocusWorkspaceUITerminalSurfaceManager: WorkspaceTerminalSurfaceManaging {
    private var surfacesByTabID: [UUID: GhosttySurfaceHandle] = [:]

    func createSurface(for tab: WorkspaceTab) async throws -> GhosttySurfaceHandle {
        let surface = GhosttySurfaceHandle()
        surfacesByTabID[tab.id] = surface
        return surface
    }

    func surface(for tabID: UUID) -> GhosttySurfaceHandle? {
        surfacesByTabID[tabID]
    }

    func canClose(surface: GhosttySurfaceHandle) async -> Bool {
        true
    }

    func focus(tabID: UUID) {}

    func resize(tabID: UUID, columns: Int, rows: Int) {}

    func hasExited(tabID: UUID) async -> Bool {
        false
    }

    func releaseSurface(for tabID: UUID) {
        surfacesByTabID[tabID] = nil
    }
}
