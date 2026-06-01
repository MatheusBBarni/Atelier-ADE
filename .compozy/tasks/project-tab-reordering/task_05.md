---
status: completed
title: "Restore-order hardening and reorder observability"
type: backend
complexity: high
dependencies:
  - task_02
---

# Task 05: Restore-order hardening and reorder observability

## Overview
This task hardens the trust-critical edge cases around reorder durability. It ensures degraded restore, hidden persisted tabs, and pilot diagnostics all reflect the same canonical ordering rules so reorder bugs are visible early and do not silently degrade the feature promise.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST preserve deterministic order after degraded restore when projects or file tabs are filtered out.
2. MUST keep persisted-but-not-visible tabs in a stable relative tail after visible selected-session tab reorders.
3. MUST add reorder-related diagnostics, metrics, or structured events using existing observability patterns.
4. MUST surface restore-order mismatch conditions as pilot-diagnostics or release-gate signals rather than leaving them silent.
5. MUST include unit and integration coverage for reorder after filtered restore, snapshot/order mismatch detection, and diagnostics updates.
</requirements>

## Subtasks
- [x] 5.1 Harden degraded-restore ordering so filtered items do not cause later reorder drift.
- [x] 5.2 Keep hidden persisted tabs and derived snapshot order aligned after visible reorder operations.
- [x] 5.3 Add reorder diagnostics and structured events to the existing observability surfaces.
- [x] 5.4 Extend restore-focused unit and integration coverage for mismatch and relaunch edge cases.
- [x] 5.5 Define release-gate style success checks for reorder persistence and restore alignment.

## Implementation Details
Use the TechSpec sections **System Architecture → Restore compatibility boundary**, **Monitoring and Observability**, and **Technical Considerations → Known Risks**. Keep this work anchored in existing restore, command, persistence, and pilot-diagnostics seams rather than inventing a separate monitoring system.

### Relevant Files
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Best place for reorder validation failures, persistence failures, and reorder-related event generation.
- `Sources/NativeMacADECore/Restore/RestoreCoordinator.swift` — Owns degraded-restore filtering and restore-order rebuilding.
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — Defines runtime authoritative order and snapshot generation used for alignment checks.
- `Sources/NativeMacADECore/Observability/PerformanceMetrics.swift` — Existing pilot diagnostics surface for metrics and release-blocking signals.
- `Tests/NativeMacADECoreTests/RestoreCoordinatorTests.swift` — Primary unit-test home for degraded-restore and hidden-tab order behavior.
- `Tests/NativeMacADECoreTests/PerformanceMetricsTests.swift` — Existing test surface for pilot-diagnostics expectations.
- `Tests/NativeMacADEIntegrationTests/RestoreCoordinatorIntegrationTests.swift` — End-to-end relaunch and degraded-restore regression coverage.
- `Tests/NativeMacADEIntegrationTests/SQLiteWorkspaceMetadataStoreTests.swift` — Persistence and snapshot edge-case coverage for restore alignment.

### Dependent Files
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Any reorder diagnostics surfaced in pilot or recovery views rely on existing shell presentation paths.
- `Sources/NativeMacADE/NativeMacADEApp.swift` — Adjacent-tab navigation will reflect any restore-order drift and must stay coherent.
- `Sources/NativeMacADECore/Persistence/WorkspacePersistenceStore.swift` — Restore hardening depends on the canonical batch persistence rules added earlier.
- `Sources/NativeMacADECore/Persistence/SQLiteWorkspaceMetadataStore.swift` — Durable snapshot/order alignment depends on correct persisted writes.
- `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift` — `RestoreSnapshot` serialization remains the persistence contract for visible order recovery.
- `Tests/NativeMacADECoreTests/AppShellStateTests.swift` — Pilot diagnostics structure changes can affect current app-shell state expectations.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Reorder-after-restore integration scenarios will rely on these diagnostics and ordering guarantees.

### Related ADRs
- [ADR-003: Command-Owned Reorder Operations for Projects and Tabs](../adrs/adr-003.md) — Keeps restore-sensitive reorder flows under the command boundary.
- [ADR-004: Canonicalize Order with Existing Fields and Atomic Batch Persistence](../adrs/adr-004.md) — Defines hidden-tab tail handling, canonical order fields, and derived snapshot rules.
- [ADR-005: Scope Tab Reordering to the Existing Session-Scoped Mixed Tab Strip](../adrs/adr-005.md) — Constrains restore hardening to selected-session mixed-tab behavior.

## Deliverables
- Deterministic degraded-restore ordering rules for reordered projects and selected-session tabs.
- Reorder diagnostics and structured events added to existing pilot observability surfaces.
- Restore-order mismatch detection aligned with release-gate expectations.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for degraded restore, relaunch order, and diagnostics updates **(REQUIRED)**

## Tests
- Unit tests:
  - [x] After filtered restore removes one file tab, the next visible-tab reorder keeps hidden persisted tabs in a stable tail order.
  - [x] Snapshot regeneration after reorder matches the runtime canonical order used for restore.
  - [x] Reorder persistence or restore-alignment failures increment the expected pilot diagnostics counters or flags.
- Integration tests:
  - [x] Reordering tabs after degraded restore persists a deterministic visible order across the next relaunch.
  - [x] A restore-order mismatch path emits the expected structured diagnostics and does not silently succeed.
  - [x] Reordered project or tab state remains aligned after relaunch even when one restored file tab is inaccessible.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Degraded restore no longer causes reorder drift or silent snapshot/order divergence.
- Reorder-specific failures become visible through existing pilot diagnostics and structured events.
