---
status: pending
title: "Build the config modal agent-profile section"
type: frontend
complexity: medium
dependencies:
  - task_03
  - task_05
---

# Task 06: Build the config modal agent-profile section

## Overview
This task implements the highest-value section of the config modal: agent-profile management. It gives users a safe, guided place to choose a default profile, work with curated built-ins such as Claude, Codex, and OpenCode, and manage custom profiles without exposing raw persistence behavior or confusing “shortcut” terminology.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The implementation MUST make Agent Profile management the lead section of the config modal.
- 2. The implementation MUST let users choose a saved default profile, including an explicit no-default/plain-shell option.
- 3. The implementation MUST distinguish built-in, customized built-in, and fully custom profiles in the UI.
- 4. The implementation MUST support the correct action matrix: built-ins are editable and resettable but not deletable; custom profiles are addable, editable, and deletable.
- 5. The implementation MUST use “Agent Profile” for user-facing copy and keep “shortcut” internal only.
- 6. The implementation MUST show safe validation feedback for invalid launch-profile edits and stale default references without partially saving bad state.
- 7. The implementation SHOULD refresh visible default and profile state immediately after every successful mutation.
</requirements>

## Subtasks
- [ ] 6.1 Define the Agent Profile section content and copy, including the default-profile selector and no-default state.
- [ ] 6.2 Add profile rows or cards that show built-in, customized, and custom states with the correct available actions.
- [ ] 6.3 Add create and edit flows for profile details and default assignment.
- [ ] 6.4 Add reset and delete flows with the required safeguards for built-ins versus custom profiles.
- [ ] 6.5 Add friendly validation and error presentation for profile edits and default-profile failures.
- [ ] 6.6 Replace in-scope user-facing “shortcut” terminology with “Agent Profile.”

## Implementation Details
See the TechSpec sections **Agent Profile Layer**, **API Endpoints**, **Testing Approach**, and **Key Decisions**. The UI must bind to the command-service settings surface instead of talking to persistence directly, and it must keep user-facing terminology distinct from the internal `SessionShortcut` type name.

### Relevant Files
- `Sources/NativeMacADE/AppShell/ConfigModalView.swift` — Modal host that should contain or compose the Agent Profile section.
- `Sources/NativeMacADE/AppShell/ConfigModalAgentProfilesSection.swift` — Likely new focused section view for profile management and default selection.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Existing modal patterns and older “shortcut” user-facing copy that needs alignment.
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — Settings and profile mutation API boundary the UI must use.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Canonical built-in/default/reset semantics that the UI must trust.
- `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift` — Internal `SessionShortcut` model and curated built-in catalog.
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — Observable preferences and section-refresh state.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Best fit for default-profile creation and persistence regressions.

### Dependent Files
- `Sources/NativeMacADE/AppShell/ConfigModalView.swift` — The appearance and shortcut sections added later will share the modal shell established here.
- `Sources/NativeMacADE/AppShell/ConfigModalAppearanceAndShortcutsSection.swift` — Downstream section work depends on consistent modal patterns and copy conventions.
- `Sources/NativeMacADE/NativeMacADEApp.swift` — The settings command is only valuable if the first modal section is useful and correctly named.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — Mutation rules this UI exposes require matching backend validation coverage.
- `Tests/NativeMacADEIntegrationTests/SQLiteWorkspaceMetadataStoreTests.swift` — Default-profile and built-in override persistence must keep backing the UI correctly.

### Related ADRs
- [ADR-001: Agent-First Scope for Config Modal Personalization](adrs/adr-001.md) — Makes this the lead section of the modal.
- [ADR-002: Guided Control Center Product Approach for Config Modal Customization](adrs/adr-002.md) — Requires a curated, guided profile experience.
- [ADR-003: In-App Modal Settings Host for Config Customization](adrs/adr-003.md) — Anchors this section in the in-window modal.
- [ADR-004: SQLite-Centered Global Preferences Layer](adrs/adr-004.md) — Default-profile selection and cleanup depend on shared persisted preferences.
- [ADR-005: Reuse SessionShortcut as the Curated Agent Profile Model](adrs/adr-005.md) — Governs built-in versus custom profile semantics.
- [ADR-007: Centralize New-Session Bootstrap in WorkspaceCommandService](adrs/adr-007.md) — The selected default profile affects only future session bootstrap through the service.

## Deliverables
- Agent Profile section as the lead config-modal surface.
- Default-profile selector with explicit no-default/plain-shell option.
- Guided add, edit, delete, and reset flows with correct built-in/custom action rules.
- Updated user-facing terminology from “shortcut” to “Agent Profile” where this feature touches the product.
- Validation and persistence refresh coverage for agent-profile mutations.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for agent-profile mutation and default-profile behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Editing a built-in profile preserves its ID, marks it customized, and leaves delete unavailable.
  - [ ] Resetting a built-in profile restores canonical values and clears customized state.
  - [ ] Adding, editing, and deleting a custom profile works, while deleting a built-in profile fails.
  - [ ] Invalid `launchArgumentsJSON` is rejected and leaves the previously saved profile unchanged.
  - [ ] Section-state helpers, if introduced, compute the correct badges and allowed actions for built-in, customized, and custom profiles.
- Integration tests:
  - [ ] Saving a default agent profile then calling `createSession(projectID:, shortcutID: nil)` creates exactly one first tab using that profile.
  - [ ] Clearing or deleting the current default profile removes the saved default and new sessions fall back to plain shell.
  - [ ] Persisted default-profile references and built-in override state round-trip through SQLite.
  - [ ] Resetting a customized built-in changes only future session bootstrap and does not mutate existing restored tabs.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Users can manage curated and custom agent profiles from one guided modal section.
- Built-in, customized, and custom profile states are visually and behaviorally distinct.
- Default-profile changes affect future session starts without confusing “shortcut” terminology in the UI.
