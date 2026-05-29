# Native Mac ADE

## Overview

Native Mac ADE is a local-first agentic development environment for solo AI-heavy developers who live in terminal-driven workflows across multiple repositories. It turns project and session management into the primary interface: open a project once, keep it visible in a persistent sidebar, and resume work through project-scoped sessions and tabs without rebuilding context.

V1 should be a strategic but disciplined release. It should be complete enough to replace daily agent-driven terminal work, but intentionally narrower than Orca-style orchestration. The goal is not to become another broad AI IDE. The goal is to become the most trustworthy native Mac place to start, supervise, and resume terminal-agent work.

### Summary / Differentiator

The differentiator is not model access or orchestration breadth. It is native Mac quality, correct project context by default, durable restore, and session-first trust. Compared with Orca, V1 stays local, calmer, and more focused: fewer top-level concepts, less operational sprawl, and a stronger day-one story for solo developers who want a reliable control center for agent sessions.

## Problem

Solo developers who use CLI agents move through many short but important loops: open a repo, start or resume an agent session, inspect output, open another tab, switch projects, then come back later and remember what was running. Today that flow is usually spread across an IDE sidebar, terminal tabs, Finder windows, and informal notes. The result is avoidable context switching, wrong-directory mistakes, weak session continuity, and too much manual reconstruction after interruptions or relaunches.

The problem is not only launch friction. Serious agent work also has a trust problem. Developers need to know which project is active, which session they are in, what happened most recently, and whether they can safely resume without guessing. If the app only organizes terminals but does not make sessions feel inspectable and resumable, it risks becoming a polished launcher rather than the place where real work begins.

The market signal is strong. AI-assisted development is mainstream, but trust and workflow fragmentation remain unresolved. The product opportunity is to provide a native Mac control center that reduces tool switching while making local agent sessions easier to supervise and recover.

### Market Data

- JetBrains AI Pulse 2026 reports that **90%** of developers use at least one AI tool at work, and **74%** use specialized AI development tools.
- Chainguard's 2026 Engineering Reality Report says **88%** of engineers lose productivity from switching between tools, and **44%** report significant focus loss.
- Stack Overflow Pulse 2026 reports **59%** of developers use agents at work, while **63%** rarely or never let agents run fully on autopilot, reinforcing the need for better supervision and trust.
- Orca, Warp, Cursor, and similar products validate the category, but Orca's broader worktree/orchestration model leaves room for a simpler native session-first alternative.

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Persistent Project Sidebar | Critical | Opening a project adds it to a durable sidebar. Selecting a project restores it as the active workspace and makes it the default context for new work. |
| F2 | Project-Scoped Sessions | Critical | Each project owns sessions with default timestamp names (`MM-DD HH:mm`), rename support, recent activity visibility, and fast switching between current and prior sessions. |
| F3 | Context-Correct Terminal Tabs | Critical | Creating a new tab opens a terminal in the currently selected project's folder and attaches it to the active project/session context by default. |
| F4 | Restore and Resume | High | On relaunch, the app restores opened projects, selected context, sessions, and prior tab/session state so users can continue work without manual reconstruction. |
| F5 | Session Trust Layer | High | Each session shows lightweight state cues such as active/idle/running status, last activity, visible recent history, and simple recovery or checkpoint affordances. |
| F6 | Local-First Data Boundaries | High | Project and session memory stays local, sensitive information stays tightly controlled, and the product avoids hidden background behavior that would weaken user trust. |
| F7 | Agent-Aware Session Templates | Medium | The app may offer lightweight session templates or launch commands for common CLI agents, but only inside the session model rather than as a separate orchestration layer. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Workflow replacement | >= 70% of pilot users' agent-driven sessions start in the ADE within 14 days | Track session starts during pilot usage and compare against self-reported baseline workflow |
| Weekly session engagement | >= 20 project sessions per active user per week | Count session starts and resumptions per active user over rolling 7-day windows |
| Restore reliability | >= 99% successful restoration of saved projects and sessions after relaunch | Instrument relaunch events and compare expected vs restored sidebar/session state |
| Time to ready terminal | <= 10 seconds median from app open to interactive terminal in the selected project | Measure launch/open-project to ready-terminal timestamps during pilot usage |
| Trust and polish rating | >= 80% of pilot users rate reliability/native feel 4/5 or higher | Run structured pilot surveys after 2 weeks of use |

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

- **Recommended approach:** Build a local-first, session-first native Mac control center for terminal agents around the project -> session -> tab spine.
- **Key trade-offs:** Breadth vs operator control; learning speed vs explicit security/provenance controls; agent-aware affordances vs strict boundary purity.
- **Risks identified:** Underbuilding supervision and recovery, drifting into Orca-style orchestration scope, weakening trust through unclear state or hidden behavior, and shipping something perceived as only a terminal wrapper.
- **Stretch goal (V2+):** Evolve sessions into a deeper trusted control plane with richer timelines, checkpoints, recovery, and optional advanced workflow surfaces after workflow replacement is proven.

## Out of Scope (V1)

- **Multi-agent orchestration and fleet-style worktree management** — Too much state, complexity, and positioning overlap with Orca before the core workflow is proven.
- **Remote execution, SSH-first flows, and cloud sync** — Expands failure modes and trust boundaries before the local workflow is solid.
- **Embedded editor or broad IDE features** — Pulls the product toward a crowded category and weakens the session-first wedge.
- **Hidden background agent execution** — Reduces user trust and makes provenance and safety harder to explain.
- **Plugin marketplace or deep automation rules** — Premature before the session model and daily-use behavior are stable.

## Architecture Decision Records

- [ADR-001: Session-First Native macOS ADE Scope for V1](adrs/adr-001.md) — Establishes a local-first project -> session -> tab model and rejects Orca-style breadth for V1.

## Open Questions

- What is the minimum checkpoint or recovery interaction users need before they trust the app for multi-step agent work?
- Should V1 ship with agent-specific session templates for one or more common CLI agents, or stay fully generic at launch?
- How much local session history should be retained by default, and what user controls should users have over retention and privacy?
