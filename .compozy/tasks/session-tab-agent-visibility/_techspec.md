# Session Tab Agent Visibility TechSpec

## Executive Summary

This TechSpec implements the PRD’s **Focused Inline Navigator** by extending the existing AppShell sidebar rather than introducing a new core monitoring subsystem. The design reuses current `WorkspaceTab` identity and recency metadata, existing `WorkspaceStore` tab ordering and selection, existing `WorkspaceCommandService.selectTab(id:)`, and `TerminalHostController` exit callbacks. New work stays intentionally small: a shared AppShell presentation resolver, a session-row summary builder, and a lightweight terminal-exit observer source near `AppDependencyContainer`.

The primary technical trade-off is **minimal surface area versus richer runtime truth**. Keeping summary composition in AppShell avoids new persistence, new core summary abstractions, and a timer-based status loop. In return, V1 status remains strictly factual and limited to what the app can already prove: tab identity, selection, absolute recency, and observed terminal exit. This matches the PRD’s trust boundary and keeps the first slice reversible.

## System Architecture

### Component Overview

**1. SessionTerminalPresentationResolver — new, AppShell-local**  
Responsibility:
- Resolve the user-facing identity for terminal tabs
- Normalize title, agent label, icon key, and fallback behavior
- Remove duplicated terminal identity logic from current tab UI

Boundary:
- Pure presentation logic only
- No persistence, no direct UI rendering, no background refresh

**2. SessionTerminalSummaryBuilder — new, AppShell-local**  
Responsibility:
- Build terminal-only child rows for one session
- Merge `WorkspaceStore` tab data, shortcut catalog lookup, and exit snapshots
- Produce ordered, render-ready summaries for `SessionRowView`

Boundary:
- Consumes current store state and cached lookup data
- Does not mutate core state

**3. ProjectSidebarView and SessionRowView — modified**  
Responsibility:
- Load and cache the current shortcut catalog
- Subscribe to terminal-exit events
- Render inline terminal child rows only when a session is expanded
- Invoke direct tab selection from child-row taps

Boundary:
- UI ownership only
- No new domain behavior beyond rendering and user actions

**4. TerminalExitEventSource — new, lightweight observer near AppDependencyContainer**  
Responsibility:
- Fan out `TerminalHostController.onSurfaceExited` to both existing logging and new AppShell listeners
- Maintain an ephemeral snapshot of observed terminal exits for current-process lifetime

Boundary:
- No persistence
- No inference of running, idle, blocked, or stale states

**5. Existing core components reused without role expansion**  
- `WorkspaceStore`: source of session, tab, selection, and ordering state
- `WorkspaceCommandService`: source of shortcut catalog and direct tab selection
- `TerminalHostController`: source of factual exit events only
- `DefaultWorkspaceCommandService.recordTerminalProcessExit`: keeps existing logging and metrics behavior intact

### Data Flow

1. `ProjectSidebarView` loads the current session shortcut catalog through `WorkspaceCommandService.availableSessionShortcuts()`.
2. When a project is expanded and a session row is visible, the summary builder requests `WorkspaceStore.terminalTabs(in: session.id)`.
3. The presentation resolver maps each terminal tab to user-facing identity using:
   - custom tab title when present
   - shortcut lookup by `tab.shortcutID`
   - `launchCommand` heuristic fallback
   - `"Terminal"` fallback
4. `TerminalExitEventSource` overlays ephemeral exit observations for matching tab IDs.
5. `SessionRowView` renders the summaries and calls `WorkspaceCommandService.selectTab(id:)` when a child row is selected.
6. When tabs are created, selected, restored, or exited, the AppShell recomputes the affected session summaries through event-driven updates only.

## Implementation Design

### Core Interfaces

Reference contracts below are Go-style interface sketches for the logical contracts. Final implementation will use Swift `struct` and `@MainActor` types in the existing package layout.

```go
type SessionTerminalSummary struct {
	SessionID       uuid.UUID
	TabID           uuid.UUID
	Title           string
	AgentLabel      string
	ShortcutID      *uuid.UUID
	LastActivatedAt time.Time
	ExitStatus      *int32
	IsSelected      bool
}
```

```go
type TerminalExitEventSource interface {
	Snapshot(tabID uuid.UUID) (exitStatus *int32, ok bool)
	Subscribe(fn func(tabID uuid.UUID, exitStatus *int32)) (unsubscribe func())
}
```

### Data Models

#### Existing models reused

**`WorkspaceTab`**  
Existing fields already cover V1 identity and ordering:
- `id`
- `sessionID`
- `kind`
- `title`
- `shortcutID`
- `launchCommand`
- `launchArgumentsJSON`
- `ordinal`
- `lastActivatedAt`

**`SessionShortcut`**  
Existing fields already cover V1 shortcut presentation:
- `id`
- `label`
- `launchCommand`
- built-in or user-override metadata

**`WorkspaceStore`**  
Existing selectors already cover V1 summary inputs:
- `terminalTabs(in:)`
- `tab(id:)`
- `selectedSessionID`
- `selectedTabID`
- ordered session access

#### New AppShell-only models

**`SessionTerminalSummary`**  
Ephemeral render model produced per terminal tab. Proposed Swift fields:
- `sessionID: UUID`
- `tabID: UUID`
- `title: String`
- `agentLabel: String`
- `shortcutID: UUID?`
- `lastActivatedAt: Date`
- `exitStatus: Int32?`
- `isSelected: Bool`

**`SessionShortcutCatalog`**  
In-memory lookup cache keyed by shortcut ID:
- `[UUID: SessionShortcut]`

Purpose:
- Support custom profile labels and icons, not just built-in shortcuts

Refresh strategy:
- Initial load on sidebar appearance
- Reload when agent-profile mutations post a shortcut-catalog change notification
- Optional reload when the app becomes active if the cached catalog is empty

**`TerminalExitSnapshot`**  
Ephemeral in-memory dictionary:
- `[UUID: Int32?]`

Purpose:
- Record only observed exit results for current-process lifetime
- Provide factual status overlay without persistence

#### Storage changes

None.

V1 does **not**:
- add new SQLite columns
- modify restore snapshot schema
- persist last-known terminal status
- add a new core runtime status enum

### API Endpoints

No external HTTP, IPC, or network API endpoints change in V1.

Internal API surface reused or added:

| Surface | Shape | Purpose |
| --- | --- | --- |
| `WorkspaceCommandService.availableSessionShortcuts()` | async -> `[SessionShortcut]` | Load the current shortcut catalog for custom profile lookup |
| `WorkspaceStore.terminalTabs(in:)` | sync -> `[WorkspaceTab]` | Source terminal-only rows in display order |
| `WorkspaceCommandService.selectTab(id:)` | async throws | Perform direct jump from inline row to actual tab |
| `TerminalHostController.onSurfaceExited` | callback | Source factual terminal exit observations |
| `TerminalExitEventSource.Subscribe` | observer | Deliver exit updates to the AppShell without a timer loop |

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
|-----------|-------------|---------------------|-----------------|
| `Sources/NativeMacADE/AppShell/ContentView.swift` | modified | Large existing file; session row UI and existing tab identity logic both change. Medium risk of UI regressions. | Add inline terminal child rows, child-row actions, and extract shared identity logic. |
| `Sources/NativeMacADE/AppShell/AgentProfileVisuals.swift` | modified | Low risk; existing icon logic already centralizes brand mapping. | Reuse or extend icon helpers for summary-row rendering. |
| `Sources/NativeMacADE/AppShell/SessionTerminalPresentationResolver.swift` | new | Low risk; pure presentation helper local to AppShell. | Add shared title, label, and icon resolution. |
| `Sources/NativeMacADE/AppShell/SessionTerminalSummaryBuilder.swift` | new | Low risk; pure summary assembly from store and cached lookup data. | Add terminal-only row construction and factual status mapping. |
| `Sources/NativeMacADECore/App/AppDependencyContainer.swift` | modified | Medium risk; currently owns the only `onSurfaceExited` wiring. | Introduce lightweight exit-event fan-out while preserving existing logging behavior. |
| `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift` | reused | Low risk if unchanged; only factual exit callback is consumed. | Keep existing callback contract intact. |
| `Package.swift` | modified | Low to medium risk; integration tests may need access to the App target for resolver and row-composition assertions. | Extend the existing integration-test dependency surface if direct AppShell coverage is needed. |
| `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` | modified | Low risk; already covers shortcut identity behavior. | Extend coverage around terminal-tab identity assumptions used by the new summary builder. |
| `Tests/NativeMacADEIntegrationTests/*` | modified | Medium risk; integration coverage will exercise sidebar-facing composition helpers and exit-event wiring. | Add focused tests for summary composition, direct tab selection, and exit-event propagation. |

## Testing Approach

### Unit Tests

**Strategy**
- Keep pure logic testable and deterministic.
- Anchor unit-style coverage around the new AppShell resolver and summary builder.
- If AppShell helpers cannot be imported through the current test target layout, extend the existing integration target to import `NativeMacADE` rather than creating a separate package or feature-only test harness.

**Key components to test**
- `SessionTerminalPresentationResolver`
- `SessionTerminalSummaryBuilder`
- `TerminalExitEventSource`

**Critical scenarios**
- Custom tab title overrides shortcut and command heuristics
- Custom profile lookup resolves label and icon by `shortcutID`
- Built-in fallback still works when only `launchCommand` is available
- File tabs are excluded from inline session rows
- Duplicate terminal labels still produce stable per-tab selection targets
- Exit snapshots override neutral state only for observed tab IDs

**Mock boundaries**
- Shortcut catalog input
- Exit-event source input
- `WorkspaceStore` fixture data for mixed file and terminal sessions

### Integration Tests

**Strategy**
- Extend the current integration-first testing style already used around `DefaultWorkspaceCommandService` and persistence.
- Keep UI-adjacent tests focused on summary composition and action wiring, not full UI snapshot coverage.

**Components to test together**
- `WorkspaceStore` + summary builder
- `AppDependencyContainer` + `TerminalExitEventSource` + `recordTerminalProcessExit`
- `ProjectSidebarView` row action path + `WorkspaceCommandService.selectTab(id:)`
- Shortcut catalog reload path after agent-profile mutations

**Test data requirements**
- Plain sessions with one terminal tab
- Mixed-agent sessions with multiple terminal tabs
- Sessions containing both terminal and file tabs
- Custom profile shortcuts with renamed labels
- Restored selections where the selected tab is a file tab inside a mixed session

**Environment dependencies**
- Existing in-memory persistence harnesses
- Existing terminal test doubles
- Possible `NativeMacADE` target import inside integration tests for direct resolver and row-composition assertions

## Development Sequencing

### Build Order

1. **Extract `SessionTerminalPresentationResolver` and define summary contracts** — no dependencies.
2. **Add `TerminalExitEventSource` and wire `AppDependencyContainer` fan-out** — depends on step 1 for shared summary and status contract shape.
3. **Implement `SessionTerminalSummaryBuilder` using `WorkspaceStore.terminalTabs(in:)`, shortcut catalog lookup, and exit snapshots** — depends on steps 1 and 2.
4. **Extend `ProjectSidebarView` and `SessionRowView` to load shortcut catalog, subscribe to exit events, render terminal-only rows, and call `selectTab(id:)`** — depends on step 3.
5. **Add or extend automated coverage in existing test targets for resolver behavior, summary composition, direct tab jump, and exit propagation** — depends on steps 1 through 4.

### Technical Dependencies

- Existing `WorkspaceTab.shortcutID` persistence and restore behavior must remain intact.
- Existing `WorkspaceCommandService.availableSessionShortcuts()` remains the source of truth for the shortcut catalog.
- Existing `TerminalHostController.onSurfaceExited` callback must continue to feed `recordTerminalProcessExit` even after fan-out is introduced.
- No external services or infrastructure are required.
- If direct AppShell assertions are added, the current integration test target may need an additional dependency on `NativeMacADE`.

## Monitoring and Observability

**Key metrics to track**
- Number of inline session expansions
- Number of inline terminal-row selections
- Time from session expansion to tab selection in local diagnostics
- Exit-event publish count versus existing `terminal_process_exited` log count
- Shortcut catalog reload success or failure count

**Log events and structured fields**
- `session_inline_expanded`
  - `project_id`
  - `session_id`
  - `terminal_row_count`
- `session_inline_tab_selected`
  - `project_id`
  - `session_id`
  - `tab_id`
  - `shortcut_id`
  - `was_exited`
- `session_shortcut_catalog_reloaded`
  - `shortcut_count`
  - `reason`
- existing `terminal_process_exited`
  - preserve current `tab_id`, `session_id`, `exit_status`

**Alerting thresholds and escalation**
- No external production alerting is required for V1 because the app is local-first and desktop-scoped.
- Treat mismatches between observed exit propagation and logged terminal exits as release blockers during implementation validation.
- Treat repeated shortcut-catalog reload failures during pilot validation as a high-priority defect because they degrade custom profile identity.

## Technical Considerations

### Key Decisions

- **Keep summary composition in AppShell**  
  Rationale: the feature lands in `SessionRowView`, and the chosen scope does not justify a core-owned summary layer yet.  
  Trade-off: less immediate reuse across future surfaces.  
  Alternatives rejected: a core-owned summary model and a broader monitor service.

- **Use factual metadata plus ephemeral exit state only**  
  Rationale: matches the PRD’s trust boundary and avoids new persistence or state-machine complexity.  
  Trade-off: status remains limited and less expressive than competitor dashboards.  
  Alternatives rejected: persisted status snapshots, richer runtime state maps, and timer-based refresh loops.

- **Use a shared AppShell presentation resolver**  
  Rationale: current title and icon heuristics already exist and should not fork between session rows and tab UI.  
  Trade-off: presentation knowledge remains local to the app target.  
  Alternatives rejected: separate per-view logic and pushing presentation helpers into store APIs.

- **Use a lightweight exit observer source near AppDependencyContainer**  
  Rationale: it preserves existing logging, stays event-driven, and avoids promoting exit state to a broader core contract.  
  Trade-off: another small wiring component appears in the app bootstrap path.  
  Alternatives rejected: store-owned exit state and no live exit propagation.

### Known Risks

- **Shortcut catalog drift after profile edits**  
  If the sidebar cache is not refreshed after save, reset, or delete, custom labels may lag behind reality.  
  Mitigation: post a shortcut-catalog change notification from profile mutation flows and reload the cache on receipt.

- **Single large ContentView file risk**  
  Modifying both session rows and existing tab identity logic inside one large file increases regression risk.  
  Mitigation: extract pure helpers into dedicated AppShell files before changing row rendering.

- **Overstated recency wording**  
  Event-driven only refresh means relative “X minutes ago” text can drift if no other event occurs.  
  Mitigation: prefer stable absolute formatting or conservative recency wording in V1.

- **Exit snapshot staleness**  
  Exit state is factual only when observed in the current app lifetime.  
  Mitigation: never infer that missing exit data means running, and clear stale snapshot entries opportunistically when sessions or tabs disappear.

- **AppShell test coverage gaps**  
  Current test targets focus on core and integration flows, not AppShell-local helpers.  
  Mitigation: extend the existing integration target to import the app target if direct AppShell assertions are required.

## Architecture Decision Records

- [ADR-001: Scope V1 as inline session-row attention routing](adrs/adr-001.md) — Keeps the feature sidebar-first and truthful rather than expanding into a broader monitoring surface.
- [ADR-002: Adopt a focused inline navigator approach for the PRD](adrs/adr-002.md) — Locks the product scope to terminal-only rows, factual status, collapsed restore, and fast tab jumps.
- [ADR-003: Keep session-tab summary composition in AppShell](adrs/adr-003.md) — Places summary building and identity resolution in the app layer instead of creating a core summary subsystem.
- [ADR-004: Use event-driven factual status derived from existing metadata](adrs/adr-004.md) — Reuses current metadata and exit callbacks without new persisted status fields or timer refresh.
