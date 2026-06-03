# Task Memory: task_04.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Wire the existing pure continuity selector into `DefaultWorkspaceCommandService.restoreWorkspace()` after coordinator metadata restore and before live `WorkspaceStore.restore(...)` / surface recreation.
- Preserve disabled and fallback restore behavior, keep `RestoreCoordinator` generic, and add restore observability for applied/disabled/fallback outcomes.

## Important Decisions
- No restore-result seam is needed so far: `RestoreCoordinator.restoreWorkspace()` already returns a normalized `WorkspaceStore` with the restored selection, sessions, and tabs needed by `FocusWorkspaceContinuityRestoreSelector`.
- The command service aligns the returned `RestoreWorkspaceResult.store.selection` with the final live restore selection, but does not write that continuity target back to `RestoreSnapshot`.
- Restore observability uses `FocusWorkspaceContinuityRestoreResolution` values: `applied`, `disabled`, `fallback_snapshot`, and `no_terminal_candidate`.

## Learnings
- Pre-change signal: `FocusWorkspaceContinuityRestoreSelector` exists and its focused tests pass, but `DefaultWorkspaceCommandService.swift` has no selector usage in the restore path.
- The restore path already recreates terminal surfaces from each restored `WorkspaceTab`, so continuity wiring must only change the selection passed to `store.restore(...)`, not terminal launch intent.
- Full-package coverage is below 80% because app/UI surfaces are included, but `Sources/NativeMacADECore` line coverage is 91.38% after the task changes.

## Files / Surfaces
- Touched: `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift`
- Touched: `Sources/NativeMacADECore/Observability/PerformanceMetrics.swift`
- Touched tests: `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift`, `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift`, `Tests/NativeMacADECoreTests/PerformanceMetricsTests.swift`

## Errors / Corrections
- Avoided relying on `RestoreWorkspaceResult.store` class aliasing by snapshotting restored projects/sessions/tabs before applying the final continuity selection to the result store.

## Ready for Next Run
- Verification evidence: `swift test --enable-code-coverage` passed with 440 tests; `git diff --check` passed. Core coverage from `NativeMacADE.json` was 91.38% line coverage.
