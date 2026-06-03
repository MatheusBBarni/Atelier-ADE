# Task Memory: task_04.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement task 04 lifecycle integration for portable settings: startup bootstrap, manual reload, save/export, dependency wiring, observability, tests, tracking, and one local commit.

## Important Decisions
- Treat the existing `WorkspaceCommandService` protocol additions as pre-existing task 04 scaffolding and complete the implementation in `DefaultWorkspaceCommandService` without reverting prior task tracking changes.
- Save/export order follows the TechSpec data flow: validate runtime preferences, write the portable config atomically, then persist SQLite runtime state and update `WorkspaceStore`; export failures are logged/counted and rethrown before SQLite/store mutation.
- Startup invalid portable JSON/read failures fall back to normalized SQLite preferences while recording explicit portable load diagnostics; manual reload surfaces file-load/decode failures by throwing after recording reload-failure metrics/logs.

## Learnings
- `AGENTS.md` and `CLAUDE.md` are not present under `/Users/matheusbbarni/projects/another-ade`; matches found by `find ..` belong to sibling repositories and should not be applied.
- Baseline command `swift test --filter AppShellStateTests.startupCoordinatorDoesNotRestoreBeforePreferenceLoadCompletes` fails at compile time because `DefaultWorkspaceCommandService` does not yet implement `reloadPortableSettingsConfig()` or `portableSettingsConfigURL()`.
- Full coverage-enabled verification passed with 375 tests in 35 suites via `./scripts/run.sh test --enable-code-coverage`.
- Coverage evidence: touched core files reported 87.84% line coverage overall; `DefaultWorkspaceCommandService.swift` reported 85.99% line coverage.
- Separate product build passed via `./scripts/run.sh build`.

## Files / Surfaces
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` already contains the new portable config service methods in the current worktree.
- Expected task 04 surfaces: `DefaultWorkspaceCommandService`, `AppDependencyContainer`, `PerformanceMetrics`, `WorkspaceLogger` event usage, and command-service integration tests.
- Implemented surfaces: `DefaultWorkspaceCommandService`, `AppDependencyContainer`, `PerformanceMetrics`, command-service unit/integration tests, and temp portable-store injection in terminal/restore/summary integration harnesses.

## Errors / Corrections
- Initial integration run failed because an older theme test wrote SQLite preferences directly after startup had seeded a portable file; corrected it to use `saveAppPreferences(_:)`, matching file-authoritative behavior.
- A mixed-validity reload fixture initially used unsupported theme `kanagawa`; changed it to supported `dracula` so the test targets partial default-profile/keybinding rejection rather than appearance rejection.
- A restored built-in default-profile fixture initially violated SQLite foreign keys by referencing the Claude shortcut before persisting it; seeded the built-in shortcut first.

## Ready for Next Run
- Task 04 implementation and verification are complete; remaining closeout is task tracking update and local commit.
