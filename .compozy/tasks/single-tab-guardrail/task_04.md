---
status: pending
title: "Add Focus Workspace settings UI and active-state framing"
type: frontend
complexity: medium
dependencies:
  - task_01
---

# Task 04: Add Focus Workspace settings UI and active-state framing

## Overview
Add the user-facing settings and shell framing that make Focus Workspace feel intentional instead of accidental. This task gives users a dedicated place to enable the feature and a lightweight active-state cue, while leaving blocked affordances and rejection UX to task 05.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The Settings modal MUST gain a dedicated Focus Workspace section with calm, plain-language copy describing the feature.
- 2. The Settings UI MUST use the existing `loadAppPreferences()` / `saveAppPreferences(_:)` pipeline and MUST NOT introduce view-local-only preference state.
- 3. The shell MUST show a lightweight active-state cue when Focus Workspace is enabled.
- 4. The framing MUST stay truthful to the approved model: legacy multi-tab sessions can still exist, and Focus Workspace allows one terminal tab plus one optional file tab.
- 5. This task SHOULD keep scope to settings and active framing only; hiding creation affordances and blocked-action alerts belong to task 05.
</requirements>

## Subtasks
- [ ] 4.1 Add a dedicated Focus Workspace section to the existing Settings modal composition.
- [ ] 4.2 Persist the Focus Workspace toggle through the app-global preferences save/load flow.
- [ ] 4.3 Add explanatory copy that describes what Focus Workspace changes and what it does not change.
- [ ] 4.4 Add a lightweight active-state cue to the shell header when Focus Workspace is enabled.
- [ ] 4.5 Add regression and manual verification coverage for settings persistence and truthful active-state framing.

## Implementation Details
Use the TechSpec **"Shell/UI behavior"**, **"User Experience"**, and **"Known Risks"** sections as the source of truth for feature framing. Follow existing `ConfigModal*Section` patterns and keep the active cue lightweight; do not implement affordance hiding or blocked-action alert mapping here.

### Relevant Files
- `Sources/NativeMacADE/AppShell/ConfigModalView.swift` — current Settings modal composition point where the new Focus Workspace section should be inserted.
- `Sources/NativeMacADE/AppShell/ConfigModalFocusWorkspaceSection.swift` — new dedicated section file for the toggle, explanatory copy, and section-level feedback.
- `Sources/NativeMacADE/AppShell/ConfigModalAppearanceAndShortcutsSection.swift` — best existing pattern for loading/saving `AppPreferences` and rendering friendly settings feedback.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — `ActiveContextBanner` lives here and is the shell entry point for the active-state cue.
- `Sources/NativeMacADECore/Workspace/AppPreferences.swift` — source of truth for the persisted flag exposed in UI.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — existing settings save/load path should remain the only persistence route.

### Dependent Files
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — the shell cue reacts to `appPreferences` changes through observable store state.
- `Sources/NativeMacADECore/Workspace/FocusWorkspacePolicy.swift` — later tasks may use shared policy truthfulness to avoid overstating compliance in the shell.
- `Sources/NativeMacADE/NativeMacADEApp.swift` — later menu gating depends on the same enabled-state preference.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — preference save/load behavior remains the main automated backing for UI persistence.
- `Tests/NativeMacADECoreTests/AppShellStateTests.swift` — startup preference load continues to support correct active-state rendering after relaunch.

### Related ADRs
- [ADR-003: Broaden MVP through in-product framing before public positioning](../adrs/adr-003.md) — prioritizes in-product discoverability and framing first.
- [ADR-005: Persist Focus Workspace as an app-global preference in AppPreferences with a v6 migration](../adrs/adr-005.md) — ties the UI to the durable app-global preference model.
- [ADR-006: Allow one terminal tab plus one optional file tab and hide blocked terminal-tab affordances](../adrs/adr-006.md) — keeps framing truthful to the approved terminal/file model.
- [ADR-004: Enforce Focus Workspace at the command layer and grandfather existing multi-tab sessions](../adrs/adr-004.md) — prevents the active cue from implying retroactive session collapse.

## Deliverables
- A dedicated Focus Workspace settings section with explanatory copy and persisted toggle behavior.
- A lightweight shell-visible active-state cue.
- Truthful Focus Workspace wording that does not over-promise strict single-tab behavior for legacy or terminal+file sessions.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for settings persistence, cue visibility, and relaunch behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Saving Focus Workspace on preserves unrelated `AppPreferences` fields and updates observable store state.
  - [ ] Saving Focus Workspace off preserves unrelated `AppPreferences` fields and removes the shell active-state cue condition.
  - [ ] The active-state cue visibility logic renders only when `focusWorkspaceEnabled` is true.
- Integration tests:
  - [ ] Opening Settings shows a dedicated Focus Workspace section with explanatory copy and the current persisted toggle state.
  - [ ] Toggling Focus Workspace on or off updates the shell cue without requiring relaunch.
  - [ ] Relaunching the app preserves the toggle state and restores the active cue correctly when Focus Workspace is enabled.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Users can discover and toggle Focus Workspace from a dedicated Settings section.
- The shell shows a lightweight, truthful active-state cue that matches the persisted preference state.
