# Single-Tab Guardrail

## Overview

Single-Tab Guardrail should give focused existing Another ADE users a deliberate focus-workspace experience that reduces wrong-tab mistakes and keeps one visible work surface at the center of a session. The feature is for users who already understand the product, want less tab management overhead, and prefer staying in one thread at a time.

This is broader than a hidden safety toggle, but still smaller than a full workspace redesign. The MVP should combine a single-tab preference with clear in-product framing so the experience feels intentional, understandable, and trustworthy. The product goal is to help users stay focused with fewer mistakes, not to replace Another ADE’s default project → session → tab model for everyone.

## Goals

- Reduce wrong-tab and accidental extra-tab mistakes for enabled users by **at least 25% within 30 days** of enablement.
- Achieve **meaningful opt-in adoption** among monthly active users while keeping the feature clearly targeted to focused existing users.
- Make the feature feel deliberate rather than buggy through strong in-product explanation, discoverability, and active-state clarity.
- Validate whether a broader focus-workspace investment is justified before expanding into public positioning or larger workflow changes.
- Use MVP learning to decide whether Phase 2 should expand discoverability, positioning, or workflow depth.

## User Stories

### Primary Persona: Focused Existing User

- As a focused existing user, I want one clear work surface per session so I make fewer tab mistakes.
- As a focused existing user, I want the product to explain why extra-tab actions are blocked so I can stay in flow instead of feeling confused.
- As a focused existing user, I want the preference to stay understandable after relaunch so I continue trusting it over time.
- As a focused existing user, I want to tell when the focus experience is active without feeling like the app has changed unpredictably.

### Secondary Persona: Terminal-Native Power User

- As a terminal-native power user, I want Another ADE to feel compatible with the way I already organize work inside tmux, herdr, or similar tools.
- As a terminal-native power user, I want the app to reduce redundant navigation instead of adding another layer of workspace management.

### Secondary Persona: Occasional File Explorer Within a Focused Session

- As a user who sometimes opens files while staying focused, I want the single-surface experience to remain understandable instead of surprising me with extra navigation.
- As a user returning to a focused session, I want the workspace to feel coherent even if my previous work included file inspection or other tab-adjacent actions.

## Core Features

### Critical

**Focus Workspace Preference**  
Provide a clearly named opt-in preference that enables a single-surface session experience for users who want fewer tab mistakes and less visible tab management.

Requirements:
- The feature must be framed as a deliberate personal preference, not an unexplained restriction.
- Users must be able to turn it on and off confidently.
- The product should explain the value in plain language for focused existing users.

**Single-Surface Guardrails**  
When the preference is active, the product should keep the user in one visible work surface per session instead of allowing the experience to drift back into accidental tab sprawl.

Requirements:
- The experience must uphold the single-surface promise consistently from the user’s perspective.
- The product should reduce wrong-surface mistakes rather than merely hiding evidence of them.
- The guardrail should feel like focus support, not punishment.

**Blocked-Action Experience That Keeps Focus**  
If a user tries to open another tab while the preference is active, the product should explain what happened and keep the user oriented in the current surface.

Requirements:
- Feedback must be immediate, clear, and calm.
- The message must explain the rule in user terms.
- Users must understand how to continue their current work or leave the focused experience if they want the default behavior back.

### High

**In-Product Framing and Discoverability**  
The MVP should broaden beyond a narrow toggle by making the feature easier to understand and easier to find inside the product.

Requirements:
- Users should be able to discover the preference through normal in-product paths.
- The active state should be visible enough that users understand why the workspace behaves differently.
- The feature should feel like part of a coherent focus-workspace story, not a buried advanced setting.

**Restore and Resume Clarity**  
Returning users should still understand the workspace when the preference is active, especially after relaunch or resume.

Requirements:
- The focus experience must remain believable after users come back to work.
- The product should avoid surprising users with a workspace that feels inconsistent with the active preference.
- Resume behavior should preserve confidence, not create doubt about whether the feature is working.

### Medium

**Terminal-Native Workflow Alignment**  
The product should acknowledge that some users want this feature because they already manage complexity elsewhere, especially inside terminal-native workflows.

Requirements:
- The feature’s framing should respect existing user habits instead of implying a whole new workflow.
- The product should feel compatible with multiplexer-heavy work without making that niche the only story.

## User Experience

### Primary Journey: Enabling Focus Workspace

1. A focused existing user finds the preference through normal product discovery paths.
2. The product explains that this mode is for people who want one visible work surface per session and fewer tab mistakes.
3. The user enables the preference and immediately sees clear confirmation that the focused experience is active.
4. The workspace feels calmer and more intentional without requiring the user to learn a new system.

### Primary Journey: Working in Focus Workspace

1. The user continues normal work inside the session.
2. When they trigger an action that would normally create another tab, the product explains that focus mode keeps work in one visible surface.
3. The user stays oriented, understands why the behavior occurred, and continues working without feeling lost or blocked by surprise.

### Primary Journey: Returning Later

1. The user reopens or resumes the app.
2. The workspace still feels coherent with the chosen focus preference.
3. The user does not need to reverse-engineer what changed or whether the mode is still active.

### UX Considerations

- Keep language calm and explicit. The feature should feel supportive, not restrictive.
- Make the active state obvious enough to prevent confusion, but not so heavy that it adds new clutter.
- Avoid making the experience feel like a bug when expected tab actions behave differently.
- Respect keyboard-first and power-user workflows.
- Preserve accessibility and clarity for long-running desktop sessions.

### Onboarding and Discoverability

- Do not create a new first-run wizard for MVP.
- Use in-product framing instead: clear settings copy, discoverable entry points, and concise state cues.
- Treat public positioning as a later-phase decision unless MVP evidence proves it should move earlier.

## High-Level Technical Constraints

- The feature must remain optional and coexist with the current project → session → tab product model.
- The user-visible experience must stay consistent wherever users normally create or reopen work surfaces.
- The focused experience must remain understandable during resume, restore, and file-oriented workflows.
- The product must preserve user trust when the active surface contains in-progress work or other high-attention context.

## Non-Goals (Out of Scope)

- Replacing the default multi-tab model for all users
- A full workspace-mode platform with multiple focus presets in MVP
- Public README and website repositioning in MVP
- Per-project or per-session focus policies
- Advanced multitasking alternatives such as parked-tab dashboards or richer tab recovery systems
- Broad onboarding redesign for new users
- Team or collaboration-focused workflows

## Phased Rollout Plan

### MVP (Phase 1)

- Focus Workspace Preference
- Single-Surface Guardrails
- Clear Blocked-Action Experience
- In-Product Framing and Active-State Clarity
- Restore and Resume Clarity

**Success criteria to proceed to Phase 2**
- Wrong-tab mistakes among enabled users decrease by **at least 25%**
- Preference adoption reaches **at least 10% of monthly active users within 60 days**
- **At least 65%** of enabled users keep the feature on after 14 days
- Enabled users report the experience is understandable and intentional

### Phase 2

- Broader in-product discoverability refinement
- Stronger focus-workspace polish based on MVP usage patterns
- Optional README and website positioning if MVP evidence supports broader product storytelling
- Better workflow guidance for terminal-native and focus-oriented users

**Success criteria to proceed to Phase 3**
- The feature expands beyond a niche toggle and shows durable repeat use
- Discoverability improves without meaningfully increasing confusion
- Public positioning shows evidence of helping product evaluation or adoption if introduced

### Phase 3

- Richer focus-workspace package for users who want a more opinionated single-surface experience
- Additional focus-oriented conveniences built on proven user behavior
- Stronger product differentiation around supporting both deep focus and multi-threaded work

**Long-term success criteria**
- Another ADE is seen as capable of supporting both parallel-tab users and focus-first users without forcing either model on everyone
- Focus-workspace capabilities contribute meaningfully to retention, satisfaction, and product identity

## Success Metrics

- **Wrong-tab mistake reduction:** decrease wrong-tab and accidental extra-tab incidents by **>= 25%** among enabled users within 30 days
- **Preference adoption:** **>= 10%** of monthly active users enable the feature within 60 days
- **14-day retention:** **>= 65%** of users who enable it keep it on after 14 days
- **Blocked-attempt recovery:** **>= 70%** of blocked extra-tab attempts resolve without users disabling the feature immediately
- **Focus clarity / satisfaction:** enabled users rate the feature **>= 4.2 / 5**
- **Repeat use depth:** a meaningful share of enabled users continue using the feature across multiple work sessions within one release cycle

## Risks and Mitigations

- **Adoption risk:** The feature may remain too hidden or feel too niche.  
  **Mitigation:** make in-product framing stronger and tie discovery to normal product use, not just buried settings.

- **Expectation risk:** Users may expect a complete workflow overhaul when the MVP is still relatively narrow.  
  **Mitigation:** use precise naming and concise copy that explain both the value and the boundary of the feature.

- **Restriction risk:** Users may feel trapped or interrupted when extra-tab actions are blocked.  
  **Mitigation:** keep feedback calm, immediate, and oriented around staying focused, with a clear path back to default behavior.

- **Scope risk:** The broader product approach could expand too far before the core value is proven.  
  **Mitigation:** keep Phase 1 disciplined and defer public positioning plus broader focus-workspace ambitions until metrics justify them.

- **Positioning risk:** If public storytelling waits too long, the feature may not help differentiation quickly.  
  **Mitigation:** treat README and website updates as a deliberate Phase 2 decision triggered by MVP evidence rather than as automatic MVP scope.

## Architecture Decision Records

- [ADR-001: Scope V1 as a settings-first single-tab preference with real enforcement](adrs/adr-001.md) — Establishes the original idea boundary around a truthful single-tab preference.
- [ADR-002: Use a broader focus-workspace product approach for the PRD](adrs/adr-002.md) — Selects the broader product framing over the narrowest MVP or softer guidance-only path.
- [ADR-003: Broaden MVP through in-product framing before public positioning](adrs/adr-003.md) — Prioritizes in-product discoverability and clarity before README or website expansion.

## Open Questions

- What should the final user-facing name be: Single-Tab Guardrail, Focused Session, Focus Workspace, or something else?
- How should the first enabled experience handle sessions that already contain more than one work surface?
- How prominent should in-product discoverability be before it feels pushy to users who do not need it?
- When should public README and website positioning move from Phase 2 opportunity to committed scope?
- How explicitly should the product acknowledge tmux, herdr, and terminal-native workflows in in-product copy?
