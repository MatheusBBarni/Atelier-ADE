# Task Memory: task_01.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement task_01 backend persistence APIs for canonical reorder saves: project dense `sortIndex` rewrites, session tab dense `ordinal` rewrites, and atomic tab reorder plus derived restore snapshot persistence.
- Baseline: `rg "saveProjectOrder|saveTabOrder|SessionTabReorderPlan"` finds these names only in PRD/TechSpec docs, not in Swift sources or tests.

## Important Decisions
- Keep this task scoped to `WorkspacePersistenceStore`, `InMemoryWorkspacePersistenceStore`, `SQLiteWorkspaceMetadataStore`, and direct persistence tests; command orchestration remains task_02.
- Reorder persistence rejects incomplete or duplicate payloads at the storage boundary so successful writes always leave dense canonical order.
- SQLite tab reorder uses a transaction-local temporary ordinal offset before writing final ordinals to avoid `UNIQUE(session_id, ordinal)` collisions during adjacent swaps and end moves.

## Learnings
- No `AGENTS.md` or `CLAUDE.md` files exist under the repository root, so there is no local guidance from those requested filenames to apply.
- TechSpec/ADRs require no schema migration: existing `projects.sort_index`, `tabs.ordinal`, and derived `restore_snapshot.tab_order_json` stay canonical.
- Full Swift tests with coverage passed; touched persistence source files are above the task coverage target (`SQLiteWorkspaceMetadataStore.swift` 93.78% line coverage, `WorkspacePersistenceStore.swift` 96.17% line coverage). Overall package line coverage remains 42.75% due pre-existing untested surfaces outside this task.

## Files / Surfaces
- Touched: `Sources/NativeMacADECore/Persistence/WorkspacePersistenceStore.swift`
- Touched: `Sources/NativeMacADECore/Persistence/SQLiteWorkspaceMetadataStore.swift`
- Touched: `Tests/NativeMacADECoreTests/WorkspaceModelsTests.swift`
- Touched: `Tests/NativeMacADEIntegrationTests/SQLiteWorkspaceMetadataStoreTests.swift`
- Touched for protocol conformance: `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift`
- Touched for protocol conformance: `Tests/NativeMacADECoreTests/RestoreCoordinatorTests.swift`

## Errors / Corrections
- Tightened SQLite temporary ordinal offset after review so it handles negative stored ordinals without colliding with existing values.

## Ready for Next Run
- Task 02 should build complete `SessionTabReorderPlan` payloads, including hidden persisted tab IDs in their existing relative order, before calling persistence.
- Code/test implementation was committed locally as `2b70df7` (`feat: add canonical reorder persistence APIs`). Task tracking and workflow memory updates were intentionally left uncommitted as tracking-only files.
