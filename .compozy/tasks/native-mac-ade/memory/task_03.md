# Task Memory: task_03.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot

- Implement Task 03: TechSpec-aligned workspace domain entities and a metadata-only SQLite persistence layer for projects, sessions, tabs, session shortcuts, and the single active restore snapshot.
- Required baseline captured: `swift test` passes before Task 03 edits; workspace already contains uncommitted Task 02-related changes that must not be overwritten or included blindly.

## Important Decisions

- Keep scope limited to metadata persistence; no scrollback, live PTY reattachment, checkpoint, secret-value, or global workspace concepts should be added.
- Domain models now expose TechSpec names (`Project`, `Session`, `Tab`) while retaining `WorkspaceProject`, `WorkspaceSession`, and `WorkspaceTab` typealiases for existing scaffold call sites.
- SQLite schema bootstrap uses the exact five metadata tables plus `PRAGMA user_version = 1`; no schema bookkeeping table was added so the V1 table set remains narrow.
- Restore snapshot JSON decode fails on malformed UUIDs instead of silently dropping corrupted tab IDs.

## Learnings

- `swift test --enable-code-coverage` writes coverage JSON to `.build/arm64-apple-macosx/debug/codecov/NativeMacADE.json`; final NativeMacADECore line coverage measured 936/1095 = 85.48%.
- `SQLite3` imports directly under the current macOS SwiftPM toolchain; no additional package dependency was required.

## Files / Surfaces

- Expected implementation surfaces: `Sources/NativeMacADECore/Workspace`, `Sources/NativeMacADECore/Persistence`, and focused core/integration tests.
- Touched Task 03 surfaces: `WorkspaceModels.swift`, `WorkspacePersistenceStore.swift`, new `WorkspaceMigrations.swift`, new `SQLiteWorkspaceMetadataStore.swift`, new `WorkspaceModelsTests.swift`, and new `SQLiteWorkspaceMetadataStoreTests.swift`.

## Errors / Corrections

- Initial restore snapshot overwrite test failed due to foreign key enforcement; corrected fixture setup to persist referenced project/session/tabs before saving snapshot rows.
- Oracle review flagged silent restore UUID drops and test-only production inspection APIs; fixed by throwing on invalid UUIDs and moving schema/row-count inspection into integration tests.

## Ready for Next Run

- Verification evidence before tracking updates: `swift test --enable-code-coverage` passed with 19 tests / 0 failures; `swift build` passed; NativeMacADECore coverage was 85.48%.
