# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State
- Task 01 generalized `WorkspaceTab` for mixed terminal/file tabs and kept persistence in the existing `tabs` table.
- Task 02 made store, command, restore, close, remove, and current terminal-host flows branch by `WorkspaceTab.kind`; file tabs are metadata-only and terminal surfaces are created only for terminal tabs.
- Task 03 added runtime-only file services: project-scoped file access, `WorkspaceFileBufferController`, save/revert/open-external command methods, restore-time saved-buffer loading, and live DI exposure through `AppDependencyContainer`.
- Task 04 integrated the app shell file workspace: `WorkspaceDetailView` now hosts the shared mixed tab strip, terminal/editor primary host, right working-set/repository sidebar, and a thin `CodeEditorView` file editor wrapper.
- Task 05 added app-level file save/revert/open-external commands, file workflow telemetry/logging, visible file restore diagnostics, and dirty file-tab protections for close/remove-session/remove-project.

## Shared Decisions
- SQLite mixed-tab schema uses existing schema version 2 because `currentUserVersion` was already 2 before this task; migration includes an idempotent repair for pre-task v2 databases missing `tabs.kind` and `tabs.file_path`.
- SQLite stores only `file_path` for file tabs; `WorkspaceFileReference.projectRoot` is derived from the tab `workingDirectory`, so file-tab saves require those values to match.
- `openFileTab(sessionID:path:)` validates an absolute readable UTF-8 file under the session project, loads the runtime buffer, then persists/selects or reuses file-tab metadata.
- Restore filters invalid, outside-project, missing, or unreadable file tabs before hydrating `WorkspaceStore`, preserving valid mixed-tab snapshot order and emitting warning diagnostics.
- File buffers now live only in `WorkspaceFileBufferController`; future UI should bind editor text/dirty state through `AppDependencyContainer.fileBufferController`, while durable tab metadata remains in `WorkspaceStore`/SQLite.
- `WorkspaceCommandService` owns explicit `saveFileTab`, `revertFileTab`, and `openFileInExternalEditor` boundaries; app commands route through the shell so failures surface as user messages and editor dirty state refreshes.
- `CodeEditorView` is an app-target dependency only. Core exposes editor/sidebar presentation as plain structs; `LanguageSupport` mappings are centralized in the app wrapper and unsupported keys fall back to plain text.
- File workflow logs use `hashed_path` or omit paths; raw file paths must not be added to file open/save/revert/restore/dirty-close/external-editor log fields.

## Shared Learnings

## Open Risks

## Handoffs
