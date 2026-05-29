import Foundation
import Testing
@testable import NativeMacADECore

@Suite(.serialized)
@MainActor
struct ScaffoldIntegrationTests {
    @Test
    func liveContainerStartsEmptyAndWiresRequiredBoundaries() {
        let container = AppDependencyContainer.live()

        #expect(container.workspaceStore.projects.isEmpty)
        #expect(container.workspaceStore.selectedProjectID == nil)
    }

    @Test
    func terminalHostCreatesSingleEmbeddedSurfaceWithoutRequiringGhosttyRuntime() async throws {
        let host = TerminalHostController()
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: try makeTemporaryDirectory(), ordinal: 0)

        let surface = try await host.createSurface(for: tab)

        #expect(LiveGhosttyAdapter.pinnedRevision == "cb36966a752982014827a9cabcf630ec3788b3d9")
        #expect(surface.rawSurfaceID == 0)
        #expect(surface.appContextID == 0)
    }

    @Test
    func adapterInitializesOneGhosttyAppContextPerProcess() async throws {
        let firstAdapter = LiveGhosttyAdapter()
        let secondAdapter = LiveGhosttyAdapter()
        firstAdapter.resetSharedAppContextForTesting()

        try await firstAdapter.initializeIfNeeded()
        let first = try await firstAdapter.createSurface(configuration: GhosttyLaunchConfiguration(workingDirectory: "/tmp/ade-one"))
        try await secondAdapter.initializeIfNeeded()
        let second = try await secondAdapter.createSurface(configuration: GhosttyLaunchConfiguration(workingDirectory: "/tmp/ade-two"))

        #expect(first.appContextID == 1)
        #expect(second.appContextID == 1)
        #expect(first.rawSurfaceID != second.rawSurfaceID)
        #expect(CGhosttyRuntime.initializeCallCount == 1)
    }

    @Test
    func surfaceCreationFailureReturnsTypedUserVisibleErrorWithoutCrashing() async throws {
        let adapter = LiveGhosttyAdapter(runtime: CGhosttyRuntime(forceSurfaceCreationFailure: true))
        adapter.resetSharedAppContextForTesting()

        do {
            _ = try await adapter.createSurface(configuration: GhosttyLaunchConfiguration(workingDirectory: "/tmp/ade"))
            Issue.record("Expected pinned Ghostty surface creation failure")
        } catch let error as GhosttyAdapterError {
            #expect(error == .surfaceCreationFailed("Pinned libghostty surface creation failed"))
            #expect(error.workspaceCommandError == .terminalUnavailable("Pinned libghostty surface creation failed"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private func makeTemporaryDirectory() throws -> String {
    let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("native-mac-ade-scaffold-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url.path
}
