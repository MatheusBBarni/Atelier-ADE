# Task Memory: task_01.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement storage-only support for `AppPreferences.focusWorkspaceContinuityEnabled`: model default/value semantics, SQLite schema v7 migration/repair, existing app_preferences load/save round-trip, and regression tests.

## Important Decisions
- Scope stays on task 01 / TechSpec build-order step 1. Parent-child invariant enforcement, restore selection, settings UI, and copy are deferred to later tasks.

## Learnings
- `WorkspaceMigrations.bootstrap` already has a repair path for current-version databases with missing app-preferences columns; the continuity column follows the same `ALTER TABLE ... DEFAULT 0` pattern.
- SwiftPM repo-wide coverage is 47.6048% because unrelated existing source is under-covered; the three task-owned source files are above 90% line coverage.

## Files / Surfaces
- Planned surfaces: `AppPreferences`, `WorkspaceMigrations`, `SQLiteWorkspaceMetadataStore`, `WorkspaceModelsTests`, and `SQLiteWorkspaceMetadataStoreTests`.
- Touched surfaces: `Sources/NativeMacADECore/Workspace/AppPreferences.swift`, `Sources/NativeMacADECore/Persistence/WorkspaceMigrations.swift`, `Sources/NativeMacADECore/Persistence/SQLiteWorkspaceMetadataStore.swift`, `Tests/NativeMacADECoreTests/WorkspaceModelsTests.swift`, and `Tests/NativeMacADEIntegrationTests/SQLiteWorkspaceMetadataStoreTests.swift`.

## Errors / Corrections
- Initially made the v2 seed insert include the new v7 column; corrected it to rely on the new column default so the migration does not add extra brittleness to older edge cases.

## Ready for Next Run
- Verification run after the final migration correction: `swift test --enable-code-coverage` passed with 418 tests across 39 suites.
- Task-owned source coverage from `.build/arm64-apple-macosx/debug/codecov/NativeMacADE.json`: `AppPreferences.swift` 95.3125% lines, `WorkspaceMigrations.swift` 92.0530% lines, `SQLiteWorkspaceMetadataStore.swift` 93.8534% lines.
