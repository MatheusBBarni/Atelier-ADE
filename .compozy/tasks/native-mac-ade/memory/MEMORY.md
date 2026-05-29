# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State

- Task 01 established a SwiftPM-based macOS workspace with a SwiftUI executable target, `NativeMacADECore` library target, and separate core/integration test targets.
- Task 06 added the app-owned SwiftUI/AppKit terminal host seam: `TerminalHostController` is now shared by the command service and `ContentView`, owns tab -> surface/cache/lifecycle state, and exposes AppKit host views for selected/visible session tabs.

## Shared Decisions

- `libghostty` remains unpinned after task 01; task 02 owns the actual upstream revision/linking work. Task 01 only introduced the `GhosttyAdapter` seam and `UnavailableGhosttyAdapter` placeholder.

## Shared Learnings

- The Xcode 26 toolchain can build and test the SwiftPM workspace through both `swift` commands and the generated Xcode package scheme (`xcodebuild -scheme NativeMacADE -destination 'platform=macOS' test`).
- SQLite is available directly through `import SQLite3` in the current macOS SwiftPM toolchain; Task 03 did not add an external persistence dependency.
- The implemented source layout uses `Sources/NativeMacADE/...` and `Sources/NativeMacADECore/...`; some PRD task file path examples still use older `AnotherADE/...` placeholders.
- `NordTheme` lives in `NativeMacADECore` so app chrome and future terminal/tab features can share default theme tokens while remaining testable from core tests.
- Terminal lifecycle handling is currently centralized in `TerminalHostController`: tab surface creation is idempotent, host-view resize replays current bounds to the Ghostty adapter, and exit monitoring calls back on the main actor. Future restore work should reuse this controller instead of creating a second surface registry.

## Open Risks

- Task 02 could not honestly be closed with the current local C boundary alone: the app still needs a real pinned upstream `libghostty` binary/source artifact linked into the build, not only pin metadata and an app-owned shim.

## Handoffs
