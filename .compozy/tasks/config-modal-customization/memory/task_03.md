# Task Memory: task_03.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Add the command-service settings orchestration surface for loading/saving app preferences and saving/deleting/resetting `SessionShortcut` agent profiles.
- Preserve task-02 bootstrap behavior: default profile changes affect new sessions only, and later tabs keep using the persisted session shortcut.

## Important Decisions
- Keep orchestration in `DefaultWorkspaceCommandService`; do not add a parallel settings service.
- Validate preferences and launch-profile mutations before writing through `WorkspacePersistenceStore`.
- Treat canonical built-ins by stable ID only. Built-in saves force `isBuiltIn = true`, mark `hasUserOverride` only when launch fields differ from the canonical profile, and reset writes the canonical row back.
- `saveAppPreferences(_:)` seeds a referenced built-in profile row before saving preferences so SQLite's `default_session_shortcut_id` foreign key is valid even when the profile list was not preloaded.

## Learnings
- No repo-local `AGENTS.md` or `CLAUDE.md` exists under `/Users/matheusbbarni/projects/another-ade`; use PRD, TechSpec, ADRs, memory, and repository code as guidance.
- Baseline before implementation: `WorkspaceCommandService` has read-only `availableSessionShortcuts()` but no app-preference or profile mutation APIs, and `SessionShortcut.builtInDefaults` contains only Codex and Claude.
- Final verification after implementation: `swift test --enable-code-coverage` passed 102 tests in 12 suites; `llvm-cov report` showed 81.53% region coverage and 88.74% line coverage for source files; `swift build` passed.

## Files / Surfaces
- Expected primary surfaces: `WorkspaceCommandService.swift`, `DefaultWorkspaceCommandService.swift`, `WorkspaceModels.swift`, `WorkspaceStore.swift`, `DefaultWorkspaceCommandServiceTests.swift`, and `DefaultWorkspaceCommandServiceIntegrationTests.swift`.
- Touched implementation surfaces: `WorkspaceCommandService.swift`, `DefaultWorkspaceCommandService.swift`, `AppPreferences.swift`, `WorkspaceModels.swift`, `WorkspaceStore.swift`.
- Touched test surfaces: `DefaultWorkspaceCommandServiceTests.swift`, `DefaultWorkspaceCommandServiceIntegrationTests.swift`.

## Errors / Corrections
- Initial stale-default SQLite integration fixture tried to write an invalid preference through normal persistence, but the foreign key correctly rejected it. The test now creates a deliberate corrupt DB fixture with foreign keys disabled for that row.
- Self-review found that saving a built-in default preference could validate from the in-memory catalog before SQLite had the built-in row; fixed by seeding the referenced built-in before preference save and covering OpenCode as the default.

## Ready for Next Run
- Task 03 implementation and verification are complete; remaining work should move to task 04/05 theme/runtime and UI wiring on top of the new command-service seam.
