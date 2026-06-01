# Task Memory: task_05.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement Task 05 shell behavior: focus-aware terminal affordance hiding, tab-row visibility, agent-tab/menu/placeholder gating, calm focus rejection alerts, tests, manual verification notes, tracking updates, and a local commit after clean verification.

## Important Decisions
- Use the existing shared `FocusWorkspacePolicy` for shell visibility decisions and add small pure helpers there rather than duplicating tab-count logic in SwiftUI.
- Keep command enforcement authoritative; UI gating only hides or preempts affordances where selected-session state is already known.
- Keep `TabChromeView` mounted at zero height when the Focus Workspace tab row is visually collapsed so menu handlers for close/rename remain available.
- Map `WorkspaceCommandError.focusWorkspaceRejected` through `FocusWorkspaceBlockedActionPresentation` and then into `UserMessage.commandFailure`.

## Learnings
- `TabChromeView` currently owns `.createPlainTab` and `.createDefaultAgentTab` notification handlers. Collapsing that row for one-tab Focus Workspace sessions would also remove menu/shortcut handling unless the handlers move to an always-present shell layer.
- `NativeMacADEApp` currently shows terminal-tab menu commands whenever a session exists; `ContentView` catches focus command rejections with raw `String(describing:)` in terminal/file open paths.
- Menu notification handling for terminal tab creation now lives in `WorkspaceDetailView`, which stays mounted when the tab row is collapsed.

## Files / Surfaces
- Expected code surfaces: `FocusWorkspacePolicy.swift`, `FocusWorkspacePresentation.swift`, `ContentView.swift`, `NativeMacADEApp.swift`, and focused core/integration tests.
- Touched code/tests: `Sources/NativeMacADECore/Workspace/FocusWorkspacePolicy.swift`, `Sources/NativeMacADECore/Workspace/FocusWorkspacePresentation.swift`, `Sources/NativeMacADE/AppShell/ContentView.swift`, `Sources/NativeMacADE/NativeMacADEApp.swift`, `Tests/NativeMacADECoreTests/FocusWorkspacePolicyTests.swift`, `Tests/NativeMacADECoreTests/FocusWorkspacePresentationTests.swift`, `Tests/NativeMacADEIntegrationTests/FocusWorkspaceUIContractIntegrationTests.swift`.

## Errors / Corrections
- Correction during implementation: initial row-collapse approach would have removed tab chrome command handlers. Fixed by keeping `TabChromeView` mounted with zero height while moving create-tab notifications to `WorkspaceDetailView`.

## Ready for Next Run
- Verification evidence: `swift test --filter FocusWorkspace` passed 26 tests; `swift test --enable-code-coverage` passed 299 tests; `xcrun llvm-cov report ... -ignore-filename-regex='(^|/)\\.build/|(^|/)Tests/'` reported 82.90% region coverage and 89.73% line coverage.
- Manual shell verification guidance for QA: enable Focus Workspace, then check empty selected session still shows first-tab CTAs and menu commands; one-terminal session hides tab plus and New Tab/New Agent menu commands and shows friendly Focus Workspace copy if a blocked command is invoked; terminal+file session keeps tab row visible but hides blocked terminal creation; same-file reopen focuses the existing file tab; different-file open from tree and search shows the friendly file-slot alert; restored legacy multi-tab session remains navigable and shows friendly copy on new terminal-tab attempt.
