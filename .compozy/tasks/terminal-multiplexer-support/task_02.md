---
status: completed
title: Focus Workspace continuity invariant enforcement
type: backend
complexity: medium
dependencies:
  - task_01
---

# Task 02: Focus Workspace continuity invariant enforcement

## Overview

This task enforces the parent-child rule that continuity can only exist under Focus Workspace. It centralizes load and save normalization in Core so invalid persisted states cannot survive relaunch, and so the non-opted-in workflow remains unchanged outside the new preference.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST normalize any incoming or loaded preference state with `focusWorkspaceEnabled = false` so `focusWorkspaceContinuityEnabled` is also persisted and exposed as `false`.
2. MUST enforce the parent-child invariant in core load and save paths, not only in SwiftUI settings code.
3. MUST preserve existing Focus Workspace behavior for users who do not opt in and avoid introducing spurious parent enable or disable side effects when only the child flag is repaired.
4. MUST ensure startup and restore consumers observe normalized app preferences before restore-time continuity decisions are applied.
</requirements>

## Subtasks
- [x] 2.1 Add centralized normalization for the continuity child preference in core app-preferences load and save paths.
- [x] 2.2 Ensure invalid persisted combinations are repaired to a truthful disabled state before the rest of the app consumes them.
- [x] 2.3 Preserve existing Focus Workspace behavior and side effects for users who leave continuity disabled.
- [x] 2.4 Add regression coverage for save-time normalization, load-time repair, and startup ordering.

## Implementation Details

Use the TechSpec sections **System Architecture → Preferences and settings layer**, **Data Flow → Settings path**, **API Endpoints → Internal service API impact**, and **Development Sequencing → Build Order (step 2)**. This task should enforce the invariant in Core and leave UI rendering details to the settings task.

### Relevant Files
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Main seam for normalized app-preferences load/save behavior and repair handling.
- `Sources/NativeMacADECore/Workspace/AppPreferences.swift` — Optional home for a small helper that represents the normalized parent-child preference contract.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — Best unit-test surface for save normalization, load repair, and child-only state handling.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Covers end-to-end save and reload behavior through the command-service boundary.
- `Tests/NativeMacADECoreTests/AppShellStateTests.swift` — Verifies startup still loads normalized preferences before restore begins.

### Dependent Files
- `Sources/NativeMacADE/AppShell/ConfigModalFocusWorkspaceSection.swift` — Later UI logic depends on the invariant already being enforced in Core.
- `Sources/NativeMacADECore/App/AppShellState.swift` — Startup continues to rely on normalized preferences being available before restore.
- `Sources/NativeMacADECore/Workspace/FocusWorkspacePresentation.swift` — Presentation copy later assumes only valid continuity states are exposed.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Restore-time continuity application later depends on this invariant remaining stable.

### Related ADRs
- [ADR-003: Model continuity as a Focus Workspace sub-toggle](../adrs/adr-003.md) — Defines the required parent-child invariant and requires Core-side enforcement.

## Deliverables
- Core normalization of `focusWorkspaceContinuityEnabled` during app-preferences load and save.
- Repair behavior for invalid persisted parent-off/child-on combinations.
- Startup and command-service regression coverage for normalized preference consumption.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Focus Workspace continuity invariant behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Saving preferences with `focusWorkspaceEnabled = false` and `focusWorkspaceContinuityEnabled = true` persists the normalized state `{false, false}`.
  - [x] Loading an impossible persisted state `{focusWorkspaceEnabled = false, focusWorkspaceContinuityEnabled = true}` repairs the exposed preferences to `{false, false}`.
  - [x] Saving preferences with both `focusWorkspaceEnabled = true` and `focusWorkspaceContinuityEnabled = true` preserves the opted-in state.
  - [x] Child-only repair does not trigger extra parent enable or disable behavior beyond the normalized preference result.
- Integration tests:
  - [x] Disabling Focus Workspace after continuity was enabled persists both preferences as `false` after reload.
  - [x] App startup loads normalized app preferences before restore consumers observe continuity state.
  - [x] Non-opted-in users continue to load and save Focus Workspace preferences without any continuity-specific behavior changes.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Invalid parent-off/child-on continuity states cannot survive a load/save cycle.
- Restore and UI consumers see a single normalized continuity preference contract from Core.
