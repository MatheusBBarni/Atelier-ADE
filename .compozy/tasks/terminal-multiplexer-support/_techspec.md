# Focus Workspace Continuity for Multiplexer-Heavy Workflows

## Executive Summary

This implementation extends the existing Focus Workspace architecture instead of introducing a new multiplexer subsystem. The design keeps continuity inside the current app-owned boundaries: preferences, restore metadata, selection logic, and existing SwiftUI presentation surfaces. MVP adds one new child preference under Focus Workspace, applies a restore-only terminal-first selection rule for opted-in users, and reuses current correction surfaces rather than adding a new command or pane-aware runtime model.

The primary technical trade-off is deliberate: the system will no longer treat literal last-tab selection as the only restore truth for opted-in continuity sessions. Instead, it keeps persisted snapshot state truthful to actual UI selection, then applies a terminal-first restore override at restore time when continuity is enabled. That keeps persistence simple and honest, but it requires precise restore-path logic and explicit UI cues so the override remains understandable.

## System Architecture

### Component Overview

**1. Preferences and settings layer**
- `AppPreferences` remains the persisted settings root.
- Add `focusWorkspaceContinuityEnabled` as a child preference under `focusWorkspaceEnabled`.
- `ConfigModalFocusWorkspaceSection` remains the only MVP configuration surface.
- `FocusWorkspacePresentation.swift` remains the source of truth for settings copy and active cues.

**2. Restore selection layer**
- Add a small pure Core component, tentatively `FocusWorkspaceContinuityRestoreSelector`, under `NativeMacADECore/Workspace/`.
- Responsibility: derive the restore-time `WorkspaceSelection` for continuity-enabled sessions.
- Boundary: restore only; it must not change general in-session selection heuristics.

**3. Restore orchestration layer**
- `DefaultWorkspaceCommandService.restoreWorkspace()` remains the public restore entry point.
- `RestoreCoordinator` continues to load projects, sessions, tabs, and raw snapshot metadata.
- After coordinator restore succeeds, the command service applies the continuity selector before the live store is restored and terminal or file surfaces are recreated.

**4. Persistence layer**
- `WorkspacePersistenceStore` remains unchanged as the protocol boundary.
- `SQLiteWorkspaceMetadataStore` and `WorkspaceMigrations` gain one new preferences column and migration.
- `RestoreSnapshot` remains unchanged for MVP.

**5. Presentation and correction layer**
- Existing active focus cues, settings copy, session rows, and session search remain the correction and trust surfaces.
- No new top-level command, palette, or dashboard is added.

### Data Flow

**Settings path**
1. User toggles Focus Workspace Continuity inside the existing Focus Workspace settings section.
2. `saveAppPreferences(_:)` normalizes the parent-child preference invariant.
3. Preferences persist through the existing app-preferences record.
4. The store updates and existing Focus Workspace presentation surfaces react.

**Startup or restore path**
1. `AppShellStartupCoordinator.run` loads preferences before restore.
2. `DefaultWorkspaceCommandService.restoreWorkspace()` calls `RestoreCoordinator.restoreWorkspace()` to rebuild metadata state.
3. The continuity selector evaluates restored sessions and tabs using existing snapshot and recency fields.
4. If continuity is enabled, it produces a terminal-first `WorkspaceSelection` for the restored session.
5. The command service applies that selection to the live store, recreates fresh terminal surfaces, and reloads file buffers.
6. Existing cues and correction surfaces explain or recover from any mismatch.

## Implementation Design

### Core Interfaces

Conceptual contract for the new restore-only selector:

```go
type ContinuityConfig struct {
    FocusWorkspaceEnabled   bool
    ContinuityEnabled       bool
}

type RestoreTargetSelector interface {
    Resolve(snapshot RestoreSnapshot, sessions []WorkspaceSession, tabs []WorkspaceTab, cfg ContinuityConfig) WorkspaceSelection
}
```

Planned Swift mapping:
- Implement as a pure Core type near `WorkspaceStore` and `FocusWorkspacePolicy`, but keep it separate from `FocusWorkspacePolicy` because it governs restore targeting rather than tab-creation guardrails.
- Preferred signature shape: selector consumes restored metadata plus `AppPreferences` and returns one `WorkspaceSelection`.
- Error handling: selector does not throw. It falls back to the raw snapshot selection or existing restore selection when continuity is disabled or no eligible terminal tab exists.

The public `WorkspaceCommandService` surface stays unchanged:
- `loadAppPreferences()`
- `saveAppPreferences(_:)`
- `restoreWorkspace()`

### Data Models

**Modified model: `AppPreferences`**
- Add `focusWorkspaceContinuityEnabled: Bool`
- Default value: `false`
- Invariant: if `focusWorkspaceEnabled == false`, then `focusWorkspaceContinuityEnabled` must be persisted and loaded as `false`

**Unchanged model: `RestoreSnapshot`**
- Keep `selectedProjectID`, `selectedSessionID`, `selectedTabID`, and `tabOrder` unchanged
- Continue treating snapshot state as the literal last known UI selection, not as a synthetic continuity target

**Unchanged model: `WorkspaceTab`**
- Reuse `kind`, `workingDirectory`, `shortcutID`, `launchCommand`, `launchArgumentsJSON`, and `lastActivatedAt`
- Use `lastActivatedAt` as the terminal-first tiebreaker inside the restored selected session

**Persistence shape**
- Add one new `app_preferences.focus_workspace_continuity_enabled INTEGER NOT NULL DEFAULT 0 CHECK (...)` column
- Bump `WorkspaceMigrations.currentUserVersion` from `6` to `7`
- Add a repair helper mirroring the existing app-preferences repair pattern so stale rows without the new column are normalized safely
- Do not add new tables or new restore-snapshot columns in MVP

### API Endpoints

No external network endpoints are added.

Internal service API impact:

| Surface | Change | Notes |
| --- | --- | --- |
| `WorkspaceCommandService.restoreWorkspace()` | unchanged public signature | Continuity selection is applied inside the existing restore flow |
| `WorkspaceCommandService.saveAppPreferences(_:)` | unchanged public signature | Normalizes the parent-child preference invariant before persistence |
| `WorkspaceCommandService.loadAppPreferences()` | unchanged public signature | Repairs impossible continuity states during normalized load if needed |

## Integration Points

No external service integration is required.

This feature stays inside:
- local SQLite metadata persistence
- in-process restore orchestration
- existing SwiftUI settings and workspace surfaces

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
|-----------|-------------|---------------------|-----------------|
| `AppPreferences.swift` | modified | Adds a second Focus Workspace preference; medium risk because it introduces a parent-child invariant | Add field, default, and normalization expectations |
| `WorkspaceMigrations.swift` | modified | Schema version bump and new column; medium risk due to migration correctness | Add V7 migration and repair helper |
| `SQLiteWorkspaceMetadataStore.swift` | modified | Preferences load and save queries gain one new field; medium risk if old rows or test fixtures drift | Update SQL read/write paths and persistence tests |
| `DefaultWorkspaceCommandService.swift` | modified | Restore flow and settings-save path gain continuity logic; medium risk to startup and restore semantics | Apply selector at restore boundary and normalize settings invariant |
| `RestoreCoordinator.swift` | unchanged or lightly touched | Raw metadata restore should stay truthful and generic; low risk if left unchanged | Keep coordinator focused on metadata restore unless a tiny helper seam is required |
| `FocusWorkspacePresentation.swift` | modified | Settings and active cue copy must explain the child toggle and terminal-first behavior; low risk | Add continuity-specific copy and help text |
| `ConfigModalFocusWorkspaceSection.swift` | modified | UI adds a child toggle and dependency behavior; low risk | Render child toggle, disable or clear it when parent is off |
| Existing correction surfaces (`ContentView.swift`, session search, session rows) | unchanged or lightly modified | MVP reuses them; low risk | Add only minor cue text if required |
| `RestoreCoordinatorTests` / integration tests | modified | Coverage must prove terminal-first restore, preference invariants, and migration safety; medium risk | Add unit and integration scenarios |

## Testing Approach

### Unit Tests

**Primary targets**
- Continuity selector behavior
- Preference invariant normalization
- Migration repair for the new preference column

**Recommended placement**
- Extend `RestoreCoordinatorTests.swift` or add a tightly adjacent selector-focused test file if the restore tests become too large
- Extend `SQLiteWorkspaceMetadataStoreTests.swift` for load/save and migration coverage
- Extend `AppShellStateTests.swift` only if startup ordering assertions need stronger continuity-specific expectations

**Critical unit scenarios**
- continuity disabled -> raw snapshot selection is preserved
- continuity enabled + session has terminal and file tab -> last active terminal wins
- continuity enabled + no eligible terminal -> fallback to raw snapshot selection
- parent off + child on in incoming preferences -> normalized to parent off + child off
- existing rows without the new column -> migration and repair yield `false`

### Integration Tests

**Primary targets**
- Restore pipeline from persisted metadata into live store
- Relaunch truthfulness when the last selected tab was a file tab but continuity prefers terminal
- Settings persistence and reload of the child toggle
- Focus Workspace behavior remaining unchanged for non-opted-in users

**Recommended files**
- `RestoreCoordinatorIntegrationTests.swift`
- `DefaultWorkspaceCommandServiceIntegrationTests.swift`
- `FocusWorkspaceUIContractIntegrationTests.swift`
- `SQLiteWorkspaceMetadataStoreTests.swift`

**Critical integration scenarios**
- opt-in user relaunches with terminal + file tab in one session and lands on the most recent terminal tab
- opt-in user relaunches when the selected session has no valid terminal tab and falls back cleanly
- disabling Focus Workspace automatically disables continuity in persisted preferences
- legacy multi-tab sessions restore exactly as today when continuity is not active
- terminal surfaces are recreated from launch intent after continuity selection without implying live process reattachment

## Development Sequencing

### Build Order

1. Extend `AppPreferences`, SQLite schema, and persistence load/save for `focusWorkspaceContinuityEnabled` - no dependencies.
2. Add parent-child preference normalization in `loadNormalizedAppPreferences` and `saveAppPreferences(_:)` - depends on step 1.
3. Implement the pure continuity restore selector in Core using existing snapshot and `lastActivatedAt` fields - depends on step 1.
4. Wire the selector into `DefaultWorkspaceCommandService.restoreWorkspace()` so the live store receives the continuity-adjusted `WorkspaceSelection` before surface recreation - depends on steps 2 and 3.
5. Update `FocusWorkspacePresentation` and `ConfigModalFocusWorkspaceSection` for the child toggle, help text, and continuity cue copy - depends on steps 1 and 2.
6. Add unit and integration coverage for migrations, preference invariants, restore target resolution, and opt-in or opt-out behavior - depends on steps 1 through 5.

### Technical Dependencies

- `WorkspaceMigrations` must advance cleanly to V7 before persistence tests can pass.
- Settings copy and the parent-child toggle behavior must be stable enough for UI contract assertions.
- No external infrastructure or service dependency exists for MVP.

## Monitoring and Observability

**Metrics to track**
- continuity toggle enabled or disabled events
- count of restores where continuity selection was applied
- count of restores that fell back to raw snapshot selection
- count of restores where the selected file tab was bypassed for a more recent terminal target
- corrective navigation immediately after restore for opted-in users

**Structured log fields**
- `focus_workspace_enabled`
- `focus_workspace_continuity_enabled`
- `selected_project_id_present`
- `selected_session_id_present`
- `raw_selected_tab_kind`
- `resolved_restore_tab_kind`
- `continuity_resolution` (`applied`, `fallback_snapshot`, `disabled`, `no_terminal_candidate`)
- `session_terminal_count`

**Alerting and escalation**
- No new pager or hard alert is required for MVP.
- Investigate post-launch if restore failures, continuity fallbacks, or corrective-switch behavior regress materially for opted-in users.
- Treat migration or preference-repair failures as release blockers in test and pre-release validation.

## Technical Considerations

### Key Decisions

- **Decision:** Add continuity as a child preference under Focus Workspace.  
  **Rationale:** Matches the approved product model while preserving current Focus Workspace behavior.  
  **Trade-offs:** Requires a migration and invariant handling.  
  **Alternatives rejected:** reusing the existing boolean only; creating a separate top-level mode.

- **Decision:** Apply terminal-first logic only at restore time.  
  **Rationale:** Keeps the feature aligned to the restore-first PRD and limits regression risk.  
  **Trade-offs:** Restore behavior becomes slightly less literal than raw snapshot state for opted-in users.  
  **Alternatives rejected:** global selection-heuristic changes; dedicated continuity-target persistence.

- **Decision:** Keep the public command surface unchanged.  
  **Rationale:** MVP does not need a new command or public service method because existing correction surfaces already exist.  
  **Trade-offs:** Power users do not get a new active return shortcut in Phase 1.  
  **Alternatives rejected:** dedicated return-to-focus commands; read-only continuity query APIs.

### Known Risks

- **Risk:** The child toggle can drift into an invalid persisted state.  
  **Mitigation:** Normalize on load and save in Core, not only in SwiftUI.

- **Risk:** Terminal-first restore may surprise users who last focused a file tab.  
  **Mitigation:** Keep the override scoped to opted-in continuity users and explain it in settings and active cues.

- **Risk:** Restore logic may fragment across the coordinator, command service, and store.  
  **Mitigation:** Keep one pure selector and apply it in one restore boundary inside the command service.

- **Risk:** A later need for richer continuity metadata could appear after launch.  
  **Mitigation:** Preserve truthful snapshot semantics now and revisit persistence only if integration tests or production evidence show the current fields are insufficient.

## Architecture Decision Records

- [ADR-001: Scope V1 as Focus Workspace continuity for multiplexer-heavy workflows](adrs/adr-001.md) — Sets the overall product boundary around app-owned continuity instead of true multiplexer integration.
- [ADR-002: Use a restore-first product approach for Focus Workspace continuity](adrs/adr-002.md) — Chooses smarter restore landing as the primary MVP strategy for increasing adoption.
- [ADR-003: Model continuity as a Focus Workspace sub-toggle](adrs/adr-003.md) — Adds continuity as a child preference under Focus Workspace with a persisted parent-child invariant.
- [ADR-004: Resolve continuity at restore time with terminal-first selection and truthful snapshot persistence](adrs/adr-004.md) — Keeps snapshot persistence literal while applying terminal-first selection only inside the restore path.
