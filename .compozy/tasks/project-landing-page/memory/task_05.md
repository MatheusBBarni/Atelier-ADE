# Task Memory: task_05.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Add a dedicated GitHub Pages deployment workflow for the Astro site under `web/`.
- Wire CI to run the MVP validation baseline: Astro build, link/path checks, no-JavaScript repo CTA check, and accessibility smoke check.
- Keep the workflow isolated from the existing macOS `release-build.yml` automation.

## Important Decisions
- Treat ADR-002 and the TechSpec as the current CTA posture: repo-first is intentional even though ADR-001 originally described docs-first.
- Use the existing `web/src/config/siteConfig.mjs` GitHub Pages defaults as the source for Pages `site`/`base` validation.
- Use a lightweight Node/jsdom built-output validator instead of adding a browser E2E or visual regression stack.
- Run only web unit tests in the Pages workflow before build/validation; the full local integration suite still covers Swift isolation, but Pages CI should not depend on the macOS release pipeline.

## Learnings
- `AGENTS.md` and `CLAUDE.md` are not present in this repository; only sibling project copies were found.
- Pre-change signal: `.github/workflows/deploy-pages.yml` does not exist and `npm run validate:ci` fails with a missing script.
- Verification evidence before tracking: `npm test && npm run validate:ci` passed after implementation. Unit coverage summary was statements 89.31%, branches 82.17%, functions 89.09%, lines 89.37%; integration tests reported 16 passed; validators reported `links: pass`, `no-js-cta: pass`, and `a11y: pass`.

## Files / Surfaces
- Expected implementation surfaces: `.github/workflows/deploy-pages.yml`, `web/package.json`, `web/scripts/validation/*`, and targeted web tests.
- Existing release workflow `.github/workflows/release-build.yml` must remain macOS-only and unchanged in responsibility.
- Added/updated surfaces: `.github/workflows/deploy-pages.yml`, `web/package.json`, `web/src/config/repository.mjs`, `web/src/config/siteConfig.mjs`, `web/src/siteContent.ts`, `web/scripts/validate-built-site.mjs`, `web/scripts/validation/ciCommands.mjs`, `web/scripts/validation/siteChecks.mjs`, `web/tests/unit/ciCommands.test.mjs`, `web/tests/unit/siteChecks.test.mjs`, `web/tests/integration/scaffold.test.mjs`, and `web/vitest.config.mjs`.

## Errors / Corrections
- `npm run validate:ci` initially failed during Astro build because browser CTA imports reached Node-only `siteConfig.mjs` helpers. Correction: split browser-safe repository constants into `web/src/config/repository.mjs` and keep Node path helpers in `siteConfig.mjs`.

## Ready for Next Run
- Code verification passed and task tracking is ready to be marked complete.
- Local implementation commit created: `6485bb2 ci: add pages deployment validation`. Tracking/memory files remain unstaged by workflow rule.
