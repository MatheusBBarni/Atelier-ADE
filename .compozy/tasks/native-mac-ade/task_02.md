---
status: completed
title: "Pin Ghostty and build the adapter boundary"
type: infra
complexity: high
dependencies:
    - task_01
---

# Task 02: Pin Ghostty and build the adapter boundary

## Overview
Add the pinned Ghostty dependency and isolate it behind a narrow app-owned adapter boundary. This task gives the product direct control over terminal surfaces while containing upstream API churn to a small integration layer.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. MUST pin one explicit `libghostty` revision or binary artifact into the macOS app build.
- 2. MUST expose only the minimal V1 adapter surface for initialization, terminal surface creation, inherited tab creation, launch config, resize/focus hooks, and close/exit queries.
- 3. MUST keep raw Ghostty C interop isolated from the rest of the app behind Swift-facing adapter types.
- 4. MUST enforce one Ghostty app context per process and main-actor ownership for terminal surface lifecycle.
- 5. SHOULD provide integration coverage that verifies initialization and per-tab surface creation against the pinned Ghostty revision.
</requirements>

## Subtasks
- [ ] 2.1 Add the pinned Ghostty dependency or vendored artifact to the macOS build.
- [ ] 2.2 Create the app-local interop boundary for the `libghostty` C API.
- [ ] 2.3 Implement the narrow Swift-facing Ghostty adapter contract required by the TechSpec.
- [ ] 2.4 Wire typed adapter errors and lifecycle callbacks needed by later terminal host and command-service work.
- [ ] 2.5 Add focused integration coverage for initialization and single-surface creation behavior.

## Implementation Details
Follow TechSpec "System Architecture > Component Overview" for the Ghostty Adapter and TechSpec "Integration Points" for the external Ghostty boundary. Keep the adapter minimal as required by ADR-004 and do not let persistence, restore, or feature UI code depend on raw Ghostty symbols.

### Relevant Files
- `AnotherADE.xcodeproj/project.pbxproj` — Links the pinned Ghostty artifact into the app and test targets.
- `AnotherADE/Terminal/Ghostty/CGhostty.modulemap` — Isolates the raw C interop boundary.
- `AnotherADE/Terminal/Ghostty/GhosttyAdapter.swift` — Swift-facing adapter used by terminal host and command services.
- `AnotherADE/Terminal/Ghostty/GhosttyLaunchConfig.swift` — Encodes working directory and shortcut-driven launch intent.
- `AnotherADE/Terminal/Ghostty/GhosttyError.swift` — Typed error surface for init and terminal creation failures.
- `AnotherADEIntegrationTests/GhosttyAdapterIntegrationTests.swift` — Verifies pinned Ghostty initialization and per-tab surface creation.

### Dependent Files
- `AnotherADE/Terminal/Host/TerminalHostController.swift` — Task 06 will consume the adapter to attach one surface per visible tab.
- `AnotherADE/Services/DefaultWorkspaceCommandService.swift` — Task 04 will use adapter entry points for tab creation and close behavior.
- `AnotherADE/Restore/RestoreCoordinator.swift` — Task 07 will rely on adapter launch-config behavior when reconstructing fresh shells.
- `AnotherADE/Support/Observability/WorkspaceLogger.swift` — Task 08 will log adapter failures and surface initialization metrics.

### Related ADRs
- [ADR-004: Embed Full libghostty Surfaces Inside the App](adrs/adr-004.md) — Primary decision that this task implements.
- [ADR-003: Use a SwiftUI App Shell with AppKit Terminal Hosting](adrs/adr-003.md) — Constrains the host environment around the adapter.
- [ADR-005: Persist Metadata-Only State and Restore Fresh Shells](adrs/adr-005.md) — Keeps the adapter focused on fresh-shell creation, not live-shell persistence.

## Deliverables
- Ghostty dependency pinned and linked into the macOS app scaffold.
- A narrow app-owned Ghostty adapter and launch-config boundary.
- Typed Ghostty integration errors and lifecycle callbacks required by V1.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for Ghostty initialization and surface creation **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Launch config built from a working directory and optional command produces the expected adapter request.
  - [ ] Adapter error mapping converts Ghostty init and surface failures into typed app errors.
  - [ ] Inherited-tab configuration preserves parent context metadata for a new tab request.
- Integration tests:
  - [ ] Adapter initializes one Ghostty app context successfully on process startup.
  - [ ] Creating a single terminal surface for a tab succeeds with the pinned Ghostty revision.
  - [ ] Surface creation failure returns a user-visible adapter error without crashing the app process.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The app links to a pinned Ghostty revision through a small, app-owned adapter boundary.
- Later terminal host and command-service work can use the adapter without depending on raw Ghostty C APIs.
