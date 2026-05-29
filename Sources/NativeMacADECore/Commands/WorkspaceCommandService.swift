import Foundation

public enum WorkspaceCommandError: Error, Equatable, Sendable {
    case invalidProjectPath(String)
    case invalidSessionTitle(String)
    case missingProject(UUID)
    case missingSession(UUID)
    case missingTab(UUID)
    case missingShortcut(UUID)
    case closeRejected(UUID)
    case terminalUnavailable(String)
    case persistenceFailed(String)
}

@MainActor
public protocol WorkspaceCommandService {
    func openProject(path: String) async throws -> WorkspaceProject
    func removeProject(id: UUID) async throws
    func selectProject(id: UUID?) async throws
    func selectSession(id: UUID?) async throws
    func selectTab(id: UUID?) async throws
    func availableSessionShortcuts() async throws -> [SessionShortcut]
    func createSession(projectID: UUID, shortcutID: UUID?) async throws -> WorkspaceSession
    func renameSession(sessionID: UUID, title: String) async throws
    func createTab(sessionID: UUID) async throws -> WorkspaceTab
    @discardableResult
    func restoreWorkspace() async throws -> RestoreWorkspaceResult
    func closeTab(tabID: UUID, force: Bool) async throws
    func recordTerminalProcessExit(tabID: UUID, exitStatus: Int32?)
    func recentWorkspaceEvents() -> [WorkspaceLogEvent]
    func pilotDiagnostics() -> PilotDiagnostics
}
