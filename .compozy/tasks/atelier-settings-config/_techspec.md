# Atelier Settings Config

## Executive Summary

This TechSpec implements the PRD’s portable-settings workflow as an additive layer on top of Atelier’s existing settings architecture. V1 keeps `AppPreferences`, `WorkspaceStore`, `DefaultWorkspaceCommandService`, and the current startup order in place, then introduces a file-authoritative portable config document that projects supported settings into the existing runtime state. The portable contract stays intentionally narrow: theme, terminal font size, focus workspace, managed keybindings, and built-in default profile selection. Custom agent profile definitions and other local-only settings remain outside the portable contract.

The primary technical trade-off is portability clarity versus projection complexity. Making the config file authoritative gives users a real dotfile-style artifact and preserves the cross-machine promise, but it also creates a second representation of supported settings. The design keeps that complexity bounded by limiting V1 to `AppPreferences`-backed settings, using startup plus explicit manual reload instead of file watching, and applying mixed-validity config at section granularity with explicit diagnostics.

## System Architecture

### Component Overview

- **Portable Settings Document Layer**
  - Add a small versioned config DTO owned by `NativeMacADECore` rather than serializing raw `AppPreferences` or `SessionShortcut`.
  - Own stable external keys, section-level validation, and apply diagnostics.
  - Live in the existing core module as sibling types to `AppPreferences`; do not introduce a new package.

- **Portable Settings File Store**
  - Add a small file store and locator that resolves `$XDG_CONFIG_HOME/atelier/settings.json` and falls back to `~/.config/atelier/settings.json`.
  - Own atomic read and write behavior, missing-file detection, and bootstrap seeding.
  - Keep file IO outside the UI layer.

- **Workspace Command Service**
  - Keep `DefaultWorkspaceCommandService` as the single orchestration seam.
  - Extend it to bootstrap portable settings during `loadAppPreferences()`, mirror supported settings to disk from `saveAppPreferences(_:)`, and expose an explicit manual reload action.
  - Do not create a parallel settings service in V1.

- **Runtime Preferences and Cache**
  - Keep `AppPreferences` as the in-memory runtime model and SQLite-backed cache for supported fields.
  - Leave unsupported local-only settings in the existing local persistence model.
  - Avoid any SQLite schema change in V1 because supported portable settings already fit inside `app_preferences`.

- **Settings UI Integration**
  - Keep the current config modal as the only visible host.
  - Add a lightweight portable-settings control surface in that modal for reveal path, manual reload, and last apply status.
  - Add clear labeling where a setting is portable versus local-only.

- **Startup Coordinator**
  - Preserve the current order: settings load, theme application, then workspace restore.
  - Make `loadAppPreferences()` config-aware so restored terminals and sessions still see the already-applied appearance and default-profile state.

### Data Flow

1. `ContentView` starts `AppShellStartupCoordinator.run(...)` as it does today.
2. `loadAppPreferences()` resolves the canonical config path.
3. If the file exists, the service decodes the portable document, validates each supported section, maps valid sections into an `AppPreferences` projection, persists successful sections to SQLite, updates `WorkspaceStore`, and returns apply diagnostics.
4. If the file does not exist, the service loads normalized SQLite preferences. If supported preferences already differ from pristine defaults, it seeds the config file once from those supported values; otherwise it continues without creating the file until the first supported settings save.
5. After preferences load, the app applies the active theme and only then restores workspace state, preserving the existing startup contract.
6. When users change supported settings in the modal, `saveAppPreferences(_:)` validates the new runtime model, derives the portable subset, writes the config file atomically, persists the local runtime model, then updates `WorkspaceStore`.
7. When users manually reload, the service reuses the same decode, validate, project, persist, and diagnostics path as startup.
8. Existing sessions and tabs keep their persisted launch metadata. Portable settings change future default-profile resolution only; they do not retroactively rewrite restored tabs.

### External System Interactions

- **User config filesystem**
  - Stores the canonical settings file in the resolved XDG-style path.
  - Requires atomic file writes and predictable path resolution.

- **macOS shell / Finder boundary**
  - Supports reveal/open actions for the config file path from the settings UI.

- **Ghostty / terminal host boundary**
  - Continues to consume the active runtime appearance after settings projection completes.

## Implementation Design

### Core Interfaces

```go
type PortableSettingsConfigManager interface {
    BootstrapPortableSettings() (PortableSettingsApplyResult, error)
    ReloadPortableSettings() (PortableSettingsApplyResult, error)
    ExportPortableSettings(prefs AppPreferences) error
    PortableSettingsURL() string
}
```

```go
type PortableSettingsConfig struct {
    Version        int                          `json:"version"`
    Appearance     *PortableAppearanceConfig    `json:"appearance,omitempty"`
    Behavior       *PortableBehaviorConfig      `json:"behavior,omitempty"`
    DefaultProfile *string                      `json:"defaultProfile,omitempty"`
    Keybindings    []PortableKeybindingOverride `json:"keybindings,omitempty"`
}
```

```go
type PortableSettingsApplyResult struct {
    AppliedSections  []string
    RejectedSections map[string]string
    SeededFromSQLite bool
    FileMissing      bool
}
```

**Error handling conventions**
- Invalid JSON syntax rejects the file parse and falls back to current normalized SQLite state for that load.
- Section validation failures do not block unrelated valid sections.
- Keybindings validate as a set, not field by field.
- Built-in default profile values map through stable symbolic keys such as `plain`, `codex`, `claude`, and `opencode`.
- Unsupported local-only settings are omitted from the portable document instead of serialized loosely.
- Config export writes atomically and surfaces file-write failures explicitly.

### Data Models

| Entity | Fields | Notes |
| --- | --- | --- |
| `PortableSettingsConfig` | `version: Int`, `appearance: PortableAppearanceConfig?`, `behavior: PortableBehaviorConfig?`, `defaultProfile: String?`, `keybindings: [PortableKeybindingOverride]` | Canonical external document. Versioned from V1. |
| `PortableAppearanceConfig` | `themeID: String`, `terminalFontSize: Double` | Mirrors the supported appearance subset from `AppPreferences`. |
| `PortableBehaviorConfig` | `focusWorkspaceEnabled: Bool` | Keeps the current app-global focus setting portable. |
| `PortableKeybindingOverride` | `commandID: String`, `keyEquivalent: String`, `modifiers: [String]` | Uses stable managed command IDs rather than raw persistence JSON. |
| `PortableSettingsApplyResult` | `appliedSections: [String]`, `rejectedSections: [String: String]`, `seededFromSQLite: Bool`, `fileMissing: Bool` | Drives startup diagnostics and manual reload UI feedback. |
| `AppPreferences` | existing runtime fields | Remains the internal runtime model and SQLite-backed cache for supported fields. |

#### Storage Structures

- **External file**
  - Canonical path: `$XDG_CONFIG_HOME/atelier/settings.json` or `~/.config/atelier/settings.json`
  - Format: JSON document with explicit schema version
  - Writes: atomic temp-file + rename

- **SQLite runtime cache**
  - Reuse the existing `app_preferences` row
  - No schema changes in V1
  - Continue to store unsupported local-only settings locally when they already exist in current runtime behavior

#### Mapping Rules

- `themeID`, `terminalFontSize`, `focusWorkspaceEnabled`, and managed `keybindings` map directly between config DTOs and `AppPreferences`.
- `defaultProfile` maps only to built-in profile UUIDs or `nil` for `plain`.
- If `AppPreferences.defaultSessionShortcutID` points to a custom local profile, config export omits `defaultProfile` instead of trying to serialize a non-portable value.
- Runtime-only fields such as `id`, `updatedAt`, `hasUserOverride`, and `secretRef` never appear in the external document.

### API Endpoints

No HTTP or RPC endpoints are added. V1 extends the internal command surface instead.

| Call | Inputs | Output | Behavior |
| --- | --- | --- | --- |
| `loadAppPreferences()` | none | `AppPreferences` | Bootstraps portable settings at startup, seeds from SQLite when needed, updates runtime state, and returns the effective preferences. |
| `reloadPortableSettingsConfig()` | none | `PortableSettingsApplyResult` | Re-runs decode, validate, project, persist, and diagnostics without restarting the app. |
| `portableSettingsConfigURL()` | none | `URL` | Returns the canonical reveal/open path for UI actions. |
| `saveAppPreferences(_:)` | `AppPreferences` | `Void` | Validates the full runtime preferences model, exports the supported portable subset, persists local runtime state, and updates the store. |
| `availableSessionShortcuts()` | none | `[SessionShortcut]` | Unchanged for V1; custom and built-in profile definitions remain local-only. |
| `saveSessionShortcut(_:)` / `deleteSessionShortcut(id:)` / `resetBuiltInSessionShortcut(id:)` | existing inputs | existing outputs | Unchanged for V1 portability; custom profile definitions are not part of the portable config contract. |

## Integration Points

| Boundary | Purpose | Notes |
| --- | --- | --- |
| XDG config path resolution | Canonical file location | Resolve `$XDG_CONFIG_HOME` first, then fall back to `~/.config/atelier`. |
| Local filesystem | Portable config storage | Must support atomic writes and repeated idempotent reads. |
| Finder / shell open behavior | Reveal and open file path from the UI | Keeps the feature discoverable without a separate settings window. |

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
|-----------|-------------|---------------------|-----------------|
| `Sources/NativeMacADECore/Workspace/PortableSettingsConfig.swift` | new | Medium risk. New public config DTO, section result, and symbolic built-in profile mapping become the core contract. | Add the versioned document model and mapping helpers. |
| `Sources/NativeMacADECore/Workspace/PortableSettingsFileStore.swift` | new | Medium risk. New file IO seam owns XDG resolution and atomic writes. | Add locator, JSON read/write, and bootstrap helpers. |
| `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` | modified | Medium risk. Public command surface gains manual reload and config-path access. | Add the narrow portable-settings methods only. |
| `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` | modified | High risk. Owns startup bootstrap, config export, validation, and section-granularity diagnostics. | Centralize portable settings projection and export here. |
| `Sources/NativeMacADECore/Workspace/AppPreferences.swift` | modified | Low/medium risk. Core validation needs explicit bounds and portable helpers instead of UI-only constraints. | Add portable-settings validation helpers and stable field rules. |
| `Sources/NativeMacADECore/App/AppDependencyContainer.swift` | modified | Medium risk. Live wiring must provide the file-store dependency alongside the existing persistence store. | Inject the portable config file store into the command service. |
| `Sources/NativeMacADE/AppShell/ContentView.swift` | modified | Medium risk. The UI needs a reload trigger, last-result feedback, and config reveal actions without changing startup order. | Wire the new portable-settings controls into the existing modal host. |
| `Sources/NativeMacADE/AppShell/ConfigModalView.swift` and a small portable-settings section view | modified/new | Medium risk. The modal becomes the only visible host for power-user config actions. | Add reveal/reload/status UI and portability labels. |
| `Sources/NativeMacADE/AppShell/ConfigModalAgentProfilesSection.swift` | modified | Low risk. The section needs clear copy that custom command profiles stay local-only in V1. | Add labeling and unsupported-state hints only; do not redesign profile editing. |
| `Tests/NativeMacADECoreTests/*` and `Tests/NativeMacADEIntegrationTests/*` | modified/new | Medium risk. The feature depends on strong startup and projection coverage. | Add service and integration tests for seed, export, reload, and partial apply. |

## Testing Approach

### Unit Tests

- Validate XDG path resolution order and fallback behavior.
- Validate JSON decode and encode of `PortableSettingsConfig`.
- Validate symbolic built-in profile mapping for `plain`, `codex`, `claude`, and `opencode`.
- Validate terminal font-size bounds in core, not only in UI.
- Validate grouped keybinding conflict detection and grouped default-profile validation.
- Validate export omission rules for unsupported local-only values such as custom default profiles.
- Validate section-granularity apply results and diagnostics formatting.

**Mock requirements and boundaries**
- Use temporary directories or a small file-store double for file IO logic.
- Use in-memory persistence for pure validation and mapping paths.
- Do not mock the built-in profile catalog or command IDs; keep them as stable fixtures.

### Integration Tests

- **Bootstrap from existing local state**
  - No config file, non-default supported SQLite preferences present → seed file once and keep runtime values stable.
  - No config file, pristine defaults only → do not create a file until the first supported save.

- **Startup projection**
  - Config file present → supported settings apply before workspace restore.
  - Restored tabs keep their persisted launch command and arguments after config projection.

- **Manual reload**
  - Valid file edits apply successfully.
  - Mixed valid and invalid file content applies successful sections and reports rejected sections.
  - Repeated reload is idempotent when the file has not changed.

- **Save/export behavior**
  - Saving supported settings updates both runtime SQLite state and the portable file.
  - Saving unsupported local-only profile state leaves the portable document unchanged for that section.

- **Failure behavior**
  - Invalid JSON falls back to current runtime settings and records diagnostics.
  - File-write failures surface errors without silently pretending portability succeeded.

**Environment dependencies**
- Temporary SQLite databases.
- Temporary XDG config directories.
- No network or external service dependencies.

## Development Sequencing

### Build Order

1. **Add the portable config DTOs, symbolic built-in profile mapping, and apply-result types** — no dependencies.
2. **Add the XDG locator and atomic file store** — depends on step 1.
3. **Extend core validation and mapping rules for portable settings** — depends on step 1.
4. **Implement startup bootstrap, manual reload, and export orchestration inside `DefaultWorkspaceCommandService`** — depends on steps 1, 2, and 3.
5. **Minimally extend `WorkspaceCommandService` and wire the new dependency through `AppDependencyContainer`** — depends on step 4.
6. **Add modal-level reveal, reload, and status UI plus portability labels** — depends on steps 4 and 5.
7. **Add unit and integration coverage for seed, projection, partial apply, and export** — depends on steps 1 through 6.

### Technical Dependencies

- Built-in symbolic profile identifiers must be frozen before implementation begins.
- XDG path-resolution behavior must be fixed in V1 and treated as part of the public contract.
- No external infrastructure or third-party service is required.

## Monitoring and Observability

- **Key metrics to track**
  - `portable_settings_seeded_count`
  - `portable_settings_reload_count`
  - `portable_settings_reload_failure_count`
  - `portable_settings_export_count`
  - `portable_settings_export_failure_count`
  - `portable_settings_partial_apply_count`
  - `portable_settings_section_rejected_count`

- **Log events and structured fields**
  - `portable_settings_loaded`: `path`, `file_present`, `applied_section_count`, `rejected_section_count`
  - `portable_settings_seeded`: `path`, `seed_reason`
  - `portable_settings_reloaded`: `path`, `applied_sections`, `rejected_sections`
  - `portable_settings_section_rejected`: `section`, `reason`
  - `portable_settings_exported`: `path`, `exported_sections`
  - `portable_settings_export_failed`: `path`, `reason`

- **Alerting thresholds and escalation**
  - V1 keeps local-only observability; no remote alerting stack is introduced.
  - Repeated startup rejection of the same section in pilot use is release-blocking because it undermines the portability promise.
  - Manual reload failures should appear in both user-visible feedback and diagnostics logs.

## Technical Considerations

### Key Decisions

- **Use file-authoritative projection for supported settings**
  - **Rationale:** matches the approved portability model and gives users a true portable artifact.
  - **Trade-offs:** clearer external ownership over a more complex projection layer.
  - **Alternatives rejected:** SQLite-authoritative export/import, bidirectional live mirror.

- **Keep V1 portable scope inside `AppPreferences` plus built-in default profile selection**
  - **Rationale:** avoids multi-table batch persistence and keeps the first release inside existing runtime seams.
  - **Trade-offs:** narrower agent-profile portability over fuller settings parity.
  - **Alternatives rejected:** raw `SessionShortcut` export, custom profile command portability.

- **Use startup plus manual reload only**
  - **Rationale:** explicit reload is simpler and more predictable than live file watching.
  - **Trade-offs:** fewer automatic updates over lower conflict and watcher complexity.
  - **Alternatives rejected:** live file watchers, manual import/export-only behavior.

- **Use section-granularity partial apply with diagnostics**
  - **Rationale:** preserves valid settings while respecting grouped validation constraints.
  - **Trade-offs:** more diagnostics modeling over a simpler fail-fast path.
  - **Alternatives rejected:** all-or-nothing apply, field-level partial apply.

- **Do not change SQLite schema in V1**
  - **Rationale:** supported portable settings already fit the existing `app_preferences` boundary.
  - **Trade-offs:** reuse and lower migration risk over broader first-release scope.
  - **Alternatives rejected:** new config tables, reworking the persistence protocol around file-backed state.

### Known Risks

- **Existing-install bootstrap surprise**
  - **Likelihood:** Medium
  - **Risk:** file-authoritative behavior could surprise existing users if current local settings are not seeded cleanly.
  - **Mitigation:** seed once from supported non-default SQLite preferences when no config file exists.

- **File/runtime divergence after save failure**
  - **Likelihood:** Medium
  - **Risk:** if config export or runtime persistence fails mid-save, supported settings could momentarily diverge.
  - **Mitigation:** use atomic writes, a single orchestration path, explicit failure reporting, and startup/manual reload convergence.

- **Unsupported local-only profile expectations**
  - **Likelihood:** High
  - **Risk:** users may expect custom default profiles to travel even though V1 keeps them local.
  - **Mitigation:** label custom command profiles as local-only in the modal and omit them intentionally from the portable document.

- **Core validation gaps bypassed by file edits**
  - **Likelihood:** High
  - **Risk:** UI-only constraints such as font-size clamping are insufficient once users edit a file directly.
  - **Mitigation:** move portable-settings validation into the core service layer.

- **XDG path unfamiliarity on macOS**
  - **Likelihood:** Medium
  - **Risk:** users may not intuitively know where the file lives.
  - **Mitigation:** add reveal/open actions and display the active path in the settings UI.

## Architecture Decision Records

- [ADR-001: Single-Scope Personal Settings Config](adrs/adr-001.md) — Establishes a personal-global config boundary and rejects multi-scope V1.
- [ADR-002: Curated Portable Core Product Approach](adrs/adr-002.md) — Selects a power-user portability approach with broad but selective first-release coverage.
- [ADR-003: File-Authoritative Personal Config Projection](adrs/adr-003.md) — Makes the XDG-style config file the source of truth for supported portable settings and projects it into runtime state.
- [ADR-004: Stable Portable Config Schema With Built-In Agent Scope](adrs/adr-004.md) — Uses a versioned external DTO and limits V1 agent portability to built-in default selection.
- [ADR-005: Section-Granularity Partial Apply With Diagnostics](adrs/adr-005.md) — Applies independent config sections separately while validating related fields as a unit.
