# Task Memory: task_03.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement task 03: command-layer Focus Workspace enforcement for future terminal/file create/open actions, typed command rejection errors, local metrics/logging, side-effect-free blocked attempts, and regression coverage.
- Implementation, focused tests, full `swift test --enable-code-coverage`, and first-party coverage verification are complete.

## Important Decisions
- Scope is limited to `DefaultWorkspaceCommandService`, command error surface, observability, and tests. Restore remains grandfathering/policy-free per ADR-004.
- Terminal creation gating runs before launch-profile/default-profile resolution so blocked attempts cannot create surfaces, tabs, snapshots, or preference/profile persistence side effects.
- File-open gating runs after canonical file-reference validation and same-file reuse detection, preserving same-file reopen while blocking only second different-file creation.
- Tracking-only files are updated for workflow state but should not be included in the automatic code commit.

## Learnings
- No repository-local `AGENTS.md` or `CLAUDE.md` files were found under `/Users/matheusbbarni/projects/another-ade`; sibling repository guidance files are not applicable.
- Same-file file-tab reuse legitimately updates activation/selection metadata; tests should assert stable tab identity/order rather than full persisted tab value equality for that allowed path.

## Files / Surfaces
- Planned surfaces: `WorkspaceCommandService`, `DefaultWorkspaceCommandService`, `PerformanceMetrics`, command-service unit/integration tests, performance metrics tests, and task tracking files.
- Touched code/test surfaces: `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift`, `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift`, `Sources/NativeMacADECore/Observability/PerformanceMetrics.swift`, `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift`, `Tests/NativeMacADECoreTests/PerformanceMetricsTests.swift`, `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift`.

## Errors / Corrections
- Initial same-file reuse tests incorrectly expected full persisted tab equality; corrected to assert no duplicate tab IDs while allowing activation timestamp updates.

## Ready for Next Run
- Verification evidence: `swift test --enable-code-coverage` passed with 282 tests; `xcrun llvm-cov report ... -ignore-filename-regex='(^|/)\\.build/|(^|/)Tests/'` reported total first-party region coverage 82.84%.
- Code/test commit created: `cbd564d` (`feat: enforce focus workspace command rules`). Tracking and memory files remain uncommitted by design.
