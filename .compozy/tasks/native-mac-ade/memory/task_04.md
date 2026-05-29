# Task Memory: task_04.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot

- Implement Task 04: replace placeholder-only workspace mutation with a real observable store plus a default in-process command service for project/session/tab/restore/close flows.
- Required evidence includes Swift tests for duplicate handling, naming/rename semantics, tab context inheritance, rollback on terminal failure, restore reconstruction, and last-tab close selection cleanup.

## Important Decisions

- AGENTS.md and CLAUDE.md were requested but are not present anywhere under the repository root; proceed using PRD, techspec, ADRs, package, and existing Swift sources.
- Existing Task 04 implementation is mostly present from later-task work; finish the task by closing the recency gap rather than rewriting established command/restore/terminal surfaces.
- Selection commands now validate stale IDs and use a staged activation flow so persistence failures do not mutate the live store.

## Learnings

- Current source already had most Task 04 surfaces from later-task work; this run added explicit selection-recency mutation and persistence coverage.
- `SQLiteWorkspaceMetadataStore.saveActivation(...)` must avoid async self-calls inside an open transaction; synchronous private save helpers are used so rollback can be verified deterministically.

## Files / Surfaces

- Expected surfaces: `Sources/NativeMacADECore/Workspace`, `Sources/NativeMacADECore/Commands`, `Sources/NativeMacADECore/App`, app shell wiring, and core/integration test targets.
- Touched surfaces: `WorkspaceStore`, `DefaultWorkspaceCommandService`, `WorkspacePersistenceStore`, `SQLiteWorkspaceMetadataStore`, command-service unit tests, SQLite integration tests, and persistence test doubles.

## Errors / Corrections

- Oracle review caught that naive recency persistence mutated the live store before persistence and lacked SQLite-backed transaction coverage; fixed by staging selection in a temporary store and adding SQLite success/rollback tests.

## Ready for Next Run

- Final verification evidence: `swift build && swift test --enable-code-coverage && python3 ...` passed with 64 tests; line coverage 91.83% and function coverage 80.00%.
