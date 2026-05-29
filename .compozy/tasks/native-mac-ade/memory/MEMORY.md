# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State

- Task 01 established a SwiftPM-based macOS workspace with a SwiftUI executable target, `NativeMacADECore` library target, and separate core/integration test targets.
- Task 06 added the app-owned SwiftUI/AppKit terminal host seam: `TerminalHostController` is now shared by the command service and `ContentView`, owns tab -> surface/cache/lifecycle state, and exposes AppKit host views for selected/visible session tabs.
- Task 07 implemented metadata-only restore through `RestoreCoordinator` and `WorkspaceCommandService.restoreWorkspace()`: launch restore now validates project accessibility, rebuilds workspace state, recreates fresh terminal surfaces for restored tabs, and returns recovery diagnostics/skipped-project records for UI.
- Task 08 added app-local shortcut and pilot observability infrastructure: built-in `SessionShortcut` launch profiles, OSLog-backed `WorkspaceLogger`, `PerformanceMetrics` diagnostics, and command-service inspection APIs remain inside the project/session/tab model.
- Task 04 is now closed with a failure-safe activation path: selection/recency changes are staged in a temporary `WorkspaceStore`, persisted through `WorkspacePersistenceStore.saveActivation(...)`, then committed to the live store only after persistence succeeds.

## Shared Decisions

- `libghostty` remains unpinned after task 01; task 02 owns the actual upstream revision/linking work. Task 01 only introduced the `GhosttyAdapter` seam and `UnavailableGhosttyAdapter` placeholder.

## Shared Learnings

- The Xcode 26 toolchain can build and test the SwiftPM workspace through both `swift` commands and the generated Xcode package scheme (`xcodebuild -scheme NativeMacADE -destination 'platform=macOS' test`).
- SQLite is available directly through `import SQLite3` in the current macOS SwiftPM toolchain; Task 03 did not add an external persistence dependency.
- The implemented source layout uses `Sources/NativeMacADE/...` and `Sources/NativeMacADECore/...`; some PRD task file path examples still use older `AnotherADE/...` placeholders.
- `NordTheme` lives in `NativeMacADECore` so app chrome and future terminal/tab features can share default theme tokens while remaining testable from core tests.
- Terminal lifecycle handling is currently centralized in `TerminalHostController`: tab surface creation is idempotent, host-view resize replays current bounds to the Ghostty adapter, and exit monitoring calls back on the main actor. Future restore work should reuse this controller instead of creating a second surface registry.
- Skipped restore projects remain addressable by persisted project ID: command-service recovery can forget inaccessible persisted records, and reopening a skipped path reuses the existing persisted project instead of duplicating metadata.
- Shortcut-backed session starts must keep metadata and terminal side effects coupled: `DefaultWorkspaceCommandService` creates the first surface first, commits session+first-tab metadata transactionally, and releases/destroys the surface if persistence fails.
- SQLite activation saves must remain transactional and synchronous inside the actor (`saveProject`/`saveSession`/`saveTab`/`saveSnapshot` helpers) so a mid-transaction failure rolls back recency and snapshot changes together.

## Open Risks

- Task 02 could not honestly be closed with the current local C boundary alone: the app still needs a real pinned upstream `libghostty` binary/source artifact linked into the build, not only pin metadata and an app-owned shim.

## Handoffs
