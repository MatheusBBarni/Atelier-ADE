import Foundation

public enum WorkspaceCommandError: Error, Equatable, Sendable {
    case invalidProjectPath(String)
    case invalidFilePath(String)
    case filePathOutsideProject(filePath: String, projectRoot: String)
    case fileAccessRejected(WorkspaceFileAccessError)
    case fileBufferUnavailable(UUID)
    case invalidFileTab(UUID, String)
    case externalEditorFailed(String)
    case invalidSessionTitle(String)
    case missingProject(UUID)
    case missingSession(UUID)
    case missingTab(UUID)
    case missingShortcut(UUID)
    case settingsValidationFailed(WorkspaceSettingsValidationFailure)
    case focusWorkspaceRejected(FocusWorkspaceViolation)
    case builtInShortcutDeletionRejected(UUID)
    case customShortcutResetRejected(UUID)
    case closeRejected(UUID)
    case dirtyFileTabCloseRejected(UUID)
    case invalidProjectOrder(String)
    case invalidTabOrder(String)
    case reorderRestoreAlignmentFailed(String)
    case terminalUnavailable(String)
    case persistenceFailed(String)
}

public enum WorkspaceSettingsValidationFailure: Error, Equatable, Sendable {
    case unknownThemeID(String)
    case terminalFontSizeOutOfBounds(value: Double, minimum: Double, maximum: Double)
    case unknownDefaultSessionShortcut(UUID)
    case duplicateManagedKeybinding(commandID: AppCommandID, conflictingCommandID: AppCommandID)
    case mismatchedKeybindingCommandID(expected: AppCommandID, actual: AppCommandID)
    case emptyKeybinding(AppCommandID)
    case malformedLaunchArgumentsJSON(UUID)
}

public extension WorkspaceSettingsValidationFailure {
    var diagnosticReason: String {
        switch self {
        case .unknownThemeID(let themeID):
            return "unknown_theme_id:\(themeID)"
        case .terminalFontSizeOutOfBounds(let value, let minimum, let maximum):
            return "terminal_font_size_out_of_range:\(value):min:\(minimum):max:\(maximum)"
        case .unknownDefaultSessionShortcut(let shortcutID):
            return "unknown_default_profile:\(shortcutID.uuidString)"
        case .duplicateManagedKeybinding(let commandID, let conflictingCommandID):
            return "duplicate_managed_keybinding:\(commandID.rawValue):\(conflictingCommandID.rawValue)"
        case .mismatchedKeybindingCommandID(let expected, let actual):
            return "mismatched_keybinding_command_id:\(expected.rawValue):\(actual.rawValue)"
        case .emptyKeybinding(let commandID):
            return "empty_keybinding:\(commandID.rawValue)"
        case .malformedLaunchArgumentsJSON(let shortcutID):
            return "malformed_launch_arguments_json:\(shortcutID.uuidString)"
        }
    }
}

@MainActor
public protocol WorkspaceCommandService: AppShellStartupServicing {
    func openProject(path: String) async throws -> WorkspaceProject
    func removeProject(id: UUID) async throws
    func removeSession(id: UUID) async throws
    func selectProject(id: UUID?) async throws
    func selectSession(id: UUID?) async throws
    func selectTab(id: UUID?) async throws
    func reorderProjects(_ orderedProjectIDs: [UUID]) async throws
    func reorderTabs(sessionID: UUID, orderedVisibleTabIDs: [UUID]) async throws
    func recordSettingsOpened(surface: String)
    func loadAppPreferences() async throws -> AppPreferences
    func saveAppPreferences(_ preferences: AppPreferences) async throws
    func availableSessionShortcuts() async throws -> [SessionShortcut]
    func saveSessionShortcut(_ shortcut: SessionShortcut) async throws -> SessionShortcut
    func deleteSessionShortcut(id: UUID) async throws
    func resetBuiltInSessionShortcut(id: UUID) async throws -> SessionShortcut
    func createSession(projectID: UUID, shortcutID: UUID?) async throws -> WorkspaceSession
    func renameSession(sessionID: UUID, title: String) async throws
    func createTab(sessionID: UUID) async throws -> WorkspaceTab
    func createPlainTab(sessionID: UUID) async throws -> WorkspaceTab
    func createDefaultAgentTab(sessionID: UUID) async throws -> WorkspaceTab
    func createAgentTab(sessionID: UUID, shortcutID: UUID) async throws -> WorkspaceTab
    func renameTab(tabID: UUID, title: String?) async throws -> WorkspaceTab
    func openFileTab(sessionID: UUID, path: String) async throws -> WorkspaceTab
    func saveFileTab(tabID: UUID) async throws
    func revertFileTab(tabID: UUID) async throws
    func openFileInExternalEditor(tabID: UUID) async throws
    func renameWorkspaceItem(projectID: UUID, path: String, to destinationPath: String) async throws
    func deleteWorkspaceItem(projectID: UUID, path: String) async throws
    @discardableResult
    func restoreWorkspace() async throws -> RestoreWorkspaceResult
    func closeTab(tabID: UUID, force: Bool) async throws
    func recordTerminalProcessExit(tabID: UUID, exitStatus: Int32?)
    func recentWorkspaceEvents() -> [WorkspaceLogEvent]
    func pilotDiagnostics() -> PilotDiagnostics
}
