---
status: pending
title: "Shared terminal presentation resolver"
type: refactor
complexity: medium
dependencies: []
---

# Task 01: Shared terminal presentation resolver

## Overview
Extract the terminal title, agent label, and icon fallback logic from the current AppShell views into one shared presentation resolver. This keeps the tab strip, rename placeholder logic, and future session-row summaries aligned while limiting V1 to one factual identity contract.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The feature MUST introduce a shared AppShell-local resolver for terminal presentation data, as defined by the TechSpec "System Architecture" and "Implementation Design" sections.
- 2. The resolver MUST centralize terminal title, agent label, and icon fallback behavior for terminal tabs only.
- 3. The resolver MUST preserve the approved fallback order: custom tab title, shortcut lookup, launch-command heuristic, then `Terminal`.
- 4. `TabItemView` and `TabRenameDraft` MUST consume the shared resolver so they no longer drift from each other.
- 5. The resolver SHOULD remain pure and free of persistence or runtime side effects.
</requirements>

## Subtasks
- [ ] 1.1 Define the shared terminal presentation contract used by AppShell consumers.
- [ ] 1.2 Move terminal title, agent label, and icon fallback behavior out of inline view-specific logic.
- [ ] 1.3 Update the existing tab strip to use the shared resolver for terminal identity.
- [ ] 1.4 Update rename-placeholder behavior to use the same terminal fallback contract.
- [ ] 1.5 Add automated coverage proving terminal identity resolution stays aligned across current consumers.

## Implementation Details
Create the shared resolver in AppShell and use the TechSpec "Core Interfaces" and "Data Models" sections as the contract reference. Keep file-tab naming logic unchanged. Avoid promoting this resolver into `NativeMacADECore`; ADR-003 fixes the boundary in AppShell.

### Relevant Files
- `Sources/NativeMacADE/AppShell/ContentView.swift` — `TabItemView` currently owns terminal title and icon heuristics that this task must extract.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — `TabRenameDraft` duplicates terminal fallback-title logic and must align with the resolver.
- `Sources/NativeMacADE/AppShell/AgentProfileVisuals.swift` — existing shortcut-to-brand mapping and `AgentProfileIconView` should remain the icon-rendering path.
- `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift` — `WorkspaceTab` fields (`shortcutID`, `launchCommand`, `title`) define the input surface the resolver will consume.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — existing shortcut-identity fixtures can anchor fallback coverage.

### Dependent Files
- `Sources/NativeMacADE/AppShell/SessionTerminalSummaryBuilder.swift` — later summary composition depends on the shared resolver contract.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — future `SessionRowView` child rows will consume the same resolved identity.
- `Package.swift` — may need test-target dependency changes if direct AppShell helper tests are added.

### Related ADRs
- [ADR-003: Keep session-tab summary composition in AppShell](../adrs/adr-003.md) — fixes the resolver boundary in AppShell rather than Core.
- [ADR-004: Use event-driven factual status derived from existing metadata](../adrs/adr-004.md) — keeps identity resolution grounded in existing metadata only.
- [ADR-001: Scope V1 as inline session-row attention routing](../adrs/adr-001.md) — requires shared identity without broadening the surface.

## Deliverables
- A new shared AppShell resolver for terminal presentation data.
- Existing tab-strip terminal identity logic migrated to the resolver.
- Existing rename-placeholder terminal fallback logic migrated to the resolver.
- No regression in file-tab naming behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for terminal identity consistency across current consumers **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Custom tab title overrides shortcut and launch-command fallback.
  - [ ] `shortcutID` resolves the expected label and icon inputs for built-in and custom profile fixtures.
  - [ ] Unknown launch commands are humanized and fall back to terminal identity correctly.
  - [ ] Plain shell tabs with no title or command resolve to `Terminal` and the generic terminal icon path.
  - [ ] File tabs do not route through terminal presentation logic.
- Integration tests:
  - [ ] `TabItemView` and `TabRenameDraft` produce matching terminal fallback output for the same tab fixture.
  - [ ] Legacy restored terminal tabs with missing `shortcutID` still resolve stable fallback identity.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Terminal title, agent label, and icon fallback logic exist in one shared AppShell resolver.
- Existing tab-strip and rename-placeholder terminal behavior remain aligned for the same tab inputs.
