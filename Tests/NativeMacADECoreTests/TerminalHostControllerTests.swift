import AppKit
import Foundation
import Testing
@testable import NativeMacADECore

@Suite(.serialized)
@MainActor
struct TerminalHostControllerTests {
    @Test
    func createSurfaceCreatesExactlyOneGhosttySurfacePerTerminalTab() async throws {
        let adapter = RecordingTerminalHostAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-unit-create", ordinal: 0)

        let firstSurface = try await controller.createSurface(for: tab)
        let secondSurface = try await controller.createSurface(for: tab)

        #expect(firstSurface == secondSurface)
        #expect(adapter.initializeCallCount == 1)
        #expect(adapter.createdConfigurations.count == 1)
        #expect(adapter.nativeViewRequests == [firstSurface])
    }

    @Test
    func focusDelegatesToGhosttyAdapterForActiveSurface() async throws {
        let adapter = RecordingTerminalHostAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-unit-focus", ordinal: 0)
        let surface = try await controller.createSurface(for: tab)

        controller.focus(tabID: tab.id)

        #expect(adapter.focusedSurfaces == [surface])
    }

    @Test
    func resizeDelegatesCorrectDimensionsToGhosttyAdapter() async throws {
        let adapter = RecordingTerminalHostAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-unit-resize", ordinal: 0)
        let surface = try await controller.createSurface(for: tab)

        controller.resize(tabID: tab.id, columns: 144, rows: 50)

        #expect(adapter.resizeRequests == [
            ResizeRequest(surface: surface, columns: 144, rows: 50)
        ])
    }

    @Test
    func updateAppearancePropagatesToExistingGhosttySurfaces() async throws {
        let adapter = RecordingTerminalHostAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let firstTab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-unit-theme-one", ordinal: 0)
        let secondTab = WorkspaceTab(sessionID: firstTab.sessionID, workingDirectory: "/tmp/native-mac-ade-unit-theme-two", ordinal: 1)
        let firstSurface = try await controller.createSurface(for: firstTab)
        let secondSurface = try await controller.createSurface(for: secondTab)

        controller.updateAppearance(AppTheme.dracula.terminalAppearance)

        #expect(adapter.appearanceUpdates.count == 2)
        #expect(adapter.appearanceUpdates.contains(
            AppearanceUpdateRequest(surface: firstSurface, appearance: AppTheme.dracula.terminalAppearance)
        ))
        #expect(adapter.appearanceUpdates.contains(
            AppearanceUpdateRequest(surface: secondSurface, appearance: AppTheme.dracula.terminalAppearance)
        ))
    }

    @Test
    func canCloseUsesGhosttyAdapterRuntimeState() async throws {
        let adapter = RecordingTerminalHostAdapter()
        adapter.canCloseResult = false
        let controller = TerminalHostController(adapter: adapter)
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-unit-close", ordinal: 0)
        let surface = try await controller.createSurface(for: tab)

        #expect(await controller.canClose(surface: surface) == false)
        #expect(adapter.canCloseSurfaces == [surface])
    }

    @Test
    func releaseSurfaceDestroysGhosttySurfaceAndDetachesHostedNativeView() async throws {
        let adapter = RecordingTerminalHostAdapter()
        let controller = TerminalHostController(adapter: adapter)
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-unit-release", ordinal: 0)
        let hostView = try #require(controller.makeHostView(for: tab, isActive: true) as? TerminalSurfaceHostNSView)
        let surface = try await controller.createSurface(for: tab)
        let nativeView = try #require(adapter.nativeViewsBySurface[surface])

        #expect(hostView.attachedSurface == surface)
        #expect(hostView.embeddedSurfaceView === nativeView)

        controller.releaseSurface(for: tab.id)

        #expect(adapter.destroyedSurfaces == [surface])
        #expect(hostView.attachedSurface == nil)
        #expect(hostView.embeddedSurfaceView == nil)
        #expect(nativeView.superview == nil)
        #expect(controller.surface(for: tab.id) == nil)
    }

    @Test
    func missingNativeViewFailsSurfaceCreationAndDestroysCreatedSurface() async throws {
        let adapter = RecordingTerminalHostAdapter()
        adapter.shouldReturnNativeView = false
        let controller = TerminalHostController(adapter: adapter)
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-unit-missing-view", ordinal: 0)

        await #expect(throws: GhosttyAdapterError.surfaceCreationFailed("Ghostty native view unavailable")) {
            _ = try await controller.createSurface(for: tab)
        }

        #expect(adapter.createdSurfaces.count == 1)
        #expect(adapter.destroyedSurfaces == adapter.createdSurfaces)
        #expect(controller.surface(for: tab.id) == nil)
    }

    @Test
    func terminalHostSanitizesNonFiniteGeometryBeforeLayingOutNativeView() throws {
        let view = TerminalSurfaceHostNSView()
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/native-mac-ade-unit-finite-geometry", ordinal: 0)
        let nativeView = NSView()
        var resizeSizes: [CGSize] = []

        view.onResize = { resizeSizes.append($0) }
        view.setFrameOrigin(NSPoint(x: CGFloat.infinity, y: CGFloat.nan))
        view.setFrameSize(NSSize(width: CGFloat.infinity, height: CGFloat.nan))
        view.attach(surface: GhosttySurfaceHandle(), tab: tab, appearance: .cursorDefault, nativeView: nativeView)

        #expect(view.frame.origin.x.isFinite)
        #expect(view.frame.origin.y.isFinite)
        #expect(view.frame.width.isFinite)
        #expect(view.frame.height.isFinite)
        #expect(nativeView.frame.origin.x.isFinite)
        #expect(nativeView.frame.origin.y.isFinite)
        #expect(nativeView.frame.width.isFinite)
        #expect(nativeView.frame.height.isFinite)
        #expect(resizeSizes.allSatisfy { $0.width.isFinite && $0.height.isFinite })
    }
}

@MainActor
private final class RecordingTerminalHostAdapter: GhosttyAdapter {
    private(set) var initializeCallCount = 0
    private(set) var createdConfigurations: [GhosttyLaunchConfiguration] = []
    private(set) var createdSurfaces: [GhosttySurfaceHandle] = []
    private(set) var nativeViewRequests: [GhosttySurfaceHandle] = []
    private(set) var nativeViewsBySurface: [GhosttySurfaceHandle: NSView] = [:]
    private(set) var focusedSurfaces: [GhosttySurfaceHandle] = []
    private(set) var resizeRequests: [ResizeRequest] = []
    private(set) var appearanceUpdates: [AppearanceUpdateRequest] = []
    private(set) var canCloseSurfaces: [GhosttySurfaceHandle] = []
    private(set) var destroyedSurfaces: [GhosttySurfaceHandle] = []
    var canCloseResult = true
    var shouldReturnNativeView = true

    func initializeIfNeeded() async throws {
        initializeCallCount += 1
    }

    func createSurface(configuration: GhosttyLaunchConfiguration) async throws -> GhosttySurfaceHandle {
        createdConfigurations.append(configuration)
        let surface = GhosttySurfaceHandle()
        createdSurfaces.append(surface)
        if shouldReturnNativeView {
            nativeViewsBySurface[surface] = NSView()
        }
        return surface
    }

    func createInheritedSurface(
        from parent: GhosttySurfaceHandle,
        configuration: GhosttyLaunchConfiguration
    ) async throws -> GhosttySurfaceHandle {
        try await createSurface(configuration: configuration)
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
        canCloseSurfaces.append(surface)
        return canCloseResult
    }

    func hasExited(surface: GhosttySurfaceHandle) async -> Bool {
        false
    }

    func exitStatus(surface: GhosttySurfaceHandle) async -> Int32? {
        nil
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
