---
status: completed
title: "Replace TerminalHostController SwiftTerm hosting with Ghostty native surface hosting"
type: backend
complexity: critical
dependencies:
  - task_01
  - task_02
  - task_03
---

# Task 04: Replace TerminalHostController SwiftTerm hosting with Ghostty native surface hosting

## Overview
This task performs the core runtime swap inside `TerminalHostController`. It removes the SwiftTerm session-driver branch and makes terminal tabs attach, focus, resize, close, and release Ghostty native surfaces through the adapter path.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST make `TerminalHostController.createSurface(for:)` create Ghostty-backed surfaces for all terminal tabs.
2. MUST remove the `usesEmbeddedSessionDriver` production branch and stop using `LocalProcessTerminalView`.
3. MUST attach the Ghostty native view into `TerminalSurfaceHostNSView` and preserve host layout behavior.
4. MUST preserve focus, resize, close checks, exit monitoring, release, and appearance update behavior through the Ghostty adapter.
5. MUST keep `WorkspaceTerminalSurfaceManaging` unchanged so workspace orchestration stays stable.
</requirements>

## Subtasks
- [x] 4.1 Replace SwiftTerm session-driver creation with wrapper-backed Ghostty surface creation.
- [x] 4.2 Attach the Ghostty native view to `TerminalSurfaceHostNSView`.
- [x] 4.3 Preserve focus, resize, appearance, close, release, and exit behavior.
- [x] 4.4 Remove or isolate SwiftTerm-specific host state from the terminal host view.
- [x] 4.5 Update host integration tests from SwiftTerm expectations to Ghostty host expectations.
- [x] 4.6 Verify repeated view reuse and restored tab attachment remain stable.

## Implementation Details
Use the TechSpec "System Architecture", "Core Interfaces", and "Development Sequencing" sections. This task should not alter workspace persistence or add a terminal-engine selector; the runtime swap happens behind the existing terminal surface manager contract.

### Relevant Files
- `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift` — Primary file for removing SwiftTerm hosting and attaching Ghostty native surfaces.
- `Sources/NativeMacADECore/Ghostty/GhosttyAdapter.swift` — Adapter path used for surface lifecycle and native view access.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Hosts `TerminalHostView` and calls `TerminalHostController.createSurface(for:)` from SwiftUI.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Calls the unchanged terminal surface manager contract.
- `Tests/NativeMacADEIntegrationTests/TerminalHostIntegrationTests.swift` — Primary host lifecycle and AppKit integration coverage.

### Dependent Files
- `Sources/NativeMacADECore/App/AppDependencyContainer.swift` — Live app wiring must still provide the terminal host and adapter.
- `Sources/NativeMacADE/NativeMacADEApp.swift` — Zoom commands and app wiring depend on `TerminalHostController`.
- `Tests/NativeMacADEIntegrationTests/ScaffoldIntegrationTests.swift` — Existing live terminal host tests must stop expecting embedded SwiftTerm behavior.
- `Tests/NativeMacADEIntegrationTests/RestoreCoordinatorIntegrationTests.swift` — Restore diagnostics depend on terminal surface creation behavior.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Session and tab creation depend on stable terminal surface semantics.

### Related ADRs
- [ADR-003: Replace the SwiftTerm terminal path inside TerminalHostController with Ghostty surfaces](adrs/adr-003.md) — Defines the host-level migration approach.
- [ADR-004: Remove SwiftTerm after Ghostty covers the MVP terminal baseline](adrs/adr-004.md) — Constrains the task away from SwiftTerm fallback.
- [ADR-005: Add a Swift-native Ghostty wrapper target and keep CGhostty as native interop scaffolding](adrs/adr-005.md) — Defines the runtime boundary consumed by the host.

## Deliverables
- `TerminalHostController` creates and hosts Ghostty native terminal surfaces.
- `TerminalSurfaceHostNSView` attaches and lays out the Ghostty native view.
- SwiftTerm-specific live host behavior removed from the terminal host path.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Ghostty host surface lifecycle **(REQUIRED)**

## Tests
- Unit tests:
  - [x] `createSurface(for:)` creates exactly one Ghostty surface per terminal tab.
  - [x] `focus(tabID:)` delegates to the Ghostty adapter for the active surface.
  - [x] `resize(tabID:columns:rows:)` delegates correct dimensions to the Ghostty adapter.
  - [x] `canClose(surface:)` uses Ghostty runtime state rather than SwiftTerm process state.
  - [x] `releaseSurface(for:)` destroys the Ghostty surface and detaches the hosted native view.
- Integration tests:
  - [x] `TerminalHostView` attaches a non-placeholder Ghostty native view for a selected terminal tab.
  - [x] Reused host views drop stale tab mappings and attach the new tab's Ghostty surface.
  - [x] Existing theme and zoom updates continue to update the terminal host appearance contract.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Terminal tabs are Ghostty-backed through `TerminalHostController`.
- Workspace command and persistence layers do not require API changes.
