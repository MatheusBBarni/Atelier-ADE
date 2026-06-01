# Project and Tab Reordering TechSpec

## Executive Summary

This specification implements the PRD sections **Core Features**, **User Experience**, and **Success Metrics** by extending Another ADE’s existing workspace architecture instead of introducing a new priority system or navigation surface. Project reordering will be added to the current left sidebar, tab reordering will be added to the current horizontal selected-session tab strip, and both operations will be routed through `WorkspaceCommandService` so one layer owns validation, persistence, and restore-safe state updates.

The primary technical trade-off is deliberate: reuse the current `Project.sortIndex`, `Tab.ordinal`, and `RestoreSnapshot.tabOrder` model to keep the MVP small and coherent, even though that forces two bespoke drag/drop UI paths and stricter transactional persistence logic in the command and SQLite layers. This avoids new schema concepts and new top-level UI surfaces, but it requires careful normalization and atomic writes so user-defined order remains authoritative after relaunch, restore, and degraded restore cases.

## System Architecture

### Component Overview

1. **Project sidebar reorder surface**  
   `ProjectSidebarView` in `Sources/NativeMacADE/AppShell/ContentView.swift` remains the only project-order UI surface. It gains drag/drop interaction state and visual insertion feedback, but it does not own mutation or persistence logic. This component maps directly to the PRD feature **Persistent project reordering**.

2. **Tab strip reorder surface**  
   `TabChromeView` and `TabItemView` remain the only MVP tab-order UI surface. The implementation uses the existing horizontal selected-session strip rather than adding a vertical list. Terminal and file tabs continue to share one visible ordering rule. This component maps to the PRD feature **Persistent tab reordering**.

3. **Command-layer reorder boundary**  
   `WorkspaceCommandService` and `DefaultWorkspaceCommandService` become the authoritative owner for reorder operations. The UI produces ordered identifier lists after a drop, and the command layer validates them, computes canonical dense order, persists them immediately, refreshes snapshot state, and restores the updated store into runtime memory. This component maps to the PRD features **Restore-safe custom ordering**, **Consistent ordering rules across surfaces**, and **Fast recovery from mistakes**.

4. **Canonical workspace ordering state**  
   Existing workspace models remain authoritative. Project order continues to live in `Project.sortIndex`. Session tab order continues to live in `Tab.ordinal`. `RestoreSnapshot.tabOrder` remains persisted, but only as derived state regenerated from canonical store order after each successful tab reorder. No separate priority model is introduced.

5. **Batch persistence path**  
   `WorkspacePersistenceStore`, `InMemoryWorkspacePersistenceStore`, and `SQLiteWorkspaceMetadataStore` gain explicit batch reorder operations. These paths must rewrite all affected project or session-tab rows in one transaction, update the restore snapshot in the same write, and avoid transient `UNIQUE(session_id, ordinal)` violations for tabs.

6. **Restore compatibility boundary**  
   `RestoreCoordinator` remains the owner of degraded restore behavior when projects or file tabs are inaccessible. The reorder design assumes visible runtime order is authoritative for the current session, while persisted-but-not-visible tabs keep relative order and are appended after reordered visible tabs if a later reorder occurs.

### Data Flow

- The user drags a project row or tab item inside an existing surface.
- The UI computes the resulting ordered IDs for that surface and calls a reorder command.
- The command layer validates membership, scope, and completeness of the ordered IDs against current workspace state.
- The command layer builds a normalized ordering plan, persists all affected rows atomically, regenerates snapshot order, and restores the updated store state.
- The store publishes updated project or tab order back to the existing views.
- On relaunch or restore, the persisted canonical order and derived snapshot reproduce the same visible order.

## Implementation Design

### Core Interfaces

Code examples use Swift because the codebase is Swift-based.

```swift
@MainActor
public protocol WorkspaceCommandService {
    func reorderProjects(_ orderedProjectIDs: [UUID]) async throws
    func reorderTabs(sessionID: UUID, orderedVisibleTabIDs: [UUID]) async throws
}
```

```swift
public struct SessionTabReorderPlan: Sendable {
    public var sessionID: UUID
    public var visibleTabIDs: [UUID]
    public var hiddenPersistedTabIDs: [UUID]
}
```

```swift
public protocol WorkspacePersistenceStore: Sendable {
    func saveProjectOrder(_ orderedProjectIDs: [UUID]) async throws
    func saveTabOrder(
        _ plan: SessionTabReorderPlan,
        snapshot: RestoreSnapshot
    ) async throws
}
```

### Data Models

#### Persistent models

- **`Project`**
  - Continue using `sortIndex: Int` as the canonical project-order field.
  - Reorder commands will rewrite `sortIndex` into a dense, unique sequence starting at zero.
  - No new project columns are required.

- **`WorkspaceTab`**
  - Continue using `ordinal: Int` as the canonical session-tab order field.
  - Reorder commands will rewrite ordinals into a dense, unique sequence within the selected session.
  - Terminal and file tabs stay in the same ordinal namespace.
  - No new tab columns are required.

- **`RestoreSnapshot`**
  - Continue storing selected IDs plus `tabOrder: [UUID]`.
  - Treat `tabOrder` as derived from the post-reorder store state.
  - Regenerate snapshot order immediately after every successful tab reorder.

#### New runtime and command DTOs

- **`SessionTabReorderPlan`**
  - `sessionID: UUID`
  - `visibleTabIDs: [UUID]`
  - `hiddenPersistedTabIDs: [UUID]`
  - Purpose: carry the canonical visible order plus any persisted-but-not-visible tail that must remain stable.

- **`ProjectOrderUpdate`**
  - `orderedProjectIDs: [UUID]`
  - Purpose: narrow payload for sidebar reorder commands and persistence writes.

#### Storage strategy

- Reuse the existing `projects.sort_index` and `tabs.ordinal` columns.
- Do not add a separate priority table or metadata field set.
- Add batch persistence methods so reorder writes happen atomically instead of row by row.
- Preserve hidden persisted tab metadata by appending it after reordered visible tabs, keeping relative order stable.
- Keep `RestoreSnapshot` in sync with canonical order at the end of each reorder command.

### API Endpoints

No HTTP or RPC endpoints are introduced.

The MVP extends the in-process command surface instead:

| Operation | Input | Result | Notes |
| --- | --- | --- | --- |
| `reorderProjects` | ordered project IDs | none | Rejects missing or duplicate IDs; rewrites dense `sortIndex` values and persists immediately |
| `reorderTabs` | `sessionID`, ordered visible tab IDs | none | Validates scope against selected-session tabs, rebuilds dense ordinals, updates derived snapshot, and persists atomically |

Error handling continues through `WorkspaceCommandError`, with new failure paths folded into existing validation and persistence failure cases rather than introducing a second error system.

## Integration Points

No new external services or third-party runtime integrations are introduced for MVP.

The design stays within the existing app shell, command layer, workspace store, restore flow, and SQLite persistence boundary.

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
|-----------|-------------|---------------------|-----------------|
| `Sources/NativeMacADE/AppShell/ContentView.swift` | modified | Add drag/drop state and visual insertion feedback to two custom surfaces; medium risk | Extend `ProjectSidebarView`, `TabChromeView`, and supporting row views |
| `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` | modified | Add explicit reorder commands; low risk | Extend the protocol with project and tab reorder entry points |
| `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` | modified | New validation, normalization, immediate persistence, and snapshot regeneration; high risk | Implement authoritative reorder flows |
| `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` | modified | Add helpers for canonical ordering, selection preservation, and snapshot generation reuse; medium risk | Keep current state model authoritative without adding a new ordering system |
| `Sources/NativeMacADECore/Persistence/WorkspacePersistenceStore.swift` | modified | Add batch reorder persistence APIs; medium risk | Extend protocol and in-memory test implementation |
| `Sources/NativeMacADECore/Persistence/SQLiteWorkspaceMetadataStore.swift` | modified | Must persist full ordered sets atomically while respecting `UNIQUE(session_id, ordinal)`; high risk | Add transaction-based reorder writes for projects and tabs |
| `Sources/NativeMacADECore/Restore/RestoreCoordinator.swift` | modified | May need minor alignment for reorder-safe hidden-tab handling after degraded restore; medium risk | Keep restore-compatible ordering semantics explicit |
| `Tests/NativeMacADECoreTests` and `Tests/NativeMacADEIntegrationTests` | modified/new | Coverage must prove stability across command, SQLite, and restore flows; medium risk | Add reorder-focused unit and integration cases |

## Testing Approach

### Unit Tests

- Extend `DefaultWorkspaceCommandServiceTests` for:
  - valid project reorder
  - valid mixed-tab reorder in one selected session
  - rejection of incomplete, duplicate, or out-of-scope ordered ID lists
  - selection preservation after reorder
  - immediate snapshot regeneration after tab reorder
- Extend `WorkspaceStoreTests` for:
  - dense `sortIndex` normalization
  - dense per-session ordinal normalization
  - stable ordering when recency would previously break ties
  - unchanged selection semantics after reorder
- Extend the in-memory persistence store tests for batch order save behavior.

### Integration Tests

- Add SQLite integration coverage for:
  - adjacent tab swap without uniqueness violations
  - first-to-last and last-to-first moves
  - project reorder persistence across relaunch
  - mixed terminal/file tab reorder persistence across relaunch
  - reorder immediately after degraded restore with hidden persisted tabs
- Extend restore integration coverage for:
  - snapshot alignment after reorder
  - filtered file-tab restore followed by successful visible-tab reorder
- Keep UI automation light in MVP. Add only smoke-level interaction tests if needed to verify drag affordances are wired, not as the primary confidence mechanism.

## Development Sequencing

### Build Order

1. Add reorder command declarations and narrow ordering DTOs — no dependencies.
2. Add batch reorder persistence APIs to `WorkspacePersistenceStore` and its in-memory implementation — depends on step 1.
3. Implement SQLite transactional project-order persistence and tab-order persistence with snapshot writes — depends on steps 1 and 2.
4. Implement reorder normalization and validation in `DefaultWorkspaceCommandService` — depends on steps 1 through 3.
5. Add `WorkspaceStore` helpers for canonical order rebuilding and selection-preserving state restoration — depends on step 4.
6. Wire project sidebar drag/drop interactions to `reorderProjects` — depends on steps 4 and 5.
7. Wire tab strip drag/drop interactions to `reorderTabs` in the existing horizontal strip — depends on steps 4 and 5.
8. Add reorder-focused unit and integration coverage, including degraded-restore cases — depends on steps 2 through 7.
9. Add monitoring, pilot diagnostics, and light UI smoke coverage if still needed after core tests pass — depends on steps 6 through 8.

### Technical Dependencies

- No new package dependencies are required.
- The shared mixed-tab model introduced by the existing file-tab work must remain the authoritative selected-session tab surface.
- SQLite reorder writes must use transactions to avoid temporary uniqueness conflicts.
- The current restore snapshot generation path must remain callable from reorder flows without requiring a new persistence model.

## Monitoring and Observability

- **Key metrics to track**
  - project reorder count
  - tab reorder count
  - reorder persistence failure count
  - reorder validation rejection count
  - restore-order mismatch count in pilot diagnostics
- **Structured log events**
  - `project_reordered`
  - `tab_reordered`
  - `reorder_validation_failed`
  - `reorder_persistence_failed`
  - `reorder_restore_alignment_failed`
- **Thresholds / release gates**
  - any reproducible tab-order persistence failure in pilot builds is release-blocking
  - any restore mismatch between saved order and reopened visible order should be treated as release-blocking
  - validation failures should trend toward zero outside intentional negative-test scenarios

## Technical Considerations

### Key Decisions

- **Existing surfaces only**: use the current project sidebar and horizontal selected-session tab strip instead of adding a new vertical tab surface.
- **Command-owned mutations**: keep reorder behavior in `WorkspaceCommandService` so UI surfaces remain thin and durable state changes stay centralized.
- **Existing fields as source of truth**: reuse `sortIndex`, `ordinal`, and derived snapshot order instead of introducing a new priority model.
- **Mixed visible session tabs**: reorder terminal and file tabs together because the current strip is already one ordered session surface.
- **Immediate durability**: persist on drop, not on later activation or graceful exit.

### Known Risks

- **SQLite ordinal conflict risk**: row-by-row tab saves can violate `UNIQUE(session_id, ordinal)`.  
  Mitigation: persist the full affected session order in one transaction.
- **Hidden persisted tab risk**: degraded restore can leave persisted metadata for tabs not present in the live store.  
  Mitigation: append hidden persisted tabs after reordered visible tabs while preserving their relative order.
- **Surface asymmetry risk**: project reorder and tab reorder live in different UI geometries and cannot share one list primitive.  
  Mitigation: share command and persistence rules while keeping UI interaction code surface-specific.
- **Expectation mismatch risk**: earlier wording may imply a vertical tab experience that MVP will not ship.  
  Mitigation: keep product copy and task breakdown aligned to the current horizontal strip.
- **Trust regression risk**: any drift between runtime order, persisted order, and restore order will make the feature feel unreliable immediately.  
  Mitigation: treat snapshot regeneration and relaunch verification as part of the core implementation, not follow-up polish.

## Architecture Decision Records

- [ADR-001: Projects-First Reordering Scope for V1](adrs/adr-001.md) — Captures the earlier product-stage caution that project ordering was structurally cleaner than tab ordering.
- [ADR-002: Dual-Surface MVP for Project and Tab Reordering](adrs/adr-002.md) — Commits the PRD to shipping project and tab ordering together in a tight first release.
- [ADR-003: Command-Owned Reorder Operations for Projects and Tabs](adrs/adr-003.md) — Places reorder ownership in `WorkspaceCommandService` and keeps views as thin interaction shells.
- [ADR-004: Canonicalize Order with Existing Fields and Atomic Batch Persistence](adrs/adr-004.md) — Reuses `sortIndex`, `ordinal`, and derived snapshot order with transaction-based persistence rather than a new priority model.
- [ADR-005: Scope Tab Reordering to the Existing Session-Scoped Mixed Tab Strip](adrs/adr-005.md) — Implements tab reordering in the current horizontal selected-session strip for both terminal and file tabs.
