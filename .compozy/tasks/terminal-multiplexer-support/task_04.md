---
status: pending
title: Restore pipeline continuity application
type: backend
complexity: high
dependencies:
  - task_02
  - task_03
---

# Task 04: Restore pipeline continuity application

## Overview

This task integrates continuity resolution into the real restore path so opted-in users land on the most likely terminal context after relaunch. It applies the selector at the command-service restore boundary, keeps non-opted-in behavior unchanged, and preserves the product’s truthful distinction between remembered app context and live external terminal state.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST apply the continuity selector inside `DefaultWorkspaceCommandService.restoreWorkspace()` after metadata restore succeeds and before live store restore recreates terminal and file surfaces.
2. MUST preserve current restore behavior for users who are not opted in and MUST fall back cleanly when the restored selected session has no eligible terminal tab.
3. MUST preserve truthful restore semantics by recreating terminal surfaces from existing launch intent only, without implying live process reattachment or mutating `RestoreSnapshot` into a synthetic continuity target.
4. SHOULD keep `RestoreCoordinator` generic; if additional restore data is required for selector fallback, the seam change MUST stay minimal and scoped to restore-boundary needs.
5. MUST add restore observability fields or metrics needed to distinguish applied continuity, disabled continuity, and fallback outcomes if the existing observability layer already owns restore metrics.
</requirements>

## Subtasks
- [ ] 4.1 Wire the continuity selector into the command-service restore flow at the boundary between restored metadata and live store rehydration.
- [ ] 4.2 Preserve existing restore behavior for opt-out users and for sessions without valid terminal candidates.
- [ ] 4.3 Keep restore snapshot truthfulness intact while terminal surfaces are recreated from current launch intent.
- [ ] 4.4 Add any minimal restore seam needed to expose selector inputs without broadening `RestoreCoordinator` responsibilities.
- [ ] 4.5 Add restore-path regression coverage and observability assertions for applied versus fallback outcomes.

## Implementation Details

Use the TechSpec sections **System Architecture → Restore orchestration layer**, **Data Flow → Startup or restore path**, **Impact Analysis**, **Monitoring and Observability**, and **Development Sequencing → Build Order (step 4)**. Codebase exploration found a seam mismatch with the conceptual selector contract: `RestoreCoordinator` currently returns a normalized `WorkspaceStore`, so if raw fallback data is required this task should add only a tiny restore-result seam or re-read the needed snapshot data in the command service rather than redesigning restore.

### Relevant Files
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Primary restore entry point where continuity selection must be applied before live store restore and surface recreation.
- `Sources/NativeMacADECore/Restore/RestoreCoordinator.swift` — Truthful metadata restore source that should remain generic unless a minimal additional seam is required.
- `Sources/NativeMacADECore/Workspace/FocusWorkspaceContinuityRestoreSelector.swift` — Selector contract consumed during restore-time continuity application.
- `Sources/NativeMacADECore/App/AppShellState.swift` — Startup path that ensures app preferences are loaded before restore is triggered.
- `Sources/NativeMacADECore/Observability/PerformanceMetrics.swift` — Existing observability seam to extend if restore continuity metrics or structured outcomes are recorded.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — Unit coverage for restore-boundary selector application and fallback behavior.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Best integration coverage for relaunch restore behavior and non-opt-in regressions.
- `Tests/NativeMacADEIntegrationTests/RestoreCoordinatorIntegrationTests.swift` — Additional integration surface if a minimal restore-result seam changes.
- `Tests/NativeMacADECoreTests/PerformanceMetricsTests.swift` — Validates new continuity restore metrics or structured field handling when observability is extended.

### Dependent Files
- `Sources/NativeMacADECore/Workspace/FocusWorkspacePresentation.swift` — Later active cues and help text depend on the final applied-versus-fallback restore behavior.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — UI surfaces later reflect continuity landing cues after restore completes.
- `Tests/NativeMacADECoreTests/AppShellStateTests.swift` — Startup regression coverage depends on restore still waiting for preferences.
- `Tests/NativeMacADEIntegrationTests/FocusWorkspaceUIContractIntegrationTests.swift` — UI contract expectations later depend on the final restore behavior this task enables.

### Related ADRs
- [ADR-002: Use a restore-first product approach for Focus Workspace continuity](../adrs/adr-002.md) — Makes restore landing the core user value for the MVP.
- [ADR-004: Resolve continuity at restore time with terminal-first selection and truthful snapshot persistence](../adrs/adr-004.md) — Defines the restore-only override, terminal-first rule, and truthful snapshot boundary.

## Deliverables
- Continuity selector wiring inside the real restore pipeline.
- Minimal restore seam adjustments, if needed, to provide selector inputs without broadening restore responsibilities.
- Restore observability updates for applied, disabled, and fallback continuity outcomes when supported by the existing metrics layer.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for continuity-aware relaunch restore behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `restoreWorkspace()` leaves the restored selection unchanged when continuity is disabled.
  - [ ] `restoreWorkspace()` applies the selector result before live store restore when both Focus Workspace and continuity are enabled.
  - [ ] `restoreWorkspace()` falls back to the raw restored selection when the selected session has no eligible terminal tab.
  - [ ] Restore-path observability records distinct outcomes for applied continuity versus fallback or disabled continuity when metrics are enabled.
- Integration tests:
  - [ ] Relaunching with one selected session containing both file and terminal tabs lands on the most recent terminal tab when continuity is enabled.
  - [ ] Relaunching with continuity enabled but no terminal candidate in the selected session preserves the raw restored tab selection.
  - [ ] Relaunching with continuity disabled restores the same project, session, and tab behavior as the current non-opted-in flow.
  - [ ] Continuity-aware restore recreates terminal surfaces from stored launch intent without implying live process reattachment.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Opted-in users land on the intended terminal-first restore target without changing non-opted-in restore behavior.
- Restore-time continuity remains localized to the command-service restore boundary and preserves truthful snapshot semantics.
