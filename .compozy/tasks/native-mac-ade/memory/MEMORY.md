# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State

- Task 01 established a SwiftPM-based macOS workspace with a SwiftUI executable target, `NativeMacADECore` library target, and separate core/integration test targets.

## Shared Decisions

- `libghostty` remains unpinned after task 01; task 02 owns the actual upstream revision/linking work. Task 01 only introduced the `GhosttyAdapter` seam and `UnavailableGhosttyAdapter` placeholder.

## Shared Learnings

- The Xcode 26 toolchain can build and test the SwiftPM workspace through both `swift` commands and the generated Xcode package scheme (`xcodebuild -scheme NativeMacADE -destination 'platform=macOS' test`).

## Open Risks

## Handoffs
