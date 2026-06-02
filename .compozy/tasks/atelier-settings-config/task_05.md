---
status: pending
title: "Add config-modal portable settings UX and scope labeling"
type: frontend
complexity: high
dependencies:
  - task_04
---

# Task 05: Add config-modal portable settings UX and scope labeling

## Overview

This task makes portable settings understandable and usable from the existing settings experience. It adds reveal/reload/status controls and clear scope labeling so power users can discover the feature, understand what travels across machines, and avoid confusing local-only profile behavior with the portable contract.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The implementation MUST keep the existing config modal as the only visible host for portable settings controls in V1.
- 2. The implementation MUST expose the portable config path, reveal/open actions, manual reload, and last apply status from the modal.
- 3. The implementation MUST clearly label which settings are portable in V1 and which remain local-only across appearance, focus workspace, keyboard shortcuts, and agent-profile behavior.
- 4. The implementation MUST explain that custom agent profile definitions, custom default profiles, and machine-specific command details remain local-only in V1.
- 5. The implementation MUST present reload and partial-apply feedback in a way that makes rejected sections visible instead of collapsing them into a generic success or failure message.
- 6. The implementation SHOULD reuse existing modal composition, feedback, and command-service boundaries instead of introducing direct filesystem or persistence access in views.
</requirements>

## Subtasks
- [ ] 5.1 Add a portable-settings control surface to the config modal for path visibility, reveal/open actions, reload, and status.
- [ ] 5.2 Add portable-scope labeling to the appearance, focus workspace, and keyboard shortcut sections.
- [ ] 5.3 Add mixed-scope labeling and explanatory copy to the agent-profile section for built-in default selection versus local-only custom profile details.
- [ ] 5.4 Add feedback presentation for successful reloads, rejected sections, and explicit portable-settings failures.
- [ ] 5.5 Add automated UI contract coverage for modal composition, scope messaging, and portable-settings actions.

## Implementation Details

See the TechSpec sections **Settings UI Integration**, **Data Flow**, **Impact Analysis**, and **Known Risks**. Keep the modal as the only visible host, route all behavior through the command-service seam, and make the portable-versus-local boundary explicit without redesigning the broader settings experience.

### Relevant Files
- `Sources/NativeMacADE/AppShell/ConfigModalView.swift` — Modal host that should contain the portable settings control surface and any modal-level apply status.
- `Sources/NativeMacADE/AppShell/ConfigModalAppearanceAndShortcutsSection.swift` — Portable appearance and managed-shortcuts section that needs clear portable labeling and reload-aware feedback.
- `Sources/NativeMacADE/AppShell/ConfigModalFocusWorkspaceSection.swift` — Portable behavior section that should advertise its V1 portability status clearly.
- `Sources/NativeMacADE/AppShell/ConfigModalAgentProfilesSection.swift` — Mixed-scope UI where portable built-in default selection must be distinguished from local-only custom profile editing.
- `Sources/NativeMacADECore/Workspace/AgentProfilePresentation.swift` — Existing built-in/custom row-state model that may need structured portability labels or state helpers.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Existing modal host and Finder reveal pattern that can anchor config-path reveal behavior.
- `Tests/NativeMacADEIntegrationTests/FocusWorkspaceUIContractIntegrationTests.swift` — Existing UI contract-test style that fits modal composition and copy verification.

### Dependent Files
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — UI actions depend on portable reload and config-path APIs added by the service layer.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Reload/apply status, rejected-section details, and portable-scope semantics must originate here.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — UI messaging should stay aligned with the real service outcomes for reload and partial apply.
- `Sources/NativeMacADECore/Workspace/AppPreferences.swift` — Section labeling should stay aligned with the actual portable fields supported by runtime preferences.

### Related ADRs
- [ADR-002: Curated Portable Core Product Approach](adrs/adr-002.md) — Requires a power-user, reliability-first framing with clear supported scope.
- [ADR-003: File-Authoritative Personal Config Projection](adrs/adr-003.md) — Requires reveal/open path access and explicit manual reload rather than live watching.
- [ADR-004: Stable Portable Config Schema With Built-In Agent Scope](adrs/adr-004.md) — Requires the UI to explain that only built-in default selection is portable in V1.
- [ADR-005: Section-Granularity Partial Apply With Diagnostics](adrs/adr-005.md) — Requires visible partial-apply and rejected-section feedback rather than generic messaging.

## Deliverables
- Portable-settings controls in the existing config modal for path visibility, reveal/open actions, manual reload, and status.
- Clear portable-versus-local labeling across the in-scope settings sections.
- Agent-profile copy that distinguishes portable built-in default selection from local-only custom profile behavior.
- Reload feedback UI that can communicate successful apply, partial apply, and failure states.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for modal composition, copy, and portable-settings action behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Portable status helpers, if introduced, mark appearance, focus workspace, and managed shortcuts as portable V1 settings.
  - [ ] Agent-profile presentation helpers distinguish built-in default selection from local-only custom profile editing and command details.
  - [ ] Portable reload status formatting surfaces rejected-section detail instead of collapsing to a binary success/error state.
- Integration tests:
  - [ ] The config modal includes a portable-settings control surface with config-path visibility, reveal/open action, and manual reload action.
  - [ ] The appearance, focus workspace, and keyboard shortcuts sections show portable-scope messaging aligned with the supported V1 contract.
  - [ ] The agent-profile section explicitly states that custom profiles and machine-specific command details remain local-only while built-in default selection is portable.
  - [ ] A partial-apply reload result renders visible rejected-section feedback instead of a generic success toast.
  - [ ] If reveal/open actions are testable through a seam, the modal routes them through the portable config path supplied by the command service.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Power users can discover and operate portable settings from the existing config modal without learning a second settings surface.
- The modal clearly communicates what travels across machines and what remains intentionally local in V1.
- Reload outcomes, including partial apply and rejected sections, are visible and understandable from the UI.
