import Foundation
import GhosttyKit

public extension GhosttyLaunchConfiguration {
    init(tab: WorkspaceTab, appearance: TerminalAppearance = .cursorDefault) {
        self = TerminalLaunchTranslator(tab: tab)
            .translate()
            .ghosttyLaunchConfiguration(appearance: appearance)
    }
}

public extension GhosttyAdapterError {
    var workspaceCommandError: WorkspaceCommandError {
        .terminalUnavailable(userVisibleMessage)
    }
}
