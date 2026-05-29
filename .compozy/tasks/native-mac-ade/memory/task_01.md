# Task Memory: task_01.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot

- Scaffold the greenfield native macOS app workspace with an app shell, core library boundaries, test targets, and placeholder seams for future persistence/restore/terminal/Ghostty work.

## Important Decisions

- Used Swift Package Manager as the initial workspace shape: executable target `NativeMacADE`, library target `NativeMacADECore`, unit test target, and integration test target.
- App startup now uses `AppDependencyContainer.live()` with an empty `WorkspaceStore` instead of booting from preview data.
- Kept Ghostty integration to a placeholder seam; no revision pinning or C interop was added because task 02 owns that scope.
- Encapsulated selected project/session/tab mutations behind store methods so sidebar/session/tab selection stays internally consistent.

## Learnings

- Repo root had no `AGENTS.md` or `CLAUDE.md`; only `.compozy` guidance was present before scaffold creation.
- `swift build`, `swift test`, and `xcodebuild -scheme NativeMacADE -destination 'platform=macOS' test` all work with the generated SwiftPM Xcode package scheme under Xcode 26.5.

## Files / Surfaces

- Added root Swift workspace files: `Package.swift`, `README.md`, `.gitignore`.
- Added SwiftUI app shell under `Sources/NativeMacADE`.
- Added core boundaries under `Sources/NativeMacADECore`: app container, workspace models/store, command service protocol, Ghostty adapter seam, terminal host controller, persistence store protocol/in-memory placeholder, restore coordinator.
- Added tests under `Tests/NativeMacADECoreTests` and `Tests/NativeMacADEIntegrationTests`.

## Errors / Corrections

- Initial `@Bindable` use across module boundaries failed in the app shell; replaced direct projected bindings with explicit `Binding(get:set:)` values that call store selection methods.
- Oracle self-review flagged stale selection invariants and preview app bootstrap; fixed by adding invariant-preserving selection methods and `AppDependencyContainer` startup wiring.

## Ready for Next Run

- Task 01 code and tracking were updated after validation. Task 02 should start from the existing `GhosttyAdapter` seam and decide the actual `libghostty` pin/linking strategy without expanding task 01 placeholders.
