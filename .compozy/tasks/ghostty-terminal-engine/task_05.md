---
status: pending
title: "Preserve workspace lifecycle, restore, and exit telemetry on the Ghostty path"
type: backend
complexity: high
dependencies:
  - task_04
---

# Task 05: Preserve workspace lifecycle, restore, and exit telemetry on the Ghostty path

## Overview
This task hardens the Ghostty terminal path against the workspace flows users already rely on. It verifies that session creation, tab creation, restore, close handling, exit events, diagnostics, and telemetry remain stable after the terminal host migration.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST preserve `DefaultWorkspaceCommandService` terminal surface creation behavior for new sessions and new tabs.
2. MUST preserve restore behavior for terminal tabs without changing persisted workspace metadata.
3. MUST preserve close checks, surface release, and terminal exit event publishing.
4. MUST preserve existing telemetry event names and release-blocking diagnostics for terminal failures.
5. MUST keep file tab behavior isolated from terminal surface creation.
</requirements>

## Subtasks
- [ ] 5.1 Verify new session and tab creation still create Ghostty terminal surfaces.
- [ ] 5.2 Verify restore recreates Ghostty surfaces for restored terminal tabs.
- [ ] 5.3 Verify close checks and release paths use Ghostty runtime state.
- [ ] 5.4 Verify terminal exit callbacks publish through `TerminalExitEventSource`.
- [ ] 5.5 Verify terminal failure metrics and logs retain existing names and fields.
- [ ] 5.6 Verify file tabs remain isolated from terminal surface lifecycle.

## Implementation Details
Reference the TechSpec "Monitoring and Observability" and "Testing Approach" sections. This task should make focused integration adjustments after task 04, not redesign workspace models or persistence.

### Relevant Files
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Orchestrates create, restore, close, telemetry, and surface release.
- `Sources/NativeMacADECore/App/AppDependencyContainer.swift` — Wires terminal exit callbacks to command service and event source.
- `Sources/NativeMacADECore/App/TerminalExitEventSource.swift` — Publishes terminal exit observations to app surfaces.
- `Sources/NativeMacADECore/Restore/RestoreCoordinator.swift` — Coordinates restored tab metadata before surfaces are recreated.
- `Sources/NativeMacADECore/Observability/PerformanceMetrics.swift` — Tracks terminal surface failure rate and release-blocking diagnostics.
- `Sources/NativeMacADECore/Observability/WorkspaceLogger.swift` — Emits workspace log events used by tests and diagnostics.

### Dependent Files
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Presents terminal unavailable messages and restore diagnostics.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — Unit coverage for command service terminal surface behavior.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Integration coverage for create, restore, close, and telemetry paths.
- `Tests/NativeMacADEIntegrationTests/RestoreCoordinatorIntegrationTests.swift` — Restore diagnostics and terminal failure coverage.
- `Tests/NativeMacADEIntegrationTests/SessionTerminalSummaryIntegrationTests.swift` — Terminal summary behavior depends on terminal exit snapshots.
- `Tests/NativeMacADEIntegrationTests/ScaffoldIntegrationTests.swift` — Live dependency graph and exit fan-out coverage.

### Related ADRs
- [ADR-001: Use Ghostty as the Atelier terminal while preserving the Atelier workflow](adrs/adr-001.md) — Requires workspace workflows to stay familiar.
- [ADR-003: Replace the SwiftTerm terminal path inside TerminalHostController with Ghostty surfaces](adrs/adr-003.md) — Keeps workspace contracts stable while replacing the host path.
- [ADR-006: Preserve existing launch metadata and translate it into Ghostty launch configuration](adrs/adr-006.md) — Prevents persistence and launch-flow churn.
- [ADR-007: Validate Ghostty migration with manual baseline QA and focused runtime unit tests](adrs/adr-007.md) — Requires integration coverage for lifecycle and telemetry contracts.

## Deliverables
- Workspace command flows verified against the Ghostty terminal path.
- Restore, close, release, exit event, metrics, and log behavior preserved.
- File tab isolation verified after terminal runtime migration.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for workspace lifecycle and terminal telemetry **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Creating a session records a Ghostty surface handle and persists session plus first tab only after surface creation succeeds.
  - [ ] Creating a terminal tab records terminal failure metrics and logs when Ghostty surface creation fails.
  - [ ] Closing a terminal tab asks Ghostty `canClose` unless forced.
  - [ ] Releasing a terminal tab clears command-service surface state and removes exit snapshots.
  - [ ] Opening or restoring a file tab does not create a terminal surface.
- Integration tests:
  - [ ] Restoring mixed terminal and file tabs recreates Ghostty surfaces only for terminal tabs.
  - [ ] Terminal surface failures during restore appear in restore diagnostics and `terminal_surface_failed` logs.
  - [ ] Ghostty exit callback publishes one `TerminalExitObservation` and one `terminal_process_exited` log event.
  - [ ] Terminal surface failure rate still contributes to release-blocking diagnostics above the existing threshold.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Project, session, tab, restore, close, and exit workflows behave the same through the Ghostty terminal path.
- Existing telemetry and diagnostics remain available for release readiness.
