import AppKit
import Foundation
import Testing
@testable import GhosttyKit
@testable import NativeMacADECore

@Suite(.serialized)
@MainActor
struct GhosttyAdapterTests {
    @Test
    func liveAdapterDefaultsToWrapperBackedHostPath() {
        let adapter = LiveGhosttyAdapter(runtime: RecordingGhosttySurfaceRuntime())

        #expect(adapter.usesEmbeddedSessionDriver == false)
    }

    @Test
    func createSurfaceDelegatesToWrapperRuntimeAndPreservesReturnedHandle() async throws {
        let expectedSurface = GhosttySurfaceHandle(id: UUID(), rawSurfaceID: 42, appContextID: 7)
        let runtime = RecordingGhosttySurfaceRuntime(surfaces: [expectedSurface])
        let adapter = LiveGhosttyAdapter(runtime: runtime)
        let configuration = GhosttyLaunchConfiguration(
            workingDirectory: "/tmp/native-mac-ade-wrapper",
            command: "codex",
            arguments: ["--full-auto"],
            appearance: AppTheme.dracula.terminalAppearance
        )

        let surface = try await adapter.createSurface(configuration: configuration)

        #expect(surface == expectedSurface)
        #expect(runtime.createSurfaceConfigurations == [configuration])
    }

    @Test
    func createInheritedSurfacePassesParentMetadataThroughWrapperRuntime() async throws {
        let parent = GhosttySurfaceHandle(id: UUID(), rawSurfaceID: 42, appContextID: 7)
        let expectedChild = GhosttySurfaceHandle(id: UUID(), rawSurfaceID: 43, appContextID: 7, inheritedSurfaceRawID: 42)
        let runtime = RecordingGhosttySurfaceRuntime(surfaces: [expectedChild])
        let adapter = LiveGhosttyAdapter(runtime: runtime)
        let configuration = GhosttyLaunchConfiguration(
            workingDirectory: "/tmp/native-mac-ade-child",
            command: "zsh",
            arguments: ["-l"]
        )

        let child = try await adapter.createInheritedSurface(from: parent, configuration: configuration)

        #expect(child == expectedChild)
        #expect(runtime.createSurfaceConfigurations.count == 1)
        #expect(runtime.createSurfaceConfigurations.first?.workingDirectory == "/tmp/native-mac-ade-child")
        #expect(runtime.createSurfaceConfigurations.first?.command == "zsh")
        #expect(runtime.createSurfaceConfigurations.first?.arguments == ["-l"])
        #expect(runtime.createSurfaceConfigurations.first?.inheritedSurfaceID == parent.id)
    }

    @Test
    func lifecycleAndNativeViewCallsReachWrapperRuntime() async throws {
        let expectedSurface = GhosttySurfaceHandle(id: UUID(), rawSurfaceID: 99, appContextID: 11)
        let nativeView = NSView()
        let runtime = RecordingGhosttySurfaceRuntime(surfaces: [expectedSurface])
        runtime.nativeViewsBySurface[expectedSurface] = nativeView
        runtime.canCloseResult = false
        runtime.hasExitedResult = true
        runtime.exitStatusResult = 37
        let adapter = LiveGhosttyAdapter(runtime: runtime)

        let surface = try await adapter.createSurface(
            configuration: GhosttyLaunchConfiguration(workingDirectory: "/tmp/native-mac-ade-lifecycle")
        )
        adapter.focus(surface: surface)
        adapter.resize(surface: surface, columns: 132, rows: 43)
        adapter.updateAppearance(surface: surface, appearance: AppTheme.dracula.terminalAppearance)
        let resolvedView = try #require(adapter.nativeView(for: surface))
        let canClose = await adapter.canClose(surface: surface)
        let hasExited = await adapter.hasExited(surface: surface)
        let exitStatus = await adapter.exitStatus(surface: surface)
        adapter.destroySurface(surface)

        #expect(resolvedView === nativeView)
        #expect(canClose == false)
        #expect(hasExited == true)
        #expect(exitStatus == 37)
        #expect(runtime.focusedSurfaces == [surface])
        #expect(runtime.resizeRequests == [ResizeRequest(surface: surface, columns: 132, rows: 43)])
        #expect(runtime.appearanceUpdates == [
            AppearanceUpdateRequest(surface: surface, appearance: AppTheme.dracula.terminalAppearance)
        ])
        #expect(runtime.nativeViewRequests == [surface])
        #expect(runtime.canCloseRequests == [surface])
        #expect(runtime.hasExitedRequests == [surface])
        #expect(runtime.exitStatusRequests == [surface])
        #expect(runtime.destroyedSurfaces == [surface])
    }

    @Test
    func launchConfigurationBuildsExpectedAdapterRequest() {
        let configuration = GhosttyLaunchConfiguration(
            workingDirectory: "/tmp/native-mac-ade",
            command: "codex",
            arguments: ["--full-auto"]
        )

        #expect(configuration.workingDirectory == "/tmp/native-mac-ade")
        #expect(configuration.command == "codex")
        #expect(configuration.arguments == ["--full-auto"])
        #expect(configuration.inheritedSurfaceID == nil)
    }

    @Test
    func launchConfigurationPreservesLaunchMetadataWithInjectedAppearance() {
        let tab = WorkspaceTab(
            sessionID: UUID(),
            workingDirectory: "/tmp/native-mac-ade-themed",
            launchCommand: "claude",
            launchArgumentsJSON: "[\"--continue\"]",
            ordinal: 0
        )

        let configuration = GhosttyLaunchConfiguration(tab: tab, appearance: AppTheme.dracula.terminalAppearance)

        #expect(configuration.workingDirectory == "/tmp/native-mac-ade-themed")
        #expect(configuration.command == "claude")
        #expect(configuration.arguments == ["--continue", "--dangerously-skip-permissions"])
        #expect(configuration.environment["CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN"] == "1")
        #expect(configuration.inheritedSurfaceID == nil)
        #expect(configuration.appearance == AppTheme.dracula.terminalAppearance)
    }

    @Test
    func adapterErrorMappingConvertsInitAndSurfaceFailuresToTypedUserVisibleErrors() async throws {
        let initFailingAdapter = LiveGhosttyAdapter(
            runtime: LiveGhosttySurfaceRuntime(
                bridge: CGhosttyRuntime(forceInitializationFailure: true)
            )
        )
        initFailingAdapter.resetSharedAppContextForTesting()

        await #expect(throws: GhosttyAdapterError.initializationFailed("Pinned libghostty app context initialization failed")) {
            try await initFailingAdapter.initializeIfNeeded()
        }

        let surfaceFailingAdapter = LiveGhosttyAdapter(
            runtime: LiveGhosttySurfaceRuntime(
                bridge: CGhosttyRuntime(forceSurfaceCreationFailure: true)
            )
        )
        surfaceFailingAdapter.resetSharedAppContextForTesting()

        await #expect(throws: GhosttyAdapterError.surfaceCreationFailed("Pinned libghostty surface creation failed")) {
            _ = try await surfaceFailingAdapter.createSurface(
                configuration: GhosttyLaunchConfiguration(workingDirectory: "/tmp/native-mac-ade")
            )
        }
    }

    @Test
    func inheritedTabConfigurationPreservesParentContextMetadata() {
        let parent = GhosttySurfaceHandle(id: UUID(), rawSurfaceID: 42, appContextID: 1)

        let inherited = GhosttyLaunchConfiguration.inheritedTab(
            from: parent,
            workingDirectory: "/tmp/native-mac-ade-child",
            command: "zsh",
            arguments: ["-l"]
        )

        #expect(inherited.inheritedSurfaceID == parent.id)
        #expect(inherited.workingDirectory == "/tmp/native-mac-ade-child")
        #expect(inherited.command == "zsh")
        #expect(inherited.arguments == ["-l"])
        #expect(inherited.appearance == AppTheme.defaultTheme.terminalAppearance)
    }

    @Test
    func inheritedSurfaceCreationPreservesParentRawContextInsideAdapter() async throws {
        let adapter = LiveGhosttyAdapter(runtime: LiveGhosttySurfaceRuntime())
        adapter.resetSharedAppContextForTesting()
        let parent = try await adapter.createSurface(
            configuration: GhosttyLaunchConfiguration(workingDirectory: "/tmp/native-mac-ade-parent")
        )

        let child = try await adapter.createInheritedSurface(
            from: parent,
            configuration: GhosttyLaunchConfiguration.inheritedTab(
                from: parent,
                workingDirectory: "/tmp/native-mac-ade-child"
            )
        )

        #expect(child.inheritedSurfaceRawID == parent.rawSurfaceID)
    }

    @Test
    func adapterSupportsFocusResizeCloseAndExitQueries() async throws {
        let adapter = LiveGhosttyAdapter()
        adapter.resetSharedAppContextForTesting()
        let surface = try await adapter.createSurface(
            configuration: GhosttyLaunchConfiguration(workingDirectory: "/tmp/native-mac-ade-hooks")
        )

        adapter.focus(surface: surface)
        adapter.resize(surface: surface, columns: 120, rows: 40)

        #expect(await adapter.canClose(surface: surface))
        #expect(await adapter.hasExited(surface: surface) == false)
    }
}

@MainActor
private final class RecordingGhosttySurfaceRuntime: GhosttySurfaceRuntime {
    private var surfaces: [GhosttySurfaceHandle]
    private(set) var initializeCallCount = 0
    private(set) var createSurfaceConfigurations: [GhosttyLaunchConfiguration] = []
    private(set) var nativeViewRequests: [GhosttySurfaceHandle] = []
    private(set) var focusedSurfaces: [GhosttySurfaceHandle] = []
    private(set) var resizeRequests: [ResizeRequest] = []
    private(set) var appearanceUpdates: [AppearanceUpdateRequest] = []
    private(set) var canCloseRequests: [GhosttySurfaceHandle] = []
    private(set) var hasExitedRequests: [GhosttySurfaceHandle] = []
    private(set) var exitStatusRequests: [GhosttySurfaceHandle] = []
    private(set) var destroyedSurfaces: [GhosttySurfaceHandle] = []
    var nativeViewsBySurface: [GhosttySurfaceHandle: NSView] = [:]
    var initializationError: Error?
    var surfaceCreationError: Error?
    var canCloseResult = true
    var hasExitedResult = false
    var exitStatusResult: Int32?

    init(surfaces: [GhosttySurfaceHandle] = [GhosttySurfaceHandle()]) {
        self.surfaces = surfaces
    }

    func initializeIfNeeded() async throws {
        initializeCallCount += 1
        if let initializationError {
            throw initializationError
        }
    }

    func createSurface(configuration: GhosttyLaunchConfiguration) async throws -> GhosttySurfaceHandle {
        if let surfaceCreationError {
            throw surfaceCreationError
        }
        createSurfaceConfigurations.append(configuration)
        if surfaces.isEmpty {
            return GhosttySurfaceHandle()
        }
        return surfaces.removeFirst()
    }

    func nativeView(for surface: GhosttySurfaceHandle) -> NSView? {
        nativeViewRequests.append(surface)
        return nativeViewsBySurface[surface]
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
        canCloseRequests.append(surface)
        return canCloseResult
    }

    func hasExited(surface: GhosttySurfaceHandle) async -> Bool {
        hasExitedRequests.append(surface)
        return hasExitedResult
    }

    func exitStatus(surface: GhosttySurfaceHandle) async -> Int32? {
        exitStatusRequests.append(surface)
        return exitStatusResult
    }

    func destroySurface(_ surface: GhosttySurfaceHandle) {
        destroyedSurfaces.append(surface)
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
