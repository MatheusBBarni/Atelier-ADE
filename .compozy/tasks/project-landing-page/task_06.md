---
status: pending
title: "Align README and public entry points with the new landing page"
type: docs
complexity: medium
dependencies:
  - task_03
  - task_05
---

# Task 06: Align README and public entry points with the new landing page

## Overview
This task aligns the repository’s public entry points with the new landing page so visitors do not encounter conflicting names, links, or trust signals. It keeps the repo-first evaluation flow coherent across the landing page, README, quickstart references, and release-facing surfaces.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST align `README.md` and any repo-facing public links with the landing page’s canonical public name and CTA hierarchy.
2. MUST preserve a repo-first evaluation flow while keeping docs and quickstart visible as secondary paths.
3. MUST keep status, maturity, screenshot, and license-related wording honest and consistent with the landing page.
4. MUST avoid exposing internal `NativeMacADE` package naming in public-facing entry points where `Atelier` is intended.
5. SHOULD align release-facing references and public entry points without triggering a repo-wide rename or documentation rewrite.
</requirements>

## Subtasks
- [ ] 6.1 Audit repo-facing public entry points for name, link, and status mismatches.
- [ ] 6.2 Update `README.md` so it aligns with the landing page’s canonical name, proof story, and CTA hierarchy.
- [ ] 6.3 Keep quickstart and repo navigation truthful by matching current runnable surfaces such as `scripts/run.sh`.
- [ ] 6.4 Align any public release or screenshot references that would otherwise contradict the new landing page.
- [ ] 6.5 Confirm that public entry points remain small, trustworthy, and consistent after the update.

## Implementation Details
Use TechSpec “Impact Analysis”, step 7 of “Development Sequencing”, and “Known Risks” around naming and trust drift. This task should align public surfaces, not broaden into internal package renaming or release-process redesign.

### Relevant Files
- `README.md` — main repo-facing surface that must align with the new landing page.
- `.compozy/tasks/project-landing-page/_techspec.md` — defines the expected public-entry alignment work.
- `.compozy/tasks/project-landing-page/_prd.md` — defines trust-first, screenshot-led, repo-first public behavior.
- `.compozy/tasks/project-landing-page/_idea.md` — documents the current public evaluation flow and supporting assets.
- `scripts/run.sh` — real quickstart/run surface that public instructions must continue to represent accurately.
- `.github/workflows/release-build.yml` — release artifact naming already exposes `Atelier` publicly and should stay aligned.

### Dependent Files
- `web/src/pages/index.astro` — source of the new public landing-page story that README content must match.
- `web/src/siteContent.ts` — canonical source for public name, CTA URLs, and status wording.
- `web/src/components/RepoStarCTA.astro` — defines the final repo-first CTA destination and wording.
- `docs/images/app-image.png` — current screenshot proof asset still referenced by README.
- `Package.swift` — internal naming remains different and should not leak into public copy.

### Related ADRs
- [ADR-001: Docs-First Trailhead Landing Page Scope for V1](../adrs/adr-001.md) — Reinforces honest, minimal public storytelling.
- [ADR-002: Trust-First Repo-Oriented Landing Page PRD Scope](../adrs/adr-002.md) — Sets repo-first CTA priority and screenshot-led proof.
- [ADR-003: Implement the Landing Page as an Astro Site in /web with GitHub Pages Deployment](../adrs/adr-003.md) — Keeps the public site isolated so README alignment must point into it explicitly.
- [ADR-004: Use a Client-Side GitHub Star CTA Instead of Site Analytics or Build-Time GitHub Metadata](../adrs/adr-004.md) — Keeps GitHub-native proof central to the public entry flow.

## Deliverables
- Updated `README.md` and any necessary public entry references aligned with the landing page.
- Consistent canonical public naming and CTA hierarchy across repo-facing surfaces.
- Preserved truthful quickstart/run messaging and screenshot usage.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for public-link and public-copy alignment **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Validate any shared public-link or metadata helper returns the same repo/docs/quickstart URLs used by the landing page.
  - [ ] Validate any copy-source helper resolves the canonical public product name as `Atelier`.
  - [ ] Validate any README-generation or link-map helper preserves repo-first CTA priority.
- Integration tests:
  - [ ] `README.md` links to the landing page, repository, docs, and quickstart targets all resolve to the intended public destinations.
  - [ ] `README.md` public copy uses `Atelier` and does not expose internal `NativeMacADE` naming in the landing-page-aligned sections.
  - [ ] README quickstart/build instructions remain consistent with the commands and naming in `scripts/run.sh`.
  - [ ] Public screenshot and release references remain valid after README alignment changes.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Repo-facing public entry points tell the same story as the landing page and preserve the repo-first evaluation flow.
- Visitors can move between the landing page and README without seeing conflicting names, links, or trust signals.
