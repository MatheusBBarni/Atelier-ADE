# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State
- Task 02 centralized new-session first-tab bootstrap in `DefaultWorkspaceCommandService.createSession`; future UI/settings work should treat `createSession(projectID:shortcutID:)` as returning a usable session with exactly one initial tab.
- Task 04 introduced the fixed runtime theme catalog in `AppTheme.catalog`; settings UI should present/save those IDs and let shell/terminal surfaces react through `WorkspaceStore.activeTheme`.
- Task 05 added `AppShellState` as the shared settings modal presentation state and `AppShellStartupCoordinator` as the startup path that loads preferences, applies theme, then restores workspace metadata.
- Task 05 added `AppCommandRegistry` as the single source for the managed command IDs/default bindings; app commands should resolve runtime bindings from `WorkspaceStore.appPreferences`.

## Shared Decisions
- `app_preferences.keybindings_json` is serialized through `AppPreferences.keybindingsJSON` as a JSON array of `KeybindingOverride` values sorted by command ID, not as a raw dictionary object. Future callers should use the model helpers instead of hand-rolling this format.
- Later tabs inherit launch intent from the persisted `WorkspaceSession.shortcutID`; they must not re-resolve `AppPreferences.defaultSessionShortcutID`.
- Built-in default profile selections should be saved through `WorkspaceCommandService.saveAppPreferences(_:)`, not direct persistence writes; the service seeds missing built-in `session_shortcuts` rows before saving `app_preferences` so SQLite foreign keys remain valid.
- Unknown persisted keybinding command IDs are ignored while decoding preferences; duplicate known command IDs remain invalid and trigger fallback/validation paths.

## Shared Learnings
- SwiftPM code coverage for this package includes the vendored SwiftTerm checkout in the raw total; PRD coverage checks should report first-party source coverage separately unless a repository gate defines a different denominator.

## Open Risks

## Handoffs
