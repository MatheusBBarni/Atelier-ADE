import Dispatch
import Foundation
import Testing
@testable import NativeMacADECore

@Suite(.serialized)
struct TerminalLaunchTranslatorTests {
    @Test
    func plainShellTabProducesLoginShellPayloadWithSelectedWorkingDirectory() {
        let tab = WorkspaceTab(
            sessionID: UUID(),
            workingDirectory: "/tmp/native-mac-ade-plain",
            ordinal: 0
        )

        let translation = TerminalLaunchTranslator(
            tab: tab,
            inheritedEnvironment: [:],
            preferredShellPath: "/bin/zsh"
        ).translate()

        #expect(translation.workingDirectory == "/tmp/native-mac-ade-plain")
        #expect(translation.command == nil)
        #expect(translation.arguments == [])
        #expect(translation.environmentOverrides == [:])
        #expect(translation.shellExecutable == "/bin/zsh")
        #expect(translation.shellArguments == ["-il"])
        #expect(translation.loginExecName == "-zsh")
        #expect(translation.commandLine == nil)
        #expect(translation.commandDescription == "zsh")
        #expect(translation.processEnvironment["SHELL"] == "/bin/zsh")
        #expect(translation.processEnvironment["TERM"] == "xterm-256color")
        #expect(translation.processEnvironment["COLORTERM"] == "truecolor")

        let configuration = translation.ghosttyLaunchConfiguration()
        #expect(configuration.workingDirectory == tab.workingDirectory)
        #expect(configuration.command == nil)
        #expect(configuration.arguments == [])
        #expect(configuration.nativeCommand == "'/bin/zsh' '-il'")
        #expect(configuration.environment["SHELL"] == "/bin/zsh")
    }

    @Test
    func codexLaunchTranslationPreservesStoredArgumentsAndAddsCurrentRuntimeFlags() {
        let tab = WorkspaceTab(
            sessionID: UUID(),
            workingDirectory: "/tmp/native-mac-ade-codex",
            launchCommand: "codex",
            launchArgumentsJSON: "[\"resume\",\"--model\",\"gpt-5.5\"]",
            ordinal: 0
        )

        let translation = TerminalLaunchTranslator(
            tab: tab,
            inheritedEnvironment: ["TERM": "screen-256color"],
            preferredShellPath: "/bin/zsh"
        ).translate()

        #expect(translation.command == "codex")
        #expect(translation.arguments == [
            "resume",
            "--model",
            "gpt-5.5",
            "--no-alt-screen",
            "-c",
            "tui.raw_output_mode=true"
        ])
        #expect(translation.environmentOverrides == [
            "CODEX_TUI_DISABLE_KEYBOARD_ENHANCEMENT": "1"
        ])
        #expect(translation.processEnvironment["TERM"] == "screen-256color")
        #expect(translation.processEnvironment["COLORTERM"] == "truecolor")
        #expect(translation.processEnvironment["CODEX_TUI_DISABLE_KEYBOARD_ENHANCEMENT"] == "1")
        #expect(translation.shellArguments.count == 2)
        #expect(translation.shellArguments.first == "-ilc")
        #expect(translation.commandLine?.contains("codex 'resume' '--model' 'gpt-5.5' '--no-alt-screen' '-c' 'tui.raw_output_mode=true'") == true)

        let configuration = translation.ghosttyLaunchConfiguration()
        #expect(configuration.command == "codex")
        #expect(configuration.arguments == translation.arguments)
        #expect(configuration.nativeCommand?.hasPrefix("'/bin/zsh' '-ilc' ") == true)
        #expect(configuration.nativeCommand?.contains("codex '\"'\"'resume'\"'\"'") == true)
        #expect(configuration.nativeCommand?.contains("CODEX_TUI_DISABLE_KEYBOARD_ENHANCEMENT='\"'\"'1'\"'\"'") == true)
        #expect(configuration.environment["CODEX_TUI_DISABLE_KEYBOARD_ENHANCEMENT"] == "1")
    }

    @Test
    func codexLaunchTranslationDoesNotDuplicateExistingRuntimeFlags() {
        let tab = WorkspaceTab(
            sessionID: UUID(),
            workingDirectory: "/tmp/native-mac-ade-codex-existing",
            launchCommand: "/opt/homebrew/bin/codex",
            launchArgumentsJSON: "[\"--no-alt-screen\",\"-c\",\"custom=true\"]",
            ordinal: 0
        )

        let translation = TerminalLaunchTranslator(
            tab: tab,
            inheritedEnvironment: [:],
            preferredShellPath: "/bin/zsh"
        ).translate()

        #expect(translation.arguments == ["--no-alt-screen", "-c", "custom=true"])
        #expect(translation.arguments.filter { $0 == "--no-alt-screen" }.count == 1)
        #expect(translation.arguments.filter { $0 == "-c" }.count == 1)
    }

    @Test
    func claudeLaunchTranslationPreservesStoredArgumentsAndAddsCurrentRuntimeFlags() {
        let tab = WorkspaceTab(
            sessionID: UUID(),
            workingDirectory: "/tmp/native-mac-ade-claude",
            launchCommand: "claude",
            launchArgumentsJSON: "[\"--continue\"]",
            ordinal: 0
        )

        let translation = TerminalLaunchTranslator(
            tab: tab,
            inheritedEnvironment: ["COLORTERM": "24bit"],
            preferredShellPath: "/bin/zsh"
        ).translate()

        #expect(translation.command == "claude")
        #expect(translation.arguments == ["--continue", "--dangerously-skip-permissions"])
        #expect(translation.environmentOverrides == [
            "CLAUDE_CODE_ACCESSIBILITY": "1",
            "CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN": "1",
            "CLAUDE_CODE_DISABLE_MOUSE": "1",
            "CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1",
            "CLAUDE_CODE_SYNTAX_HIGHLIGHT": "false"
        ])
        #expect(translation.processEnvironment["COLORTERM"] == "24bit")
        #expect(translation.processEnvironment["CLAUDE_CODE_DISABLE_MOUSE"] == "1")

        let configuration = translation.ghosttyLaunchConfiguration()
        #expect(configuration.command == "claude")
        #expect(configuration.arguments == ["--continue", "--dangerously-skip-permissions"])
        #expect(configuration.environment["CLAUDE_CODE_ACCESSIBILITY"] == "1")
    }

    @Test
    func invalidOrEmptyLaunchArgumentJSONDecodesToEmptyArgumentList() {
        let invalidInputs = ["", "not-json", "{\"value\":true}"]

        for input in invalidInputs {
            let tab = WorkspaceTab(
                sessionID: UUID(),
                workingDirectory: "/tmp/native-mac-ade-invalid-json",
                launchCommand: "local-tool",
                launchArgumentsJSON: input,
                ordinal: 0
            )

            let translation = TerminalLaunchTranslator(
                tab: tab,
                inheritedEnvironment: [:],
                preferredShellPath: "/bin/zsh"
            ).translate()

            #expect(translation.arguments == [])
        }
    }

    @Test
    func shellLaunchCommandRunsAliasFromInteractiveZshProfileAndPreservesQuotedArguments() throws {
        let workingDirectory = try makeTemporaryDirectory()
        let zdotdir = try makeTemporaryDirectory()
        let markerPath = URL(fileURLWithPath: workingDirectory, isDirectory: true)
            .appendingPathComponent("profile-command-output.txt")
            .path
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "_")
        let functionName = "ade_profile_function_\(suffix)"
        let aliasName = "ade_profile_alias_\(suffix)"
        try """
        function \(functionName)() {
            [[ "$1" == "two words" ]] || return 41
            [[ "$2" == "quote'arg" ]] || return 42
            [[ "$3" == '$HOME' ]] || return 43
            [[ "$ADE_PROFILE_BUILDER_FLAG" == "builder value" ]] || return 44
            print -r -- "$1|$2|$3" > "$ADE_PROFILE_MARKER"
            return 0
        }
        alias \(aliasName)=\(functionName)
        """.write(
            to: URL(fileURLWithPath: zdotdir, isDirectory: true).appendingPathComponent(".zshrc"),
            atomically: true,
            encoding: .utf8
        )
        let arguments = ["two words", "quote'arg", "$HOME"]
        let environment = [
            "ZDOTDIR": zdotdir,
            "ADE_PROFILE_MARKER": markerPath
        ]
        let oldStyleCommandLine = (["exec", TerminalLaunchCommandBuilder.shellEscape(aliasName)] + arguments.map(TerminalLaunchCommandBuilder.shellEscape))
            .joined(separator: " ")

        let oldStyleRun = try runZshLaunchCommandLine(oldStyleCommandLine, workingDirectory: workingDirectory, environment: environment)
        #expect(oldStyleRun.terminationStatus != 0)
        #expect(FileManager.default.fileExists(atPath: markerPath) == false)

        let commandLine = TerminalLaunchCommandBuilder(
            command: aliasName,
            arguments: arguments,
            environment: ["ADE_PROFILE_BUILDER_FLAG": "builder value"]
        ).commandLine()
        let run = try runZshLaunchCommandLine(commandLine, workingDirectory: workingDirectory, environment: environment)

        #expect(run.terminationStatus == 0)
        let markerContents = try String(contentsOfFile: markerPath, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(markerContents == "two words|quote'arg|$HOME")
    }

    @Test
    func shellLaunchCommandExitsWithFunctionStatus() throws {
        let workingDirectory = try makeTemporaryDirectory()
        let zdotdir = try makeTemporaryDirectory()
        let functionName = "ade_status_function_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        try """
        function \(functionName)() {
            return 37
        }
        """.write(
            to: URL(fileURLWithPath: zdotdir, isDirectory: true).appendingPathComponent(".zshrc"),
            atomically: true,
            encoding: .utf8
        )
        let commandLine = TerminalLaunchCommandBuilder(command: functionName, arguments: [], environment: [:]).commandLine()

        let run = try runZshLaunchCommandLine(commandLine, workingDirectory: workingDirectory, environment: ["ZDOTDIR": zdotdir])

        #expect(run.terminationStatus == 37)
    }
}

private func makeTemporaryDirectory() throws -> String {
    let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("native-mac-ade-launch-translation-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url.path
}

private struct ZshRunResult {
    let terminationStatus: Int32
    let standardOutput: String
    let standardError: String
}

private func runZshLaunchCommandLine(
    _ commandLine: String,
    workingDirectory: String,
    environment overrides: [String: String]
) throws -> ZshRunResult {
    let zshPath = "/bin/zsh"
    guard FileManager.default.isExecutableFile(atPath: zshPath) else {
        throw ZshRunError.zshUnavailable(zshPath)
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: zshPath)
    process.arguments = ["-ilc", commandLine]
    process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
    var processEnvironment = ProcessInfo.processInfo.environment
    for (key, value) in overrides {
        processEnvironment[key] = value
    }
    process.environment = processEnvironment

    let standardOutput = Pipe()
    let standardError = Pipe()
    process.standardOutput = standardOutput
    process.standardError = standardError

    let finished = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in finished.signal() }

    try process.run()
    guard finished.wait(timeout: .now() + .seconds(5)) == .success else {
        process.terminate()
        _ = finished.wait(timeout: .now() + .seconds(1))
        throw ZshRunError.timedOut(commandLine)
    }

    let output = String(data: standardOutput.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let error = String(data: standardError.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return ZshRunResult(
        terminationStatus: process.terminationStatus,
        standardOutput: output,
        standardError: error
    )
}

private enum ZshRunError: Error, CustomStringConvertible {
    case zshUnavailable(String)
    case timedOut(String)

    var description: String {
        switch self {
        case .zshUnavailable(let path):
            return "zsh is unavailable at \(path)"
        case .timedOut(let commandLine):
            return "zsh launch command timed out: \(commandLine)"
        }
    }
}
