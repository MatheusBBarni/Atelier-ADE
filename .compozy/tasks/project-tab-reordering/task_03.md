---
status: pending
title: "Project sidebar reorder interaction"
type: frontend
complexity: medium
dependencies:
  - task_02
---

# Task 03: Project sidebar reorder interaction

## Overview
This task delivers the visible project-ordering interaction in the existing sidebar. It lets users rearrange projects through the current workspace surface while keeping the UI thin, selection-safe, and consistent with the command-owned reorder model.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST implement project reordering only within the existing project sidebar surface.
2. MUST submit reordered project IDs through `WorkspaceCommandService` and MUST NOT mutate `WorkspaceStore` directly from the view layer.
3. MUST provide clear insertion feedback so users can predict where the moved project will land.
4. MUST preserve current sidebar selection and error-reporting conventions used in `ContentView.swift`.
5. MUST NOT expand scope into session reordering, favorites, grouping, or a new project-management surface.
6. MUST include verification that reordered project state remains stable across navigation and relaunch.
</requirements>

## Subtasks
- [ ] 3.1 Add project-row reorder interaction to the existing sidebar surface.
- [ ] 3.2 Show clear insertion and movement feedback during project drag/drop.
- [ ] 3.3 Connect the completed drop action to the project reorder command path.
- [ ] 3.4 Preserve current selection, error messaging, and sidebar readability after reordering.
- [ ] 3.5 Add regression coverage and a short manual smoke path for the user-visible interaction.

## Implementation Details
Use the TechSpec sections **System Architecture → Project sidebar reorder surface** and **User Experience** as the design boundary. Keep the feature inside the current `ContentView.swift` project sidebar, and reuse the existing async command invocation and user-message patterns instead of introducing a new view model or management surface unless required for testability.

### Relevant Files
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Defines `ProjectSidebarView` and `ProjectRowView`, the only MVP project-order UI surface.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — Command-level verification surface for project reorder outcomes triggered by the UI.
- `Tests/NativeMacADECoreTests/WorkspaceStoreTests.swift` — Store-order and selection invariants that the UI slice depends on.
- `Tests/NativeMacADEIntegrationTests/SQLiteWorkspaceMetadataStoreTests.swift` — Durable project-order reload coverage after reorder.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — End-to-end project reorder persistence and relaunch behavior.

### Dependent Files
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — UI must call the project reorder command instead of mutating local state directly.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Command handler owns validation, persistence, and runtime restoration.
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — Sidebar render order comes from the store’s canonical project ordering.
- `Sources/NativeMacADECore/Persistence/WorkspacePersistenceStore.swift` — Project reorder durability depends on batch persistence support.
- `Sources/NativeMacADECore/Persistence/SQLiteWorkspaceMetadataStore.swift` — Relaunch-visible order depends on durable project-order writes.
- `Sources/NativeMacADE/NativeMacADEApp.swift` — Cross-project session traversal follows `workspaceStore.projects` order and must stay coherent.

### Related ADRs
- [ADR-002: Dual-Surface MVP for Project and Tab Reordering](../adrs/adr-002.md) — Confirms projects must ship in the first release together with tabs.
- [ADR-003: Command-Owned Reorder Operations for Projects and Tabs](../adrs/adr-003.md) — Requires the UI to stay a thin shell that submits ordered IDs.
- [ADR-004: Canonicalize Order with Existing Fields and Atomic Batch Persistence](../adrs/adr-004.md) — Makes dense persisted `sortIndex` values the project-order source of truth.

## Deliverables
- Project drag/drop interaction added to the existing sidebar.
- Clear insertion feedback for project reordering.
- Command-backed reorder submission that preserves selection and error handling.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for project reorder persistence and relaunch stability **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] A project move from the bottom of the sidebar to the top yields the expected ordered project ID payload for the command layer.
  - [ ] Dropping a project back into its original position avoids changing canonical order.
  - [ ] Reordering a selected project keeps that project selected after the command completes.
- Integration tests:
  - [ ] After project reorder completes, reloading persisted workspace metadata returns the new project order.
  - [ ] After relaunch, the sidebar shows the same project order and selected project as before shutdown.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Users can reorder projects from the existing sidebar without introducing a new management surface.
- Project order remains visibly stable across navigation and relaunch.
