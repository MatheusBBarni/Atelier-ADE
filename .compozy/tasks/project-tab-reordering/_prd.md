# Project and Tab Reordering PRD

## Overview

Project and Tab Reordering gives Atelier users direct control over the order of the two workspace surfaces they revisit most: the persistent project sidebar and the active tab layer. It is for heavy multi-project users and AI-heavy session jugglers who repeatedly return to the same repositories and tabs throughout the day and want the workspace to preserve their own priority instead of forcing them to reconstruct it from recency.

The product value is calmer re-entry, faster recovery after context switches, and less wasted navigation. The feature is not about broad customization. It is about making order itself a trustworthy part of the workspace, so the user can place important projects and tabs where they expect to find them and see that order survive normal use.

## Goals

- Reduce repeated re-navigation when users move between active projects and in-flight tabs.
- Make custom order feel durable enough that users rely on it across relaunch, restore, and daily switching.
- Strengthen Atelier’s appeal for advanced local AI workflows without turning the MVP into a broader workspace-management system.
- Deliver a first release that covers both project-level and tab-level priority while keeping adjacent priority tools out of scope.
- Validate within the first 30 days after release that manual ordering improves daily navigation behavior for the target audience.

## User Stories

### Primary Persona — AI-Heavy Multi-Project Power User
- As an AI-heavy multi-project power user, I want to reorder projects in the sidebar so that the repositories I care about most stay where I expect them.
- As an AI-heavy multi-project power user, I want to reorder active tabs so that my most important work threads stay visually prominent.
- As an AI-heavy multi-project power user, I want my chosen order to remain stable across relaunch and restore so that I do not have to rebuild my workspace every time I return.

### Secondary Persona — Returning Context Switcher
- As a returning user, I want the workspace to reopen with my preferred order intact so that I can resume work without scanning through a reshuffled layout.
- As a returning user, I want order to reflect my intent rather than only recent activity so that long-running tasks do not disappear into the middle of the workspace.

### Secondary Persona — Session Juggler
- As a user juggling several active threads, I want tab order to stay under my control so that I can keep related work close together.
- As a user moving between several projects in one day, I want project order and tab order to follow the same mental rule so that the product feels predictable.

## Core Features

### Critical

**Persistent project reordering**  
Users can move projects above or below other projects in the sidebar and treat that order as a personal priority layer for daily work.

**Persistent tab reordering**  
Users can change the order of the active tabs they rely on and keep that arrangement instead of falling back to a purely recent-first experience.

**Restore-safe custom ordering**  
Custom project and tab order should remain intact through relaunch, restore, and normal use so the feature earns trust rather than creating fresh uncertainty.

**Clear reorder feedback**  
The experience should make it obvious where an item will land before the move completes, reducing hesitation and accidental placement.

### High

**Consistent ordering rules across surfaces**  
Projects and tabs should feel governed by the same promise: when the user deliberately changes order, that choice remains authoritative until they change it again.

**Fast recovery from mistakes**  
Correcting an accidental move should feel easy and low-risk so that users stay willing to use the feature in real workflows.

### Interaction Between Features

These features work as one navigation loop:
1. the user arranges projects so the most important repositories stay in a familiar place,
2. opens the right project faster,
3. arranges tabs so the most important active work stays visible in a preferred order,
4. returns later and finds both layers still aligned with intent.

If order does not persist or if one surface behaves differently from the other, the product promise weakens quickly. The PRD therefore treats persistence, predictability, and easy correction as core to the feature rather than optional polish.

## User Experience

### Primary Flow
1. The user opens Atelier and sees the familiar workspace.
2. The user notices that projects and tabs can be arranged to match personal priority.
3. The user reorders the most important projects first.
4. Inside active work, the user reorders tabs to keep the most relevant threads prominent.
5. The user leaves and returns later.
6. The same order is still there, making re-entry calmer and faster.

### Return Flow
1. The user comes back after an interruption or relaunch.
2. The project list still reflects the user’s chosen priority rather than a newly shuffled sequence.
3. The active tab layer still reflects the user’s preferred working order.
4. The user reaches the right project or tab with fewer corrective clicks.

### UX Considerations
- The feature should feel like a natural extension of the existing workspace, not a new management mode.
- Manual order must feel stronger than recency once the user has chosen it.
- Discoverability should come from the direct interaction itself and from the stability users experience after using it once.
- The product should avoid visual clutter, decorative controls, or configuration-heavy setup.
- Hierarchy and movement cues should remain understandable without relying on color alone.

### Accessibility and Discoverability
- Users should be able to understand that the surfaces are reorderable without a tutorial-heavy onboarding flow.
- The experience should support clear hierarchy, readable labels, and obvious movement feedback.
- Discoverability should reinforce trust by showing stable results after the first successful use.

## High-Level Technical Constraints

- The feature must preserve Atelier’s existing promise of restore-safe workspace continuity from a user perspective.
- The MVP must fit the existing project sidebar and current tab navigation model rather than introduce a separate management surface.
- The product promise must remain coherent across the visible tabs users already treat as one workspace flow.
- The feature must preserve the product’s local-first, workspace-centered identity.

## Non-Goals (Out of Scope)

- Pinning, favorites, or smart auto-sorting
- Grouping, nesting, or multi-item movement
- Cross-window or cross-pane movement between unrelated containers
- Shared or collaborative ordering semantics
- A broader workspace customization system
- New top-level navigation panels created only for managing order

## Phased Rollout Plan

### MVP (Phase 1)
**Included**
- Project reordering in the persistent sidebar
- Tab reordering in the active workspace layer
- Order persistence across normal use, relaunch, and restore
- Clear feedback during reordering
- Easy user correction after an accidental move

**Success criteria to proceed**
- Measurable reduction in re-navigation for target users
- Evidence that users reuse custom order rather than treating it as a one-time novelty
- Strong user trust that chosen order stays intact over time

### Phase 2
**Included**
- Better discoverability and clearer repeat-use cues for manual ordering
- More refined support for heavy users who rely on ordering throughout the day
- Product evaluation of whether adjacent priority tools such as pinned items deserve to follow manual ordering

**Success criteria to proceed**
- Sustained use of both project and tab ordering after the initial learning period
- Evidence that tab-level value is meaningful alongside project-level value
- Continued user demand for stronger priority controls without pressure to broaden into generic customization

### Phase 3
**Included**
- A broader workspace-priority model if user behavior justifies expansion
- Carefully chosen adjacent priority tools that complement manual ordering
- Stronger product positioning around personal workspace control for advanced users

**Long-term success criteria**
- Atelier becomes meaningfully better at preserving user intent than recency-driven workspace tools
- Personal priority control improves power-user retention and daily reliance on the product

## Success Metrics

- **Median time to reach the intended project or tab during context switches:** improve by **30 percent**
- **Wrong-navigation correction rate:** reduce by **25 percent**
- **Adoption among users with 5 or more projects or 6 or more tabs within 21 days of release:** reach **50 percent or higher**
- **Reuse of saved custom order across at least 3 distinct sessions within 30 days:** reach **40 percent or higher**
- **Successful reorder completions without immediate corrective movement:** reach **90 percent or higher**
- **Order persistence after restart or restore:** reach **99 percent or higher**

## Risks and Mitigations

**Adoption risk**  
Users may like the idea of manual order but not change daily behavior enough for it to matter.  
**Mitigation:** keep the MVP focused on high-frequency navigation moments and measure repeat use, not just first use.

**Trust risk**  
Users may stop relying on the feature if order feels unstable or inconsistent after return.  
**Mitigation:** make durable persistence part of the core product promise and treat stability as a launch requirement.

**Uneven value risk**  
Project ordering may deliver clearer value than tab ordering, making the combined story feel lopsided.  
**Mitigation:** measure project-layer and tab-layer outcomes separately inside the same PRD and use later phases to rebalance if needed.

**Expectation risk**  
Users may expect pinning, grouping, or wider customization once ordering exists.  
**Mitigation:** define narrow non-goals clearly and keep the product story centered on manual priority only.

**Competitive framing risk**  
The feature may look like parity if it is described only as drag-and-drop convenience.  
**Mitigation:** position it as durable personal priority that improves re-entry and focus, not as generic movable UI chrome.

## Architecture Decision Records

- [ADR-001: Projects-First Reordering Scope for V1](adrs/adr-001.md) — Records the earlier idea-stage recommendation to narrow V1 to project ordering first.
- [ADR-002: Dual-Surface MVP for Project and Tab Reordering](adrs/adr-002.md) — Commits the PRD to a tight first release that includes both project and tab ordering while keeping adjacent priority tools out.

## Open Questions

- Whether success should require separate adoption thresholds for project ordering and tab ordering
- Whether the tab experience should be framed primarily around active work management or around calmer return to in-flight tasks
- What user-facing recovery cue is sufficient to make accidental moves feel obviously reversible
- What evidence threshold should trigger later expansion into adjacent priority tools
