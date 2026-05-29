# Task Memory: task_02.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot

- Build Task 02 scope only: pin Ghostty at an explicit upstream revision, introduce the SwiftPM C interop target, replace the unavailable placeholder with a narrow Swift-facing adapter, and add unit/integration tests for launch config, error mapping, app-context singleton, and surface creation/failure behavior.

## Important Decisions

- Use upstream Ghostty commit `cb36966a752982014827a9cabcf630ec3788b3d9` as the explicit pin discovered from `git ls-remote https://github.com/ghostty-org/ghostty.git HEAD` on 2026-05-28.
- Keep the C-facing surface intentionally tiny and app-owned so future upstream `libghostty` API churn is contained behind `NativeMacADECore/Ghostty`.

## Learnings

- Repository has no `AGENTS.md` or `CLAUDE.md` in the workspace; required project guidance comes from the PRD, TechSpec, ADRs, task file, README, and memory files.
- Current SwiftPM scaffold has no `.xcodeproj`; Task 02 must update `Package.swift` rather than `AnotherADE.xcodeproj/project.pbxproj` from the task template.
- A local SwiftPM `CGhostty` C target can validate the adapter seam, typed error mapping, singleton ownership, inherited-surface plumbing, and tests, but it is not sufficient evidence for the task's pinned-real-`libghostty` requirement.

## Files / Surfaces

- Touched surfaces: `Package.swift`, `Sources/CGhostty/*`, `Sources/NativeMacADECore/Ghostty/*`, app DI wiring, terminal host default adapter, core tests, integration tests, and `ThirdParty/Ghostty/GhosttyPin.json`.

## Errors / Corrections

- Oracle review blocked completion because the current `CGhostty` implementation is a local shim, not a real upstream `libghostty` revision or binary artifact linked into the app build.
- Follow-up fix tightened the singleton test, made `CGhosttyRuntime` internal, and reduced public raw-handle leakage, but the real pinned-artifact blocker remains.

## Ready for Next Run

- Verification evidence for the partial adapter seam: `swift test` passed with 13 tests; `swift test --enable-code-coverage` passed with 13 tests and 94.16% line coverage; `swift build` passed; `xcodebuild -scheme NativeMacADE -destination 'platform=macOS' test` passed with app-intents/linkd warnings only.
- Do not mark Task 02 complete or commit until a real pinned `libghostty` artifact/source integration replaces or backs `Sources/CGhostty`.
