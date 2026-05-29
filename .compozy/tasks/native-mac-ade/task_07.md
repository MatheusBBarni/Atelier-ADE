---
status: completed
title: "Implement restore coordinator and relaunch recovery flow"
type: backend
complexity: high
dependencies:
  - task_03
  - task_04
  - task_05
  - task_06
---

# Task 07: Implement restore coordinator and relaunch recovery flow

## Overview
Implement the V1 relaunch behavior that reconstructs the workspace from saved metadata and reopens fresh shells. This task delivers the core continuity promise of the product without crossing into live-session persistence or deeper checkpoint/history features.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. MUST reconstruct projects, sessions, tab layout, and selected context from the stored restore snapshot on app launch.
- 2. MUST reopen fresh terminal shells from persisted metadata instead of attempting live PTY or scrollback reattachment.
- 3. MUST skip inaccessible or invalid restored project records, continue the rest of the restore flow, and surface a user-visible recovery path.
- 4. MUST preserve the last selected project, session, and tab whenever the persisted metadata remains valid.
- 5. SHOULD emit restore diagnostics for success, skip, and failure scenarios used by pilot quality review.
</requirements>

## Subtasks
- [x] 7.1 Implement the restore coordinator and launch-time replay flow.
- [x] 7.2 Load and validate the active restore snapshot and rebuild the workspace context from metadata.
- [x] 7.3 Recreate fresh terminal tabs through the existing command and terminal-host boundaries.
- [x] 7.4 Add missing-project recovery handling and visible user recovery feedback.
- [x] 7.5 Add tests for happy-path restore, partial restore, and skipped-project recovery behavior.

## Implementation Details
Follow TechSpec "Restore Coordinator" and "Development Sequencing > Build Order" step 6. Restoration is app-owned and metadata-only per ADR-005, so this task must stop short of any live shell persistence, checkpointing, or deep history replay.

### Relevant Files
- `AnotherADE/Restore/RestoreCoordinator.swift` — Owns relaunch reconstruction and restore replay.
- `AnotherADE/App/WorkspaceScene.swift` — Triggers restore at launch and hosts the recovered workspace shell.
- `AnotherADE/Persistence/SQLiteWorkspaceMetadataStore.swift` — Supplies restore snapshots, tab ordering, and project/session metadata.
- `AnotherADE/Services/DefaultWorkspaceCommandService.swift` — Replays restore into the same command boundary used by live actions.
- `AnotherADE/Terminal/Host/TerminalHostController.swift` — Recreates fresh terminal surfaces for restored tabs.
- `AnotherADE/Features/Workspace/RestoreRecoveryView.swift` — Surfaces skipped or inaccessible project recovery options.
- `AnotherADEIntegrationTests/RestoreCoordinatorIntegrationTests.swift` — Verifies restore replay and partial recovery behavior.

### Dependent Files
- `AnotherADE/Features/Sessions/SessionShortcutPicker.swift` — Task 08 will restore optional launch profiles for shortcut-based sessions.
- `AnotherADE/Support/Observability/WorkspaceLogger.swift` — Task 08 will record restore start, completion, and skipped-project metrics.
- `AnotherADE/Theme/NordTheme.swift` — The restored workspace should return to the same default shell theme introduced in task 05.

### Related ADRs
- [ADR-005: Persist Metadata-Only State and Restore Fresh Shells](adrs/adr-005.md) — Primary restore decision implemented by this task.
- [ADR-004: Embed Full libghostty Surfaces Inside the App](adrs/adr-004.md) — Requires the app to recreate tab surfaces itself during restore.
- [ADR-003: Use a SwiftUI App Shell with AppKit Terminal Hosting](adrs/adr-003.md) — Shapes launch-time replay through the SwiftUI/AppKit app shell.
- [ADR-002: Adopt a Workflow-Speed-First PRD for V1](adrs/adr-002.md) — Constrains V1 to basic restore rather than deeper continuity.

## Deliverables
- Restore coordinator and launch-time replay flow.
- Metadata-only relaunch reconstruction for projects, sessions, tabs, and selected context.
- Recovery handling for inaccessible project paths and partial restore failures.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for relaunch restore and recovery behavior **(REQUIRED)**.

## Tests
- Unit tests:
  - [x] Restoring a valid snapshot selects the expected project, session, and tab IDs.
  - [x] Restore replay reopens fresh shells instead of attempting live-session attachment.
  - [x] Skipping an inaccessible project leaves the remaining restored projects and tabs intact.
- Integration tests:
  - [x] Relaunch with a valid snapshot reconstructs the same visible project/session/tab layout from metadata.
  - [x] Relaunch with one missing project path restores the remaining context and surfaces recovery UI for the skipped item.
  - [x] Corrupted or incomplete snapshot data fails safely without crashing the app and returns the user to a recoverable workspace state.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Relaunch reliably restores the expected workspace context using fresh shells.
- Missing or invalid restore records degrade gracefully without blocking the rest of the workspace.
