# Project Landing Page

## Overview

Create a minimal, docs-first landing page for Atelier that helps developers understand the product quickly, see what is real today, and move into evaluation with confidence. The page should explain why Atelier exists, show the core workflow and product surfaces, and route qualified visitors into docs and quickstart without pretending the project is more polished than it is.

This idea is for developers evaluating whether Atelier fits their daily workflow. Its value is not just presentation. It reduces discovery friction, sharpens product positioning, and gives the project a public surface that matches its actual strengths: native macOS feel, local-first transparency, and faster workflow through clearer project and session context.

V1 should stay deliberately small. It should behave like a trailhead into the product, not a full marketing site.

### Summary / Differentiator

Atelier should not position itself as just another AI coding tool. Its differentiator is a native, local-first, transparent agentic development workflow for macOS that helps developers move faster without hiding context behind a browser shell, mystery sync layer, or overloaded IDE plugin model.

## Problem

Atelier already has a stronger product story than its current public surface communicates. The repository and existing product artifacts show a native macOS app with persistent projects, project-scoped sessions, restore and resume behavior, agent-oriented workflows, and a clear “speed with confidence” thesis. But a new visitor mostly encounters a README. That forces them to infer too much before they can decide whether the project is relevant, credible, or worth the setup effort.

This gap matters because developer-tool evaluation is crowded and skeptical. The market is full of tools like Cursor, Warp, Windsurf, Zed, and Claude Code, all competing for attention with fast, polished product narratives. If Atelier remains README-first without a clearer orientation layer, qualified developers may misclassify it as unfinished, redundant, or too obscure to try, even when its actual workflow model is meaningfully different.

### Market Data

Developer adoption of AI tooling is already mainstream. JetBrains reported that **85%** of developers regularly use AI for coding and **62%** rely on at least one coding assistant, agent, or AI-enhanced editor. At the same time, trust remains fragile: Sonar reported that **96%** of developers do not fully trust AI-generated code. That means Atelier cannot win with vague “AI-powered” language alone. It needs a surface that makes its workflow, control model, and maturity legible.

Documentation and onboarding quality also directly affect evaluation. State of Docs 2025 reported that **90%+** of buyers say documentation matters in purchase decisions. A 2025 open-source developer survey found that **73.2%** of developers want a quickstart or tutorial in minutes, while **34.7%** abandon tools when setup is difficult. For Atelier, this means a landing page cannot be pure branding. It must work together with a trustworthy quickstart/install path so the page does not amplify friction downstream.

## Integration with Existing Features

| Integration Point | How |
| --- | --- |
| `README.md` | Serves as the immediate documentation and quickstart destination until a fuller docs site exists |
| `docs/images/app-image.png` | Provides the first public proof asset for the landing page |
| `scripts/run.sh` | Anchors the current quickstart/install path that the page must represent honestly |
| `.github/workflows/release-build.yml` | Supports future evolution toward a clearer release/download path |
| `.compozy/tasks/native-mac-ade/_prd.md` | Supplies the strongest existing product framing: speed with confidence, local-first, native workflow |

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Outcome-First Hero | Critical | Present Atelier in one clear statement for developers: what it is, who it is for, and why it is different from browser-shell or plugin-based agent workflows. |
| F2 | Product Proof Block | Critical | Show an immediate proof asset, such as the current app screenshot or short demo media, so the page feels concrete rather than conceptual. |
| F3 | Workflow and Feature Highlights | Critical | Explain the main workflow with concrete product facts: persistent projects, project-scoped sessions, native terminal tabs, restore/resume, and transparent local-first behavior. |
| F4 | Docs-First CTA with Secondary Quickstart | High | Make documentation the primary path while keeping a visible secondary quickstart/install route for high-intent visitors who want to try the product immediately. |
| F5 | Trust and Legibility Layer | High | Align product naming, maturity/status language, source links, license visibility, and quickstart messaging so the public surface does not ask for more trust than the project has earned. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Docs click-through rate | `>= 35%` of landing-page visitors | Track unique visitors who click the primary docs CTA |
| Install-start rate | `>= 8%` of unique landing-page visitors | Track visitors who begin the quickstart/install flow from the landing page |
| Quickstart completion rate | `>= 30%` of landing-page-driven install starts | Measure how many install starts reach the last documented setup step |
| Message clarity rate | `>= 80%` | In usability interviews or 5-second tests, users can correctly explain Atelier’s value after a brief scan |
| Feature-section reach | `>= 60%` of visitors | Track scroll depth to the main workflow/features section |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Strong |
| **Frequency** | How often would users encounter this value? | Maybe |
| **Differentiation** | Does this set us apart or just match competitors? | Strong |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Must do |

Leverage type: Quick Win

## Council Insights

- **Recommended approach:** Build a minimal, static, docs-first landing page now, but pair it with a more trustworthy quickstart/install path so the public story and first-run experience stay aligned.
- **Key trade-offs:**
  - A landing page improves discovery now, but can amplify onboarding friction if it overpromises.
  - A visible install path helps activation, but too much install emphasis too early can weaken trust.
  - A generic marketing page is easy to imitate, while a trailhead-style page better matches Atelier’s current maturity and product shape.
- **Risks identified:**
  - Brand drift across `Atelier`, `Another ADE`, and `NativeMacADE` may confuse visitors.
  - Speed claims can backfire if they sound benchmark-like instead of workflow-specific.
  - A thin trust layer around install, licensing, or maturity may lower confidence right when users decide whether to try the tool.
  - If metrics stop at clicks, the team may misdiagnose onboarding problems as messaging problems.
- **Stretch goal (V2+):** Expand the page into an interactive proof hub with richer demo media, a stronger release/download path, and deeper workflow proof once trust and onboarding assets are mature.

## Out of Scope (V1)

- **Benchmark-heavy performance claims** — V1 should not publish “faster than X” messaging without public proof and repeatable evidence.
- **Gated email capture, waitlists, or lead forms** — These add compliance and trust overhead while conflicting with the project’s open, developer-first posture.
- **Enterprise trust theater** — Dedicated security, governance, or team-scale pages are premature for the project’s current maturity.
- **Large competitor comparison grids** — They create claim burden, distract from the product’s own story, and invite noise before positioning is settled.
- **Binary-download-first funnel** — V1 should not center a download promise until the canonical release/install story is clearer and more trustworthy.

## Architecture Decision Records

- [ADR-001: Docs-First Trailhead Landing Page Scope for V1](adrs/adr-001.md) — Establishes a minimal, honest, docs-first landing page instead of an install-first marketing site.

## Open Questions

- What should be the single canonical public product name across repo, landing page, and docs?
- Should the first secondary CTA point to the current README quickstart, a dedicated getting-started page, or GitHub Releases once that path is ready?
- Is the current screenshot enough as public proof, or does the page need a short workflow demo to make the differentiator legible?
- Which downstream activation event should be treated as the true success threshold: install start, quickstart completion, or first successful session launch?
