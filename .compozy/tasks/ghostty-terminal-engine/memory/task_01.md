# Task Memory: task_01.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement Task 01 only: add a Swift-native Ghostty wrapper target above `CGhostty`, expose the minimal terminal-hosting runtime API, keep `CGhostty` as the low-level interop/pinned-revision scaffold, and add focused wrapper tests plus SwiftPM wiring verification.

## Important Decisions
- Use `GhosttyKit` as the new Swift wrapper target name unless implementation evidence shows an existing naming convention conflict.
- Keep wrapper-owned value types in `GhosttyKit` and provide `NativeMacADECore` type aliases plus workspace-specific extensions so existing core call sites avoid broad import churn.
- Keep `LiveGhosttyAdapter.usesEmbeddedSessionDriver == true` for Task 01 scope; later tasks will route host UI through wrapper-native views.

## Learnings
- No repo-root `AGENTS.md` or `CLAUDE.md` exists in `/Users/matheusbbarni/projects/another-ade`; required guidance files were searched and missing before implementation.
- Pre-change signal: `swift build --target GhosttyKit` fails with `error: no target named 'GhosttyKit'`, confirming the wrapper target is not present.
- `GhosttyKit` builds as a SwiftPM target after adding it above `CGhostty`; `NativeMacADECore` needed an explicit `import GhosttyKit` only in `TerminalHostController` for wrapper static members used in default arguments.
- Focused Ghostty verification passed with `./scripts/run.sh test --filter Ghostty`: 18 Swift Testing tests across wrapper, adapter, scaffold, command-service, and terminal-host suites.
- Final verification before tracking updates: `swift build --target CGhostty --target GhosttyKit --target NativeMacADECore`, `./scripts/run.sh test --enable-code-coverage`, `xcrun llvm-cov report ... Sources/GhosttyKit`, `./scripts/run.sh build`, and `git diff --check` all passed.
- Coverage evidence: `Sources/GhosttyKit` reports 89.41% region coverage and 98.18% line coverage after the full coverage run.

## Files / Surfaces
- Planned surfaces: `Package.swift`, new `Sources/GhosttyKit`, wrapper-focused tests, and existing Ghostty adapter/scaffold tests as needed for compatibility.
- Touched so far: `Package.swift`, `Sources/GhosttyKit/*`, `Sources/NativeMacADECore/Ghostty/*`, `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift`, `Tests/GhosttyKitTests/GhosttySurfaceRuntimeTests.swift`, `Tests/NativeMacADECoreTests/GhosttyAdapterTests.swift`, and `Tests/NativeMacADEIntegrationTests/ScaffoldIntegrationTests.swift`.

## Errors / Corrections
- Corrected the first `NativeMacADECore` build failure by importing `GhosttyKit` in `TerminalHostController`; Swift required the explicit import for `.cursorDefault` in a default argument.

## Ready for Next Run
- Task 01 implementation and verification are complete. Tracking files still need status updates and the code changes need a scoped local commit.
