# Task Memory: task_06.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Remove the remaining SwiftTerm SwiftPM dependency/resolution now that tasks 04-05 established the Ghostty-only host and workspace lifecycle path.
- Capture release-gate evidence for Ghostty-only build/test behavior, telemetry visibility, and the manual terminal correctness baseline.

## Important Decisions
- No conflict found between task_06, the TechSpec, and ADRs 001-007. The accepted direction is Ghostty-only terminal hosting with no SwiftTerm fallback or terminal-engine selector.
- `AGENTS.md` and `CLAUDE.md` were not present under `/Users/matheusbbarni/projects/another-ade`; PRD docs and ADRs are the available repo/task guidance for this run.

## Learnings
- Pre-change `rg "SwiftTerm|LocalProcessTerminalView|TerminalSessionDriver" Package.swift Package.resolved Sources Tests` only found SwiftTerm in `Package.swift` and `Package.resolved`; no production/test Swift source still references the old symbols.
- After removal, the same symbol search returns no matches across `Package.swift`, `Package.resolved`, `Sources`, and `Tests`.
- `swift build` passes without SwiftTerm linked, and focused Ghostty/terminal/workspace/scaffold tests passed 108 tests in 6 suites.
- Full `swift test --enable-code-coverage` passed 416 tests in 39 suites. Whole-package coverage is 47.43% lines because SwiftUI app-shell files are mostly untested; task-surface coverage for `GhosttyKit` plus `NativeMacADECore` is 91.55% lines and 85.23% regions when excluding `Sources/NativeMacADE` UI.
- Manual baseline execution is blocked in this environment: fresh `Atelier.app` from `./scripts/run.sh bundle` launches as `com.matheusbbarni.Atelier`, but Accessibility/System Events report zero windows and logs show invalid AppKit geometry.

## Files / Surfaces
- Touched: `Package.swift`, `Package.resolved`, `.compozy/tasks/ghostty-terminal-engine/manual-baseline-qa-task-06.md`, workflow memory.

## Errors / Corrections
- Attempted raw executable launch and supported bundle launch for manual QA. Raw executable and rebuilt `Atelier.app` both started a process but exposed no window; relaunching with `-ApplePersistenceIgnoreState YES` did not resolve it.

## Ready for Next Run
- Do not mark task 06 complete until manual terminal correctness baseline is executed against a visible Atelier window and embedded Ghostty surface.
- If the windowless launch reproduces outside automation, investigate the AppKit/SwiftUI invalid geometry startup issue before rerunning manual baseline QA.
