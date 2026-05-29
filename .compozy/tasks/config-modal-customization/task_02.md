---
status: pending
title: "Centralize new-session bootstrap and default-profile resolution"
type: backend
complexity: high
dependencies:
  - task_01
---

# Task 02: Centralize new-session bootstrap and default-profile resolution

## Overview
This task makes `createSession` the single owner of first-tab bootstrap for all new sessions. It removes the current split between UI-owned plain-session tab creation and service-owned shortcut-backed bootstrap so explicit profiles, saved default profiles, and plain shells all behave the same way.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The implementation MUST make `WorkspaceCommandService.createSession` the only owner of first-tab bootstrap for new sessions.
- 2. The implementation MUST resolve launch intent in one order only: explicit profile, then saved default profile, then plain shell.
- 3. The implementation MUST guarantee exactly one first tab per new session.
- 4. The implementation MUST keep session creation and first-tab bootstrap atomic so failures do not leave orphaned tabless sessions behind.
- 5. The implementation MUST preserve restore semantics so already-persisted tabs keep their saved launch intent after preferences change.
- 6. The implementation SHOULD leave `createTab(sessionID:)` as the later-tab path only.
</requirements>

## Subtasks
- [ ] 2.1 Audit all new-session entry points and remove UI-side first-tab bootstrap assumptions.
- [ ] 2.2 Normalize the explicit-profile, saved-default, and plain-shell launch-source contract in the command service.
- [ ] 2.3 Update session persistence, selection, and logging so all new-session paths follow one bootstrap flow.
- [ ] 2.4 Preserve existing restore and later-tab behavior while retiring only the split first-tab path.
- [ ] 2.5 Add regression coverage for exactly-one-tab creation, rollback safety, and later-tab inheritance behavior.

## Implementation Details
See the TechSpec sections **Data Flow**, **API Endpoints**, and **Development Sequencing** for the normalized session-bootstrap contract. This task must not reintroduce duplicate-tab behavior through UI fallbacks or restore-time preference re-resolution.

### Relevant Files
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — Public service contract whose semantics change here.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Current split bootstrap behavior lives here and must be normalized.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Still creates a tab after plain-session creation and must stop doing so.
- `Sources/NativeMacADE/NativeMacADEApp.swift` — App-level “New Session” depends on the normalized bootstrap contract.
- `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift` — Defines `WorkspaceSession`, `WorkspaceTab`, and `SessionShortcut` launch-intent fields this task must preserve.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — Best fit for unit-level bootstrap rules and error/rollback behavior.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Best fit for SQLite-backed exactly-one-tab and restore regression coverage.

### Dependent Files
- `Sources/NativeMacADE/AppShell/ConfigModalView.swift` — Later settings UI depends on a correct saved-default bootstrap contract.
- `Sources/NativeMacADE/NativeMacADEApp.swift` — Top-level new-session command should continue to produce a usable session immediately.
- `Tests/NativeMacADEIntegrationTests/RestoreCoordinatorIntegrationTests.swift` — Restore coverage depends on this task not re-resolving defaults for persisted tabs.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Later settings orchestration depends on this normalized session creation path.

### Related ADRs
- [ADR-004: SQLite-Centered Global Preferences Layer](adrs/adr-004.md) — Supplies the saved default-profile reference this task consumes.
- [ADR-005: Reuse SessionShortcut as the Curated Agent Profile Model](adrs/adr-005.md) — Launch resolution still works through `SessionShortcut`.
- [ADR-006: Limited Keybinding Scope and Immediate Preference Application](adrs/adr-006.md) — Preferences affect future sessions only; existing launch intent stays stable.
- [ADR-007: Centralize New-Session Bootstrap in WorkspaceCommandService](adrs/adr-007.md) — Directly defines the required contract for this task.

## Deliverables
- Unified `createSession` behavior for explicit-profile, saved-default, and plain-shell starts.
- Removal of immediate follow-up `createTab` calls from plain-session UI paths.
- Logging and selection behavior updated to reflect one consistent bootstrap path.
- Updated unit and integration coverage for exactly-one-tab creation and rollback behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for session bootstrap behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Explicit `shortcutID` creates one session and one first tab with the selected profile’s launch command and arguments.
  - [ ] `shortcutID == nil` with a saved default profile creates one first tab using that saved profile.
  - [ ] `shortcutID == nil` with no saved default profile creates one plain first tab with nil launch command and args.
  - [ ] Missing explicit shortcut still throws `missingShortcut` and leaves store and persistence unchanged.
  - [ ] Later `createTab(sessionID:)` inherits the session’s stored launch intent instead of rereading current preferences.
- Integration tests:
  - [ ] SQLite-backed explicit-profile session creation writes exactly one `sessions` row and one `tabs` row.
  - [ ] SQLite-backed saved-default session creation writes exactly one first tab and preserves the correct launch intent.
  - [ ] Terminal surface failure during first-tab bootstrap rolls back both the session and tab persistence records.
  - [ ] Restoring old tabs after a default-profile change reopens them with their original persisted command and arguments.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- No new-session entry path creates duplicate first tabs.
- Plain, explicit-profile, and saved-default session starts share one authoritative bootstrap contract.
- Restore behavior remains metadata-only and unaffected by saved default changes.
