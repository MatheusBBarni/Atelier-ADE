import AppKit
import Foundation
import Testing
@testable import GhosttyKit

@Suite(.serialized)
@MainActor
struct GhosttySurfaceRuntimeTests {
    @Test
    func initializationUsesOneSharedAppContextAcrossRuntimeInstances() async throws {
        LiveGhosttySurfaceRuntime.resetForTesting()
        let firstRuntime = LiveGhosttySurfaceRuntime()
        let secondRuntime = LiveGhosttySurfaceRuntime()

        try await firstRuntime.initializeIfNeeded()
        try await firstRuntime.initializeIfNeeded()
        try await secondRuntime.initializeIfNeeded()

        let firstSurface = try await firstRuntime.createSurface(
            configuration: GhosttyLaunchConfiguration(workingDirectory: "/tmp/ade-ghostty-one")
        )
        let secondSurface = try await secondRuntime.createSurface(
            configuration: GhosttyLaunchConfiguration(workingDirectory: "/tmp/ade-ghostty-two")
        )

        #expect(CGhosttyRuntime.initializeCallCount == 1)
        #expect(firstSurface.appContextID == 1)
        #expect(secondSurface.appContextID == 1)
        #expect(firstSurface.rawSurfaceID != secondSurface.rawSurfaceID)
    }

    @Test
    func exposesPinnedGhosttyRevisionFromCGhostty() {
        #expect(LiveGhosttySurfaceRuntime.pinnedRevision == "cb36966a752982014827a9cabcf630ec3788b3d9")
        #expect(CGhosttyRuntime.pinnedRevision == LiveGhosttySurfaceRuntime.pinnedRevision)
    }

    @Test
    func surfaceCreationPreservesLaunchAndAppearancePayloads() async throws {
        LiveGhosttySurfaceRuntime.resetForTesting()
        let runtime = LiveGhosttySurfaceRuntime()
        let appearance = TerminalAppearance(
            backgroundHex: "#101820",
            foregroundHex: "#F2AA4C",
            cursorHex: "#2F7CF6",
            selectionHex: "#223344",
            fontName: "SpaceMono Nerd Font",
            fontSize: 15
        )
        let configuration = GhosttyLaunchConfiguration(
            workingDirectory: "/tmp/ade-ghostty-payload",
            command: "codex",
            arguments: ["--full-auto", "-c", "tui.raw_output_mode=true"],
            environment: ["CODEX_TUI_DISABLE_KEYBOARD_ENHANCEMENT": "1"],
            appearance: appearance
        )

        let surface = try await runtime.createSurface(configuration: configuration)
        let storedConfiguration = try #require(runtime.configuration(for: surface))
        let nativeView = try #require(runtime.nativeView(for: surface))

        #expect(storedConfiguration.workingDirectory == "/tmp/ade-ghostty-payload")
        #expect(storedConfiguration.command == "codex")
        #expect(storedConfiguration.arguments == ["--full-auto", "-c", "tui.raw_output_mode=true"])
        #expect(storedConfiguration.environment == ["CODEX_TUI_DISABLE_KEYBOARD_ENHANCEMENT": "1"])
        #expect(runtime.environmentVariableCount(surface: surface) == 1)
        #expect(storedConfiguration.appearance == appearance)
        #expect(runtime.nativeView(for: surface) === nativeView)
        #expect(nativeView.accessibilityLabel() == "Ghostty bridge diagnostic surface")
        #expect(nativeView.subviews.isEmpty == false)
        #expect(nativeView.layer?.backgroundColor != nil)
    }

    @Test
    func inheritedSurfaceCreationPreservesParentRawContext() async throws {
        LiveGhosttySurfaceRuntime.resetForTesting()
        let runtime = LiveGhosttySurfaceRuntime()

        let parent = try await runtime.createSurface(
            configuration: GhosttyLaunchConfiguration(workingDirectory: "/tmp/ade-ghostty-parent")
        )
        let child = try await runtime.createSurface(
            configuration: .inheritedTab(
                from: parent,
                workingDirectory: "/tmp/ade-ghostty-child",
                command: "zsh",
                arguments: ["-l"]
            )
        )

        #expect(child.inheritedSurfaceRawID == parent.rawSurfaceID)
    }

    @Test
    func lifecycleCallsUpdateWrapperSurfaceStateAndDestroyRemovesSurface() async throws {
        LiveGhosttySurfaceRuntime.resetForTesting()
        let runtime = LiveGhosttySurfaceRuntime()
        let surface = try await runtime.createSurface(
            configuration: GhosttyLaunchConfiguration(workingDirectory: "/tmp/ade-ghostty-lifecycle")
        )

        runtime.focus(surface: surface)
        runtime.resize(surface: surface, columns: 132, rows: 43)

        #expect(runtime.isFocused(surface: surface))
        #expect(runtime.size(for: surface)?.columns == 132)
        #expect(runtime.size(for: surface)?.rows == 43)
        #expect(await runtime.canClose(surface: surface))
        #expect(await runtime.hasExited(surface: surface) == false)
        #expect(await runtime.exitStatus(surface: surface) == 0)

        runtime.destroySurface(surface)

        #expect(runtime.nativeView(for: surface) == nil)
        #expect(runtime.configuration(for: surface) == nil)
        #expect(await runtime.canClose(surface: surface))
        #expect(await runtime.hasExited(surface: surface))
        #expect(await runtime.exitStatus(surface: surface) == nil)
    }

    @Test
    func appearanceUpdatesReachExistingSurfaceConfigurationAndNativeView() async throws {
        LiveGhosttySurfaceRuntime.resetForTesting()
        let runtime = LiveGhosttySurfaceRuntime()
        let surface = try await runtime.createSurface(
            configuration: GhosttyLaunchConfiguration(
                workingDirectory: "/tmp/ade-ghostty-appearance",
                appearance: .cursorDefault
            )
        )
        let nativeView = try #require(runtime.nativeView(for: surface))

        runtime.updateAppearance(surface: surface, appearance: .nordDefault)

        #expect(runtime.configuration(for: surface)?.appearance == .nordDefault)
        #expect(nativeView.layer?.backgroundColor == NSColor.ghosttyKitTestColor(hex: TerminalAppearance.nordDefault.backgroundHex).cgColor)
    }

    @Test
    func forcedInitializationFailureMapsToUserVisibleGhosttyError() async {
        LiveGhosttySurfaceRuntime.resetForTesting()
        let runtime = LiveGhosttySurfaceRuntime(
            bridge: CGhosttyRuntime(forceInitializationFailure: true)
        )

        await #expect(throws: GhosttyAdapterError.initializationFailed("Pinned libghostty app context initialization failed")) {
            try await runtime.initializeIfNeeded()
        }
    }

    @Test
    func forcedSurfaceCreationFailureMapsToUserVisibleGhosttyError() async {
        LiveGhosttySurfaceRuntime.resetForTesting()
        let runtime = LiveGhosttySurfaceRuntime(
            bridge: CGhosttyRuntime(forceSurfaceCreationFailure: true)
        )

        await #expect(throws: GhosttyAdapterError.surfaceCreationFailed("Pinned libghostty surface creation failed")) {
            _ = try await runtime.createSurface(
                configuration: GhosttyLaunchConfiguration(workingDirectory: "/tmp/ade-ghostty-failure")
            )
        }
    }
}

private extension NSColor {
    static func ghosttyKitTestColor(hex: String) -> NSColor {
        let normalized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: normalized).scanHexInt64(&value)
        return NSColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
