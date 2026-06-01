---
status: pending
title: Settings UI and runtime appearance application
type: frontend
complexity: high
dependencies:
  - task_01
  - task_02
---

# Task 03: Settings UI and runtime appearance application

## Overview

This task turns the new appearance-selection model into visible product behavior. It updates the Settings picker to the approved System-first single-list design, wires runtime theme resolution through the root shell and terminal update path, preserves generic light/dark editor syntax theming, and verifies that startup plus runtime switching behave correctly.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST replace the existing grouped Dark/Light appearance picker with a single ordered list that shows System first and then the curated preset list.
2. MUST route root runtime appearance application through the shared effective-theme resolver and stop forcing a fixed `preferredColorScheme` when the persisted selection is `system`.
3. MUST keep `FileEditorHostView` on generic light/dark syntax theming in V1 while ensuring shell and terminal visuals use the resolved concrete preset.
4. MUST verify startup behavior, terminal appearance updates, and live System-mode switching with automated coverage where practical and manual macOS appearance QA where necessary.
</requirements>

## Subtasks
- [ ] 3.1 Update the appearance selector UI to render a synthetic System option first and preserve the approved preset ordering after it.
- [ ] 3.2 Update runtime shell appearance application to use the effective-theme resolver instead of concrete-only direct lookup.
- [ ] 3.3 Ensure terminal appearance updates stay synchronized for startup, explicit theme changes, and System-driven light/dark changes.
- [ ] 3.4 Keep the editor on generic light/dark syntax mapping and verify that V1 does not introduce preset-specific editor theming.
- [ ] 3.5 Add integration coverage and manual verification notes for startup, selection changes, and live macOS appearance switching.

## Implementation Details

Follow the TechSpec sections **System Architecture → Settings Appearance UI**, **System Architecture → App Shell Runtime**, **System Architecture → Terminal Host Runtime**, and **Testing Approach → Integration Tests**. Keep the UI Settings-first, avoid adding a quick-switch surface, and do not expand the work into richer editor-specific or preview-card theming flows.

### Relevant Files
- `Sources/NativeMacADE/AppShell/ConfigModalAppearanceAndShortcutsSection.swift` — Current grouped picker, draft synchronization, and autosave seam for appearance settings.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Root shell appearance application, startup hook, terminal update path, and editor host integration.
- `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift` — Applies `TerminalAppearance` to existing and new terminal surfaces.
- `Sources/NativeMacADECore/App/AppShellState.swift` — Startup ordering seam where preferences load before restore and runtime appearance application.
- `Tests/NativeMacADEIntegrationTests/TerminalHostIntegrationTests.swift` — Best integration-test home for startup and runtime terminal appearance behavior.
- `Tests/NativeMacADECoreTests/AppShellStateTests.swift` — Useful test home for startup-order assertions if root startup behavior needs focused coverage.
- `.compozy/tasks/light-dark-themes/_techspec.md` — Authoritative reference for runtime appearance flow, editor scope, and manual QA expectations.

### Dependent Files
- `Sources/NativeMacADECore/Theme/AppTheme.swift` — Supplies the shared effective-theme resolver and curated preset ordering used by the UI and runtime.
- `Sources/NativeMacADECore/Workspace/AppPreferences.swift` — Provides the persisted appearance selection model consumed by Settings.
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — Existing concrete-only theme shortcut must no longer bypass the shared runtime resolver.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Settings autosave and startup load behavior must already accept `system` for this UI to function.
- `Package.swift` — Current test-target layout limits direct app-UI automation and informs the reliance on integration tests plus manual QA.

### Related ADRs
- [ADR-001: Scope V1 as Curated Appearance Presets and Polish](../adrs/adr-001.md) — Keeps this work within curated appearance improvement rather than broad theming.
- [ADR-002: Use a Settings-First Appearance Baseline with System as the Lead Choice](../adrs/adr-002.md) — Defines the System-first Settings UI contract.
- [ADR-004: Keep V1 Theme Expansion Inside the Existing Catalog and Generic Editor Mapping](../adrs/adr-004.md) — Requires the single-list selector and generic editor theming in V1.
- [ADR-005: Centralize Effective Theme Resolution in the Theme Domain](../adrs/adr-005.md) — Requires runtime consumers to use the shared resolver rather than ad hoc logic.

## Deliverables
- Updated Settings appearance selector with System first and curated presets following the approved order.
- Root runtime theme application wired to the effective-theme resolver for shell and terminal behavior.
- Preserved generic light/dark editor syntax behavior under the new runtime appearance contract.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for startup and runtime appearance behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] The appearance-option ordering helper returns System first, followed by the curated preset list in the approved order.
  - [ ] Runtime theme selection uses the effective-theme resolver instead of direct concrete-only preset lookup where selection-based behavior is involved.
  - [ ] `FileEditorHostView` continues to map editor syntax theme from light/dark environment state rather than preset-specific IDs.
- Integration tests:
  - [ ] Launching with persisted `themeID = system` applies terminal appearance matching the current runtime light/dark scheme before restored terminal surfaces appear.
  - [ ] Changing appearance from System to a concrete preset updates terminal appearance immediately without breaking the Settings autosave flow.
  - [ ] Changing appearance from a concrete preset back to System preserves `themeID = system` while applying the correct resolved concrete terminal appearance.
  - [ ] If the harness supports runtime scheme changes, switching macOS light/dark while `themeID = system` updates existing terminal surfaces without requiring relaunch.
  - [ ] If live runtime scheme flipping is not fully automatable, manual QA verifies System-mode behavior during macOS light/dark switching.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Settings exposes a single System-first appearance selector that persists one selection ID and matches the approved product behavior.
- Shell and terminal appearance follow the effective runtime theme correctly, while editor syntax theming remains generic light/dark in V1.
