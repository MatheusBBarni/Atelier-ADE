---
status: completed
title: "Remove SwiftTerm and complete correctness baseline evidence"
type: chore
complexity: high
dependencies:
    - task_04
    - task_05
---

# Task 06: Remove SwiftTerm and complete correctness baseline evidence

## Overview
This task finishes the migration by removing SwiftTerm from production and capturing the manual correctness baseline evidence required by the PRD and TechSpec. It ensures the repo no longer carries the old terminal runtime after the Ghostty path is verified.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST remove the SwiftTerm package dependency after Ghostty host and workspace lifecycle tests pass.
2. MUST delete or replace SwiftTerm-specific code, imports, types, and test assertions.
3. MUST verify no production path retains `LocalProcessTerminalView` or `TerminalSessionDriver`.
4. MUST document manual baseline QA evidence for interactive TUIs, shell behavior, rendering fidelity, and heavy output.
5. MUST keep terminal surface failure telemetry and launch-to-ready metrics available after dependency removal.
</requirements>

## Subtasks
- [x] 6.1 Remove SwiftTerm from SwiftPM dependency declarations and resolved package state.
- [x] 6.2 Delete or replace remaining SwiftTerm-specific host code and tests.
- [x] 6.3 Verify the project builds without SwiftTerm imports or symbols.
- [x] 6.4 Run the full automated test suite relevant to terminal, restore, workspace, and app scaffolding.
- [ ] 6.5 Execute and record manual correctness baseline QA evidence.
- [x] 6.6 Confirm terminal metrics and logs remain visible after the removal.

## Execution Notes

- Automated removal/build/test evidence is recorded in `.compozy/tasks/ghostty-terminal-engine/manual-baseline-qa-task-06.md`.
- Manual correctness baseline execution is blocked because the rebuilt `Atelier.app` launches without an Accessibility/System Events window in this environment. Keep `status: pending` until the manual baseline can run against a visible embedded Ghostty terminal surface.

## Implementation Details
Reference TechSpec "Development Sequencing", "Testing Approach", and "Monitoring and Observability". Keep this as the final cleanup and release-gate task; do not remove SwiftTerm before task 04 and task 05 have established the Ghostty path.

### Relevant Files
- `Package.swift` — Remove the SwiftTerm package dependency and product dependency.
- `Package.resolved` — Remove stale SwiftTerm resolution entries if no longer needed.
- `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift` — Must no longer import SwiftTerm or define SwiftTerm-specific driver/view state.
- `Tests/NativeMacADEIntegrationTests/TerminalHostIntegrationTests.swift` — Must no longer assert SwiftTerm live behavior.
- `Tests/NativeMacADEIntegrationTests/ScaffoldIntegrationTests.swift` — Must no longer expect embedded surfaces that bypass Ghostty runtime.
- `.compozy/tasks/ghostty-terminal-engine/_techspec.md` — Defines the manual correctness baseline evidence expected before completion.

### Dependent Files
- `Sources/NativeMacADECore/App/AppDependencyContainer.swift` — Live dependency graph must still build and publish terminal exits.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Terminal host UI must still compile and present terminal unavailable errors.
- `Tests/NativeMacADECoreTests/GhosttyAdapterTests.swift` — Runtime and launch tests must cover behavior formerly masked by SwiftTerm.
- `Tests/NativeMacADECoreTests/PerformanceMetricsTests.swift` — Release-blocking diagnostics must remain stable.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Workspace create/restore/close flows must still pass after removal.
- `ThirdParty/Ghostty/GhosttyPin.json` — Ghostty pin remains the terminal runtime reference after SwiftTerm removal.

### Related ADRs
- [ADR-002: Define MVP terminal correctness baseline across common power-user workflows](adrs/adr-002.md) — Defines the baseline that must be evidenced.
- [ADR-004: Remove SwiftTerm after Ghostty covers the MVP terminal baseline](adrs/adr-004.md) — Authorizes dependency removal after coverage is complete.
- [ADR-007: Validate Ghostty migration with manual baseline QA and focused runtime unit tests](adrs/adr-007.md) — Defines the validation mix for this final task.

## Deliverables
- SwiftTerm removed from package dependencies and production code.
- SwiftTerm-specific tests deleted or replaced by Ghostty-focused assertions.
- Manual baseline QA evidence recorded for interactive TUIs, shell behavior, rendering fidelity, and heavy output.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Ghostty-only terminal runtime and workspace flows **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `rg "SwiftTerm|LocalProcessTerminalView|TerminalSessionDriver"` returns no production Swift references.
  - [ ] Ghostty adapter and launch translation unit tests still pass without SwiftTerm linked.
  - [ ] Performance metrics tests still report terminal surface failure thresholds correctly.
- Integration tests:
  - [ ] Full terminal host integration tests pass with Ghostty-only hosting.
  - [ ] Default workspace command service integration tests pass for create, restore, close, and terminal failure flows.
  - [ ] Scaffold integration tests pass for live dependency graph and terminal exit fan-out.
  - [ ] Manual QA records pass/fail evidence for vim-style TUI, htop-style TUI, tmux-style workflow, agent CLI, shell prompt/input, resize, copy/paste, colors, Unicode, ligatures, alternate screen, long build output, logs, and streaming agent output.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- SwiftTerm is absent from production dependencies and code.
- Manual correctness baseline evidence is complete and shows no known regression versus current Atelier terminal behavior.
