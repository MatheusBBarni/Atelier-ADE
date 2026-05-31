# Session Tab Agent Visibility

## Overview

Session Tab Agent Visibility helps solo power users understand which local coding-agent tab needs attention without opening every session or tab. The feature targets users who keep several agent-driven threads open in parallel and need faster, calmer navigation inside Atelier’s existing project and session structure.

The value is attention routing, not generic observability. V1 should be a **Quick Win**: show truthful per-tab agent context directly inside expanded session rows, preserve that context across restore, and use only low-ambiguity signals the product can defend. The goal is to reduce scan time and wrong-tab switching without pretending Atelier already has a full live-monitoring stack.

### Summary / Differentiator

Many competing tools surface agent activity in standalone dashboards or vendor-specific panes. Atelier can differentiate by making agent visibility feel native to the workspace itself: a **vendor-neutral, local-first attention layer** embedded directly in the session hierarchy users already scan.

## Problem

Atelier already gives users persistent projects, sessions, and terminal tabs, but it still makes multi-agent work harder than it should be. A user may have the correct project open and the right session selected, yet still waste time figuring out which terminal tab belongs to which agent, which thread is still relevant, and which tab deserves attention first. That friction compounds when several tabs look similar, when a session contains mixed agent types, or when the user returns after stepping away.

The real problem is not “missing labels.” It is that the workspace currently stops one layer too early for multi-agent workflows. The user needs fast situational awareness at the **tab-within-session** level, especially when juggling several active threads. Without that visibility, the current workflow encourages tab thrash, repeated verification clicks, and slower re-entry into work after even short interruptions.

This matters because AI-assisted coding is already mainstream, while multi-agent coordination is becoming a real workflow pattern. As more users run several agents in parallel, the product’s value increasingly depends on whether it can act as a reliable control surface for local work, not just a container for terminals. At the same time, shipping fake-precise activity states too early would damage trust. The opportunity is to solve the attention problem now with truthful signals, while leaving room for richer runtime observability later.

### Market Data

- Stack Overflow Developer Survey 2025 reports **51% of professional developers use AI tools daily**, and **84%** of developers use or plan to use AI tools in development workflows.
- The same survey shows workplace AI-agent usage is still early: **14.1%** use agents daily at work, **9%** weekly, and **17.4%** plan to start soon.
- Among agent users, **69%** report productivity gains, while only **17%** report improved team collaboration. That supports a **solo power-user** focus rather than a team-monitoring-first position.
- Competitive review across Claude Code Agent View, Cursor Agents Window, and community tools such as guppi and agenttop shows a common pattern: the most valuable monitoring surfaces are **attention-first**, not transcript-first.
- Current observability patterns in the market remain fragmented and often improvised, which leaves space for Atelier to offer a more native, local, and workflow-centered experience.

### Integration with Existing Features

| Integration Point | How |
| --- | --- |
| Project/session sidebar | Expanded session rows are the primary surface for inline tab-level agent visibility |
| Workspace models and restore flow | Per-tab agent identity must survive restore so sessions remain legible after relaunch |
| Existing terminal tabs | The feature adds context around terminal tabs rather than changing the terminal-first workspace model |
| Tab chrome | The same identity treatment can later be reused in the main tab strip if that reuse is cheap and coherent |

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Durable Per-Tab Agent Identity | Critical | Each terminal tab retains the agent or profile identity it was launched with, including mixed-agent sessions and restored workspaces. |
| F2 | Inline Session Agent Rows | Critical | Expanded session rows show the terminal tabs inside the session with agent label, tab label, and compact visual identity for faster scanning. |
| F3 | Trustworthy Attention Signals | Critical | V1 shows only low-ambiguity signals such as launch identity, exited state, and recency-oriented hints; it avoids strong active/idle/stale claims the runtime cannot yet support reliably. |
| F4 | Fast Jump to Relevant Tab | High | Users can select the relevant tab directly from the inline session view, reducing scan-to-action time and wrong-tab switching. |
| F5 | Restore-Safe Context Clarity | High | When users reopen Atelier, restored sessions preserve agent identity and remain understandable without re-opening every tab. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Median scan-to-action time for users with 3+ terminal tabs | **-40%** | Instrument time from sidebar interaction start to terminal tab activation before vs. after rollout |
| Wrong-tab open rate during multi-tab workflows | **-30%** | Track cases where users switch away from a newly opened tab within a short threshold and then open a different tab in the same session |
| Returning multi-session users reaching the correct tab in under 10 seconds | **>= 75%** | Measure time from app foreground or session restore to the first durable tab activation for users with restored multi-tab sessions |
| Adoption among users with 3+ open terminal tabs | **>= 60% within 14 days** | Count eligible users who interact with the inline session visibility surface during the first 14 days after release |
| Perceived clarity score | **>= 4.2 / 5** | Collect lightweight in-app or pilot feedback on whether the workspace is easier to scan and resume |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Maybe |
| **Frequency** | How often would users encounter this value? | Strong |
| **Differentiation** | Does this set us apart or just match competitors? | Strong |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Must do |

Leverage type: **Quick Win**

## Council Insights

- **Recommended approach:** Ship V1 as an inline session-row attention-routing feature grounded in durable per-tab identity and factual, trust-preserving signals.
- **Key trade-offs:** speed of learning versus semantic richness; trustworthy hints versus more ambitious live-state claims; scoped sidebar-first delivery versus stronger cross-surface parity.
- **Risks identified:** users may over-trust ambiguous status; sidebar density may increase; the feature may feel cosmetic if it does not materially reduce scan time; delaying tab-strip reuse too long could create product inconsistency.
- **Stretch goal (V2+):** evolve the identity layer into a broader native agent control surface with stronger runtime signals, attention prioritization, and possible quick actions.

## Out of Scope (V1)

- **Dedicated global Agents panel** — V1 should validate the inline attention-routing hypothesis before opening a second monitoring surface.
- **Authoritative active / idle / stale runtime states** — The current runtime does not yet support these semantics reliably enough to make strong claims.
- **Cross-agent control actions** — Pause, kill, reply, approve, or reprioritize actions would expand the feature from visibility into orchestration too early.
- **Mandatory tab-strip parity** — Reusing agent identity in the tab strip is valuable, but it should not block the first scoped release unless the reuse is effectively free.
- **Team or shared-session monitoring** — The validated user is the solo power user, not a team supervisor or collaboration admin.

## Architecture Decision Records

- [ADR-001: Scope V1 as inline session-row attention routing](adrs/adr-001.md) — Commits V1 to durable per-tab identity, sidebar-first visibility, and truthful low-ambiguity attention signals.

## Open Questions

- What exact user-facing status language should V1 use so it communicates useful attention hints without implying false runtime precision?
- Which recency signal is most useful and defensible in V1: last activation, recent output, exit state, or another event?
- Should restored multi-tab sessions default to expanded inline visibility, or stay collapsed unless the user opens them?
- If tab-strip identity reuse is genuinely cheap, should it ship in the same slice or immediately after the first release?
