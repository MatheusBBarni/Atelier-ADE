# Config Modal Customization

## Overview

Config Modal Customization gives Another ADE a dedicated settings surface for power users who want the product to match how they work every day. It addresses a visible gap in the current experience: users can organize projects, sessions, and tabs, but they cannot shape the environment around those workflows through agent defaults, added agent choices, themes, or shortcut preferences.

The feature is primarily for developers switching from mature tools such as Cursor and VS Code, plus existing Another ADE power users who already rely on agent-driven workflows. These users expect a product that remembers their preferred setup, respects their habits, and feels complete enough for all-day use.

The value is twofold. First, it reduces repeated setup by making preferred agent behavior and core personalization persistent. Second, it improves daily-driver credibility by closing obvious maturity gaps in customization. The product should position this as a guided control center for daily agent work, not as a sprawling preferences system.

## Goals

- Increase the share of sessions that start from saved defaults instead of repeated manual setup.
- Make Another ADE feel complete enough for Cursor and VS Code switchers to adopt as a daily workflow surface.
- Strengthen the product’s agent-first identity by making agent choice and default behavior a first-class user capability.
- Deliver the full user-visible launch bundle for V1: curated agent expansion, editable agent defaults, better theme support including light themes, and core shortcut customization.
- Preserve the product’s local-first, trustworthy feel while expanding what users can personalize.

## User Stories

### Primary Persona: Tool Switcher from Cursor or VS Code
- As a developer evaluating Another ADE, I want to set my preferred agent defaults so the app feels familiar and ready every time I start work.
- As a switcher, I want a polished light or dark theme choice so the product fits my daily environment.
- As a switcher, I want core shortcuts to align with my habits so I do not lose speed when changing tools.

### Primary Persona: Existing Another ADE Power User
- As a power user, I want to change how built-in agents launch so I can match the product to the workflows I already use.
- As a power user, I want to add a curated new agent option such as OpenCode so I can use the right tool for different tasks without leaving Another ADE.
- As a power user, I want my settings to carry across relaunches so I do not reconfigure the product repeatedly.

### Secondary Persona: AI Workflow Experimenter
- As an experimenter, I want clear built-in and custom states so I can try new setups without losing trust in what the product will do.
- As an experimenter, I want safe feedback around command-related changes so I can understand the effect of my choices before I rely on them.

## Core Features

### Critical

**Dedicated Config Modal**  
Provide one clear, first-class place for users to manage personalization. The modal should group settings around the way people think about daily use: agents and defaults first, then appearance, then shortcuts. It should be easy to discover, easy to scan, and easy to return to.

**Curated Agent Expansion and Default Control**  
Let users edit the default behavior of built-in agents such as Claude and Codex, and add curated new agent choices such as OpenCode. The product should make agent control feel like part of session setup, not a disconnected admin task.

**Persistent Personalized Defaults**  
Ensure that saved preferences become part of normal daily behavior. A user who configures the product should feel the benefit during new-session creation, session resumption, and repeated use over time.

### High

**Theme Expansion Including Light Themes**  
Add a small set of polished theme choices, including strong light-theme support. Theme choice should help users feel comfortable using Another ADE for long stretches of work and reduce one of the most obvious maturity gaps versus competing tools.

**Core Shortcut Customization**  
Allow users to customize the most important workflow shortcuts that shape day-to-day speed. V1 should focus on the commands people feel constantly, not an exhaustive remapping surface.

**Safe Personalization Feedback**  
Explain personalization clearly. Users should be able to tell which options are built-in, which are customized, and which choices affect agent launch behavior. The product should make powerful changes feel deliberate rather than surprising.

### Medium

**Discoverability for Switchers**  
Make the configuration surface easy to find for new users coming from other tools. The value of the feature depends not only on available controls, but on users quickly understanding that Another ADE can adapt to their habits.

## User Experience

### Primary Journey: First-Time Personalization
1. A user opens Another ADE and discovers a dedicated config modal from an obvious entry point.
2. The modal leads with agent defaults and curated agent choices, which matches the user’s main reason for opening it.
3. The user selects preferred agents, updates default behavior, chooses a theme, and adjusts a small set of core shortcuts.
4. The app confirms that these preferences are saved and will shape future sessions.
5. The next time the user starts work, the app feels faster and more personally fitted.

### Primary Journey: Daily Repeat Use
1. A returning user starts or resumes a session.
2. Their saved defaults already shape the experience, reducing setup friction.
3. If the workflow changes, they can reopen the config modal, make a focused adjustment, and return to work quickly.
4. Over time, the modal becomes part of the user’s control loop rather than a one-time setup screen.

### UX Considerations
- Keep the modal guided and compact rather than exposing an overwhelming settings catalog.
- Put the highest-value controls first: agent defaults, curated agent choices, then visual comfort, then shortcut fit.
- Use clear labeling and safe language for anything that changes agent launch behavior.
- Support accessible, readable theme choices and interactions suitable for long-running desktop workflows.
- Avoid making users hunt for core personalization behind obscure menus or advanced-only flows.

### Onboarding and Discoverability
- Signal early that Another ADE can adapt to the user’s existing workflow instead of forcing a rigid default.
- Highlight the config modal as part of the product’s value proposition for switchers from mature tools.
- Make the first visit feel fast and useful, not like a complex setup process.

## High-Level Technical Constraints

- The feature must preserve the product’s local-first and trust-oriented positioning from the user’s perspective.
- Personalization must remain compatible with the existing session-first workflow rather than introducing a separate product layer.
- Changes that affect user behavior across relaunches must feel reliable and predictable.
- Sensitive or security-relevant user choices must remain explicit and user-controlled.
- Performance should feel immediate enough that opening or adjusting settings does not interrupt workflow momentum.

## Non-Goals (Out of Scope)

- An open marketplace or broad discovery system for external agents
- Per-project or per-task personalization policies in V1
- Cross-device sync or cloud backup of preferences
- Exhaustive remapping of every shortcut in the product
- A broad “advanced settings” platform unrelated to daily workflow personalization

## Phased Rollout Plan

### MVP (Phase 1)
- Dedicated config modal
- Curated agent expansion
- Editable built-in agent defaults
- Theme expansion including polished light themes
- Customization of core workflow shortcuts
- Clear built-in versus customized states
- Persistent defaults that affect future session starts

**Success criteria to proceed to Phase 2**
- A meaningful share of active users personalize the product
- Session starts from saved defaults rise measurably
- Early switchers report that Another ADE feels more complete and more usable as a daily driver

### Phase 2
- Broader convenience improvements for repeat users
- Better discoverability and onboarding around personalization
- Optional workflow presets that reduce repeated switching between common modes of work

**Success criteria to proceed to Phase 3**
- Personalized users show stronger repeat usage than non-personalized users
- Workflow presets or similar convenience layers show evidence of regular reuse
- Personalization becomes part of the product’s adoption story, not just a support feature

### Phase 3
- More advanced workflow-fit features that build on proven usage patterns
- Deeper personalization packages for users who regularly switch work modes
- Stronger competitive positioning around agent-first workflow control

**Long-term success criteria**
- Another ADE is seen as both trustworthy and personally adaptable
- Personalization helps the product win and keep serious daily users against mature alternatives

## Success Metrics

- **Configured session starts:** Increase the share of new sessions launched with saved defaults or selected preferences within 60 days of release.
- **Personalization adoption:** Achieve strong active-user adoption of at least one personalized setting within the first month.
- **Agent customization adoption:** Show that a meaningful share of active users edit agent defaults or choose a curated expanded agent.
- **Theme adoption:** Confirm that non-default theme use is material enough to justify theme expansion, especially light-theme support.
- **Shortcut adoption:** Confirm that core shortcut customization is used often enough to support the chosen launch scope.
- **Retention or satisfaction lift:** Show that users who personalize the product are more likely to return or rate the product as daily-driver ready.

## Risks and Mitigations

- **Adoption risk:** Users may not notice the feature or may treat it as optional polish.  
  **Mitigation:** Make the config modal prominent, lead with agent control, and tie personalization to real workflow wins.

- **Scope risk:** The feature may grow into a broad settings project that weakens the product story.  
  **Mitigation:** Keep the release centered on daily workflow fit and limit V1 to the controls users feel most often.

- **Competitive risk:** If the release feels shallow next to mature tools, switchers may still reject Another ADE.  
  **Mitigation:** Focus on the most visible parity gaps while keeping agent control as the differentiating story.

- **Trust risk:** Users may hesitate to change powerful defaults if the consequences feel unclear.  
  **Mitigation:** Use explicit language, clear provenance, and visible confirmation around important changes.

- **Positioning risk:** The feature could be seen as generic preferences work instead of a product-strengthening move.  
  **Mitigation:** Frame it as a guided control center for agent-driven work, not as miscellaneous customization.

## Architecture Decision Records

- [ADR-001: Agent-First Scope for Config Modal Personalization](adrs/adr-001.md) — Establishes agent-first scope and a narrow preferences model for personalization.
- [ADR-002: Guided Control Center Product Approach for Config Modal Customization](adrs/adr-002.md) — Selects the full but guided V1 approach built for switchers from mature tools.

## Open Questions

- Should V1 include only a small curated set of added agents, or should the curated list be broad enough to cover several common switcher workflows?
- What is the minimum theme set required for users to perceive the product as complete rather than merely improved?
- Which shortcut changes matter most often in practice, and which ones can safely wait for a later phase?
- What is the best product language for making agent-default customization feel powerful but safe?
- Should future workflow presets be framed as a separate feature, or as a natural extension of this config modal story?
