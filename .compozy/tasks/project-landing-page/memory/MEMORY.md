# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State

## Shared Decisions
- Until a `LICENSE` file exists, public entry copy should frame the repository as public/source-visible for inspection and avoid broad open-source license claims.

## Shared Learnings
- Browser-bundled web code should import repository constants from `web/src/config/repository.mjs`; `web/src/config/siteConfig.mjs` also exports them but includes Node-only workspace helper imports.

## Open Risks

## Handoffs
