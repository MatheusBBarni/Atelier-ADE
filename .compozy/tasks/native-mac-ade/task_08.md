---
status: completed
title: "Add lightweight session shortcuts and pilot observability polish"
type: backend
complexity: medium
dependencies:
  - task_04
  - task_06
  - task_07
---

# Task 08: Add lightweight session shortcuts and pilot observability polish

## Overview
Add the optional session shortcuts and pilot diagnostics that round out the V1 workflow loop. This task keeps shortcuts lightweight and fully inside the project/session/tab model while adding the local metrics and structured logging needed to judge pilot quality and release readiness.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. MUST implement lightweight session shortcuts as optional launch profiles within the existing session creation flow.
- 2. MUST map shortcut metadata to Ghostty launch behavior without changing the project -> session -> tab model.
- 3. MUST add local structured logging and pilot metrics for project open, session create, tab create, restore, terminal-surface failure, and process exit flows.
- 4. MUST keep secrets out of SQLite and allow only indirect Keychain references if shortcuts later need sensitive values.
- 5. SHOULD make pilot regressions around restore reliability, terminal creation failure rate, and launch-to-ready latency easy to inspect locally.
</requirements>

## Subtasks
- [x] 8.1 Add lightweight session shortcut definitions, persistence support, and launch-profile mapping.
- [x] 8.2 Extend session creation flows so users can choose an optional shortcut without changing session semantics.
- [x] 8.3 Add local structured log events and pilot metrics for workspace, restore, and terminal lifecycle flows.
- [x] 8.4 Add pilot-oriented diagnostics or debug surfaces needed to inspect release-blocking regressions locally.
- [x] 8.5 Add tests for shortcut launch mapping and observability event coverage.

## Implementation Details
Use TechSpec "Monitoring and Observability" and the PRD's lightweight shortcut scope to keep this work narrow. Do not turn shortcuts into an agent-first abstraction or turn observability into backend alerting; both must stay local and app-owned in V1.

### Relevant Files
- `AnotherADE/Workspace/SessionShortcut.swift` — Defines the lightweight session shortcut metadata model.
- `AnotherADE/Persistence/SQLiteWorkspaceMetadataStore.swift` — Stores shortcut records and any shortcut-linked session metadata.
- `AnotherADE/Services/DefaultWorkspaceCommandService.swift` — Resolves shortcut selection into session/tab launch behavior.
- `AnotherADE/Features/Sessions/SessionShortcutPicker.swift` — Optional session-start UI for built-in shortcuts.
- `AnotherADE/Support/Observability/WorkspaceLogger.swift` — Structured event logging for project/session/tab/restore flows.
- `AnotherADE/Support/Observability/PerformanceMetrics.swift` — Tracks launch, restore, and terminal-surface timing/quality counters.
- `AnotherADEIntegrationTests/SessionShortcutAndObservabilityIntegrationTests.swift` — Verifies shortcut launch mapping and local diagnostics coverage.

### Dependent Files
- `AnotherADE/Terminal/Ghostty/GhosttyLaunchConfig.swift` — Shortcut metadata must translate into terminal launch configuration consistently.
- `AnotherADE/Restore/RestoreCoordinator.swift` — Restored tabs should retain any stored shortcut-linked launch intent.
- `AnotherADE/Features/Workspace/WorkspaceRootView.swift` — May surface pilot-only diagnostics or error states tied to observability outputs.

### Related ADRs
- [ADR-002: Adopt a Workflow-Speed-First PRD for V1](adrs/adr-002.md) — Keeps shortcuts lightweight and in service of faster session starts.
- [ADR-003: Use a SwiftUI App Shell with AppKit Terminal Hosting](adrs/adr-003.md) — Ensures diagnostics remain app-local and consistent with the chosen shell architecture.
- [ADR-004: Embed Full libghostty Surfaces Inside the App](adrs/adr-004.md) — Shortcut mapping ultimately drives embedded terminal launch behavior.
- [ADR-005: Persist Metadata-Only State and Restore Fresh Shells](adrs/adr-005.md) — Keeps shortcut persistence and restore semantics metadata-only.

## Deliverables
- Lightweight session shortcut metadata, launch mapping, and optional selection UI.
- Local structured logging and performance metrics for pilot quality gates.
- Pilot diagnostics that make restore and terminal failures inspectable without backend infrastructure.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for shortcut launch mapping and observability behavior **(REQUIRED)**.

## Tests
- Unit tests:
  - [x] Selecting a shortcut when creating a session stores the expected shortcut ID and launch profile metadata.
  - [x] Shortcut launch mapping produces the expected command and argument set for the Ghostty launch config.
  - [x] Structured log payloads include hashed project identifiers and the required event fields.
- Integration tests:
  - [x] Creating a session with a lightweight shortcut launches the first tab with the expected shortcut-derived configuration.
  - [x] Restore replay preserves shortcut-linked launch intent when reconstructing a session from metadata.
  - [x] Terminal-surface failure and restore failure paths emit the expected pilot diagnostics without backend dependencies.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Lightweight shortcuts accelerate common session starts without changing the core session model.
- Pilot builds expose enough local diagnostics to judge restore reliability, terminal creation failures, and launch-speed regressions.
