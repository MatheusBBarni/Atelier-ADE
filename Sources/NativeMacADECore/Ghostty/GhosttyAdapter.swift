import AppKit
import Foundation
import GhosttyKit

@MainActor
public struct GhosttyLifecycleCallbacks {
    public var surfaceCreated: ((GhosttySurfaceHandle) -> Void)?
    public var surfaceExited: ((GhosttySurfaceHandle) -> Void)?

    public init(
        surfaceCreated: ((GhosttySurfaceHandle) -> Void)? = nil,
        surfaceExited: ((GhosttySurfaceHandle) -> Void)? = nil
    ) {
        self.surfaceCreated = surfaceCreated
        self.surfaceExited = surfaceExited
    }
}

@MainActor
public protocol GhosttyAdapter {
    var usesEmbeddedSessionDriver: Bool { get }
    func initializeIfNeeded() async throws
    func createSurface(configuration: GhosttyLaunchConfiguration) async throws -> GhosttySurfaceHandle
    func createInheritedSurface(
        from parent: GhosttySurfaceHandle,
        configuration: GhosttyLaunchConfiguration
    ) async throws -> GhosttySurfaceHandle
    func nativeView(for surface: GhosttySurfaceHandle) -> NSView?
    func focus(surface: GhosttySurfaceHandle)
    func resize(surface: GhosttySurfaceHandle, columns: Int, rows: Int)
    func canClose(surface: GhosttySurfaceHandle) async -> Bool
    func hasExited(surface: GhosttySurfaceHandle) async -> Bool
    func exitStatus(surface: GhosttySurfaceHandle) async -> Int32?
    func destroySurface(_ surface: GhosttySurfaceHandle)
}

public extension GhosttyAdapter {
    var usesEmbeddedSessionDriver: Bool { false }

    func nativeView(for surface: GhosttySurfaceHandle) -> NSView? {
        nil
    }
}

@MainActor
public final class LiveGhosttyAdapter: GhosttyAdapter {
    public static let pinnedRevision = LiveGhosttySurfaceRuntime.pinnedRevision

    private let runtime: any GhosttySurfaceRuntime
    private let callbacks: GhosttyLifecycleCallbacks

    public init(
        callbacks: GhosttyLifecycleCallbacks = GhosttyLifecycleCallbacks()
    ) {
        self.runtime = LiveGhosttySurfaceRuntime()
        self.callbacks = callbacks
    }

    init(
        runtime: any GhosttySurfaceRuntime,
        callbacks: GhosttyLifecycleCallbacks = GhosttyLifecycleCallbacks()
    ) {
        self.runtime = runtime
        self.callbacks = callbacks
    }

    public var usesEmbeddedSessionDriver: Bool { false }

    func resetSharedAppContextForTesting() {
        LiveGhosttySurfaceRuntime.resetForTesting()
    }

    public func initializeIfNeeded() async throws {
        try await runtime.initializeIfNeeded()
    }

    public func createSurface(configuration: GhosttyLaunchConfiguration) async throws -> GhosttySurfaceHandle {
        let surface = try await runtime.createSurface(configuration: configuration)
        callbacks.surfaceCreated?(surface)
        return surface
    }

    public func createInheritedSurface(
        from parent: GhosttySurfaceHandle,
        configuration: GhosttyLaunchConfiguration
    ) async throws -> GhosttySurfaceHandle {
        var inheritedConfiguration = configuration
        if inheritedConfiguration.inheritedSurfaceID == nil {
            inheritedConfiguration.inheritedSurfaceID = parent.id
        }
        return try await createSurface(configuration: inheritedConfiguration)
    }

    public func focus(surface: GhosttySurfaceHandle) {
        runtime.focus(surface: surface)
    }

    public func nativeView(for surface: GhosttySurfaceHandle) -> NSView? {
        runtime.nativeView(for: surface)
    }

    public func resize(surface: GhosttySurfaceHandle, columns: Int, rows: Int) {
        runtime.resize(surface: surface, columns: columns, rows: rows)
    }

    public func canClose(surface: GhosttySurfaceHandle) async -> Bool {
        await runtime.canClose(surface: surface)
    }

    public func hasExited(surface: GhosttySurfaceHandle) async -> Bool {
        let exited = await runtime.hasExited(surface: surface)
        if exited { callbacks.surfaceExited?(surface) }
        return exited
    }

    public func exitStatus(surface: GhosttySurfaceHandle) async -> Int32? {
        await runtime.exitStatus(surface: surface)
    }

    public func destroySurface(_ surface: GhosttySurfaceHandle) {
        runtime.destroySurface(surface)
    }
}
