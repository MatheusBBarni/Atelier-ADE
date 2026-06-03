# Task Memory: task_02.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Route `LiveGhosttyAdapter` through `GhosttyKit.GhosttySurfaceRuntime`, expose native view access on the adapter boundary, and stop forcing the live adapter onto the embedded SwiftTerm driver branch while keeping existing host tests compatible until Task 04.

## Important Decisions
- Kept `TerminalHostController`'s embedded `TerminalSessionDriver` branch intact for Task 04 compatibility, but made only test adapters opt into it; `LiveGhosttyAdapter` now reports `usesEmbeddedSessionDriver == false`.
- Added `GhosttyAdapter.nativeView(for:)` as the core boundary hook and delegated the live implementation to `GhosttySurfaceRuntime.nativeView(for:)`.

## Learnings
- Pre-change signal: `swift test --filter ScaffoldIntegrationTests/terminalHostCreatesSingleEmbeddedSurfaceWithoutRequiringGhosttyRuntime` passed and asserted default host creation still returns a zero raw Ghostty handle, proving the current live path bypasses wrapper-backed surface creation.
- Focused task verification passed with `swift test --filter 'GhosttyAdapterTests|ScaffoldIntegrationTests|TerminalHostIntegrationTests|DefaultWorkspaceCommandServiceIntegrationTests'` after adapter and test updates.
- Final verification passed with `swift test --enable-code-coverage`; output reported 397 tests across 37 suites. Scoped first-party Ghostty runtime coverage was 97.38% line coverage across `Sources/GhosttyKit` and `Sources/NativeMacADECore/Ghostty`.

## Files / Surfaces
- Planned surfaces: `Sources/NativeMacADECore/Ghostty/GhosttyAdapter.swift`, adapter/host/scaffold tests, and task tracking files after verification.
- Implementation surfaces touched so far: `GhosttyAdapter.swift`, `GhosttyAdapterTests.swift`, `TerminalHostIntegrationTests.swift`, and `ScaffoldIntegrationTests.swift`.

## Errors / Corrections

## Ready for Next Run
- Task 04 should replace the host placeholder path with `GhosttyAdapter.nativeView(for:)` attachment and remove the remaining production need for `TerminalSessionDriver`.
