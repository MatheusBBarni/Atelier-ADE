# Task Memory: task_02.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Enforce the Focus Workspace parent-child invariant in Core: parent-off app preferences must expose and persist `focusWorkspaceContinuityEnabled = false` on both load and save, without changing existing parent behavior.

## Important Decisions
- Keep normalization in the command-service preference boundary, with a small `AppPreferences` helper so save, load, and portable-settings apply paths share the same contract.

## Learnings
- Pre-change signal: `DefaultWorkspaceCommandService.swift` had no `focusWorkspaceContinuityEnabled` references, and no Core normalization helper existed for the continuity child flag.
- `AGENTS.md` / `CLAUDE.md` were not present in the `another-ade` repo; a parent-directory search only found those files in sibling repositories.
- `WorkspaceCommandService.loadAppPreferences()` startup goes through `bootstrapPortableSettings()`, so normalization must happen inside `loadNormalizedAppPreferences(...)` and after portable-settings projection as well as direct settings save.

## Files / Surfaces
- `Sources/NativeMacADECore/Workspace/AppPreferences.swift`
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift`
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift`
- `Tests/NativeMacADECoreTests/AppShellStateTests.swift`
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift`

## Errors / Corrections
- Repository-wide coverage includes untested SwiftUI app files and reported 36.22% line coverage, so task coverage evidence was taken from the modified Core backend files: `DefaultWorkspaceCommandService.swift`, `AppPreferences.swift`, and `AppShellState.swift` reported 86.58% line coverage.

## Ready for Next Run
- Implementation complete and verified with `./scripts/run.sh test --enable-code-coverage` passing 426 tests across 39 suites.
- Focused suites also passed: `NativeMacADECoreTests.DefaultWorkspaceCommandServiceTests` (105 tests), `NativeMacADECoreTests.AppShellStateTests` (5 tests), and `NativeMacADEIntegrationTests.DefaultWorkspaceCommandServiceIntegrationTests` (61 tests).
