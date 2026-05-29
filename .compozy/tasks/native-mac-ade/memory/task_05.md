# Task Memory: task_05.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot

- Implement Task 05: SwiftUI workspace shell with persistent project sidebar, project-scoped session management, rename flow, active-state cues, and Nord app-shell theme.
- Required validation includes Task 05 unit/integration coverage for selection, session create/rename, remove-project, restore reconstruction, and default theme tokens.

## Important Decisions

- Repository has no root `AGENTS.md` or `CLAUDE.md`; required reads were attempted and no files exist under the workspace.
- Real source layout is `Sources/NativeMacADE/...` and `Sources/NativeMacADECore/...`, not the task doc's older `AnotherADE/...` path examples.
- Selection actions now go through `WorkspaceCommandService.selectProject/selectSession/selectTab` so restore snapshots track user navigation rather than only create/open mutations.
- Session rename preserves recency ordering; it changes title and `isUserNamed` without bumping `lastActivatedAt`.
- Live app dependency wiring now requires SQLite metadata persistence instead of silently falling back to in-memory storage.

## Learnings

- Baseline before Task 05 edits: `swift test` passes 26 tests; app shell exists but is placeholder-level and lacks project removal, real folder picker, session rename UI, and Nord theme.
- Workspace has pre-existing uncommitted edits from earlier tasks; Task 05 must keep scope tight and avoid rewriting unrelated surfaces.
- Final Task 05 verification: `swift test --enable-code-coverage` passed 31 tests in 8 suites; `llvm-cov report` showed 86.28% line coverage for non-test source files.

## Files / Surfaces

- Expected Task 05 surfaces: `Sources/NativeMacADE/AppShell/ContentView.swift`, new SwiftUI feature/theme files under `Sources/NativeMacADE`, workspace command/store removal APIs, and Task 05 tests.
- Touched surfaces: `Sources/NativeMacADE/AppShell/ContentView.swift`, `Sources/NativeMacADE/NativeMacADEApp.swift`, `Sources/NativeMacADECore/App/AppDependencyContainer.swift`, `Sources/NativeMacADECore/Commands/*`, `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift`, `Sources/NativeMacADECore/Theme/NordTheme.swift`, core/integration tests.

## Errors / Corrections

- Reviewer found direct store selection did not persist restore snapshots; corrected by adding command-service selection methods and routing UI selection through them.
- Reviewer found rename bumped recency and reordered sessions; corrected to preserve ordering.
- Initial project removal forgot live surface handles without close checks; corrected to call `canClose` for removed tab surfaces and reject removal when a surface refuses close.

## Ready for Next Run

- Task 06 should use `NordTheme` tokens for terminal/tab chrome consistency but still owns actual terminal launch/theme integration.
