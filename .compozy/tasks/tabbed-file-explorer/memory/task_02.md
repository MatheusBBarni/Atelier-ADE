# Task Memory: task_02.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement task 02: make store, command-service, close/remove, and restore flows branch by `WorkspaceTab.kind` while terminal behavior remains unchanged and file tabs persist metadata only.
- Pre-change signal: `WorkspaceCommandService` has no file-tab command APIs, and `DefaultWorkspaceCommandService.restoreWorkspace()` recreates terminal surfaces by iterating every restored tab.

## Important Decisions
- Added metadata-only `openFileTab(sessionID:path:)` in task 02 so file tabs can enter the shared tab namespace before task 03 adds live file buffers/save/revert.
- File tabs bypass terminal `canClose` and terminal surface release in close/remove flows for this task; dirty-buffer close checks remain future task 03 work because no buffer runtime exists yet.
- Restore treats invalid or unreadable file tabs as skipped warning diagnostics and keeps valid mixed tab ordering from the existing snapshot order.

## Learnings
- This repo has no `AGENTS.md` or `CLAUDE.md` under `/Users/matheusbbarni/projects/another-ade`; task execution uses PRD/TechSpec/ADRs and existing repo patterns as guidance.

## Files / Surfaces
- Expected surfaces: `WorkspaceStore`, `WorkspaceCommandService`, `DefaultWorkspaceCommandService`, `RestoreCoordinator`, current terminal host filtering in `ContentView`, and related unit/integration tests.
- Touched implementation: `WorkspaceStore`, `WorkspaceCommandService`, `DefaultWorkspaceCommandService`, `RestoreCoordinator`, `TerminalHostController`, and `ContentView`.
- Touched tests: `WorkspaceStoreTests`, `DefaultWorkspaceCommandServiceTests`, `RestoreCoordinatorTests`, `RestoreCoordinatorIntegrationTests`, and `DefaultWorkspaceCommandServiceIntegrationTests`.

## Errors / Corrections
- Targeted test compile caught a missing explicit `return` in the unit test fake terminal manager; fixed before continuing.

## Ready for Next Run
- Full verification passed with `swift test --enable-code-coverage`: 151 tests, 0 failures. NativeMacADECore line coverage from the generated codecov JSON is 3,496/3,892 lines = 89.83%.
- Targeted pre-final verification passed for `WorkspaceStoreTests`, `DefaultWorkspaceCommandServiceTests`, `RestoreCoordinatorTests`, `RestoreCoordinatorIntegrationTests`, and `DefaultWorkspaceCommandServiceIntegrationTests`: 87 tests, 0 failures.
- Self-review found no blocking issues; `git diff --check` passed.
