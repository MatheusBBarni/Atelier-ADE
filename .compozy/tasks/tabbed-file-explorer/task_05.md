---
status: pending
title: "Add app commands, telemetry, and workflow hardening for file tabs"
type: backend
complexity: high
dependencies:
  - task_03
  - task_04
---

# Task 05: Add app commands, telemetry, and workflow hardening for file tabs

## Overview
Finish the feature by adding the user command surface, privacy-safe telemetry, and the hardening required for a trustworthy mixed-tab workflow. This task focuses on save/revert/external-editor commands, file-specific close and restore messaging, and final integration coverage so the feature is safe to pilot.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST expose explicit save, revert, and external-editor actions at the app command level with enablement driven by the selected file tab.
2. MUST extend metrics and structured logging for file opens, saves, reverts, restore failures, dirty-close decisions, and external-editor escalation without logging raw file paths.
3. MUST harden mixed-tab restore and close UX so dirty file tabs, missing restored files, and file-specific rejection states are communicated accurately.
4. SHOULD preserve the current pilot-diagnostics and restore-reporting style instead of inventing a second observability surface.
</requirements>

## Subtasks
- [ ] 5.1 Add save, revert, and external-editor commands and shortcuts to the app-level command surface with selected-file enablement rules.
- [ ] 5.2 Add file workflow metrics and structured log events with privacy-safe path handling.
- [ ] 5.3 Update close and restore user messages so file-tab rejection and missing restored files no longer use terminal-specific copy.
- [ ] 5.4 Harden destructive flows such as close, remove-session, and remove-project for dirty file tabs.
- [ ] 5.5 Expand integration coverage for mixed restore, save/revert, close confirmation, and file workflow telemetry.

## Implementation Details
This task lands the final workflow hardening around the TechSpec sections "Monitoring and Observability", "Technical Considerations", and "Development Sequencing". Keep the feature centered on explicit user trust: deliberate save, accurate close messages, and restore diagnostics that match the metadata-only continuity model.

### Relevant Files
- `Sources/NativeMacADE/NativeMacADEApp.swift` — Primary app command host for save, revert, and external-editor actions.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Visible restore diagnostics, toolbar actions, and tab-close messaging currently written for terminal-only flows.
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — Command protocol and error surface that must reflect file-tab save/revert/close outcomes.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Central restore, close, and orchestration path for file workflow hardening.
- `Sources/NativeMacADECore/Observability/PerformanceMetrics.swift` — Pilot metric model that will grow file-specific counters and latencies.
- `Sources/NativeMacADECore/Observability/WorkspaceLogger.swift` — Structured event sink for file workflow events.
- `Sources/NativeMacADECore/Restore/RestoreCoordinator.swift` — Existing restore diagnostics builder for missing or unreadable file-tab recovery.

### Dependent Files
- `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift` — File-tab model metadata drives save/revert command enablement and restore diagnostics.
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — Selected tab and activation order determine command availability and working-set telemetry.
- `Sources/NativeMacADECore/Persistence/SQLiteWorkspaceMetadataStore.swift` — Mixed-tab persistence must already be stable before restore hardening and telemetry are meaningful.
- `Sources/NativeMacADECore/App/AppDependencyContainer.swift` — Live DI must already provide the file runtime services and external-editor boundary this task surfaces.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Best end-to-end seam for file workflow hardening and telemetry coverage.

### Related ADRs
- [ADR-002: Adopt a working-set-first quick-fix editor approach for the PRD](../adrs/adr-002.md) — Keeps commands and workflow hardening scoped to quick-fix editing rather than full editor parity.
- [ADR-003: Extend the shared session tab model to support file tabs and terminal tabs](../adrs/adr-003.md) — Requires commands and restore UX to stay within one shared tab strip.
- [ADR-005: Persist file-tab metadata only, with explicit save and no unsaved-buffer restore](../adrs/adr-005.md) — Directly constrains save, close, and restore user expectations.

## Deliverables
- App-level save, revert, and external-editor commands with correct selected-file enablement.
- File workflow metrics and structured logs with privacy-safe path handling.
- Updated restore and close messaging for dirty file tabs and missing restored file tabs.
- Hardened destructive flows for dirty file tabs in close/remove-session/remove-project paths.
- Final integration coverage for save/revert/restore/close/telemetry behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for file workflow hardening and telemetry **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `DefaultWorkspaceCommandServiceTests`: dirty file tabs trigger file-specific rejection handling instead of terminal-specific `still running` behavior.
  - [ ] `PerformanceMetricsTests`: file-open/save/restore counters and dirty-close confirmation counts roll up into pilot diagnostics correctly.
  - [ ] `WorkspaceLogger`-focused tests or command-service tests: file workflow events hash or omit file paths rather than logging raw file locations.
- Integration tests:
  - [ ] `DefaultWorkspaceCommandServiceIntegrationTests`: file open → edit → save → relaunch preserves saved contents and clears dirty state while unsaved changes are intentionally not restored.
  - [ ] `RestoreCoordinatorIntegrationTests`: missing restored file tabs produce visible diagnostics without aborting the whole workspace restore.
  - [ ] Integration or smoke coverage: app command enablement reflects the selected file tab for save/revert/open-external-editor actions.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Users can invoke save, revert, and external-editor flows from the app command surface when a file tab is active.
- File workflow metrics and logs exist without exposing raw file paths.
- Mixed-tab restore and close behavior communicate file-specific outcomes clearly and no longer rely on terminal-only UX copy.
