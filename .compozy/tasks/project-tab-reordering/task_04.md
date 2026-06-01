---
status: pending
title: "Mixed selected-session tab strip reorder interaction"
type: frontend
complexity: high
dependencies:
  - task_02
---

# Task 04: Mixed selected-session tab strip reorder interaction

## Overview
This task delivers tab reordering in the shipped tab surface rather than inventing a new one. It adds reorder interaction to the existing horizontal selected-session strip for both terminal and file tabs, while preserving mixed-tab semantics, selected-tab stability, and adjacent-tab navigation behavior.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST implement tab reordering in the existing horizontal `TabChromeView` / `TabItemView` surface.
2. MUST reorder all visible selected-session tabs together, including mixed terminal and file tabs.
3. MUST submit ordered visible tab IDs through `WorkspaceCommandService` and MUST NOT add a second tab-order source in the view layer.
4. MUST preserve selected-tab behavior and keep previous/next tab traversal aligned with reordered ordinals.
5. MUST NOT introduce a vertical tab surface, cross-session tab movement, or per-kind reorder rules in MVP.
6. MUST include relaunch and mixed-tab regression coverage for the reordered strip.
</requirements>

## Subtasks
- [ ] 4.1 Add drag/drop reorder interaction to the existing horizontal selected-session tab strip.
- [ ] 4.2 Keep terminal and file tabs under one visible ordering rule in the strip.
- [ ] 4.3 Connect drop completion to the tab reorder command path.
- [ ] 4.4 Preserve selected-tab state and adjacent-tab navigation semantics after reorder.
- [ ] 4.5 Add mixed-tab persistence and relaunch regressions plus lightweight manual smoke guidance.

## Implementation Details
Use the TechSpec sections **System Architecture → Tab strip reorder surface**, **Implementation Design → Data Models**, and **Technical Considerations → Key Decisions**. Stay inside the existing selected-session tab strip and interpret the PRD’s tab-order promise through the shipped surface rather than creating a new vertical experience.

### Relevant Files
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Defines `TabChromeView` and `TabItemView`, the only MVP tab-order UI surface.
- `Sources/NativeMacADE/NativeMacADEApp.swift` — Previous/next tab commands consume `workspaceStore.tabsForSelectedSession` and must stay aligned with reordered tab order.
- `Tests/NativeMacADECoreTests/WorkspaceStoreTests.swift` — Covers mixed terminal/file ordering and order-sensitive selection fallback.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — Command-level validation, snapshot regeneration, and selected-tab preservation coverage.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Mixed-tab persistence and relaunch coverage for selected-session reorder flows.
- `Tests/NativeMacADEIntegrationTests/RestoreCoordinatorIntegrationTests.swift` — Relaunch and degraded-restore coverage for mixed sessions.
- `Tests/NativeMacADEIntegrationTests/SQLiteWorkspaceMetadataStoreTests.swift` — Durable ordinal and transaction-safety coverage for reordered tabs.

### Dependent Files
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — `tabsForSelectedSession` is the canonical visible order that the UI renders.
- `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift` — Defines mixed tab kinds, ordinals, and snapshot order contracts.
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — UI submits reordered visible tab IDs through this command API.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Command handler owns validation, canonical ordering, and persistence.
- `Sources/NativeMacADECore/Persistence/WorkspacePersistenceStore.swift` — Tab reorder durability depends on batch tab-order save support.
- `Sources/NativeMacADECore/Persistence/SQLiteWorkspaceMetadataStore.swift` — Transaction-safe session ordinal writes are required for durable mixed-tab reorders.
- `Sources/NativeMacADECore/Restore/RestoreCoordinator.swift` — Relaunch order depends on snapshot-aligned restore behavior.

### Related ADRs
- [ADR-002: Dual-Surface MVP for Project and Tab Reordering](../adrs/adr-002.md) — Confirms tab ordering is part of the first release.
- [ADR-003: Command-Owned Reorder Operations for Projects and Tabs](../adrs/adr-003.md) — Requires the tab strip to call command-layer reorder APIs.
- [ADR-004: Canonicalize Order with Existing Fields and Atomic Batch Persistence](../adrs/adr-004.md) — Defines canonical `ordinal` ordering and derived snapshot updates.
- [ADR-005: Scope Tab Reordering to the Existing Session-Scoped Mixed Tab Strip](../adrs/adr-005.md) — Locks MVP to the current horizontal strip and mixed visible tabs.

## Deliverables
- Reorder interaction added to the existing selected-session horizontal tab strip.
- Mixed terminal/file visible tabs use one shared reorder rule.
- Selected-tab and previous/next-tab behavior remain aligned with reordered tab ordinals.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for mixed-tab reorder persistence and relaunch stability **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Reordering a mixed visible tab set produces the expected ordered visible tab ID payload for the command layer.
  - [ ] Reordering the currently selected tab keeps the same tab selected after the move completes.
  - [ ] Reordering tabs does not break adjacent-tab traversal order used by previous/next tab commands.
- Integration tests:
  - [ ] Reordering a session that contains both terminal and file tabs persists the mixed order across relaunch.
  - [ ] Reordering tabs after adding a file tab still restores the selected tab and visible order correctly.
  - [ ] First-to-last and last-to-first tab moves survive reload without ordinal drift.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Users can reorder visible selected-session tabs without adding a second tab surface.
- Mixed terminal/file tab order stays stable across relaunch and adjacent-tab navigation.
