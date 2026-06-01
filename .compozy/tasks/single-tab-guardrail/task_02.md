---
status: pending
title: "Introduce shared Focus Workspace policy helper"
type: refactor
complexity: medium
dependencies:
  - task_01
---

# Task 02: Introduce shared Focus Workspace policy helper

## Overview
Add a small pure policy helper so command enforcement and UI affordances share one Focus Workspace rule set. This task prevents policy drift without introducing a new service subsystem or moving mutation ownership out of `DefaultWorkspaceCommandService`.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The implementation MUST introduce a shared pure helper in `NativeMacADECore` for Focus Workspace session-state evaluation.
- 2. The helper MUST remain side-effect free and MUST NOT own persistence, logging, selection, or mutation behavior.
- 3. The helper MUST model the approved Focus Workspace matrix: focus off is unrestricted; focus on allows at most one terminal tab plus one optional file tab.
- 4. The helper MUST allow same-file reopen under Focus Workspace and MUST reject a second different file tab when one file tab already exists.
- 5. The helper SHOULD expose derived compliance or overflow state only if needed to keep UI framing truthful for legacy multi-tab sessions.
- 6. This task MUST NOT implement command gating, menu hiding, or blocked-action UI directly; those belong to later tasks.
</requirements>

## Subtasks
- [ ] 2.1 Define the Focus Workspace session-state model in core.
- [ ] 2.2 Define the Focus Workspace violation model for blocked action outcomes.
- [ ] 2.3 Add pure policy decisions for terminal creation eligibility and file-open eligibility.
- [ ] 2.4 Reuse existing store tab queries or add a minimal derived-state helper only if it removes duplicated count logic.
- [ ] 2.5 Add isolated matrix tests for allowed, blocked, and legacy-overflow cases.

## Implementation Details
Use the TechSpec **"System Architecture"**, **"Core Interfaces"**, and **"Technical Considerations"** sections as the reference for boundaries and naming. Keep the new helper tiny and stateless, similar in spirit to existing workspace helpers; do not expand it into a service or couple it to persistence or UI state.

### Relevant Files
- `Sources/NativeMacADECore/Workspace/FocusWorkspacePolicy.swift` — new shared home for session-state evaluation and allowed action decisions.
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — existing `tabs(for:)`, `terminalTabs(in:)`, and `fileTabs(in:)` may supply derived state inputs.
- `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift` — `WorkspaceTabKind` bounds the policy matrix to `.terminal` and `.file`.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — downstream consumer for create/open enforcement once this helper exists.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — downstream consumer for tab-row and plus-affordance truthfulness.
- `Sources/NativeMacADE/NativeMacADEApp.swift` — downstream consumer for focus-aware menu visibility.
- `Tests/NativeMacADECoreTests/FocusWorkspacePolicyTests.swift` — new isolated test home for the policy matrix.

### Dependent Files
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — later task adds the typed focus rejection error surface that will depend on this policy result.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — later command tests should prove service behavior matches the shared helper.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — later SQLite-backed coverage should consume the same policy assumptions.
- `Tests/NativeMacADECoreTests/WorkspaceStoreTests.swift` — may need updates if a small store convenience helper is added.

### Related ADRs
- [ADR-007: Use a shared pure Focus Workspace policy helper instead of duplicating rules in views and commands](../adrs/adr-007.md) — primary architectural rationale for this task.
- [ADR-006: Allow one terminal tab plus one optional file tab and hide blocked terminal-tab affordances](../adrs/adr-006.md) — defines the approved tab matrix and same-file reopen rule.
- [ADR-004: Enforce Focus Workspace at the command layer and grandfather existing multi-tab sessions](../adrs/adr-004.md) — preserves command ownership and legacy-session truthfulness.
- [ADR-005: Persist Focus Workspace as an app-global preference in AppPreferences with a v6 migration](../adrs/adr-005.md) — the helper’s `enabled` input comes from the persisted preference.

## Deliverables
- A shared pure Focus Workspace policy helper in `NativeMacADECore`.
- Derived Focus Workspace session-state and violation types suitable for both command and UI consumers.
- Isolated matrix coverage for allowed and blocked terminal/file scenarios.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration-style tests for store-derived state and legacy-overflow truthfulness **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Focus disabled returns terminal/file creation allowed regardless of current tab counts.
  - [ ] Focus enabled with `terminal=0,file=0` allows first terminal creation and first file open.
  - [ ] Focus enabled with `terminal=1,file=0` rejects additional terminal creation with the terminal-tab violation.
  - [ ] Focus enabled with `terminal=1,file=1` allows same-file reopen but rejects a different-file second file tab.
  - [ ] Legacy-overflow states such as `terminal=2,file=0` or `terminal=1,file=2` report non-compliant state without mutating anything.
- Integration tests:
  - [ ] A store-backed selected session with mixed visible tabs produces the same derived terminal/file counts used by policy evaluation.
  - [ ] A restored legacy multi-tab store fixture remains readable as overflow/non-compliant state rather than being normalized by the helper.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Commands and UI can consume one shared Focus Workspace rule set without duplicating tab-count logic.
- The helper remains pure, side-effect free, and limited to the approved terminal/file allowance matrix.
