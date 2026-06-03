# Task Memory: task_03.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Extract terminal launch metadata translation out of `TerminalSessionDriver` while preserving plain shell, stored command/argument JSON, Codex, Claude, environment override, and shell escaping behavior.

## Important Decisions
- Keep persisted `WorkspaceTab` fields unchanged. Feed later Ghostty hosting by deriving `GhosttyLaunchConfiguration(tab:)` from the same SwiftTerm-independent launch translation used by the compatibility driver.
- Add runtime-only environment data to `GhosttyLaunchConfiguration`; this does not change workspace persistence and lets later Ghostty hosting consume the same translated process environment as the SwiftTerm compatibility path.

## Learnings
- Repo-local `AGENTS.md` and `CLAUDE.md` are absent under `/Users/matheusbbarni/projects/another-ade`; only sibling-repo guidance files were found.
- Current launch behavior is embedded in `TerminalSessionDriver`: preferred shell resolution, `-il`/`-ilc` shell args, process environment defaults, agent-specific environment overrides, stored JSON argument decoding, agent argument additions, launch banner command description, and shell escaping via `TerminalLaunchCommandBuilder`.
- Targeted verification passed for the extracted seam: `swift test --filter TerminalLaunchTranslatorTests` ran 7 tests, including zsh alias/function shell escaping/status checks, and `swift test --filter 'GhosttyAdapterTests|DefaultWorkspaceCommandServiceTests|DefaultWorkspaceCommandServiceIntegrationTests|GhosttySurfaceRuntimeTests'` ran 172 tests.
- Final verification passed with `swift test --enable-code-coverage`: 404 tests in 38 suites. Changed launch surfaces exceeded the 80% task target: `TerminalLaunchTranslator.swift` 97.95% line coverage, `GhosttyLaunchConfiguration+Workspace.swift` 100%, `TerminalHostController.swift` 84.49%, and `GhosttyTypes.swift` 100%. Repo-wide coverage from the same report is 35.27%, so the task target was treated as changed launch-translation coverage.

## Files / Surfaces
- Planned: `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift`, `Sources/NativeMacADECore/Ghostty/GhosttyLaunchConfiguration+Workspace.swift`, new launch translation source, and focused launch translation tests.
- Touched: `Sources/NativeMacADECore/TerminalHost/TerminalLaunchTranslator.swift`, `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift`, `Sources/NativeMacADECore/Ghostty/GhosttyLaunchConfiguration+Workspace.swift`, `Sources/GhosttyKit/GhosttyTypes.swift`, launch/adapter/runtime tests, and command-service integration tests.

## Errors / Corrections

## Ready for Next Run
- Task 04 should use `GhosttyLaunchConfiguration(tab:)` or `TerminalLaunchTranslator` rather than reading raw `WorkspaceTab.launchCommand` / `launchArgumentsJSON` directly, because agent runtime arguments and environment are now applied there.
