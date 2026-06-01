---
status: pending
title: Theme selection model and catalog updates
type: backend
complexity: medium
dependencies: []
---

# Task 01: Theme selection model and catalog updates

## Overview

This task establishes the core theme-domain contract that all later work depends on. It introduces the reserved `system` selection semantics, centralizes effective theme resolution in the existing theme domain, and expands the curated preset catalog without creating new registries, packages, or persistence structures.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST add a reserved `system` appearance selection contract in the existing theme domain while keeping `AppTheme` as the catalog of concrete presets only.
2. MUST centralize selection-ID plus runtime-scheme resolution in the Theme domain and codify the first-light and first-dark preset mapping used by System mode.
3. MUST expand the curated preset catalog in `AppTheme` directly and preserve stable preset IDs and ordering required by the TechSpec.
4. MUST keep V1 aligned with ADR-004 by avoiding any new registry, plugin model, external theme manifest, or editor-specific preset mapping.
</requirements>

## Subtasks
- [ ] 1.1 Add the reserved System-selection constants and supported-selection helpers in the existing theme domain.
- [ ] 1.2 Add the effective-theme resolver that maps persisted selection plus runtime light/dark scheme to a concrete `AppTheme`.
- [ ] 1.3 Freeze and document the curated preset ordering contract, including the first-light and first-dark fallback behavior.
- [ ] 1.4 Expand the curated `AppTheme.catalog` with the approved V1 presets while preserving stable identifiers.
- [ ] 1.5 Add focused model-level test coverage for resolver behavior, supported selection IDs, and catalog-order guarantees.

## Implementation Details

Keep all theme-selection logic inside the existing theme domain and model layer described in the TechSpec sections **System Architecture → Theme Domain** and **Implementation Design → Data Models**. This task should not modify UI flow, persistence schema, or runtime shell wiring beyond what is necessary to define the shared contract consumed later.

### Relevant Files
- `Sources/NativeMacADECore/Theme/AppTheme.swift` — Primary home for the concrete preset catalog, selection constants, and effective-theme resolver.
- `Sources/NativeMacADECore/Workspace/AppPreferences.swift` — Holds the persisted `themeID` model contract and selection-support helpers.
- `Tests/NativeMacADECoreTests/AppThemeTests.swift` — Best unit-test home for resolver behavior, supported selection IDs, and catalog ordering assertions.
- `Tests/NativeMacADECoreTests/WorkspaceModelsTests.swift` — Useful home for `AppPreferences` value-semantic and default-contract assertions.
- `.compozy/tasks/light-dark-themes/_techspec.md` — Authoritative reference for the theme-domain additions, exclusions, and sequencing.

### Dependent Files
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — Runtime consumers currently assume concrete-only theme resolution and will depend on the new resolver contract.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Validation and repair logic depends on the widened selection model.
- `Sources/NativeMacADE/AppShell/ConfigModalAppearanceAndShortcutsSection.swift` — Later UI work depends on the final catalog ordering and selection IDs defined here.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Runtime appearance application will later consume the effective-theme resolver from this task.
- `Tests/NativeMacADEIntegrationTests/TerminalHostIntegrationTests.swift` — Later runtime integration coverage depends on the concrete theme-resolution contract established here.

### Related ADRs
- [ADR-002: Use a Settings-First Appearance Baseline with System as the Lead Choice](../adrs/adr-002.md) — Establishes System as the lead visible option.
- [ADR-003: Persist System Appearance as a Reserved Theme Selection](../adrs/adr-003.md) — Defines the reserved `system` selection contract.
- [ADR-004: Keep V1 Theme Expansion Inside the Existing Catalog and Generic Editor Mapping](../adrs/adr-004.md) — Requires catalog expansion inside `AppTheme` and no broader theming layer.
- [ADR-005: Centralize Effective Theme Resolution in the Theme Domain](../adrs/adr-005.md) — Requires a shared theme-domain resolver for runtime consumers.

## Deliverables
- Updated `AppTheme` domain contract with reserved System-selection semantics and effective-theme resolution.
- Curated preset catalog updates with stable IDs and explicit first-light / first-dark ordering.
- Supporting `AppPreferences` selection-model updates required by the core contract.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for theme selection contract compatibility **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `AppTheme.resolveEffective(selectionID:systemScheme:)` returns the selected concrete light preset when a light preset ID is provided.
  - [ ] `AppTheme.resolveEffective(selectionID:systemScheme:)` returns the selected concrete dark preset when a dark preset ID is provided.
  - [ ] `AppTheme.resolveEffective(selectionID:systemScheme:)` returns the first light preset when `selectionID = system` and runtime scheme is light.
  - [ ] `AppTheme.resolveEffective(selectionID:systemScheme:)` returns the first dark preset when `selectionID = system` and runtime scheme is dark.
  - [ ] `AppTheme.supportedSelectionIDs` includes `system` and all concrete preset IDs without duplicates.
  - [ ] `AppPreferences` selection-model helpers accept `system` and preserve stable value semantics.
- Integration tests:
  - [ ] Existing concrete preset IDs still resolve to the same `AppTheme` instances after catalog expansion.
  - [ ] The curated catalog order keeps the intended first light and first dark presets used by System mode.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The codebase has one central theme-domain resolver for persisted selection plus runtime scheme.
- `system` is a first-class selection contract without adding new persistence schema or theme-loading abstractions.
