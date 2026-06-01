# Task Memory: task_02.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Prepare the MVP landing-page asset boundary: copied screenshot/logo under `web/src/assets`, fixed public metadata under `web/public`, README/docs assets and Swift app resources preserved.
- Required tests cover asset metadata helpers, Swift resource isolation, canonical `Atelier` labels, built screenshot resolution, public metadata availability, README screenshot preservation, and 80%+ coverage.

## Important Decisions
- Use `docs/images/app-image.png` as the MVP screenshot source and `docs/images/atelier-logo.png` as the public logo/favicon source.
- Keep `Sources/NativeMacADE/Resources/AppIcon.png` app-owned; do not reference it from landing-page asset metadata.
- Root `AGENTS.md` and `CLAUDE.md` were requested but are absent in this repository after `rg --files` lookup.

## Learnings
- `scripts/run.sh` depends on `Sources/NativeMacADE/Resources/AppIcon.png`; asset work must leave that path untouched.
- `README.md` currently renders `docs/images/app-image.png`; task scope requires preserving that reference and source file.
- Pre-change baseline: `web/src/assets/atelier-app-screenshot.png`, `web/src/assets/atelier-logo.png`, `web/public/favicon.png`, `web/public/site.webmanifest`, `web/public/robots.txt`, `web/public/.nojekyll`, `web/src/siteContent.ts`, and `web/ASSETS.md` were missing.
- Final verification command `npm test && npm run build` from `web/` passed: 9 unit tests, 6 integration tests, 100% helper coverage, and Astro built 1 page.
- Browser smoke against `http://127.0.0.1:4321/Atelier-ADE/` loaded title/H1 `Atelier` and exposed both logo and screenshot images in the accessibility snapshot.

## Files / Surfaces
- Planned: `web/src/assets/`, `web/public/`, `web/src/siteContent.ts`, `web/src/pages/index.astro`, `web/tests/`, `web/ASSETS.md`.
- Preserve: `docs/images/app-image.png`, `docs/images/atelier-logo.png`, `Sources/NativeMacADE/Resources/AppIcon.png`, `scripts/run.sh`, `README.md`.
- Touched: `web/src/assets/atelier-app-screenshot.png`, `web/src/assets/atelier-logo.png`, `web/public/favicon.png`, `web/public/site.webmanifest`, `web/public/robots.txt`, `web/public/.nojekyll`, `web/src/siteContent.ts`, `web/src/pages/index.astro`, `web/vitest.config.mjs`, `web/tests/unit/siteContent.test.mjs`, `web/tests/integration/scaffold.test.mjs`, `web/ASSETS.md`.

## Errors / Corrections
- Integration testing showed fixed public metadata links rendered as `/favicon.png` and `/site.webmanifest` while Astro-managed assets used `/Atelier-ADE/_astro/...`; corrected `index.astro` to derive fixed metadata URLs from `getAstroSiteConfig().base`.

## Ready for Next Run
- Task implementation is verified and ready for tracking updates/commit; keep `.compozy/tasks/project-landing-page/memory/` out of the code commit because it was already an untracked memory directory.
