---
status: completed
title: "Integrate the right sidebar workspace and CodeEditorView into the app shell"
type: frontend
complexity: high
dependencies:
  - task_02
  - task_03
---

# Task 04: Integrate the right sidebar workspace and CodeEditorView into the app shell

## Overview
Integrate the approved file workspace experience into the app shell by adding the right-side working-set-first surface, repository tree, mixed tab chrome, and syntax-aware editor host. This task is the main user-facing slice: it converts the terminal-only detail pane into a mixed terminal/file workspace while keeping the left project/session sidebar intact.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST integrate the new file workspace inside the existing `WorkspaceDetailView` seam instead of introducing a second top-level shell model.
2. MUST render one shared session tab strip for terminal tabs and file tabs, with per-kind titles, icons, help text, and dirty-state cues.
3. MUST use `CodeEditorView` for syntax highlighting and direct editing only, deferring diagnostics, completion, and hover services in MVP.
4. SHOULD keep the terminal surface safe by ensuring terminal host paths only run for terminal tabs.
</requirements>

## Subtasks
- [x] 4.1 Add `CodeEditorView` and `LanguageSupport` to the app target and introduce a thin editor wrapper view for the file-tab host.
- [x] 4.2 Extend `WorkspaceDetailView` into a split detail layout with terminal content on one side and the file workspace surface on the other.
- [x] 4.3 Build the working-set-first sidebar and secondary repository tree using the selected project/session context.
- [x] 4.4 Update the shared tab chrome so file tabs and terminal tabs render correctly in one strip with accurate labels and close affordances.
- [x] 4.5 Wire the selected file tab to the editor host and keep terminal host creation restricted to terminal tabs.
- [x] 4.6 Add smoke-level coverage or testable state coverage for mixed-tab shell behavior and working-set rendering inputs.

## Implementation Details
Use the TechSpec sections "System Architecture", "Integration Points", and "Development Sequencing" as the implementation guide. Keep the UI split localized to the existing detail-pane seam and prefer thin wrapper views over leaking editor-library types into core modules.

### Relevant Files
- `Package.swift` — App-target dependency seam for `CodeEditorView` and `LanguageSupport`.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Current app shell, `WorkspaceDetailView`, tab chrome, and terminal-only surface path.
- `Sources/NativeMacADE/NativeMacADEApp.swift` — App-level scene and command wiring that will later expose save/revert/editor actions.
- `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift` — Shared mixed-tab metadata consumed by the app shell.
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — Current selected-tab and ordering model that the shell reads.
- `Sources/NativeMacADECore/App/AppDependencyContainer.swift` — Live DI seam for file runtime services required by the shell.
- `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift` — Existing host-wrapper pattern and terminal-only runtime that must remain isolated from file tabs.

### Dependent Files
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — UI actions depend on the file-tab command surface added earlier.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — UI selection, close, and open flows depend on mixed-tab-aware command branching.
- `Sources/NativeMacADECore/Restore/RestoreCoordinator.swift` — Relaunch UX and visible working-set state depend on mixed-tab restore results.
- `Tests/NativeMacADECoreTests/WorkspaceStoreTests.swift` — Core state coverage supports shell-level working-set derivation and mixed tab selection.

### Related ADRs
- [ADR-001: Scope tabbed-file-explorer as a session-aware working-set navigator](../adrs/adr-001.md) — Requires working-set-first navigation and a secondary repository tree.
- [ADR-002: Adopt a working-set-first quick-fix editor approach for the PRD](../adrs/adr-002.md) — Constrains the editor experience to syntax-aware quick-fix editing.
- [ADR-003: Extend the shared session tab model to support file tabs and terminal tabs](../adrs/adr-003.md) — Requires one shared tab strip across terminal and file work.
- [ADR-004: Use CodeEditorView for MVP syntax-aware editing with highlighting and editing only](../adrs/adr-004.md) — Constrains the editor integration scope.
- [ADR-005: Persist file-tab metadata only, with explicit save and no unsaved-buffer restore](../adrs/adr-005.md) — Drives visible dirty-state cues and restore expectations in the UI.

## Deliverables
- Updated app package dependencies for the editor surface.
- A split `WorkspaceDetailView` with terminal content, right-side file workspace, and shared mixed tab chrome.
- A thin `CodeEditorView` wrapper integrated into the selected file-tab host.
- Working-set-first sidebar and repository tree UI for the selected project/session.
- Coverage for mixed-tab shell behavior through testable core state or smoke-level integration checks.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for mixed-tab shell and editor-host flows **(REQUIRED)**

## Tests
- Unit tests:
  - [x] `WorkspaceStoreTests`: mixed tab activation order produces the expected working-set input for the right sidebar.
  - [x] `DefaultWorkspaceCommandServiceTests`: selecting a file tab updates the shared selected-tab state without triggering terminal-only side effects.
  - [x] Any new editor-wrapper state tests: a file tab maps to the expected language configuration and dirty-state presentation inputs.
- Integration tests:
  - [x] Build/smoke coverage: the app target compiles and links with `CodeEditorView` and `LanguageSupport` added to `Package.swift`.
  - [x] `DefaultWorkspaceCommandServiceIntegrationTests` or equivalent smoke path: opening a file tab results in shared tab selection plus editor-host rendering eligibility, while terminal tabs still render through `TerminalHostController`.
  - [x] `RestoreCoordinatorIntegrationTests`: a restored mixed session produces a usable selected file tab and does not recreate terminal surfaces for file tabs.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The app shell exposes a right-side working-set-first file workspace without replacing the existing left project/session sidebar.
- File tabs and terminal tabs share one visible tab strip with accurate per-kind labels and close affordances.
- `CodeEditorView` is integrated narrowly for highlighting and editing only, with terminal-host logic unchanged for terminal tabs.
