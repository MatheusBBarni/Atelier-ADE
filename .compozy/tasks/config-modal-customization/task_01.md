---
status: pending
title: "Add app preferences model and additive SQLite v2 migration"
type: backend
complexity: high
dependencies: []
---

# Task 01: Add app preferences model and additive SQLite v2 migration

## Overview
This task establishes the persisted settings foundation for Config Modal Customization. It adds the narrow global preferences model, the additive SQLite v2 migration, and matching in-memory persistence behavior so the rest of the feature can build on one stable, local-first settings seam.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The implementation MUST add a narrow typed `AppPreferences` model for the V1 settings surface instead of a generic settings bag.
- 2. The implementation MUST add typed keybinding override support scoped only to the approved managed command set, including tab navigation, session navigation, session search, terminal zoom, right-sidebar toggle, and settings access.
- 3. The implementation MUST extend `SessionShortcut` with explicit built-in override state and persist that state through both live and in-memory stores.
- 4. The implementation MUST extend `WorkspacePersistenceStore`, `SQLiteWorkspaceMetadataStore`, and `InMemoryWorkspacePersistenceStore` with equivalent `AppPreferences` load/save behavior.
- 5. The implementation MUST ship an additive SQLite v2 upgrade path that preserves all existing project, session, tab, and restore data.
- 6. The implementation SHOULD clear any saved default-profile reference when the referenced shortcut is deleted so downstream session bootstrap stays safe.
</requirements>

## Subtasks
- [ ] 1.1 Define the new global preferences and keybinding domain types required by the TechSpec Data Models section.
- [ ] 1.2 Extend `SessionShortcut` with the explicit built-in override state required for curated agent-profile customization.
- [ ] 1.3 Expand the persistence protocol and both persistence implementations to load and save app preferences.
- [ ] 1.4 Add the additive SQLite schema update, default seed row, and user-version bump for v2.
- [ ] 1.5 Ensure shortcut deletion clears any stored default-profile reference in both live and in-memory persistence paths.
- [ ] 1.6 Add regression coverage for models, migration behavior, and persistence round-trips.

## Implementation Details
Modify the core models and persistence seams first. See the TechSpec sections **Data Models**, **Storage Structures**, and **Migration Strategy** for the required shape of `AppPreferences`, keybinding overrides, and the SQLite v2 upgrade. Keep the implementation additive and local-first.

### Relevant Files
- `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift` — Current `SessionShortcut` model and built-in defaults that need additive preference-related state.
- `Sources/NativeMacADECore/Workspace/AppPreferences.swift` — Likely new home for `AppPreferences`, keybinding override types, and related typed settings models.
- `Sources/NativeMacADECore/Persistence/WorkspacePersistenceStore.swift` — Persistence boundary that must grow to cover app preferences.
- `Sources/NativeMacADECore/Persistence/SQLiteWorkspaceMetadataStore.swift` — Live SQLite store that must persist the new table and override state.
- `Sources/NativeMacADECore/Persistence/WorkspaceMigrations.swift` — Startup-critical schema bootstrap and user-version migration logic.
- `Tests/NativeMacADEIntegrationTests/SQLiteWorkspaceMetadataStoreTests.swift` — Best fit for migration and persistence round-trip coverage.
- `Tests/NativeMacADECoreTests/WorkspaceModelsTests.swift` — Best fit for typed model semantics and override-state coverage.

### Dependent Files
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — Later tasks need settings APIs on top of the new persistence contract.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Default-profile resolution and settings mutation flows depend on this data existing first.
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — Later UI/runtime tasks depend on an observable preferences model.
- `Sources/NativeMacADE/NativeMacADEApp.swift` — Dynamic top-level command bindings depend on typed keybinding preference data.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Startup preference load depends on this task’s persisted settings foundation.

### Related ADRs
- [ADR-001: Agent-First Scope for Config Modal Personalization](adrs/adr-001.md) — Keeps the preferences layer narrow and agent-first.
- [ADR-004: SQLite-Centered Global Preferences Layer](adrs/adr-004.md) — Directly defines the persistence approach for this task.
- [ADR-005: Reuse SessionShortcut as the Curated Agent Profile Model](adrs/adr-005.md) — Requires extending `SessionShortcut` instead of inventing a new persisted profile type.
- [ADR-006: Limited Keybinding Scope and Immediate Preference Application](adrs/adr-006.md) — Constrains keybinding modeling to the approved managed command set, including terminal zoom.
- [ADR-007: Centralize New-Session Bootstrap in WorkspaceCommandService](adrs/adr-007.md) — The default-profile reference created here feeds the later bootstrap contract.

## Deliverables
- Typed `AppPreferences` and keybinding override models aligned with the TechSpec.
- Additive `SessionShortcut` built-in override state with persistence support.
- Extended `WorkspacePersistenceStore`, `SQLiteWorkspaceMetadataStore`, and `InMemoryWorkspacePersistenceStore` for app preferences.
- SQLite v2 migration with seeded default preferences row and preserved workspace metadata.
- Updated model and persistence test suites.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for preferences persistence and migration **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `AppPreferences` preserves theme ID, optional default shortcut ID, keybinding overrides, and update timestamps as value-semantic data.
  - [ ] `SessionShortcut.hasUserOverride` round-trips correctly for built-in and custom profiles.
  - [ ] In-memory persistence save/load preserves app preferences and override state without mutation.
  - [ ] Deleting a shortcut in the in-memory store clears `defaultSessionShortcutID` when it points at that shortcut.
- Integration tests:
  - [ ] Fresh SQLite bootstrap creates `app_preferences`, exposes `has_user_override`, and sets `PRAGMA user_version = 2`.
  - [ ] A hand-built v1 SQLite database upgrades to v2 without changing existing projects, sessions, tabs, or restore rows.
  - [ ] SQLite save/load round-trip preserves `AppPreferences`, including nil and non-nil default shortcut references.
  - [ ] SQLite save/load round-trip preserves `SessionShortcut.hasUserOverride` for built-in overrides.
  - [ ] Deleting a persisted shortcut referenced by `app_preferences.default_session_shortcut_id` clears that stored reference.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Existing workspace metadata survives the v1→v2 migration unchanged.
- Both live and in-memory stores expose the same `AppPreferences` behavior.
- Downstream tasks can rely on one persisted default-profile and keybinding source of truth.
