# Native Mac ADE

## Overview

Native Mac ADE is a local-first macOS product for solo AI-heavy developers who work across a small set of important repositories and return to them repeatedly during the day. It replaces the fragmented workflow of IDE sidebars, terminal tabs, Finder windows, and ad hoc notes with a project-first workspace built around persistent project navigation, project-scoped sessions, and fast in-context terminal work.

The product’s core value is speed with confidence. V1 should make it dramatically faster to open the right project, start or resume the right session, and open new tabs in the right context. It should feel calmer and more trustworthy than broader ADE products by staying focused on the high-frequency workflow loop instead of trying to own orchestration breadth on day one.

## Goals

- Make Native Mac ADE the default place where pilot users begin terminal-agent work on macOS.
- Reduce context-switching friction for developers who revisit a few active repositories many times per day.
- Lower wrong-project and wrong-context mistakes by making project selection and default context explicit.
- Deliver a first release that feels native, reliable, and easy enough to keep open all day.

### Business Objectives and Expected Outcomes

- Prove that a workflow-speed-first wedge can win against an IDE-plus-terminal-tabs workaround.
- Establish a clear product position as a calmer, more native alternative to broader ADE tools.
- Validate that users will adopt a session-first workspace even without deeper orchestration features in V1.

### Milestones

- **MVP readiness**: the core project, session, tab, and restore loop is stable enough for pilot use.
- **Pilot validation**: users adopt the product as part of their daily workflow and report meaningful time/confidence gains.
- **Phase advancement**: deeper continuity or supervision features are considered only after the MVP workflow loop proves itself.

## User Stories

### Primary Persona: Solo AI-Heavy macOS Developer

- As a solo developer, I want to open a repository once and keep it in a persistent sidebar so that I can return to it quickly throughout the day.
- As a solo developer, I want each project to have its own named sessions so that I can organize work by repo and task without losing track of context.
- As a solo developer, I want a new tab to start in the currently selected project so that I do not waste time correcting the working context.
- As a solo developer, I want to relaunch the app and return to my previous projects and sessions so that interruptions do not force me to rebuild my workflow.
- As a solo developer, I want lightweight agent shortcuts when starting a session so that common workflows feel faster without adding extra complexity.

### Secondary Persona: Consultant or Freelancer

- As a consultant, I want to keep several client projects visible and separated so that I can switch between them without mixing up work.
- As a consultant, I want to rename sessions clearly so that I can recognize purpose and history at a glance.
- As a consultant, I want basic visibility into what I was doing most recently in a session so that I can resume work confidently after context switching.

### Edge Cases

- As a user returning after a restart, I want the product to reopen into a familiar state so that the first action of the day feels immediate.
- As a user juggling a few active repos, I want the active project to be obvious so that quick tab creation never feels risky.

## Core Features

### Critical

- **Persistent Project Sidebar**  
  The sidebar is the primary navigation surface. When a user opens a project, it remains available for future sessions until the user removes it. This supports the target pattern of a few active projects with many returns.

- **Project-Scoped Sessions**  
  Every project has its own session list. New sessions receive a default timestamp-based name and can be renamed later. Sessions help users separate work without inventing a heavier orchestration model.

- **Context-Correct Terminal Tabs**  
  When the user creates a new tab, the app uses the selected project as the default context. This is the core speed promise of the product and a direct improvement over generic terminal tabs.

### High

- **Basic Restore and Resume**  
  The app restores the user’s recently open projects, selected context, and session/tab state after relaunch. V1 should promise basic continuity, not a deep historical replay model.

- **Active Context Clarity**  
  The current project and session should be visually obvious throughout the workspace. Users should not need to guess where a new tab will open or which session they are looking at.

- **Lightweight Agent Shortcuts**  
  The app may offer a small set of shortcuts or presets for common agent-start workflows inside a session. These should speed up routine actions without changing the product’s core project/session model.

### Medium

- **Recent Session Orientation**  
  Users should be able to recognize which sessions were active most recently. V1 should provide enough orientation to support confident returns without expanding into heavy monitoring or checkpoint systems.

### Feature Interaction Principles

- The sidebar determines the active project.
- The active project determines the default context for new tabs.
- Sessions belong to projects, not to a global workspace.
- Restore should return the user to a recognizable working state across those same concepts.

## User Experience

### First Use

1. The user opens a project.
2. The project appears in the sidebar and becomes the active workspace.
3. The app opens a terminal experience inside that project context.
4. The user can begin a session immediately or accept the default session naming pattern.

### Repeat Use

1. The user reopens the app.
2. The sidebar restores familiar projects.
3. The user selects a project and resumes a prior session or opens a new tab in that project.
4. The product minimizes setup steps and reinforces confidence through clear active-state cues.

### Primary UX Principles

- **Speed over ceremony**: the fastest path to useful work should be the default path.
- **Project context is always explicit**: users should always know which project is active.
- **Session management should feel lightweight**: sessions provide structure without introducing operator overhead.
- **Mac-native calm**: the product should feel trustworthy, focused, and consistent with long-lived desktop use.

### Onboarding and Discoverability

- Opening the first project should immediately teach the core model.
- Session rename, new tab behavior, and recent-session recognition should be obvious without documentation.
- Agent shortcuts, if included, should feel optional and helpful rather than central to understanding the product.

### Accessibility and Usability Expectations

- Keyboard-friendly navigation should support fast switching between projects, sessions, and tabs.
- Labels, active states, and focus indicators should be visually clear.
- The product should remain understandable during rapid switching, not only during deliberate step-by-step use.

## High-Level Technical Constraints

- The core experience must feel native to macOS rather than like a browser-based workspace.
- Core workflows must work without requiring a cloud account or always-on remote dependency.
- The product must preserve clear project boundaries and avoid ambiguous cross-project behavior in V1.
- User privacy and trust must remain central, especially around session memory and app behavior after relaunch.
- The product must meet a user-perceived speed bar where opening or resuming work feels nearly immediate.

## Non-Goals (Out of Scope)

- **Multi-agent orchestration and fleet-style work management** — V1 is not trying to compete with broader ADEs on orchestration depth.
- **Remote execution, SSH-first workflows, or cloud sync** — These expand the product surface beyond the chosen wedge.
- **Embedded editor or full IDE behavior** — The product should complement terminal-agent workflows, not become a broad coding suite in V1.
- **Deep checkpoints, timelines, or rich historical replay** — V1 promises basic restore, not a full continuity control plane.
- **Team collaboration features** — The first release is optimized for solo use, not shared workflows.
- **Plugin marketplace or heavy automation rules** — These add breadth before the core workflow is validated.

## Phased Rollout Plan

### MVP (Phase 1)

**Included**
- Persistent project sidebar
- Project-scoped sessions with rename support
- New tabs opening in the selected project
- Basic restore and resume
- Clear active project/session cues
- Lightweight agent shortcuts

**Success criteria to proceed**
- Pilot users begin most terminal-agent work here
- Users report materially faster project switching than their current workaround
- Restore behavior is reliable enough to build daily trust

### Phase 2

**Additions**
- Better recent-session orientation
- Stronger visibility into session recency and activity
- Improved controls around session memory and user confidence

**Success criteria to proceed**
- Users still adopt the product as a daily workspace after the novelty period
- Users ask for deeper continuity or supervision within the existing model rather than entirely different workflows
- The product position remains clear and differentiated

### Phase 3

**Longer-term expansion**
- Deeper continuity features if justified by user behavior
- Richer session-level trust and recovery capabilities
- Select advanced workflow surfaces only if they strengthen the existing wedge rather than blur it

**Long-term success criteria**
- The product becomes a durable habit for target users
- Users see it as a distinct category leader for this narrow workflow
- Expansion happens from proven demand, not from imitation of broader competitors

## Success Metrics

- **Workflow replacement**: at least 70% of pilot users’ terminal-agent sessions begin in Native Mac ADE within 14 days.
- **Weekly engagement**: active pilot users start or resume at least 20 project sessions per week.
- **Restore reliability**: at least 99% of expected project and session state returns successfully after relaunch.
- **Time to ready context**: median time from app open to an interactive terminal in the selected project stays at or below 10 seconds.
- **Perceived workflow speed**: at least 80% of pilot users say project switching feels materially faster than their previous setup.
- **Trust and polish**: at least 80% of pilot users rate reliability and native feel at 4 out of 5 or higher.

## Risks and Mitigations

- **Users see the product as nice-to-have rather than essential**  
  Mitigation: keep the MVP centered on a painfully frequent workflow and measure real workflow replacement early.

- **The product looks too narrow next to Orca or Warp**  
  Mitigation: position it clearly as a calmer, native, solo-developer tool that solves one high-frequency job better.

- **Users want richer continuity than the MVP promises**  
  Mitigation: set expectations around basic restore in V1 and use Phase 2 to deepen continuity only if the demand is real.

- **The product feels like workflow polish without enough visible value**  
  Mitigation: make speed gains obvious in onboarding, default behavior, and day-to-day switching.

- **Scope expands before the wedge is proven**  
  Mitigation: gate later features behind clear pilot success criteria and preserve the non-goals explicitly.

## Architecture Decision Records

- [ADR-001: Session-First Native macOS ADE Scope for V1](adrs/adr-001.md) — Establishes the local-first project → session → tab model and rejects broader orchestration scope in V1.
- [ADR-002: Adopt a Workflow-Speed-First PRD for V1](adrs/adr-002.md) — Sets faster project-based workflow as the primary product framing for the first release.

## Open Questions

- How much recent activity should V1 expose without turning basic restore into a deeper history system.
- Which lightweight agent shortcuts are frequent enough to deserve first-class visibility in the first release.
- Whether product messaging should lead with “projects,” “sessions,” or “terminal-agent workflow” in external positioning.
- What privacy controls users expect around retained local session context as the product expands beyond MVP.
