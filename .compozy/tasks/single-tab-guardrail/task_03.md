---
status: pending
title: "Enforce focus rules in commands and local observability"
type: backend
complexity: high
dependencies:
  - task_01
  - task_02
---

# Task 03: Enforce focus rules in commands and local observability

## Overview
Implement Focus Workspace as a future-only command-layer policy inside `DefaultWorkspaceCommandService`. This task is the correctness boundary for blocked terminal/file actions, legacy-session grandfathering, and local enable/disable plus rejection observability.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The command-service error surface MUST gain a dedicated `focusWorkspaceRejected` case backed by typed focus-policy violations.
- 2. `DefaultWorkspaceCommandService` MUST enforce Focus Workspace only on future create/open actions and MUST NOT normalize or collapse legacy multi-tab sessions.
- 3. Terminal-tab creation paths (`createTab`, `createPlainTab`, `createDefaultAgentTab`, `createAgentTab`) MUST reject additional terminal creation when the selected session already has a terminal tab under Focus Workspace.
- 4. `openFileTab` MUST preserve same-file reuse, MUST allow the first file tab, and MUST reject a second different file tab when one file tab already exists under Focus Workspace.
- 5. Blocked attempts MUST be side-effect free: no new terminal surfaces, no new file tabs, no snapshot mutations, and no persistence writes.
- 6. The implementation MUST record local metrics and structured log events for preference enable/disable and focus-policy blocked attempts.
- 7. Restore behavior MUST remain grandfathering/policy-free, with enforcement applied only to future commands after restore completes.
</requirements>

## Subtasks
- [ ] 3.1 Add the typed Focus Workspace rejection case to the public command-service error surface.
- [ ] 3.2 Enforce additional-terminal-tab blocking across all terminal-tab creation flows.
- [ ] 3.3 Enforce the approved file-open matrix for first file open, same-file reuse, and second different-file rejection.
- [ ] 3.4 Keep blocked actions side-effect free across store state, persistence, and terminal surfaces.
- [ ] 3.5 Extend local metrics and logging for enable/disable and blocked-attempt observability.
- [ ] 3.6 Add regression coverage for no-mutation blocking, grandfathered restore behavior, and observability fields.

## Implementation Details
Use the TechSpec **"API Endpoints"**, **"Monitoring and Observability"**, **"Known Risks"**, and **"Development Sequencing"** sections as the implementation guide. Keep all durable enforcement inside `DefaultWorkspaceCommandService`; do not split focus ownership into restore, views, or a new subsystem.

### Relevant Files
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — defines `WorkspaceCommandError` and the public create/open command surface.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — owns preference save/load, terminal creation, file-open behavior, restore, and structured logging.
- `Sources/NativeMacADECore/Observability/PerformanceMetrics.swift` — existing local counters and diagnostics should grow with Focus Workspace metrics.
- `Sources/NativeMacADECore/Workspace/FocusWorkspacePolicy.swift` — shared policy helper consumed for create/open gating.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — main home for side-effect-free rejection and logging assertions.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — SQLite-backed coverage for future commands after restore.
- `Tests/NativeMacADECoreTests/PerformanceMetricsTests.swift` — direct metrics/diagnostics assertions for new counters.

### Dependent Files
- `Sources/NativeMacADECore/Workspace/AppPreferences.swift` — this task depends on the persisted focus flag from task 01.
- `Sources/NativeMacADECore/App/AppShellState.swift` — startup ordering depends on the preference being loaded before restore.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — later blocked-action UX depends on the dedicated focus rejection error emitted here.
- `Sources/NativeMacADE/NativeMacADEApp.swift` — later menu gating depends on the same shared policy outcomes.
- `Tests/NativeMacADECoreTests/AppShellStateTests.swift` — startup ordering remains a regression concern once the preference exists.

### Related ADRs
- [ADR-004: Enforce Focus Workspace at the command layer and grandfather existing multi-tab sessions](../adrs/adr-004.md) — primary decision for enforcement ownership and future-only behavior.
- [ADR-006: Allow one terminal tab plus one optional file tab and hide blocked terminal-tab affordances](../adrs/adr-006.md) — defines the allowed create/open matrix and same-file reuse exception.
- [ADR-007: Use a shared pure Focus Workspace policy helper instead of duplicating rules in views and commands](../adrs/adr-007.md) — requires command enforcement to consume the shared helper, not reimplement rules.
- [ADR-005: Persist Focus Workspace as an app-global preference in AppPreferences with a v6 migration](../adrs/adr-005.md) — ties enforcement to app-global preference state.

## Deliverables
- Typed Focus Workspace rejection errors in the public command-service surface.
- Command-layer enforcement for terminal and file tab creation/open flows.
- Local metrics and structured logs for focus enable/disable and blocked attempts.
- SQLite-backed regression coverage for future commands after restore and side-effect-free blocking.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for blocked command flows, same-file reuse, and grandfathered restore behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] With Focus Workspace enabled and an existing terminal tab, `createTab`, `createPlainTab`, `createDefaultAgentTab`, and `createAgentTab` each reject with the focus terminal-tab violation.
  - [ ] Blocked terminal-tab attempts create no new terminal surface, add no tab, and do not mutate the restore snapshot.
  - [ ] With Focus Workspace enabled, opening the first file tab succeeds and preserves selection behavior.
  - [ ] With Focus Workspace enabled and an existing file tab for the same path, `openFileTab` reuses the tab instead of blocking or creating a duplicate.
  - [ ] With Focus Workspace enabled and an existing different file tab, `openFileTab` rejects with the focus file-tab violation and does not mutate store or persistence state.
  - [ ] Saving preferences from focus off→on and on→off records the correct local metrics/log events.
- Integration tests:
  - [ ] A restored legacy multi-tab session remains unchanged after restore when Focus Workspace is enabled.
  - [ ] After restoring a legacy multi-tab session, a future terminal-tab creation attempt is blocked by the command service.
  - [ ] A SQLite-backed session with one terminal and one file tab still allows same-file reopen but blocks a second different file tab under Focus Workspace.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Focus Workspace enforcement lives entirely in the command layer for future create/open actions.
- Blocked attempts are side-effect free and locally observable through stable metrics/logging fields.
