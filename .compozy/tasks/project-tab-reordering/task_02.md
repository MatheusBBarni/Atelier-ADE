---
status: pending
title: "Reorder command orchestration and snapshot alignment"
type: backend
complexity: high
dependencies:
  - task_01
---

# Task 02: Reorder command orchestration and snapshot alignment

## Overview
This task makes reorder behavior an authoritative workspace command instead of a view-local mutation. It adds command-level validation, selection preservation, hidden-tab handling, and snapshot regeneration so manual ordering stays coherent across runtime state, persistence, and restore.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST add explicit `reorderProjects` and `reorderTabs` command entry points to `WorkspaceCommandService`.
2. MUST validate ordered ID payloads for completeness, uniqueness, and scope before mutating runtime or persisted state.
3. MUST preserve current project or tab selection when the reordered item set still contains the selected identifier.
4. MUST treat `RestoreSnapshot.tabOrder` as derived state regenerated from canonical order after each successful tab reorder.
5. MUST handle persisted-but-not-visible tabs by appending them after reordered visible tabs while preserving their relative order.
6. MUST include unit and integration coverage for invalid payload rejection, snapshot regeneration, selection preservation, and reorder after degraded restore.
</requirements>

## Subtasks
- [ ] 2.1 Extend the command surface with project and tab reorder operations.
- [ ] 2.2 Add command-layer validation for malformed, duplicate, incomplete, or out-of-scope reorder payloads.
- [ ] 2.3 Normalize canonical order and preserve selection before persisting changes.
- [ ] 2.4 Regenerate derived snapshot order after successful tab reorders.
- [ ] 2.5 Add command/store tests for invalid payloads, hidden persisted tabs, and stable selection behavior.

## Implementation Details
Implement this task using the TechSpec sections **System Architecture → Command-layer reorder boundary**, **Implementation Design → API Endpoints**, and **Technical Considerations → Key Decisions**. Keep the command layer as the only owner of reorder semantics; SwiftUI surfaces should only submit ordered identifiers.

### Relevant Files
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — Public command contract that must expose reorder entry points.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Main orchestration layer for validation, normalization, persistence, and snapshot updates.
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — Existing ordering, selection, and snapshot helpers that must stay coherent after reorder.
- `Sources/NativeMacADECore/Restore/RestoreCoordinator.swift` — Degraded-restore behavior and hidden-tab semantics must remain compatible with command-owned reorders.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — Primary unit-test surface for reorder orchestration behavior.
- `Tests/NativeMacADECoreTests/WorkspaceStoreTests.swift` — Best place to verify dense ordering and unchanged selection semantics.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — End-to-end command + SQLite + restore coverage for reorder flows.
- `Tests/NativeMacADEIntegrationTests/RestoreCoordinatorIntegrationTests.swift` — Relauch and filtered-restore integration coverage for hidden-tab handling.

### Dependent Files
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Sidebar and tab-strip UI will call the new reorder commands.
- `Sources/NativeMacADE/NativeMacADEApp.swift` — Adjacent-tab navigation behavior depends on command-generated tab order.
- `Sources/NativeMacADECore/Workspace/FileWorkspacePresentation.swift` — Any file-working-set ordering derived from tab ordinals must stay aligned.
- `Sources/NativeMacADECore/Persistence/WorkspacePersistenceStore.swift` — Command orchestration depends on the batch persistence APIs introduced by task 01.
- `Sources/NativeMacADECore/Persistence/SQLiteWorkspaceMetadataStore.swift` — Command flows depend on atomic writes and derived snapshot persistence.

### Related ADRs
- [ADR-003: Command-Owned Reorder Operations for Projects and Tabs](../adrs/adr-003.md) — Makes the command layer the single mutation owner for reorder flows.
- [ADR-004: Canonicalize Order with Existing Fields and Atomic Batch Persistence](../adrs/adr-004.md) — Requires canonical order fields and derived snapshot regeneration.
- [ADR-005: Scope Tab Reordering to the Existing Session-Scoped Mixed Tab Strip](../adrs/adr-005.md) — Constrains command behavior to selected-session mixed tabs.

## Deliverables
- Reorder command APIs added to the command service contract.
- Command-layer orchestration for project reorder and selected-session mixed-tab reorder.
- Snapshot regeneration and hidden persisted-tab handling aligned with canonical order.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for command + persistence + restore alignment **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `reorderProjects` rejects duplicate or missing project IDs instead of mutating state.
  - [ ] `reorderTabs` rejects visible-tab payloads that include out-of-session or unknown tab IDs.
  - [ ] Reordering projects or tabs preserves the selected ID when it still exists after the move.
  - [ ] Successful tab reorder regenerates `RestoreSnapshot.tabOrder` from canonical post-reorder state.
  - [ ] Reorder after degraded restore appends hidden persisted tabs after the visible reordered set without changing hidden relative order.
- Integration tests:
  - [ ] Reordering tabs in a mixed terminal/file session persists the new order and reloads it correctly after relaunch.
  - [ ] Reordering projects persists the new sidebar order and keeps selection stable after restore.
  - [ ] Reordering after a filtered restore keeps visible order deterministic and snapshot-aligned on the next launch.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Reorder commands become the only authoritative mutation path for manual ordering.
- Snapshot order and canonical persisted order stay aligned after reorder and relaunch.
