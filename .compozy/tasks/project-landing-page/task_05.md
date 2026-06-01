---
status: pending
title: "Add GitHub Pages deployment and basic web validation"
type: infra
complexity: medium
dependencies:
  - task_01
  - task_02
  - task_03
  - task_04
---

# Task 05: Add GitHub Pages deployment and basic web validation

## Overview
This task makes the landing page publishable and verifiable. It adds a dedicated GitHub Pages workflow for the new Astro site and wires in the basic build, link, and accessibility checks the MVP requires without expanding into a heavy QA or visual-regression stack.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST add a dedicated GitHub Pages workflow that builds and deploys the Astro site from `web/`.
2. MUST keep the Pages workflow separate from the existing macOS release workflow.
3. MUST run the MVP validation baseline: Astro build, link/path checks, no-JavaScript CTA validation, and a basic accessibility smoke pass.
4. MUST keep Pages configuration compatible with the final `site` and `base` settings used by Astro.
5. SHOULD fail fast in CI without affecting the existing Swift release pipeline.
</requirements>

## Subtasks
- [ ] 5.1 Add the GitHub Actions workflow that builds the Astro site from `web/`.
- [ ] 5.2 Configure the workflow to publish to GitHub Pages using repository-supported permissions.
- [ ] 5.3 Add the required build and link/path validation commands to the workflow.
- [ ] 5.4 Add a lightweight accessibility and no-JavaScript CTA smoke validation step.
- [ ] 5.5 Keep the new workflow isolated from the existing macOS release automation.

## Implementation Details
Use TechSpec “Integration Points”, “Testing Approach”, “Development Sequencing”, and “Monitoring and Observability”. This task owns publishability and CI validation, not page content or README alignment.

### Relevant Files
- `.github/workflows/deploy-pages.yml` — primary CI/deployment deliverable for the web surface.
- `web/package.json` — defines build and validation commands the workflow will execute.
- `web/astro.config.mjs` — must expose correct Pages-aware `site` and `base` behavior.
- `web/src/pages/index.astro` — source of route, headings, links, and labels checked by smoke validation.
- `web/src/components/RepoStarCTA.astro` — must preserve a working fallback CTA when validated without JavaScript.
- `.compozy/tasks/project-landing-page/_techspec.md` — defines the required validation baseline.

### Dependent Files
- `.github/workflows/release-build.yml` — existing workflow that must stay independent.
- `.gitignore` — may need to already cover `web/` artifacts for a clean CI workspace.
- `README.md` — later link alignment depends on the final published site location.
- `docs/images/app-image.png` — affects built-page asset resolution in validation.
- `scripts/run.sh` — should remain untouched by web deployment work.

### Related ADRs
- [ADR-001: Docs-First Trailhead Landing Page Scope for V1](../adrs/adr-001.md) — Reinforces a narrow, inspectable MVP surface.
- [ADR-002: Trust-First Repo-Oriented Landing Page PRD Scope](../adrs/adr-002.md) — Keeps the validation focused on the repo-first public flow.
- [ADR-003: Implement the Landing Page as an Astro Site in /web with GitHub Pages Deployment](../adrs/adr-003.md) — Directly defines Pages-based deployment from `/web`.
- [ADR-004: Use a Client-Side GitHub Star CTA Instead of Site Analytics or Build-Time GitHub Metadata](../adrs/adr-004.md) — Requires validation of fallback-first CTA behavior.

## Deliverables
- Dedicated GitHub Pages deployment workflow for the Astro site.
- CI validation baseline for build, link/path, accessibility, and no-JS CTA behavior.
- Confirmed separation between web deploy automation and existing app release automation.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for CI build/deploy validation behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Validate any workflow-command helper or validation-script parser resolves the expected `web/` commands.
  - [ ] Validate any site/base-path helper used by CI checks respects the GitHub Pages repository path.
  - [ ] Validate any no-JS CTA check helper identifies the GitHub repo link in built output.
- Integration tests:
  - [ ] The GitHub Pages workflow builds the site successfully from `web/`.
  - [ ] Link/path validation passes against the built output using the configured Pages base path.
  - [ ] The validation suite confirms the repo CTA still works when JavaScript enhancement is unavailable.
  - [ ] The existing `release-build.yml` remains unchanged in responsibility and still targets the macOS app only.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The repository can publish the landing page through a dedicated GitHub Pages workflow.
- Basic validation catches broken builds, broken links, and broken fallback CTA behavior before deployment.
