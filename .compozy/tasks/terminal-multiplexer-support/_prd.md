# Focus Workspace Continuity for Multiplexer-Heavy Workflows

## Overview

Focus Workspace Continuity extends Another ADE for solo power users who already organize terminal work in tmux, herdr, or similar tools and want the app to return them to the right work context with less friction. The product value is not deeper multiplexer control. The value is faster re-entry into the right project, session, and tab while preserving trust in what the app does and does not remember.

The MVP uses a restore-first approach. It should make Focus Workspace feel like the most reliable way to resume work after switching away or relaunching the app, while keeping the feature opt-in and protecting the current multi-tab workflow for everyone else.

## Goals

- Increase Focus Workspace adoption among solo power users who prefer terminal-first workflows.
- Reduce the time and friction required to return to the right work context after a switch away or relaunch.
- Strengthen user trust in Focus Workspace by making its continuity behavior explicit, predictable, and easy to understand.
- Preserve the existing flexible workflow for users who do not opt in.
- Establish a credible product foundation for later continuity and attention-routing improvements if adoption proves strong.

## User Stories

### Primary Persona: Solo Power User
- As a solo power user, I want Another ADE to reopen close to the last place I was working so I can resume quickly without hunting through sessions and tabs.
- As a solo power user, I want Focus Workspace to feel aligned with my tmux-style workflow so the app does not become a second layer of avoidable navigation.
- As a solo power user, I want to trust what the app remembers so I am not surprised by where I land after returning.

### Secondary Persona: Returning Focus Workspace User
- As a returning user, I want the app to make my likely next step obvious so I can get back into flow with minimal thinking.
- As a returning user, I want visible cues that confirm the active focus target so I know I am back in the right context.

### Secondary Persona: Existing Flexible Workflow User
- As a user who prefers multiple tabs and sessions, I want my current workflow to remain unchanged unless I explicitly opt into Focus Workspace continuity.
- As a user exploring the feature, I want a clear explanation of what changes before I enable it so I can decide whether it fits my style.

## Core Features

### 1. Opt-In Focus Workspace Continuity
The product offers Focus Workspace Continuity as an intentional, settings-first workflow for users who want the app to minimize redundant navigation around a single active thread.

Functional requirements:
- Users can discover and enable the experience from the existing settings surface.
- The feature is clearly framed as a personal workflow preference, not a default behavior change.
- Users who do not opt in keep the current flexible project, session, and tab workflow.

### 2. Smarter Restore Landing
The product lands opted-in users closer to the last meaningful project, session, and tab context when they return after a switch away or relaunch.

Functional requirements:
- The remembered landing point should feel specific enough to reduce manual rediscovery.
- The experience should prioritize the context users are most likely trying to resume, not a generic last-opened shell.
- The landing behavior must remain understandable and predictable.

### 3. Continuity Cues and Trust Signals
The product makes the remembered focus target visible enough that users understand where they are being returned and why.

Functional requirements:
- Users can see clear cues about the active focus target and continuity behavior.
- Product language distinguishes remembered app context from live external terminal state.
- The experience should reduce uncertainty rather than introduce hidden-state anxiety.

### 4. Supportive Return-to-Context Navigation
The product includes lightweight navigation support that reinforces the restore-first workflow without turning the MVP into a broader orchestration surface.

Functional requirements:
- Users can quickly confirm or correct the focus target when the initial landing is not what they expected.
- Existing command and shortcut flows remain consistent with the continuity story.
- Navigation support should complement the main restore behavior rather than become the primary value proposition.

### 5. Multiplexer-Friendly Positioning In Product
The product explains why this workflow fits tmux-heavy and terminal-first usage without claiming deeper pane awareness or external session control.

Functional requirements:
- Settings and in-product copy describe the workflow in language power users will recognize.
- Messaging stays honest about the product boundary.
- The MVP wins through in-product clarity before broader public repositioning.

## User Experience

### User Journey
1. A solo power user discovers Focus Workspace Continuity in Settings.
2. The product explains that the workflow is designed for users who want fast re-entry into a single active thread while managing deeper terminal complexity elsewhere.
3. The user enables the feature and continues working normally.
4. After switching away or relaunching the app, the user lands close to the last meaningful context instead of manually searching through projects, sessions, or tabs.
5. The app shows enough continuity cues that the user understands where they landed and can confirm or correct it quickly.
6. Over time, the workflow earns trust because it reduces re-entry friction without changing the experience for non-opted-in users.

### UX Considerations
- The experience should feel calm, specific, and reversible.
- Discoverability should remain settings-first for MVP.
- Copy should use familiar terminal-native language while keeping the promise narrow and truthful.
- Cues should be readable, low-noise, and accessible for keyboard-first users and users relying on standard macOS accessibility support.
- The workflow should not make existing flexible users feel that their mode is now second-class.

## High-Level Technical Constraints

- The experience must fit the existing project, session, tab, and Focus Workspace model rather than redefine the product around pane management.
- The product must preserve truthful restore semantics and avoid implying recovery of live external terminal state.
- The feature must coexist cleanly with current non-opted-in workflows.
- The experience should remain fast enough that returning users perceive it as an immediate productivity gain.

## Non-Goals

- Live tmux, zellij, or pane-window awareness.
- Reattachment to running external terminal processes.
- Remote or SSH continuity promises.
- A broader task dashboard or orchestration center.
- Public market positioning that overstates the product as deep multiplexer integration.
- A redesign of the existing multi-tab workflow for users who do not opt in.

## Phased Rollout Plan

### MVP (Phase 1)
Included:
- Opt-in Focus Workspace Continuity
- Smarter restore landing
- Continuity cues and trust signals
- In-product multiplexer-friendly positioning
- Lightweight correction path when the remembered landing is not ideal

Success criteria to proceed:
- Focus Workspace adoption reaches the target power-user cohort threshold.
- Users who enable the workflow keep using it over time.
- Corrective switching after return drops meaningfully.

### Phase 2
Included:
- Stronger active return-to-context support during live work
- More explicit focus-target visibility in key navigation surfaces
- Better product guidance based on observed adoption behavior

Success criteria to proceed:
- Phase 1 adoption is durable rather than curiosity-driven.
- Users show repeat reliance on the continuity workflow, not just initial experimentation.
- User feedback indicates demand for more active continuity support.

### Phase 3
Included:
- Broader continuity and attention-routing enhancements for users managing multiple active threads
- Expanded visibility into which context needs attention next
- More deliberate product positioning around continuity for terminal-native workflows

Long-term success criteria:
- Another ADE becomes a preferred workflow layer for a distinct terminal-first user segment.
- The product earns stronger differentiation without sacrificing trust or simplicity.

## Success Metrics

- Focus Workspace adoption rate of at least 10 percent of monthly active desktop users within 60 days of release.
- Fourteen-day retention of at least 70 percent among enabled users.
- A 15 percent lift in average days active per week among enabled users within 30 days.
- Context return success rate of at least 80 percent, measured by returns not followed by corrective session or tab switching within two minutes.
- A 30 percent reduction in app-level tab churn for opted-in sessions.
- Qualitative feedback from power users that the workflow better fits terminal-first habits.

## Risks and Mitigations

### Risk: The improvement feels too subtle
Mitigation:
- Anchor the MVP on visibly better restore landing, not only copy and cues.
- Measure whether users actually return with fewer corrective actions.

### Risk: Users infer deeper multiplexer support than the product offers
Mitigation:
- Keep the primary framing centered on continuity and fast re-entry.
- Use multiplexer-friendly language as explanation, not as a claim of pane control.

### Risk: Settings-first discovery limits adoption
Mitigation:
- Make the setting explanation clear and relevant to solo power users.
- Review adoption data before deciding whether later phases need stronger in-product prompts.

### Risk: Existing flexible users worry the product is shifting away from them
Mitigation:
- Preserve the current workflow for non-opted-in users.
- Keep the product language explicit that this is an optional preference.

### Risk: The MVP solves restore friction but not the broader continuity need
Mitigation:
- Treat Phase 1 as a learning step with explicit success and expansion gates.
- Use later phases only if adoption and feedback justify broader scope.

## Architecture Decision Records

- [ADR-001: Scope V1 as Focus Workspace continuity for multiplexer-heavy workflows](adrs/adr-001.md) — Sets the overall product boundary around app-owned continuity instead of true multiplexer integration.
- [ADR-002: Use a restore-first product approach for Focus Workspace continuity](adrs/adr-002.md) — Chooses smarter restore landing as the primary MVP strategy for increasing adoption.

## Open Questions

- Final user-facing name for the workflow and whether it remains under the Focus Workspace label.
- Inclusion or exclusion of the last active file tab when the user returns to context.
- Best cohort definition for measuring solo power-user adoption without inflating results with casual usage.
- Threshold for when later phases should expand beyond restore-first value into active attention routing.
