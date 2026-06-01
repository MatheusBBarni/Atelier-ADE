---
status: completed
title: "Scaffold Astro site foundation in `web/`"
type: frontend
complexity: high
dependencies: []
---

# Task 01: Scaffold Astro site foundation in `web/`

## Overview
This task creates the isolated Astro workspace that the landing page will live in. It establishes the minimum web-tooling footprint the repository needs without expanding scope into content, assets, or runtime enhancements.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST create a new top-level `web/` Astro project boundary that is isolated from the SwiftPM app and internal `docs/` content.
2. MUST add the minimum build configuration required for a static Astro site with GitHub Pages-aware `site` and `base` settings.
3. MUST add repository ignore rules for web dependencies and build artifacts without changing Swift build behavior.
4. MUST leave a buildable one-route site skeleton that later tasks can extend.
5. SHOULD keep the initial scaffold limited to the MVP footprint described in TechSpec “System Architecture” and “Development Sequencing”.
</requirements>

## Subtasks
- [x] 1.1 Create the `web/` project root with Astro package metadata and build scripts.
- [x] 1.2 Add Astro and TypeScript configuration for a static GitHub Pages deployment path.
- [x] 1.3 Add a minimal landing-page route stub so the site builds before feature content lands.
- [x] 1.4 Update repository ignore rules for `web/node_modules`, `web/dist`, and `.astro` artifacts.
- [x] 1.5 Keep all web tooling separate from `Package.swift`, `scripts/run.sh`, and existing release automation.

## Implementation Details
Create the new web surface described in TechSpec “System Architecture” and step 1 of “Development Sequencing”. Keep this task scoped to workspace setup only; do not absorb asset normalization, page content, or GitHub API behavior.

### Relevant Files
- `web/package.json` — owns Astro dependencies and local build scripts.
- `web/astro.config.mjs` — defines GitHub Pages `site`, `base`, and static-output behavior.
- `web/tsconfig.json` — establishes the minimum TypeScript baseline for Astro.
- `web/src/pages/index.astro` — provides the initial buildable route stub for later page work.
- `.gitignore` — must be extended for Node and Astro output artifacts.
- `.compozy/tasks/project-landing-page/_techspec.md` — source of truth for structure and sequencing.

### Dependent Files
- `.github/workflows/deploy-pages.yml` — will consume the build scripts and config created here.
- `README.md` — later public-link alignment depends on the final site location and path conventions.
- `docs/images/app-image.png` — later asset work depends on the scaffolded Astro asset structure.
- `scripts/run.sh` — must remain untouched so Swift app workflows stay isolated.
- `Package.swift` — confirms the SwiftPM boundary this task must not cross.

### Related ADRs
- [ADR-002: Trust-First Repo-Oriented Landing Page PRD Scope](../adrs/adr-002.md) — Keeps the MVP small and repo-oriented.
- [ADR-003: Implement the Landing Page as an Astro Site in /web with GitHub Pages Deployment](../adrs/adr-003.md) — Directly defines the site location and deployment model.
- [ADR-004: Use a Client-Side GitHub Star CTA Instead of Site Analytics or Build-Time GitHub Metadata](../adrs/adr-004.md) — Prevents foundation work from introducing backend or analytics infrastructure.

## Deliverables
- New top-level `web/` Astro workspace with package metadata and static-site config.
- Minimal buildable route stub in `web/src/pages/index.astro`.
- Updated `.gitignore` entries for Astro and Node artifacts.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for scaffold build and workspace isolation **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Validate any extracted config helper derives the expected GitHub Pages `base` or site metadata value.
  - [x] Validate any shared script/config utility returns stable defaults for local and CI builds.
  - [x] Validate any helper added for workspace path or metadata handling preserves the `web/` boundary.
- Integration tests:
  - [x] `npm run build` (or equivalent) from `web/` succeeds with the scaffold only.
  - [x] The generated site contains a valid `index.html` route in build output.
  - [x] Swift workflows (`swift build` / existing release workflow structure) remain unaffected by the new web scaffold.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The repository contains an isolated `web/` Astro scaffold with no required changes to Swift build surfaces.
- GitHub Pages-aware configuration exists and is ready for later landing-page content work.
