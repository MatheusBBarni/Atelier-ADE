# Single-Tab Guardrail

## Overview

Single-Tab Guardrail gives Another ADE an opt-in preference for focused solo users who want one visible work surface per session instead of a tab-management workflow. It targets people who usually stay in one thread, often rely on tmux, herdr, or another terminal multiplexer inside the active session, and want the app to stop encouraging accidental tab sprawl.

The value is behavioral simplicity, not cosmetic minimalism. V1 should be a **Quick Win**: add a settings-first preference that prevents second-tab creation, keeps restore behavior truthful, and makes the single-tab contract obvious to the user. The launch should also explain this clearly in the README and the website so terminal-native users immediately understand why Atelier is a good fit for multiplexer-heavy workflows.

### Summary / Differentiator

Many tools offer focus or zen views that hide chrome. Atelier can differentiate by offering a **truthful single-tab guardrail**: not just fewer visible tabs, but fewer chances to create the wrong surface in the first place. That also gives the product a clearer story for tmux, herdr, and other terminal-multiplexer users who already manage complexity inside the terminal and do not want a second navigation layer from the app.

### Integration with Existing Features

| Integration Point | How |
| --- | --- |
| Config modal / app preferences | The feature should live in the existing settings surface as an opt-in personal preference |
| Project / session workflow | The feature keeps the current project-and-session model intact instead of redefining session behavior |
| Terminal-first usage | The feature supports users who already manage complexity inside tmux, herdr, or similar terminal multiplexers |
| Existing tab visibility work | The feature complements broader wrong-tab clarity improvements but should remain independently scoped |
| README and website (`web`) | Launch messaging should explain that Atelier is terminal-multiplexer-friendly because it can remove redundant app-level tab management for single-surface workflows |

## Problem

Another ADE already supports projects, sessions, and mixed tab workflows, but that flexibility creates unnecessary friction for a subset of users. Some users do not want multiple visible tabs at all. They want a single active surface, especially when they already use tmux, herdr, or another terminal multiplexer inside the terminal itself. For those users, the current tab model adds a second layer of navigation that feels redundant, increases scan cost, and makes wrong-tab mistakes more likely.

This is not only a visual clutter issue. It is a control issue. When the product allows several paths to open more tabs, users who intended to stay in one thread can lose confidence in where work is happening. That makes the interface feel more complicated than their workflow requires. A cosmetic hide-tabs toggle would not solve that problem if commands or restore behavior can still recreate hidden tabs behind the scenes.

There is also a positioning gap. A terminal-native user evaluating Atelier may not realize that the product can support a multiplexer-first workflow unless the product explains it directly. If README and website copy continue to emphasize tabs and sessions without also describing the single-surface option, the feature may remain discoverable only after frustration instead of shaping adoption up front.

The market shows that optional simplification is expected, but mostly implemented as chrome reduction rather than behavioral guardrails. VS Code, IntelliJ IDEA, Windows Terminal, and other tools already expose focus or distraction-free views. That validates demand for simplified workspaces, but it also leaves room for Atelier to be more explicit and trustworthy for users who want a true single-tab contract.

### Market Data

- A knowledge-worker tab study found **59%** of users later find tabs that should be closed, **55%** feel they cannot let tabs go, and **28%** often struggle to find the tab they need.
- A 2023 CHI browsing-clutter study found **52.8%** of participants usually had **5–10 tabs** open and described a personal limit after which tab clutter becomes stressful or annoying.
- VS Code, IntelliJ IDEA, and Windows Terminal all provide optional focus, zen, or hidden-tab modes, which signals that simplified workspace presentation is already a mainstream expectation.
- Nielsen Norman Group guidance warns that hidden or overflowing tabs reduce discoverability and increase interaction cost when users do not need simultaneous views.

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Single-Tab Guardrail Enforcement | Critical | When enabled, the product prevents creation of a second tab within a session across normal terminal and file-tab entry points instead of relying on visual hiding alone. |
| F2 | Settings-First Preference Control | Critical | Users can enable or disable the guardrail from the existing config modal, with clear language that frames it as a personal preference for simpler single-surface work. |
| F3 | Restore-Safe Single-Tab Behavior | High | Sessions restored while the preference is enabled remain understandable and consistent with the single-tab promise instead of resurrecting hidden extra tabs unexpectedly. |
| F4 | Clear Blocked-Action Feedback | High | If a user attempts an action that would create another tab, the product explains why it was blocked and offers an obvious escape hatch rather than failing silently. |
| F5 | Terminal-Multiplexer-Friendly Positioning | High | The README and website explain why Atelier works well with tmux, herdr, and similar tools, so terminal-native users understand the benefit before they adopt the feature. |
| F6 | Visible Single-Tab State Cue | Medium | The workspace shows a lightweight indication that the guardrail is active so users understand the current behavior without mistaking it for a product bug. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Preference adoption rate | **>= 10%** of monthly active users within 60 days | Track unique users who enable the setting and divide by monthly active users |
| Wrong-tab open rate among enabled users | **-25%** within 30 days | Compare short-bounce tab switches and corrective tab jumps before vs. after enabling |
| Guardrail retention | **>= 65%** of enabled users keep it on after 14 days | Measure the share of users who enable the preference and do not disable it within 14 days |
| Blocked-attempt recovery rate | **>= 70%** of blocked second-tab attempts resolve without disabling the setting | Track blocked attempts followed by continued work in the same session versus immediate disable |
| Satisfaction from enabled users | **>= 4.2 / 5** within one release cycle | Collect lightweight feedback from users who enable the preference |

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

- **Recommended approach:** Ship V1 as a narrow, opt-in single-tab guardrail in Settings, with real enforcement across tab-creation and restore paths.
- **Key trade-offs:** fast learning loop versus broader mode ambition; explicit blocking versus silent rerouting; behavioral truthfulness versus cosmetic simplicity.
- **Risks identified:** hidden-state regressions, confusing restore behavior, ambiguity around file-tab handling, and weak mode signaling if the preference feels like a bug instead of a deliberate choice.
- **Stretch goal (V2+):** evolve this from a guardrail into a broader focus-workspace experience with smarter single-surface navigation and deeper support for terminal-native workflows.

## Out of Scope (V1)

- **Broad single-session or focus-workspace platform** — V1 should validate the narrow guardrail hypothesis before expanding into a larger workflow mode.
- **First-run onboarding or setup wizard** — The product has no current onboarding flow, and adding one would expand scope beyond the core learning goal.
- **Per-project or per-session policy controls** — V1 should stay app-level and personal, not become a policy matrix.
- **Cosmetic hide-tabs toggle without behavioral enforcement** — This would create invisible state and break trust instead of reducing confusion.
- **Advanced multi-tab recovery tools** — If users need rich recovery or parked-tab flows, that is evidence for a later, broader focus-mode initiative.

## Architecture Decision Records

- [ADR-001: Scope V1 as a settings-first single-tab preference with real enforcement](adrs/adr-001.md) — Commits V1 to a truthful, opt-in single-tab guardrail instead of a cosmetic hide-tabs toggle or broader mode platform.

## Open Questions

- Should enabling the preference immediately reconcile existing multi-tab sessions, or only affect future actions?
- Are any current “open new tab” actions safe enough to become explicit single-surface reuse flows, or should V1 block all second-tab creation uniformly?
- What is the clearest user-facing name: “Single-Tab Guardrail,” “Single-Tab Mode,” “Focused Session,” or something else?
- Should later visual polish fully hide the tab row, collapse it, or keep a minimal single-tab indicator?
- How explicit should the README and website be in positioning Atelier for tmux / herdr / terminal-multiplexer workflows?
