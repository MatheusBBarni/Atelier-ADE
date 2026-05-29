# Tabbed File Explorer

## Overview

Tabbed File Explorer extends Another ADE from project-and-session navigation into file-level work that active coders can complete without leaving the app for every small inspection or correction. The feature adds a right-side file surface that keeps the likely next files visible, lets users open them in syntax-aware tabs, and supports quick in-context edits while preserving the product’s terminal-first identity.

The feature is for solo active coders who spend long stretches inside one or a few repositories and frequently bounce between terminal output and source files. It is valuable because it removes a repeated context break from the current workflow: the user already knows the right project and session, but still has to leave Another ADE to inspect or change the right file. The MVP should solve that high-frequency problem without expanding into a full editor-first workspace.

## Goals

### Product Goals
- Reduce the number of times pilot users leave Another ADE for quick file inspection or small code changes.
- Make file access feel fast, obvious, and trustworthy inside the existing project → session → tab workflow.
- Prove that light in-app editing increases daily usefulness without weakening the product’s terminal-first wedge.

### Business Objectives and Expected Outcomes
- Increase the share of active coding sessions that remain inside Another ADE for both terminal work and nearby file work.
- Strengthen Another ADE’s position as the place where users begin, resume, and continue coding work rather than only launch terminal actions.
- Validate whether quick-fix editing is enough to create a daily habit before investing in broader editor capabilities.

### Milestones
- **MVP readiness**: the file surface is usable enough for real pilot work, especially quick inspection and small edits.
- **Pilot validation**: users rely on it repeatedly during daily coding and report meaningfully less app switching.
- **Expansion gate**: richer editor behavior is considered only if pilots prove strong demand beyond quick-fix use cases.

## User Stories

### Primary Persona: Solo Active Coder
- As a solo developer, I want to open a relevant file from the current workspace without leaving Another ADE so that I can stay in flow during active coding.
- As a solo developer, I want the sidebar to surface the files I am most likely to need next so that I spend less time hunting through the repository.
- As a solo developer, I want opened files to render with code-aware visual clarity so that I can inspect and understand them quickly.
- As a solo developer, I want to make small in-context edits in the same session so that I do not need a second tool for every quick fix.
- As a solo developer, I want to switch cleanly between terminal tabs and file tabs so that project context stays obvious.

### Secondary Persona: Consultant or Freelancer
- As a consultant, I want a clear file path and project context when I open a file so that I do not make changes in the wrong repository.
- As a consultant, I want to move from file inspection to my full editor when needed so that larger tasks still feel supported.

### Edge Cases
- As a returning user, I want enough continuity to regain orientation quickly after relaunch so that interruptions do not erase momentum.
- As a user opening an unsupported or awkward file, I want the product to guide me toward the right next step so that the experience still feels trustworthy.

## Core Features

### Critical
- **Session-Aware Working Set Sidebar**  
  The right sidebar should prioritize files that are most useful during the current session, such as recently opened, pinned, or otherwise relevant files, before falling back to the broader repository tree.

- **Secondary Repository Tree**  
  Users should still be able to browse the workspace directly through a recognizable folder and file structure. This gives orientation and familiarity without making the tree the dominant product model.

- **Syntax-Aware File Tabs**  
  Opening a file should create an in-app tab that renders code with clear language-aware visual structure. The experience should support fast inspection and reduce the cognitive load of raw text.

- **Quick-Fix Editing**  
  The MVP should allow light code changes inside Another ADE so that small corrections, adjustments, or follow-up edits do not require an external editor.

### High
- **Context Clarity Across Terminal and File Work**  
  The product should make the active project, session, and open file relationship easy to understand so users can move between terminal work and file work without confusion.

- **External Editor Escalation**  
  Users should be able to continue in their preferred editor when a task grows beyond quick-fix scope. Another ADE should support that escalation cleanly rather than compete with it prematurely.

- **Fast Single-File Access**  
  The first release should make opening the next needed file feel immediate, especially for the common case of finding and opening one relevant file from an active session.

### Feature Interaction Principles
- The project and session remain the top-level context.
- The sidebar helps users reach files inside that context faster.
- File tabs complement terminal tabs rather than replacing them.
- Editing in MVP supports quick progress, not full editor replacement.

## User Experience

### First Use
1. The user opens or resumes a project and session as they do today.
2. The new right sidebar reveals a working set and a repository tree.
3. The user clicks a file and sees it open in a syntax-aware tab inside the same workspace.
4. The user makes a small change or inspects the file, then returns to terminal work or escalates to an external editor if needed.

### Repeat Use
1. The user returns to Another ADE and resumes the right project and session.
2. The sidebar makes the next likely files easy to reach.
3. The user alternates between terminal output and file tabs without leaving the app for every small task.
4. The product reinforces confidence through clear path context, obvious active states, and a calm layout.

### UX Principles
- **Speed over ceremony**: opening the next useful file should feel immediate.
- **Context stays explicit**: the user should never lose track of project, session, or file location.
- **Working set before hierarchy**: the product should favor likely next actions over forcing users through the full tree every time.
- **Mac-native calm**: the new surface should feel integrated, not like an IDE bolted onto a terminal shell.

### Onboarding and Discoverability
- The sidebar should explain itself through visible working-set cues and familiar tree behavior.
- The distinction between quick-fix editing and full-editor work should be understandable without documentation.
- Escalating to an external editor should feel like a natural next step, not a fallback failure.

### Accessibility and Usability Expectations
- Keyboard-friendly file access and tab switching should remain central for fast users.
- Active states, selected files, and project boundaries should be visually clear.
- The layout should remain readable under rapid context switching, not only careful step-by-step use.

## High-Level Technical Constraints

- The experience must remain native to macOS and consistent with the current local-first product feel.
- The feature must preserve clear project boundaries so users do not lose confidence about where edits apply.
- The product should maintain fast perceived performance when opening common code files and switching between terminal and file context.
- Privacy and trust expectations should remain aligned with the product’s local-first positioning.
- The feature should not force the product into a broad full-IDE promise before later phases justify that expansion.

## Non-Goals (Out of Scope)

- **Full editor replacement** — The MVP is not meant to displace general-purpose IDEs for all coding tasks.
- **Broad IDE authoring depth** — Rich authoring features, deep code-intelligence expectations, and full editing parity are explicitly deferred.
- **Repository file management suite** — Creating, renaming, moving, duplicating, or deleting files is outside the first release.
- **Advanced multi-pane editing workflows** — Split editors, compare-heavy layouts, and broader editing choreography belong to later phases.
- **Unlimited continuity promises for file state** — The MVP should not promise full document-history or editor-session restoration beyond what it can explain clearly.

## Phased Rollout Plan

### MVP (Phase 1)
**Included**
- Session-aware right sidebar
- Secondary repository tree
- Syntax-aware file tabs
- Quick-fix editing
- Clear terminal/file context cues
- External editor escalation

**Success criteria to proceed**
- Pilot users rely on in-app file access repeatedly during active coding.
- Users report materially less app switching for inspection and small edits.
- The product still feels focused and trustworthy rather than bloated.

### Phase 2
**Additions**
- Stronger working-set intelligence such as pinned, recent, or changed-file emphasis
- Better continuity around recently opened file work
- More explicit user controls over file-surface behavior and layout

**Success criteria to proceed**
- Users continue to choose Another ADE for file-adjacent work after the novelty period.
- Demand for deeper editing capabilities appears consistently in pilot feedback.
- The product still reads as session-first, not editor-first.

### Phase 3
**Longer-term expansion**
- Broader file workflows only if the usage data proves that users want Another ADE to own more of the editing loop
- Stronger compare or review flows if they reinforce the terminal-and-file workflow rather than replace it
- Optional layout flexibility or richer file intelligence if it increases daily reliance

**Long-term success criteria**
- Users treat Another ADE as the default place to begin and continue active coding sessions.
- The feature compounds daily habit value rather than acting as a one-off convenience.
- Expansion decisions remain evidence-led rather than driven by generic IDE imitation.

## Success Metrics

- **Median time to open a target file from an active session**: at or below 5 seconds.
- **Weekly pilot users using the file surface on 3 or more days per week**: at least 70%.
- **Pilot users reporting less app switching for inspection and small edits**: at least 80% rate the improvement 4 out of 5 or higher.
- **Sessions with at least one in-app file open**: at least 60% of active pilot sessions by week 2.
- **Sessions with at least one in-app quick edit**: at least 40% of active pilot sessions by week 2.
- **Perceived workspace trust and clarity**: at least 80% of pilot users rate context clarity 4 out of 5 or higher.

## Risks and Mitigations

- **Users expect a full editor too soon**  
  Mitigation: position the MVP clearly around quick-fix editing and fast file access, then gate broader expansion behind evidence.

- **The feature weakens the terminal-first product story**  
  Mitigation: keep session context, working-set behavior, and terminal adjacency central in product messaging and rollout criteria.

- **The new surface adds clutter instead of calm**  
  Mitigation: prioritize fast single-file access, strong active-state cues, and a working-set-first default rather than a dense file-management UI.

- **Pilot success is ambiguous because users try the feature but do not adopt it**  
  Mitigation: track repeat weekly use, app-switch reduction, and quick-edit behavior instead of one-time activation alone.

- **Competitors make the feature feel undifferentiated**  
  Mitigation: emphasize the session-aware working-set model and measure whether that creates a stronger daily workflow loop than a generic tree-first experience.

## Architecture Decision Records

- [ADR-001: Scope tabbed-file-explorer as a session-aware working-set navigator](adrs/adr-001.md) — Establishes working-set-first navigation and protects the terminal-first wedge.
- [ADR-002: Adopt a working-set-first quick-fix editor approach for the PRD](adrs/adr-002.md) — Refines the MVP from preview-only tabs to syntax-aware tabs with light editing.

## Open Questions

- Which file types should the MVP clearly support for comfortable quick-fix editing from day one.
- How much continuity should users expect for open file tabs after relaunch.
- Whether the right sidebar should remain the default layout only or become configurable later.
- What pilot feedback threshold should justify expanding from quick-fix editing toward richer editor behavior.
