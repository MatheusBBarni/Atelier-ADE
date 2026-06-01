# Light and Dark Theme Expansion

## Overview

Light and Dark Theme Expansion turns Another ADE's existing theme infrastructure into a finished appearance experience. It focuses on users who want the app to match personal visual preference during daily work, especially across long sessions. V1 should stay disciplined: improve the current Appearance UX in Settings and add a small curated set of light and dark presets that feel coherent across shell, editor, and terminal surfaces.

This is a quick-win quality feature with broad reach and high frequency, not a major differentiator. The goal is to make appearance feel intentionally productized rather than merely technically available.

## Problem

Another ADE already has theme plumbing, but the product experience still feels incomplete. The current system exposes theme selection in Settings and persists choices, yet the catalog is thin on the light side and some surfaces still carry light-mode polish risk. For users who care about personal preference, that gap matters every time the app opens: the preference exists, but the experience may not feel complete enough to trust or recommend.

This is a product quality issue more than a missing-feature issue. In developer tools, appearance is not merely cosmetic. Users spend long sessions reading code, terminal output, and split views; when the app does not offer a satisfying set of appearance choices, it feels less mature even if its core workflows are strong. Another ADE risks looking opinionated in the wrong place: it already supports theming internally, but the product surface does not yet communicate that it takes user comfort and preference seriously.

The market reinforces this expectation. Modern productivity and developer-adjacent tools treat appearance controls as baseline product quality. Users do not expect infinite customization, but they do expect a complete, easy-to-find appearance setting with a small number of good options. For Another ADE, the opportunity is not to invent a theming platform. It is to close the gap between existing capability and user-perceived completeness.

### Market Data

- Nielsen Norman Group reports that dark-mode preference is not uniform: users split across dark, light, and mixed behavior, which means one default will not satisfy everyone.
- A 2025 mobile UI study found strong dark-mode preference in evening and low-light contexts, but weaker preference for long-form reading, reinforcing that appearance choice is situational rather than one-size-fits-all.
- Notion, Slack, Microsoft Teams, and Discord all expose appearance controls as standard product behavior, typically through Settings/Preferences and often with a small set of curated choices.
- Broader personalization research from BCG, Salesforce, and Deloitte Digital shows users increasingly expect products to accommodate individual preference, even when the personalization itself is simple.

## Integration with Existing Features

| Integration Point | How |
| --- | --- |
| `ConfigModalAppearanceAndShortcutsSection` | Keep theme selection in the existing Appearance settings surface rather than introducing a new navigation path. |
| `AppTheme` catalog | Extend the existing preset catalog with a small curated set of additional themes, especially stronger light-theme coverage. |
| `AppPreferences.themeID` and persistence layer | Preserve current theme persistence and validation behavior so new presets remain safe across restarts and migrations. |
| App shell and environment color scheme | Ensure selected presets continue to drive shell chrome and coarse light/dark behavior consistently. |
| Terminal and editor surfaces | Validate that terminal appearance, editor presentation, overlays, and surrounding UI remain visually coherent when users switch themes. |

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Refined Appearance Settings | Critical | Improve the existing Appearance settings flow so theme selection is clearer, easier to trust, and immediately understandable as the home for visual preference. |
| F2 | Curated Theme Preset Expansion | Critical | Add a small, opinionated set of additional light and dark presets, with special attention to improving light-theme coverage rather than maximizing theme count. |
| F3 | Cross-Surface Appearance Consistency | High | Ensure the selected preset applies coherently across app chrome, overlays, editor presentation, and terminal appearance so switching themes feels complete rather than partial. |
| F4 | Safe Persistence and Fallbacks | High | Preserve stable theme IDs, existing persistence, and safe fallback behavior so added presets do not introduce broken selections or migration regressions. |
| F5 | Theme Confidence Signals | High | Add lightweight cues inside the settings experience that help users choose confidently, such as clearer labeling, grouping, or concise guidance around curated options. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Theme adoption rate | >= 25% of monthly active users select a non-default theme within 90 days | Track unique users who save a theme change event and divide by monthly active users |
| Appearance settings engagement | >= 35% of monthly active users open the Appearance section within 90 days | Instrument Appearance settings view events and compare with monthly active users |
| Light-theme adoption | >= 10% of monthly active users select a light theme within 90 days | Track saved theme selections where the chosen preset is light-themed |
| Appearance satisfaction | >= 4.2/5 average on a post-release appearance satisfaction prompt within one release cycle | Collect in-app survey responses from users who visit Appearance settings |
| Appearance-related complaints | Reduce theme/readability complaints by >= 50% within 2 releases | Compare tagged feedback, issues, or support requests before and after release |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Strong |
| **Frequency** | How often would users encounter this value? | Must do |
| **Differentiation** | Does this set us apart or just match competitors? | Pass |
| **Defensibility** | Is this easy to copy or does it compound over time? | Pass |
| **Feasibility** | Can we actually build this? | Must do |

Leverage type: Quick Win

## Council Insights

- **Recommended approach:** Productize the existing theme system as a curated appearance experience: improve the current settings UX, add a very small number of additional presets, and make the result feel complete across surfaces.
- **Key trade-offs:** more choice vs lower QA burden; market parity vs strict V1 scope; curated presets vs drifting into a theming platform.
- **Risks identified:** additional presets can expose light-mode inconsistencies, discoverability may matter more than theme count, and requests for System/Auto or custom themes can expand scope quickly.
- **Stretch goal (V2+):** add System/Auto behavior or a richer adaptive appearance model once the curated preset experience proves useful.

## Out of Scope (V1)

- **System/Auto mode** — Common in the market, but it adds state and QA complexity that can wait until the curated preset release proves its value.
- **User-authored custom themes** — This would turn a bounded preset feature into a broader theming platform too early.
- **Per-component appearance overrides** — Different themes for editor, terminal, or shell would complicate the model before the base experience is complete.
- **Broad visual redesign outside theme work** — The goal is to improve appearance choice and consistency, not rework the whole UI.
- **Large theme catalog or marketplace-style expansion** — V1 should ship a short curated set, not maximize quantity.

## Architecture Decision Records

- [ADR-001: Scope V1 as Curated Appearance Presets and Polish](adrs/adr-001.md) — Keeps V1 focused on polishing the existing Appearance flow and adding a small preset expansion instead of building a larger theming system.

## Open Questions

- How many additional presets are required for launch to feel complete without turning the catalog into clutter?
- Should V1 include any preview or recommendation treatment inside Settings, or only clearer grouping and labels?
- If System/Auto proves technically cheap during planning, should it remain out of scope or be reconsidered as a narrow compatibility addition?
- What is the best lightweight way to measure appearance satisfaction without adding too much product overhead?
