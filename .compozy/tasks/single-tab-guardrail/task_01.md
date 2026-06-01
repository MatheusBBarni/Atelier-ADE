---
status: completed
title: "Persist Focus Workspace preference and ship migration v6"
type: backend
complexity: high
dependencies: []
---

# Task 01: Persist Focus Workspace preference and ship migration v6

## Overview
Persist the Focus Workspace feature as part of the existing app-global preferences model and SQLite metadata schema. This task lays the durable foundation for every later Focus Workspace behavior, so it must keep startup loading, migration safety, and default fallback semantics stable.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The implementation MUST add `focusWorkspaceEnabled` to `AppPreferences` with a default value of `false`.
- 2. The implementation MUST persist the new field in the existing single-row `app_preferences` table and MUST bump `WorkspaceMigrations.currentUserVersion` from `5` to `6`.
- 3. Fresh bootstrap, upgrade, and repair paths MUST create or recover the new column idempotently without losing existing theme, default profile, terminal font size, or keybinding data.
- 4. `SQLiteWorkspaceMetadataStore` load/save SQL MUST round-trip `focusWorkspaceEnabled` in both directions.
- 5. Startup behavior MUST remain load-preferences-first, then restore, and default fallback behavior MUST still produce `AppPreferences.defaults` with Focus Workspace disabled.
- 6. This task SHOULD NOT introduce any session-level, tab-level, or restore-policy persistence for Focus Workspace.
</requirements>

## Subtasks
- [x] 1.1 Extend the persisted `AppPreferences` model to carry the Focus Workspace flag with stable defaults.
- [x] 1.2 Add a v6 metadata migration and repair path for the new `app_preferences` column.
- [x] 1.3 Update SQLite preference load/save queries so the new field round-trips with the existing settings payload.
- [x] 1.4 Preserve startup preference loading and `.defaults` fallback semantics with the expanded model.
- [x] 1.5 Add regression coverage for fresh databases, upgraded databases, repaired preference loads, and startup ordering.

## Implementation Details
Implement this task using the TechSpec **"Data Models"**, **"Impact Analysis"**, and **"Development Sequencing"** sections as the authoritative guide. Keep the change inside the existing preferences and metadata seams; do not widen scope into command enforcement, UI behavior, or restore normalization.

### Relevant Files
- `Sources/NativeMacADECore/Workspace/AppPreferences.swift` — defines the app-global preferences model and defaults.
- `Sources/NativeMacADECore/Persistence/WorkspaceMigrations.swift` — owns `currentUserVersion`, app-preferences DDL, bootstrap seed row, and repair helpers.
- `Sources/NativeMacADECore/Persistence/SQLiteWorkspaceMetadataStore.swift` — hard-coded `app_preferences` SELECT and UPSERT SQL must stay in sync with schema changes.
- `Sources/NativeMacADECore/App/AppShellState.swift` — startup still must load preferences before restore and fall back cleanly on load failure.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — existing preference-repair path must preserve the new field while healing unrelated stale references.
- `Tests/NativeMacADEIntegrationTests/SQLiteWorkspaceMetadataStoreTests.swift` — current home for fresh bootstrap, migration, repair, and app-preferences round-trip coverage.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — unit coverage for preference default/save/load behavior.

### Dependent Files
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — carries the full `AppPreferences` struct into observable app state.
- `Sources/NativeMacADECore/Persistence/WorkspacePersistenceStore.swift` — in-memory persistence stores the full preferences struct and may need expectation updates.
- `Sources/NativeMacADE/AppShell/ConfigModalAppearanceAndShortcutsSection.swift` — downstream settings UI reads and saves the widened preferences model.
- `Sources/NativeMacADE/AppShell/ConfigModalAgentProfilesSection.swift` — downstream settings UI also reads and saves full `AppPreferences` values.
- `Tests/NativeMacADECoreTests/AppShellStateTests.swift` — startup-order and default fallback assertions depend on the expanded model.
- `Tests/NativeMacADECoreTests/WorkspaceModelsTests.swift` — `AppPreferences.defaults` and value-semantics coverage should reflect the new field.

### Related ADRs
- [ADR-005: Persist Focus Workspace as an app-global preference in AppPreferences with a v6 migration](../adrs/adr-005.md) — primary technical decision for app-global persistence and migration scope.
- [ADR-004: Enforce Focus Workspace at the command layer and grandfather existing multi-tab sessions](../adrs/adr-004.md) — constrains this task from introducing restore-time or session-level policy state.
- [ADR-001: Scope V1 as a settings-first single-tab preference with real enforcement](../adrs/adr-001.md) — establishes durable settings-first behavior as a product requirement.

## Deliverables
- `AppPreferences` updated to include `focusWorkspaceEnabled` with stable defaults.
- `WorkspaceMigrations` updated to v6 with bootstrap and repair coverage for the new column.
- `SQLiteWorkspaceMetadataStore` updated to load and save `focusWorkspaceEnabled` correctly.
- Startup and preference-repair paths verified against the expanded settings model.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for fresh bootstrap, v5→v6 upgrade, and startup ordering **(REQUIRED)**

## Tests
- Unit tests:
  - [x] `AppPreferences.defaults` returns `focusWorkspaceEnabled == false` and preserves existing default theme/font/keybinding behavior.
  - [x] Saving and reloading preferences through the command service preserves `focusWorkspaceEnabled` without mutating unrelated fields.
  - [x] Preference repair for stale theme or default-profile data does not clobber `focusWorkspaceEnabled`.
- Integration tests:
  - [x] Fresh SQLite bootstrap creates `user_version == 6`, includes `focus_workspace_enabled`, and seeds one `app_preferences` row with the flag set to false.
  - [x] Upgrading a v5 database to v6 preserves existing workspace metadata and adds `focus_workspace_enabled` with a false default.
  - [x] Startup still loads preferences before restore, and load failure still falls back to `.defaults` with Focus Workspace disabled.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Fresh and upgraded databases load `focusWorkspaceEnabled` without breaking existing preference or restore behavior.
- The app can start, fall back to defaults, and persist preferences with the new field present.
