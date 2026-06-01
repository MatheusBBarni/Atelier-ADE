---
status: pending
title: "Add the GitHub repo star CTA as progressive enhancement"
type: frontend
complexity: medium
dependencies:
  - task_03
---

# Task 04: Add the GitHub repo star CTA as progressive enhancement

## Overview
This task implements the only planned runtime enhancement on the MVP landing page: a GitHub repo button that still works without JavaScript and optionally upgrades itself with live star count. It preserves the repo-first evaluation path without introducing backend infrastructure, analytics, or secret management.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST render a primary repo CTA that works as a plain GitHub link before JavaScript runs.
2. MUST fetch public GitHub repository metadata client-side to enhance the button with star count.
3. MUST treat the GitHub fetch as optional enhancement and preserve navigation on network, rate-limit, or response failures.
4. MUST avoid tokens, backend services, analytics coupling, or retry-heavy runtime behavior.
5. SHOULD source CTA text and repo URL from the centralized site content module rather than internal Swift metadata.
</requirements>

## Subtasks
- [ ] 4.1 Create the reusable repo CTA component boundary for the landing page.
- [ ] 4.2 Render stable fallback CTA markup that points directly to the GitHub repository.
- [ ] 4.3 Add client-side GitHub metadata fetch to update the CTA label with live star count.
- [ ] 4.4 Handle rate limits, invalid responses, and network failures by falling back silently.
- [ ] 4.5 Keep the enhancement small and isolated from unrelated page logic.

## Implementation Details
Follow TechSpec “Core Interfaces”, “API Endpoints”, “Integration Points”, and step 4 of “Development Sequencing”. This task owns the GitHub metadata enhancement only; it should not broaden into analytics or server-side data plumbing.

### Relevant Files
- `web/src/components/RepoStarCTA.astro` — primary component boundary for CTA rendering and enhancement.
- `web/src/pages/index.astro` — integration point where the primary CTA is rendered.
- `web/src/siteContent.ts` — canonical source for repo URL, button label, and public naming.
- `.compozy/tasks/project-landing-page/_techspec.md` — defines the repo CTA state contract, GitHub endpoint, and failure handling.
- `README.md` — public naming and repo-facing language should stay aligned with the CTA.

### Dependent Files
- `web/package.json` — build/test tooling must support any new helper or component test setup.
- `web/astro.config.mjs` — final site path must not break CTA navigation under GitHub Pages.
- `.github/workflows/deploy-pages.yml` — later validation must check the no-JS fallback and build behavior.
- `Package.swift` — internal naming must not leak into CTA labels.
- `docs/images/app-image.png` — adjacent page asset, useful when validating full-page rendering alongside CTA behavior.

### Related ADRs
- [ADR-002: Trust-First Repo-Oriented Landing Page PRD Scope](../adrs/adr-002.md) — Keeps the repo CTA primary and secondary paths secondary.
- [ADR-003: Implement the Landing Page as an Astro Site in /web with GitHub Pages Deployment](../adrs/adr-003.md) — Limits runtime behavior to a minimal Astro site.
- [ADR-004: Use a Client-Side GitHub Star CTA Instead of Site Analytics or Build-Time GitHub Metadata](../adrs/adr-004.md) — Directly governs the client-side fetch and fallback strategy.

## Deliverables
- Reusable primary repo CTA component with stable fallback markup.
- Client-side GitHub star-count enhancement with graceful failure behavior.
- Page integration that preserves repo-first CTA priority.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for fallback-first CTA behavior and GitHub metadata enhancement **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Valid GitHub metadata response updates the CTA label with the expected star count.
  - [ ] Invalid or incomplete GitHub metadata response preserves fallback CTA text.
  - [ ] Network or rate-limit failures do not remove the CTA link or block navigation.
- Integration tests:
  - [ ] With JavaScript disabled, the primary CTA still links directly to `https://github.com/MatheusBBarni/Atelier-ADE`.
  - [ ] With a mocked successful GitHub response, the rendered CTA displays the updated star count.
  - [ ] With a mocked failing GitHub response, the page still builds and the CTA remains clickable.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The primary CTA always works as a GitHub link and upgrades itself only when public metadata is available.
- The landing page gains live repo-proof behavior without adding backend or analytics infrastructure.
