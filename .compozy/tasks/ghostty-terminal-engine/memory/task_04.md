# Task Memory: task_04.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Replace the remaining SwiftTerm-backed `TerminalHostController` runtime branch with Ghostty adapter/native view hosting while keeping `WorkspaceTerminalSurfaceManaging` unchanged.

## Important Decisions
- Treat a missing Ghostty native view after surface creation as a surface creation failure; do not silently host a placeholder for terminal tabs.
- Keep `GhosttyAdapter.usesEmbeddedSessionDriver` untouched for now because other task-02 scaffold coverage still asserts the live adapter reports `false`; remove only the `TerminalHostController` production branch in this task.

## Learnings
- `AGENTS.md` and `CLAUDE.md` are not present under `/Users/matheusbbarni/projects/another-ade`; PRD, TechSpec, ADRs, task files, and workflow memory are the available task guidance.
- Pre-change signal: `TerminalHostController.swift` still imports SwiftTerm, stores `sessionDriversByTabID`, branches on `adapter.usesEmbeddedSessionDriver`, exposes `localProcessTerminalView`, and defines `TerminalSessionDriver`.
- Implementation result: `TerminalHostController` now creates only Ghostty adapter surfaces, caches the adapter native view per tab, attaches that view into `TerminalSurfaceHostNSView`, and destroys the surface if native view lookup fails.
- Verification evidence: `swift test --enable-code-coverage` passed 410 tests across 39 suites; `xcrun llvm-cov report` shows `TerminalHostController.swift` at 90.11% region coverage and 96.84% line coverage.

## Files / Surfaces
- Touched: `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift`
- Touched: `Tests/NativeMacADECoreTests/TerminalHostControllerTests.swift`
- Touched: `Tests/NativeMacADEIntegrationTests/TerminalHostIntegrationTests.swift`
- Touched: `.compozy/tasks/ghostty-terminal-engine/task_04.md` and `_tasks.md` for completion tracking after verification.

## Errors / Corrections
- Corrected stale shared workflow memory that still described the task-04 host SwiftTerm branch as present.

## Ready for Next Run
- If continuing to task 05, start from the Ghostty-only host path and verify workspace lifecycle/restore/exit telemetry without relying on SwiftTerm fallback behavior.
