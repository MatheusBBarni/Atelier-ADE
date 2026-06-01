# Task Memory: task_03.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement the project sidebar reorder interaction in `ContentView.swift`, keeping views as a thin drag/drop shell that submits ordered project IDs through `WorkspaceCommandService.reorderProjects`.

## Important Decisions
- Use existing command/store/persistence reorder behavior from task_02; do not add a new project management surface or mutate `WorkspaceStore` directly from SwiftUI.
- Added a narrow `ProjectReorderPayload` helper in `NativeMacADECore` so the sidebar can compute command payloads and skip original-position no-ops without moving persistence or store ownership into SwiftUI.
- Sidebar drag providers use an own-process project ID `UTType`; `ProjectSidebarView` relies on local state for active drag feedback but generic text drops cannot enter the reorder path.

## Learnings
- Repository has no local `AGENTS.md` or `CLAUDE.md`; PRD, TechSpec, ADRs, and task files are the active project-specific guidance for this run.
- Pre-change signal: command/store/persistence reorder paths exist, but `ProjectSidebarView` has no project drag/drop wiring or insertion feedback.
- Swift 6 rejected a mutable `PreferenceKey.defaultValue`; using `static let` fixed the compile error.
- Validation evidence: `./scripts/run.sh test --enable-code-coverage` passed 252 tests with total core region coverage 81.66% and line coverage 88.81%; `./scripts/run.sh build` completed successfully.

## Files / Surfaces
- Touched: `Sources/NativeMacADE/AppShell/ContentView.swift` for project row drag/drop, insertion indicator, no-op filtering, command-backed submission, and error messaging.
- Touched: `Sources/NativeMacADECore/Workspace/ProjectReorderPayload.swift` for ordered project ID payload calculation.
- Touched: `Tests/NativeMacADECoreTests/ProjectReorderPayloadTests.swift` for bottom-to-top and no-op payload coverage.
- Touched: `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` for selected-project stability after reorder.

## Errors / Corrections
- Corrected the drop provider from generic text to an own-process project ID type after self-review found stale drag state could otherwise combine with unrelated text drops.
- Corrected `ProjectDropTargetHeightPreferenceKey.defaultValue` from `static var` to `static let` after `swift build` reported a Swift 6 concurrency-safety error.

## Ready for Next Run
- Task 03 implementation and verification are ready for tracking updates and commit. Manual smoke path: open an app workspace with at least three projects, drag the bottom project row to the top half of the first project card, confirm the insertion line appears above the first card, drop, navigate away/back or relaunch, and confirm order plus selected project persist.
