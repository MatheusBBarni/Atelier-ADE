import Foundation
import Testing
@testable import NativeMacADECore

@Suite(.serialized)
@MainActor
struct GhosttyAdapterTests {
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
    func adapterErrorMappingConvertsInitAndSurfaceFailuresToTypedUserVisibleErrors() async throws {
        let initFailingAdapter = LiveGhosttyAdapter(
            runtime: CGhosttyRuntime(forceInitializationFailure: true)
        )
        initFailingAdapter.resetSharedAppContextForTesting()

        await #expect(throws: GhosttyAdapterError.initializationFailed("Pinned libghostty app context initialization failed")) {
            try await initFailingAdapter.initializeIfNeeded()
        }

        let surfaceFailingAdapter = LiveGhosttyAdapter(
            runtime: CGhosttyRuntime(forceSurfaceCreationFailure: true)
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
    }

    @Test
    func inheritedSurfaceCreationPreservesParentRawContextInsideAdapter() async throws {
        let adapter = LiveGhosttyAdapter()
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
