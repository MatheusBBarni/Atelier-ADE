# Session Tab Agent Visibility PRD

## Overview

Session Tab Agent Visibility helps solo power users manage multiple local coding-agent threads with less scanning and less guesswork. It solves a narrow but frequent problem inside Atelier: users can open the right project and still lose time figuring out which terminal tab belongs to which agent, which session matters now, and where to click next.

This PRD defines V1 as a focused inline navigator inside the existing project and session sidebar. The feature is for users who keep several agent-driven terminal tabs open at once and want faster attention routing without a separate monitoring dashboard. The value is practical and immediate: clearer identity, calmer re-entry after context switches, and faster jump-to-tab behavior inside the native workspace.

## Goals

- Reduce the time it takes a multi-session user to identify and open the correct terminal tab.
- Make mixed-agent sessions understandable at a glance without requiring users to open every tab.
- Preserve trust by using only factual, low-ambiguity status signals in V1.
- Strengthen Atelier’s value for advanced local agent workflows without expanding V1 into a full observability product.
- Validate that inline session visibility meaningfully improves navigation before broader follow-on surfaces are considered.

## User Stories

### Primary Persona — Solo Power User
- As a solo power user, I want to see which terminal tabs belong to which agents inside a session so that I can jump to the right work thread quickly.
- As a solo power user, I want the inline view to show only the terminal work that matters so that file-related noise does not slow me down.
- As a solo power user, I want direct tab access from the session view so that I can move from scan to action in one step.

### Secondary Persona — Returning Context Switcher
- As a returning user, I want restored sessions to remain calm and readable so that I can choose what to inspect without the sidebar feeling overloaded.
- As a returning user, I want session details to be available on demand so that I can understand tab-level context when I need it.

### Secondary Persona — Multi-Agent Organizer
- As a user running different agent profiles in parallel, I want each tab’s identity to stay visible and consistent after restore so that my workspace remains legible over time.
- As a user managing several related sessions, I want factual signals such as identity and completion-related state so that I can trust what the product is showing me.

## Core Features

### Critical

**Inline terminal-tab visibility within expanded session rows**  
The project sidebar should allow users to expand a session and see the terminal tabs it contains. The list should be optimized for quick recognition and selection, not passive reading.

**Per-tab agent identity**  
Each visible terminal tab should present clear agent identity using the profile or agent context already associated with that tab. This identity should remain stable across relaunch and restore.

**Direct jump to the correct terminal tab**  
Users should be able to move from inline recognition to the selected tab immediately. The primary behavior of the feature is fast navigation, not passive monitoring.

**Strictly factual status communication**  
V1 should communicate only low-ambiguity signals the product can defend from a user perspective. It should avoid stronger live-state language that implies certainty the product does not yet have.

### High

**Restore-safe sidebar behavior**  
Restored workspaces should remain visually calm by default. Sessions should stay collapsed on return, while preserving the ability to open session details when the user chooses.

**Consistent session comprehension for mixed-agent work**  
The feature should make sessions with multiple agent types easier to understand without introducing a new dashboard or a separate agent-management mode.

### Interaction Between Features

These features work together as one navigation loop:
1. the user scans sessions in the existing sidebar,
2. expands the relevant session,
3. identifies the correct terminal tab through agent identity and factual signals,
4. opens that tab immediately.

If any step fails, the feature loses most of its value. The PRD therefore treats scan clarity and direct jump behavior as inseparable.

## User Experience

### Primary Flow
1. The user opens Atelier and sees the familiar project and session sidebar.
2. The user scans sessions to decide where attention is needed.
3. The user expands one session.
4. The user sees the terminal tabs in that session, each with recognizable agent identity and concise factual context.
5. The user selects the correct tab directly from the inline view.
6. The user resumes work without opening several wrong tabs first.

### Return Flow
1. The user returns to a restored workspace.
2. The sidebar remains calm because sessions are still collapsed by default.
3. The user expands only the session they want to inspect.
4. The user understands the terminal tabs quickly and resumes the correct thread.

### UX Considerations
- The experience must improve scan speed, not create a denser or noisier sidebar.
- Terminal work should be the focus of the inline view in V1.
- Status wording must feel trustworthy and restrained.
- The feature should remain discoverable without introducing a separate onboarding flow or a new top-level workspace concept.
- The inline view should support fast recognition through concise labeling and strong visual differentiation between tabs.

### Accessibility and Discoverability
- Session expansion and tab selection should remain accessible through the same interaction model users already rely on in the sidebar.
- Labels and hierarchy should remain readable for users who rely on clear structure rather than color alone.
- Discoverability should come from extending an existing navigation surface rather than forcing users to learn a new panel.

## High-Level Technical Constraints

- The V1 product experience must fit inside Atelier’s existing project and session navigation model rather than introduce a separate management surface.
- The feature must preserve restore behavior that feels calm and intentional from the user’s perspective.
- The V1 promise must stay within signals the product can present truthfully and consistently.
- The initial user-facing scope is limited to terminal tabs, even though the broader session model may include other tab types.
- The feature should preserve Atelier’s local-first and workspace-centered product identity.

## Non-Goals (Out of Scope)

- A dedicated global Agents panel
- Team monitoring, collaboration, or shared session oversight
- Strong inferred states such as active, idle, blocked, or stale
- Cross-agent operational controls such as pause, kill, reprioritize, or inline response
- File-tab visibility inside the inline session view
- A broader observability or analytics product
- Mandatory parity with every other navigation surface in the same release

## Phased Rollout Plan

### MVP (Phase 1)
**Included**
- Expanded session rows show terminal tabs only
- Clear per-tab agent identity
- Factual, trust-preserving tab context
- Direct jump from inline session view to the correct terminal tab
- Restored workspaces remain collapsed by default

**Success criteria to proceed**
- Measurable reduction in scan-to-action time
- Positive evidence that users open fewer wrong tabs
- Strong qualitative feedback that the sidebar is easier to read, not noisier

### Phase 2
**Included**
- Stronger resume support around recent or notable session context
- More refined discoverability and inline information hierarchy
- Possible selective reuse of agent identity treatment in adjacent navigation surfaces when it clearly improves consistency

**Success criteria to proceed**
- Users continue to rely on the feature after the first learning period
- Evidence shows that richer context improves navigation without harming trust
- Product confidence increases that the identity layer is worth expanding

### Phase 3
**Included**
- Broader agent-session visibility patterns
- More advanced attention management for power users
- A clearer product decision on whether Atelier should become a fuller local agent control surface

**Long-term success criteria**
- The product becomes meaningfully better for multi-agent local workflows than generic terminal or vendor-specific tooling
- Expanded visibility increases power-user retention and daily reliance on the workspace

## Success Metrics

- **Median scan-to-action time for users with 3 or more terminal tabs:** improve by **40 percent**
- **Wrong-tab open rate in multi-tab workflows:** reduce by **30 percent**
- **Returning multi-session users reaching the correct tab in under 10 seconds:** reach **75 percent or higher**
- **Adoption among users with 3 or more open terminal tabs within 14 days of release:** reach **60 percent or higher**
- **Perceived clarity score in pilot or post-release feedback:** reach **4.2 out of 5 or better**

## Risks and Mitigations

**Adoption risk**  
Users may not change behavior if the new surface feels like extra decoration rather than a faster path.  
**Mitigation:** keep the feature action-oriented, make direct tab jump central, and measure scan-to-action improvements early.

**Trust risk**  
Users may stop relying on the feature if status wording feels overstated or inconsistent.  
**Mitigation:** use strictly factual status in V1 and avoid stronger interpretive language.

**Clutter risk**  
The sidebar may feel busier and less calm if the inline view shows too much information.  
**Mitigation:** keep sessions collapsed by default, show only terminal tabs, and prioritize concise labels over dense metadata.

**Competitive risk**  
The feature may look too small compared with broader agent windows in competitor products.  
**Mitigation:** frame V1 around speed, truthfulness, and native workflow fit rather than breadth, then expand only if user behavior justifies it.

**Scope risk**  
Pressure may grow to add file context, prioritization logic, or global monitoring too early.  
**Mitigation:** anchor the release on the approved approach and treat broader visibility surfaces as later phases, not MVP additions.

## Architecture Decision Records

- [ADR-001: Scope V1 as inline session-row attention routing](adrs/adr-001.md) — Establishes sidebar-first visibility, durable per-tab identity, and a truthful low-ambiguity scope.
- [ADR-002: Adopt a focused inline navigator approach for the PRD](adrs/adr-002.md) — Commits the PRD to terminal-only inline rows, factual status, collapsed restore behavior, and fast jump-to-tab outcomes.

## Open Questions

- Final user-facing wording for factual status communication
- The most useful factual context beyond identity, such as recency or completion-related state
- The best lightweight discoverability cue for users who may not think to expand sessions
- The timing and value threshold for bringing the same identity treatment into adjacent navigation surfaces
