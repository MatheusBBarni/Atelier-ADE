# Atelier Settings Config

## Overview

Atelier Settings Config gives multi-machine power users a reliable way to carry their Atelier setup across machines. It turns personal settings from hidden local state into a reusable, inspectable part of the user’s working environment.

The feature is for users who already invest in tailoring their tools and want Atelier to behave like the rest of their personal developer setup. Today, Atelier remembers preferences locally, but it does not let users treat those preferences as something they can move, review, or keep in sync with their broader workflow habits. That weakens Atelier’s credibility as a daily-use tool for serious users.

The value is direct and practical. Users should be able to move from one machine to another without rebuilding their setup, keep their Atelier preferences aligned with the rest of their personal tooling, and trust that the product will behave consistently after reinstall or migration. The first release should stay focused on portable personal settings, not expand into team policy, project-level behavior, or a generic configuration platform.

## Goals

- Make Atelier feel reusable across machines for power users who rely on a stable personal setup.
- Reduce repeated setup work when users reinstall Atelier or switch devices.
- Strengthen Atelier’s daily-driver credibility by exposing portable settings in a way serious developer tools already do.
- Deliver broad value across the main settings categories while keeping the portability promise reliable.
- Position the feature as a power-user capability that deepens trust and retention, not as a broad preferences overhaul.

## User Stories

### Primary Persona: Multi-Machine Power User
- As a multi-machine power user, I want my Atelier setup to travel with me so I do not rebuild the same environment on every machine.
- As a multi-machine power user, I want the main settings that shape my day-to-day work to behave consistently after reinstall or migration.
- As a multi-machine power user, I want Atelier to feel like part of my personal tooling stack rather than an isolated desktop app.

### Secondary Persona: Dotfiles-Oriented Developer
- As a developer who keeps my tools under versioned personal control, I want Atelier settings to be inspectable so I can understand and manage my setup.
- As a dotfiles-oriented developer, I want my Atelier configuration to fit naturally into the way I already manage personal developer preferences.

### Secondary Persona: AI Workflow Customizer
- As a user who adjusts agent profiles, shortcuts, and behavior often, I want my preferred setup to remain stable across machines so my workflow does not reset every time I change environments.
- As an AI workflow customizer, I want Atelier to make clear which settings are meant to travel and which are intentionally local.

## Core Features

### Critical

**Portable Personal Settings Contract**  
Atelier should offer one personal-global settings file for the user’s portable setup. The contract should cover the settings that matter most in daily use and can travel reliably across machines.

**Broad but Reliable Category Coverage**  
The first release should cover the main settings categories users already recognize in Atelier, including agent-profile preferences, appearance, shortcuts, and general app behavior, but only where those settings preserve the core portability promise.

**Normal Settings and Power-User Config Work Together**  
Users should be able to treat the settings file and the existing settings experience as part of one coherent product. The file should feel like an advanced extension of the normal settings flow, not a separate system meant only for experts who bypass the app.

### High

**Cross-Machine Reuse Workflow**  
The product should support the user job of moving Atelier from one machine to another with minimal setup rebuilding. Portability should feel intentional, not like an accidental side effect.

**Clear Supported Scope**  
Atelier should explain which settings are portable in V1 and which are intentionally excluded. Users should not have to guess whether a preference will travel with them.

**Safe Recovery and Confidence**  
Users should feel safe trying the feature because they can understand what changed, recover from mistakes, and trust that Atelier will not silently behave differently after a config edit or migration.

### Medium

**Power-User Discoverability**  
The feature should be easy for power users to find from the existing settings experience, while remaining lightweight enough that casual users do not feel forced into a more advanced workflow.

## User Experience

### Primary Journey: First-Time Setup Portability
1. A power user discovers that Atelier supports portable personal settings.
2. The user understands that this capability applies to their own reusable setup, not to project or team policy.
3. The user connects the feature to the settings they already care about, such as agent preferences, appearance, shortcuts, and general behavior.
4. The user leaves with confidence that Atelier will behave the same way on another machine.

### Primary Journey: Moving to a New Machine
1. A returning user installs or opens Atelier on another machine.
2. The user brings over their portable settings.
3. Atelier reflects the user’s expected setup across the supported settings categories.
4. The user resumes work without rebuilding their environment from scratch.

### Primary Journey: Ongoing Personal Maintenance
1. A user changes a preference in their normal Atelier workflow.
2. The user understands whether that preference is part of the portable contract.
3. The user continues to treat Atelier as part of their personal setup over time, not just during migration moments.

### UX Considerations
- Keep the feature legible as a power-user capability, not a mandatory setup step for everyone.
- Use plain language around what travels across machines and what remains local.
- Preserve trust by making changes visible and predictable from a user perspective.
- Make the relationship between standard settings use and portable configuration easy to understand.
- Support a workflow that feels compatible with long-term daily use, not only one-time transfer.

### Onboarding and Discoverability
- Surface the feature where power users already look for personalization.
- Frame the value in terms of reusable setup and daily consistency.
- Avoid overexplaining advanced concepts to users who do not need them.

## High-Level Technical Constraints

- The feature must preserve Atelier’s local-first and trust-oriented product positioning.
- The first release must remain personal-global in scope from the user’s perspective.
- Settings included in V1 must support reliable cross-machine reuse.
- Sensitive or machine-specific information must not be framed as portable personal setup.
- The experience must feel fast and predictable enough for everyday use.

## Non-Goals (Out of Scope)

- Project-shared, repo-scoped, or team-managed settings behavior
- A promise that every current or future Atelier setting is portable in V1
- Workspace, session, tab, or restore-state portability
- Rules, automation, or policy features beyond personal settings portability
- A mainstream onboarding flow that treats this as a required setup step for all users
- Credentials, secrets, or sensitive local-only information as part of the portable config story

## Phased Rollout Plan

### MVP (Phase 1)
- One personal-global Atelier settings configuration for portable personal setup
- Coverage across the main user-visible settings categories where portability is reliable
- A clear bridge between the normal settings experience and the power-user configuration workflow
- Clear explanation of supported versus unsupported settings in V1
- User confidence and recovery cues that make the feature feel safe to adopt

**Success criteria to proceed to Phase 2**
- A meaningful share of active users reuse their Atelier setup across machines or reinstalls
- Portable settings usage shows repeat behavior rather than one-time experimentation
- Users demonstrate trust in the feature instead of treating it as risky or confusing

### Phase 2
- Better convenience around setup transfer and reuse
- Stronger power-user guidance for maintaining portable settings over time
- Optional packaging or portability improvements that make repeat setup even easier

**Success criteria to proceed to Phase 3**
- Repeat usage continues to grow beyond initial migration moments
- Portable configuration becomes part of Atelier’s retention story for power users
- Users ask for broader portability workflows based on proven value, not novelty

### Phase 3
- More advanced reuse layers built on proven portability behavior
- Workflow-level conveniences such as reusable profiles or related higher-order personalization
- Evidence-based exploration of broader scope only if the personal-global model succeeds first

**Long-term success criteria**
- Atelier is seen as both personal and portable by serious users
- Portable settings help Atelier win and keep daily-use power users against mature alternatives

## Success Metrics

- **Portable setup adoption:** At least 25% of weekly active users create, edit, or apply a portable setting within 45 days of release.
- **Repeat reuse:** At least 40% of portable-settings users reuse the same setup across multiple launches or migrations within 30 days.
- **Config-backed session starts:** At least 30% of new sessions start with non-default preferences sourced from portable settings within 60 days.
- **Reliability from the user perspective:** Fewer than 2% of portable-settings attempts result in a failed or abandoned apply experience within 45 days.
- **Retention lift:** Users who adopt portable settings show at least 12% higher 4-week retention than users who do not.

## Risks and Mitigations

- **Adoption risk:** Users may not discover the feature or may treat it as too advanced to trust.  
  **Mitigation:** Keep the feature visible in the existing settings experience and frame it around a concrete job: reuse your Atelier setup across machines.

- **Perceived incompleteness risk:** Users may expect every setting to be portable immediately.  
  **Mitigation:** Position V1 around reliable portability, not universal coverage, and explain the supported scope clearly.

- **Positioning risk:** The feature may be misunderstood as generic preferences work instead of a product-strengthening capability.  
  **Mitigation:** Keep the story centered on reusable personal setup and daily-driver credibility for serious users.

- **Trust risk:** Users may worry that changes to portable settings will create inconsistent behavior.  
  **Mitigation:** Use clear feedback and recovery-oriented product language so users feel in control.

- **Competitive risk:** If the release feels too narrow, mature-tool switchers may still see Atelier as behind.  
  **Mitigation:** Ensure the first release covers the main settings categories users feel most often, while keeping the portability rule intact.

## Architecture Decision Records

- [ADR-001: Single-Scope Personal Settings Config](adrs/adr-001.md) — Establishes a personal-global config boundary and rejects multi-scope V1.
- [ADR-002: Curated Portable Core Product Approach](adrs/adr-002.md) — Selects a power-user portability approach with broad but selective first-release coverage.

## Open Questions

- Which exact settings within the current modal qualify as reliably portable in V1?
- Should agent-profile command details be part of the first portable contract when users may differ across machines?
- How strongly should Atelier emphasize this capability during setup versus keeping it mostly discoverable within settings?
- What level of future demand should trigger expansion into workflow profiles or broader portability layers?
