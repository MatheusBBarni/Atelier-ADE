# Security Review: another-ade

## Scope

| Field | Value |
| --- | --- |
| Target | `/Users/matheusbbarni/projects/another-ade` |
| Commit | `23620fe` |
| Scan date | 2026-06-01 |
| Mode | Repository-wide Codex Security scan with authorized subagents |
| Primary inputs | `Sources/`, `Package.swift`, `Package.resolved`, `ThirdParty/Ghostty/GhosttyPin.json`, `scripts/run.sh`, `README.md` |
| Exclusions | Generated `.build` artifacts were excluded from primary ranking; SwiftTerm checkout files were inspected only as dependency evidence for `F-002`. |
| Artifacts | `/tmp/codex-security-scans/another-ade/23620fe_20260601T012031Z` |

Three subagent slices reviewed file/persistence/workspace, terminal/native/agent-launch, and UI/restore/dependency surfaces. The parent pass validated two reportable findings and suppressed the other reviewed candidates in the coverage ledger.

External references used: [Claude Code CLI reference](https://code.claude.com/docs/en/cli-reference), [Claude Code permission modes](https://code.claude.com/docs/en/permission-modes), [SwiftTerm GHSA-jq43-q8mx-r7mq](https://github.com/advisories/GHSA-jq43-q8mx-r7mq), and [OSV querybatch API](https://api.osv.dev/v1/querybatch).

## Threat Model

Atelier is a local macOS agentic development environment. The meaningful assets are the user's filesystem contents reachable from selected projects, terminal and agent sessions running with the user's account privileges, persistent SQLite workspace metadata, and privacy-sensitive project/session metadata.

The highest-risk boundaries are project selection, file workspace access, terminal and agent launch, restore from persisted metadata, and terminal emulator parsing. Attacker-controlled or semi-trusted inputs include repository contents, project directory names, symlinks inside a selected project, restored local metadata if another local process can write it, terminal output, and custom profile command text. There is no network service in this repository, so findings require local user interaction unless a source path shows otherwise.

Severity was calibrated accordingly: Critical requires arbitrary code execution or project-boundary file overwrite without meaningful user consent; High includes reliable loss of the agent permission boundary or automatic attacker-influenced command execution through normal project workflows; Medium includes terminal UI/clipboard manipulation, privacy exposure, or weaker local persistence abuse.

## Findings

| ID | Severity | Confidence | Title |
| --- | --- | --- | --- |
| F-001 | High | High | Claude profile silently disables Claude Code permissions |
| F-002 | Medium | Medium-High | Terminal startup banner interprets unsanitized path and command control sequences |

### [1] Claude profile silently disables Claude Code permissions

| Field | Value |
| --- | --- |
| Severity | High |
| Confidence | High |
| Confidence rationale | Direct source trace from shipped profile defaults to process launch; official Claude Code docs confirm the injected flag enables `bypassPermissions`; no UI disclosure or opt-in was found. |
| Category | Agent permission boundary bypass / unsafe default |
| CWE | CWE-693: Protection Mechanism Failure |
| Affected lines | `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift:202-207`; `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift:421-426,515-531`; `Sources/NativeMacADE/AppShell/ConfigModalAgentProfilesSection.swift:585-699` |

#### Summary

The built-in Claude Agent Profile is stored and displayed as `claude` with an empty argument list, but `TerminalSessionDriver.resolvedLaunchArguments(for:)` appends `--dangerously-skip-permissions` to every `claude` launch. A user who starts the built-in or saved Claude profile in an untrusted project gets a Claude Code session with its permission prompts and safety checks bypassed, without an explicit opt-in in Atelier.

#### Validation

`WorkspaceModels.swift:202-207` defines the shipped Claude profile with `launchCommand: "claude"` and `launchArgumentsJSON: "[]"`. `DefaultWorkspaceCommandService.createSession` copies the resolved launch command and arguments into the first terminal tab at `DefaultWorkspaceCommandService.swift:313-377`. At terminal start, `TerminalHostController.swift:515-531` decodes the saved arguments and appends `--dangerously-skip-permissions` whenever the executable basename is `claude`. The resulting command is launched through `startProcess` at `TerminalHostController.swift:421-426`.

The settings UI at `ConfigModalAgentProfilesSection.swift:585-699` only edits the stored command and JSON argument list. It does not show that Atelier will inject a dangerous Claude flag later.

Claude Code documentation states that `--dangerously-skip-permissions` is equivalent to `--permission-mode bypassPermissions`; the permission-mode documentation describes `bypassPermissions` as disabling permission prompts and safety checks and says it should only be used in isolated environments.

#### Dataflow

Source: built-in or saved `SessionShortcut` with `launchCommand == "claude"` and benign-looking `launchArgumentsJSON`.

Propagation: `DefaultWorkspaceCommandService.resolveLaunchIntent` selects the profile, `createSession` stores the launch command and arguments into `WorkspaceTab`, and `TerminalSessionDriver.launchCommandLine()` asks `resolvedLaunchArguments(for:)` for the runtime arguments.

Sink: `TerminalHostController.swift:527-528` silently appends the dangerous flag before `terminalView.startProcess(...)` launches the shell command in the project directory.

#### Reachability

This is reachable through normal use. A victim opens a project and starts the shipped Claude profile, edits a profile whose command resolves to `claude`, or sets Claude as the default and creates a new session. A malicious repository can then influence Claude through project instructions, files, or prompts while the expected Claude Code approval boundary is disabled.

#### Severity

High. The issue removes the primary user-consent boundary for an agent session running under the user's macOS account in a selected project. That can permit file edits and command execution without the prompts Claude Code normally uses to mediate risky actions. It is not Critical because exploitation still requires user interaction to open the project and start or restore a Claude profile.

#### Remediation

Remove the automatic `--dangerously-skip-permissions` append. If Atelier wants a bypass mode, make it an explicit per-profile opt-in that is stored in `launchArgumentsJSON`, visibly shown in the UI, gated by a warning, and disabled by default for shipped profiles. Add tests that prove the built-in Claude profile launches without bypass flags unless the user explicitly persisted that argument.

### [2] Terminal startup banner interprets unsanitized path and command control sequences

| Field | Value |
| --- | --- |
| Severity | Medium |
| Confidence | Medium-High |
| Confidence rationale | Direct source trace from banner construction to SwiftTerm parser and clipboard delegate; impact is local UI/clipboard manipulation rather than proven arbitrary code execution. |
| Category | Terminal escape injection / clipboard injection |
| CWE | CWE-150: Improper Neutralization of Escape, Meta, or Control Sequences |
| Affected lines | `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift:419,463-466`; dependency evidence in `.build/checkouts/SwiftTerm/Sources/SwiftTerm/*` |

#### Summary

At terminal startup, Atelier builds a banner from the project working directory and resolved command description, then feeds that raw string into SwiftTerm as terminal input before the shell starts. A project directory name or command text containing terminal control sequences can be interpreted by SwiftTerm, including OSC 52 clipboard writes.

#### Validation

`TerminalHostController.swift:419` calls `terminalView.feed(text: launchBanner())`. `launchBanner()` at `TerminalHostController.swift:463-466` interpolates `tab.workingDirectory` and `resolvedCommandDescription()` directly into the string. There is no escaping or filtering of C0, ESC, CSI, OSC, or other terminal control bytes.

SwiftTerm's `feed(text:)` path forwards text to the emulator for interpretation. In the checked-out SwiftTerm dependency, `Terminal.feed(text:)` parses the UTF-8 bytes, `EscapeSequenceParser` dispatches OSC 52 to `Terminal.oscClipboard`, and `MacLocalTerminalView.clipboardCopy` writes decoded content to `NSPasteboard.general`.

#### Dataflow

Source: project path selected or restored as `tab.workingDirectory`, plus profile command/arguments used in `resolvedCommandDescription()`.

Propagation: `launchBanner()` embeds the source values directly in a user-visible banner string.

Sink: `terminalView.feed(text:)` sends the banner to SwiftTerm's terminal parser, where terminal escape sequences are active.

#### Reachability

The path source is reachable through normal project-opening workflows. For example, a malicious archive or cloned project can have a folder name containing terminal control bytes. When the victim opens that folder and starts a terminal tab, the banner is parsed before the shell starts. Custom profile command text is more user-controlled, but it confirms the same missing escaping pattern.

#### Severity

Medium. A practical attack can overwrite the clipboard or spoof terminal UI text without needing the shell process to emit anything. The current evidence does not prove arbitrary command execution in SwiftTerm `1.13.0`, and the known SwiftTerm CVE for command injection affects versions `< 1.2.0`, while this project pins `1.13.0`.

#### Remediation

Do not feed unsanitized app-generated labels into the terminal emulator. Either render the startup banner outside SwiftTerm, or sanitize all dynamic banner fields by stripping or visibly escaping control characters before calling `feed(text:)`. Add a regression test with ESC, CSI, and OSC 52 bytes in `workingDirectory` and profile command strings to prove the emitted banner cannot affect terminal state or the clipboard.

## Reviewed Surfaces And Suppressions

| Surface | Result |
| --- | --- |
| File workspace traversal | Suppressed: `LocalWorkspaceFileAccess` standardizes absolute paths, resolves symlinks, checks containment, and revalidates before load/save. |
| SQLite injection | Suppressed: persistence operations use prepared statements and typed bind helpers. |
| Restore file-tab breakout | Suppressed: restore validates owning project/session, matching roots, containment, and readability. |
| Shell metacharacter injection | Suppressed: `TerminalLaunchCommandBuilder` shell-escapes arguments and unsafe command words. |
| Dependency advisories | Suppressed: OSV returned no advisories for checked pins; SwiftTerm GHSA-jq43-q8mx-r7mq affects `< 1.2.0`, while this repo pins `1.13.0`. |
| Ghostty upstream runtime | Deferred: repo contains a pin and local shim only; no repo-owned issue was proven. |

## Verification

- Reviewed 35 repo-owned ranked source/build files from `deep_review_input.csv`, plus `Package.resolved`.
- Validated report structure with `validate_report_format.py`.
- Rendered HTML artifact with `render_report_html.py`.
- Ran a focused terminal-host integration test during the terminal slice: `swift test --filter NativeMacADEIntegrationTests.TerminalHostIntegrationTests/shellLaunchCommandRunsAliasFromInteractiveZshProfileAndPreservesQuotedArguments`.

