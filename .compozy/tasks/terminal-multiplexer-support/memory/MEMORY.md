# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State
- Task 01 implemented the storage foundation: `AppPreferences.focusWorkspaceContinuityEnabled` persists through `app_preferences.focus_workspace_continuity_enabled`, and SQLite workspace metadata is now schema version 7.
- Task 02 enforced the Core parent-child invariant: command-service save, normalized load, and portable-settings apply paths normalize parent-off preferences to `focusWorkspaceContinuityEnabled = false`.
- Task 03 implemented `FocusWorkspaceContinuityRestoreSelector.resolve(restoredSelection:sessions:tabs:appPreferences:)` as the pure restore-only terminal-first selector.
- Task 04 wires the selector inside `DefaultWorkspaceCommandService.restoreWorkspace()` after `RestoreCoordinator` metadata restore and before live `WorkspaceStore.restore(...)` / terminal surface recreation.
- Task 05 exposes continuity as a child setting under Focus Workspace and reuses the active banner cue plus existing session search/session row surfaces for trust and correction.

## Shared Decisions
- Continuity storage stays in the existing app preferences row. No continuity table, restore snapshot field, or separate persistence boundary was added for task 01.
- Task 04 did not add a `RestoreCoordinator` seam; the coordinator remains generic, and the command service applies continuity using the restored store selection, sessions, and tabs.
- Continuity UI/cue copy lives in `FocusWorkspacePresentation`; settings and active banner surfaces should consume that presentation instead of duplicating wording.
- Restore continuity observability uses `continuity_resolution` values `applied`, `disabled`, `fallback_snapshot`, and `no_terminal_candidate`, plus `raw_selected_tab_kind`, `resolved_restore_tab_kind`, and `session_terminal_count`.

## Shared Learnings
- Future invariant, restore, and UI tasks can read/write the continuity flag through the existing `WorkspacePersistenceStore.loadAppPreferences` / `save(appPreferences:)` boundary.
- Future restore/UI tasks can treat preferences returned by `WorkspaceCommandService.loadAppPreferences()` and stored by `saveAppPreferences(_:)` as continuity-normalized; invalid parent-off/child-on persisted rows are repaired before startup restore consumers observe them.
- Restore-time continuity changes the in-memory live/result selection only; `RestoreSnapshot` remains literal last UI selection and is not rewritten to the continuity target.

## Open Risks

## Handoffs
- Continuity copy must stay truthful to app-owned project/session/tab context and terminal surface recreation from launch intent; do not imply live tmux pane or external process reattachment.
