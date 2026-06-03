import Foundation

public struct FocusWorkspaceContinuityRestoreSelector: Sendable {
    public init() {}

    public func resolve(
        restoredSelection: WorkspaceSelection,
        sessions: [WorkspaceSession],
        tabs: [WorkspaceTab],
        appPreferences: AppPreferences
    ) -> WorkspaceSelection {
        guard appPreferences.focusWorkspaceEnabled,
              appPreferences.focusWorkspaceContinuityEnabled,
              let selectedProjectID = restoredSelection.projectID,
              let selectedSessionID = restoredSelection.sessionID,
              sessions.contains(where: { $0.id == selectedSessionID && $0.projectID == selectedProjectID })
        else {
            return restoredSelection
        }

        guard let terminalTab = tabs
            .filter({ $0.sessionID == selectedSessionID && $0.kind == .terminal })
            .sorted(by: terminalRestoreSort)
            .first
        else {
            return restoredSelection
        }

        return WorkspaceSelection(
            projectID: selectedProjectID,
            sessionID: selectedSessionID,
            tabID: terminalTab.id
        )
    }

    private func terminalRestoreSort(_ lhs: WorkspaceTab, _ rhs: WorkspaceTab) -> Bool {
        if lhs.lastActivatedAt != rhs.lastActivatedAt {
            return lhs.lastActivatedAt > rhs.lastActivatedAt
        }

        if lhs.ordinal != rhs.ordinal {
            return lhs.ordinal < rhs.ordinal
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }
}
