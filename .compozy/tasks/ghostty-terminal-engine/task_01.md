---
status: completed
title: "Add Swift Ghostty wrapper target"
type: infra
complexity: high
dependencies: []
---

# Task 01: Add Swift Ghostty wrapper target

## Overview
This task creates the Swift-native Ghostty wrapper target selected in the TechSpec. It establishes the app-facing runtime boundary that will later let `TerminalHostController` host Ghostty surfaces without reaching directly into C interop details.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST add a SwiftPM target for the Swift-native Ghostty wrapper and wire it to the existing `CGhostty` interop target.
2. MUST expose a minimal app-facing Ghostty runtime API aligned with the TechSpec "Core Interfaces" section.
3. MUST keep `CGhostty` as low-level interop scaffolding and pinned-revision metadata, not replace it.
4. MUST avoid adding Ghostty config parity, pane APIs, or cmux-style workflow APIs in this MVP wrapper.
5. MUST include focused tests that prove the wrapper can initialize, report the pinned revision, create a test surface, and map initialization or surface errors.
</requirements>

## Subtasks
- [x] 1.1 Add the Swift wrapper target and package dependency wiring.
- [x] 1.2 Define the minimal wrapper runtime surface needed by the TechSpec.
- [x] 1.3 Bridge wrapper calls to the existing `CGhostty` scaffolding.
- [x] 1.4 Preserve pinned revision and typed error behavior through the wrapper.
- [x] 1.5 Add tests for wrapper initialization, surface creation, and failure mapping.

## Implementation Details
Create the wrapper in a new SwiftPM target and keep it scoped to terminal hosting primitives. Reference the TechSpec "System Architecture" and "Core Interfaces" sections for the intended boundary, and reference ADR-005 for why `CGhostty` remains underneath the Swift wrapper.

### Relevant Files
- `Package.swift` — Declares the current `CGhostty` and `NativeMacADECore` targets and must add the wrapper target wiring.
- `Sources/CGhostty/include/CGhostty.h` — Existing C ABI scaffold and pinned revision surface.
- `Sources/CGhostty/CGhostty.c` — Current stub implementation used by tests and the wrapper bridge.
- `Sources/NativeMacADECore/Ghostty/CGhosttyRuntime.swift` — Existing Swift runtime wrapper that should inform or move into the new wrapper boundary.
- `Sources/NativeMacADECore/Ghostty/GhosttyAdapter.swift` — Existing adapter contracts that the wrapper must support later.
- `ThirdParty/Ghostty/GhosttyPin.json` — Documents the pinned upstream Ghostty source revision and integration target.

### Dependent Files
- `Sources/NativeMacADECore/Ghostty/GhosttyAdapter.swift` — Will depend on the wrapper target in task 02.
- `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift` — Will consume native view and lifecycle behavior after task 04.
- `Tests/NativeMacADECoreTests/GhosttyAdapterTests.swift` — Existing Ghostty runtime expectations should remain compatible or move to wrapper-focused tests.
- `Tests/NativeMacADEIntegrationTests/ScaffoldIntegrationTests.swift` — Contains pinned-revision and live-adapter checks that may need updated target references.

### Related ADRs
- [ADR-005: Add a Swift-native Ghostty wrapper target and keep CGhostty as native interop scaffolding](adrs/adr-005.md) — Defines the native boundary shape for this task.
- [ADR-007: Validate Ghostty migration with manual baseline QA and focused runtime unit tests](adrs/adr-007.md) — Requires focused runtime unit coverage for the wrapper.

## Deliverables
- New SwiftPM wrapper target for app-facing Ghostty runtime behavior.
- Minimal wrapper API for initialization, surface creation, native view access placeholder, lifecycle, and error mapping.
- Tests proving wrapper initialization, pinned revision access, surface creation, and failure mapping.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for wrapper target wiring through SwiftPM **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Wrapper initialization returns one shared app context for repeated initialization calls.
  - [x] Wrapper exposes the pinned Ghostty revision from `CGhostty`.
  - [x] Wrapper surface creation preserves working directory, command, arguments, and appearance payloads.
  - [x] Forced initialization failure maps to the existing user-visible Ghostty error type.
  - [x] Forced surface creation failure maps to the existing user-visible Ghostty error type.
- Integration tests:
  - [x] SwiftPM builds `CGhostty`, the new wrapper target, and `NativeMacADECore` together.
  - [x] Existing scaffold tests can still assert the pinned Ghostty revision through the app dependency graph.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The Swift wrapper target builds and isolates app-facing Ghostty runtime behavior from C interop.
- No Ghostty config parity, pane, or cmux-style workflow surface is introduced.
