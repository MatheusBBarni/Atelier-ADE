# Config Modal Customization

## Overview

Config Modal Customization adds a dedicated settings surface for power users to personalize Another ADE without leaving its session-first workflow. It solves a gap between the product's local-first, trustworthy positioning and its current fixed behavior: users cannot change core shortcuts, pick non-Nord or light themes, edit default Claude/Codex commands, or add additional agent entries such as OpenCode.

This matters most for solo AI-heavy developers who use multiple agent workflows every day and expect their environment to fit how they work. Today, Another ADE already organizes projects, sessions, and tabs, but it does not let users shape the environment around those workflows. That makes the product feel less adaptable than the category leaders even when its core session model is stronger.

V1 should be a strategic but disciplined release. It should ship the full original personalization bundle the user requested, but it should still present agent management as the organizing center of the experience. The goal is not to become a generic preferences app. The goal is to make Another ADE feel personally fitted to the user's daily agent workflow.

### Summary / Differentiator

Most AI coding tools compete on model access, orchestration breadth, or editor integration. Another ADE can differentiate by making personalization native to a session-first, local-first Mac workflow: agent defaults, additional agent commands, themes, and shortcuts live in one coherent control surface focused on predictable local execution rather than opaque automation.

## Problem

Power users do not use one static agent setup. A typical workflow might use Claude for review, Codex for implementation, and another tool such as OpenCode for local experimentation or lower-cost tasks. In Another ADE today, those preferences cannot be encoded cleanly in the product. Claude and Codex exist only as built-in launch profiles, theming is fixed to Nord in dark mode, and core keyboard shortcuts are hard-coded. Users who want different defaults or additional agents must work around the product instead of through it.

That is more than a polish issue. Another ADE is positioned as the place where agent work begins, resumes, and stays trustworthy. If users cannot control which command launches, how the UI looks during long sessions, or how quickly they can trigger common actions, the app feels less like a daily control center and more like a constrained wrapper around the terminal. The friction is small on any one action, but persistent across every session.

The market supports the need for this feature. AI-assisted development is mainstream, and agent usage is rising quickly, but users still prefer visible, supervised control over opaque automation. Products such as GitHub Copilot, Cursor, Windsurf, Claude Code, and OpenCode all reinforce that agent choice and workflow fit matter. At the same time, mature developer tools have already trained users to expect editable shortcuts, theme choice, and coherent settings organization. Without a serious personalization story, Another ADE risks feeling opinionated in the wrong places.

### Market Data

- Stack Overflow 2025 reports that **84%** of developers are using or planning to use AI tools, and **51%** of professional developers use them daily.
- Stack Overflow Pulse 2026 reports that **59%** of developers use AI agents at work, while **63%** rarely or never let agents run fully on autopilot, which reinforces demand for explicit control.
- Competitors including **GitHub Copilot, Cursor, Windsurf, Claude Code, and OpenCode** all highlight model or agent choice as a product capability, validating the category direction.
- VS Code documentation and Microsoft settings guidance show that **editable shortcuts, theme choice, grouped settings, and immediate feedback** are baseline expectations in serious developer tools.

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Dedicated Config Modal | Critical | Add a clear, first-class configuration surface with grouped sections for agents, commands, appearance, and shortcuts so personalization has one obvious home. |
| F2 | Agent and Command Management | Critical | Let users edit built-in Claude and Codex defaults, add supported agent entries such as OpenCode, and manage the default command and arguments used to launch each agent. |
| F3 | Theme Expansion and Light Themes | High | Offer multiple themes, including high-quality light themes, so users can adapt the app to long-running daily workflows and different environments. |
| F4 | Core Shortcut Customization | High | Let users change the most important workflow shortcuts, including primary session and tab actions, with visible defaults and a clear reset path. |
| F5 | Safe Personalization Feedback | High | Show which entries are built-in versus custom, explain when changes affect launch behavior, and make risky command changes feel explicit rather than hidden. |
| F6 | Persistent Session Integration | High | Make configured agents, themes, commands, and shortcuts persist across relaunches and show up naturally in session creation and day-to-day use. |

### Integration with Existing Features

| Integration Point | How |
| --- | --- |
| `SessionShortcut` launch profiles | Extend the existing shortcut model from lightweight built-ins into editable agent/default-command entries. |
| Session creation flow | Surface configured defaults directly when users start or resume work so settings affect real workflows immediately. |
| App shell and modal patterns | Reuse the existing native modal/sheet patterns to introduce a dedicated config entry point. |
| Theme and terminal chrome | Apply selected themes consistently across app chrome and terminal presentation so the UI feels coherent. |
| Menu commands and primary actions | Connect shortcut customization to the app's most important existing commands rather than treating it as a separate power-user island. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Personalization adoption | >= 35% of active weekly users change at least one setting within 30 days of release | Instrument setting-change events and compare unique users with weekly active users |
| Agent customization adoption | >= 20% of active weekly users add or edit an agent profile or default command within 30 days | Track create/edit events for built-in and custom agent entries |
| Config-driven session starts | >= 30% of new sessions launch with a saved/default agent profile within 45 days | Measure session starts that use configured defaults or saved agent entries |
| Theme adoption | >= 15% of active weekly users switch to a non-default theme within 30 days | Track theme selection events and weekly active users |
| Shortcut customization adoption | >= 10% of active weekly users customize at least one core shortcut within 45 days | Track shortcut-change events against weekly active users |
| Retention lift from personalization | >= 10% higher 4-week retention for users who customize settings vs users who do not | Compare cohort retention between customizers and non-customizers |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Strong |
| **Frequency** | How often would users encounter this value? | Must do |
| **Differentiation** | Does this set us apart or just match competitors? | Strong |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Maybe |

Leverage type: Strategic Bet

## Council Insights

- **Recommended approach:** Keep the full config-modal idea, but structure it around agent management and default-command control so the feature feels like workflow personalization instead of a generic preferences page.
- **Key trade-offs:** completeness vs scope discipline; open customization vs trust and validation; familiar settings breadth vs preserving the product's session-first wedge.
- **Risks identified:** building a broad settings platform before proving the highest-value behaviors, expanding the trust boundary through editable commands, and underdelivering on shortcut or theme expectations if the release feels uneven.
- **Stretch goal (V2+):** evolve personalization into named workflow profiles that bundle agent choice, command defaults, permissions, and appearance for different work modes.

## Out of Scope (V1)

- **Per-project or per-task routing policies** — This would turn personalization into a deeper orchestration system before the base configuration workflow is proven.
- **Plugin marketplace or open agent discovery ecosystem** — Too much ecosystem and governance scope for the first release of agent expansion.
- **Cross-device sync or cloud backup of preferences** — Expands the local-first boundary and adds infrastructure before usage is validated.
- **Exhaustive remapping of every internal shortcut** — V1 should focus on the primary workflow commands that matter most in daily use.

## Architecture Decision Records

- [ADR-001: Agent-First Scope for Config Modal Personalization](adrs/adr-001.md) — Establishes agent-first scope, introduces a narrow shared preferences layer, and avoids turning V1 into a broad settings platform.

## Open Questions

- Should the first release support only a curated set of new agents such as OpenCode, or also allow fully arbitrary user-defined agent entries from day one?
- How much theme breadth is required for launch to feel complete: a small set of excellent dark/light themes, or a broader visual catalog?
- Should shortcut customization stay global in V1, or is there product value in project-specific behavior later?
- What level of validation and warning copy is necessary to make editable default commands feel powerful without feeling risky?
