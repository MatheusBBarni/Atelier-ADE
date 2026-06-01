# Task Memory: task_06.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Align README and public repo-facing entry points with the shipped landing page: canonical name `Atelier`, repo-first CTA hierarchy, honest early/source-build-first status, README screenshot proof, and quickstart commands backed by `scripts/run.sh`.

## Important Decisions
- Scope stays public-entry alignment only; do not rename SwiftPM package/product names such as `NativeMacADE`.
- Treat `web/src/siteContent.ts` as the canonical public link/copy source for landing-page alignment.
- Because the repository currently has no `LICENSE` file, public entry copy should say source is public for inspection and license/reuse rights are pending rather than making a broad open-source license claim.

## Learnings
- `AGENTS.md` and `CLAUDE.md` are not present in this repository root.
- The landing-page PRD/ADR source of truth is repo-first now; older docs-first language remains historical context in `_idea.md` and ADR-001.
- Pre-change baseline: `README.md` had no landing-page/product-overview link and did not expose the landing-page CTA labels (`Open the repository`, `Read the README`, `Build and run`).
- Verification evidence: `npm run test` passed 37 unit tests and 22 integration tests; unit coverage was 89.35% statements / 82.17% branches / 89.09% functions / 89.41% lines. `npm run validate:ci` passed unit coverage, Astro build, link validation, no-JS CTA validation, and accessibility smoke. `./scripts/run.sh test` passed 213 Swift tests.

## Files / Surfaces
- Initial audit surfaces: `README.md`, `web/src/siteContent.ts`, `web/src/pages/index.astro`, `web/src/components/RepoStarCTA.astro`, `scripts/run.sh`, `.github/workflows/release-build.yml`, `Package.swift`, `docs/images/app-image.png`.
- Updated surfaces so far: `README.md`, `web/src/siteContent.ts`, `web/src/pages/index.astro`, `web/tests/unit/siteContent.test.mjs`, `web/tests/integration/scaffold.test.mjs`, `web/tests/integration/publicEntryPoints.test.mjs`.

## Errors / Corrections
- Corrected public license language after confirming no `LICENSE` file exists.

## Ready for Next Run
- Task 06 implementation and verification are complete; remaining closeout is tracking status update plus the local commit.
