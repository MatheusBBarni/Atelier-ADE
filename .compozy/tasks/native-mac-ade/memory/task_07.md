# Task Memory: task_07.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot

- Implement Task 07: metadata-only relaunch restore that rebuilds projects/sessions/tabs/selection, recreates fresh terminal surfaces, skips inaccessible records, and exposes recovery feedback.
- Required source of truth read before edits: task_07.md, _tasks.md, _prd.md, _techspec.md, ADRs 001-005, shared memory, current task memory. AGENTS.md and CLAUDE.md were searched for and are absent in this repo.

## Important Decisions

- Restore must stay metadata-only per ADR-005; do not persist or reattach live PTYs, scrollback, or shell processes.
- `WorkspaceCommandService.restoreWorkspace()` now returns a `RestoreWorkspaceResult` so app launch can surface recovery feedback without reading persistence directly.
- Skipped project recovery uses persisted-project IDs: skipped records can be forgotten, and reopening a now-accessible skipped path reuses the existing persisted project instead of creating a duplicate.

## Learnings

- Existing code already has `RestoreCoordinator`, `WorkspaceStore.restore(...)`, persistence snapshot APIs, command service restore entrypoint, and lazy terminal host creation; Task 07 needs to extend this to validation/recovery/fresh-shell replay semantics rather than create a parallel workspace model.
- Snapshot tab ordering must tolerate decodable-but-bad payloads such as duplicate or incomplete tab IDs; restore now de-duplicates order entries and renumbers restored tabs consistently.

## Files / Surfaces

- Expected implementation surfaces: `Sources/NativeMacADECore/Restore/RestoreCoordinator.swift`, command-service/container restore wiring, recovery UI in app shell, and restore-focused unit/integration tests.
- Touched implementation: `Sources/NativeMacADECore/Restore/RestoreCoordinator.swift`, `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift`, `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift`, `Sources/NativeMacADE/AppShell/ContentView.swift`.
- Touched tests: `Tests/NativeMacADECoreTests/RestoreCoordinatorTests.swift`, `Tests/NativeMacADEIntegrationTests/RestoreCoordinatorIntegrationTests.swift`, `Tests/NativeMacADECoreTests/WorkspaceStoreTests.swift`.

## Errors / Corrections

- Self-review via oracle found duplicate `tabOrder` could trap and skipped projects had no actual recovery path; fixed by duplicate-safe ordering, persisted-project reuse on reopen, and persisted-only remove support for forgotten skipped projects.
- `RestoreCoordinator` initially returned a `WorkspaceStore` created with invalid selection IDs; changed restore assembly to use `WorkspaceStore.restore(...)` so selection normalization applies before returning the result.

## Ready for Next Run

- Verification after final changes: `swift test` passed 50 tests; `swift test --enable-code-coverage` passed 50 tests; `xcrun llvm-cov report ...` showed total line coverage 88.78%; `xcodebuild -scheme NativeMacADE -destination 'platform=macOS' test` succeeded with 26 core tests and 24 integration tests.
