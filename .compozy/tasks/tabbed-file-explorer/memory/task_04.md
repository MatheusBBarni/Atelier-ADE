# Task Memory: task_04.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Integrate the file workspace at the existing `WorkspaceDetailView` seam: right-side working set/tree, shared mixed tab chrome, and a narrow `CodeEditorView` host for selected file tabs.

## Important Decisions
- Keep editor library types in the app/UI layer only; core should expose testable presentation inputs and continue owning file buffers through `WorkspaceFileBufferController`.
- Use `CodeEditorView` only in `FileEditorHostView`; `NativeMacADECore` exposes plain presentation structs for working set, tree rows, and editor eligibility.
- Use a lightweight `Notification.Name.fileBufferDirtyStateChanged` revision tick to refresh tab/sidebar dirty cues because `WorkspaceFileBufferManaging` is protocol-backed and not directly observable in the app shell.

## Learnings
- Prior tasks already added mixed tab metadata, file-tab command flows, restore filtering/loading, and runtime file buffers.
- `ContentView.swift` currently guards terminal hosts to terminal tabs, but selected file tabs still render `FileTabPlaceholderView`.
- No `AGENTS.md` or `CLAUDE.md` files exist under the current checkout.
- Pre-change signal: `swift test --filter WorkspaceStoreTests/mixedTabSnapshotPreservesSingleOrderedTabNamespace` passes, while `rg` finds no `CodeEditorView`/`LanguageSupport` usage.
- `CodeEditorView` 0.15.4 builds with products `CodeEditorView` and `LanguageSupport`; Swift 6 needs `@preconcurrency import CodeEditorView` for its mutable static theme catalog.
- `LanguageSupport` has a limited built-in language set; the app wrapper maps supported keys to library configurations and falls back to `.none`.

## Files / Surfaces
- Expected app surfaces: `Package.swift`, `Sources/NativeMacADE/AppShell/ContentView.swift`, `Sources/NativeMacADE/NativeMacADEApp.swift`.
- Expected core/test surfaces: workspace presentation helpers, file buffer/editor presentation tests, command/restore integration tests as needed.
- Touched app surfaces: added `CodeEditorView`/`LanguageSupport` package dependency, passed file services into the app shell, split `WorkspaceDetailView`, added `FileEditorHostView`, right file workspace sidebar, mixed tab dirty cues, and repository/working-set UI.
- Touched core/test surfaces: added `FileWorkspacePresentation.swift`, exposed `WorkspaceFileBufferController.languageConfigurationKey(forPath:)`, added presentation/unit tests and mixed file-tab integration coverage.

## Errors / Corrections
- Existing modified worktree entries are task tracking/memory files from earlier runs; avoid reverting or staging unrelated tracking files.
- Corrected an initial dirty-state bug where an unloaded editor buffer could appear dirty before `bufferSnapshot` existed.

## Verification
- `swift build --product NativeMacADE` passed after the final code change.
- Focused mixed-tab/editor tests passed: `FileWorkspacePresentationTests`, new command-service file-tab selection test, and mixed file-tab integration paths.
- `swift test` passed with 174 tests.
- `swift test --enable-code-coverage` passed with 174 tests; project-owned source coverage from the generated JSON is 3994/4494 lines, 88.87%.

## Ready for Next Run
