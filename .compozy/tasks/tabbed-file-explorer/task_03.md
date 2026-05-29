---
status: pending
title: "Add file runtime services for project-scoped access, buffers, and explicit save/revert"
type: backend
complexity: high
dependencies:
  - task_01
  - task_02
---

# Task 03: Add file runtime services for project-scoped access, buffers, and explicit save/revert

## Overview
Add the runtime-only services that make file tabs editable without turning `WorkspaceStore` into a buffer store. This task introduces project-scoped file access, live editor buffers, dirty state, explicit save/revert behavior, and the external-editor boundary that later UI and command wiring will use.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST keep live file buffers, editor positions, and dirty state outside `WorkspaceStore` and SQLite, using a runtime controller consistent with the TechSpec "System Architecture".
2. MUST validate file reads and writes against the selected project root and reject out-of-root or unsupported file access clearly.
3. MUST support explicit save and revert semantics, with dirty state cleared only after successful save or successful revert reload.
4. SHOULD provide an external-editor opener boundary without coupling file-editing logic directly to SwiftUI views.
</requirements>

## Subtasks
- [ ] 3.1 Add a project-scoped file-access boundary for enumerating, loading, saving, and validating files under the selected project root.
- [ ] 3.2 Add a runtime file-buffer controller for live editor text, saved text snapshots, dirty state, and per-tab buffer lifecycle.
- [ ] 3.3 Add command-service support for opening file tabs, saving buffers, reverting buffers, and preparing external-editor escalation.
- [ ] 3.4 Populate project bookmark data during project-open flow so restored file access has a stable project-level anchor.
- [ ] 3.5 Add unit and integration coverage for file loading, save/revert behavior, dirty state transitions, and root-path rejection.

## Implementation Details
Use the TechSpec sections "Implementation Design > Core Interfaces", "Data Models", and "Technical Considerations" as the source of truth for the runtime split. Keep these services inside the existing core target and avoid persisting unsaved buffers.

### Relevant Files
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — Needs the new file-tab command surface for open/save/revert/external-editor operations.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Orchestrates file open/save/revert flows and must avoid routing file IO through terminal-only logic.
- `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift` — Provides project bookmark data and the shared file-tab metadata contract.
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — Supplies tab activation/selection data used by working-set derivation and command orchestration.
- `Sources/NativeMacADECore/Restore/RestoreCoordinator.swift` — Existing metadata-only restore model that constrains runtime buffer persistence.
- `Sources/NativeMacADECore/App/AppDependencyContainer.swift` — Live DI seam for the file-access service, buffer controller, and external-editor opener.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Downstream UI consumer for dirty-close and editor-host behavior.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — Best unit seam for save/revert/dirty-state orchestration.

### Dependent Files
- `Sources/NativeMacADECore/Persistence/WorkspacePersistenceStore.swift` — Must remain metadata-only even as runtime services are added.
- `Sources/NativeMacADECore/Persistence/SQLiteWorkspaceMetadataStore.swift` — Stores bookmark data and file-tab metadata that runtime services rely on.
- `Sources/NativeMacADE/NativeMacADEApp.swift` — Later menu commands will invoke save/revert/external-editor operations introduced here.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Later UI work will bind the editor surface to the runtime buffer controller created here.
- `Tests/NativeMacADEIntegrationTests/RestoreCoordinatorIntegrationTests.swift` — Later restore coverage will depend on the explicit non-restoration of unsaved buffers.

### Related ADRs
- [ADR-002: Adopt a working-set-first quick-fix editor approach for the PRD](../adrs/adr-002.md) — Constrains MVP editing to quick-fix scope instead of full IDE parity.
- [ADR-004: Use CodeEditorView for MVP syntax-aware editing with highlighting and editing only](../adrs/adr-004.md) — Defines the narrow editor integration that these runtime services must support.
- [ADR-005: Persist file-tab metadata only, with explicit save and no unsaved-buffer restore](../adrs/adr-005.md) — Constrains dirty state, save behavior, and restore semantics.

## Deliverables
- A project-scoped file-access service for validated text load/save operations.
- A runtime file-buffer controller for live editor text, saved text snapshots, and dirty state.
- Command-service support for file open/save/revert/external-editor operations.
- Project bookmark-data population during project-open flow.
- Unit tests for file access, dirty state, explicit save, and revert behavior.
- Integration tests for metadata-only restore, bookmark persistence, and out-of-root rejection.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for file runtime and save/revert flows **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `DefaultWorkspaceCommandServiceTests`: opening a file inside the selected project creates a file tab and loads the initial buffer without altering terminal-tab semantics.
  - [ ] `DefaultWorkspaceCommandServiceTests`: attempting to open or save a file outside the project root returns a specific file-access rejection.
  - [ ] New file-buffer controller tests: editing marks the buffer dirty, successful save clears dirty state, and failed save preserves unsaved text.
  - [ ] New file-buffer controller tests: revert reloads saved disk contents and clears dirty state only when reload succeeds.
- Integration tests:
  - [ ] `DefaultWorkspaceCommandServiceIntegrationTests`: a file open → edit → save flow persists metadata and writes the saved contents to disk.
  - [ ] `SQLiteWorkspaceMetadataStoreTests`: project bookmark data persists and reloads alongside file-tab metadata.
  - [ ] `RestoreCoordinatorIntegrationTests`: relaunch restores file tabs from disk but does not restore unsaved buffer text.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- File buffers remain runtime-only and are not stored in workspace metadata.
- Save and revert behavior is explicit, project-scoped, and preserves user trust around unsaved changes.
- External-editor escalation can be invoked through a dedicated boundary without coupling file IO to views.
