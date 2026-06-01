# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State
- Task 01 implemented the core model contract: `AppPreferences.themeID` defaults to the reserved `system` selection, while `AppTheme.catalog` remains concrete presets only.

## Shared Decisions
- Future appearance UI/runtime tasks should use `AppTheme.orderedSelectionIDs`, `AppTheme.supportedSelectionIDs`, and `AppTheme.resolveEffective(selectionID:systemScheme:)` rather than adding a second registry or resolving persisted selections through concrete-only lookup.

## Shared Learnings
- System mode fallback is pinned by concrete catalog order: light resolves to `catppuccin`, dark resolves to `dracula`.
- Service-level theme application observability now records `selection_id`; when the selection is `system`, concrete runtime resolution is intentionally deferred until UI/runtime code has the current system scheme.

## Open Risks

## Handoffs
