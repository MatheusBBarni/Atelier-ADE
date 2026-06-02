# Ghostty Terminal Engine for Atelier

## Overview

Atelier will use Ghostty as its embedded terminal experience. The change is for power users who expect terminal behavior to match a serious native terminal, not a simplified embedded shell.

The MVP keeps Atelier's current project, session, tab, restore, and agent launch workflow intact. The value is terminal correctness inside Atelier, so users can trust embedded terminal tabs for real work without switching out to standalone Ghostty or cmux.

## Goals

- Make Ghostty the default terminal experience for every Atelier terminal tab.
- Improve trust among power users who expect Ghostty-level terminal behavior.
- Preserve the existing Atelier workflow for projects, sessions, tabs, restore, and agent starts.
- Reduce terminal-related friction that causes users to leave Atelier during focused work.
- Establish a concrete correctness baseline for power-user terminal workflows.
- Treat any regression versus the current Atelier terminal behavior as an MVP failure.

## User Stories

### Primary Persona: Terminal Power User

- As a terminal power user, I want Atelier terminal tabs to use Ghostty so command-line apps behave correctly.
- As a terminal power user, I want the current Atelier workflow to remain familiar so I do not need to relearn the app.
- As a terminal power user, I want terminal behavior to feel credible enough that I can stay inside Atelier.
- As a terminal power user, I want interactive TUIs, shell input, rendering, and heavy output to stay reliable enough for daily work.
- As a terminal power user, I want the Ghostty switch to avoid regressions in workflows that already work today.

### Secondary Persona: Agent-Heavy Developer

- As an agent-heavy developer, I want Codex, Claude, and similar tools to run inside a more capable terminal surface.
- As an agent-heavy developer, I want streaming agent output, keyboard input, and long-running sessions to remain usable.
- As an agent-heavy developer, I want existing agent launch flows to remain unchanged.

## Core Features

### 1. Ghostty Terminal Tabs

All Atelier terminal tabs use Ghostty as the terminal experience.

Functional requirements:

- New terminal tabs open with Ghostty behavior by default.
- Restored terminal tabs return as Ghostty terminal tabs.
- Existing project, session, tab, and agent launch flows remain unchanged.
- The experience does not expose a second terminal-engine choice in the MVP.

### 2. Workflow Preservation

The terminal replacement does not redesign Atelier's workspace model.

Functional requirements:

- Project sidebar behavior remains the same.
- Session creation and tab creation remain the same.
- Restore behavior remains understandable and consistent with today's app.
- Agent profile starts continue to feel like Atelier actions, not separate Ghostty workflows.

### 3. Terminal Correctness Baseline

The MVP is judged by whether power users can trust common terminal workflows. Any regression versus the current Atelier terminal behavior counts as a failure.

Functional requirements:

- Interactive TUIs behave correctly in normal use, including vim-style editors, htop-style monitors, tmux-style workflows, and agent CLIs.
- Shell behavior remains dependable, including prompts, resizing, copy and paste, keyboard input, and normal command execution.
- Rendering fidelity remains acceptable for daily work, including colors, Unicode, ligatures, and alternate-screen behavior.
- Heavy output remains usable, including logs, long builds, and streaming agent output.
- Terminal rendering should feel like a real native terminal, not a placeholder shell.
- Failures are visible enough that users understand when a terminal could not start or continue.

### 4. Honest Ghostty Scope

The product promise is "Atelier uses Ghostty as its terminal," not "Atelier matches every standalone Ghostty feature."

Functional requirements:

- User-facing messaging avoids promising panes, splits, full config parity, or cmux-style agent attention.
- Later Ghostty parity work can build on this MVP without being implied by it.

## User Experience

1. The user opens Atelier and selects an existing project.
2. The user creates or restores a session.
3. Terminal tabs open in the same place and flow as before, but the terminal experience is Ghostty.
4. The user runs shell tools, interactive TUIs, editor commands, long builds, and agent sessions with higher confidence in terminal correctness.
5. If a common workflow worked in the current Atelier terminal, the user expects it to keep working after the Ghostty switch.
6. When the user returns later, restored terminal tabs still fit Atelier's familiar workspace model.

UX considerations:

- No new onboarding should be required for existing users.
- The transition should feel like a quality upgrade, not a workflow migration.
- Copy should be precise and restrained.
- Keyboard-first users should not lose existing efficiency.
- Correctness failures should be visible and understandable, not silent or mysterious.

## High-Level Technical Constraints

- The MVP must keep Atelier's existing project, session, tab, restore, and agent launch contracts.
- Ghostty should be the default terminal experience for terminal tabs.
- The product should not require users to manage a terminal-engine preference.
- The user-visible experience should remain native macOS quality.
- The terminal switch must not regress common workflows that already work in Atelier today.

## Non-Goals

- Full standalone Ghostty configuration parity.
- cmux-style panes, splits, or terminal layout workflows.
- cmux-style agent attention, notifications, or socket-control workflows.
- A redesign of Atelier's project, session, or tab model.
- Remote terminal continuity or external process reattachment.
- Multiplexer-aware pane state.
- Expanding the MVP into a comprehensive terminal compatibility certification program.

## Phased Rollout Plan

### MVP (Phase 1)

Included:

- Ghostty terminal tabs as the default terminal experience
- Current Atelier workflow preservation
- Terminal correctness baseline for power users
- Regression protection against current Atelier terminal behavior
- Clear product boundary around non-goals

Success criteria to proceed:

- Power users can use Atelier terminal tabs without immediately switching to another terminal for correctness reasons.
- Interactive TUIs, shell behavior, rendering fidelity, and heavy output meet the correctness baseline.
- Existing workflows for projects, sessions, restore, and agent starts remain intact.
- No known regression versus current Atelier terminal behavior remains in a baseline workflow.
- No meaningful increase in terminal-start failure reports.

### Phase 2

Included:

- Broader Ghostty parity improvements based on user feedback
- More deliberate handling of fonts, themes, and terminal behavior expectations
- Better failure diagnostics and user recovery paths
- Expanded baseline examples if users report important missed workflows

### Phase 3

Included:

- Considered expansion into Ghostty config parity or richer terminal workflows
- Evaluation of cmux-adjacent workflow features only if users ask for them after the core switch
- More formal compatibility expectations if terminal correctness becomes a primary differentiator

## Success Metrics

- At least 80 percent of tested power-user terminal workflows complete without users switching to an external terminal.
- Zero known regressions versus current Atelier terminal behavior in baseline workflows at MVP release.
- Terminal-start failure rate stays below 1 percent.
- Qualitative feedback from power users confirms improved terminal correctness.
- Agent session starts remain at or above the current success baseline.
- Correctness-related terminal complaints decrease after release.
- Baseline workflow validation includes interactive TUIs, shell behavior, rendering fidelity, and heavy output.

## Risks and Mitigations

### Risk: Users expect full standalone Ghostty parity

Mitigation:

- Keep release messaging focused on Ghostty as Atelier's terminal foundation.
- Defer config parity and advanced workflows until the core switch is validated.

### Risk: Workflow disruption hides the terminal-quality win

Mitigation:

- Preserve current Atelier project, session, tab, restore, and agent flows.
- Treat workflow changes as out of scope for MVP.

### Risk: The cmux comparison creates broader expectations

Mitigation:

- Use cmux only as inspiration for "Ghostty as the terminal," not as a promise of panes, splits, or agent attention.

### Risk: Terminal correctness remains too vague to validate

Mitigation:

- Define acceptance through representative power-user workflows across interactive TUIs, shell behavior, rendering fidelity, and heavy output.
- Treat current Atelier terminal behavior as the minimum regression bar.

### Risk: The regression bar delays release

Mitigation:

- Keep the baseline focused on common workflows that matter to power users.
- Move non-regression improvements outside the baseline into later phases.

## Architecture Decision Records

- [ADR-001: Use Ghostty as the Atelier terminal while preserving the Atelier workflow](adrs/adr-001.md) - Ghostty becomes the terminal experience for Atelier tabs, while config parity and cmux-style workflows stay out of the MVP.
- [ADR-002: Define MVP terminal correctness baseline across common power-user workflows](adrs/adr-002.md) - MVP acceptance covers interactive TUIs, shell behavior, rendering fidelity, and heavy output, with regressions versus current Atelier behavior treated as failures.

## Open Questions

- Final release wording for describing Ghostty without implying full standalone Ghostty parity.
- Specific representative examples for each correctness-baseline workflow class.
- Whether Phase 2 should prioritize Ghostty config parity or better terminal diagnostics.
- Which current Atelier terminal workflows are accepted as the non-regression baseline before implementation starts.
