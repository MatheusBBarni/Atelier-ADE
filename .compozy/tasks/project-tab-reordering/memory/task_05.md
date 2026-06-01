# Task Memory: task_05.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Harden restore/reorder edge cases for project and selected-session tab order, add reorder observability, and prove mismatch paths are surfaced through diagnostics/release gates.

## Important Decisions
- Treat ADR-001 as historical context; ADR-002 plus ADR-003/004/005 and the TechSpec define the current dual-surface task direction.
- Baseline signal before implementation: `rg` for expected reorder metric/event names returned no matches in `Sources` or `Tests`, so observability work is not already present.
- Restore-order mismatch conditions are surfaced as `RestoreDiagnostic.telemetryReason` values prefixed with `restore_order_`; the command service maps those to `reorder_restore_alignment_failed` events and pilot release-gate counters.
- Post-write reorder alignment checks reload persisted project/tab order and tab restore snapshot after command-owned saves; a mismatch throws `WorkspaceCommandError.reorderRestoreAlignmentFailed`.

## Learnings
- `DefaultWorkspaceCommandService.reorderTabs` already appends persisted-but-hidden tabs after reordered visible tabs using `SessionTabReorderPlan.hiddenPersistedTabIDs`.
- `RestoreCoordinator.orderedTabs` currently deduplicates/filters snapshot order silently, which is the likely seam for restore-order mismatch diagnostics.
- Root `AGENTS.md` and `CLAUDE.md` are not present in this repository checkout.
- Full Swift verification with coverage reports total line coverage of 82.17% when ignoring `.build` and `Tests`.

## Files / Surfaces
- Expected primary surfaces: `PerformanceMetrics`, `DefaultWorkspaceCommandService`, `RestoreCoordinator`, restore/command/persistence tests.
- Touched implementation: `PerformanceMetrics`, `WorkspaceCommandService`, `DefaultWorkspaceCommandService`, `RestoreCoordinator`.
- Touched tests: command-service unit/integration tests, restore coordinator unit/integration tests, performance metrics tests.

## Errors / Corrections

## Ready for Next Run
