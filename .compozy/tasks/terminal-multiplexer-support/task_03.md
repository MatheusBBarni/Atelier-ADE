---
status: pending
title: Restore-time continuity selector
type: backend
complexity: medium
dependencies:
  - task_01
---

# Task 03: Restore-time continuity selector

## Overview

This task adds the pure restore-only selector that expresses the MVP continuity rule without leaking it into general tab selection behavior. It gives the restore flow one app-owned decision point for terminal-first targeting while preserving truthful snapshot persistence and clean fallbacks.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST introduce a pure Core restore selector that consumes restored selection data plus app preferences and returns one `WorkspaceSelection` without side effects or throwing errors.
2. MUST activate only when both `focusWorkspaceEnabled` and `focusWorkspaceContinuityEnabled` are `true`.
3. MUST prefer the most recent terminal tab in the restored selected session using existing `lastActivatedAt` metadata, and MUST fall back to the raw restored selection when no eligible terminal tab exists.
4. MUST keep `RestoreSnapshot` truthful to actual UI history and MUST NOT change general in-session selection heuristics or add a new public command surface.
</requirements>

## Subtasks
- [ ] 3.1 Define the restore-only continuity selector as a separate Core type adjacent to existing workspace selection policy code.
- [ ] 3.2 Encode the terminal-first selection rule using restored session membership, tab kind, and `lastActivatedAt` metadata.
- [ ] 3.3 Preserve clean fallback behavior for disabled continuity, missing selected-session context, and sessions without terminal candidates.
- [ ] 3.4 Add focused selector tests that prove the contract independently from restore orchestration.

## Implementation Details

Use the TechSpec sections **System Architecture → Restore selection layer**, **Implementation Design → Core Interfaces**, **Implementation Design → Data Models**, and **Development Sequencing → Build Order (step 3)**. Keep this task limited to the pure selector contract; do not wire it into restore orchestration here.

### Relevant Files
- `Sources/NativeMacADECore/Workspace/FocusWorkspaceContinuityRestoreSelector.swift` — New pure Core selector file proposed by the TechSpec for restore-only continuity resolution.
- `Sources/NativeMacADECore/Workspace/WorkspaceSelection.swift` — Existing selection type returned by the selector.
- `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift` — Source of `WorkspaceTab.kind`, `lastActivatedAt`, and `RestoreSnapshot` data used by selector rules.
- `Sources/NativeMacADECore/Workspace/FocusWorkspacePolicy.swift` — Nearby policy boundary that this selector should stay separate from.
- `Tests/NativeMacADECoreTests/FocusWorkspaceContinuityRestoreSelectorTests.swift` — New focused test file for selector behavior and fallbacks.

### Dependent Files
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Later restore wiring will consume the selector result before live store restore.
- `Sources/NativeMacADECore/Restore/RestoreCoordinator.swift` — Remains the truthful metadata restore source that feeds the selector.
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — Final restore application later depends on selector output remaining compatible with store normalization.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Later integration tests will prove selector results are honored during relaunch restore.

### Related ADRs
- [ADR-004: Resolve continuity at restore time with terminal-first selection and truthful snapshot persistence](../adrs/adr-004.md) — Defines the restore-only selector contract, terminal-first rule, and truthful persistence boundary.

## Deliverables
- New pure Core continuity restore selector returning a `WorkspaceSelection`.
- Selector contract covering disabled, terminal-first, and fallback restore paths.
- Focused selector-level regression coverage independent of UI and restore orchestration.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for selector compatibility with restored workspace selection **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Continuity disabled returns the raw restored `WorkspaceSelection` unchanged.
  - [ ] Continuity enabled with one selected session containing both file and terminal tabs returns the terminal tab with the newest `lastActivatedAt`.
  - [ ] Continuity enabled with no terminal tab in the selected session returns the raw restored selection.
  - [ ] A terminal tab in a different session is ignored when resolving the continuity target.
  - [ ] Missing or stale selected-session context falls back to the raw restored selection instead of inventing a new target.
- Integration tests:
  - [ ] Applying a valid selector result to the restored workspace selection remains compatible with `WorkspaceStore` normalization behavior.
  - [ ] Applying a fallback selector result preserves the existing restored tab order and selected-session context.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The codebase has one pure restore-only selector for continuity decisions instead of spreading terminal-first logic across restore layers.
- Disabled or missing-terminal scenarios always fall back to truthful restored selection rather than inventing synthetic continuity state.
