---
status: pending
title: "Add settings orchestration and agent-profile mutation APIs"
type: backend
complexity: high
dependencies:
  - task_01
  - task_02
---

# Task 03: Add settings orchestration and agent-profile mutation APIs

## Overview
This task expands the command-service and store seam from read-only launch-profile lookup into full settings orchestration. It makes preferences and agent-profile mutations safe, validated, observable, and ready for the modal UI without exposing persistence directly to the app shell.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The implementation MUST expose one command-service seam for loading and saving app preferences and for listing, saving, deleting, and resetting agent profiles.
- 2. The implementation MUST validate theme IDs, managed keybindings, default-profile references, and launch-argument JSON before persistence.
- 3. The implementation MUST preserve provenance rules: built-ins are editable and resettable but never deletable; custom profiles are deletable.
- 4. The implementation MUST self-heal stale saved default-profile references during load and destructive profile mutations.
- 5. The implementation MUST freeze the curated built-in catalog with stable IDs, including OpenCode.
- 6. The implementation MUST update observable preferences state immediately after successful mutations.
- 7. The implementation SHOULD keep the preferences surface narrow to the approved V1 fields only.
</requirements>

## Subtasks
- [ ] 3.1 Expand the command-service contract, errors, and store mutation surface for settings and agent-profile operations.
- [ ] 3.2 Add persistence-backed flows for loading, saving, deleting, and resetting agent profiles and app preferences.
- [ ] 3.3 Freeze the curated built-in catalog and merge it deterministically with persisted profile rows.
- [ ] 3.4 Add stale-default cleanup and safe fallback behavior for invalid saved default references.
- [ ] 3.5 Update observable store state so downstream UI and app commands react to successful changes immediately.
- [ ] 3.6 Add regression coverage for validation, provenance, precedence, and self-healing behavior.

## Implementation Details
See the TechSpec sections **Core Interfaces**, **API Endpoints**, **Data Models**, and **Key Decisions**. Keep settings orchestration in the existing command-service seam; do not introduce a separate settings protocol or expose persistence details to the UI.

### Relevant Files
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — Protocol and error surface that must expand for settings operations.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Primary orchestration point for validation, persistence, catalog seeding, and state updates.
- `Sources/NativeMacADECore/Persistence/WorkspacePersistenceStore.swift` — Persistence boundary that task_03 consumes for app-preferences and profile mutation paths.
- `Sources/NativeMacADECore/Persistence/SQLiteWorkspaceMetadataStore.swift` — SQLite-backed save/load/delete behavior for preferences and agent profiles.
- `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift` — Canonical built-in catalog and persisted agent-profile model.
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — Observable settings state for later UI/runtime use.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — Best fit for validation, provenance, and fallback rules.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Best fit for saved-default precedence and catalog merge behavior.

### Dependent Files
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Later startup and modal flows depend on these settings APIs.
- `Sources/NativeMacADE/NativeMacADEApp.swift` — Runtime keybinding resolution depends on persisted preferences reads.
- `Sources/NativeMacADECore/Theme/NordTheme.swift` — Later theme work depends on persisted theme choice flowing through this seam.
- `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift` — Live appearance updates depend on preferences being available at runtime.
- `Sources/NativeMacADECore/App/AppDependencyContainer.swift` — Dependency wiring depends on the expanded command-service and store capabilities.

### Related ADRs
- [ADR-001: Agent-First Scope for Config Modal Personalization](adrs/adr-001.md) — Keeps this task focused on agent-first settings behavior.
- [ADR-004: SQLite-Centered Global Preferences Layer](adrs/adr-004.md) — Governs the persistence seam this task must use.
- [ADR-005: Reuse SessionShortcut as the Curated Agent Profile Model](adrs/adr-005.md) — Directly governs built-in catalog, provenance, and profile mutation rules.
- [ADR-006: Limited Keybinding Scope and Immediate Preference Application](adrs/adr-006.md) — Constrains keybinding scope and future-session semantics.
- [ADR-007: Centralize New-Session Bootstrap in WorkspaceCommandService](adrs/adr-007.md) — Requires this task’s default-profile state to cooperate with the normalized bootstrap contract.

## Deliverables
- Expanded `WorkspaceCommandService` settings and profile mutation surface.
- Validation rules for theme IDs, keybindings, default-profile references, and launch-argument JSON.
- Curated built-in catalog including OpenCode with stable IDs and explicit provenance handling.
- Self-healing stale-default cleanup and immediate observable store updates.
- Updated unit and integration test coverage for settings orchestration behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for settings orchestration and agent-profile mutations **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Saving preferences rejects unknown theme IDs and leaves persisted preferences unchanged.
  - [ ] Saving preferences rejects duplicate managed keybindings and reports a typed validation failure.
  - [ ] Saving or editing a profile rejects malformed `launchArgumentsJSON` and preserves the previous valid profile state.
  - [ ] Editing a built-in profile marks it overridden; resetting it restores canonical values and clears override state.
  - [ ] Deleting a custom profile clears `defaultSessionShortcutID` when it references that profile.
  - [ ] Attempting to delete a built-in profile fails without mutating persistence.
- Integration tests:
  - [ ] Preferences and built-in override state round-trip through SQLite.
  - [ ] Explicit profile beats saved default, and saved default beats plain shell during new-session creation.
  - [ ] Loading persisted stale default-profile data self-heals to nil and plain session creation still succeeds.
  - [ ] Repeated profile-list loads do not duplicate built-ins and always include the curated OpenCode profile.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The UI can mutate preferences and agent profiles without talking to persistence directly.
- Built-in, customized, and custom profile states behave deterministically.
- Stale saved default references never block new-session creation.
