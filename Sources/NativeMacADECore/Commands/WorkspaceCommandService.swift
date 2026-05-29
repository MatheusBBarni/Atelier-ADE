import Foundation

public enum WorkspaceCommandError: Error, Equatable, Sendable {
    case invalidProjectPath(String)
    case missingProject(UUID)
    case missingSession(UUID)
    case missingTab(UUID)
    case terminalUnavailable(String)
    case persistenceFailed(String)
}

@MainActor
public protocol WorkspaceCommandService {
    func openProject(path: String) async throws -> WorkspaceProject
    func createSession(projectID: UUID, shortcutID: UUID?) async throws -> WorkspaceSession
    func renameSession(sessionID: UUID, title: String) async throws
    func createTab(sessionID: UUID) async throws -> WorkspaceTab
    func restoreWorkspace() async throws
    func closeTab(tabID: UUID, force: Bool) async throws
}
