# Focus Workspace Continuity for Multiplexer-Heavy Workflows

## Overview

Focus Workspace Continuity gives Another ADE an opt-in workflow for power-user developers who already manage pane and window complexity in tmux, herdr, or another terminal multiplexer and want the app to become the fastest way back to the right work context.

This idea does not turn Another ADE into a multiplexer. It treats the app as a continuity layer: preserve the last meaningful project, session, and terminal context the app owns; make return-to-context fast; and keep the user out of avoidable app-level tab management. V1 should be a **Quick Win** aimed at increasing **Focus Workspace adoption**.

### Summary / Differentiator

Many tools offer resume, zen modes, or terminal-native agents. Another ADE can differentiate by offering a **truthful continuity layer** for multiplexer-heavy workflows: explicit multiplexer-friendly behavior, faster return to the right context, and no false promise of live pane control or process reattachment.

### Integration with Existing Features

| Integration Point | How |
| --- | --- |
| Focus Workspace policy | Extends the existing settings-first focus mode instead of creating a separate workflow product |
| Project / session / tab model | Uses the current hierarchy as the continuity surface users return to |
| Restore snapshot persistence | Broadens app-owned restore intent so users land closer to the last meaningful work context |
| Command registry and keyboard shortcuts | Adds or sharpens keyboard-first return-to-context behavior for pane/window switch moments |
| Session rows and tab UI | Makes the remembered focus target legible without introducing a pane model |

## Problem

Another ADE already supports projects, sessions, tabs, and restore, but multiplexer-heavy users still face a workflow gap. When they switch panes or windows in tmux-like environments, the terminal remains the place where work runs, while the app can become a second navigation layer that is easy to lose track of. The result is not just visual clutter. It is interruption cost: users must rediscover the right project, session, or tab before they can resume work.

The current product boundary makes that gap more visible. Restore is metadata-only, there is no live pane model, and the app cannot truthfully reattach to arbitrary running external terminal state. That means Another ADE should not compete with tmux on pane ownership. It should instead become better at the part it does own: helping users re-enter the right app context quickly and confidently after they leave it.

This matters because the broader market already validates terminal-native AI and keyboard-first development workflows. Mainstream tools now support resume and parallel sessions, while smaller tools are pushing further on attention routing and continuity. Another ADE has a practical opportunity in the middle: a smaller, honest, multiplexer-friendly continuity experience that fits the current architecture and can be shipped quickly.

### Market Data

- The **2025 Stack Overflow Developer Survey** reports **Bash/Shell at 48.7%**, **Vim at 24.3%**, and **Neovim at 14.0%**, which reinforces that terminal-centric and keyboard-first workflows remain significant.
- The **2024 Stack Overflow Developer Survey** reported that **76%** of respondents were using or planning to use AI tools in development, which increases the value of faster session recovery and parallel workflow support.
- **Homebrew Formula Analytics** shows **tmux at 464,529 installs over 365 days** versus **zellij at 57,326**, which suggests tmux remains the dominant visible multiplexer in the macOS-heavy developer slice relevant to this product.
- Mainstream products such as **Claude Code**, **Cursor**, **Warp**, and **OpenCode** already validate resume and parallel agent workflows, while smaller tools such as **projmux**, **comux**, and **TUICommander** validate the narrower pain around pane awareness, continuity, and "what needs me now" routing.

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Focus Workspace Continuity Preference | Critical | Users can enable an opt-in Focus Workspace mode for multiplexer-heavy workflows that prioritizes one clear work surface and reduces redundant app-side context switching. |
| F2 | Return-to-Context Command | Critical | The app provides a fast return path to the last meaningful project, session, and tab context so pane/window switching inside the terminal does not force manual rediscovery inside the app. |
| F3 | Truthful Context Restore | High | Restore preserves app-owned continuity signals such as the last active session, tab, launch profile, and current working directory when available, while clearly distinguishing reopened context from still-running external terminal state. |
| F4 | In-Product Continuity Cues | High | The workspace makes the current focus state and return target understandable so users know where the app will take them back without mistaking the behavior for hidden state or a bug. |
| F5 | Multiplexer-Friendly Framing | High | Settings copy, mode labeling, and supporting product language explain that Another ADE works well with tmux, herdr, and similar tools because it complements them rather than trying to replace them. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Focus Workspace adoption rate | **>= 10%** of monthly active desktop users within 60 days | Track unique users who enable the continuity-focused mode and divide by monthly active desktop users |
| 14-day enabled retention | **>= 70%** of enabled users remain opted in after 14 days | Measure the share of users who enable the mode and do not disable it within 14 days |
| Days-active-per-week lift | **+15%** within 30 days for enabled users | Compare average days active per week before and after enablement for the same cohort |
| Context return success rate | **>= 80%** within 30 days | Measure return-to-context actions or restores that are not followed by manual corrective session/tab switching within 2 minutes |
| App-level tab churn reduction | **-30%** within 30 days for enabled sessions | Compare tab creation and short-bounce tab switching frequency before vs. after enablement |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Maybe |
| **Frequency** | How often would users encounter this value? | Strong |
| **Differentiation** | Does this set us apart or just match competitors? | Maybe |
| **Defensibility** | Is this easy to copy or does it compound over time? | Pass |
| **Feasibility** | Can we actually build this? | Must do |

Leverage type: **Quick Win**

## Council Insights

- **Recommended approach:** Extend Focus Workspace as a recovery-first continuity layer for multiplexer-heavy users, with fast return-to-context behavior and an honest restore contract.
- **Key trade-offs:** faster learning versus deeper continuity ambition; minimal metadata versus a richer owned continuity model; explicit multiplexer-friendly language versus a more abstract continuity-first frame.
- **Risks identified:** solving rediscovery while missing deeper continuity pain, overpromising with multiplexer wording, and letting ad hoc restore state harden into accidental architecture.
- **Stretch goal (V2+):** evolve the feature into a stronger continuity and attention-routing layer that helps users identify which session, tab, or agent needs them next.

## Out of Scope (V1)

- **Live tmux, zellij, or pane-window awareness** — V1 should not model or control external multiplexer topology the app does not own.
- **True process reattachment or running shell restoration** — The current architecture cannot truthfully promise restoration of in-flight external terminal processes.
- **Remote or SSH continuity** — The product and prior specs explicitly keep remote-session semantics out of the current scope.
- **Full continuity control plane or named working-set platform** — That is a larger product bet and should wait until the quick-win adoption hypothesis is validated.
- **Broad public positioning as deep multiplexer integration** — V1 should avoid a market claim stronger than the actual product boundary.

## Architecture Decision Records

- [ADR-001: Scope V1 as Focus Workspace continuity for multiplexer-heavy workflows](adrs/adr-001.md) — Commits V1 to app-owned context recovery and honest multiplexer-friendly framing instead of live external session integration.

## Open Questions

- What should the user-facing name be: keep "Focus Workspace," add a continuity-oriented subtitle, or introduce a new mode label?
- Should the return target be strictly terminal-first, or should the last active file tab also participate when Focus Workspace is enabled?
- Which app-owned continuity signals are reliably available across all launch paths, especially current working directory and launch-profile identity?
- What is the best cohort definition for measuring multiplexer-heavy or power-user adoption without adding noisy analytics?
