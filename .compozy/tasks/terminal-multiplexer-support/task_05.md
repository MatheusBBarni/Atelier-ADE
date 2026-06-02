---
status: pending
title: Settings UI, copy, and continuity cues
type: frontend
complexity: high
dependencies:
  - task_02
  - task_04
---

# Task 05: Settings UI, copy, and continuity cues

## Overview

This task exposes continuity as an understandable, opt-in Focus Workspace extension instead of a hidden restore behavior. It adds the child toggle, truthful explanation copy, and lightweight active cues needed to help users understand why they were returned to a particular context without implying deeper multiplexer or process awareness.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST render continuity as a child option under the existing Focus Workspace setting and MUST disable or clear it when the parent Focus Workspace toggle is off.
2. MUST keep continuity copy and active-cue wording centralized in `FocusWorkspacePresentation` so settings, banners, and related surfaces use one truthful explanation source.
3. MUST explain that continuity remembers app-owned project, session, and tab context only, and MUST NOT imply live tmux, pane, or external process reattachment.
4. SHOULD reuse existing settings, active-banner, session-row, and session-search correction surfaces rather than adding a new command, dashboard, or palette dedicated to continuity.
5. MUST keep the settings and cue surfaces accessible for keyboard-first usage and standard macOS accessibility support.
</requirements>

## Subtasks
- [ ] 5.1 Add the continuity child toggle to the Focus Workspace settings section using the existing async preference-save pattern.
- [ ] 5.2 Add centralized presentation strings for continuity labels, help text, and active-cue wording.
- [ ] 5.3 Reflect the continuity state through existing banner or focus-cue surfaces so restore behavior is understandable after return.
- [ ] 5.4 Reuse existing correction surfaces for confirmation or course correction when the restored target is not what the user expected.
- [ ] 5.5 Add UI contract and presentation regression coverage for the child toggle, copy, and cue behavior.

## Implementation Details

Use the TechSpec sections **System Architecture → Preferences and settings layer**, **System Architecture → Presentation and correction layer**, **PRD → Continuity Cues and Trust Signals**, **PRD → Supportive Return-to-Context Navigation**, and **Development Sequencing → Build Order (step 5)**. Keep copy grounded in the product boundary from ADR-001 and prefer small changes to existing surfaces over creating a new continuity-specific UI shell.

### Relevant Files
- `Sources/NativeMacADECore/Workspace/FocusWorkspacePresentation.swift` — Source of truth for continuity setting copy, help text, and active-cue wording.
- `Sources/NativeMacADE/AppShell/ConfigModalFocusWorkspaceSection.swift` — Existing Focus Workspace settings surface where the child toggle and dependency behavior should live.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Hosts the active context banner, focus cue view, and session search or row surfaces reused as correction cues.
- `Tests/NativeMacADECoreTests/FocusWorkspacePresentationTests.swift` — Unit coverage for centralized continuity labels, help text, and active-cue strings.
- `Tests/NativeMacADEIntegrationTests/FocusWorkspaceUIContractIntegrationTests.swift` — Contract tests for child-toggle rendering, identifiers, and cue wiring.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — End-to-end setting persistence and relaunch coverage for the visible continuity workflow.

### Dependent Files
- `Sources/NativeMacADECore/Workspace/AppPreferences.swift` — UI depends on the finalized persisted continuity preference contract.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Settings save behavior and restore cues depend on normalized continuity state and restore application.
- `Sources/NativeMacADE/AppShell/SessionTerminalSummaryBuilder.swift` — Existing session-level terminal summaries may be reused or indirectly affected by continuity cue wording.
- `Tests/NativeMacADEIntegrationTests/SessionRowViewContractTests.swift` — Existing row contract coverage may need to reflect any reused cue surface changes.

### Related ADRs
- [ADR-001: Scope V1 as Focus Workspace continuity for multiplexer-heavy workflows](../adrs/adr-001.md) — Keeps copy honest about app-owned continuity instead of true multiplexer integration.
- [ADR-003: Model continuity as a Focus Workspace sub-toggle](../adrs/adr-003.md) — Requires continuity to appear as a child setting under Focus Workspace.
- [ADR-004: Resolve continuity at restore time with terminal-first selection and truthful snapshot persistence](../adrs/adr-004.md) — Requires cue text to explain terminal-first restore without misrepresenting persisted truth.

## Deliverables
- Focus Workspace settings UI with a continuity child toggle and parent-child dependency behavior.
- Centralized continuity copy and cue strings reused across settings and active context surfaces.
- Lightweight trust and correction cues for continuity-enabled restore behavior using existing UI surfaces.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for visible continuity settings and cues **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `FocusWorkspacePresentation` exposes continuity toggle label and help text that distinguish remembered app context from live terminal state.
  - [ ] `FocusWorkspacePresentation` exposes active-cue wording for continuity-enabled state without implying tmux, pane, or process reattachment.
  - [ ] The settings presentation for parent-off state does not expose continuity as independently active.
- Integration tests:
  - [ ] The Focus Workspace settings section renders a continuity child toggle beneath the parent toggle and persists its enabled state across reload.
  - [ ] Turning Focus Workspace off clears the continuity child toggle and reloads the settings surface with both toggles off.
  - [ ] After a continuity-enabled relaunch restore, the active cue or banner explains the remembered focus target using the centralized continuity copy.
  - [ ] Continuity-enabled users can still use existing session search or row surfaces to confirm or correct the restored target without any new top-level command surface.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Users can discover, enable, and understand continuity from the existing Focus Workspace settings flow.
- Visible continuity cues stay truthful about app-owned restore behavior and do not imply deeper multiplexer or process control.
