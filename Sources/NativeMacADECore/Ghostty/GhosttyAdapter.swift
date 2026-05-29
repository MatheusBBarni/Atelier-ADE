import Foundation

public struct GhosttyLaunchConfiguration: Equatable, Sendable {
    public var workingDirectory: String
    public var command: String?
    public var arguments: [String]
    public var inheritedSurfaceID: UUID?
    public var appearance: TerminalAppearance

    public init(
        workingDirectory: String,
        command: String? = nil,
        arguments: [String] = [],
        inheritedSurfaceID: UUID? = nil,
        appearance: TerminalAppearance = .nordDefault
    ) {
        self.workingDirectory = workingDirectory
        self.command = command
        self.arguments = arguments
        self.inheritedSurfaceID = inheritedSurfaceID
        self.appearance = appearance
    }

    public static func inheritedTab(
        from parent: GhosttySurfaceHandle,
        workingDirectory: String,
        command: String? = nil,
        arguments: [String] = []
    ) -> GhosttyLaunchConfiguration {
        GhosttyLaunchConfiguration(
            workingDirectory: workingDirectory,
            command: command,
            arguments: arguments,
            inheritedSurfaceID: parent.id
        )
    }
}

public struct TerminalAppearance: Equatable, Sendable {
    public var backgroundHex: String
    public var foregroundHex: String
    public var cursorHex: String
    public var selectionHex: String
    public var fontName: String
    public var fontSize: Double

    public init(
        backgroundHex: String,
        foregroundHex: String,
        cursorHex: String,
        selectionHex: String,
        fontName: String = "SF Mono",
        fontSize: Double = 13
    ) {
        self.backgroundHex = backgroundHex
        self.foregroundHex = foregroundHex
        self.cursorHex = cursorHex
        self.selectionHex = selectionHex
        self.fontName = fontName
        self.fontSize = fontSize
    }

    public static let nordDefault = TerminalAppearance(
        backgroundHex: NordTheme.polarNight0.hex,
        foregroundHex: NordTheme.snowStorm2.hex,
        cursorHex: NordTheme.frost1.hex,
        selectionHex: NordTheme.polarNight3.hex
    )
}

public struct GhosttySurfaceHandle: Equatable, Hashable, Sendable {
    public let id: UUID
    let rawSurfaceID: UInt64
    let appContextID: UInt64
    let inheritedSurfaceRawID: UInt64?

    public init(id: UUID = UUID()) {
        self.init(id: id, rawSurfaceID: 0, appContextID: 0, inheritedSurfaceRawID: nil)
    }

    init(
        id: UUID = UUID(),
        rawSurfaceID: UInt64 = 0,
        appContextID: UInt64 = 0,
        inheritedSurfaceRawID: UInt64? = nil
    ) {
        self.id = id
        self.rawSurfaceID = rawSurfaceID
        self.appContextID = appContextID
        self.inheritedSurfaceRawID = inheritedSurfaceRawID
    }
}

public enum GhosttyAdapterError: Error, Equatable, Sendable {
    case initializationFailed(String)
    case surfaceCreationFailed(String)
    case invalidAppContext(String)
    case unknown(String)

    public var userVisibleMessage: String {
        switch self {
        case .initializationFailed(let message),
             .surfaceCreationFailed(let message),
             .invalidAppContext(let message),
             .unknown(let message):
            return message
        }
    }

    public var workspaceCommandError: WorkspaceCommandError {
        .terminalUnavailable(userVisibleMessage)
    }
}

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
    func initializeIfNeeded() async throws
    func createSurface(configuration: GhosttyLaunchConfiguration) async throws -> GhosttySurfaceHandle
    func createInheritedSurface(
        from parent: GhosttySurfaceHandle,
        configuration: GhosttyLaunchConfiguration
    ) async throws -> GhosttySurfaceHandle
    func focus(surface: GhosttySurfaceHandle)
    func resize(surface: GhosttySurfaceHandle, columns: Int, rows: Int)
    func canClose(surface: GhosttySurfaceHandle) async -> Bool
    func hasExited(surface: GhosttySurfaceHandle) async -> Bool
}

@MainActor
public final class LiveGhosttyAdapter: GhosttyAdapter {
    public static let pinnedRevision = CGhosttyRuntime.pinnedRevision

    private let runtime: CGhosttyRuntime
    private let callbacks: GhosttyLifecycleCallbacks
    private static var sharedAppContext: CGhosttyRuntime.AppContext?
    private var surfaces: [UUID: CGhosttyRuntime.Surface] = [:]

    public init(
        callbacks: GhosttyLifecycleCallbacks = GhosttyLifecycleCallbacks()
    ) {
        self.runtime = CGhosttyRuntime()
        self.callbacks = callbacks
    }

    init(
        runtime: CGhosttyRuntime,
        callbacks: GhosttyLifecycleCallbacks = GhosttyLifecycleCallbacks()
    ) {
        self.runtime = runtime
        self.callbacks = callbacks
    }

    func resetSharedAppContextForTesting() {
        Self.sharedAppContext = nil
        CGhosttyRuntime.resetForTesting()
    }

    public func initializeIfNeeded() async throws {
        if Self.sharedAppContext != nil { return }
        Self.sharedAppContext = try runtime.initialize()
    }

    public func createSurface(configuration: GhosttyLaunchConfiguration) async throws -> GhosttySurfaceHandle {
        try await initializeIfNeeded()
        return try createSurface(configuration: configuration, inheritedSurfaceID: nil)
    }

    public func createInheritedSurface(
        from parent: GhosttySurfaceHandle,
        configuration: GhosttyLaunchConfiguration
    ) async throws -> GhosttySurfaceHandle {
        try await initializeIfNeeded()
        return try createSurface(configuration: configuration, inheritedSurfaceID: parent.rawSurfaceID)
    }

    public func focus(surface: GhosttySurfaceHandle) {
        guard var rawSurface = surfaces[surface.id] else { return }
        runtime.focus(surface: &rawSurface, focused: true)
        surfaces[surface.id] = rawSurface
    }

    public func resize(surface: GhosttySurfaceHandle, columns: Int, rows: Int) {
        guard var rawSurface = surfaces[surface.id] else { return }
        runtime.resize(surface: &rawSurface, columns: columns, rows: rows)
        surfaces[surface.id] = rawSurface
    }

    public func canClose(surface: GhosttySurfaceHandle) async -> Bool {
        guard let rawSurface = surfaces[surface.id] else { return true }
        return runtime.canClose(surface: rawSurface)
    }

    public func hasExited(surface: GhosttySurfaceHandle) async -> Bool {
        guard let rawSurface = surfaces[surface.id] else { return true }
        let exited = runtime.hasExited(surface: rawSurface)
        if exited { callbacks.surfaceExited?(surface) }
        return exited
    }

    private func createSurface(
        configuration: GhosttyLaunchConfiguration,
        inheritedSurfaceID: UInt64?
    ) throws -> GhosttySurfaceHandle {
        guard let appContext = Self.sharedAppContext else {
            throw GhosttyAdapterError.invalidAppContext("Ghostty app context is not initialized")
        }

        let rawSurface = try runtime.createSurface(
            appContext: appContext,
            configuration: configuration,
            inheritedSurfaceID: inheritedSurfaceID
        )
        let handle = GhosttySurfaceHandle(
            rawSurfaceID: rawSurface.id,
            appContextID: rawSurface.appContextID,
            inheritedSurfaceRawID: rawSurface.inheritedSurfaceID
        )
        surfaces[handle.id] = rawSurface
        callbacks.surfaceCreated?(handle)
        return handle
    }
}
