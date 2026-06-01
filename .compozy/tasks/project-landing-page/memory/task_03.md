# Task Memory: task_03.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement task 03: replace the scaffold landing page with the trust-first single-route MVP, centralizing public copy and links in `web/src/siteContent.ts`.
- Baseline captured before implementation: `npm run build` succeeds, but built HTML still contains `Landing page foundation` and lacks repo/docs/quickstart CTA copy.

## Important Decisions
- Follow ADR-002 over ADR-001 where CTA posture differs: repository is the primary downstream path, while docs and quickstart remain secondary.
- Do not add GitHub API/star-fetch behavior in this task; leave stable fallback markup and an integration point for task 04.
- Use the repository README as the current docs target and the README build/run anchor as the quickstart target because no separate public docs or quickstart route exists yet.

## Learnings
- Root `AGENTS.md` and `CLAUDE.md` are absent in this repository.
- `README.md` and `scripts/run.sh` confirm the public product name is `Atelier`; `NativeMacADE` is internal package/executable naming and must not appear in public page copy.
- Browser plugin runtime was loadable, but no in-app browser was registered in this session (`agent.browsers.list()` returned empty), so visual browser inspection could not be completed through Browser.

## Files / Surfaces
- Expected implementation surfaces: `web/src/siteContent.ts`, `web/src/pages/index.astro`, and web tests under `web/tests/`.
- Implemented surfaces: `web/src/siteContent.ts`, `web/src/pages/index.astro`, `web/tests/unit/siteContent.test.mjs`, and `web/tests/integration/scaffold.test.mjs`.
- The page exposes the future repo-star enhancement insertion point with `id="repo-star-cta"`, `data-repo-star-cta`, `data-repo-url`, and `data-repo-cta-fallback`.

## Errors / Corrections
- Initial integration assertion expected an exact `<h1>` tag string; Astro injects scoped `data-astro-*` attributes, so the test was corrected to use a semantic regex.

## Ready for Next Run
- Verification passed with `cd web && npm run test && npm run build && cd .. && swift test`: web unit 13/13 with 100% coverage, web integration 10/10, Astro build 1 page, Swift test 213/213.
- Tracking files were updated after verification; implementation commit should include only web source/test changes, not `.compozy` tracking or memory files.
