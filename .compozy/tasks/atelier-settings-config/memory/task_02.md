# Task Memory: task_02.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement the `NativeMacADECore` portable settings file-store seam for XDG-first canonical path resolution, missing/decode/write result separation, parent directory bootstrap, atomic JSON saves, and direct filesystem tests for task 02.

## Important Decisions
- Added `PortableSettingsConfigLocator` as the deterministic XDG/home path seam and `PortableSettingsFileStore` as the reusable core IO seam.
- `load()` returns `.missingFile(URL)` for first-run absence and throws typed `readFailed` / `decodeFailed` errors for present but unreadable or invalid content.
- `save(_:)` encodes pretty/sorted JSON, creates the parent directory, writes a hidden temp file in the destination directory, then moves or replaces the canonical file.

## Learnings
- The repo's documented verification gate is `./scripts/run.sh test`, which delegates to `swift test`; focused store unit and integration filters passed before broad verification.
- `./scripts/run.sh test --enable-code-coverage` passed with 355 tests; SwiftPM codecov reports `PortableSettingsFileStore.swift` at 91.6% line coverage and 100% function coverage.

## Files / Surfaces
- `Sources/NativeMacADECore/Workspace/PortableSettingsFileStore.swift`
- `Tests/NativeMacADECoreTests/PortableSettingsFileStoreTests.swift`
- `Tests/NativeMacADEIntegrationTests/PortableSettingsFileStoreIntegrationTests.swift`

## Errors / Corrections

## Ready for Next Run
- Task 02 implementation is ready for downstream service integration; use `PortableSettingsFileStore.canonicalURL`, `load()`, and `save(_:)` rather than adding file IO in command/UI layers.
