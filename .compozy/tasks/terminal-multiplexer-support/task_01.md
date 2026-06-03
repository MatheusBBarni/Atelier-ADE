---
status: completed
title: Continuity preference model, persistence, and migration
type: backend
complexity: high
dependencies: []
---

# Task 01: Continuity preference model, persistence, and migration

## Overview

This task establishes the persisted continuity preference contract that every later continuity behavior depends on. It adds the new child preference to the existing app-owned settings model and SQLite metadata store, while keeping defaults safe, migrations repairable, and restore snapshot semantics unchanged.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST add `focusWorkspaceContinuityEnabled` to `AppPreferences` with a default value of `false` and preserve existing value semantics for preferences.
2. MUST persist the new preference in the existing `app_preferences` record through the current workspace persistence layer without adding new tables or a separate continuity store.
3. MUST bump SQLite workspace metadata schema version from `6` to `7`, add a safe migration path, and repair current-version databases or rows that are missing the new column by normalizing the value to `false`.
4. MUST keep `RestoreSnapshot` and other restore metadata shapes unchanged, consistent with the truthful snapshot boundary defined in the TechSpec and ADR-004.
</requirements>

## Subtasks
- [x] 1.1 Extend the persisted app-preferences model to include the continuity child preference and default contract.
- [x] 1.2 Update the workspace metadata schema, seed row, and repair path to support the new continuity column in both fresh and legacy databases.
- [x] 1.3 Update SQLite load and save behavior so the continuity preference round-trips through the existing persistence boundary.
- [x] 1.4 Add migration and round-trip regression coverage for bootstrap, upgrade, and repair scenarios.

## Implementation Details

Use the TechSpec sections **Implementation Design → Data Models**, **Implementation Design → Persistence shape**, **Impact Analysis**, and **Development Sequencing → Build Order (step 1)** as the source of truth. This task should establish storage only; do not fold parent-child invariant enforcement or restore-time selection logic into this slice.

### Relevant Files
- `Sources/NativeMacADECore/Workspace/AppPreferences.swift` — Adds the new persisted continuity preference and default model contract.
- `Sources/NativeMacADECore/Persistence/WorkspaceMigrations.swift` — Owns the schema version bump, `app_preferences` column addition, bootstrap DDL, and repair path.
- `Sources/NativeMacADECore/Persistence/SQLiteWorkspaceMetadataStore.swift` — Reads and writes the new continuity column through existing app-preferences queries.
- `Sources/NativeMacADECore/Persistence/WorkspacePersistenceStore.swift` — Existing persistence protocol boundary that carries the widened `AppPreferences` shape.
- `Tests/NativeMacADEIntegrationTests/SQLiteWorkspaceMetadataStoreTests.swift` — Best home for bootstrap, upgrade, repair, and persistence round-trip coverage.
- `Tests/NativeMacADECoreTests/WorkspaceModelsTests.swift` — Covers `AppPreferences` defaults and value-semantic expectations.

### Dependent Files
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Later tasks depend on this persisted field for invariant repair and restore gating.
- `Sources/NativeMacADE/AppShell/ConfigModalFocusWorkspaceSection.swift` — The settings UI will later bind to the new persisted preference.
- `Sources/NativeMacADECore/Workspace/FocusWorkspacePresentation.swift` — Later copy and cues depend on the final child-toggle contract.
- `Sources/NativeMacADECore/App/AppShellState.swift` — Startup restore flow relies on loading the widened app-preferences model before restore.

### Related ADRs
- [ADR-003: Model continuity as a Focus Workspace sub-toggle](../adrs/adr-003.md) — Defines the new child preference and persistence scope.
- [ADR-004: Resolve continuity at restore time with terminal-first selection and truthful snapshot persistence](../adrs/adr-004.md) — Requires continuity storage without altering `RestoreSnapshot` truthfulness.

## Deliverables
- Updated `AppPreferences` model with persisted `focusWorkspaceContinuityEnabled` support.
- SQLite schema version `7` with bootstrap, migration, and repair handling for the new continuity column.
- Updated app-preferences SQLite load/save behavior for the continuity flag.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for continuity preference persistence and migration safety **(REQUIRED)**

## Tests
- Unit tests:
  - [x] `AppPreferences` defaults set `focusWorkspaceContinuityEnabled` to `false` for newly created preferences.
  - [x] `AppPreferences` value-semantic copies preserve an explicitly set `focusWorkspaceContinuityEnabled` value.
  - [x] Current-version repair logic returns `focusWorkspaceContinuityEnabled = false` when the stored row is missing the new column.
- Integration tests:
  - [x] A fresh workspace metadata database bootstraps `app_preferences.focus_workspace_continuity_enabled` with default `0`.
  - [x] A version-6 workspace metadata database upgrades to version `7` and loads `focusWorkspaceContinuityEnabled = false`.
  - [x] Saving preferences with `focusWorkspaceEnabled = true` and `focusWorkspaceContinuityEnabled = true` round-trips both flags through `SQLiteWorkspaceMetadataStore`.
  - [x] A current-version database missing the new column is repaired without losing the rest of the app-preferences record.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The codebase persists the continuity child preference through the existing app-preferences record and SQLite metadata store.
- Fresh, upgraded, and repaired databases all load a safe continuity default without adding new persistence tables or synthetic restore metadata.
