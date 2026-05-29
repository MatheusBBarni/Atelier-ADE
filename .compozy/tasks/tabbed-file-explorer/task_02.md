---
status: pending
title: "Make store, command, and restore flows file-tab aware"
type: backend
complexity: high
dependencies:
  - task_01
---

# Task 02: Make store, command, and restore flows file-tab aware

## Overview
Make the existing shared session workflow understand file tabs as first-class tabs alongside terminal tabs. This task updates selection, ordering, restore, and close logic so the backend can branch by tab kind while preserving current terminal behavior and without yet introducing live editor buffers.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST keep one shared session-scoped tab namespace for terminal tabs and file tabs, including selection, ordering, activation timestamps, and restore ordering.
2. MUST prevent file tabs from being treated as terminal surfaces during create, restore, close, remove-project, and remove-session flows.
3. MUST extend command and restore behavior so mixed-tab sessions recover predictably and produce diagnostics for invalid restored file tabs.
4. SHOULD preserve current terminal semantics as the default path when a tab is still terminal-backed.
</requirements>

## Subtasks
- [ ] 2.1 Extend `WorkspaceStore` helpers and selection logic so mixed terminal/file tabs remain coherent within one session.
- [ ] 2.2 Update `WorkspaceCommandService` and `DefaultWorkspaceCommandService` to expose and branch on file-tab behavior without creating file buffers yet.
- [ ] 2.3 Update restore assembly and restore replay so file tabs reuse the existing snapshot order but bypass terminal surface recreation.
- [ ] 2.4 Add per-kind close and destructive-action protections for file tabs versus terminal tabs.
- [ ] 2.5 Expand store, command-service, and restore tests for mixed tab ordering, close branching, and restore diagnostics.

## Implementation Details
This task is the shared backend seam for mixed-tab behavior. Use the TechSpec sections "System Architecture", "Implementation Design > API Endpoints", and "Development Sequencing" to keep store, command, and restore logic aligned with ADR-003 and ADR-005.

### Relevant Files
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — Owns tab ordering, selection normalization, activation recency, and snapshot generation.
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — Public command surface and error model that must become file-tab aware.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Main branching point for tab creation, restore replay, close flow, and destructive actions.
- `Sources/NativeMacADECore/Restore/RestoreCoordinator.swift` — Restore ordering and diagnostics seam for missing or unreadable restored file tabs.
- `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift` — Consumed tab-kind/file-reference shape from task 01.
- `Tests/NativeMacADECoreTests/WorkspaceStoreTests.swift` — Best unit seam for mixed-tab ordering and selection rules.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — Best unit seam for close/remove/selection branching by tab kind.
- `Tests/NativeMacADECoreTests/RestoreCoordinatorTests.swift` — Best unit seam for restore ordering and file-tab diagnostics.
- `Tests/NativeMacADEIntegrationTests/RestoreCoordinatorIntegrationTests.swift` — Integration seam for mixed-tab relaunch recovery.

### Dependent Files
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Later UI work depends on file-tab aware selection, close semantics, and restore behavior.
- `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift` — Must remain terminal-only and should only receive terminal tabs after this task.
- `Sources/NativeMacADECore/App/AppDependencyContainer.swift` — Later tasks will inject file runtime services into the command/restore paths introduced here.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Later end-to-end coverage will depend on the new mixed-tab command behavior.

### Related ADRs
- [ADR-003: Extend the shared session tab model to support file tabs and terminal tabs](../adrs/adr-003.md) — Requires one shared tab strip and one selection/restore model.
- [ADR-005: Persist file-tab metadata only, with explicit save and no unsaved-buffer restore](../adrs/adr-005.md) — Shapes restore and close behavior for file tabs.

## Deliverables
- File-tab aware store helpers for mixed tab ordering, selection, and snapshot handling.
- Extended command-service contract and implementation for mixed terminal/file tab behavior.
- Restore logic that can replay mixed tabs without trying to create terminal surfaces for file tabs.
- Unit tests for close branching, selection updates, and mixed-tab store behavior.
- Integration tests for mixed restore ordering and degraded restore diagnostics.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for mixed-tab command and restore flows **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `WorkspaceStoreTests`: selecting and activating mixed terminal/file tabs preserves one session-scoped tab order and one selected tab ID.
  - [ ] `DefaultWorkspaceCommandServiceTests`: restoring a mixed session recreates terminal surfaces only for terminal tabs.
  - [ ] `DefaultWorkspaceCommandServiceTests`: closing a file tab follows file-specific rejection rules while terminal close behavior stays unchanged.
  - [ ] `DefaultWorkspaceCommandServiceTests`: removing a session or project with mixed tabs branches correctly by tab kind instead of assuming every tab is terminal-backed.
- Integration tests:
  - [ ] `RestoreCoordinatorIntegrationTests`: a relaunched mixed session restores tab order and selection while skipping unreadable file tabs with diagnostics.
  - [ ] `DefaultWorkspaceCommandServiceIntegrationTests`: mixed tab metadata persists through selection changes, close actions, and restore snapshot updates.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Mixed terminal/file tabs share one session-scoped ordering and selection model.
- File tabs no longer trigger terminal surface recreation during restore or close flows.
- Restore diagnostics remain trustworthy when restored file tabs cannot be reopened.
