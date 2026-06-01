# Task Memory: task_01.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Scaffold the first isolated Astro workspace under top-level `web/` with static GitHub Pages-aware config, one buildable route, tests, and ignore rules.
- Keep scope limited to foundation only; no landing-page content, asset normalization, GitHub API CTA behavior, deploy workflow, README changes, `Package.swift`, or `scripts/run.sh` edits.

## Important Decisions
- Use ADR-002/ADR-003/ADR-004 as current direction where they refine ADR-001: repo-first CTA posture, Astro in `/web`, GitHub Pages deployment model, and no analytics/backend foundation in this task.
- Keep the Astro config values in `web/src/config/siteConfig.mjs` so the GitHub Pages `site`/`base` defaults and local/CI overrides are unit-tested instead of embedded only in `astro.config.mjs`.
- Disable Astro telemetry through package scripts for local and CI web commands.

## Learnings
- Repository has no local `AGENTS.md` or `CLAUDE.md`; matches found by `find ..` were in sibling projects and do not apply.
- Baseline before implementation: `web/` and `web/package.json` are absent.
- Git remote is `git@github.com:MatheusBBarni/Atelier-ADE.git`, so Pages defaults should target owner `MatheusBBarni`, repo `Atelier-ADE`, site `https://matheusbbarni.github.io`, and base `/Atelier-ADE/`.
- Astro 6.4.2 requires Node `>=22.12.0`; the web package engine and lockfile were corrected to match.

## Files / Surfaces
- Must avoid edits to Swift build surfaces: `Package.swift`, `scripts/run.sh`, and existing `.github/workflows/release-build.yml`.
- Added `web/package.json`, `web/package-lock.json`, `web/astro.config.mjs`, `web/tsconfig.json`, `web/vitest.config.mjs`, `web/src/config/siteConfig.mjs`, `web/src/env.d.ts`, `web/src/pages/index.astro`, `web/tests/unit/siteConfig.test.mjs`, and `web/tests/integration/scaffold.test.mjs`.
- Updated `.gitignore` for `web/node_modules/`, `web/dist/`, `web/.astro/`, and `web/coverage/`.

## Errors / Corrections
- Corrected the initial package engine from Node `>=20.19.0` to `>=22.12.0` after checking Astro's installed package metadata.

## Ready for Next Run
- Fresh verification after the final code change passed: `npm test` from `web/` (5 unit tests, 3 integration tests, 100% config-helper coverage), `npm run build` from `web/` (static output with `dist/index.html`), root `swift build`, and `git diff --check`.
- Generated artifacts remain ignored; do not stage `web/node_modules/`, `web/dist/`, `web/.astro/`, or `web/coverage/`.
