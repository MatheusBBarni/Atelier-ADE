import Foundation

public struct GhosttyLaunchConfiguration: Equatable, Sendable {
    public var workingDirectory: String
    public var command: String?
    public var arguments: [String]

    public init(workingDirectory: String, command: String? = nil, arguments: [String] = []) {
        self.workingDirectory = workingDirectory
        self.command = command
        self.arguments = arguments
    }
}

public struct GhosttySurfaceHandle: Equatable, Sendable {
    public let id: UUID

    public init(id: UUID = UUID()) {
        self.id = id
    }
}

@MainActor
public protocol GhosttyAdapter {
    func initializeIfNeeded() async throws
    func createSurface(configuration: GhosttyLaunchConfiguration) async throws -> GhosttySurfaceHandle
    func focus(surface: GhosttySurfaceHandle)
    func resize(surface: GhosttySurfaceHandle, columns: Int, rows: Int)
    func canClose(surface: GhosttySurfaceHandle) async -> Bool
}

@MainActor
public struct UnavailableGhosttyAdapter: GhosttyAdapter {
    public init() {}

    public func initializeIfNeeded() async throws {
        throw WorkspaceCommandError.terminalUnavailable("libghostty is not pinned or linked yet")
    }

    public func createSurface(configuration: GhosttyLaunchConfiguration) async throws -> GhosttySurfaceHandle {
        throw WorkspaceCommandError.terminalUnavailable("Cannot create Ghostty surface before task 02 pins libghostty")
    }

    public func focus(surface: GhosttySurfaceHandle) {}

    public func resize(surface: GhosttySurfaceHandle, columns: Int, rows: Int) {}

    public func canClose(surface: GhosttySurfaceHandle) async -> Bool { true }
}
