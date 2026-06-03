---
status: completed
title: "Implement portable settings projection, omission rules, and section validation"
type: backend
complexity: high
dependencies:
  - task_01
---

# Task 03: Implement portable settings projection, omission rules, and section validation

## Overview

This task turns the portable config schema into usable runtime behavior. It defines how supported config sections map into `AppPreferences`, how invalid sections are rejected without blocking unrelated valid ones, and how local-only settings stay out of the portable contract.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The implementation MUST map the supported portable sections to the current runtime preferences surface for `themeID`, `terminalFontSize`, `focusWorkspaceEnabled`, built-in default-profile selection, and managed keybinding overrides.
- 2. The implementation MUST validate portable config at section granularity so valid sections can apply even when unrelated sections are rejected.
- 3. The implementation MUST move portable-settings validation for theme selection, terminal font-size bounds, default-profile scope, and managed keybindings into core logic instead of relying on UI-only checks.
- 4. The implementation MUST omit unsupported local-only state such as custom default profiles, custom profile definitions, secret references, and raw launch-command details from portable export.
- 5. The implementation SHOULD keep the translation and validation rules centralized in core helpers that downstream startup, reload, and save flows can reuse.
</requirements>

## Subtasks
- [x] 3.1 Define the mapping between each supported portable config section and the effective `AppPreferences` fields.
- [x] 3.2 Add grouped validation rules for portable appearance, behavior, default-profile, and keybinding sections.
- [x] 3.3 Add export omission rules for local-only state that must not become part of the portable contract.
- [x] 3.4 Add section-level diagnostics that identify which sections were applied and which were rejected.
- [x] 3.5 Add automated coverage for valid, invalid, mixed-validity, and local-only omission scenarios.

## Implementation Details

See the TechSpec sections **Error handling conventions**, **Mapping Rules**, **Testing Approach**, and **Technical Considerations → Known Risks**. Keep this work inside the core mapping and validation layer, preserve the approved built-in-only default-profile scope, and make the current portable `terminalFontSize` contract consistent with core validation rather than UI clamping alone.

### Relevant Files
- `Sources/NativeMacADECore/Workspace/PortableSettingsConfig.swift` — Portable DTOs and the natural home for section-level projection and diagnostics helpers.
- `Sources/NativeMacADECore/Workspace/AppPreferences.swift` — Current runtime preferences model whose supported fields need portable-aware validation helpers.
- `Sources/NativeMacADECore/Commands/AppCommandRegistry.swift` — Canonical managed command IDs and grouped keybinding validation logic for the portable keybinding section.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Existing settings validation and default-profile repair logic that should consume the new projection helpers.
- `Sources/NativeMacADECore/Theme/AppTheme.swift` — Supported theme selection IDs and runtime theme semantics that appearance validation must respect.
- `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift` — Built-in `SessionShortcut` catalog used for portable default-profile mapping and custom-profile omission rules.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — Current core validation seam that should gain portable section-apply coverage.

### Dependent Files
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — Validation failure surfaces may need to represent new portable-section errors or diagnostics.
- `Sources/NativeMacADE/AppShell/ConfigModalAppearanceAndShortcutsSection.swift` — UI font-size and keybinding flows should rely on core validation once it exists.
- `Sources/NativeMacADE/AppShell/ConfigModalAgentProfilesSection.swift` — Default-profile UI behavior depends on built-in-only portable mapping and custom-profile omission rules.
- `Sources/NativeMacADE/NativeMacADEApp.swift` — Managed keybindings consumed at runtime must remain compatible with projected portable overrides.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Cross-boundary section apply behavior should be verified against the real service/persistence path.

### Related ADRs
- [ADR-003: File-Authoritative Personal Config Projection](adrs/adr-003.md) — Requires one shared projection path from file-backed config into runtime state.
- [ADR-004: Stable Portable Config Schema With Built-In Agent Scope](adrs/adr-004.md) — Constrains default-profile portability to built-ins and excludes custom profile definitions.
- [ADR-005: Section-Granularity Partial Apply With Diagnostics](adrs/adr-005.md) — Requires grouped section validation and explicit rejected-section diagnostics.

## Deliverables
- Core projection helpers between portable config sections and `AppPreferences`.
- Section-level validation and apply-diagnostics behavior for supported portable settings.
- Export omission rules for local-only profile state and other unsupported fields.
- Core enforcement of portable theme, font-size, default-profile, and keybinding constraints.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for mixed-validity and portable-section application behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Unknown theme IDs in the portable appearance section are rejected without mutating unrelated valid sections.
  - [x] Out-of-range portable `terminalFontSize` values are rejected in core validation rather than silently accepted from a file edit.
  - [x] Duplicate or empty managed keybinding overrides reject the keybindings section as a unit.
  - [x] `plain`, `codex`, `claude`, and `opencode` portable default-profile values map correctly, while custom-profile identifiers are rejected or omitted from portable export.
  - [x] Exporting runtime preferences with a custom default profile omits the portable default-profile field instead of serializing local-only command state.
- Integration tests:
  - [x] A mixed-validity portable config applies valid appearance or behavior sections while reporting rejected default-profile or keybinding sections explicitly.
  - [x] Successfully projected portable sections persist back through the `AppPreferences` runtime cache without clobbering unrelated local-only settings.
  - [x] Portable keybinding projection produces the same effective runtime shortcuts consumed by the managed app-command layer.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Supported portable settings map cleanly into `AppPreferences` through one shared core translation layer.
- Invalid sections produce explicit diagnostics without blocking independent valid sections.
- Local-only profile data and other unsupported fields never leak into the portable export contract.
