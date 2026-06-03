import AppKit
import Foundation

@MainActor
public final class LiveGhosttySurfaceRuntime: GhosttySurfaceRuntime {
    public static let pinnedRevision = CGhosttyRuntime.pinnedRevision

    private static var sharedAppContext: CGhosttyRuntime.AppContext?

    private let cRuntime: CGhosttyRuntime
    private var surfaces: [UUID: SurfaceRecord] = [:]

    public init() {
        self.cRuntime = CGhosttyRuntime()
    }

    init(bridge: CGhosttyRuntime) {
        self.cRuntime = bridge
    }

    public static func resetForTesting() {
        sharedAppContext = nil
        CGhosttyRuntime.resetForTesting()
    }

    public func initializeIfNeeded() async throws {
        if Self.sharedAppContext != nil { return }
        Self.sharedAppContext = try cRuntime.initialize()
    }

    public func createSurface(configuration: GhosttyLaunchConfiguration) async throws -> GhosttySurfaceHandle {
        try await initializeIfNeeded()

        guard let appContext = Self.sharedAppContext else {
            throw GhosttyAdapterError.invalidAppContext("Ghostty app context is not initialized")
        }

        let inheritedRawID = configuration.inheritedSurfaceID.flatMap { surfaces[$0]?.rawSurface.id }
        let rawSurface = try cRuntime.createSurface(
            appContext: appContext,
            configuration: configuration,
            inheritedSurfaceID: inheritedRawID
        )
        let handle = GhosttySurfaceHandle(
            rawSurfaceID: rawSurface.id,
            appContextID: rawSurface.appContextID,
            inheritedSurfaceRawID: rawSurface.inheritedSurfaceID
        )

        surfaces[handle.id] = SurfaceRecord(
            configuration: configuration,
            rawSurface: rawSurface,
            nativeView: NSView(),
            focused: false,
            columns: 80,
            rows: 24
        )
        return handle
    }

    public func nativeView(for surface: GhosttySurfaceHandle) -> NSView? {
        surfaces[surface.id]?.nativeView
    }

    public func focus(surface: GhosttySurfaceHandle) {
        guard var record = surfaces[surface.id] else { return }
        cRuntime.focus(surface: &record.rawSurface, focused: true)
        record.focused = true
        surfaces[surface.id] = record
    }

    public func resize(surface: GhosttySurfaceHandle, columns: Int, rows: Int) {
        guard var record = surfaces[surface.id] else { return }
        cRuntime.resize(surface: &record.rawSurface, columns: columns, rows: rows)
        record.columns = columns
        record.rows = rows
        surfaces[surface.id] = record
    }

    public func canClose(surface: GhosttySurfaceHandle) async -> Bool {
        guard let record = surfaces[surface.id] else { return true }
        return cRuntime.canClose(surface: record.rawSurface)
    }

    public func hasExited(surface: GhosttySurfaceHandle) async -> Bool {
        guard let record = surfaces[surface.id] else { return true }
        return cRuntime.hasExited(surface: record.rawSurface)
    }

    public func exitStatus(surface: GhosttySurfaceHandle) async -> Int32? {
        guard let record = surfaces[surface.id] else { return nil }
        return cRuntime.exitStatus(surface: record.rawSurface)
    }

    public func destroySurface(_ surface: GhosttySurfaceHandle) {
        guard var record = surfaces[surface.id] else { return }
        cRuntime.destroy(surface: &record.rawSurface)
        surfaces[surface.id] = nil
    }

    func configuration(for surface: GhosttySurfaceHandle) -> GhosttyLaunchConfiguration? {
        surfaces[surface.id]?.configuration
    }

    func isFocused(surface: GhosttySurfaceHandle) -> Bool {
        surfaces[surface.id]?.focused == true
    }

    func size(for surface: GhosttySurfaceHandle) -> (columns: Int, rows: Int)? {
        guard let record = surfaces[surface.id] else { return nil }
        return (record.columns, record.rows)
    }
}

@MainActor
private struct SurfaceRecord {
    var configuration: GhosttyLaunchConfiguration
    var rawSurface: CGhosttyRuntime.Surface
    var nativeView: NSView
    var focused: Bool
    var columns: Int
    var rows: Int
}
