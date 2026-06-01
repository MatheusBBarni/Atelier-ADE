# Project and Tab Reordering

## Overview

Project and Tab Reordering lets Atelier users drag projects to reorder the sidebar and move tabs vertically to preserve their own priority. It targets power users who keep many projects and tabs open and want the workspace to reflect how they think, not just recency. The feature matters because visual order is a form of working memory: when the app preserves deliberate placement, users spend less time re-navigating and less attention reconstructing context.

This idea should be treated as a **Strategic Bet**. The V1 scope is intentionally narrow in breadth—only project order and tab order—but ambitious in leverage because it brings two surfaces under one user-authored priority model in the same release.

### Summary / Differentiator

Most developer tools treat ordering as a local convenience inside one surface, or they lean on recency, pinning, and pane management. Atelier can differentiate by making **persistent personal priority** feel native across the workspace: the order the user creates becomes a durable, trustworthy navigation layer rather than a temporary UI detail.

## Problem

Atelier already gives users durable projects, sessions, and tabs, but it still decides too much of the visual hierarchy for them. A power user may know exactly which repositories matter most today and which tabs need to stay near the top of attention, yet the workspace offers limited control over that ordering. The result is small but repeated friction: scan, search, reopen, re-orient, repeat. When this happens dozens of times a day, the product feels more organized than a raw terminal, but still less controllable than the best daily-use tools.

The deeper problem is not just that lists cannot be rearranged. It is that the workspace does not yet let users externalize priority into the interface across the surfaces they consult most. Recency is useful, but recency is not the same as intent. A project that matters all week may not be the one touched most recently. A tab that anchors a long-running task may need to remain visually prominent even after other tabs open around it. Without user-authored order, Atelier makes the user carry that priority model in their head.

This matters more in AI-assisted workflows, where the number of simultaneous contexts rises quickly. Users are more likely to have multiple projects, restored sessions, and several tabs in flight at once. Every extra navigation correction eats into the very productivity gains AI tooling promises. The opportunity is to make the workspace feel calmer and more personal by preserving deliberate order where users already look.

### Market Data

- Cortex 2024 reports **58%** of engineering leaders believe developers lose **more than 5 hours per week** to unproductive work, and **26%** identify gathering project context as a top source of productivity loss.
- Stack Overflow Developer Survey 2025 reports **66%** of developers are frustrated when AI output is “almost right,” and **45.2%** say debugging AI-generated code takes more time. That reinforces the value of lowering navigation and context-reconstruction overhead around AI-heavy workflows.
- Competitive review shows **VS Code** supports drag-reordering for workspace folders and editor tabs, **Replit** supports personal prioritization through pinning/recent organization and tab moves, and **IntelliJ IDEA** lets users rearrange UI chrome. Manual ordering is a baseline expectation in serious tools, but not yet a differentiated, durable priority layer in AI-first workspaces.

### Integration with Existing Features

| Integration Point | How |
| --- | --- |
| Persistent project sidebar | Project reordering changes the order of durable sidebar entries users revisit constantly. |
| Workspace restore and persistence | Custom project and tab order must survive relaunch and restore without drifting. |
| Existing session and tab navigation | Tab reordering must align with current session context and tab selection behavior. |
| Shared tab model | If terminal and file tabs share one namespace, ordering semantics must stay predictable across mixed tab types. |

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Persistent Project Reordering | Critical | Users can drag projects above or below other projects in the sidebar, and Atelier preserves that custom order as their personal priority model. |
| F2 | Persistent Tab Reordering | Critical | Users can move tabs vertically within the relevant tab navigation surface, and the product preserves that order instead of falling back to pure recency. |
| F3 | Restore-Safe Custom Ordering | Critical | Custom project and tab order survives app relaunch, restored workspaces, and normal navigation without silent resets or drift. |
| F4 | Clear Drag Feedback and Drop Targets | High | Reordering interactions show obvious insertion states and nearby movement so users can predict where a project or tab will land before they drop it. |
| F5 | Consistent Ordering Semantics Across Surfaces | High | Projects and tabs follow similar mental rules: manual order wins when the user sets it, and the app does not unexpectedly reshuffle that order during normal use. |
| F6 | Low-Friction Recovery from Mistakes | High | If a user moves something accidentally, correcting the order is fast and obvious, so the feature remains trustworthy instead of fragile. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Median time to reach the intended project or tab during context switches | **-30%** | Instrument time from navigation start in the sidebar or tab surface to the first sustained activation of the intended destination before vs. after rollout. |
| Wrong-navigation correction rate | **-25%** | Track short-window reversals where a user opens one project or tab, then quickly switches to another nearby destination in the same navigation session. |
| Adoption among users with 5+ projects or 6+ tabs | **>= 50% within 21 days** | Count eligible active users who perform at least one reorder interaction during the first 21 days after release. |
| Reuse of saved custom order across 3+ sessions | **>= 40% within 30 days** | Measure users who return on three separate sessions while retaining a non-default project or tab order. |
| Successful reorder completions without immediate corrective move | **>= 90%** | Count reorder drops that are not followed by another reorder of the same item within a short threshold. |
| Order persistence after restart or restore | **>= 99%** | Compare saved order state against restored order for projects and tabs after relaunch or restoration events. |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Maybe |
| **Frequency** | How often would users encounter this value? | Strong |
| **Differentiation** | Does this set us apart or just match competitors? | Maybe |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Strong |

Leverage type: **Strategic Bet**

## Council Insights

- **Recommended approach:** The council recommended a narrower projects-first V1, then treating tab reordering as a follow-on once Atelier has a more coherent tab-priority surface.
- **Key trade-offs:** learning speed versus same-release parity; durable user-authored priority versus premature abstraction; higher strategic ambition versus a higher trust and complexity burden in V1.
- **Risks identified:** tab reordering may overload the first release; manual ordering may feel good without materially changing behavior; accidental drags or weak restore behavior could destroy trust quickly.
- **Stretch goal (V2+):** evolve manual ordering into a broader workspace-priority model that can later combine projects, tabs, pinning/favorites, and restore-aware priority behavior.

## Out of Scope (V1)

- **Pinning, favorites, or smart auto-sorting** — V1 should validate direct manual ordering before expanding into a larger prioritization system.
- **Grouping, nested project organization, or multi-select moves** — These add hierarchy and batch-management complexity beyond the first trusted reorder release.
- **Cross-window or cross-pane reparenting** — V1 should focus on order within the current surfaces, not moving items between distinct structural containers.
- **Keyboard-only reorder commands and layout presets** — Valuable for power users, but not necessary to validate the core manual ordering hypothesis.
- **Collaborative or shared ordering semantics** — Ordering is personal workspace state, not a team-synced coordination model in V1.

## Architecture Decision Records

- [ADR-001: Projects-First Reordering Scope for V1](adrs/adr-001.md) — The council recommended a projects-only first slice to reduce premature tab complexity.

## Open Questions

- What tab navigation surface should own the “move vertically” interaction so it feels coherent with the rest of Atelier?
- Should custom tab order be scoped globally per workspace, per session, or only within the currently visible tab set?
- What recovery affordance is necessary to make accidental moves feel safe enough for daily use?
- If early data shows strong project-layer value but weak tab-layer value, should the PRD split delivery after all?
