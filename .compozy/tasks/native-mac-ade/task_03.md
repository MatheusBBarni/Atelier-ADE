---
status: pending
title: "Implement workspace domain models and SQLite metadata store"
type: backend
complexity: high
dependencies:
  - task_01
---

# Task 03: Implement workspace domain models and SQLite metadata store

## Overview
Implement the domain entities and metadata-only SQLite persistence that anchor the project -> session -> tab model. This task creates the stored state needed for navigation, relaunch restore, ordering, and optional session shortcuts without drifting into live shell persistence.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. MUST implement the `Project`, `Session`, `Tab`, `SessionShortcut`, and `RestoreSnapshot` entities defined in the TechSpec.
- 2. MUST create explicit SQLite schema ownership for `projects`, `sessions`, `tabs`, `session_shortcuts`, and `restore_snapshot`.
- 3. MUST persist metadata only and exclude shell scrollback, live PTY/session reattachment, checkpoints, and global workspace abstractions.
- 4. MUST keep secrets out of SQLite and allow only indirect secret references for future shortcut needs.
- 5. SHOULD preserve ordering, recency, and optional bookmark data fields needed by later restore and UI flows.
</requirements>

## Subtasks
- [ ] 3.1 Add the core workspace entity definitions required by the TechSpec.
- [ ] 3.2 Create the SQLite schema and migration/bootstrap logic for V1 metadata tables.
- [ ] 3.3 Implement repository or store operations for project, session, tab, shortcut, and restore-snapshot metadata.
- [ ] 3.4 Add serialization and mapping coverage for ordering, recency, and restore snapshot behavior.
- [ ] 3.5 Add persistence tests that exercise metadata-only storage rules and deliberate exclusions.

## Implementation Details
Follow TechSpec "Implementation Design > Data Models" and "Storage Structures" exactly. This task establishes the data contract that the store, command service, restore flow, and session shortcuts depend on, so keep the schema narrow and aligned with ADR-005.

### Relevant Files
- `AnotherADE/Workspace/Project.swift` — Canonical project metadata model.
- `AnotherADE/Workspace/Session.swift` — Project-scoped session metadata, naming, and recency.
- `AnotherADE/Workspace/Tab.swift` — Per-tab relaunch metadata and ordering.
- `AnotherADE/Workspace/SessionShortcut.swift` — Lightweight shortcut metadata model.
- `AnotherADE/Workspace/RestoreSnapshot.swift` — Active workspace restore metadata.
- `AnotherADE/Persistence/SQLiteWorkspaceMetadataStore.swift` — Repository/store boundary for metadata CRUD and queries.
- `AnotherADE/Persistence/WorkspaceMigrations.swift` — SQLite schema bootstrap and migration ownership.

### Dependent Files
- `AnotherADE/Workspace/WorkspaceStore.swift` — Task 04 will consume these entities as in-memory state.
- `AnotherADE/Services/DefaultWorkspaceCommandService.swift` — Task 04 will coordinate mutations through this persistence layer.
- `AnotherADE/Features/Sessions/SessionListView.swift` — Task 05 will display session names, recency, and ordering from this metadata.
- `AnotherADE/Restore/RestoreCoordinator.swift` — Task 07 will rebuild the workspace from persisted restore snapshots.
- `AnotherADE/Support/Observability/WorkspaceLogger.swift` — Task 08 will record persistence-related pilot diagnostics.

### Related ADRs
- [ADR-005: Persist Metadata-Only State and Restore Fresh Shells](adrs/adr-005.md) — Primary persistence and restore constraint for this task.
- [ADR-001: Session-First Native macOS ADE Scope for V1](adrs/adr-001.md) — Locks the data model to the project -> session -> tab spine.
- [ADR-002: Adopt a Workflow-Speed-First PRD for V1](adrs/adr-002.md) — Keeps metadata scoped to fast workflow restoration rather than deep history.

## Deliverables
- Domain entity definitions for projects, sessions, tabs, session shortcuts, and restore snapshots.
- SQLite schema/bootstrap ownership for all V1 metadata tables.
- Metadata CRUD/query operations that later services can consume.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for persistence schema and restore-query behavior **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Default session naming stores `MM-DD HH:mm` values and flips `isUserNamed` only after rename.
  - [ ] Tab metadata preserves session ownership, working directory, ordinal, and relaunch launch fields.
  - [ ] Restore snapshot serialization preserves selected project/session/tab IDs and tab ordering.
- Integration tests:
  - [ ] SQLite bootstrap creates exactly the `projects`, `sessions`, `tabs`, `session_shortcuts`, and `restore_snapshot` tables.
  - [ ] Replacing the active restore snapshot overwrites prior snapshot data without duplicating active rows.
  - [ ] Loading persisted metadata for an existing project/session/tab graph returns the expected ordering and recency fields.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The app has an explicit metadata-only persistence layer aligned with the TechSpec and ADR-005.
- Later tasks can build UI, command flows, and restore behavior without inventing new storage concepts.
