---
status: completed
title: "Route GhosttyAdapter through the Swift wrapper runtime"
type: backend
complexity: high
dependencies:
  - task_01
---

# Task 02: Route GhosttyAdapter through the Swift wrapper runtime

## Overview
This task updates the existing `GhosttyAdapter` path to use the Swift wrapper target from task 01. It keeps the app-facing adapter seam stable while moving runtime behavior out of direct `CGhosttyRuntime` ownership.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST route `LiveGhosttyAdapter` through the Swift wrapper runtime created in task 01.
2. MUST keep `GhosttyAdapter` compatible with existing `TerminalHostController` tests until task 04 replaces the host path.
3. MUST expose native view access through the adapter boundary for later host attachment.
4. MUST remove the live adapter's production reliance on `usesEmbeddedSessionDriver == true`.
5. MUST preserve existing error mapping to `WorkspaceCommandError.terminalUnavailable`.
</requirements>

## Subtasks
- [x] 2.1 Update `LiveGhosttyAdapter` to depend on the Swift wrapper runtime.
- [x] 2.2 Preserve existing surface creation, inherited surface, focus, resize, close, exit, and destroy behavior.
- [x] 2.3 Add native view access to the adapter boundary for later host integration.
- [x] 2.4 Update adapter tests for wrapper-backed runtime calls and errors.
- [x] 2.5 Keep test fakes compatible with the revised adapter contract.

## Implementation Details
Modify the adapter boundary described in the TechSpec "System Architecture" and "Integration Points" sections. Keep the existing app error semantics intact so `DefaultWorkspaceCommandService` does not need to know about wrapper internals.

### Relevant Files
- `Sources/NativeMacADECore/Ghostty/GhosttyAdapter.swift` — Primary adapter contract and live implementation to route through the wrapper.
- `Sources/NativeMacADECore/Ghostty/CGhosttyRuntime.swift` — Existing runtime logic that should be replaced or delegated away from `NativeMacADECore`.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Maps `GhosttyAdapterError` into workspace-visible terminal errors.
- `Tests/NativeMacADECoreTests/GhosttyAdapterTests.swift` — Primary unit coverage for launch configuration, adapter errors, and lifecycle behavior.
- `Tests/NativeMacADEIntegrationTests/TerminalHostIntegrationTests.swift` — Contains `RecordingGhosttyAdapter` fake that may need protocol updates.

### Dependent Files
- `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift` — Will consume native view access and wrapper-backed lifecycle in task 04.
- `Sources/NativeMacADECore/App/AppDependencyContainer.swift` — Instantiates the live adapter in the app dependency graph.
- `Tests/NativeMacADEIntegrationTests/ScaffoldIntegrationTests.swift` — Exercises live adapter initialization and pinned revision behavior.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Uses fake terminal managers that depend on stable surface/error semantics.

### Related ADRs
- [ADR-003: Replace the SwiftTerm terminal path inside TerminalHostController with Ghostty surfaces](adrs/adr-003.md) — Requires the adapter to become the real Ghostty runtime path.
- [ADR-005: Add a Swift-native Ghostty wrapper target and keep CGhostty as native interop scaffolding](adrs/adr-005.md) — Defines why the adapter should depend on the wrapper.
- [ADR-007: Validate Ghostty migration with manual baseline QA and focused runtime unit tests](adrs/adr-007.md) — Requires automated coverage around runtime wrapping.

## Deliverables
- `LiveGhosttyAdapter` routed through the new Swift Ghostty wrapper target.
- Adapter API support for native view access needed by host integration.
- Existing adapter error mapping preserved.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for app dependency and adapter wiring **(REQUIRED)**

## Tests
- Unit tests:
  - [x] `LiveGhosttyAdapter.createSurface` delegates to the wrapper runtime and preserves the returned `GhosttySurfaceHandle`.
  - [x] `LiveGhosttyAdapter.createInheritedSurface` passes parent context metadata through the wrapper.
  - [x] Adapter focus, resize, close, exit status, and destroy calls reach the wrapper runtime.
  - [x] Adapter initialization and surface failures still map to `GhosttyAdapterError`.
  - [x] Test fakes compile and capture native view access calls without requiring a real Ghostty surface.
- Integration tests:
  - [x] `AppDependencyContainer.live()` constructs a wrapper-backed `LiveGhosttyAdapter`.
  - [x] Scaffold tests still confirm one Ghostty app context per process through the live adapter.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- `LiveGhosttyAdapter` no longer owns app-facing runtime behavior directly through `CGhosttyRuntime`.
- The adapter exposes the lifecycle and native view hooks required for task 04.
