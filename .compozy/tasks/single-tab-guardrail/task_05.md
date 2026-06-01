---
status: completed
title: "Gate shell affordances and map blocked-action UX"
type: frontend
complexity: high
dependencies:
  - task_02
  - task_03
  - task_04
---

# Task 05: Gate shell affordances and map blocked-action UX

## Overview
Align the visible shell with Focus Workspace by hiding blocked terminal-tab affordances where possible and presenting calm, feature-specific feedback when command-layer rejections still occur. This task finishes the user-facing behavior across tab chrome, app menus, placeholder surfaces, file-opening flows, and shared `UserMessage` alerts.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The shell MUST hide terminal-tab creation affordances where it can determine they are blocked under Focus Workspace.
- 2. Command-layer focus rejections MUST remain the source of truth, and the shell MUST map them to calm, feature-specific `UserMessage` copy instead of raw error descriptions.
- 3. The tab row MUST remain visible for terminal+file sessions and grandfathered legacy multi-tab sessions, and it SHOULD only collapse or disappear when the selected session has exactly one visible tab.
- 4. Empty-session or first-surface creation paths MUST remain available when Focus Workspace still allows them.
- 5. File-open flows MUST allow first file open and same-file reopen, and MUST alert only for blocked different-file opens once a file tab already exists.
- 6. This task SHOULD avoid adding a new UI test framework in MVP; use targeted automated coverage plus specific manual integration verification.
</requirements>

## Subtasks
- [x] 5.1 Gate tab-bar terminal creation affordances and row-visibility rules against the shared Focus Workspace policy.
- [x] 5.2 Gate app-menu terminal-tab commands and any related shortcut-backed creation affordances.
- [x] 5.3 Align agent-tab palette and placeholder entry points with the same Focus Workspace affordance rules.
- [x] 5.4 Map focus-policy command rejections to calm `UserMessage` alert titles and details.
- [x] 5.5 Preserve allowed first-surface and same-file flows while rejecting blocked different-file opens with clear feedback.
- [x] 5.6 Add focused automated assertions and manual shell verification for menus, alerts, placeholder flows, and tab-row visibility.

## Implementation Details
Use the TechSpec **"Shell/UI behavior"**, **"Known Risks"**, and **"Development Sequencing"** sections as the implementation guide. Keep UI gating secondary to command enforcement, and reuse the shared focus policy/helper rather than duplicating terminal/file count logic in every SwiftUI surface.

### Relevant Files
- `Sources/NativeMacADE/AppShell/ContentView.swift` — primary shell owner of `UserMessage`, tab chrome, agent-tab palette flows, file-open handlers, and placeholder CTAs.
- `Sources/NativeMacADE/NativeMacADEApp.swift` — app menu and keyboard-shortcut-backed terminal-tab affordances live here.
- `Sources/NativeMacADECore/Workspace/FocusWorkspacePolicy.swift` — shared rule set for truthfully hiding or showing affordances.
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — typed focus rejection surface that the shell must map to friendly copy.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — source-of-truth command behavior for terminal/file rejections.
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — selected-session visible tab composition drives tab-row visibility truthfulness.

### Dependent Files
- `Sources/NativeMacADE/AppShell/ConfigModalFocusWorkspaceSection.swift` — user-facing settings and framing from task 04 set the context for shell behavior.
- `Sources/NativeMacADE/AppShell/ConfigModalView.swift` — Settings remains the main discovery path for enabling the mode that this task reacts to.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — automated shell expectations depend on reliable command-level rejection semantics.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — future-after-restore and blocked different-file behavior should already be covered here.
- `Tests/NativeMacADEIntegrationTests/RestoreCoordinatorIntegrationTests.swift` — legacy multi-tab restore truthfulness matters for tab-row visibility behavior.

### Related ADRs
- [ADR-006: Allow one terminal tab plus one optional file tab and hide blocked terminal-tab affordances](../adrs/adr-006.md) — defines the allowed matrix, affordance hiding, and tab-row visibility behavior.
- [ADR-004: Enforce Focus Workspace at the command layer and grandfather existing multi-tab sessions](../adrs/adr-004.md) — keeps command rejections as the truth source and legacy sessions visible.
- [ADR-007: Use a shared pure Focus Workspace policy helper instead of duplicating rules in views and commands](../adrs/adr-007.md) — requires shell gating to consume shared policy outcomes.
- [ADR-003: Broaden MVP through in-product framing before public positioning](../adrs/adr-003.md) — keeps shell behavior aligned with in-product discoverability and clarity goals.

## Deliverables
- Focus-aware tab chrome and app-menu affordance gating that hides blocked terminal-tab creation where possible.
- Calm `UserMessage` alerts for focus-policy blocked terminal/file actions.
- Truthful tab-row visibility behavior for single-tab, terminal+file, and legacy multi-tab sessions.
- Specific manual integration verification guidance for shell surfaces that lack direct UI automation.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for shell gating, blocked alerts, file-open exceptions, and legacy-session visibility **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Focus-policy error mapping returns a specific title/detail pair for blocked terminal-tab creation.
  - [x] Focus-policy error mapping returns a specific title/detail pair for blocked second different-file opens.
  - [x] Tab-row visibility logic hides the row only when the selected session has exactly one visible tab under Focus Workspace.
- Integration tests:
  - [x] With Focus Workspace enabled and one terminal tab, the tab-bar plus affordance and app-menu terminal-tab creation actions are hidden.
  - [x] With Focus Workspace enabled and an empty or first-surface state, allowed placeholder and first-tab actions remain available.
  - [x] With Focus Workspace enabled and a terminal+file session, the tab row remains visible for navigation while blocked terminal-tab creation affordances stay hidden.
  - [x] With Focus Workspace enabled, a blocked different-file open from both the file tree and search surfaces shows calm Focus Workspace alert copy.
  - [x] A restored legacy multi-tab session remains visible and navigable, and a new blocked terminal-tab attempt shows the friendly Focus Workspace alert.
- Test coverage target: >=80%
- All tests must pass

## Verification Evidence
- `swift test --filter FocusWorkspace` passed 26 focused tests.
- `swift test --enable-code-coverage` passed the full suite: 299 tests, 0 failures.
- `xcrun llvm-cov report .build/arm64-apple-macosx/debug/NativeMacADEPackageTests.xctest/Contents/MacOS/NativeMacADEPackageTests -instr-profile .build/arm64-apple-macosx/debug/codecov/default.profdata -ignore-filename-regex='(^|/)\\.build/|(^|/)Tests/'` reported 82.90% region coverage and 89.73% line coverage.

## Manual Shell Verification
- Enable Focus Workspace, select an empty session, and confirm the first-tab placeholder CTAs plus app-menu terminal commands remain available.
- In a one-terminal session, confirm the tab row is visually collapsed, tab/menu terminal creation affordances are hidden, and any direct blocked agent/tab action shows the Focus Workspace terminal message.
- In a terminal+file session, confirm the tab row remains visible for navigation while terminal creation affordances stay hidden.
- Reopen the same file and confirm the existing file tab is selected; open a different file from both the file tree and search results and confirm the Focus Workspace file-slot message appears.
- Restore or seed a legacy multi-tab session, confirm all existing tabs remain visible and navigable, then attempt a new terminal tab and confirm the friendly Focus Workspace message appears.

## Success Criteria
- All tests passing
- Test coverage >=80%
- Users do not see blocked terminal-tab creation affordances where the shell can determine they are disallowed.
- Blocked terminal/file actions show calm, feature-specific alert copy while preserving truthful navigation for allowed terminal+file and legacy multi-tab sessions.
