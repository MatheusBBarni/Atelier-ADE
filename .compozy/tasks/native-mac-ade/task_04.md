---
status: pending
title: "Implement workspace store and command services"
type: backend
complexity: high
dependencies:
  - task_03
---

# Task 04: Implement workspace store and command services

## Overview
Implement the in-memory workspace source of truth and the command boundary that mutates it. This task turns persisted project/session/tab metadata into a usable application state model and provides the core action surface every UI and terminal flow depends on.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. MUST implement an observable `WorkspaceStore` as the in-memory source of truth for opened projects, sessions, tabs, and selected context.
- 2. MUST implement the in-process command boundary for `OpenProject`, `CreateSession`, `RenameSession`, `CreateTab`, `RestoreWorkspace`, and `CloseTab`.
- 3. MUST preserve the project -> session -> tab model and prevent duplicate project entries or orphaned tab metadata on failure.
- 4. MUST enforce default session naming, rename semantics, and selected-project inheritance for new tabs.
- 5. SHOULD expose typed validation and lifecycle errors that later UI can surface clearly.
</requirements>

## Subtasks
- [ ] 4.1 Add workspace state structures for opened projects, selected context, sessions, and tabs.
- [ ] 4.2 Implement the store update rules for selection, recency, and tab/session membership.
- [ ] 4.3 Implement the default command service for project open, session create/rename, tab create/close, and restore invocation.
- [ ] 4.4 Add typed command and validation errors for invalid project, session, tab, and terminal lifecycle states.
- [ ] 4.5 Add tests that verify state transitions, duplicate handling, and failure rollback behavior.

## Implementation Details
Reference TechSpec "Core Interfaces" and "System Architecture > Component Overview" for the command boundary and store responsibilities. This task should stay narrow: local command services, no event bus, no external API, and no background orchestration abstractions.

### Relevant Files
- `AnotherADE/Workspace/WorkspaceStore.swift` — Observable state container for projects, sessions, tabs, and selection.
- `AnotherADE/Workspace/WorkspaceSelection.swift` — Explicit selected project/session/tab state and transition helpers.
- `AnotherADE/Services/WorkspaceCommandService.swift` — Command contract referenced by later UI and terminal flows.
- `AnotherADE/Services/DefaultWorkspaceCommandService.swift` — Concrete coordination of persistence, store mutation, and terminal actions.
- `AnotherADE/Services/WorkspaceCommandError.swift` — Typed failures for validation, restore, and terminal creation issues.
- `AnotherADE/App/DependencyContainer.swift` — Wires the store and command service into the app shell.
- `AnotherADETests/WorkspaceCommandServiceTests.swift` — Verifies command ordering, rollback, and state transitions.

### Dependent Files
- `AnotherADE/Features/Projects/ProjectSidebarView.swift` — Task 05 will bind project selection and open/remove actions to this command boundary.
- `AnotherADE/Features/Sessions/SessionListView.swift` — Task 05 will use store-published session state and rename/create commands.
- `AnotherADE/Terminal/Host/TerminalHostController.swift` — Task 06 will send close and exit callbacks back through this boundary.
- `AnotherADE/Restore/RestoreCoordinator.swift` — Task 07 will drive `RestoreWorkspace()` through the services defined here.
- `AnotherADE/Support/Observability/WorkspaceLogger.swift` — Task 08 will log project/session/tab lifecycle events emitted from these flows.

### Related ADRs
- [ADR-003: Use a SwiftUI App Shell with AppKit Terminal Hosting](adrs/adr-003.md) — Establishes local command services and lightweight stores as the core architecture.
- [ADR-005: Persist Metadata-Only State and Restore Fresh Shells](adrs/adr-005.md) — Constrains the restore and persistence semantics that this service layer coordinates.
- [ADR-001: Session-First Native macOS ADE Scope for V1](adrs/adr-001.md) — Keeps state ownership aligned to project -> session -> tab.
- [ADR-004: Embed Full libghostty Surfaces Inside the App](adrs/adr-004.md) — Later terminal host work depends on this service layer to orchestrate surface lifecycle.

## Deliverables
- Observable workspace state types and store implementation.
- The default command-service implementation for all V1 project/session/tab actions.
- Typed command errors and failure-handling rules for later UI surfaces.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for state/persistence/service interaction **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Opening an already-known project reselects the existing project instead of duplicating it.
  - [ ] Creating a session assigns a default timestamp title and links it to the selected project.
  - [ ] Renaming a session updates the title and flips `isUserNamed` to true.
  - [ ] Creating a tab inherits the current project/session context and updates selection state.
- Integration tests:
  - [ ] A failed tab creation request leaves persistence and in-memory tab state unchanged.
  - [ ] Restoring a saved project/session/tab graph reconstructs the same selected context in the store.
  - [ ] Closing the last tab in a session updates store state without leaving stale selected-tab references.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The app has a single local command boundary and store that all later UI and terminal work can share.
- Project, session, and tab state transitions are deterministic and failure-safe.
