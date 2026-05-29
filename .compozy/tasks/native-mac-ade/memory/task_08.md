# Task Memory: task_08.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot

- Implement Task 08: lightweight session shortcuts through existing project/session/tab flows plus app-local pilot observability for open/session/tab/restore/terminal lifecycle events.
- Scope stays local-first and metadata-only: shortcut secrets may only be persisted as indirect references, and observability must remain in-process/local without backend alerting.

## Important Decisions

- Treat existing task_04 tracking as stale for this run because the required WorkspaceStore and DefaultWorkspaceCommandService surfaces exist and task_06/task_07 already depend on them; do not broaden scope to fix prior tracking changes in this task.
- Shortcut-backed session creation creates the first terminal surface before committing metadata, then persists session+first tab in a SQLite transaction through `save(session:firstTab:)`; persistence failure releases/destroys the surface before any store mutation.
- Local pilot observability is app-owned: `WorkspaceLogger` keeps in-memory structured events and mirrors them to OSLog, while `PerformanceMetrics` exposes diagnostics for in-app pilot banners and command-service inspection.

## Learnings

- Root AGENTS.md and CLAUDE.md are not present in this repository; PRD/task/ADR files are the available execution guidance.
- Launch-to-ready diagnostics use explicit launch-to-ready durations instead of tab creation timings so restore surface replay cannot hide startup regressions.
- Terminal process exit status now flows through the C shim, Ghostty adapter, terminal host callback, and command-service log event.

## Files / Surfaces

- Planned surfaces: core workspace models/persistence, DefaultWorkspaceCommandService, RestoreCoordinator/terminal lifecycle observability, and core/integration tests.
- Touched surfaces: `WorkspaceModels`, `WorkspacePersistenceStore`, `SQLiteWorkspaceMetadataStore`, `DefaultWorkspaceCommandService`, `WorkspaceCommandService`, `WorkspaceLogger`, `PerformanceMetrics`, `GhosttyAdapter`, `CGhosttyRuntime`, `CGhostty` shim, `TerminalHostController`, `AppDependencyContainer`, `ContentView`, and command/restore/terminal/metrics tests.

## Errors / Corrections

- Oracle review caught shortcut-flow reachability, local inspectability, launch-to-ready metric mixing, non-atomic shortcut session creation, and surface cleanup gaps; fixes added UI picker, OSLog/local diagnostics, separate launch-to-ready metrics, transactional session+first-tab persistence, and adapter/runtime destroy cleanup.

## Verification Evidence

- `swift test --enable-code-coverage` passed after all changes: 60 tests in 12 suites, 0 failures.
- Coverage evidence: `.build/arm64-apple-macosx/debug/codecov/NativeMacADE.json` reports line coverage 3622/3945 = 91.81%.
- Oracle final blocker check reported no blocker-level issues after surface destroy and persistence-failure release fixes.

## Ready for Next Run

- Task 08 implementation and verification are complete; remaining work is tracking update and local commit.
