---
status: pending
title: "Extract launch metadata translation from the SwiftTerm driver"
type: refactor
complexity: medium
dependencies: []
---

# Task 03: Extract launch metadata translation from the SwiftTerm driver

## Overview
This task separates terminal launch behavior from `TerminalSessionDriver` so the Ghostty migration can preserve existing shell and agent starts. It creates a reusable launch translation seam before the SwiftTerm-specific driver is removed.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST extract launch command, argument, and environment translation out of `TerminalSessionDriver`.
2. MUST preserve current plain shell, Codex, Claude, and stored launch-argument behavior.
3. MUST preserve shell escaping behavior currently covered by `TerminalLaunchCommandBuilder` tests.
4. MUST avoid changing persisted `WorkspaceTab` fields or adding terminal engine metadata.
5. MUST make launch translation usable by Ghostty launch configuration in later tasks.
</requirements>

## Subtasks
- [ ] 3.1 Identify all launch behavior currently embedded in `TerminalSessionDriver`.
- [ ] 3.2 Move launch translation into a Swift type independent of SwiftTerm.
- [ ] 3.3 Preserve command escaping and agent-specific argument/environment behavior.
- [ ] 3.4 Update tests so launch behavior is covered without a SwiftTerm terminal view.
- [ ] 3.5 Keep `GhosttyLaunchConfiguration` compatible with existing workspace tab metadata.

## Implementation Details
Use the TechSpec "Data Models" and "Development Sequencing" sections for the desired launch payload shape. This task should not host Ghostty views; it only preserves launch metadata behavior so task 04 can consume it.

### Relevant Files
- `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift` — Contains `TerminalSessionDriver`, launch argument construction, environment overrides, and `TerminalLaunchCommandBuilder`.
- `Sources/NativeMacADECore/Ghostty/GhosttyAdapter.swift` — Defines `GhosttyLaunchConfiguration` and argument decoding.
- `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift` — Defines `WorkspaceTab` launch metadata fields.
- `Tests/NativeMacADEIntegrationTests/TerminalHostIntegrationTests.swift` — Contains current launch-command builder tests tied to the terminal host file.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — Verifies launch metadata mappings for session shortcuts.

### Dependent Files
- `Sources/NativeMacADECore/Ghostty/GhosttyAdapter.swift` — Will receive translated launch payloads when the adapter path is updated.
- `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift` — Task 04 will remove the SwiftTerm driver after this behavior is extracted.
- `Tests/NativeMacADECoreTests/GhosttyAdapterTests.swift` — May need launch configuration coverage updates.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Agent launch and tab creation flows depend on stable launch metadata.

### Related ADRs
- [ADR-006: Preserve existing launch metadata and translate it into Ghostty launch configuration](adrs/adr-006.md) — Defines the launch metadata preservation strategy.
- [ADR-004: Remove SwiftTerm after Ghostty covers the MVP terminal baseline](adrs/adr-004.md) — Requires launch behavior to survive removal of `TerminalSessionDriver`.
- [ADR-007: Validate Ghostty migration with manual baseline QA and focused runtime unit tests](adrs/adr-007.md) — Requires unit coverage for launch configuration.

## Deliverables
- Launch translation type independent of SwiftTerm and `TerminalSessionDriver`.
- Preserved Codex, Claude, plain shell, stored command, argument, and environment behavior.
- Updated launch translation tests that do not require `LocalProcessTerminalView`.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for session shortcut launch metadata preservation **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Plain shell tab produces a launch payload with the selected working directory and no agent command.
  - [ ] Codex launch translation preserves stored arguments and current Codex-specific additions.
  - [ ] Claude launch translation preserves stored arguments and current Claude-specific additions.
  - [ ] Command escaping preserves arguments containing spaces, quotes, and `$HOME`.
  - [ ] Invalid or empty launch argument JSON still decodes to an empty argument list.
- Integration tests:
  - [ ] Creating a session with a built-in agent shortcut persists the same launch command and arguments as before.
  - [ ] Creating an additional agent tab reuses stored session shortcut launch metadata.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Launch behavior is testable without SwiftTerm.
- Ghostty launch configuration can consume the preserved workspace launch metadata.
