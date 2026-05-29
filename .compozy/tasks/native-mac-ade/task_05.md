---
status: pending
title: "Build project sidebar, session management UI, and default Nord shell theme"
type: frontend
complexity: high
dependencies:
  - task_01
  - task_04
---

# Task 05: Build project sidebar, session management UI, and default Nord shell theme

## Overview
Implement the first major user-facing workflow shell: the persistent project sidebar, project-scoped session management, and the default Nord visual theme for the macOS app chrome. This task turns the workspace state model into the fast, calm navigation experience promised by the PRD.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. MUST implement a persistent project sidebar that supports open, select, remove, and reselect flows.
- 2. MUST implement project-scoped session listing and actions for create, select, resume, and rename.
- 3. MUST keep active project and active session visually obvious and keyboard-friendly at all times.
- 4. MUST apply Nord as the default app-shell theme for sidebar, session views, and surrounding chrome.
- 5. SHOULD provide clear empty, loading, and no-project-selected states that do not hide the workflow model.
</requirements>

## Subtasks
- [ ] 5.1 Build the root SwiftUI workspace shell that places the project sidebar beside session-focused content.
- [ ] 5.2 Implement project sidebar UI for selecting, opening, and removing projects.
- [ ] 5.3 Implement the project-scoped session list with create, select, and rename flows.
- [ ] 5.4 Apply the Nord theme tokens to the app shell and make active-state cues explicit.
- [ ] 5.5 Add tests that verify selection, session rename, default naming visibility, and theme defaults.

## Implementation Details
Use TechSpec "User Experience" and "System Architecture > Component Overview" to keep SwiftUI responsible for navigation and visible workspace state. Apply the user's Nord-theme request here as the default app shell theme, while leaving terminal launch/theme integration to task 06.

### Relevant Files
- `AnotherADE/Features/Workspace/WorkspaceRootView.swift` — Hosts the sidebar, session area, and empty-state routing.
- `AnotherADE/Features/Projects/ProjectSidebarView.swift` — Primary navigation surface for persisted projects.
- `AnotherADE/Features/Projects/ProjectRowView.swift` — Encodes active project state and row-level project actions.
- `AnotherADE/Features/Sessions/SessionListView.swift` — Displays project-scoped sessions and recency ordering.
- `AnotherADE/Features/Sessions/SessionRenameView.swift` — Supports explicit rename flow for user-named sessions.
- `AnotherADE/Theme/NordTheme.swift` — Centralizes default shell theme tokens for the app chrome.
- `AnotherADETests/WorkspaceSidebarAndSessionViewTests.swift` — Covers selection, rename, default titles, and theme defaults.

### Dependent Files
- `AnotherADE/Features/Tabs/TabBarView.swift` — Task 06 will extend this shell with tab chrome bound to the same active context.
- `AnotherADE/Terminal/Ghostty/GhosttyLaunchConfig.swift` — Task 06 will apply the Nord default to terminal startup behavior.
- `AnotherADE/Restore/RestoreCoordinator.swift` — Task 07 will restore project/session selection into the UI built here.
- `AnotherADE/Support/Observability/WorkspaceLogger.swift` — Task 08 will log project and session actions initiated from these views.

### Related ADRs
- [ADR-002: Adopt a Workflow-Speed-First PRD for V1](adrs/adr-002.md) — Makes the persistent sidebar and fast project flow the primary product wedge.
- [ADR-003: Use a SwiftUI App Shell with AppKit Terminal Hosting](adrs/adr-003.md) — Keeps sidebar and session management in SwiftUI.
- [ADR-001: Session-First Native macOS ADE Scope for V1](adrs/adr-001.md) — Preserves project-scoped sessions and explicit active context.
- [ADR-005: Persist Metadata-Only State and Restore Fresh Shells](adrs/adr-005.md) — Ensures the UI does not imply deeper session persistence than V1 provides.

## Deliverables
- Root workspace shell, persistent project sidebar, and project-scoped session management UI.
- Default Nord theme for the app shell and visible active-state styling.
- Keyboard-friendly and visually explicit active project/session behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for sidebar/session interaction flows **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Selecting a project updates the active project highlight and exposes only that project's sessions.
  - [ ] Creating a new session from the selected project displays the default timestamp-based title.
  - [ ] Renaming a session updates the visible title while preserving project ownership and ordering.
  - [ ] Nord theme tokens are the default values used by the workspace shell and sidebar rows.
- Integration tests:
  - [ ] Opening a project from the sidebar adds it to the persistent project list and selects it immediately.
  - [ ] Removing a project from the sidebar clears dependent selection state without crashing the workspace shell.
  - [ ] Restored selection state reopens the same project and session in the UI after relaunch reconstruction.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Users can manage projects and sessions from a persistent SwiftUI shell with explicit active context.
- Nord is the default shell theme and appears consistently across the app chrome introduced in V1.
