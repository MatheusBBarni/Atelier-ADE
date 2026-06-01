---
status: completed
title: "Prepare MVP site assets and fixed public metadata"
type: frontend
complexity: medium
dependencies:
  - task_01
---

# Task 02: Prepare MVP site assets and fixed public metadata

## Overview
This task prepares the small set of public-ready assets the landing page needs and puts them under clear Astro ownership. It keeps the MVP screenshot-led without disturbing the app-owned resources or the current README asset flow.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST copy or normalize only the MVP screenshot, logo, favicon, and fixed public metadata files needed by the landing page.
2. MUST place page-imported assets under `web/src/assets/` and fixed-path public files under `web/public/`.
3. MUST NOT move or break app-owned resources currently used by the Swift app or bundle scripts.
4. MUST keep public asset naming aligned with the canonical public product name used by the landing page.
5. SHOULD avoid repo-wide asset cleanup; this task is limited to MVP site ownership.
</requirements>

## Subtasks
- [x] 2.1 Audit current screenshot, logo, and icon sources already present in the repo.
- [x] 2.2 Copy the selected MVP visual assets into Astro-managed locations under `web/`.
- [x] 2.3 Add fixed-path public metadata files required for GitHub Pages hosting and site identity.
- [x] 2.4 Preserve the existing README screenshot source so current repo presentation does not break.
- [x] 2.5 Document the asset ownership boundary between app resources, docs assets, and site assets.

## Implementation Details
Use the asset split defined in TechSpec “System Architecture” and step 5 of “Development Sequencing”. This task should not expand into page layout work beyond making assets available for the route to consume.

### Relevant Files
- `web/src/assets/` — destination for the screenshot and other Astro-managed images.
- `web/public/` — destination for favicon and fixed-path public files.
- `docs/images/app-image.png` — current screenshot source for MVP proof.
- `docs/images/atelier-logo.png` — strongest current public-logo candidate.
- `Sources/NativeMacADE/Resources/AppIcon.png` — existing app icon source that must remain app-owned.
- `.compozy/tasks/project-landing-page/_techspec.md` — defines asset ownership and task sequencing.

### Dependent Files
- `web/src/pages/index.astro` — will consume the normalized screenshot and public metadata.
- `web/src/siteContent.ts` — should point to the selected public asset names and URLs.
- `README.md` — still depends on `docs/images/app-image.png`, so current screenshot handling must remain intact.
- `web/astro.config.mjs` — affects how public asset URLs resolve under GitHub Pages.
- `scripts/run.sh` — indirectly depends on app-owned icon resources remaining untouched.

### Related ADRs
- [ADR-001: Docs-First Trailhead Landing Page Scope for V1](../adrs/adr-001.md) — Constrains the MVP to a narrow proof set.
- [ADR-002: Trust-First Repo-Oriented Landing Page PRD Scope](../adrs/adr-002.md) — Requires screenshot-led proof and trust-first presentation.
- [ADR-003: Implement the Landing Page as an Astro Site in /web with GitHub Pages Deployment](../adrs/adr-003.md) — Defines the `/web` ownership model for site assets.

## Deliverables
- Normalized MVP screenshot/logo assets in the correct `web/` locations.
- Fixed-path public metadata assets required by the Astro site.
- Preserved app-resource and README asset behavior outside the site.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for asset resolution and public metadata availability **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Validate any asset-metadata helper resolves the expected public paths for screenshot and favicon assets.
  - [x] Validate any asset-selection helper does not reference Swift app resource paths directly.
  - [x] Validate any public-name-derived asset labels use the canonical `Atelier` naming.
- Integration tests:
  - [x] Built landing page resolves the screenshot from the new Astro-managed asset location.
  - [x] Built site serves favicon and any other fixed-path public metadata files from `web/public/`.
  - [x] `README.md` still renders the existing screenshot path without broken references after asset preparation.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The MVP asset set is available under `web/` without breaking current app or README asset usage.
- Asset ownership is explicit and limited to the landing page scope.
