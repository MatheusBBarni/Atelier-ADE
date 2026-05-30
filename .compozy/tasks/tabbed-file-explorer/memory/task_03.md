# Task Memory: task_03.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement task 03: add project-scoped file access, runtime-only file buffers, explicit save/revert/open-external command surfaces, and project bookmark population without storing live buffer text in `WorkspaceStore` or SQLite.
- Pre-change signal: `openFileTab` exists from task 02, but `rg "saveFileTab|revertFileTab|WorkspaceFileBuffer|ExternalEditor" Sources Tests` showed no save/revert command surface, file-buffer controller, or external-editor boundary in `Sources`.

## Important Decisions
- Added `WorkspaceFileAccessing`, `WorkspaceFileBufferManaging`, and `ExternalEditorOpening` as core runtime boundaries instead of storing buffers in `WorkspaceStore` or SQLite.
- `DefaultWorkspaceCommandService.openFileTab` now validates and loads text before persisting a new file tab, so unsupported or out-of-root files do not leave stale tab metadata behind.
- Save and revert operate through `WorkspaceFileBufferController`; dirty state changes only after `saveTextFile` succeeds or after a successful revert reload.
- Project open stores Foundation-created bookmark data when available; no fake bookmark bytes are persisted if bookmark creation fails.

## Learnings
- No repo-local `AGENTS.md` or `CLAUDE.md` files exist under `/Users/matheusbbarni/projects/another-ade`; sibling repo guidance files were intentionally ignored as unrelated.
- Existing dirty worktree changes are tracking/memory files from other tasks and prior tabbed-file-explorer tasks; avoid reverting or restaging those unrelated edits.
- Swift 6 rejects `NSEnumerator` sequence iteration from async contexts; `LocalWorkspaceFileAccess.enumerateProjectFiles` uses `nextObject()` instead.

## Files / Surfaces
- `Sources/NativeMacADECore/Files/WorkspaceFileServices.swift`: new file-access service, runtime buffer controller, file/editor position models, and system external-editor opener.
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift`: added save/revert/open-external command requirements and file-specific command errors.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift`: wired project bookmark creation, file-tab buffer loading, save/revert/open-external orchestration, restore buffer loading, and buffer discard on close/remove.
- `Sources/NativeMacADECore/App/AppDependencyContainer.swift`: exposes live file access, buffer controller, and external editor opener for later UI binding.
- Added/updated unit and integration tests for file access, buffer dirty state, command-service file flows, bookmark metadata, and metadata-only restore.

## Errors / Corrections
- Removed a path-bytes bookmark fallback during self-review because it would populate invalid bookmark data.
- Initial compile failed on async `NSEnumerator` iteration; fixed by using `nextObject()`.

## Ready for Next Run
- Verification before tracking: `swift test --enable-code-coverage` passed 168 tests; `xcrun llvm-cov report ...` reported 80.48% source region coverage and 88.77% source line coverage.
- Final pre-commit verification after tracking: `git diff --check`, `git diff --cached --check`, and `swift test --enable-code-coverage` passed; coverage remained 80.48% regions and 88.77% lines.
- Code/test changes were committed locally as `73e5059 feat: add file runtime services`; task memory/tracking files were intentionally left uncommitted per tracking-only commit guidance.
