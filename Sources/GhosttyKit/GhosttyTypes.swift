import AppKit
import Foundation

public struct GhosttyLaunchConfiguration: Equatable, Sendable {
    public var workingDirectory: String
    public var command: String?
    public var arguments: [String]
    public var nativeCommand: String?
    public var environment: [String: String]
    public var inheritedSurfaceID: UUID?
    public var appearance: TerminalAppearance

    public init(
        workingDirectory: String,
        command: String? = nil,
        arguments: [String] = [],
        nativeCommand: String? = nil,
        environment: [String: String] = [:],
        inheritedSurfaceID: UUID? = nil,
        appearance: TerminalAppearance = .cursorDefault
    ) {
        self.workingDirectory = workingDirectory
        self.command = command
        self.arguments = arguments
        self.nativeCommand = nativeCommand
        self.environment = environment
        self.inheritedSurfaceID = inheritedSurfaceID
        self.appearance = appearance
    }

    public static func inheritedTab(
        from parent: GhosttySurfaceHandle,
        workingDirectory: String,
        command: String? = nil,
        arguments: [String] = [],
        nativeCommand: String? = nil,
        environment: [String: String] = [:],
        appearance: TerminalAppearance = .cursorDefault
    ) -> GhosttyLaunchConfiguration {
        GhosttyLaunchConfiguration(
            workingDirectory: workingDirectory,
            command: command,
            arguments: arguments,
            nativeCommand: nativeCommand,
            environment: environment,
            inheritedSurfaceID: parent.id,
            appearance: appearance
        )
    }

    public static func decodeArguments(from json: String?) -> [String] {
        guard let json,
              let data = json.data(using: .utf8),
              let arguments = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return arguments
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

    public static let cursorDefault = TerminalAppearance(
        backgroundHex: "#0D1117",
        foregroundHex: "#E6EDF3",
        cursorHex: "#58A6FF",
        selectionHex: "#30363D"
    )

    public static let nordDefault = TerminalAppearance(
        backgroundHex: "#2E3440",
        foregroundHex: "#ECEFF4",
        cursorHex: "#88C0D0",
        selectionHex: "#4C566A"
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
}

@MainActor
public protocol GhosttySurfaceRuntime {
    func initializeIfNeeded() async throws
    func createSurface(configuration: GhosttyLaunchConfiguration) async throws -> GhosttySurfaceHandle
    func nativeView(for surface: GhosttySurfaceHandle) -> NSView?
    func focus(surface: GhosttySurfaceHandle)
    func resize(surface: GhosttySurfaceHandle, columns: Int, rows: Int)
    func updateAppearance(surface: GhosttySurfaceHandle, appearance: TerminalAppearance)
    func canClose(surface: GhosttySurfaceHandle) async -> Bool
    func hasExited(surface: GhosttySurfaceHandle) async -> Bool
    func exitStatus(surface: GhosttySurfaceHandle) async -> Int32?
    func destroySurface(_ surface: GhosttySurfaceHandle)
}
