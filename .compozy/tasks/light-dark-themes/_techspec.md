# Light and Dark Theme Expansion

## Executive Summary

This TechSpec implements the PRD sections **Settings-First Appearance Control**, **System-Led Theme Selection**, **Curated Preset Expansion**, **Whole-Experience Appearance Consistency**, and **Reliable Appearance Memory** by extending Another ADE’s existing appearance pipeline rather than introducing a new settings subsystem. The design keeps appearance inside the current `AppPreferences.themeID` → `WorkspaceStore` → `ContentView` / `TerminalHostController` path, adds a reserved persisted selection value for `system`, and resolves that selection into a concrete runtime `AppTheme` through a central helper in the Theme domain.

The primary technical trade-off is seam reuse versus explicit model richness. Reusing the existing string-based preference seam keeps the change small, avoids any SQLite schema migration, and limits V1 to additive updates in the current architecture. In return, the runtime must distinguish persisted selection from effective concrete theme, codify the “first light / first dark preset” contract for System mode, and accept that editor syntax theming remains generic light/dark instead of preset-specific in V1.

## System Architecture

### Component Overview

- **Theme Domain**
  - `AppTheme` remains the catalog of concrete presets.
  - It gains the System-selection constants and a central effective-theme resolver.
  - It becomes the only runtime seam that turns a persisted selection ID plus current system light/dark state into a concrete `AppTheme`.

- **Preferences Model and Validation**
  - `AppPreferences.themeID` remains the only persisted appearance field.
  - Valid values expand from concrete preset IDs only to concrete preset IDs plus the reserved `system` selection.
  - Fresh defaults and invalid-theme repair both fall back to `system`.

- **Settings Appearance UI**
  - `ConfigModalAppearanceAndShortcutsSection` remains the only V1 appearance-management surface.
  - The theme selector becomes a single ordered list with a synthetic **System** option first, followed by curated concrete presets.
  - The picker still saves one string selection value.

- **App Shell Runtime**
  - `ContentView` stops treating the stored theme ID as always concrete.
  - It resolves the effective theme from the stored selection plus the current SwiftUI/macOS color scheme.
  - It continues to inject shell palette, tint, and font-size environment values into the view tree.

- **Terminal Host Runtime**
  - `TerminalHostController` remains the sink for `TerminalAppearance`.
  - Existing and newly attached terminal surfaces update whenever the effective concrete theme changes, including System-driven light/dark switches.

- **Editor Host Runtime**
  - `FileEditorHostView` stays on the current generic `Theme.defaultDark` / `Theme.defaultLight` mapping.
  - V1 does not introduce preset-specific editor syntax themes.

- **Persistence and Startup**
  - `DefaultWorkspaceCommandService` remains the single validation, repair, persistence, and metrics seam for appearance settings.
  - SQLite storage stays in the existing `app_preferences` row with no new table or column.

### Data Flow

1. On launch, `AppShellStartupCoordinator` loads `AppPreferences` through `WorkspaceCommandService`.
2. `DefaultWorkspaceCommandService` validates the stored `themeID`; unknown or stale values repair to `system`.
3. `ContentView` reads `store.appPreferences.themeID` and the current SwiftUI/macOS color scheme.
4. `AppTheme.resolveEffective(selectionID:systemScheme:)` returns the concrete runtime theme.
5. `ContentView` injects the resolved shell palette and font-size environment values into the view tree.
6. If the selection is a concrete preset, `ContentView` forces `preferredColorScheme` to the preset’s light/dark scheme.
7. If the selection is `system`, `ContentView` does not force `preferredColorScheme`, so the window follows macOS appearance naturally.
8. `ContentView.applyActiveTheme()` pushes the resolved `terminalAppearance` into `TerminalHostController`.
9. `FileEditorHostView` continues to derive syntax theme from the resulting `@Environment(\.colorScheme)` value, not from the concrete preset ID.

### External System Interactions

- **SwiftUI / macOS appearance environment**
  - Supplies the runtime light/dark state used when the persisted selection is `system`.
  - No authentication or external service boundary applies.

- **Terminal host boundary**
  - Receives the resolved `TerminalAppearance` for existing and future terminal surfaces.
  - No new retry or backoff behavior is introduced.

- **CodeEditorView boundary**
  - Continues to accept only generic light/dark editor themes from environment state.
  - V1 does not attempt deeper preset-specific integration.

## Implementation Design

### Core Interfaces

The concrete implementation will be Swift. The Go-like contracts below describe the logical seams other components depend on.

```go
type WorkspaceCommandService interface {
    LoadAppPreferences() (AppPreferences, error)
    SaveAppPreferences(prefs AppPreferences) error
}
```

```go
type ThemeResolutionRequest struct {
    SelectionID  string
    SystemScheme string // light | dark
}

type ResolvedTheme struct {
    ThemeID     string
    ColorScheme string
}
```

**Error handling conventions**
- `system` is a valid persisted appearance selection and must not be treated as corruption.
- Unknown or stale concrete theme IDs repair to `system`.
- The System option must stay selected in Settings even while the effective concrete preset changes underneath it.
- Runtime consumers must use the effective-theme resolver instead of direct concrete preset lookup when appearance selection is involved.
- V1 does not add retry loops, remote fallbacks, or secondary persistence paths for appearance.

### Data Models

| Entity | Fields | Notes |
| --- | --- | --- |
| `AppPreferences` | existing `id`, `themeID`, `defaultSessionShortcutID`, `terminalFontSize`, `keybindings`, `updatedAt` | `themeID` now stores either a concrete preset ID or the reserved `system` selection. |
| `AppTheme` | existing `id`, `displayName`, `colorScheme`, `shellPalette`, `terminalAppearance` | Remains a concrete preset only. Gains constants and helper methods for effective resolution. |
| `AppearanceOption` (UI-local helper) | `id`, `displayName`, `kind`, `colorScheme` | Optional private UI helper for building the single ordered list with synthetic System first. |
| `WorkspaceStore` | existing fields plus `appPreferences` | Remains the observable source of persisted preference state. Runtime theme resolution no longer depends on `activeTheme` as a concrete-only shortcut. |

#### Storage Structures

- **`app_preferences.theme_id`**
  - Existing `TEXT NOT NULL` column remains unchanged.
  - Valid values become:
    - `system`
    - any ID present in `AppTheme.catalog`

- **Schema migration**
  - No SQLite schema migration is required.
  - No `user_version` bump is required.
  - Existing persisted concrete theme IDs remain valid.
  - Fresh defaults and repair fallback paths switch to `system`.

#### Theme-Domain Additions

- `AppTheme.systemSelectionID = "system"`
- `AppTheme.supportedSelectionIDs`
- `AppTheme.defaultSelectionID = systemSelectionID`
- `AppTheme.firstLightPreset`
- `AppTheme.firstDarkPreset`
- `AppTheme.resolveEffective(selectionID:systemScheme:)`

#### Deliberate Exclusions

- No new `appearance_preferences` table
- No separate light/dark System-pair persistence
- No preset-specific editor syntax mapping
- No external theme manifests or plugin-style theme loading
- No quick-switch surface outside Settings in V1

### API Endpoints

No HTTP or RPC endpoints are added. V1 extends the internal command surface only.

| Call | Inputs | Output | Behavior |
| --- | --- | --- | --- |
| `loadAppPreferences()` | none | `AppPreferences` | Loads preferences, normalizes invalid selections, and updates the store. |
| `saveAppPreferences(_:)` | `AppPreferences` | `Void` | Validates `themeID`, persists the selection, updates the store, and emits metrics/logs. |
| `AppTheme.resolveEffective(selectionID:systemScheme:)` | selection ID, current runtime scheme | `AppTheme` | Resolves the concrete runtime theme for shell and terminal use. |

## Integration Points

| Boundary | Purpose | Behavior |
| --- | --- | --- |
| SwiftUI/macOS `colorScheme` environment | Supplies current system light/dark state | Drives effective theme resolution when selection is `system` |
| `TerminalHostController` | Applies runtime terminal appearance | Receives updated `TerminalAppearance` whenever effective theme changes |
| `CodeEditorView` | Applies editor syntax theme | Continues using generic light/dark mapping from environment color scheme |

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
|-----------|-------------|---------------------|-----------------|
| `Sources/NativeMacADECore/Theme/AppTheme.swift` | modified | High risk. Becomes the central effective-theme resolver and System-selection contract. | Add reserved-selection constants, first-light/first-dark helpers, supported selection IDs, and effective resolver logic. |
| `Sources/NativeMacADECore/Workspace/AppPreferences.swift` | modified | Medium risk. Default and validation semantics change while schema stays stable. | Update default selection ID and supported-selection rules to include `system`. |
| `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` | modified | Medium risk. Existing concrete-only `activeTheme` usage becomes insufficient for System mode. | Remove or stop using direct concrete-only runtime access and route consumers through the effective resolver. |
| `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` | modified | High risk. Validation, repair, metrics, and save flows must all accept `system`. | Update validation, stale-ID repair, logging, and save/load behavior for reserved selection IDs. |
| `Sources/NativeMacADE/AppShell/ConfigModalAppearanceAndShortcutsSection.swift` | modified | Medium risk. Theme picker becomes a synthetic System + preset list while keeping autosave behavior stable. | Insert System first, preserve ordered preset list, and keep selection persistence bound to one string ID. |
| `Sources/NativeMacADE/AppShell/ContentView.swift` | modified | High risk. Root appearance resolution and terminal updates must react to both preference changes and system appearance changes. | Resolve effective theme from selection + runtime scheme, conditionally apply `preferredColorScheme`, and refresh terminal appearance on changes. |
| `Sources/NativeMacADE/AppShell/ContentView.swift` (`FileEditorHostView`) | unchanged or low-touch modified | Low risk. Editor remains generic light/dark in V1. | Preserve current environment-driven editor theme behavior and verify it still works under System mode. |
| `Tests/NativeMacADECoreTests/*` | modified/new | Medium risk. Resolver and validation behavior need broader coverage. | Add unit tests for System selection, first-light/first-dark mapping, and default/repair behavior. |
| `Tests/NativeMacADEIntegrationTests/*` | modified/new | Medium risk. Startup, persistence, and terminal update behavior must stay correct. | Add integration tests for persisted System selection, repair fallback, and terminal appearance application. |

## Testing Approach

### Unit Tests

- Validate `AppTheme.resolveEffective(selectionID:systemScheme:)` for:
  - explicit light preset
  - explicit dark preset
  - `system` with light runtime scheme
  - `system` with dark runtime scheme
- Validate that `AppTheme.supportedSelectionIDs` includes `system`.
- Validate the first-light / first-dark contract used by System mode.
- Validate that `AppPreferences.defaults.themeID == system`.
- Validate that settings validation accepts `system` and rejects truly unknown IDs.
- Validate that repair fallback returns `system` for stale or invalid theme IDs.

**Mock requirements and boundaries**
- Use pure unit tests for resolver behavior.
- Keep the catalog concrete; do not mock preset ordering.
- Do not mock macOS appearance at this layer; pass explicit light/dark values into the resolver.

### Integration Tests

- **Preferences round-trip**
  - Save `themeID = system` and reload it through SQLite.
  - Confirm the selection remains `system` after persistence.

- **Startup resolution**
  - Launch with persisted `system` selection and verify the resolved theme matches the current runtime light/dark scheme.
  - Confirm startup still applies terminal appearance before restored terminal surfaces become active.

- **Repair behavior**
  - Seed a stale theme ID, load preferences, and verify the selection repairs to `system`.

- **Terminal update behavior**
  - Verify explicit theme selection updates terminal appearance immediately.
  - Verify System selection resolves to the correct terminal appearance for the supplied runtime scheme.
  - If the existing integration harness can drive runtime scheme changes directly, add one test that flips system light/dark while selection remains `system` and verifies existing terminal surfaces update.
  - If that harness path is not practical without UI automation, keep the resolver and terminal-application behavior automated and require a manual QA pass for live OS switching.

- **Regression coverage**
  - Existing concrete preset IDs continue to load and apply unchanged.
  - No SQLite migration is required for existing persisted preferences.

**Environment dependencies**
- Temporary SQLite databases
- Existing in-memory or fake terminal host seams
- Manual macOS light/dark switching verification for the final live-switch user path if no non-UI test seam is practical

## Development Sequencing

### Build Order

1. **Extend the Theme domain with System-selection constants, first-light/first-dark helpers, curated preset additions, and the effective resolver** — no dependencies.
2. **Update `AppPreferences` defaults and supported-selection validation to include `system`** — depends on step 1.
3. **Update `DefaultWorkspaceCommandService` load/save/repair behavior so `system` is valid and stale IDs repair to `system`** — depends on steps 1 and 2.
4. **Update the Settings appearance picker to show a synthetic System option first and persist the reserved selection ID** — depends on steps 1 through 3.
5. **Update `ContentView` to resolve the effective runtime theme from persisted selection plus current runtime scheme, and conditionally stop forcing `preferredColorScheme` in System mode** — depends on steps 1 through 4.
6. **Confirm `FileEditorHostView` remains on generic light/dark syntax theming under the new runtime behavior** — depends on step 5.
7. **Add unit and integration coverage for System selection, startup resolution, repair fallback, and terminal updates; finalize manual QA for live macOS appearance switching** — depends on steps 1 through 6.

### Technical Dependencies

- The curated preset IDs and their final order must be frozen before implementation because System mode depends on the first-light / first-dark contract.
- Runtime consumers must switch to the shared effective-theme resolver instead of direct concrete-only preset lookup.
- The design assumes SwiftUI/macOS `colorScheme` changes are observable at the root shell. If that proves unreliable in a spike, the fallback is to bridge the current system appearance into app state explicitly while keeping the same `AppTheme` resolver contract.

## Monitoring and Observability

- **Key metrics to track**
  - `settings_opened_count`
  - `settings_saved_count`
  - `settings_save_failure_count`
  - `theme_changed_count`
  - `effective_theme_applied_count`
  - `theme_repair_count`

- **Log events and structured fields**
  - `settings_saved`: `theme_id`, `changed_keybinding_count`
  - `theme_applied`: `selection_id`, `resolved_theme_id`, `source=user_selection|system_appearance|startup|repair`
  - `settings_save_failed`: `reason`, `field`
  - `theme_repaired`: `invalid_theme_id`, `fallback_theme_id`

- **Alerting thresholds and escalation**
  - V1 remains local-only; no remote alerting stack is introduced.
  - Repeated settings-save failures or unresolved theme-application errors during pilot use are release-blocking because they undermine the feature’s core promise.

## Technical Considerations

### Key Decisions

- **Persist System as a reserved `themeID`**
  - **Rationale:** keeps appearance inside the existing `app_preferences` seam and avoids schema changes.
  - **Trade-off:** string-based selection stays lightweight but requires explicit validation and runtime resolution.
  - **Alternatives rejected:** separate System-pair persistence, UI-only transient System behavior.

- **Use `system` as the default and repair fallback**
  - **Rationale:** aligns fresh installs and recovery behavior with the PRD’s System-first experience.
  - **Trade-off:** repaired users move to OS-following behavior rather than a fixed preset.
  - **Alternatives rejected:** keep Cursor as default, leave invalid selections unrepaired.

- **Centralize effective resolution in `AppTheme`**
  - **Rationale:** creates one testable seam for selection ID + runtime scheme → concrete preset.
  - **Trade-off:** call sites must adopt the resolver instead of relying on direct concrete lookup.
  - **Alternatives rejected:** resolve inside `WorkspaceStore`, resolve ad hoc in `ContentView`.

- **Keep the selector as a single System-first list**
  - **Rationale:** matches the approved V1 UI and avoids introducing separate mode/preset state.
  - **Trade-off:** System behavior depends on ordered preset semantics instead of a richer pair-selection model.
  - **Alternatives rejected:** two-stage mode + preset UI, preview-card selector.

- **Keep editor theming generic light/dark in V1**
  - **Rationale:** preserves YAGNI and avoids expanding the feature into editor-specific theme mapping work.
  - **Trade-off:** preset fidelity stops at shell and terminal in V1.
  - **Alternatives rejected:** preset-specific editor mapping, editor exclusion from appearance scope.

### Known Risks

- **Catalog-order drift**
  - Reordering presets can silently change System behavior.
  - **Mitigation:** codify and test the first-light / first-dark contract.

- **Resolver bypass**
  - A runtime caller may keep using direct `AppTheme.resolve(id:)` and miss System semantics.
  - **Mitigation:** route all appearance-selection paths through the effective resolver and update affected tests.

- **Live OS-switch propagation**
  - SwiftUI environment changes may not propagate exactly as expected for all runtime surfaces.
  - **Mitigation:** automate resolver and terminal-application coverage, then finish with manual macOS light/dark verification.

- **Preset/editor mismatch**
  - Some curated presets may still feel inconsistent because editor syntax remains generic light/dark.
  - **Mitigation:** keep shell, overlays, and terminal polished enough that the remaining mismatch is acceptable in V1.

- **Accessibility regressions**
  - New light presets can expose weak contrast or inconsistent states.
  - **Mitigation:** include contrast-focused manual QA and keep the curated set small.

## Architecture Decision Records

- [ADR-001: Scope V1 as Curated Appearance Presets and Polish](adrs/adr-001.md) — Keeps the feature scoped to curated appearance improvement instead of a broad theming system.
- [ADR-002: Use a Settings-First Appearance Baseline with System as the Lead Choice](adrs/adr-002.md) — Selects a Settings-first MVP that includes System while keeping the release disciplined.
- [ADR-003: Persist System Appearance as a Reserved Theme Selection](adrs/adr-003.md) — Stores System as a reserved selection ID and uses it as the default and repair fallback.
- [ADR-004: Keep V1 Theme Expansion Inside the Existing Catalog and Generic Editor Mapping](adrs/adr-004.md) — Extends `AppTheme.catalog` directly and keeps editor syntax theming at generic light/dark in V1.
- [ADR-005: Centralize Effective Theme Resolution in the Theme Domain](adrs/adr-005.md) — Adds a shared resolver that maps persisted selection plus runtime scheme to a concrete `AppTheme`.
