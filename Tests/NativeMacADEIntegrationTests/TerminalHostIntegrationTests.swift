import AppKit
import Foundation
import Testing
@testable import NativeMacADECore

@Suite(.serialized)
@MainActor
struct TerminalHostIntegrationTests {
    @Test
    func newTabCreatesExactlyOneGhosttySurfaceWithSelectedWorkingDirectoryAndDefaultAppearance() async throws {
        let adapter = RecordingGhosttyAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-host", ordinal: 0)

        let firstSurface = try await controller.createSurface(for: tab)
        let secondSurface = try await controller.createSurface(for: tab)

        #expect(firstSurface == secondSurface)
        #expect(adapter.createdConfigurations.count == 1)
        #expect(adapter.createdConfigurations.first?.workingDirectory == tab.workingDirectory)
        #expect(adapter.createdConfigurations.first?.appearance == AppTheme.defaultTheme.terminalAppearance)
    }

    @Test
    func focusAndResizePropagateLifecycleHooksToGhosttyAdapter() async throws {
        let adapter = RecordingGhosttyAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-hooks", ordinal: 0)
        let surface = try await controller.createSurface(for: tab)
        let view = try #require(controller.makeHostView(for: tab, isActive: true) as? TerminalSurfaceHostNSView)

        controller.focus(tabID: tab.id)
        controller.resize(tabID: tab.id, columns: 132, rows: 43)
        view.setFrameSize(NSSize(width: 960, height: 384))
        try await waitUntil("ghostty resize callback") {
            adapter.resizeRequests.contains(ResizeRequest(surface: surface, columns: 118, rows: 23))
        }

        #expect(adapter.focusedSurfaces == [surface])
        #expect(adapter.resizeRequests.contains(ResizeRequest(surface: surface, columns: 132, rows: 43)))
        #expect(adapter.resizeRequests.contains(ResizeRequest(surface: surface, columns: 118, rows: 23)))
    }

    @Test
    func terminalHostViewAppliesDefaultAppearanceToAppKitContainer() async throws {
        let adapter = RecordingGhosttyAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-theme-default", ordinal: 0)

        let view = try #require(controller.makeHostView(for: tab, isActive: true) as? TerminalSurfaceHostNSView)
        let surface = try await controller.createSurface(for: tab)
        let nativeView = try #require(adapter.nativeViewsBySurface[surface])

        #expect(view.terminalAppearance == AppTheme.defaultTheme.terminalAppearance)
        #expect(view.attachedSurface == surface)
        #expect(view.embeddedSurfaceView === nativeView)
        #expect(view.subviews.contains(where: { $0 === nativeView }))
        #expect(view.layer?.backgroundColor == NSColor(hex: AppTheme.defaultTheme.terminalAppearance.backgroundHex).cgColor)
    }

    @Test
    func changingThemeAfterHostViewExistsUpdatesHostWithoutDuplicateSurface() async throws {
        let adapter = RecordingGhosttyAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-live-theme", ordinal: 0)
        let view = try #require(controller.makeHostView(for: tab, isActive: true) as? TerminalSurfaceHostNSView)
        let surface = try await controller.createSurface(for: tab)

        controller.updateAppearance(AppTheme.catppuccin.terminalAppearance)
        let reusedSurface = try await controller.createSurface(for: tab)

        #expect(surface == reusedSurface)
        #expect(adapter.createdConfigurations.count == 1)
        #expect(controller.surface(for: tab.id) == surface)
        #expect(adapter.appearanceUpdates == [
            AppearanceUpdateRequest(surface: surface, appearance: AppTheme.catppuccin.terminalAppearance)
        ])
        #expect(view.terminalAppearance == AppTheme.catppuccin.terminalAppearance)
        #expect(view.layer?.backgroundColor == NSColor(hex: AppTheme.catppuccin.terminalAppearance.backgroundHex).cgColor)
    }

    @Test
    func terminalZoomCommandsAdjustAttachedHostFontSize() throws {
        let controller = TerminalHostController()
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-zoom", ordinal: 0)
        let view = try #require(controller.makeHostView(for: tab, isActive: true) as? TerminalSurfaceHostNSView)
        let defaultFontSize = view.terminalAppearance.fontSize

        controller.zoomIn()
        #expect(view.terminalAppearance.fontSize == defaultFontSize + 1)

        controller.zoomOut()
        #expect(view.terminalAppearance.fontSize == defaultFontSize)
    }

    @Test
    func creatingNewTabAfterThemeChangePassesUpdatedAppearanceToAdapter() async throws {
        let adapter = RecordingGhosttyAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let sessionID = UUID()
        let firstTab = WorkspaceTab(sessionID: sessionID, workingDirectory: "/tmp/native-mac-ade-first-theme", ordinal: 0)
        let secondTab = WorkspaceTab(sessionID: sessionID, workingDirectory: "/tmp/native-mac-ade-second-theme", ordinal: 1)

        _ = try await controller.createSurface(for: firstTab)
        controller.updateAppearance(AppTheme.dracula.terminalAppearance)
        _ = try await controller.createSurface(for: secondTab)

        #expect(adapter.createdConfigurations.map(\.appearance) == [
            AppTheme.defaultTheme.terminalAppearance,
            AppTheme.dracula.terminalAppearance
        ])
    }

    @Test
    func switchingThemeUpdatesAttachedHostAndNewSurfaceWithoutChangingWorkspaceMetadata() async throws {
        let adapter = RecordingGhosttyAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let store = WorkspaceStore()
        let persistence = InMemoryWorkspacePersistenceStore()
        let service = DefaultWorkspaceCommandService(
            store: store,
            persistenceStore: persistence,
            portableSettingsFileStore: temporaryPortableSettingsFileStore(),
            restoreCoordinator: RestoreCoordinator(persistenceStore: persistence),
            terminalSurfaceManager: controller
        )
        let project = try await service.openProject(path: makeTemporaryDirectory())
        let session = try await service.createSession(projectID: project.id, shortcutID: nil)
        let firstTab = try #require(store.tabs.first)
        let hostView = try #require(controller.makeHostView(for: firstTab, isActive: true) as? TerminalSurfaceHostNSView)

        try await service.saveAppPreferences(AppPreferences(themeID: "catppuccin"))
        controller.updateAppearance(store.effectiveTheme(systemScheme: .light).terminalAppearance)
        let secondTab = try await service.createTab(sessionID: session.id)

        #expect(hostView.terminalAppearance == AppTheme.catppuccin.terminalAppearance)
        #expect(adapter.createdConfigurations.map(\.appearance) == [
            AppTheme.defaultTheme.terminalAppearance,
            AppTheme.catppuccin.terminalAppearance
        ])
        #expect(store.sessions.first?.id == session.id)
        #expect(store.sessions.first?.shortcutID == session.shortcutID)
        #expect(store.tabs.first { $0.id == firstTab.id }?.launchCommand == firstTab.launchCommand)
        #expect(store.tabs.first { $0.id == firstTab.id }?.launchArgumentsJSON == firstTab.launchArgumentsJSON)
        #expect(secondTab.sessionID == session.id)
    }

    @Test
    func startupPreferenceLoadAppliesSavedThemeBeforeRestoredTerminalSurfaceCreation() async throws {
        let adapter = RecordingGhosttyAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let store = WorkspaceStore()
        let persistence = InMemoryWorkspacePersistenceStore()
        let projectPath = try makeTemporaryDirectory()
        let project = WorkspaceProject(path: projectPath, displayName: "Themed Restore")
        let session = WorkspaceSession(projectID: project.id, title: "Restored")
        let tab = WorkspaceTab(sessionID: session.id, workingDirectory: projectPath, ordinal: 0)
        let service = DefaultWorkspaceCommandService(
            store: store,
            persistenceStore: persistence,
            portableSettingsFileStore: temporaryPortableSettingsFileStore(),
            restoreCoordinator: RestoreCoordinator(persistenceStore: persistence),
            terminalSurfaceManager: controller
        )

        try await persistence.save(project: project)
        try await persistence.save(session: session)
        try await persistence.save(tab: tab)
        try await persistence.save(snapshot: RestoreSnapshot(
            selectedProjectID: project.id,
            selectedSessionID: session.id,
            selectedTabID: tab.id,
            openTabIDs: [tab.id]
        ))
        try await persistence.save(appPreferences: AppPreferences(themeID: "catppuccin"))

        let startupResult = await AppShellStartupCoordinator.run(commandService: service, store: store) {
            controller.updateAppearance(store.effectiveTheme(systemScheme: .light).terminalAppearance)
        }

        #expect(startupResult.preferenceLoadErrorDescription == nil)
        #expect(startupResult.restoreErrorDescription == nil)
        #expect(adapter.createdConfigurations.map(\.appearance) == [AppTheme.catppuccin.terminalAppearance])
        #expect(store.effectiveTheme(systemScheme: .light) == AppTheme.catppuccin)
    }

    @Test
    func startupSystemPreferenceAppliesResolvedTerminalAppearanceBeforeRestore() async throws {
        let adapter = RecordingGhosttyAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let store = WorkspaceStore()
        let persistence = InMemoryWorkspacePersistenceStore()
        let projectPath = try makeTemporaryDirectory()
        let project = WorkspaceProject(path: projectPath, displayName: "System Restore")
        let session = WorkspaceSession(projectID: project.id, title: "Restored")
        let tab = WorkspaceTab(sessionID: session.id, workingDirectory: projectPath, ordinal: 0)
        let service = DefaultWorkspaceCommandService(
            store: store,
            persistenceStore: persistence,
            portableSettingsFileStore: temporaryPortableSettingsFileStore(),
            restoreCoordinator: RestoreCoordinator(persistenceStore: persistence),
            terminalSurfaceManager: controller
        )

        try await persistence.save(project: project)
        try await persistence.save(session: session)
        try await persistence.save(tab: tab)
        try await persistence.save(snapshot: RestoreSnapshot(
            selectedProjectID: project.id,
            selectedSessionID: session.id,
            selectedTabID: tab.id,
            openTabIDs: [tab.id]
        ))
        try await persistence.save(appPreferences: AppPreferences(themeID: AppTheme.systemSelectionID))

        let startupResult = await AppShellStartupCoordinator.run(commandService: service, store: store) {
            controller.updateAppearance(store.effectiveTheme(systemScheme: .dark).terminalAppearance)
        }

        #expect(startupResult.preferenceLoadErrorDescription == nil)
        #expect(startupResult.restoreErrorDescription == nil)
        #expect(store.appPreferences.themeID == AppTheme.systemSelectionID)
        #expect(adapter.createdConfigurations.map(\.appearance) == [AppTheme.dracula.terminalAppearance])
    }

    @Test
    func selectionChangesBetweenSystemAndConcreteThemesUpdateExistingAndNewTerminalSurfaces() async throws {
        let adapter = RecordingGhosttyAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let store = WorkspaceStore()
        let persistence = InMemoryWorkspacePersistenceStore()
        let service = DefaultWorkspaceCommandService(
            store: store,
            persistenceStore: persistence,
            portableSettingsFileStore: temporaryPortableSettingsFileStore(),
            restoreCoordinator: RestoreCoordinator(persistenceStore: persistence),
            terminalSurfaceManager: controller
        )
        let project = try await service.openProject(path: makeTemporaryDirectory())
        let session = try await service.createSession(projectID: project.id, shortcutID: nil)
        let firstTab = try #require(store.tabs.first)
        let hostView = try #require(controller.makeHostView(for: firstTab, isActive: true) as? TerminalSurfaceHostNSView)

        try await service.saveAppPreferences(AppPreferences(themeID: AppTheme.systemSelectionID))
        controller.updateAppearance(store.effectiveTheme(systemScheme: .dark).terminalAppearance)

        #expect(store.appPreferences.themeID == AppTheme.systemSelectionID)
        #expect(hostView.terminalAppearance == AppTheme.dracula.terminalAppearance)

        try await service.saveAppPreferences(AppPreferences(themeID: "catppuccin"))
        controller.updateAppearance(store.effectiveTheme(systemScheme: .dark).terminalAppearance)
        let secondTab = try await service.createTab(sessionID: session.id)

        #expect(store.appPreferences.themeID == "catppuccin")
        #expect(hostView.terminalAppearance == AppTheme.catppuccin.terminalAppearance)
        #expect(adapter.createdConfigurations.map(\.appearance) == [
            AppTheme.defaultTheme.terminalAppearance,
            AppTheme.catppuccin.terminalAppearance
        ])
        #expect(secondTab.sessionID == session.id)

        try await service.saveAppPreferences(AppPreferences(themeID: AppTheme.systemSelectionID))
        controller.updateAppearance(store.effectiveTheme(systemScheme: .light).terminalAppearance)

        #expect(store.appPreferences.themeID == AppTheme.systemSelectionID)
        #expect(hostView.terminalAppearance == AppTheme.catppuccin.terminalAppearance)
    }

    @Test
    func liveSystemSchemeChangeUpdatesExistingTerminalSurfaceWithoutRelaunch() async throws {
        let adapter = RecordingGhosttyAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let store = WorkspaceStore(appPreferences: AppPreferences(themeID: AppTheme.systemSelectionID))
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-live-system-theme", ordinal: 0)
        let view = try #require(controller.makeHostView(for: tab, isActive: true) as? TerminalSurfaceHostNSView)
        _ = try await controller.createSurface(for: tab)

        controller.updateAppearance(store.effectiveTheme(systemScheme: .light).terminalAppearance)
        #expect(view.terminalAppearance == AppTheme.catppuccin.terminalAppearance)

        controller.updateAppearance(store.effectiveTheme(systemScheme: .dark).terminalAppearance)

        #expect(store.appPreferences.themeID == AppTheme.systemSelectionID)
        #expect(view.terminalAppearance == AppTheme.dracula.terminalAppearance)
        #expect(adapter.createdConfigurations.map(\.appearance) == [AppTheme.defaultTheme.terminalAppearance])
    }

    @Test
    func attachingSurfaceReplaysCurrentHostBoundsAsInitialResize() async throws {
        let adapter = RecordingGhosttyAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-initial-size", ordinal: 0)
        let view = try #require(controller.makeHostView(for: tab, isActive: true) as? TerminalSurfaceHostNSView)
        view.setFrameSize(NSSize(width: 800, height: 320))
        let surface = try await controller.createSurface(for: tab)

        #expect(adapter.resizeRequests.contains(ResizeRequest(surface: surface, columns: 100, rows: 20)))
    }

    @Test
    func reusedHostViewDropsStaleTabMappingBeforeNewTabAttach() async throws {
        let adapter = RecordingGhosttyAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let firstTab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-first", ordinal: 0)
        let secondTab = WorkspaceTab(sessionID: firstTab.sessionID, workingDirectory: "/tmp/native-mac-ade-second", ordinal: 1)
        let view = try #require(controller.makeHostView(for: firstTab, isActive: true) as? TerminalSurfaceHostNSView)
        let firstSurface = try await controller.createSurface(for: firstTab)
        let firstNativeView = try #require(adapter.nativeViewsBySurface[firstSurface])

        controller.updateHostView(view, tab: secondTab, isActive: true)
        let secondSurface = try await controller.createSurface(for: secondTab)
        let secondNativeView = try #require(adapter.nativeViewsBySurface[secondSurface])
        controller.releaseSurface(for: firstTab.id)

        #expect(firstSurface != secondSurface)
        #expect(view.tabID == secondTab.id)
        #expect(view.attachedSurface == secondSurface)
        #expect(view.embeddedSurfaceView === secondNativeView)
        #expect(firstNativeView.superview == nil)
    }

    @Test
    func processExitQueryReturnsAdapterExitState() async throws {
        let adapter = RecordingGhosttyAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-exit", ordinal: 0)
        let surface = try await controller.createSurface(for: tab)
        adapter.exitedSurfaces.insert(surface)

        #expect(await controller.hasExited(tabID: tab.id))
    }

    @Test
    func processExitMonitorInvokesMainActorCallback() async throws {
        let adapter = RecordingGhosttyAdapter()
        adapter.exitsEverySurface = true
        let controller = TerminalHostController(adapter: adapter)
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-exit-callback", ordinal: 0)
        var exitedEvents: [(UUID, Int32?)] = []
        controller.onSurfaceExited = { exitedEvents.append(($0, $1)) }

        _ = try await controller.createSurface(for: tab)
        try await waitUntil("terminal exit callback") {
            exitedEvents.count == 1
        }

        #expect(exitedEvents.map(\.0) == [tab.id])
        #expect(exitedEvents.map(\.1) == [0])
    }

    @Test
    func canCloseUsesGhosttyAdapterRuntimeState() async throws {
        let adapter = RecordingGhosttyAdapter()
        adapter.canCloseResult = false
        let controller = TerminalHostController(adapter: adapter)
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-close", ordinal: 0)

        let surface = try await controller.createSurface(for: tab)

        #expect(await controller.canClose(surface: surface) == false)
    }

    @Test
    func terminalHostRelayoutsGhosttyNativeViewAfterZeroSizedInitialAttach() async throws {
        let adapter = RecordingGhosttyAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-native-relayout", ordinal: 0)
        let view = try #require(controller.makeHostView(for: tab, isActive: true) as? TerminalSurfaceHostNSView)

        let surface = try await controller.createSurface(for: tab)
        view.setFrameSize(NSSize(width: 800, height: 320))
        let nativeView = try #require(adapter.nativeViewsBySurface[surface])

        try await waitUntil("ghostty native view attachment") {
            nativeView.frame.width > 0 && nativeView.frame.height > 0
        }

        #expect(view.embeddedSurfaceView === nativeView)
        #expect(nativeView.frame.width > 0)
        #expect(nativeView.frame.height > 0)

        controller.releaseSurface(for: tab.id)
    }

    @Test
    func ghosttyTerminalHostRefreshesAttachedViewAppearance() async throws {
        let adapter = RecordingGhosttyAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-native-appearance", ordinal: 0)
        let view = try #require(controller.makeHostView(for: tab, isActive: true) as? TerminalSurfaceHostNSView)

        _ = try await controller.createSurface(for: tab)

        controller.updateAppearance(AppTheme.dracula.terminalAppearance)

        #expect(view.terminalAppearance == AppTheme.dracula.terminalAppearance)
        #expect(view.layer?.backgroundColor == NSColor(hex: AppTheme.dracula.terminalAppearance.backgroundHex).cgColor)
        #expect(adapter.appearanceUpdates.count == 1)

        controller.releaseSurface(for: tab.id)
    }

    @Test
    func testAdapterCapturesNativeViewAccessWithoutRealGhosttySurface() throws {
        let adapter = RecordingGhosttyAdapter()
        let surface = GhosttySurfaceHandle()
        let nativeView = try #require(adapter.nativeView(for: surface))
        let storedView = try #require(adapter.nativeViewsBySurface[surface])

        #expect(adapter.nativeViewRequests == [surface])
        #expect(storedView === nativeView)
    }
}

@MainActor
private final class RecordingGhosttyAdapter: GhosttyAdapter {
    private(set) var initializeCallCount = 0
    private(set) var createdConfigurations: [GhosttyLaunchConfiguration] = []
    private(set) var focusedSurfaces: [GhosttySurfaceHandle] = []
    private(set) var resizeRequests: [ResizeRequest] = []
    private(set) var appearanceUpdates: [AppearanceUpdateRequest] = []
    private(set) var destroyedSurfaces: [GhosttySurfaceHandle] = []
    private(set) var nativeViewRequests: [GhosttySurfaceHandle] = []
    private(set) var nativeViewsBySurface: [GhosttySurfaceHandle: NSView] = [:]
    var canCloseResult = true
    var exitedSurfaces: Set<GhosttySurfaceHandle> = []
    var exitsEverySurface = false

    func initializeIfNeeded() async throws {
        initializeCallCount += 1
    }

    func createSurface(configuration: GhosttyLaunchConfiguration) async throws -> GhosttySurfaceHandle {
        createdConfigurations.append(configuration)
        return recordSurface()
    }

    func createInheritedSurface(
        from parent: GhosttySurfaceHandle,
        configuration: GhosttyLaunchConfiguration
    ) async throws -> GhosttySurfaceHandle {
        createdConfigurations.append(configuration)
        return recordSurface()
    }

    func nativeView(for surface: GhosttySurfaceHandle) -> NSView? {
        nativeViewRequests.append(surface)
        if let nativeView = nativeViewsBySurface[surface] {
            return nativeView
        }

        let nativeView = NSView()
        nativeViewsBySurface[surface] = nativeView
        return nativeView
    }

    func focus(surface: GhosttySurfaceHandle) {
        focusedSurfaces.append(surface)
    }

    func resize(surface: GhosttySurfaceHandle, columns: Int, rows: Int) {
        resizeRequests.append(ResizeRequest(surface: surface, columns: columns, rows: rows))
    }

    func updateAppearance(surface: GhosttySurfaceHandle, appearance: TerminalAppearance) {
        appearanceUpdates.append(AppearanceUpdateRequest(surface: surface, appearance: appearance))
    }

    func canClose(surface: GhosttySurfaceHandle) async -> Bool {
        canCloseResult
    }

    func hasExited(surface: GhosttySurfaceHandle) async -> Bool {
        exitsEverySurface || exitedSurfaces.contains(surface)
    }

    func exitStatus(surface: GhosttySurfaceHandle) async -> Int32? {
        0
    }

    func destroySurface(_ surface: GhosttySurfaceHandle) {
        destroyedSurfaces.append(surface)
    }

    private func recordSurface() -> GhosttySurfaceHandle {
        let surface = GhosttySurfaceHandle()
        nativeViewsBySurface[surface] = NSView()
        return surface
    }
}

private struct ResizeRequest: Equatable {
    let surface: GhosttySurfaceHandle
    let columns: Int
    let rows: Int
}

private struct AppearanceUpdateRequest: Equatable {
    let surface: GhosttySurfaceHandle
    let appearance: TerminalAppearance
}

private func makeTemporaryDirectory() throws -> String {
    let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("native-mac-ade-terminal-host-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url.path
}

@MainActor
private func waitUntil(
    _ description: String,
    timeout: Duration = .seconds(1),
    pollInterval: Duration = .milliseconds(10),
    condition: @MainActor () -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)

    while clock.now < deadline {
        if condition() {
            return
        }
        try await Task.sleep(for: pollInterval)
    }

    throw WaitTimeoutError(description: description)
}

private struct WaitTimeoutError: Error, CustomStringConvertible {
    let description: String
}

private func temporaryPortableSettingsFileStore() -> PortableSettingsFileStore {
    let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("native-mac-ade-terminal-host-portable-settings-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("settings.json")
    return PortableSettingsFileStore(canonicalURL: url)
}

private extension NSColor {
    convenience init(hex: String) {
        let normalized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: normalized).scanHexInt64(&value)
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
