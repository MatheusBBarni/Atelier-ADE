---
status: pending
title: Preference validation, repair, and persistence behavior
type: backend
complexity: high
dependencies:
  - task_01
---

# Task 02: Preference validation, repair, and persistence behavior

## Overview

This task makes the new appearance-selection contract durable and safe across load, save, repair, and restart flows. It updates the existing command-service and persistence-facing seams so `system` is treated as a valid persisted selection, stale theme IDs repair to `system`, and the current local-first storage model remains unchanged.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST update the existing preference validation seam so `system` is accepted anywhere a persisted `themeID` is validated or normalized.
2. MUST make stale or invalid persisted theme IDs repair to `system` and align fresh default preference seeding with the same fallback behavior.
3. MUST preserve the existing SQLite `app_preferences` row shape and avoid any schema migration or `user_version` bump.
4. MUST update existing metrics and logging paths so theme saves, repairs, and applications remain observable under the new selection semantics.
</requirements>

## Subtasks
- [ ] 2.1 Update preference validation to recognize `system` as a supported persisted selection.
- [ ] 2.2 Update stale-theme repair behavior so invalid selections recover to `system` instead of a fixed preset.
- [ ] 2.3 Align default preference seeding and raw persistence round-trip behavior with the new selection model.
- [ ] 2.4 Update metrics and logging fields or event handling affected by the new reserved selection and repair flow.
- [ ] 2.5 Add focused unit and integration coverage for validation, repair, round-trip persistence, and startup normalization.

## Implementation Details

Keep all validation, repair, persistence, and observability changes inside the existing service and SQLite seams described in the TechSpec sections **System Architecture → Preferences Model and Validation**, **Implementation Design → Storage Structures**, and **Monitoring and Observability**. This task should not introduce new persistence backends, new tables, or broader settings abstractions.

### Relevant Files
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Primary load/save/repair/metrics seam for appearance settings.
- `Sources/NativeMacADECore/Workspace/AppPreferences.swift` — Defines defaults and supported selection IDs consumed by validation.
- `Sources/NativeMacADECore/Persistence/SQLiteWorkspaceMetadataStore.swift` — Persists `theme_id` as the single raw appearance-selection field.
- `Sources/NativeMacADECore/Persistence/WorkspaceMigrations.swift` — Seeds the `app_preferences` row and must stay schema-stable.
- `Sources/NativeMacADECore/Observability/PerformanceMetrics.swift` — Existing settings and theme metrics seam that may need updates.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — Best unit-test home for validation, logging, and save-flow behavior.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Best integration-test home for round-trip persistence, startup repair, and corruption recovery.
- `Tests/NativeMacADEIntegrationTests/SQLiteWorkspaceMetadataStoreTests.swift` — Useful integration-test home for default-row and persistence assertions.

### Dependent Files
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — Will receive repaired or defaulted selection IDs after service load behavior changes.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Startup runtime application depends on repaired/default preference values being stable.
- `Sources/NativeMacADE/AppShell/ConfigModalAppearanceAndShortcutsSection.swift` — Settings autosave depends on the service accepting `system` as a valid persisted selection.
- `Tests/NativeMacADECoreTests/AppThemeTests.swift` — Selection-contract unit tests may need updates once defaults and fallback behavior change.
- `Tests/NativeMacADEIntegrationTests/TerminalHostIntegrationTests.swift` — Runtime theme application tests depend on the new persisted selection semantics.

### Related ADRs
- [ADR-002: Use a Settings-First Appearance Baseline with System as the Lead Choice](../adrs/adr-002.md) — Requires System to be a real persisted MVP option.
- [ADR-003: Persist System Appearance as a Reserved Theme Selection](../adrs/adr-003.md) — Defines default and repair fallback behavior.
- [ADR-005: Centralize Effective Theme Resolution in the Theme Domain](../adrs/adr-005.md) — Service logic must preserve the resolver contract instead of duplicating runtime mapping.

## Deliverables
- Updated service validation and repair behavior for reserved `system` selection.
- Stable SQLite persistence and default-seeding behavior with no schema changes.
- Updated settings/theme observability for save, repair, and application events affected by the new selection semantics.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for persistence, repair, and startup normalization **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Saving `AppPreferences` with `themeID = system` succeeds and updates store state without validation failure.
  - [ ] Saving `AppPreferences` with an unknown `themeID` still returns a validation error.
  - [ ] Loading preferences with an invalid persisted theme ID repairs the selection to `system`.
  - [ ] Default preference construction used by service startup seeds `themeID = system`.
  - [ ] Theme save and repair paths emit the expected metrics or log events for the new selection contract.
- Integration tests:
  - [ ] SQLite round-trip preserves `theme_id = system` through save and reload.
  - [ ] Startup load repairs a raw stale `theme_id` to `system` without mutating unrelated preference fields.
  - [ ] Existing concrete preset IDs still round-trip unchanged after the new repair rules are introduced.
  - [ ] Fresh `app_preferences` seeding uses `system` without requiring a schema migration.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- `system` is accepted everywhere the persisted theme selection is loaded, validated, or saved.
- Invalid or stale persisted theme IDs repair safely to `system` without introducing schema changes or data-loss regressions.
