# Task Memory: task_02.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement Task 02 backend persistence contract: accept `system` as a persisted theme selection, repair stale theme IDs to `system`, keep SQLite schema/user_version stable, and add service/store tests for validation, persistence, repair, startup normalization, and observability.

## Important Decisions
- Keep changes inside existing `AppPreferences`, `DefaultWorkspaceCommandService`, `PerformanceMetrics`, SQLite metadata, and existing test seams. Do not add persistence schema or runtime UI changes in this task.
- Service `theme_applied` logs keep the legacy `theme_id` field and add `selection_id`, `resolved_theme_id`, `resolution_status`, and `source`. For `system`, service logging marks resolution as `deferred_to_runtime_system_scheme` instead of guessing a concrete preset without the runtime scheme.

## Learnings
- Repository has no `AGENTS.md` or `CLAUDE.md` under `another-ade`; nearest matches are in sibling projects and are not applicable.
- Task 01 already added `AppTheme.systemSelectionID`, `AppTheme.defaultSelectionID == "system"`, `AppTheme.supportedSelectionIDs`, and `AppPreferences.defaultThemeID == AppTheme.defaultSelectionID`.
- Pre-change observability gap: no `themeRepairCount`, `effectiveThemeAppliedCount`, or `theme_repaired` event exists; service `theme_applied` currently logs only `theme_id`.

## Files / Surfaces
- Planned source surfaces: `DefaultWorkspaceCommandService.swift`, `PerformanceMetrics.swift`.
- Planned tests: `DefaultWorkspaceCommandServiceTests.swift`, `DefaultWorkspaceCommandServiceIntegrationTests.swift`, `SQLiteWorkspaceMetadataStoreTests.swift`, and `PerformanceMetricsTests.swift` if metrics API changes.
- Touched source surfaces: `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift`, `Sources/NativeMacADECore/Observability/PerformanceMetrics.swift`.
- Touched tests: `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift`, `Tests/NativeMacADECoreTests/PerformanceMetricsTests.swift`, `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift`, `Tests/NativeMacADEIntegrationTests/SQLiteWorkspaceMetadataStoreTests.swift`.

## Errors / Corrections
- Started two SwiftPM test filters in parallel; SwiftPM serialized on `.build`. Continued with single verification commands afterward.

## Ready for Next Run
- Verification completed for Task 02: `./scripts/run.sh test --enable-code-coverage` passed with 226 tests. `xcrun llvm-cov report ... -ignore-filename-regex='.build|Tests|ThirdParty'` reported total coverage 80.55% regions and 87.91% lines.
- Task 02 tracking was marked completed in `task_02.md` and `_tasks.md` after verification and self-review.
