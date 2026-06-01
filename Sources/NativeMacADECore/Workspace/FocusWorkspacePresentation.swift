import Foundation

public struct FocusWorkspaceSettingsPresentation: Equatable, Sendable {
    public static let title = "Focus Workspace"
    public static let summary = "Keep each session centered on one terminal tab, with one optional file tab for reference."
    public static let toggleTitle = "Enable Focus Workspace"
    public static let enabledStatus = "Focus Workspace is active for future tab actions."
    public static let disabledStatus = "The default multi-tab workspace is active."
    public static let behaviorTitle = "What changes"
    public static let behaviorDetail = "Future terminal-tab actions stay with the current terminal surface once a session already has one."
    public static let fileDetail = "Opening a file can add one file tab to the session; reopening that same file returns to it."
    public static let legacyTitle = "What stays unchanged"
    public static let legacyDetail = "Existing multi-tab sessions stay intact. Focus Workspace guides new actions instead of closing or hiding old tabs."

    public var isEnabled: Bool

    public init(preferences: AppPreferences) {
        isEnabled = preferences.focusWorkspaceEnabled
    }

    public var status: String {
        isEnabled ? Self.enabledStatus : Self.disabledStatus
    }
}

public struct FocusWorkspaceActiveCuePresentation: Equatable, Sendable {
    public static let label = "Focus Workspace"
    public static let accessibilityLabel = "Focus Workspace active"
    public static let helpText = "Focus Workspace is on. Future actions allow one terminal tab plus one optional file tab; existing multi-tab sessions are preserved."

    public var isVisible: Bool

    public init(preferences: AppPreferences) {
        isVisible = preferences.focusWorkspaceEnabled
    }
}
