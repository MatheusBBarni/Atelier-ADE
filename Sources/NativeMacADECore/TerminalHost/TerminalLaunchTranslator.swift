import Darwin
import Foundation
import GhosttyKit

public struct TerminalLaunchTranslation: Equatable, Sendable {
    public var workingDirectory: String
    public var command: String?
    public var arguments: [String]
    public var environmentOverrides: [String: String]
    public var processEnvironment: [String: String]
    public var shellExecutable: String
    public var shellArguments: [String]
    public var loginExecName: String
    public var commandLine: String?
    public var commandDescription: String

    public var nativeGhosttyCommand: String {
        ([shellExecutable] + shellArguments)
            .map(TerminalLaunchCommandBuilder.shellEscape)
            .joined(separator: " ")
    }

    public var processEnvironmentEntries: [String] {
        processEnvironment
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
    }

    public func ghosttyLaunchConfiguration(appearance: TerminalAppearance = .cursorDefault) -> GhosttyLaunchConfiguration {
        GhosttyLaunchConfiguration(
            workingDirectory: workingDirectory,
            command: command,
            arguments: arguments,
            nativeCommand: nativeGhosttyCommand,
            environment: processEnvironment,
            appearance: appearance
        )
    }
}

public struct TerminalLaunchTranslator: Equatable, Sendable {
    public var tab: WorkspaceTab
    public var inheritedEnvironment: [String: String]
    public var preferredShellPathOverride: String?

    public init(
        tab: WorkspaceTab,
        inheritedEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        preferredShellPath: String? = nil
    ) {
        self.tab = tab
        self.inheritedEnvironment = inheritedEnvironment
        self.preferredShellPathOverride = preferredShellPath
    }

    public func translate() -> TerminalLaunchTranslation {
        let shellExecutable = preferredShellPathOverride ?? Self.preferredShellPath(inheritedEnvironment: inheritedEnvironment)
        let command = normalizedCommand(tab.launchCommand)
        let arguments = resolvedLaunchArguments(command: command)
        let environmentOverrides = launchEnvironmentOverrides(command: command)
        let commandLine = command.map {
            TerminalLaunchCommandBuilder(
                command: $0,
                arguments: arguments,
                environment: environmentOverrides
            ).commandLine()
        }

        return TerminalLaunchTranslation(
            workingDirectory: tab.workingDirectory,
            command: command,
            arguments: arguments,
            environmentOverrides: environmentOverrides,
            processEnvironment: processEnvironment(
                shellExecutable: shellExecutable,
                overrides: environmentOverrides
            ),
            shellExecutable: shellExecutable,
            shellArguments: commandLine.map { ["-ilc", $0] } ?? ["-il"],
            loginExecName: "-\(URL(fileURLWithPath: shellExecutable).lastPathComponent)",
            commandLine: commandLine,
            commandDescription: commandDescription(
                shellExecutable: shellExecutable,
                command: command,
                arguments: arguments
            )
        )
    }

    private func normalizedCommand(_ command: String?) -> String? {
        guard let command = command?.trimmingCharacters(in: .whitespacesAndNewlines), !command.isEmpty else {
            return nil
        }
        return command
    }

    private func resolvedLaunchArguments(command: String?) -> [String] {
        guard let command else { return [] }

        var arguments = GhosttyLaunchConfiguration.decodeArguments(from: tab.launchArgumentsJSON)
        let executableName = Self.executableName(command)

        if executableName == "codex", !arguments.contains("--no-alt-screen") {
            arguments.append("--no-alt-screen")
        }

        if executableName == "codex", !arguments.contains("-c") {
            arguments.append(contentsOf: ["-c", "tui.raw_output_mode=true"])
        }

        if executableName == "claude", !arguments.contains("--dangerously-skip-permissions") {
            arguments.append("--dangerously-skip-permissions")
        }

        return arguments
    }

    private func launchEnvironmentOverrides(command: String?) -> [String: String] {
        guard let command else { return [:] }

        let executableName = Self.executableName(command)
        var environment: [String: String] = [:]

        if executableName == "codex" {
            environment["CODEX_TUI_DISABLE_KEYBOARD_ENHANCEMENT"] = "1"
        }

        if executableName == "claude" {
            environment["CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN"] = "1"
            environment["CLAUDE_CODE_DISABLE_MOUSE"] = "1"
            environment["CLAUDE_CODE_ACCESSIBILITY"] = "1"
            environment["CLAUDE_CODE_DISABLE_TERMINAL_TITLE"] = "1"
            environment["CLAUDE_CODE_SYNTAX_HIGHLIGHT"] = "false"
        }

        return environment
    }

    private func processEnvironment(
        shellExecutable: String,
        overrides: [String: String]
    ) -> [String: String] {
        var environment = inheritedEnvironment
        environment["SHELL"] = shellExecutable
        environment["TERM"] = environment["TERM"] ?? "xterm-256color"
        environment["COLORTERM"] = environment["COLORTERM"] ?? "truecolor"
        for (key, value) in overrides {
            environment[key] = value
        }
        return environment
    }

    private func commandDescription(
        shellExecutable: String,
        command: String?,
        arguments: [String]
    ) -> String {
        guard let command else {
            return URL(fileURLWithPath: shellExecutable).lastPathComponent
        }

        return ([command] + arguments).joined(separator: " ")
    }

    private static func executableName(_ command: String) -> String {
        URL(fileURLWithPath: command).lastPathComponent.lowercased()
    }

    private static func preferredShellPath(inheritedEnvironment: [String: String]) -> String {
        let candidates = [
            userLoginShellPath(),
            inheritedEnvironment["SHELL"],
            "/bin/zsh"
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for candidate in candidates {
            let path = URL(fileURLWithPath: candidate).standardizedFileURL.path
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return "/bin/zsh"
    }

    private static func userLoginShellPath() -> String? {
        guard let passwd = getpwuid(getuid()) else { return nil }
        let shell = String(cString: passwd.pointee.pw_shell)
        return shell.isEmpty ? nil : shell
    }
}

public struct TerminalLaunchCommandBuilder: Equatable, Sendable {
    public var command: String
    public var arguments: [String]
    public var environment: [String: String]

    public init(command: String, arguments: [String], environment: [String: String]) {
        self.command = command
        self.arguments = arguments
        self.environment = environment
    }

    public func commandLine() -> String {
        let environmentTokens = environment
            .sorted { $0.key < $1.key }
            .map { key, value in
                "\(key)=\(Self.shellEscape(value))"
            }
        let invocation = (environmentTokens + [Self.commandToken(command)] + arguments.map(Self.shellEscape))
            .joined(separator: " ")

        return "\(invocation); __ade_launch_status=$?; exit $__ade_launch_status"
    }

    public static func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    private static func commandToken(_ value: String) -> String {
        guard isSafeUnquotedCommandWord(value) else {
            return shellEscape(value)
        }

        return value
    }

    private static func isSafeUnquotedCommandWord(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }

        let allowedScalars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_+-./:@")
        return value.unicodeScalars.allSatisfy { allowedScalars.contains($0) }
    }
}
