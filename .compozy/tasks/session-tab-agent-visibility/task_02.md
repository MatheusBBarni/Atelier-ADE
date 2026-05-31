---
status: pending
title: "Terminal exit observer source"
type: backend
complexity: medium
dependencies: []
---

# Task 02: Terminal exit observer source

## Overview
Add a lightweight exit-event source that fans out `TerminalHostController` exit callbacks while preserving the existing logging and metrics path. This gives the AppShell a factual, event-driven status input for V1 without introducing a persisted runtime-status model.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The implementation MUST preserve the current `terminal_process_exited` logging and metrics behavior triggered from `recordTerminalProcessExit(tabID:exitStatus:)`.
- 2. The new exit-event source MUST remain ephemeral and in-memory only, with no persistence or restore-schema changes.
- 3. The source MUST support factual exit snapshot lookup and subscription for UI consumers.
- 4. The implementation MUST avoid expanding `WorkspaceStore` into a broader runtime-status model.
- 5. The refresh path SHOULD remain event-driven only, with no timer-based polling loop.
</requirements>

## Subtasks
- [ ] 2.1 Define the lightweight terminal-exit observer contract used by AppShell consumers.
- [ ] 2.2 Wire the observer source into the existing `TerminalHostController.onSurfaceExited` path.
- [ ] 2.3 Preserve the existing command-service logging and metrics sink while adding fan-out behavior.
- [ ] 2.4 Expose snapshot and subscription behavior suitable for AppShell factual status consumers.
- [ ] 2.5 Add automated coverage for fan-out, snapshot, unsubscribe, and logging preservation behavior.

## Implementation Details
Create the observer near `AppDependencyContainer` as described in the TechSpec "System Architecture" and "Monitoring and Observability" sections. Do not add store-owned status or any new persisted status field. Missing exit data must remain neutral and must not imply a running state.

### Relevant Files
- `Sources/NativeMacADECore/App/AppDependencyContainer.swift` — current bootstrap point for the single `onSurfaceExited` consumer; primary integration seam.
- `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift` — factual terminal-exit source contract must remain intact.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — existing logging and metric sink that must continue to receive every exit event.
- `Tests/NativeMacADEIntegrationTests/TerminalHostIntegrationTests.swift` — existing integration pattern for exit-callback propagation.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — existing regression pattern for exit log fields.

### Dependent Files
- `Sources/NativeMacADE/AppShell/ContentView.swift` — later sidebar consumers will subscribe to exit updates.
- `Sources/NativeMacADE/AppShell/SessionTerminalSummaryBuilder.swift` — later summary composition depends on exit snapshots.
- `Tests/NativeMacADEIntegrationTests/ScaffoldIntegrationTests.swift` — good place for live-container wiring assertions.

### Related ADRs
- [ADR-004: Use event-driven factual status derived from existing metadata](../adrs/adr-004.md) — defines the event-driven, ephemeral status model.
- [ADR-003: Keep session-tab summary composition in AppShell](../adrs/adr-003.md) — keeps the observer lightweight and close to app bootstrap instead of building a broader monitor service.

## Deliverables
- A new lightweight terminal-exit event source near app bootstrap.
- Existing terminal-exit logging and metrics behavior preserved.
- Ephemeral exit snapshot lookup and subscription support for AppShell consumers.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for exit fan-out and logging preservation **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Initial snapshot for an unseen tab ID returns no exit observation.
  - [ ] Publishing an exit stores the expected snapshot for the matching tab ID.
  - [ ] Multiple subscribers receive the same `(tabID, exitStatus)` event.
  - [ ] Unsubscribed listeners do not receive later exit events.
  - [ ] `nil` exit status is preserved in the snapshot path while remaining valid for logging.
- Integration tests:
  - [ ] Live container wiring publishes exit events to the observer source and still emits the existing `terminal_process_exited` behavior exactly once.
  - [ ] Existing terminal host exit propagation tests remain green after fan-out is added.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- AppShell consumers can observe factual terminal exits without a new persisted or store-owned status model.
- Existing exit logging and metrics behavior remain unchanged from the user-visible diagnostics perspective.
