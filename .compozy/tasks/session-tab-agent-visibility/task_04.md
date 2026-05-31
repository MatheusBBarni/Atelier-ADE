---
status: pending
title: "Session disclosure UI and direct tab jump"
type: frontend
complexity: medium
dependencies:
  - task_03
---

# Task 04: Session disclosure UI and direct tab jump

## Overview
Extend the sidebar session rows so users can expand a session, inspect terminal-only child rows, and jump directly to the correct tab. This task lands the visible V1 experience while preserving the approved restore behavior that keeps sessions collapsed until the user expands them.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The sidebar UI MUST render inline terminal child rows only when the user expands a session.
- 2. Session disclosure state MUST remain view-local and MUST default to collapsed on restore.
- 3. Child-row taps MUST route through `WorkspaceCommandService.selectTab(id:)` rather than mutating selection directly.
- 4. The UI MUST preserve terminal-only scope and MUST keep file tabs out of the inline child-row list.
- 5. Session-row changes SHOULD maintain accessibility labeling and keep secondary `SessionRowView` call sites compiling.
</requirements>

## Subtasks
- [ ] 4.1 Add session-local disclosure state to the sidebar surface.
- [ ] 4.2 Render terminal child rows from the approved summary pipeline only when a session is expanded.
- [ ] 4.3 Highlight the selected terminal tab when the current session selection matches a rendered child row.
- [ ] 4.4 Route child-row selection through the command service so project, session, and tab selection stay synchronized.
- [ ] 4.5 Preserve collapsed restore behavior and ensure non-primary `SessionRowView` call sites remain valid.
- [ ] 4.6 Add automated coverage for disclosure behavior, terminal-only rendering, direct jump behavior, and restore-default collapse.

## Implementation Details
Implement the visible sidebar experience using the summary pipeline from task 03 and the direct-jump path described in the TechSpec "User Experience" and "Development Sequencing" sections. Do not expand this task into file rows, global monitor UI, or stored expansion-state persistence.

### Relevant Files
- `Sources/NativeMacADE/AppShell/ContentView.swift` — `ProjectSidebarView` owns the existing project expansion state and is the correct place for session disclosure state.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — `SessionRowView` is the current flat session row and must be extended to support nested terminal child rows.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — `SessionListView` also instantiates `SessionRowView` and must remain source-compatible.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — `selectTab(id:)` is the approved direct-jump path.
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — current selected-session and selected-tab semantics define which child row is highlighted.

### Dependent Files
- `Sources/NativeMacADE/AppShell/SessionTerminalSummaryBuilder.swift` — this task renders the summary output built in task 03.
- `Sources/NativeMacADE/AppShell/SessionTerminalPresentationResolver.swift` — row identity and iconography depend on the shared resolver from task 01.
- `Tests/NativeMacADEIntegrationTests/RestoreCoordinatorIntegrationTests.swift` — restore-default collapse behavior should be validated here.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — existing mixed-tab fixtures can validate direct tab-jump selection behavior.

### Related ADRs
- [ADR-002: Adopt a focused inline navigator approach for the PRD](../adrs/adr-002.md) — locks the UI scope to terminal-only rows, collapsed restore, and fast jump-to-tab behavior.
- [ADR-003: Keep session-tab summary composition in AppShell](../adrs/adr-003.md) — keeps the visible feature anchored in AppShell.
- [ADR-004: Use event-driven factual status derived from existing metadata](../adrs/adr-004.md) — constrains any rendered status to factual inputs only.

## Deliverables
- Sidebar session rows with disclosure behavior for terminal-only child rows.
- Direct tab-jump behavior from child-row taps.
- Collapsed-by-default restore behavior preserved.
- Accessible session and child-row rendering that keeps current secondary call sites compiling.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for disclosure, direct jump, and restore-default collapse **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Expanded session renders only terminal child rows even when the session contains file tabs.
  - [ ] The currently selected terminal tab is the only child row marked selected.
  - [ ] If a mixed session currently has a file tab selected, no terminal child row is falsely highlighted.
  - [ ] Duplicate terminal labels still map child-row taps to the correct `tabID`.
- Integration tests:
  - [ ] Clicking a terminal child row updates selected project, session, and tab through the command-service selection path.
  - [ ] Restored workspaces keep session rows collapsed by default until the user expands them.
  - [ ] Session-row signature changes do not break the secondary `SessionListView` path.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Users can expand a session and jump directly to the correct terminal tab from the sidebar.
- Restored workspaces remain collapsed by default, and the sidebar stays terminal-only and factual in V1.
