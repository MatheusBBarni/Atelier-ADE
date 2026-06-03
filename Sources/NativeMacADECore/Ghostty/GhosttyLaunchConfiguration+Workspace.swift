import Foundation
import GhosttyKit

public extension GhosttyLaunchConfiguration {
    init(tab: WorkspaceTab, appearance: TerminalAppearance = .cursorDefault) {
        self.init(
            workingDirectory: tab.workingDirectory,
            command: tab.launchCommand,
            arguments: Self.decodeArguments(from: tab.launchArgumentsJSON),
            appearance: appearance
        )
    }
}

public extension GhosttyAdapterError {
    var workspaceCommandError: WorkspaceCommandError {
        .terminalUnavailable(userVisibleMessage)
    }
}
