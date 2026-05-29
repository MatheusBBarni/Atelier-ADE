---
status: completed
title: "Build tab chrome and AppKit terminal host integration"
type: frontend
complexity: high
dependencies:
  - task_02
  - task_04
  - task_05
---

# Task 06: Build tab chrome and AppKit terminal host integration

## Overview
Implement the in-app terminal experience by connecting tab chrome to AppKit-hosted Ghostty surfaces. This task is where the ADE becomes a working terminal product: each visible tab gains a real terminal surface, the correct working directory, clear focus behavior, and the default Nord terminal appearance.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. MUST render tab chrome bound to workspace tab state and selected session context.
- 2. MUST host one embedded Ghostty surface per visible tab through dedicated AppKit host components.
- 3. MUST launch each new tab in the selected project's working directory and apply the default Nord terminal theme behavior.
- 4. MUST handle focus, resize, close requests, and process-exit callbacks on the main actor.
- 5. MUST respect Ghostty confirm-quit behavior before forcing a tab close.
</requirements>

## Subtasks
- [x] 6.1 Build the SwiftUI tab chrome and bind it to selected session/tab state.
- [x] 6.2 Implement the AppKit terminal host components that attach one Ghostty surface per visible tab.
- [x] 6.3 Connect tab creation and selection flows to working-directory launch behavior through the Ghostty adapter.
- [x] 6.4 Apply the Nord default terminal appearance and clear focus/active-state behavior in the terminal area.
- [x] 6.5 Add tests for Ghostty host lifecycle, tab behavior, and close/exit semantics.

## Implementation Details
Reference TechSpec "System Architecture > Terminal Host Layer" and "Integration Points" for the Ghostty boundary. Keep the tab experience inside the app-owned project -> session -> tab model and do not introduce external Ghostty coordination or multi-window orchestration in V1.

### Relevant Files
- `AnotherADE/Features/Tabs/TabBarView.swift` — Renders tab chrome and selection state.
- `AnotherADE/Features/Tabs/TabItemView.swift` — Displays tab title, active state, and close affordance.
- `AnotherADE/Terminal/Host/TerminalHostView.swift` — SwiftUI/AppKit bridge for embedding the terminal host.
- `AnotherADE/Terminal/Host/TerminalHostController.swift` — Owns AppKit terminal lifecycle, focus, sizing, and close requests.
- `AnotherADE/Terminal/Host/TerminalSurfaceCoordinator.swift` — Coordinates one Ghostty surface per visible tab.
- `AnotherADE/Terminal/Ghostty/GhosttyAdapter.swift` — Adapter entry point used for surface lifecycle and launch behavior.
- `AnotherADEIntegrationTests/TerminalHostIntegrationTests.swift` — Verifies terminal creation, focus, resize, exit, and close semantics.

### Dependent Files
- `AnotherADE/Restore/RestoreCoordinator.swift` — Task 07 will recreate tab surfaces using the host components defined here.
- `AnotherADE/Support/Observability/WorkspaceLogger.swift` — Task 08 will record terminal lifecycle and creation failures.
- `AnotherADE/Services/DefaultWorkspaceCommandService.swift` — Close/create flows from task 04 will be completed by the host lifecycle behavior in this task.
- `AnotherADE/Features/Sessions/SessionShortcutPicker.swift` — Task 08 will feed shortcut-based launch profiles into this terminal path.

### Related ADRs
- [ADR-004: Embed Full libghostty Surfaces Inside the App](adrs/adr-004.md) — Primary terminal integration decision for this task.
- [ADR-003: Use a SwiftUI App Shell with AppKit Terminal Hosting](adrs/adr-003.md) — Defines the SwiftUI/AppKit split this task must honor.
- [ADR-005: Persist Metadata-Only State and Restore Fresh Shells](adrs/adr-005.md) — Keeps tab lifecycle compatible with fresh-shell restore semantics.
- [ADR-001: Session-First Native macOS ADE Scope for V1](adrs/adr-001.md) — Ensures tabs remain subordinate to project and session context.

## Deliverables
- SwiftUI tab chrome bound to workspace state.
- AppKit terminal host components that embed one Ghostty surface per visible tab.
- Working-directory tab launch behavior and default Nord terminal appearance.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for Ghostty host lifecycle and tab behavior **(REQUIRED)**.

## Tests
- Unit tests:
  - [x] Creating a tab requests the selected project working directory from the command/service boundary.
  - [x] Closing a tab with a live terminal process honors confirm-quit before force close.
  - [x] Tab selection updates the visible active tab state without losing the selected session context.
- Integration tests:
  - [x] A new tab creates exactly one Ghostty surface with the selected project's working directory.
  - [x] Resizing or focusing the terminal host propagates the expected lifecycle hooks to the Ghostty adapter.
  - [x] Terminal process exit updates the workspace state and leaves the remaining tabs stable.
  - [x] The default Nord terminal appearance is applied when a terminal surface is created.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Each visible tab owns a working embedded Ghostty surface launched in the correct project context.
- Tab creation, selection, focus, and close behavior feel native and remain inside the ADE window model.
