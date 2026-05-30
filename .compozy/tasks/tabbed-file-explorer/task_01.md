---
status: completed
title: "Generalize workspace tabs and migrate persistence for mixed tab kinds"
type: backend
complexity: high
dependencies: []
---

# Task 01: Generalize workspace tabs and migrate persistence for mixed tab kinds

## Overview
Generalize the shared workspace tab model so terminal tabs and file tabs can coexist without introducing a second persistence pipeline. This task establishes the durable metadata contract for the rest of the feature by extending `WorkspaceTab`, shipping the SQLite v2 migration, and preserving backward compatibility for existing terminal-only workspaces.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST extend the shared `WorkspaceTab` metadata so terminal tabs and file tabs can be represented in one session-scoped tab namespace.
2. MUST implement a real SQLite migration path from schema v1 to schema v2 without losing existing project, session, terminal tab, or restore metadata.
3. MUST keep terminal defaults backward-compatible so existing constructors, persistence rows, and restore snapshots remain valid until later tasks add file-tab behavior.
4. SHOULD avoid creating a second tab table or parallel persistence model; see TechSpec "Data Models" and ADR-003.
</requirements>

## Subtasks
- [x] 1.1 Add tab-kind and file-reference metadata to the shared workspace tab model with terminal-safe defaults.
- [x] 1.2 Introduce schema v2 changes for mixed tab persistence and implement versioned migration logic instead of bootstrap-only setup.
- [x] 1.3 Update SQLite and in-memory persistence implementations to load and save mixed terminal/file tab metadata.
- [x] 1.4 Preserve restore snapshot compatibility so mixed tabs still reuse the existing selected-tab and ordered-tab model.
- [x] 1.5 Extend model and persistence tests to cover migration, round-trip loading, and mixed-tab ordering compatibility.

## Implementation Details
Update the shared tab metadata and persistence seams first so later tasks can rely on a stable mixed-tab contract. Follow the TechSpec sections "System Architecture", "Implementation Design > Data Models", and "Development Sequencing" for the v2 migration and shared-tab rules.

### Relevant Files
- `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift` — Primary model seam for `WorkspaceTab`, tab kind, file metadata, and restore compatibility.
- `Sources/NativeMacADECore/Persistence/WorkspaceMigrations.swift` — Current schema/bootstrap path that must become real versioned migration logic.
- `Sources/NativeMacADECore/Persistence/SQLiteWorkspaceMetadataStore.swift` — SQLite tab load/save and activation transaction logic for mixed-tab persistence.
- `Sources/NativeMacADECore/Persistence/WorkspacePersistenceStore.swift` — Persistence protocol and in-memory implementation that must stay in sync with the new tab shape.
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — Snapshot ordering and session tab helpers that rely on the shared tab model.
- `Tests/NativeMacADECoreTests/WorkspaceModelsTests.swift` — Best unit-test seam for new tab-kind and file-reference serialization behavior.
- `Tests/NativeMacADEIntegrationTests/SQLiteWorkspaceMetadataStoreTests.swift` — Best integration seam for migration and mixed-tab round-trip coverage.

### Dependent Files
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Later tasks will consume the new tab metadata in create, restore, and close flows.
- `Sources/NativeMacADECore/Restore/RestoreCoordinator.swift` — Restore ordering and diagnostics will depend on the persisted mixed-tab shape.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — UI consumers will later branch on tab kind for mixed tab chrome and surfaces.
- `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift` — Must remain terminal-only despite the generalized tab model.

### Related ADRs
- [ADR-003: Extend the shared session tab model to support file tabs and terminal tabs](../adrs/adr-003.md) — Defines the single shared tab namespace this task must preserve.
- [ADR-005: Persist file-tab metadata only, with explicit save and no unsaved-buffer restore](../adrs/adr-005.md) — Constrains persistence to durable file metadata only.

## Deliverables
- Updated shared workspace tab model with tab kind and file metadata.
- SQLite schema v2 migration path with backward-compatible restoration of existing terminal-only state.
- Updated SQLite and in-memory persistence implementations for mixed tabs.
- Unit tests covering model serialization and snapshot compatibility.
- Integration tests covering v1→v2 migration and mixed-tab persistence round-trips.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for mixed-tab persistence and migration **(REQUIRED)**

## Tests
- Unit tests:
  - [x] `WorkspaceModelsTests`: a terminal tab without file metadata still round-trips with default tab kind.
  - [x] `WorkspaceModelsTests`: a file tab preserves its file path/reference fields when encoded and decoded.
  - [x] `WorkspaceStoreTests`: mixed terminal/file tab snapshots preserve ordered tab IDs without introducing a second namespace.
- Integration tests:
  - [x] `SQLiteWorkspaceMetadataStoreTests`: a schema v1 database migrates to v2 without losing existing projects, sessions, terminal tabs, or restore snapshot data.
  - [x] `SQLiteWorkspaceMetadataStoreTests`: saving and reloading a mixed terminal/file tab session preserves tab kind, file path, ordinal, and activation timestamps.
  - [x] `SQLiteWorkspaceMetadataStoreTests`: invalid stored mixed-tab values fail with a descriptive persistence error instead of silently corrupting restore state.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Existing terminal-only workspaces load successfully after the schema change.
- Mixed tab metadata persists and restores through one shared `tabs` table.
- No new persistence path is introduced outside the existing workspace metadata store.
