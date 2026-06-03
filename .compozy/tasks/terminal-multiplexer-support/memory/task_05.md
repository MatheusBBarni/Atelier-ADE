# Task Memory: task_05.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement task 05: expose Focus Workspace Continuity as a child setting, centralize copy/cues in `FocusWorkspacePresentation`, reuse the active banner and existing correction surfaces, and add focused unit/integration coverage.
- Source documents and ADRs agree on scope: continuity is app-owned project/session/tab restore context only, not live multiplexer/pane/process reattachment.
- Pre-change baseline: no source/test matches for `focus-workspace-continuity-toggle`, `continuityToggleTitle`, `continuityHelpText`, `continuityActiveCue`, or `remembered app`.

## Important Decisions
- Continuity state and copy are centralized in `FocusWorkspaceSettingsPresentation` and `FocusWorkspaceActiveCuePresentation`; the SwiftUI views consume presentation properties instead of owning continuity wording.
- The active banner remains the cue surface. It shows the existing Focus Workspace cue for parent-only users and switches to continuity label/help text only when both parent and child preferences are enabled.
- Existing session search and session row/terminal-child-row surfaces remain the correction path; no new continuity command, palette, or dashboard was added.

## Learnings
- Root-level `AGENTS.md` and `CLAUDE.md` are absent in `another-ade`; only unrelated sibling repositories contain those files.
- Shared memory confirms task 05 should build on task 02 normalized preferences and task 04 restore-time terminal-first selection.
- The `WorkspaceCommandService` protocol is broad, but `FocusWorkspaceUIContractIntegrationTests` can construct the settings section body with `DefaultWorkspaceCommandService`, `InMemoryWorkspacePersistenceStore`, and a tiny terminal-surface fake to cover the SwiftUI section shape.
- SwiftPM full-repo line coverage remains below 80% because app/UI files are included, but current Core source coverage is 91.39%; `FocusWorkspacePresentation.swift` is 100% line-covered.

## Files / Surfaces
- Touched task surfaces: `Sources/NativeMacADECore/Workspace/FocusWorkspacePresentation.swift`, `Sources/NativeMacADE/AppShell/ConfigModalFocusWorkspaceSection.swift`, `Sources/NativeMacADE/AppShell/ContentView.swift`, `Tests/NativeMacADECoreTests/FocusWorkspacePresentationTests.swift`, `Tests/NativeMacADEIntegrationTests/FocusWorkspaceUIContractIntegrationTests.swift`, and `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift`.

## Errors / Corrections
- Worktree already has unrelated modified files before this task, including other `.compozy` task groups, `Package.swift`, and `Package.resolved`; keep staging scoped to task 05 files.
- First UI contract run failed on brittle source assertions; corrected assertions to match actual source shapes and reran the suite successfully.
- Self-review corrected continuity copy from broad "app tabs from saved launch intent" wording to truthful "terminal surfaces from saved launch intent."

## Ready for Next Run
- Verification evidence after final code change: `./scripts/run.sh test --filter FocusWorkspacePresentationTests` passed 7 tests; `./scripts/run.sh test --filter FocusWorkspaceUIContractIntegrationTests` passed 9 tests; `./scripts/run.sh test --filter DefaultWorkspaceCommandServiceIntegrationTests` passed 65 tests; `./scripts/run.sh test --enable-code-coverage` passed 445 tests across 41 suites; `./scripts/run.sh build` passed; `git diff --check` passed.
- Final coverage evidence from `.build/arm64-apple-macosx/debug/codecov/NativeMacADE.json`: Core source line coverage 91.39%, `FocusWorkspacePresentation.swift` 100%, `FocusWorkspaceUIContractIntegrationTests.swift` 87.06%, `DefaultWorkspaceCommandServiceIntegrationTests.swift` 98.98%, and `ConfigModalFocusWorkspaceSection.swift` 68.83%.
