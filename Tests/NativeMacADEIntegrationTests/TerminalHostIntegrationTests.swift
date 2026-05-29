import AppKit
import Foundation
import Testing
@testable import NativeMacADECore

@Suite(.serialized)
@MainActor
struct TerminalHostIntegrationTests {
    @Test
    func newTabCreatesExactlyOneGhosttySurfaceWithSelectedWorkingDirectoryAndNordAppearance() async throws {
        let adapter = RecordingGhosttyAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-host", ordinal: 0)

        let firstSurface = try await controller.createSurface(for: tab)
        let secondSurface = try await controller.createSurface(for: tab)

        #expect(firstSurface == secondSurface)
        #expect(adapter.createdConfigurations.count == 1)
        #expect(adapter.createdConfigurations.first?.workingDirectory == tab.workingDirectory)
        #expect(adapter.createdConfigurations.first?.appearance == .nordDefault)
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
    func terminalHostViewAppliesNordAppearanceToAppKitContainer() async throws {
        let adapter = RecordingGhosttyAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-nord", ordinal: 0)

        let view = try #require(controller.makeHostView(for: tab, isActive: true) as? TerminalSurfaceHostNSView)
        _ = try await controller.createSurface(for: tab)

        #expect(view.terminalAppearance == .nordDefault)
        #expect(view.attachedSurface != nil)
        #expect(view.embeddedSurfaceView != nil)
        #expect(view.subviews.contains(where: { $0 === view.embeddedSurfaceView }))
        #expect(view.layer?.backgroundColor == NSColor(hex: TerminalAppearance.nordDefault.backgroundHex).cgColor)
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

        controller.updateHostView(view, tab: secondTab, isActive: true)
        let secondSurface = try await controller.createSurface(for: secondTab)
        controller.releaseSurface(for: firstTab.id)

        #expect(firstSurface != secondSurface)
        #expect(view.tabID == secondTab.id)
        #expect(view.attachedSurface == secondSurface)
        #expect(view.embeddedSurfaceView != nil)
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
    func embeddedShellPreventsCloseWhileProcessIsRunning() async throws {
        let controller = TerminalHostController()
        let workingDirectory = try makeTemporaryDirectory()
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: workingDirectory, ordinal: 0)

        let surface = try await controller.createSurface(for: tab)

        #expect(await controller.canClose(surface: surface) == false)

        controller.releaseSurface(for: tab.id)
    }

    @Test
    func liveTerminalHostRelayoutsSwiftTermViewAfterZeroSizedInitialAttach() async throws {
        let controller = TerminalHostController()
        let workingDirectory = try makeTemporaryDirectory()
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: workingDirectory, ordinal: 0)
        let view = try #require(controller.makeHostView(for: tab, isActive: true) as? TerminalSurfaceHostNSView)

        _ = try await controller.createSurface(for: tab)
        view.setFrameSize(NSSize(width: 800, height: 320))
        try await waitUntil("swiftterm view attachment") {
            guard let terminalView = view.localProcessTerminalView else { return false }
            return terminalView.frame.width > 0 && terminalView.frame.height > 0 && terminalView.process.running
        }

        let terminalView = try #require(view.localProcessTerminalView)
        #expect(terminalView.frame.width > 0)
        #expect(terminalView.frame.height > 0)
        #expect(terminalView.process.running)

        controller.releaseSurface(for: tab.id)
    }
}

@MainActor
private final class RecordingGhosttyAdapter: GhosttyAdapter {
    private(set) var initializeCallCount = 0
    private(set) var createdConfigurations: [GhosttyLaunchConfiguration] = []
    private(set) var focusedSurfaces: [GhosttySurfaceHandle] = []
    private(set) var resizeRequests: [ResizeRequest] = []
    private(set) var destroyedSurfaces: [GhosttySurfaceHandle] = []
    var canCloseResult = true
    var exitedSurfaces: Set<GhosttySurfaceHandle> = []
    var exitsEverySurface = false

    func initializeIfNeeded() async throws {
        initializeCallCount += 1
    }

    func createSurface(configuration: GhosttyLaunchConfiguration) async throws -> GhosttySurfaceHandle {
        createdConfigurations.append(configuration)
        return GhosttySurfaceHandle()
    }

    func createInheritedSurface(
        from parent: GhosttySurfaceHandle,
        configuration: GhosttyLaunchConfiguration
    ) async throws -> GhosttySurfaceHandle {
        createdConfigurations.append(configuration)
        return GhosttySurfaceHandle()
    }

    func focus(surface: GhosttySurfaceHandle) {
        focusedSurfaces.append(surface)
    }

    func resize(surface: GhosttySurfaceHandle, columns: Int, rows: Int) {
        resizeRequests.append(ResizeRequest(surface: surface, columns: columns, rows: rows))
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
}

private struct ResizeRequest: Equatable {
    let surface: GhosttySurfaceHandle
    let columns: Int
    let rows: Int
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
