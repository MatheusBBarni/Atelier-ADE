# Task Memory: task_01.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Define the additive `NativeMacADECore` portable settings contract for task 01: versioned DTOs, apply-result diagnostics, managed keybinding override shape, and built-in default-profile symbols. Do not implement file IO, projection, service orchestration, or UI in this task.

## Important Decisions
- PRD, TechSpec, and ADRs are aligned: V1 uses a stable external schema, omits raw runtime/persistence details, and limits default-profile portability to built-ins plus `plain`.
- Added the schema as an additive core DTO layer only; file IO, runtime projection, command-service reload/export APIs, and UI remain later-task scope.
- Centralized built-in catalog lookup through `SessionShortcut.canonicalBuiltInShortcut(...)` and portable symbols through `PortableDefaultProfileIdentifier`; `DefaultWorkspaceCommandService` now uses the shared helper instead of a private duplicate.

## Learnings
- `AGENTS.md` and `CLAUDE.md` are not present in this checkout as of the initial repo-root scan.
- Foundation `JSONEncoder` does not provide stable top-level object key ordering here, even with manual keyed-container encode calls; tests should assert semantic section presence and array order instead of object key order.
- Coverage evidence from `./scripts/run.sh test --enable-code-coverage`: `PortableSettingsConfig.swift` reported 90.16% line coverage and 92.11% function coverage.

## Files / Surfaces
- Planned source seam: `Sources/NativeMacADECore/Workspace/PortableSettingsConfig.swift`.
- Planned validation seams: built-in `SessionShortcut` catalog, managed command registry IDs, and existing default-profile service tests.
- Added `Tests/NativeMacADECoreTests/PortableSettingsConfigTests.swift` for DTO/schema coverage.
- Extended `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` with portable built-in/default-profile runtime mapping coverage.
- Modified `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` only to consume the shared built-in helper.

## Errors / Corrections
- Initial DTO test incorrectly assumed top-level JSON object key order would be stable. Corrected the test to check section presence and keybinding array order, which matches JSON semantics and task intent.

## Ready for Next Run
- Full coverage-enabled test suite passed after implementation: 347 tests in 33 suites via `./scripts/run.sh test --enable-code-coverage`.
- Local implementation commit created: `24edaf9 feat: add portable settings schema`. Task tracking and workflow memory changes were intentionally left unstaged/out of that commit per the task rule.
