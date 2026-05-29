---
status: pending
title: "Build the config modal appearance and shortcut sections, plus settings observability"
type: frontend
complexity: medium
dependencies:
  - task_04
  - task_05
  - task_06
---

# Task 07: Build the config modal appearance and shortcut sections, plus settings observability

## Overview
This task completes the V1 config modal by adding the appearance and top-level keyboard shortcut sections and by instrumenting the feature with local settings observability. It makes theme and keybinding changes visible immediately, keeps terminology clear between agent profiles and keyboard shortcuts, and ensures the feature ships with meaningful diagnostics instead of a follow-up cleanup phase.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The implementation MUST add appearance and shortcut sections to the in-app config modal while keeping them secondary to the Agent Profile section.
- 2. The implementation MUST let users choose one of the supported app themes — Dracula, OneDark, Catppuccin, or Cursor — and see successful theme changes apply immediately to both shell chrome and terminal appearance.
- 3. The implementation MUST limit editable keyboard shortcuts to `previousTab`, `nextTab`, `previousSession`, `nextSession`, `searchSessions`, `zoomInTerminal`, `zoomOutTerminal`, `toggleRightSidebar`, and `openSettings`, and support resetting bindings back to defaults.
- 4. The implementation MUST keep keyboard-shortcut terminology distinct from Agent Profile terminology throughout the modal.
- 5. The implementation MUST emit local observations for settings opened, saved, save failed, theme changed, and keybinding changed.
- 6. The implementation MUST leave previously saved preferences intact when a save fails validation.
- 7. The implementation SHOULD fit the existing sheet/modal interaction style and preserve launch/restore responsiveness.
</requirements>

## Subtasks
- [ ] 7.1 Finish the modal appearance section with theme selection, current-state display, and save/reset behavior.
- [ ] 7.2 Finish the managed shortcut section for the approved navigation, search, zoom, sidebar, and settings commands, including changed-versus-default state.
- [ ] 7.3 Add local settings-open, save, failure, theme-change, and keybinding-change observations to the shared logger and metrics surfaces.
- [ ] 7.4 Ensure successful saves refresh shell styling, terminal appearance, and top-level command bindings immediately.
- [ ] 7.5 Add regression coverage for theme switching, shortcut reset and failure handling, and settings observability output.

## Implementation Details
See the TechSpec sections **Monitoring and Observability**, **Keybinding Registry**, **Theme Runtime**, and **Known Risks**. Keep V1 shortcut scope bounded to `previousTab`, `nextTab`, `previousSession`, `nextSession`, `searchSessions`, `zoomInTerminal`, `zoomOutTerminal`, `toggleRightSidebar`, and `openSettings`, and keep observability local-first using the project’s existing logger and pilot-diagnostics patterns.

### Relevant Files
- `Sources/NativeMacADE/AppShell/ConfigModalView.swift` — Shared modal shell that must host the appearance and shortcut sections.
- `Sources/NativeMacADE/AppShell/ConfigModalAppearanceAndShortcutsSection.swift` — Likely new focused section view for theme and top-level keybinding UI.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Current shell still forces Nord/dark and contains hard-coded shortcut assumptions that must align with the new sections.
- `Sources/NativeMacADE/NativeMacADEApp.swift` — Runtime app-command bindings must reflect saved overrides.
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — Settings save/open surface used by the modal sections.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Validation, save success, and failure observation hooks belong here.
- `Sources/NativeMacADECore/Observability/PerformanceMetrics.swift` — Existing local metrics surface to extend with settings counters and diagnostics.
- `Sources/NativeMacADECore/Observability/WorkspaceLogger.swift` — Existing structured log surface to extend with settings events.

### Dependent Files
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — Save success and failure observability must be covered at the service layer.
- `Tests/NativeMacADECoreTests/PerformanceMetricsTests.swift` — Metrics expectations for new settings counters and diagnostics belong here.
- `Tests/NativeMacADEIntegrationTests/SQLiteWorkspaceMetadataStoreTests.swift` — Theme and keybinding preferences still need persistence round-trip coverage.
- `Tests/NativeMacADEIntegrationTests/TerminalHostIntegrationTests.swift` — Terminal appearance changes must remain correct once driven from the appearance section.
- `Tests/NativeMacADECoreTests/NordThemeTests.swift` — Existing Nord-only assumptions need to coexist with a broader runtime theme set.

### Related ADRs
- [ADR-001: Agent-First Scope for Config Modal Personalization](adrs/adr-001.md) — Keeps these sections secondary to agent control.
- [ADR-002: Guided Control Center Product Approach for Config Modal Customization](adrs/adr-002.md) — Requires this work for a “complete enough” switcher-facing V1.
- [ADR-003: In-App Modal Settings Host for Config Customization](adrs/adr-003.md) — Keeps these sections inside the in-window modal.
- [ADR-004: SQLite-Centered Global Preferences Layer](adrs/adr-004.md) — Persists theme and keybinding state through the shared preferences seam.
- [ADR-005: Reuse SessionShortcut as the Curated Agent Profile Model](adrs/adr-005.md) — Makes naming clarity important because keyboard shortcuts now share the modal with agent profiles.
- [ADR-006: Limited Keybinding Scope and Immediate Preference Application](adrs/adr-006.md) — Directly defines V1 scope and runtime behavior for these sections.

## Deliverables
- Appearance section for theme selection and reset.
- Keyboard shortcut section for the approved navigation, search, zoom, sidebar, and settings command set with changed/default state.
- Local metrics and structured logging for settings opens, saves, failures, theme changes, and keybinding changes.
- Immediate runtime refresh for theme and keybinding changes after successful save.
- Updated observability and runtime-behavior test coverage.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for appearance, keybinding, and settings observability behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Saving a theme-only change records one settings save and one theme-change observation, with no keybinding-change observation.
  - [ ] Saving managed keybinding overrides for tab navigation, session navigation, session search, terminal zoom, right-sidebar toggle, and settings records the expected changed-count and resetting one override clears only that override.
  - [ ] Duplicate or invalid top-level keybindings are rejected, emit one failure observation, and leave persisted preferences unchanged.
  - [ ] Opening the settings surface records one local open observation with context about project selection state.
- Integration tests:
  - [ ] Preferences round-trip preserves a selected theme from Dracula, OneDark, Catppuccin, or Cursor plus at least one managed keybinding override.
  - [ ] Switching themes updates both new terminal surfaces and existing attached host views without losing tab or session metadata.
  - [ ] After loading saved overrides, the managed navigation, search, zoom, sidebar, and settings commands resolve to overridden bindings; after reset, they resolve back to defaults.
  - [ ] Failed settings save leaves prior preferences intact and records a failure observation without blocking later successful saves.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Users can change the supported Dracula, OneDark, Catppuccin, and Cursor themes and the managed shortcut set, including terminal zoom, from the modal and see successful changes immediately.
- Settings opens, saves, failures, theme changes, and keybinding changes are visible through local metrics and logs.
- Keyboard-shortcut terminology stays distinct from Agent Profile terminology throughout the completed modal.
