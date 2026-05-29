# Config Modal Customization

## Executive Summary

This TechSpec implements the PRD’s guided control center as an additive extension of Another ADE’s current architecture. The design keeps the feature inside the existing app shell, command service, workspace store, SQLite persistence layer, and terminal host instead of introducing a parallel settings subsystem. V1 adds one in-app config modal, a narrow global `AppPreferences` model, curated agent-profile management built on `SessionShortcut`, a fixed four-theme runtime catalog, and a managed keybinding registry for session and tab navigation, session search, terminal zoom, right-sidebar toggle, and settings access.

The primary technical trade-off is seam reuse versus localized complexity. Reusing `SessionShortcut`, `WorkspacePersistenceStore`, and `DefaultWorkspaceCommandService` minimizes new abstractions and keeps settings behavior consistent with restore and launch intent. In return, the implementation must touch multiple existing layers that are currently hard-coded to Nord dark theme and static keyboard shortcuts, and it must normalize the current split session-creation path so default agent profiles do not create inconsistent or duplicate tabs.

## System Architecture

### Component Overview

- **App Shell**
  - `NativeMacADEApp` remains the scene owner and command host.
  - It adds a `Settings…` command (`⌘,`) and resolves top-level keyboard shortcuts from persisted preferences instead of hard-coded bindings.
  - `ContentView` becomes the in-app modal host and the startup coordinator for loading preferences before clearing the restore overlay.

- **Workspace Store**
  - `WorkspaceStore` remains the in-memory source of truth for project, session, tab, and selection state.
  - It gains observed `appPreferences` state so theme and command bindings can react immediately without a second global store.
  - It does not become a generic settings container; V1 stores only the preferences required by this feature.

- **Workspace Command Service**
  - `WorkspaceCommandService` expands to own settings reads and writes in addition to existing workspace actions.
  - `DefaultWorkspaceCommandService` remains the single orchestration seam for persistence, validation, session bootstrap, and logging.
  - `createSession` becomes the sole owner of first-tab bootstrap for explicit profiles, saved default profiles, and plain shell sessions.

- **Persistence Store**
  - `WorkspacePersistenceStore`, `SQLiteWorkspaceMetadataStore`, and `InMemoryWorkspacePersistenceStore` extend to load and save `AppPreferences`.
  - SQLite adds a new `app_preferences` table and an additive schema update for built-in profile override state.
  - The store remains local-first and keeps secrets outside SQLite.

- **Agent Profile Layer**
  - `SessionShortcut` stays the persisted launch-profile model.
  - Curated agent options such as OpenCode extend the existing built-in catalog.
  - Built-in profile reset and customization state are explicit parts of the model contract, not implicit UI-only behavior.

- **Theme Runtime**
  - A new `AppTheme` domain object replaces direct Nord-only shell assumptions.
  - The V1 catalog is fixed to `dracula`, `onedark`, `catppuccin`, and `cursor`.
  - Each theme carries both shell palette values and a `TerminalAppearance`.
  - SwiftUI resolves the current theme from `WorkspaceStore.appPreferences.themeID`, while the terminal host applies the paired terminal appearance.

- **Keybinding Registry**
  - A narrow managed command registry defines stable IDs and default bindings for `previousTab` (`⌘[`), `nextTab` (`⌘]`), `previousSession` (`⌘↑`), `nextSession` (`⌘↓`), `searchSessions` (`⌘P`), `zoomInTerminal` (`⌘+`), `zoomOutTerminal` (`⌘-`), `toggleRightSidebar` (`⌘L`), and `openSettings` (`⌘,`).
  - Persisted overrides store only user changes; runtime merges them with static defaults.
  - `toggleRightSidebar` is included as a stable command ID even though the right sidebar itself remains deferred for now.
  - V1 does not attempt a general action-ID system for view-local shortcuts.

- **Terminal Host Layer**
  - `TerminalHostController` gains a live terminal-appearance source instead of always using `.nordDefault`.
  - New surfaces use the current appearance, and existing attached host views update when the theme changes.
  - Restore behavior remains metadata-only; persisted tabs still reopen with their saved launch intent.

### Data Flow

1. On launch, `ContentView` loads `AppPreferences` through `WorkspaceCommandService`, applies them to `WorkspaceStore`, then runs `restoreWorkspace`.
2. SwiftUI resolves the current shell theme from `WorkspaceStore.appPreferences` and injects it into the view tree.
3. `NativeMacADEApp.commands` resolves top-level keyboard shortcuts from the same observed preferences state.
4. Opening the config modal loads the current `AppPreferences` plus available `SessionShortcut` records.
5. Saving settings validates the input, persists the updated preference or profile state, updates `WorkspaceStore`, and emits logs and metrics.
6. When a user creates a new session, `DefaultWorkspaceCommandService.createSession` resolves launch intent in this order: explicit `shortcutID`, saved default profile, plain shell. The service creates the first tab in all cases.
7. Later tabs continue to inherit the saved `session.shortcutID` exactly as they do today.
8. Restore rebuilds tabs from persisted launch metadata and does not retroactively apply new default profiles to old sessions.

### External System Interactions

- **macOS command and windowing APIs**
  - Provide the top-level command menu, modal presentation, and keyboard shortcut registration.
- **Ghostty / terminal host boundary**
  - Receives the resolved `TerminalAppearance` for new and existing terminal surfaces.
- **SQLite**
  - Remains the only persistent metadata store for V1 configuration state.
- **Keychain**
  - Remains unchanged; `secretRef` stays an indirect reference only.

## Implementation Design

### Core Interfaces

The concrete implementation will be Swift, but the logical service contract below defines the main dependency boundary.

```go
type WorkspaceCommandService interface {
    LoadAppPreferences() (AppPreferences, error)
    SaveAppPreferences(prefs AppPreferences) error
    AvailableSessionShortcuts() ([]SessionShortcut, error)
    SaveSessionShortcut(shortcut SessionShortcut) (SessionShortcut, error)
    DeleteSessionShortcut(id string) error
    ResetBuiltInSessionShortcut(id string) (SessionShortcut, error)
    CreateSession(projectID string, shortcutID *string) (SessionRef, error)
}
```

```go
type AppPreferences struct {
    ThemeID                  string
    DefaultSessionShortcutID *string
    Keybindings              map[string]KeybindingOverride
    UpdatedAtUnix            int64
}
```

**Error handling conventions**
- Invalid `launchArgumentsJSON` is rejected before persistence instead of silently falling back to `[]`.
- Duplicate managed keybindings are rejected before persistence with a typed validation error.
- Unknown theme IDs and dangling default-profile references fall back safely, emit logs, and self-heal persisted state on the next save path.
- Built-in agent profiles cannot be deleted; they can only be reset to canonical defaults.
- `createSession` must never create more than one first tab for a new session.

### Data Models

| Entity | Fields | Notes |
| --- | --- | --- |
| `AppPreferences` | `id: Int`, `themeID: String`, `defaultSessionShortcutID: UUID?`, `keybindings: [AppCommandID: KeybindingOverride]`, `updatedAt: Date` | New global preferences model. `id` stays fixed at `1`. |
| `KeybindingOverride` | `commandID: AppCommandID`, `keyEquivalent: String`, `modifiers: [KeyModifier]` | Persist only overrides for the managed command set: previous/next tab, previous/next session, session search, terminal zoom in/out, right-sidebar toggle, and settings. |
| `SessionShortcut` | `id: UUID`, `label: String`, `launchCommand: String`, `launchArgumentsJSON: String?`, `secretRef: String?`, `isBuiltIn: Bool`, `hasUserOverride: Bool` | Reused as the curated agent-profile model. `hasUserOverride` prevents shipped default changes from being mistaken for user edits. |
| `AppTheme` | `id: String`, `displayName: String`, `colorScheme: ThemeColorScheme`, `shellPalette: ShellThemePalette`, `terminalAppearance: TerminalAppearance` | New runtime theme descriptor shared by SwiftUI and terminal host code. V1 supports `dracula`, `onedark`, `catppuccin`, and `cursor` only. |
| `WorkspaceStore` | existing fields plus `appPreferences: AppPreferences` | Keeps preferences observable at app scope without introducing a second global store. |

#### Storage Structures

- **`app_preferences`** — new single-row table:
  - `id INTEGER PRIMARY KEY NOT NULL CHECK (id = 1)`
  - `theme_id TEXT NOT NULL`
  - `default_session_shortcut_id TEXT REFERENCES session_shortcuts(id) ON DELETE SET NULL`
  - `keybindings_json TEXT NOT NULL`
  - `updated_at REAL NOT NULL`

- **`session_shortcuts`** — additive column:
  - `has_user_override INTEGER NOT NULL DEFAULT 0`

- **`restore_snapshot`** — unchanged

#### Migration Strategy

- Bump `WorkspaceMigrations.currentUserVersion` from `1` to `2`.
- Keep bootstrap behavior for fresh databases.
- Add an incremental migration path from version `1` to `2`:
  1. create `app_preferences` if missing;
  2. add `has_user_override` to `session_shortcuts` if missing;
  3. seed the single `app_preferences` row with the `cursor` theme, no default profile, and empty keybinding overrides;
  4. set `PRAGMA user_version = 2`.
- Keep the migration additive so existing projects, sessions, tabs, and restore snapshots remain untouched.

#### Deliberate Exclusions

- No per-project preference table.
- No cloud-synced settings state.
- No generic key-value settings schema.
- No open-ended agent marketplace or arbitrary plugin metadata.
- No retroactive mutation of existing session launch intent when defaults change.

### API Endpoints

No HTTP or RPC endpoints are added. V1 extends the internal command surface instead.

| Call | Inputs | Output | Behavior |
| --- | --- | --- | --- |
| `loadAppPreferences()` | none | `AppPreferences` | Returns persisted preferences or seeded defaults. |
| `saveAppPreferences(_:)` | typed `AppPreferences` | `Void` | Validates theme ID, default profile reference, and keybinding conflicts before persistence. |
| `availableSessionShortcuts()` | none | `[SessionShortcut]` | Returns curated built-ins plus saved custom profiles. |
| `saveSessionShortcut(_:)` | `SessionShortcut` | `SessionShortcut` | Creates or updates a custom profile, or updates a built-in profile in place and sets `hasUserOverride = true`. |
| `deleteSessionShortcut(id:)` | profile ID | `Void` | Deletes custom profiles only; clears `app_preferences.default_session_shortcut_id` if needed. |
| `resetBuiltInSessionShortcut(id:)` | built-in profile ID | `SessionShortcut` | Restores the canonical built-in values and clears `hasUserOverride`. |
| `createSession(projectID:shortcutID:)` | project ID, optional explicit profile ID | `WorkspaceSession` | Always creates the first tab. Resolution order is explicit profile, saved default profile, then plain shell. |

## Integration Points

No new external service integrations are introduced in V1.

The feature only touches existing internal boundaries:
- the macOS command menu and modal presentation layer in `NativeMacADE`;
- the Ghostty terminal host boundary for runtime appearance changes;
- the existing SQLite metadata store.

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
|-----------|-------------|---------------------|-----------------|
| `Sources/NativeMacADE/NativeMacADEApp.swift` | modified | Medium risk. Commands move from hard-coded shortcuts to a registry-backed runtime model, and a new `Settings…` action is added. | Replace static keyboard shortcuts with resolved bindings and add the settings entry point. |
| `Sources/NativeMacADE/AppShell/ContentView.swift` | modified | High risk. Startup flow, dynamic theme application, and modal hosting all change in the root view. | Load preferences before clearing restore state, host the modal, and replace hard-coded Nord usage. |
| `Sources/NativeMacADE/AppShell/ConfigModalView.swift` | new | Medium risk. New settings surface with multiple sections and validation paths. | Add the modal and keep it scoped to approved V1 controls only. |
| `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` | modified | Medium risk. Store gains observed preference state. | Add `appPreferences` and mutation helpers without turning the store into a generic settings bag. |
| `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` | modified | Medium risk. Protocol expands to cover settings operations. | Add the small settings surface and update all conformers. |
| `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` | modified | High risk. Becomes the single owner of settings persistence, validation, and uniform session bootstrap. | Centralize first-tab creation and validate all new preference mutations. |
| `Sources/NativeMacADECore/Persistence/*` | modified | High risk. Schema migration and new load/save paths affect startup and data integrity. | Add `AppPreferences` persistence, user-version migration, and in-memory parity. |
| `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift` or sibling model file | modified | Medium risk. Adds `AppPreferences`, keybinding types, and explicit built-in override state. | Introduce additive model types and keep naming clear. |
| `Sources/NativeMacADECore/Theme/*` | modified/new | High risk. Theme state becomes runtime-driven instead of static Nord-only values. | Add `AppTheme` catalog and replace direct Nord-only assumptions. |
| `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift` | modified | High risk. Terminal appearance must update live and apply to future surfaces. | Add current appearance state and refresh host views/drivers on theme change. |
| `Tests/NativeMacADEIntegrationTests/*` and `Tests/NativeMacADECoreTests/*` | modified/new | Medium risk. Existing restore and launch tests must stay stable while new settings behavior is added. | Add migration, default-profile, theme, and keybinding coverage. |

## Testing Approach

### Unit Tests

- Validate `AppTheme` lookup and fallback behavior for known and unknown theme IDs.
- Validate `KeybindingOverride` parsing, normalization, and duplicate-command conflict detection.
- Validate `SessionShortcut` mutation rules:
  - built-ins can be edited and reset;
  - custom profiles can be edited and deleted;
  - invalid argument JSON is rejected before save.
- Validate `AppPreferences` merge behavior, especially override-only keybinding persistence.
- Validate helper logic that clears invalid default-profile references.

**Mock requirements and boundaries**
- Use in-memory persistence for pure validation paths.
- Do not mock theme catalogs or command identifiers; keep them as static test fixtures.
- Keep Ghostty out of unit scope.

### Integration Tests

- **Migration tests**
  - Upgrade a version `1` SQLite database to `2`.
  - Verify `app_preferences` exists, `has_user_override` is present, and existing workspace tables remain intact.

- **Preferences round-trip tests**
  - Save and reload `AppPreferences` through SQLite and in-memory stores.
  - Verify typed keybindings survive serialization and deserialization.

- **Session bootstrap tests**
  - Explicit profile session creates exactly one first tab with the explicit launch intent.
  - Saved default profile session creates exactly one first tab when `shortcutID == nil`.
  - Plain session creates exactly one first tab with no launch command.
  - Deleting a profile referenced by preferences clears the saved default profile safely.

- **Restore stability tests**
  - Existing restored tabs keep their persisted launch command and arguments even after preferences change.
  - Restore remains metadata-only and does not re-resolve the current default profile.

- **Theme application tests**
  - Saving a new theme updates root shell state immediately.
  - New terminal surfaces use the new `TerminalAppearance`.
  - Existing attached host views refresh to the new appearance without recreating session metadata.

- **Command binding tests**
  - Resolved managed commands for tab navigation, session navigation, session search, terminal zoom, right-sidebar toggle, and settings use persisted overrides after preferences load.
  - Resetting a binding removes the override and returns to the static default.

**Environment dependencies**
- Temporary SQLite databases for migration coverage.
- In-memory or fake terminal host surfaces for theme application checks.
- No external service or network environment is required.

## Development Sequencing

### Build Order

1. **Add core preference and keybinding models plus migration scaffolding** — no dependencies.
2. **Extend persistence with `AppPreferences` and built-in override support** — depends on step 1.
3. **Normalize `createSession` so it always owns first-tab bootstrap and default-profile resolution** — depends on steps 1 and 2.
4. **Extend `WorkspaceStore` and `WorkspaceCommandService` with settings load/save flows and validation** — depends on steps 1, 2, and 3.
5. **Introduce `AppTheme` and wire live shell and terminal appearance updates** — depends on steps 1, 2, and 4.
6. **Introduce the top-level command registry and dynamic keyboard shortcut resolution in `NativeMacADEApp`** — depends on steps 1, 2, and 4.
7. **Add the config modal UI and bind it to command-service actions and observed store state** — depends on steps 4, 5, and 6.
8. **Add migration, integration, and focused unit tests across persistence, session bootstrap, theme changes, and command overrides** — depends on steps 2 through 7.

### Technical Dependencies

- No external infrastructure or service dependency blocks V1.
- The curated built-in agent list, the fixed theme catalog (`dracula`, `onedark`, `catppuccin`, `cursor`), and the managed command IDs (`previousTab`, `nextTab`, `previousSession`, `nextSession`, `searchSessions`, `zoomInTerminal`, `zoomOutTerminal`, `toggleRightSidebar`, `openSettings`) must be frozen before implementation begins so stable IDs can be persisted safely.
- The implementation depends on SwiftUI command rebuilding behaving correctly from observed app state; if that proves unreliable in a spike, the fallback is to keep the same command IDs but route them through app-owned `@State` mirrors of `WorkspaceStore.appPreferences`.

## Monitoring and Observability

- **Key metrics to track**
  - `settings_opened_count`
  - `settings_saved_count`
  - `settings_save_failure_count`
  - `session_created_count` with `launch_profile_source = explicit|default|plain`
  - `theme_changed_count`
  - `keybinding_changed_count`
  - `default_profile_resolution_failure_count`

- **Log events and structured fields**
  - `settings_opened`: `surface`, `selected_project_id_present`
  - `settings_saved`: `theme_id`, `default_profile_id`, `changed_keybinding_count`
  - `settings_save_failed`: `reason`, `field`
  - `session_created`: add `launch_profile_source` and `launch_profile_id`
  - `theme_applied`: `theme_id`
  - `keybinding_conflict_rejected`: `command_id`, `conflicting_command_id`
  - `default_profile_cleared`: `stale_profile_id`, `reason`

- **Alerting thresholds and escalation**
  - V1 keeps local-only observability; no remote alerting stack is added.
  - Extend `PerformanceMetrics` or pilot diagnostics with settings persistence failures and default-profile resolution failures.
  - A repeat settings persistence failure in manual pilot use is release-blocking until fixed because it undermines the core feature promise.

## Technical Considerations

### Key Decisions

- **Host settings in the main window, not a separate Settings scene**
  - **Rationale:** matches the approved guided control-center experience and reuses existing modal patterns.
  - **Trade-off:** faster integration and stronger workflow affinity over standard macOS preferences behavior.
  - **Alternatives rejected:** native Settings scene, hybrid scene plus modal.

- **Keep preferences inside the existing SQLite persistence boundary**
  - **Rationale:** one persistence seam is easier to test, migrate, and reason about than a split SQLite plus `UserDefaults` model.
  - **Trade-off:** more work in the existing metadata store over the convenience of platform defaults.
  - **Alternatives rejected:** `UserDefaults` split, separate settings store.

- **Reuse `SessionShortcut` as the curated agent profile model**
  - **Rationale:** it already owns the persisted launch contract for sessions and tabs.
  - **Trade-off:** minimal schema and service churn over cleaner naming.
  - **Alternatives rejected:** new `AgentProfile` entity, wrapper abstraction over `SessionShortcut`.

- **Centralize first-tab bootstrap in `createSession`**
  - **Rationale:** avoids double-tab risk and makes explicit, default, and plain session launch semantics uniform.
  - **Trade-off:** changes current service behavior and requires UI updates.
  - **Alternatives rejected:** keep split UI/service bootstrap, add a second start-session API.

- **Limit V1 keyboard customization to the managed navigation, search, zoom, sidebar, and settings command set**
  - **Rationale:** it covers the most visible workflow controls without building a broad action-routing system.
  - **Trade-off:** smaller scope over comprehensive shortcut remapping.
  - **Alternatives rejected:** in-view shortcut capture, broad general remapping layer.

- **Avoid a separate `WorkspaceSettingsService` protocol in V1**
  - **Rationale:** the same concrete service already owns the persistence and orchestration seams this feature needs.
  - **Trade-off:** one broader protocol over another abstraction layer and more container wiring.
  - **Alternatives rejected:** parallel settings-service protocol backed by the same concrete implementation.

### Known Risks

- **Theme migration depth**
  - **Likelihood:** High
  - **Risk:** hard-coded `NordTheme` and `.nordDefault` references are scattered through the shell and terminal host.
  - **Mitigation:** introduce one runtime `AppTheme` type, do a full pass over hard-coded theme references in the app shell, and test existing host-view updates explicitly.

- **Schema migration correctness**
  - **Likelihood:** Medium
  - **Risk:** version `1` to `2` migration touches startup-critical persistence.
  - **Mitigation:** keep the migration additive, isolate it from restore logic, and cover it with SQLite fixture tests.

- **Command rebuild behavior in SwiftUI**
  - **Likelihood:** Medium
  - **Risk:** dynamic keyboard shortcuts in `commands` may not refresh as expected from observed state.
  - **Mitigation:** validate the behavior early, and keep the fallback limited to app-owned mirrored state rather than a redesign.

- **Preference/reference drift**
  - **Likelihood:** Medium
  - **Risk:** saved default profile references can become stale after deletion or curated-catalog changes.
  - **Mitigation:** clear invalid references during load and delete paths, log the event, and never fail session creation because of a stale preference.

- **Shortcut naming confusion**
  - **Likelihood:** Medium
  - **Risk:** “shortcut” currently means launch profile in core models and keyboard shortcut in user-facing settings.
  - **Mitigation:** use “Agent Profile” consistently in UI and docs while retaining `SessionShortcut` in code for V1.

## Architecture Decision Records

- [ADR-001: Agent-First Scope for Config Modal Personalization](adrs/adr-001.md) — Establishes agent-first scope and a narrow preferences model for personalization.
- [ADR-002: Guided Control Center Product Approach for Config Modal Customization](adrs/adr-002.md) — Selects the full but guided V1 approach built for switchers from mature tools.
- [ADR-003: In-App Modal Settings Host for Config Customization](adrs/adr-003.md) — Keeps the settings surface inside the main app window instead of adding a separate Settings scene.
- [ADR-004: SQLite-Centered Global Preferences Layer](adrs/adr-004.md) — Extends the existing persistence boundary with a small global preferences record.
- [ADR-005: Reuse SessionShortcut as the Curated Agent Profile Model](adrs/adr-005.md) — Builds curated agent profiles and editable defaults on top of the existing launch-profile model.
- [ADR-006: Limited Keybinding Scope and Immediate Preference Application](adrs/adr-006.md) — Constrains V1 shortcut customization to the managed navigation, search, sidebar, and settings command set and applies UI changes immediately.
- [ADR-007: Centralize New-Session Bootstrap in WorkspaceCommandService](adrs/adr-007.md) — Makes session creation the single owner of first-tab bootstrap and default-profile resolution.
