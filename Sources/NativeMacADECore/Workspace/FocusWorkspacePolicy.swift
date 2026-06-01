import Foundation

public struct FocusWorkspaceSessionState: Equatable, Sendable {
    public var enabled: Bool
    public var terminalTabCount: Int
    public var fileTabCount: Int
    public var visibleTabCount: Int

    public init(
        enabled: Bool,
        terminalTabCount: Int,
        fileTabCount: Int,
        visibleTabCount: Int? = nil
    ) {
        self.enabled = enabled
        self.terminalTabCount = terminalTabCount
        self.fileTabCount = fileTabCount
        self.visibleTabCount = visibleTabCount ?? terminalTabCount + fileTabCount
    }

    public init(enabled: Bool, tabs: [WorkspaceTab]) {
        self.init(
            enabled: enabled,
            terminalTabCount: tabs.filter { $0.kind == .terminal }.count,
            fileTabCount: tabs.filter { $0.kind == .file }.count,
            visibleTabCount: tabs.count
        )
    }

    public var isCompliant: Bool {
        !enabled || !hasTabOverflow
    }

    public var hasLegacyOverflow: Bool {
        enabled && hasTabOverflow
    }

    private var hasTabOverflow: Bool {
        terminalTabCount > 1 || fileTabCount > 1
    }
}

public enum FocusWorkspaceViolation: Error, Equatable, Sendable {
    case additionalTerminalTabBlocked
    case additionalFileTabBlocked
}

public struct FocusWorkspacePolicyDecision: Equatable, Sendable {
    public var violation: FocusWorkspaceViolation?

    public var isAllowed: Bool {
        violation == nil
    }

    public init(violation: FocusWorkspaceViolation?) {
        self.violation = violation
    }

    public static let allowed = FocusWorkspacePolicyDecision(violation: nil)

    public static func blocked(_ violation: FocusWorkspaceViolation) -> FocusWorkspacePolicyDecision {
        FocusWorkspacePolicyDecision(violation: violation)
    }
}

public enum FocusWorkspacePolicy {
    public static func terminalCreationDecision(
        in state: FocusWorkspaceSessionState
    ) -> FocusWorkspacePolicyDecision {
        guard state.enabled, state.terminalTabCount > 0 else {
            return .allowed
        }
        return .blocked(.additionalTerminalTabBlocked)
    }

    public static func canCreateTerminal(in state: FocusWorkspaceSessionState) -> Bool {
        terminalCreationDecision(in: state).isAllowed
    }

    public static func fileOpenDecision(
        in state: FocusWorkspaceSessionState,
        openingSameFile: Bool
    ) -> FocusWorkspacePolicyDecision {
        guard state.enabled, !openingSameFile, state.fileTabCount > 0 else {
            return .allowed
        }
        return .blocked(.additionalFileTabBlocked)
    }

    public static func canOpenFile(
        in state: FocusWorkspaceSessionState,
        openingSameFile: Bool
    ) -> Bool {
        fileOpenDecision(in: state, openingSameFile: openingSameFile).isAllowed
    }
}

public extension WorkspaceStore {
    func focusWorkspaceSessionState(
        enabled: Bool? = nil,
        in sessionID: UUID
    ) -> FocusWorkspaceSessionState {
        FocusWorkspaceSessionState(
            enabled: enabled ?? appPreferences.focusWorkspaceEnabled,
            tabs: tabs(for: sessionID)
        )
    }

    var selectedFocusWorkspaceSessionState: FocusWorkspaceSessionState? {
        guard let selectedSessionID else { return nil }
        return focusWorkspaceSessionState(in: selectedSessionID)
    }
}
