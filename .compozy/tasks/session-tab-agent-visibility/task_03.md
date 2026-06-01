---
status: completed
title: "Session terminal summary pipeline and shortcut catalog refresh"
type: frontend
complexity: high
dependencies:
  - task_01
  - task_02
---

# Task 03: Session terminal summary pipeline and shortcut catalog refresh

## Overview
Build the AppShell summary pipeline that prepares terminal-only child rows for each session by combining ordered terminal tabs, shortcut-catalog metadata, shared identity resolution, and factual exit snapshots. This task also ensures custom profile changes can refresh the cached shortcut catalog without requiring an app restart.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The summary pipeline MUST build session child rows from `WorkspaceStore.terminalTabs(in:)` only and MUST exclude file tabs.
- 2. The pipeline MUST preserve terminal tab display order as provided by the store and MUST not reorder rows by recency.
- 3. The pipeline MUST merge shared presentation resolution, shortcut-catalog lookup, and factual exit snapshots into one render-ready summary model.
- 4. The AppShell MUST reload cached shortcut metadata after agent-profile save, reset, or delete flows so custom labels remain current.
- 5. The summary model MUST remain factual only; missing exit data or stale lookup data MUST NOT imply richer live-state semantics.

</requirements>

## Subtasks
- [x] 3.1 Define the render-ready terminal summary model and builder contract for one session.
- [x] 3.2 Build terminal-only summary generation from store tabs, resolver output, and exit snapshots.
- [x] 3.3 Add AppShell shortcut-catalog caching keyed by shortcut ID.
- [x] 3.4 Add event-driven catalog refresh behavior after profile save, reset, and delete flows.
- [x] 3.5 Keep selected-file-tab scenarios neutral so no terminal child row is falsely marked selected.
- [x] 3.6 Add automated coverage for mixed sessions, custom profile refresh, exit overlay, and neutral fallback behavior.

## Implementation Details
Implement the summary builder in AppShell and use the TechSpec "Data Models", "Testing Approach", and "Technical Considerations" sections as the authoritative pattern guide. Do not expand scope into file-tab rows, persisted status, or priority ranking. Existing command-service catalog loading remains the source of truth.

### Relevant Files
- `Sources/NativeMacADE/AppShell/ContentView.swift` — `ProjectSidebarView` is the primary owner of sidebar state and the most natural shortcut-catalog cache consumer.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — `SessionRowView` will consume render-ready summary rows built by this task.
- `Sources/NativeMacADE/AppShell/ConfigModalAgentProfilesSection.swift` — current profile save, reset, and delete flows are the required invalidation points for shortcut-catalog refresh.
- `Sources/NativeMacADE/NativeMacADEApp.swift` — existing `Notification.Name` extension pattern can carry a shortcut-catalog refresh notification.
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — `terminalTabs(in:)` and current selection state define summary inputs and ordering.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — `availableSessionShortcuts()` remains the catalog source of truth.

### Dependent Files
- `Sources/NativeMacADE/AppShell/SessionTerminalPresentationResolver.swift` — this task depends on the shared identity resolver from task 01.
- `Sources/NativeMacADECore/App/TerminalExitEventSource.swift` — this task depends on the exit snapshot and subscription seam from task 02.
- `Sources/NativeMacADE/AppShell/AgentProfileVisuals.swift` — summary rows will reuse existing icon-branding behavior through the resolved shortcut model.
- `Package.swift` — may need target exposure updates if AppShell-local helper coverage is added directly.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — existing shortcut and mixed-tab fixtures can be extended for summary assertions.

### Related ADRs
- [ADR-003: Keep session-tab summary composition in AppShell](../adrs/adr-003.md) — places the summary builder in AppShell rather than Core.
- [ADR-004: Use event-driven factual status derived from existing metadata](../adrs/adr-004.md) — constrains the status overlay and refresh model.
- [ADR-002: Adopt a focused inline navigator approach for the PRD](../adrs/adr-002.md) — keeps the summary terminal-only, factual, and action-oriented.
- [ADR-001: Scope V1 as inline session-row attention routing](../adrs/adr-001.md) — prevents this task from broadening into a monitoring subsystem.

## Deliverables
- A new AppShell summary builder that outputs terminal-only render-ready session summaries.
- In-memory shortcut-catalog caching and event-driven refresh after profile mutations.
- Neutral selected-state behavior when a mixed session currently has a file tab selected.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for mixed sessions, shortcut refresh, and exit overlay behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Mixed session input containing terminal and file tabs produces summaries for terminal tabs only.
  - [x] Summary ordering follows `WorkspaceStore.terminalTabs(in:)` output order.
  - [x] Custom profile lookup resolves updated label and icon data after a catalog refresh.
  - [x] Exit snapshots only affect matching terminal tab summaries.
  - [x] A selected file tab in a mixed session results in no terminal summary marked selected.
- Integration tests:
  - [x] Saving a custom agent profile triggers catalog refresh and updates subsequent summary identity output.
  - [x] Resetting or deleting an agent profile triggers catalog refresh without requiring app restart.
  - [x] Summary generation remains stable for sessions created with plain, default, and explicit agent-tab flows.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Session summary generation is terminal-only, factual, and stable for mixed-session inputs.
- Custom profile label changes propagate to summary identity without requiring app restart.
