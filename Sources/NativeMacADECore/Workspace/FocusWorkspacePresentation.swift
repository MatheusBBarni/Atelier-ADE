import Foundation

public struct FocusWorkspaceSettingsPresentation: Equatable, Sendable {
    public static let title = "Focus Workspace"
    public static let summary = "Keep each session centered on one terminal tab, with one optional file tab for reference."
    public static let toggleTitle = "Enable Focus Workspace"
    public static let continuityToggleTitle = "Enable continuity"
    public static let enabledStatus = "Focus Workspace is active for future tab actions."
    public static let disabledStatus = "The default multi-tab workspace is active."
    public static let continuityEnabledStatus = "Continuity can guide relaunches back to the remembered app context."
    public static let continuityDisabledStatus = "Continuity is off. Restore uses the last app selection."
    public static let continuityUnavailableStatus = "Turn on Focus Workspace before enabling continuity."
    public static let behaviorTitle = "What changes"
    public static let behaviorDetail = "Future terminal-tab actions stay with the current terminal surface once a session already has one."
    public static let fileDetail = "Opening a file can add one file tab to the session; reopening that same file returns to it."
    public static let continuityTitle = "What continuity remembers"
    public static let continuityHelpText = "Atelier remembers app-owned project, session, and tab context only. It can recreate terminal surfaces from saved launch intent, but it does not reconnect to live tmux panes or external terminal processes."
    public static let legacyTitle = "What stays unchanged"
    public static let legacyDetail = "Existing multi-tab sessions stay intact. Focus Workspace guides new actions instead of closing or hiding old tabs."

    public var isEnabled: Bool
    public var isContinuityAvailable: Bool
    public var isContinuityEnabled: Bool

    public init(preferences: AppPreferences) {
        isEnabled = preferences.focusWorkspaceEnabled
        isContinuityAvailable = preferences.focusWorkspaceEnabled
        isContinuityEnabled = preferences.focusWorkspaceEnabled && preferences.focusWorkspaceContinuityEnabled
    }

    public var status: String {
        isEnabled ? Self.enabledStatus : Self.disabledStatus
    }

    public var continuityStatus: String {
        guard isContinuityAvailable else {
            return Self.continuityUnavailableStatus
        }
        return isContinuityEnabled ? Self.continuityEnabledStatus : Self.continuityDisabledStatus
    }
}

public struct FocusWorkspaceActiveCuePresentation: Equatable, Sendable {
    public static let label = "Focus Workspace"
    public static let continuityLabel = "Continuity"
    public static let accessibilityLabel = "Focus Workspace active"
    public static let continuityAccessibilityLabel = "Focus Workspace Continuity active"
    public static let helpText = "Focus Workspace is on. Future actions allow one terminal tab plus one optional file tab; existing multi-tab sessions are preserved."
    public static let continuityHelpText = "Focus Workspace Continuity is on. After relaunch, Atelier can return to the remembered app-owned project, session, and terminal tab context. It recreates terminal surfaces from saved launch intent; it does not reattach to live tmux panes or external processes. Use session search or the session list to confirm or switch context."

    public var isVisible: Bool
    public var isContinuityEnabled: Bool

    public init(preferences: AppPreferences) {
        isVisible = preferences.focusWorkspaceEnabled
        isContinuityEnabled = preferences.focusWorkspaceEnabled && preferences.focusWorkspaceContinuityEnabled
    }

    public var labelText: String {
        isContinuityEnabled ? Self.continuityLabel : Self.label
    }

    public var accessibilityLabelText: String {
        isContinuityEnabled ? Self.continuityAccessibilityLabel : Self.accessibilityLabel
    }

    public var activeHelpText: String {
        isContinuityEnabled ? Self.continuityHelpText : Self.helpText
    }
}

public struct FocusWorkspaceBlockedActionPresentation: Equatable, Sendable {
    public let title: String
    public let detail: String

    public init?(error: WorkspaceCommandError) {
        guard case .focusWorkspaceRejected(let violation) = error else { return nil }
        self.init(violation: violation)
    }

    public init(violation: FocusWorkspaceViolation) {
        switch violation {
        case .additionalTerminalTabBlocked:
            title = "Focus Workspace kept this session focused"
            detail = "This session already has a terminal tab. Use the current tab, or turn off Focus Workspace in Settings to use multiple terminal tabs."
        case .additionalFileTabBlocked:
            title = "Focus Workspace kept this file slot focused"
            detail = "This session already has a file tab. Reopen that file to return to it, or turn off Focus Workspace in Settings before opening a different file."
        }
    }
}
