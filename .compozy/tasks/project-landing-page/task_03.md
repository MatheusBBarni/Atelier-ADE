---
status: completed
title: "Implement the trust-first landing page content and layout"
type: frontend
complexity: medium
dependencies:
  - task_01
  - task_02
---

# Task 03: Implement the trust-first landing page content and layout

## Overview
This task builds the actual MVP landing page experience: the trust-first hero, screenshot-led proof, concrete capability summary, and secondary evaluation links. It turns the scaffold into the single-route public surface defined by the PRD while keeping content centralized and easy to align with the repo.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST implement the MVP as a single landing-page route under `web/src/pages/index.astro`.
2. MUST centralize public copy, canonical name, CTA URLs, and capability data in `web/src/siteContent.ts`.
3. MUST render the trust-first hero, screenshot proof, capability summary, and secondary docs/quickstart links defined by the PRD.
4. MUST keep repo-first CTA placement available for task 04 without embedding GitHub star-fetch logic here.
5. SHOULD derive public wording from current truthful repo sources such as `README.md` and `scripts/run.sh`.
</requirements>

## Subtasks
- [x] 3.1 Define the centralized public content model for hero, capabilities, trust notes, and link targets.
- [x] 3.2 Implement the single-page Astro route structure for the MVP sections.
- [x] 3.3 Render the screenshot-led proof section using the normalized assets from task 02.
- [x] 3.4 Add secondary docs and quickstart paths without displacing the repo-first CTA hierarchy.
- [x] 3.5 Keep public naming, maturity, and capability language aligned with current repo reality.

## Implementation Details
Follow TechSpec “System Architecture”, “Implementation Design”, and step 3 of “Development Sequencing”. This task owns page markup and centralized content, while task 04 owns the dynamic repo-CTA enhancement.

### Relevant Files
- `web/src/pages/index.astro` — primary implementation surface for page structure and sections.
- `web/src/siteContent.ts` — single source of truth for landing-page copy and URLs.
- `README.md` — current public wording for capabilities, status, and product framing.
- `scripts/run.sh` — source of truthful quickstart-related wording and app naming.
- `docs/images/app-image.png` — original proof asset source that informs the screenshot-led section.

### Dependent Files
- `web/src/components/RepoStarCTA.astro` — will be integrated into the page as the primary CTA component.
- `web/src/assets/` — must already contain the normalized screenshot and site visuals.
- `.github/workflows/deploy-pages.yml` — later deployment checks depend on a valid rendered page.
- `README.md` — later public-entry alignment depends on final copy and CTA targets chosen here.
- `Package.swift` — internal naming must remain hidden from public-facing copy.

### Related ADRs
- [ADR-001: Docs-First Trailhead Landing Page Scope for V1](../adrs/adr-001.md) — Preserves the small, honest landing-page scope.
- [ADR-002: Trust-First Repo-Oriented Landing Page PRD Scope](../adrs/adr-002.md) — Governs trust-first messaging, screenshot-led proof, and repo-first CTA hierarchy.
- [ADR-003: Implement the Landing Page as an Astro Site in /web with GitHub Pages Deployment](../adrs/adr-003.md) — Fixes the Astro single-route surface in `/web`.
- [ADR-004: Use a Client-Side GitHub Star CTA Instead of Site Analytics or Build-Time GitHub Metadata](../adrs/adr-004.md) — Requires a stable primary CTA seam for later progressive enhancement.

## Deliverables
- Finalized `web/src/siteContent.ts` with centralized public landing-page content.
- MVP landing-page route with trust-first hero, proof, capability, and secondary-link sections.
- Integrated page structure that leaves a clean insertion point for the repo-star CTA.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for route rendering, content hierarchy, and fallback navigation **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Validate the site-content module exports the canonical product name, repo URL, docs URL, and quickstart URL expected by the page.
  - [x] Validate capability items and trust-note data renderable by the route include all required MVP sections.
  - [x] Validate any helper used for section ordering or CTA grouping preserves repo-first priority.
- Integration tests:
  - [x] Built landing page renders hero, screenshot/proof, capability summary, and secondary docs/quickstart links.
  - [x] Built landing page exposes a primary repo CTA placeholder or integration point before JavaScript enhancement.
  - [x] Public copy on the page uses `Atelier` and does not expose internal `NativeMacADE` package naming.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The single Astro route renders the full MVP landing-page content defined by the PRD.
- Public copy and link targets are centralized enough to support later README and deployment alignment.
