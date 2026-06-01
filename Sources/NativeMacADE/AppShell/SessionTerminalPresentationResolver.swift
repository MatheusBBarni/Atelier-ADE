import Foundation
import NativeMacADECore

struct SessionTerminalPresentation: Equatable {
    let title: String
    let fallbackTitle: String
    let agentLabel: String
    let shortcutID: UUID?
    let iconInput: SessionTerminalIconInput

    var iconShortcut: SessionShortcut? {
        iconInput.shortcut
    }

    func fallbackSystemImage(isActive: Bool) -> String? {
        iconInput.fallbackSystemImage(isActive: isActive)
    }
}

enum SessionTerminalIconInput: Equatable {
    case shortcut(SessionShortcut)
    case launchCommand(command: String, label: String)
    case terminal

    var shortcut: SessionShortcut? {
        switch self {
        case .shortcut(let shortcut):
            return shortcut
        case .launchCommand(let command, let label):
            return SessionShortcut(label: label, launchCommand: command)
        case .terminal:
            return nil
        }
    }

    func fallbackSystemImage(isActive: Bool) -> String? {
        switch self {
        case .shortcut, .launchCommand:
            return nil
        case .terminal:
            return isActive ? "terminal.fill" : "terminal"
        }
    }
}

struct SessionTerminalPresentationResolver {
    private let shortcutLookup: [UUID: SessionShortcut]

    init(shortcuts: [SessionShortcut] = SessionShortcut.builtInDefaults) {
        var lookup = Dictionary(uniqueKeysWithValues: SessionShortcut.builtInDefaults.map { ($0.id, $0) })
        for shortcut in shortcuts {
            lookup[shortcut.id] = shortcut
        }
        shortcutLookup = lookup
    }

    func resolve(tab: WorkspaceTab, legacySessionShortcutID: UUID? = nil) -> SessionTerminalPresentation? {
        guard tab.kind == .terminal else {
            return nil
        }

        let shortcut = resolvedShortcut(for: tab, legacySessionShortcutID: legacySessionShortcutID)
        let commandFallback = commandPresentation(for: tab.launchCommand)
        let fallbackLabel = shortcut?.label.nonEmptyTrimmed
            ?? commandFallback?.label
            ?? "Terminal"
        let customTitle = tab.title?.nonEmptyTrimmed
        let iconInput: SessionTerminalIconInput

        if let shortcut {
            iconInput = .shortcut(shortcut)
        } else if let commandFallback {
            iconInput = .launchCommand(command: commandFallback.command, label: commandFallback.label)
        } else {
            iconInput = .terminal
        }

        return SessionTerminalPresentation(
            title: customTitle ?? fallbackLabel,
            fallbackTitle: fallbackLabel,
            agentLabel: fallbackLabel,
            shortcutID: shortcut?.id,
            iconInput: iconInput
        )
    }

    private func resolvedShortcut(for tab: WorkspaceTab, legacySessionShortcutID: UUID?) -> SessionShortcut? {
        if let shortcutID = tab.shortcutID,
           let shortcut = shortcutLookup[shortcutID] {
            return shortcut
        }

        guard tab.shortcutID == nil,
              tab.launchCommand?.nonEmptyTrimmed != nil,
              let legacySessionShortcutID
        else {
            return nil
        }

        return shortcutLookup[legacySessionShortcutID]
    }

    private func commandPresentation(for launchCommand: String?) -> (command: String, label: String)? {
        guard let command = launchCommand?.nonEmptyTrimmed else {
            return nil
        }

        let executableName = URL(fileURLWithPath: command).lastPathComponent.lowercased()
        let label: String
        switch executableName {
        case "codex":
            label = "Codex"
        case "claude":
            label = "Claude"
        case "opencode":
            label = "OpenCode"
        default:
            label = executableName
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }

        return (command, label)
    }
}

private extension String {
    var nonEmptyTrimmed: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
