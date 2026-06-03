---
status: completed
title: "Integrate portable settings into startup, save, reload, and app wiring"
type: backend
complexity: high
dependencies:
  - task_02
  - task_03
---

# Task 04: Integrate portable settings into startup, save, reload, and app wiring

## Overview

This task makes portable settings part of the real application lifecycle. It connects the new config store and projection rules to startup bootstrap, settings saves, manual reload, dependency injection, and observability while preserving the existing “load preferences before restore” contract.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The implementation MUST extend the command-service surface with portable settings reload and config-path accessors suitable for UI consumption.
- 2. The implementation MUST make `loadAppPreferences()` bootstrap from the file-authoritative portable config when the file exists, while preserving the existing startup order of preferences load, theme application, then workspace restore.
- 3. The implementation MUST seed the portable config file once from supported non-default SQLite-backed preferences when the file is missing, and MUST avoid seeding when runtime preferences are still at pristine defaults.
- 4. The implementation MUST export the supported portable subset during `saveAppPreferences(_:)` while keeping unsupported local-only runtime state outside the portable file.
- 5. The implementation MUST reuse the same decode, validate, project, persist, and diagnostics path for startup and explicit manual reload.
- 6. The implementation MUST emit portable-settings metrics and logs for seed, reload, export, failures, and partial-apply outcomes.
- 7. The implementation SHOULD surface portable file-load and file-write failures explicitly instead of silently pretending portability succeeded.
</requirements>

## Subtasks
- [x] 4.1 Extend the command-service API surface for portable config reload and config-path access.
- [x] 4.2 Wire the portable file store into live app dependencies and test harness construction.
- [x] 4.3 Add startup bootstrap behavior for file-present, file-missing, seed-from-SQLite, and pristine-default scenarios.
- [x] 4.4 Add save/export orchestration that keeps the runtime cache, portable file, and store state aligned.
- [x] 4.5 Reuse one shared apply path for startup and manual reload diagnostics.
- [x] 4.6 Add observability and automated coverage for bootstrap, reload, export, and failure behavior.

## Implementation Details

See the TechSpec sections **Workspace Command Service**, **Startup Coordinator**, **Data Flow**, **Impact Analysis**, **Testing Approach → Integration Tests**, and **Monitoring and Observability**. Keep orchestration centered in `DefaultWorkspaceCommandService`, preserve the current startup ordering contract, and avoid introducing a parallel settings service or SQLite schema change in V1.

### Relevant Files
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — Public surface that must expose portable reload and config-path access for the UI.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Core orchestration seam for startup bootstrap, save/export ordering, reload reuse, and diagnostics.
- `Sources/NativeMacADECore/App/AppDependencyContainer.swift` — Live dependency wiring point for the portable file store and any related collaborators.
- `Sources/NativeMacADECore/App/AppShellState.swift` — Startup coordinator contract that must keep preferences load ahead of restore.
- `Sources/NativeMacADECore/Observability/PerformanceMetrics.swift` — Counter and diagnostic surface for seed/reload/export success and failure events.
- `Sources/NativeMacADECore/Observability/WorkspaceLogger.swift` — Structured logging seam for portable-settings load, seed, reload, rejection, and export events.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Best fit for end-to-end bootstrap, save/export, and reload coverage.

### Dependent Files
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — Store updates drive live runtime theme, default-profile, and keybinding behavior after load or reload.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Startup theme application and settings-sheet host depend on the updated command-service behavior.
- `Sources/NativeMacADE/AppShell/ConfigModalView.swift` — Later UI controls will consume portable config URL, reload actions, and last-apply results from this service seam.
- `Sources/NativeMacADECore/Persistence/SQLiteWorkspaceMetadataStore.swift` — Runtime cache persistence remains the bridge between portable projection and the existing app state model.
- `Tests/NativeMacADECoreTests/AppShellStateTests.swift` — Startup-order regressions should remain covered when portable bootstrap is inserted into preference loading.

### Related ADRs
- [ADR-001: Single-Scope Personal Settings Config](adrs/adr-001.md) — Keeps integration scoped to personal-global settings rather than multi-scope precedence rules.
- [ADR-003: File-Authoritative Personal Config Projection](adrs/adr-003.md) — Requires file-authoritative startup and save behavior with explicit manual reload.
- [ADR-004: Stable Portable Config Schema With Built-In Agent Scope](adrs/adr-004.md) — Constrains the portable subset that save/export logic may write.
- [ADR-005: Section-Granularity Partial Apply With Diagnostics](adrs/adr-005.md) — Governs startup and reload diagnostics when only some sections can be applied.

## Deliverables
- Command-service APIs for portable settings reload and config-path retrieval.
- Live startup bootstrap, seed, save/export, and manual reload orchestration for portable settings.
- Dependency wiring that makes the portable file store available in app and test harnesses.
- Portable-settings metrics and structured logs for success, failure, and partial-apply outcomes.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for bootstrap, reload, save/export, and failure behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [x] `loadAppPreferences()` with a present portable config applies supported portable sections before returning runtime preferences.
  - [x] When no portable config exists and supported SQLite preferences are non-default, bootstrap seeds the portable file exactly once.
  - [x] When no portable config exists and runtime preferences are pristine defaults, bootstrap leaves the file absent.
  - [x] `saveAppPreferences(_:)` exports the supported portable subset and records failure when the portable file cannot be written.
  - [x] Manual reload reuses the shared apply path and returns explicit diagnostics for applied and rejected sections.
- Integration tests:
  - [x] Startup with a portable config applies the effective appearance and default-profile state before workspace restore begins.
  - [x] Invalid portable JSON falls back to the current normalized runtime preferences while recording portable-load diagnostics.
  - [x] Manual reload of a mixed-validity file applies valid sections, reports rejected sections, and remains idempotent when the file has not changed.
  - [x] Saving supported settings updates both the SQLite runtime cache and the portable settings file without exporting local-only custom profile data.
  - [x] Changing the portable default-profile configuration affects future session bootstrap only and does not rewrite persisted launch metadata for restored tabs.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Portable settings participate in real startup, save, and reload behavior through one shared command-service orchestration path.
- Existing startup ordering remains intact: preferences load first, runtime appearance applies next, workspace restore follows.
- Seed, reload, export, and rejection outcomes are observable through explicit metrics and structured logs.
