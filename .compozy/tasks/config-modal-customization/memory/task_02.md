# Task Memory: task_02.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Centralize first-tab bootstrap in `WorkspaceCommandService.createSession` for explicit profile, saved default profile, and plain shell session starts.
- Preserve restore semantics and keep `createTab(sessionID:)` as the later-tab path that uses persisted session launch intent.

## Important Decisions
- Follow TechSpec/ADR-007 resolution order exactly: explicit `shortcutID`, then saved `AppPreferences.defaultSessionShortcutID`, then plain shell.
- `createSession` now persists session plus first tab through `save(session:firstTab:)` for every launch source; terminal surface creation happens before persistence so surface failures leave no session/tab records.
- `createTab(sessionID:)` resolves only from the session's stored `shortcutID`; it does not read current app preferences.

## Learnings
- No repo-local `AGENTS.md` or `CLAUDE.md` was found under `/Users/matheusbbarni/projects/another-ade`; execution is grounded in the PRD, TechSpec, ADRs, and repository code.
- Worktree already had modified task-01 tracking/memory files before task-02 edits; keep those unrelated changes intact.
- `availableSessionShortcuts()` remains the built-in profile seeding path. Session launch resolution can read built-ins without seeding, then persists the chosen built-in before saving a session reference.

## Files / Surfaces
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift`
- `Sources/NativeMacADE/AppShell/ContentView.swift`
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift`
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift`

## Errors / Corrections
- Updated test expectations where plain `createSession` now creates ordinal-0 first tabs, making later `createTab` calls ordinal 1+.
- Extended the unit test clock fallback so tests remain monotonic after `createSession` gained first-tab work and extra `now()` calls.

## Ready for Next Run
- Fresh verification passed after implementation: `swift test --enable-code-coverage` ran 90 tests successfully; source coverage was 80.45% regions and 88.40% lines via `llvm-cov report`.
- Fresh `swift build` completed successfully after the coverage run.
