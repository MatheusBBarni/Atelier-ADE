# Task 06 Manual Correctness Baseline QA

Date: 2026-06-02
Build: `.build/arm64-apple-macosx/debug/Atelier.app` from `./scripts/run.sh bundle`
Result: Blocked

## Summary

SwiftTerm removal and Ghostty-only automated checks passed, but the interactive manual terminal baseline could not be executed in this automation session because the supported local `Atelier.app` launch did not create an accessible macOS window.

This file records the attempted manual QA evidence. It does not certify the manual correctness baseline as passed.

## Environment Evidence

- `./scripts/run.sh bundle` rebuilt and signed `.build/arm64-apple-macosx/debug/Atelier.app` successfully.
- `open -n .build/arm64-apple-macosx/debug/Atelier.app --args -ApplePersistenceIgnoreState YES` launched process `NativeMacADE`.
- `orca computer list-apps --json` saw `Atelier` with bundle id `com.matheusbbarni.Atelier`.
- `orca computer get-app-state --app com.matheusbbarni.Atelier --json --no-screenshot --restore-window` failed with `window_not_found`.
- `osascript -e 'tell application "System Events" to tell process "Atelier" to get {frontmost, visible, count of windows, name of windows}'` returned `false, true, 0,`.
- Recent `/usr/bin/log show --predicate 'process == "NativeMacADE"'` output included `No windows open yet` and repeated AppKit runtime issues: `Invalid view geometry: x is infinity`, `Invalid view geometry: y is infinity`.
- Orca desktop automation had Accessibility permission, but Screen Recording was not granted. The blocking signal was window absence from Accessibility and System Events, not screenshot capture alone.

## Automated Baseline Evidence Available

- `rg -n "SwiftTerm|LocalProcessTerminalView|TerminalSessionDriver" Package.swift Package.resolved Sources Tests` returned no matches after dependency removal.
- `swift build` completed successfully without SwiftTerm linked.
- `swift test --filter 'GhosttyAdapterTests|TerminalLaunchTranslatorTests|PerformanceMetricsTests|TerminalHostIntegrationTests|DefaultWorkspaceCommandServiceIntegrationTests|ScaffoldIntegrationTests'` passed 108 tests in 6 suites.
- `swift test --enable-code-coverage` passed 416 tests in 39 suites.
- Target-scoped coverage for `GhosttyKit` plus `NativeMacADECore`, excluding `Sources/NativeMacADE` app-shell UI and tests, was 91.55% line coverage and 85.23% region coverage.
- Whole-package SwiftPM coverage JSON reported 47.43% line coverage because the SwiftUI app-shell target is largely not covered by unit tests.

## Manual Workflow Matrix

| Workflow | Status | Evidence |
|---|---|---|
| vim-style TUI | Blocked | No Atelier window or terminal surface available to interact with. |
| htop-style TUI | Blocked | No Atelier window or terminal surface available to interact with. |
| tmux-style workflow | Blocked | No Atelier window or terminal surface available to interact with. |
| agent CLI | Blocked | No Atelier window or terminal surface available to interact with. |
| shell prompt/input | Blocked | No Atelier window or terminal surface available to interact with. |
| resize | Blocked | No Atelier window or terminal surface available to interact with. |
| copy/paste | Blocked | No Atelier window or terminal surface available to interact with. |
| colors | Blocked | No Atelier window or terminal surface available to inspect. |
| Unicode | Blocked | No Atelier window or terminal surface available to inspect. |
| ligatures | Blocked | No Atelier window or terminal surface available to inspect. |
| alternate screen | Blocked | No Atelier window or terminal surface available to interact with. |
| long build output | Blocked | No Atelier window or terminal surface available to interact with. |
| logs | Blocked | App logs were inspected, but terminal workload log behavior could not be exercised. |
| streaming agent output | Blocked | No Atelier window or terminal surface available to interact with. |

## Follow-Up Required

Before task 06 can be marked complete, rerun the manual baseline in an environment where `Atelier.app` creates a visible window and the embedded Ghostty terminal surface is available. If the windowless launch reproduces outside automation, fix the AppKit/SwiftUI startup geometry issue first, then rerun this checklist.

## 2026-06-03 Follow-Up Evidence

Result: Still not certified as complete.

- `swift test --filter 'GhosttySurfaceRuntimeTests|TerminalHostControllerTests|TerminalHostIntegrationTests'` passed 33 tests in 3 suites.
- `swift test` passed 446 tests in 41 suites.
- `./scripts/run.sh bundle` rebuilt and signed `.build/arm64-apple-macosx/debug/Atelier.app` successfully.
- `open -n .build/arm64-apple-macosx/debug/Atelier.app --args -ApplePersistenceIgnoreState YES` launched process `NativeMacADE`.
- `osascript -e 'tell application "System Events" to tell process "Atelier" to get {frontmost, visible, count of windows, name of windows}'` returned `true, true, 1, Atelier`.
- Recent `/usr/bin/log show --predicate 'process == "NativeMacADE"' --last 2m` did not include the prior `Invalid view geometry: x is infinity` or `Invalid view geometry: y is infinity` AppKit messages.
- Window screenshot capture remains unavailable in this automation session: `screencapture -x -l <Atelier window id>` returned `could not create image from window`.
- The wrapper runtime now returns a visible diagnostic AppKit surface instead of a blank `NSView`; this is covered by `GhosttySurfaceRuntimeTests.surfaceCreationPreservesLaunchAndAppearancePayloads`.

The manual correctness baseline remains pending because `ThirdParty/Ghostty/GhosttyPin.json` still points to a pinned source revision and notes that `CGhostty` must be replaced with direct calls into a matching vendored `libghostty` binary artifact when available. This follow-up fixes the silent blank/windowless failure path, but it does not certify real interactive Ghostty terminal behavior for vim-style TUIs, htop-style TUIs, tmux-style workflows, shell input, copy/paste, rendering fidelity, heavy output, or streaming agent output.
