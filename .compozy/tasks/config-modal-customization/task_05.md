---
status: pending
title: "Add settings host, startup preference load, and top-level command registry"
type: frontend
complexity: medium
dependencies:
  - task_03
  - task_04
---

# Task 05: Add settings host, startup preference load, and top-level command registry

## Overview
This task adds the main-window settings host and the app-level command wiring that makes the feature discoverable and live at startup. It ensures persisted preferences load before restore completes, exposes `Settings…` through both keyboard and visible UI entry points, and replaces hard-coded top-level command bindings with a small registry-backed runtime model.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The implementation MUST host settings as an in-app modal in the main window rather than a separate Settings scene.
- 2. The implementation MUST load persisted app preferences before restore finishes and before the restore overlay is dismissed.
- 3. The implementation MUST provide both a `Settings…` command (`⌘,`) and a visible in-window entry point that open the same modal host.
- 4. The implementation MUST replace hard-coded top-level shortcuts with a registry-driven binding model for `previousTab`, `nextTab`, `previousSession`, `nextSession`, `searchSessions`, `zoomInTerminal`, `zoomOutTerminal`, `toggleRightSidebar`, and `openSettings`.
- 5. The implementation MUST remove duplicate managed shortcut declarations so the runtime registry is the single source of truth.
- 6. The implementation SHOULD apply theme and keybinding changes immediately while leaving existing restored tab launch intent unchanged.
- 7. The implementation SHOULD fall back safely when preferences are missing, stale, or invalid without blocking launch.
</requirements>

## Subtasks
- [ ] 5.1 Add shared app-shell state for presenting and dismissing the settings modal.
- [ ] 5.2 Add the `Settings…` command and one obvious in-window entry point for the modal.
- [ ] 5.3 Load persisted preferences during startup before restore/UI unblocking finishes.
- [ ] 5.4 Introduce the small managed command registry and resolve runtime shortcuts from persisted preferences, including terminal zoom bindings.
- [ ] 5.5 Reconcile menu and toolbar command surfaces so managed bindings come from one source of truth.
- [ ] 5.6 Add launch-time and command-resolution regression coverage.

## Implementation Details
See the TechSpec sections **App Shell**, **Data Flow**, **High-Level Technical Constraints**, and **Technical Dependencies**. Keep the registry bounded to `previousTab`, `nextTab`, `previousSession`, `nextSession`, `searchSessions`, `zoomInTerminal`, `zoomOutTerminal`, `toggleRightSidebar`, and `openSettings`, and avoid rebuilding the app into a general settings platform.

### Relevant Files
- `Sources/NativeMacADE/NativeMacADEApp.swift` — Current top-level command menu with hard-coded bindings and no settings command.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Root startup flow, modal host location, and current hard-coded UI shortcut assumptions.
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — Settings load/save surface consumed by startup and modal host code.
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — Observable preferences state for app-wide theme and keybinding resolution.
- `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift` — Restored and new surfaces should respect loaded appearance by the time startup completes.
- `Sources/NativeMacADECore/Commands/AppCommandRegistry.swift` — Likely new home for stable app-command IDs and default bindings.
- `Tests/NativeMacADECoreTests/AppCommandRegistryTests.swift` — Best fit for registry default/override behavior.
- `Tests/NativeMacADEIntegrationTests/TerminalHostIntegrationTests.swift` — Best fit for startup preference application across restore.

### Dependent Files
- `Sources/NativeMacADE/AppShell/ConfigModalView.swift` — Later UI tasks depend on the modal host and entry-point wiring created here.
- `Sources/NativeMacADECore/App/AppDependencyContainer.swift` — Live app wiring may need to expose additional app-shell state or registry support.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Startup and restore behavior depend on preferences being loaded before the shell unblocks.
- `Tests/NativeMacADEIntegrationTests/SQLiteWorkspaceMetadataStoreTests.swift` — Launch-time behavior depends on sane seeded and persisted preferences data.

### Related ADRs
- [ADR-003: In-App Modal Settings Host for Config Customization](adrs/adr-003.md) — Directly defines the settings host approach.
- [ADR-004: SQLite-Centered Global Preferences Layer](adrs/adr-004.md) — Requires startup preference loading through the shared persistence seam.
- [ADR-005: Reuse SessionShortcut as the Curated Agent Profile Model](adrs/adr-005.md) — Settings host still surfaces profile-backed defaults.
- [ADR-006: Limited Keybinding Scope and Immediate Preference Application](adrs/adr-006.md) — Directly constrains the command registry and immediate-update behavior.
- [ADR-007: Centralize New-Session Bootstrap in WorkspaceCommandService](adrs/adr-007.md) — Prevents startup/modal work from reintroducing split session bootstrap assumptions.

## Deliverables
- In-app settings modal host in the main window.
- `Settings…` app command plus a visible in-window entry point.
- Startup preference load before restore completion.
- Top-level app-command registry with runtime binding resolution and duplicate shortcut cleanup.
- Updated launch-time and command-resolution test coverage.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for startup preference load and runtime command bindings **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Registry defaults resolve correctly for `previousTab`, `nextTab`, `previousSession`, `nextSession`, `searchSessions`, `zoomInTerminal`, `zoomOutTerminal`, `toggleRightSidebar`, and `openSettings`.
  - [ ] Persisted overrides replace only the targeted app commands and reset cleanly to defaults.
  - [ ] Duplicate or unknown override entries are rejected or ignored predictably.
  - [ ] App-shell startup state does not clear the restore overlay before preference load completes or safely falls back.
- Integration tests:
  - [ ] Launch with a saved non-default theme and restore snapshot; restored terminal surfaces use the loaded appearance on startup.
  - [ ] Launch with saved keybinding overrides; top-level command bindings resolve to overrides after load, then revert after reset.
  - [ ] The `Settings…` command and visible in-window entry open the same modal host.
  - [ ] Unknown theme IDs or stale default-profile references do not block restore or create extra tabs.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Preferences are applied before the restored workspace becomes interactive.
- `Settings…` is reachable by both keyboard and visible UI and opens one shared modal host.
- All managed navigation, search, zoom, sidebar, and settings command bindings resolve through one runtime registry.
