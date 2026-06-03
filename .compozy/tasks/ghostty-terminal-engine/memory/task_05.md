# Task Memory: task_05.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Preserve workspace lifecycle, restore, close/release, exit event, telemetry, diagnostics, and file-tab isolation contracts after the Ghostty-only `TerminalHostController` migration.
- Required evidence covers `DefaultWorkspaceCommandService` unit behavior plus integration coverage for restore, exit fan-out, diagnostics, and release readiness metrics.

## Important Decisions
- Kept production code unchanged after inspection and focused verification; the Ghostty-only command, restore, close, release, exit, metrics, and file-tab isolation contracts were already implemented.
- Added test-only hardening instead of adding runtime branches or persistence changes.
- Coverage evidence is scoped to `NativeMacADECore` and the touched backend surfaces; whole-package coverage includes mostly untested SwiftUI app-shell files and is not a meaningful backend task gate.

## Learnings
- `DefaultWorkspaceCommandService` records Ghostty handles in its own `surfacesByTabID` cache and falls back to `terminalSurfaceManager.surface(for:)`, so close/release tests should assert the actual `GhosttySurfaceHandle` sent to `canClose`.
- Restore creates terminal surfaces after restoring workspace metadata into memory; file tabs are loaded through file buffers and must not touch the terminal surface manager.
- Terminal exit callback fan-out is wired in `AppDependencyContainer.live()` by calling both `recordTerminalProcessExit` and `TerminalExitEventSource.publish`.

## Files / Surfaces
- Initial focus: `DefaultWorkspaceCommandService`, `AppDependencyContainer`, `TerminalExitEventSource`, `RestoreCoordinator`, `PerformanceMetrics`, `WorkspaceLogger`, and related core/integration tests.
- Touched tests: `DefaultWorkspaceCommandServiceTests.swift`, `PerformanceMetricsTests.swift`, `DefaultWorkspaceCommandServiceIntegrationTests.swift`, `ScaffoldIntegrationTests.swift`.
- Verification covered full `./scripts/run.sh build`, full `./scripts/run.sh test --enable-code-coverage`, `git diff --check`, and coverage extraction from SwiftPM codecov JSON.

## Errors / Corrections
- Initial pre-change filtered SwiftPM commands were started in parallel; they only proved the new task-specific test names were absent. Subsequent SwiftPM verification was run serially.
- Replaced a brittle `harness.store.projects[0]` assertion helper with the captured project ID during self-review.

## Ready for Next Run
- Current implementation is test-only. Do not reintroduce a SwiftTerm fallback while completing later task 06 cleanup.
- Local commit `3645236` contains only the test hardening files; workflow tracking and memory files were intentionally left unstaged per the task instruction to keep tracking-only files out of automatic commits.
