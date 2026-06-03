# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State
- Task 01 added `GhosttyKit` as the Swift wrapper target above `CGhostty`; `NativeMacADECore` now depends on `GhosttyKit` rather than `CGhostty` directly.
- Task 02 routed `LiveGhosttyAdapter` through `GhosttySurfaceRuntime`, exposed `GhosttyAdapter.nativeView(for:)`, and changed the live adapter to `usesEmbeddedSessionDriver == false`.
- Task 03 extracted launch translation into `TerminalLaunchTranslator`; `TerminalSessionDriver` and `GhosttyLaunchConfiguration(tab:)` now share that path for shell args, command args, and environment.
- Task 04 removed the SwiftTerm session-driver branch from `TerminalHostController`; terminal host creation now requires an adapter-provided Ghostty native view and delegates focus, resize, close, exit, and destroy behavior through `GhosttyAdapter`.
- Task 05 hardened workspace lifecycle, restore, close/release, exit fan-out, terminal failure diagnostics, and file-tab isolation with focused tests only; no production behavior changes were needed.

## Shared Decisions
- Ghostty value types and the low-level `CGhosttyRuntime` Swift bridge live in `GhosttyKit`; `NativeMacADECore` keeps workspace-specific extensions and type aliases for compatibility.
- `GhosttyLaunchConfiguration` now carries runtime-only environment data. This does not change persisted `WorkspaceTab` fields.

## Shared Learnings

## Open Risks
- Task 06 removed `SwiftTerm` from SwiftPM state, but the manual GUI baseline is not yet complete.
- Manual GUI QA from automation is currently blocked: `scripts/run.sh bundle` produces `Atelier.app`, but launching it on this machine exposed no Accessibility/System Events windows and AppKit logged invalid geometry (`x/y is infinity`).

## Handoffs
- Task 04 should consume launch metadata via `GhosttyLaunchConfiguration(tab:)` or `TerminalLaunchTranslator`; avoid reimplementing raw launch-command/argument decoding because Codex/Claude additions and env overrides live in the translator.
- Task 05 should assume `TerminalHostController` is Ghostty-only and verify workspace lifecycle/restore/exit telemetry without reintroducing a SwiftTerm fallback.
- Task 06 should keep the Ghostty-only host assumption from tasks 04-05 while removing leftover SwiftTerm dependency/scaffolding.
