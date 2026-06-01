---
status: pending
title: "Canonical reorder persistence APIs"
type: backend
complexity: high
dependencies: []
---

# Task 01: Canonical reorder persistence APIs

## Overview
This task establishes the persistence foundation for manual ordering. It extends the existing workspace persistence boundary so project order and selected-session tab order can be rewritten atomically, durably, and without introducing a second priority model.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST add batch persistence entry points for project-order and session-tab-order updates to `WorkspacePersistenceStore` and every conformer.
2. MUST keep `Project.sortIndex` and `WorkspaceTab.ordinal` as the canonical persisted order fields and MUST NOT introduce a new priority schema for MVP.
3. MUST persist tab reorders atomically with derived `RestoreSnapshot.tabOrder` updates so relaunch order cannot drift from runtime order.
4. MUST handle SQLite `UNIQUE(session_id, ordinal)` constraints safely for tab reorders.
5. MUST include Swift Testing unit and SQLite-backed integration coverage for dense rewrites, adjacent swaps, first/last moves, and rollback on failure.
</requirements>

## Subtasks
- [ ] 1.1 Add persistence protocol methods for canonical project-order saves and session-tab-order saves.
- [ ] 1.2 Update the in-memory persistence conformer so tests can exercise batch reorder semantics.
- [ ] 1.3 Implement atomic SQLite reorder writes for projects, tabs, and derived snapshot state.
- [ ] 1.4 Preserve dense, unique persisted ordering after every successful batch write.
- [ ] 1.5 Add unit and integration coverage for reorder persistence success and failure cases.

## Implementation Details
Modify the persistence boundary described in the TechSpec sections **System Architecture → Batch persistence path** and **Implementation Design → Storage strategy**. Keep the work scoped to canonical ordering fields and transaction-safe rewrites; do not introduce a separate priority model or schema concept.

### Relevant Files
- `Sources/NativeMacADECore/Persistence/WorkspacePersistenceStore.swift` — Defines the persistence protocol and the in-memory conformer that must grow batch reorder APIs.
- `Sources/NativeMacADECore/Persistence/SQLiteWorkspaceMetadataStore.swift` — Owns durable SQLite writes and must add atomic reorder persistence.
- `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift` — Defines `Project.sortIndex`, `WorkspaceTab.ordinal`, and `RestoreSnapshot.tabOrder`.
- `Sources/NativeMacADECore/Persistence/WorkspaceMigrations.swift` — Documents the existing schema constraints, including `UNIQUE(session_id, ordinal)`.
- `Tests/NativeMacADECoreTests/WorkspaceModelsTests.swift` — Existing home for in-memory persistence behavior that can cover new batch save semantics.
- `Tests/NativeMacADEIntegrationTests/SQLiteWorkspaceMetadataStoreTests.swift` — Primary integration surface for atomic reorder persistence and rollback behavior.

### Dependent Files
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — Future caller contract should align with the new persistence payloads.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Reorder orchestration will depend on these new atomic persistence methods.
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — Store ordering and snapshot helpers must remain compatible with dense persisted values.
- `Sources/NativeMacADECore/Restore/RestoreCoordinator.swift` — Restore behavior depends on persisted ordinals and derived snapshot alignment.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — Custom persistence test doubles here must match any protocol additions.
- `Tests/NativeMacADECoreTests/RestoreCoordinatorTests.swift` — Custom persistence mocks and restore-order expectations will need updated protocol support.

### Related ADRs
- [ADR-003: Command-Owned Reorder Operations for Projects and Tabs](../adrs/adr-003.md) — The persistence APIs are the backend contract consumed by command-owned reorder flows.
- [ADR-004: Canonicalize Order with Existing Fields and Atomic Batch Persistence](../adrs/adr-004.md) — Defines canonical order fields, dense normalization, and atomic persistence.
- [ADR-005: Scope Tab Reordering to the Existing Session-Scoped Mixed Tab Strip](../adrs/adr-005.md) — Constrains tab-order persistence to the selected session’s mixed strip.

## Deliverables
- Batch reorder persistence methods added to the workspace persistence protocol and all conformers.
- Atomic SQLite project-order and tab-order persistence paths with derived snapshot updates.
- Dense persisted ordering preserved for projects and selected-session tabs.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for reorder persistence and rollback behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Saving reordered project IDs rewrites `sortIndex` into a dense sequence starting at zero.
  - [ ] Saving reordered visible tab IDs rewrites session ordinals into a dense sequence while leaving hidden persisted tabs in a stable relative tail.
  - [ ] Saving tab order also updates `RestoreSnapshot.tabOrder` to match the canonical post-save order.
- Integration tests:
  - [ ] Adjacent tab swap in SQLite succeeds without triggering a `UNIQUE(session_id, ordinal)` failure.
  - [ ] Moving the first tab to the end and the last tab to the beginning persists correctly across reload.
  - [ ] A failed reorder transaction rolls back both row updates and snapshot changes.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Project-order and tab-order persistence complete atomically in durable storage.
- Relaunch reads back the same canonical order that was just saved.
