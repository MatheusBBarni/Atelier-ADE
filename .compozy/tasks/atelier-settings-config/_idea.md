# Atelier Settings Config

## Overview

Atelier Settings Config adds a file-backed personalization layer for power users who want their Atelier setup to be inspectable, versioned, and portable across machines. It solves a gap between Atelier’s current settings experience and the expectations of modern developer tools: users can change settings in the app today, but they cannot treat those choices as durable personal configuration.

The primary user is the power user who already customizes agent profiles, appearance, shortcuts, and app behavior, and who wants that setup to survive reinstalls, machine switches, and dotfile-driven workflows. The feature matters because Atelier is increasingly positioned as a daily control surface for AI-assisted development. If personalization lives only in a local SQLite file, the app feels less reproducible and less trustworthy than tools that expose inspectable configuration.

V1 should be a strategic but disciplined release. It should ship a single personal-global config scope that covers a curated, supported contract of settings from the existing modal. It should not become a multi-scope configuration platform, policy system, or automation surface.

### Summary / Differentiator

Many AI-heavy developer tools expose files for rules or configuration, but they often split personal setup, project rules, and local state in ways that remain fragmented for users. Atelier can differentiate by making personal configuration portable and inspectable while keeping the experience local-first, deterministic, and tightly aligned with the app’s existing settings surface.

## Problem

Atelier already gives users a visible settings modal for agent profiles, appearance, shortcuts, and app behavior. That is useful, but the resulting setup is trapped inside a local SQLite database. Users cannot diff it, keep it in dotfiles, restore it predictably on a new machine, or reason about it as a durable personal artifact. For power users, that means every meaningful customization remains local state instead of becoming part of their working environment.

This problem compounds as AI-assisted development becomes more routine. A user might rely on custom agent profiles, preferred themes, tuned shortcuts, and default behavior every day, yet still have no reliable way to treat those choices as portable identity. The current solution is insufficient because it supports personalization but not reproducibility. That leaves Atelier behind the expectations set by serious editors and AI-native tools, where inspectable configuration is part of the product, not an afterthought.

The opportunity is real, but so is the scope risk. If Atelier tries to solve personal config, team policy, project-shared settings, machine-local overrides, and AI behavior rules all at once, V1 becomes a configuration platform instead of a focused personalization feature. The highest-value problem is narrower: give users a personal-global config they can trust, version, and move, while keeping the boundary clear about what is and is not portable in V1.

### Market Data

- Stack Overflow Developer Survey 2025 reports that **84%** of developers are using or planning to use AI tools, and **47.1%** use them daily.
- Stack Overflow 2025 reports that **51%** of professional developers use AI tools daily, which raises the bar for daily workflow customization.
- Tools such as **VS Code, Zed, Claude Code, Cursor, Windsurf, and OpenCode** all expose file-backed configuration or rules, which validates inspectable configuration as a mainstream expectation.
- Public research shows mixed trust in AI tooling, which strengthens the case for visible, diffable, reversible settings instead of opaque-only preferences.

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Personal-Global Settings File | Critical | Add one user-owned Atelier config file for supported personal settings so users can inspect, version, back up, and move their setup across machines. |
| F2 | Modal-to-File Round-Trip | Critical | Keep supported settings consistent between the existing settings modal and the config file so users can edit through either surface without drifting into separate systems. |
| F3 | Supported Settings Contract | Critical | Cover the supported subset of settings-modal values across agent profiles, appearance, shortcuts, and general app settings, with explicit exclusions for unsupported or unstable fields. |
| F4 | Validation and Safe Apply | High | Validate the config schema and reject or safely ignore invalid changes with clear user feedback so broken files do not silently corrupt Atelier behavior. |
| F5 | Portable Setup Workflow | High | Give users a straightforward way to locate, review, reload, and recover their personal config so portability feels first-class rather than hidden. |
| F6 | Scope Transparency | High | Make it explicit that V1 is personal-global only and does not apply repo, team, or machine-local override semantics. |

### Integration with Existing Features

| Integration Point | How |
| --- | --- |
| Config modal | The file-backed contract mirrors the existing settings categories instead of creating a separate preferences model. |
| `AppPreferences` | Global app settings remain the source domain for supported appearance, behavior, and shortcut preferences. |
| `SessionShortcut` profiles | Agent profiles become part of the portable personalization story instead of local-only launch metadata. |
| Workspace command service | The existing validation and persistence seam becomes the natural boundary for loading and applying supported config values. |
| App startup flow | Supported config should affect Atelier behavior early enough that restored sessions feel consistent with the user’s saved setup. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Config adoption | >= 25% of weekly active users create, edit, or apply at least one config-backed setting within 45 days | Instrument config create/edit/apply events and compare unique users to weekly active users |
| Repeat config usage | >= 40% of config users load or apply config-backed settings across 2+ launches within 30 days | Track config load/apply events by user or install across distinct launches |
| Config-backed session starts | >= 30% of new sessions start with non-default preferences sourced from config within 60 days | Measure session starts that use supported settings from the config contract |
| Reliability | < 2% of config parse or apply attempts fail within 45 days of release | Track parse/apply failures divided by total config parse/apply attempts |
| Retention lift | >= 12% higher 4-week retention for config users than non-config users | Compare 4-week retention between users who use config-backed settings and those who do not |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Maybe |
| **Frequency** | How often would users encounter this value? | Must do |
| **Differentiation** | Does this set us apart or just match competitors? | Strong |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Strong |

Leverage type: Strategic Bet

## Council Insights

- **Recommended approach:** Ship one personal-global config file for a curated supported contract of existing settings, not a multi-scope configuration hierarchy.
- **Key trade-offs:** completeness vs supported allowlist; portability vs trust boundary; future-proof boundary design vs speculative over-architecture.
- **Risks identified:** users may expect full modal parity too early, editable agent or command settings may widen the blast radius, and pressure may build to add project or team scopes before the personal contract is proven.
- **Stretch goal (V2+):** revisit workflow profiles or additional config scopes only after the personal-global contract shows adoption and stability.

## Out of Scope (V1)

- **Project-shared, repo-scoped, or team-managed config** — This would turn V1 into a precedence and policy system instead of a personal portability feature.
- **Machine-local override layers** — A second scope adds support and merge complexity before the first scope is validated.
- **Workspace, session, tab, or restore-state export** — These are operational state, not personal configuration, and would blur the product boundary.
- **Rules, automation, or agent-policy platform behavior** — This is a different product category than settings portability.
- **Secrets, credentials, or protected tokens in the config file** — Sensitive values should stay outside a shareable and user-editable config artifact.

## Architecture Decision Records

- [ADR-001: Single-Scope Personal Settings Config](adrs/adr-001.md) — Establishes a personal-global config boundary, rejects multi-scope V1, and limits the first release to a curated supported contract.

## Open Questions

- Which exact settings-modal fields qualify for the supported V1 contract, and which should remain excluded until stability is proven?
- Should V1 support user-authored agent command details when those commands may vary by machine or local environment?
- How visible should file management be in the product: reveal-and-reload, guided import/export, or a stronger onboarding flow for dotfile users?
- What evidence threshold should trigger reconsideration of workflow profiles or additional scopes after launch?
