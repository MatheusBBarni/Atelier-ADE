# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State

## Shared Decisions
- Task 01 persistence APIs validate complete canonical reorder payloads: `saveProjectOrder` expects every persisted project exactly once, and `saveTabOrder` expects every persisted tab for the target session exactly once via `visibleTabIDs + hiddenPersistedTabIDs`.

## Shared Learnings
- Future command orchestration must include persisted-but-hidden session tabs in `SessionTabReorderPlan.hiddenPersistedTabIDs`; omitting them causes persistence validation to fail instead of silently dropping or duplicating ordinals.
- Reorder drag/drop surfaces should use an own-process custom `UTType` instead of generic text drops so stale local drag state or unrelated external drags cannot trigger command payloads.

## Open Risks

## Handoffs
