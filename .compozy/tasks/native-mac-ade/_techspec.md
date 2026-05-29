# Native Mac ADE

## Executive Summary

This TechSpec implements the PRD's workflow-speed-first V1 as a greenfield native macOS application. The design uses a SwiftUI app shell for scene management, sidebar navigation, and state-driven UI, paired with AppKit terminal host components that embed full `libghostty` surfaces inside the app. Core product state stays organized around the existing project -> session -> tab model, with local command services coordinating user actions, terminal lifecycle, and persistence.

The primary technical trade-off is direct control versus lower integration risk. Embedding full `libghostty` gives the app tight control over tabs, working-directory defaults, close behavior, and restore flow, which is necessary for the in-app ADE experience. In return, V1 accepts upstream API churn, a mixed SwiftUI/AppKit stack, and a simpler continuity model that restores metadata and opens fresh shells instead of preserving live terminal processes.

## System Architecture

### Component Overview

- **App Shell**
  - Owns app lifecycle, scene composition, top-level navigation, and dependency wiring.
  - Hosts the persistent project sidebar, session list, and tab chrome.
  - Exposes the selected project and selected session to the rest of the UI.

- **Workspace Store**
  - Maintains the in-memory source of truth for opened projects, sessions, tabs, selected context, and lightweight UI state.
  - Receives updates from command services and terminal lifecycle callbacks.
  - Publishes state changes to SwiftUI views.

- **Workspace Command Service**
  - Defines the in-process command boundary for `openProject`, `createSession`, `renameSession`, `createTab`, `restoreWorkspace`, and `runShortcut`.
  - Coordinates persistence updates with terminal surface creation and closure.
  - Converts domain intents into concrete launch configurations for tabs.

- **Terminal Host Layer**
  - Contains AppKit-backed terminal controllers and views that own one embedded Ghostty surface per tab.
  - Manages focus, sizing, close requests, and surface lifecycle on the main actor.
  - Sends terminal exit and close events back to the command service/store.

- **Ghostty Adapter**
  - Wraps the minimum `libghostty` C API needed by V1: process-level initialization, surface creation, inherited tab creation, launch configuration, resize/focus hooks, and process exit/confirm-quit queries.
  - Hides upstream API details behind a narrow Swift-facing contract.

- **Persistence Store**
  - Persists project, session, tab, shortcut, and restore-snapshot metadata in SQLite.
  - Loads the previous workspace state on launch and saves updated state on user actions and lifecycle checkpoints.
  - Stores no terminal scrollback or live shell process state.

- **Restore Coordinator**
  - Rebuilds the workspace from the latest restore snapshot during app launch.
  - Recreates fresh terminal tabs from saved metadata and re-selects the previous project/session/tab where possible.
  - Handles inaccessible project paths by skipping them and surfacing recovery UI.

### Data Flow

1. A SwiftUI action, such as selecting a project or creating a tab, triggers a method on the Workspace Command Service.
2. The command service updates the Persistence Store, calculates the next domain state, and asks the Terminal Host Layer to create or close surfaces when needed.
3. The Ghostty Adapter builds the underlying surface configuration and returns lifecycle callbacks to the terminal host.
4. The terminal host reports surface events, such as process exit or close request, back to the command service and Workspace Store.
5. The Workspace Store republishes the new selected project/session/tab state to SwiftUI views.
6. On app launch, the RestoreCoordinator loads the latest restore snapshot and replays the minimal commands required to reconstruct the workspace with fresh shells.

### External System Interactions

- `libghostty` provides embedded terminal rendering and PTY-backed terminal surface lifecycle.
- macOS file and windowing APIs provide project-folder access, scene lifecycle, focus, and close semantics.
- SQLite provides local metadata storage.
- Keychain remains reserved for future sensitive shortcut data; it is not part of the core V1 happy path unless a shortcut needs secrets.

## Implementation Design

### Core Interfaces

The concrete implementation will be Swift, but the logical service contract below defines the boundary other components depend on.

```go
type WorkspaceCommandService interface {
    OpenProject(path string) (ProjectRef, error)
    CreateSession(projectID string, shortcutID *string) (SessionRef, error)
    RenameSession(sessionID string, title string) error
    CreateTab(sessionID string) (TabRef, error)
    RestoreWorkspace() error
    CloseTab(tabID string, force bool) error
}
```

```go
type RestoreSnapshot struct {
    SelectedProjectID string
    SelectedSessionID string
    SelectedTabID     string
    OpenTabIDs        []string
    CapturedAtUnix    int64
}
```

**Error handling conventions**
- Invalid project paths return typed validation errors and do not mutate workspace state.
- Terminal surface creation failures return user-visible errors and leave the workspace selection intact.
- Restore skips unrecoverable records, logs them, and continues reconstructing the rest of the workspace.
- Close requests from a live terminal surface must respect Ghostty's confirm-quit semantics before force-killing a process.

### Data Models

| Entity | Fields | Notes |
| --- | --- | --- |
| `Project` | `id: UUID`, `path: String`, `bookmarkData: Data?`, `displayName: String`, `createdAt: Date`, `lastOpenedAt: Date`, `sortIndex: Int` | `bookmarkData` is optional V1 support for re-accessing folders cleanly across launches; `path` remains the canonical working-directory reference. |
| `Session` | `id: UUID`, `projectID: UUID`, `title: String`, `isUserNamed: Bool`, `shortcutID: UUID?`, `createdAt: Date`, `lastActivatedAt: Date` | Default titles follow `MM-DD HH:mm`; user renames set `isUserNamed = true`. |
| `Tab` | `id: UUID`, `sessionID: UUID`, `workingDirectory: String`, `launchCommand: String?`, `launchArgumentsJSON: String?`, `ordinal: Int`, `createdAt: Date`, `lastActivatedAt: Date` | Stores the metadata required to recreate a fresh shell after relaunch. |
| `SessionShortcut` | `id: UUID`, `label: String`, `launchCommand: String`, `launchArgumentsJSON: String?`, `secretRef: String?`, `isBuiltIn: Bool` | V1 supports lightweight shortcuts only; `secretRef` points to Keychain if needed later. |
| `RestoreSnapshot` | `id: Int`, `selectedProjectID: UUID?`, `selectedSessionID: UUID?`, `selectedTabID: UUID?`, `tabOrderJSON: String`, `updatedAt: Date` | Use a single active snapshot row for V1's main workspace window. |

#### Storage Structures

- `projects` table stores sidebar membership and ordering.
- `sessions` table stores session names and project ownership.
- `tabs` table stores per-tab relaunch metadata only.
- `session_shortcuts` table stores built-in or user-defined lightweight launch profiles.
- `restore_snapshot` table stores one canonical representation of the active workspace layout.

#### Deliberate Exclusions

- No persisted shell scrollback.
- No live PTY/session reattachment records.
- No checkpoint or milestone tables.
- No global workspace entity above project/session/tab in V1.

### API Endpoints

V1 exposes no external HTTP, WebSocket, or IPC API. The only API surface is the in-process command boundary.

| Command | Inputs | Result | Failure Modes |
| --- | --- | --- | --- |
| `OpenProject` | absolute project path | creates or reselects a `Project` | invalid/inaccessible path |
| `CreateSession` | project ID, optional shortcut ID | creates a `Session` and first tab as needed | missing project, invalid shortcut |
| `RenameSession` | session ID, title | updates `Session.title` | missing session, invalid title |
| `CreateTab` | session ID | creates a `Tab` and Ghostty surface | surface creation failure, missing session |
| `RestoreWorkspace` | none | reconstructs projects, sessions, tabs from latest snapshot | corrupted snapshot, inaccessible project |
| `CloseTab` | tab ID, force flag | closes terminal surface and updates metadata | live-process confirmation rejected |

## Integration Points

| Boundary | Purpose | Auth/Authz | Error Handling |
| --- | --- | --- | --- |
| `libghostty` | Embedded terminal surfaces, PTY lifecycle, close/exit state | None; local library boundary only | Fail fast on initialization/surface creation errors, surface user-visible errors, keep adapter narrow |
| macOS filesystem + open panel | User-selected project directories and relaunch access | User-initiated folder access only | Skip inaccessible paths during restore and prompt user to reopen or remove them |
| SQLite local store | Local metadata persistence | App-local only | Treat write failures as blocking for state mutation; recover with last known good snapshot when possible |
| Keychain (optional V1 use) | Secret storage for future shortcut-sensitive data | App-local Keychain item access | Missing secrets disable the shortcut and surface configuration errors without crashing |

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
|-----------|-------------|---------------------|-----------------|
| App shell | new | New SwiftUI app lifecycle and navigation layer; medium risk because it owns all high-level state wiring | Scaffold a single macOS app target with scene composition and dependency injection |
| Workspace store | new | New in-memory model for project/session/tab selection; medium risk because UI consistency depends on it | Implement observable workspace state and deterministic state transitions |
| Workspace command service | new | New command boundary coordinating state, persistence, and terminal creation; medium risk because it is the core orchestration point | Define narrow service methods and typed errors |
| Terminal host layer | new | New AppKit view/controller layer for one Ghostty surface per tab; high risk because it bridges UI stacks and C APIs | Isolate in dedicated host components with main-actor ownership |
| Ghostty adapter | new | New wrapper over public-alpha `libghostty`; high risk due to upstream churn | Pin upstream revision and expose only minimal V1 APIs |
| Persistence store | new | New SQLite-backed metadata layer; low-to-medium risk if schema stays narrow | Implement explicit schema and repository methods for project/session/tab/restore |
| Restore coordinator | new | New workspace reconstruction flow on launch; medium risk because user trust depends on it | Rebuild state from metadata and reopen fresh shells predictably |
| Test targets | new | New unit and focused integration coverage; low risk with disciplined scope | Add domain/persistence unit tests and Ghostty-host integration tests |

## Testing Approach

### Unit Tests

- Test the Workspace Store for selection changes, duplicate-project behavior, session rename behavior, and tab inheritance from the selected project/session.
- Test the Persistence Store with a temporary SQLite database for CRUD behavior, ordering, snapshot overwrite rules, and restore-query correctness.
- Test the Workspace Command Service with Ghostty Adapter and Persistence Store doubles to verify command ordering and error propagation.
- Test default session naming, shortcut resolution, and restore snapshot serialization deterministically with a controlled clock.

**Critical scenarios**
- Opening an already-known project reselects it instead of duplicating it.
- Creating a tab always inherits the correct working directory from the selected session/project.
- Renaming a session flips `isUserNamed` and preserves ordering.
- Restore skips a missing project path without corrupting the rest of the workspace.
- A failed terminal creation does not leave orphaned tab metadata behind.

### Integration Tests

- Verify that the Ghostty Adapter can initialize once per process and create one surface per tab with the expected working directory and launch configuration.
- Verify that the Terminal Host Layer handles focus, resize, close request, and process-exit callbacks correctly.
- Verify that `RestoreWorkspace` recreates the expected number of tabs and reselects the intended project/session/tab from a stored snapshot.
- Verify that lightweight session shortcuts translate into the expected launch configuration without altering the project/session model.

**Environment dependencies**
- macOS test runner with the pinned Ghostty revision available.
- Writable temporary directory for SQLite and restore fixtures.
- A deterministic test command for shell launches so terminal integration tests do not depend on user-specific shell state.

## Development Sequencing

### Build Order

1. **Scaffold the macOS app target, test targets, and pinned Ghostty dependency boundary** — no dependencies.
2. **Implement core domain models and SQLite persistence for projects, sessions, tabs, shortcuts, and restore snapshots** — depends on step 1.
3. **Implement the Workspace Store and Workspace Command Service contracts** — depends on steps 1 and 2.
4. **Implement the Ghostty Adapter and AppKit Terminal Host Layer** — depends on steps 1 and 3.
5. **Build the SwiftUI sidebar, session list, and tab chrome against the store and terminal host** — depends on steps 3 and 4.
6. **Implement the Restore Coordinator and lightweight session shortcut flow** — depends on steps 2, 3, 4, and 5.
7. **Add unit tests, integration tests, performance instrumentation, and launch/restore polish** — depends on steps 2, 3, 4, 5, and 6.

### Technical Dependencies

- A pinned Ghostty revision or packaged binary artifact for the chosen `libghostty` embedding path.
- A single macOS build pipeline that can link the Ghostty C boundary cleanly into the app target.
- A clear local logging/instrumentation plan for launch, restore, and terminal-surface failures.
- Final decision during implementation on the thinnest SQLite binding that preserves explicit schema ownership.

## Monitoring and Observability

- **Key metrics to track**
  - app launch duration
  - project open duration
  - new tab creation duration
  - restore duration
  - restore success/failure count
  - Ghostty surface initialization failure count
  - close confirmation accept/reject count
  - inaccessible restored project count

- **Log events and structured fields**
  - `project_opened` with project ID and hashed path
  - `session_created` with project ID and session ID
  - `tab_created` with session ID, tab ID, and launch profile label
  - `restore_started` / `restore_completed` with tab count and duration
  - `restore_skipped_project` with hashed path and failure reason
  - `terminal_surface_failed` with tab ID and Ghostty error details
  - `terminal_process_exited` with tab ID and exit status

- **Alerting thresholds and escalation**
  - V1 has no backend alerting system.
  - For pilot builds, treat restore failure above 1% of launches, Ghostty surface initialization failure above 1% of tab creations, or median launch-to-ready time above the PRD budget as release-blocking quality regressions.
  - Surface these regressions through local diagnostics, CI test failures, and pilot build review rather than server-side paging.

## Technical Considerations

### Key Decisions

- **SwiftUI shell with AppKit terminal hosting** keeps the app native and aligns with Ghostty's macOS integration model while limiting custom UI infrastructure.
- **Full `libghostty` embedding** gives the app direct control over tabs, terminal lifecycle, and working-directory defaults at the cost of upstream API stability risk.
- **Metadata-only SQLite persistence with fresh-shell restore** keeps V1 aligned with the workflow-speed-first PRD and avoids background live-session complexity.
- **Local command services instead of a richer event bus** provide a clean internal API boundary without introducing infrastructure V1 does not need.
- **Single-window workspace state in V1** simplifies restore, selection, and persistence semantics; multi-window support remains future work unless the product proves a need.

### Known Risks

- **`libghostty` API churn may force adapter updates**
  - Likelihood: medium-high
  - Mitigation: pin a specific revision, isolate the adapter surface, and test upgrades explicitly.

- **SwiftUI/AppKit boundary bugs may affect focus and lifecycle behavior**
  - Likelihood: medium
  - Mitigation: keep terminal hosting isolated, main-actor-only, and covered by focused integration tests.

- **Users may misinterpret restore as live-shell persistence**
  - Likelihood: medium
  - Mitigation: keep relaunch behavior explicit in UI copy and ensure recreated tabs preserve the correct context even when shell state is fresh.

- **Project reaccess on launch may vary by distribution/sandbox setup**
  - Likelihood: medium
  - Mitigation: store canonical paths plus optional bookmark data and degrade gracefully when access cannot be re-established.

- **The greenfield app may accumulate unnecessary structure too early**
  - Likelihood: medium
  - Mitigation: keep the initial scaffold to one app target, one test target family, and a minimal set of concrete services.

## Architecture Decision Records

- [ADR-001: Session-First Native macOS ADE Scope for V1](adrs/adr-001.md) — Establishes the local-first project -> session -> tab product boundary and rejects broader orchestration scope in V1.
- [ADR-002: Adopt a Workflow-Speed-First PRD for V1](adrs/adr-002.md) — Sets faster project-based workflow as the primary framing for the first release.
- [ADR-003: Use a SwiftUI App Shell with AppKit Terminal Hosting](adrs/adr-003.md) — Chooses SwiftUI for the app shell and AppKit host components for embedded Ghostty surfaces.
- [ADR-004: Embed Full libghostty Surfaces Inside the App](adrs/adr-004.md) — Chooses direct embedded `libghostty` integration over wrappers or external-app coordination.
- [ADR-005: Persist Metadata-Only State and Restore Fresh Shells](adrs/adr-005.md) — Chooses SQLite metadata persistence with fresh-shell restoration instead of live shell persistence.
