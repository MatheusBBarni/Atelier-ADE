# Task Memory: task_02.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement Task 02 by adding an ephemeral in-memory terminal-exit observer source near `AppDependencyContainer`, fan out `TerminalHostController.onSurfaceExited`, and preserve `DefaultWorkspaceCommandService.recordTerminalProcessExit(tabID:exitStatus:)` logging/metrics behavior.

## Important Decisions
- Keep exit observations out of `WorkspaceStore` and persistence; missing snapshots remain neutral and do not imply a running terminal.
- `TerminalExitEventSource` stores `TerminalExitObservation` values instead of `[UUID: Int32?]` so an observed `nil` exit status remains distinguishable from an unseen tab.
- `AppDependencyContainer.live()` keeps the command-service logging call in the `TerminalHostController.onSurfaceExited` callback and publishes the same event to the observer after recording the existing log/metric path.

## Learnings
- Repository-local `AGENTS.md` and `CLAUDE.md` are not present in `/Users/matheusbbarni/projects/another-ade`; neighboring-repo guidance files are ignored.
- `AtelierApp` does not retain the whole `AppDependencyContainer`; the live terminal-exit callback must retain `terminalExitEvents` strongly or the observer can be deallocated in the real app.
- Verification after final source changes: `swift test --enable-code-coverage` passed 313 tests in 28 suites; `swift build` passed; NativeMacADECore coverage was 83.08% regions and 89.92% lines, and `TerminalExitEventSource.swift` was 100% lines/regions.

## Files / Surfaces
- `Sources/NativeMacADECore/App/TerminalExitEventSource.swift`
- `Sources/NativeMacADECore/App/AppDependencyContainer.swift`
- `Tests/NativeMacADECoreTests/TerminalExitEventSourceTests.swift`
- `Tests/NativeMacADEIntegrationTests/ScaffoldIntegrationTests.swift`

## Errors / Corrections
- The Compozy skill path listed under the runtime cache was missing on disk; used the installed `.agents/skills` copies for `cy-workflow-memory`, `cy-execute-task`, and `cy-final-verify`.
- Self-review caught that weakly capturing `terminalExitEvents` in the live callback would not survive app startup because only selected dependencies are retained by `AtelierApp`; corrected to retain the source through the callback while keeping the command service weak.

## Ready for Next Run
- Task 02 code/test changes were committed locally as `59620ab` (`feat: add terminal exit event source`); task tracking and memory files remain unstaged per workflow rules.
