---
status: completed
title: "Define portable settings schema and stable built-in profile mapping"
type: backend
complexity: medium
dependencies: []
---

# Task 01: Define portable settings schema and stable built-in profile mapping

## Overview

This task establishes the public portable-settings contract for Atelier V1. It introduces the versioned config DTOs, apply-result model, and stable built-in profile identifiers that let the feature stay portable across machines without exposing internal UUIDs or raw persistence details.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The implementation MUST add a versioned `PortableSettingsConfig` document and section DTOs for portable appearance, behavior, default-profile selection, and managed keybinding overrides.
- 2. The implementation MUST add a `PortableSettingsApplyResult` model that can report applied sections, rejected sections, seeded-from-SQLite state, and missing-file state for startup and manual reload flows.
- 3. The implementation MUST define stable symbolic built-in profile identifiers for `plain`, `codex`, `claude`, and `opencode` without exposing raw `SessionShortcut` UUIDs in the external contract.
- 4. The implementation MUST keep runtime-only or local-only fields such as timestamps, override metadata, secrets, raw custom command definitions, and arbitrary custom profile content out of the portable schema.
- 5. The implementation SHOULD centralize built-in profile mapping helpers so the portable contract does not drift from the core built-in catalog and default-profile presentation logic.
</requirements>

## Subtasks
- [x] 1.1 Define the versioned portable config document shape and its supported top-level sections.
- [x] 1.2 Define the portable apply-result model needed by startup, reload, and diagnostics flows.
- [x] 1.3 Establish stable symbolic identifiers for the supported built-in default profiles and the no-default/plain-shell state.
- [x] 1.4 Define the portable keybinding override shape against managed command IDs only.
- [x] 1.5 Document and enforce which runtime-only and local-only fields are excluded from the external contract.

## Implementation Details

See the TechSpec sections **Core Interfaces**, **Data Models**, **Mapping Rules**, and **Technical Considerations → Key Decisions**. Keep the portable schema additive inside `NativeMacADECore`, preserve the approved built-in-only agent scope, and avoid leaking internal persistence details into the user-facing config contract.

### Relevant Files
- `Sources/NativeMacADECore/Workspace/PortableSettingsConfig.swift` — New home for the portable config DTOs, apply-result model, and symbolic built-in profile mapping.
- `Sources/NativeMacADECore/Workspace/AppPreferences.swift` — Current runtime settings root whose supported fields define most of the portable V1 surface.
- `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift` — Existing built-in `SessionShortcut` catalog that the symbolic default-profile mapping must target.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Current built-in shortcut lookup and default-profile handling that the new schema will eventually feed.
- `Sources/NativeMacADECore/Commands/AppCommandRegistry.swift` — Canonical managed command IDs and default keybindings that portable keybinding DTOs must align to.
- `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift` — Existing validation and built-in-profile test seam that should gain schema-aware coverage.

### Dependent Files
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — Later tasks will expose portable reload/path APIs that depend on these new shared types.
- `Sources/NativeMacADE/AppShell/ConfigModalAgentProfilesSection.swift` — The UI default-profile flow needs a stable portable mapping for built-ins versus plain shell.
- `Sources/NativeMacADE/AppShell/SessionTerminalPresentationResolver.swift` — Built-in profile identity helpers must not drift from terminal/session presentation behavior.
- `Sources/NativeMacADECore/Workspace/AgentProfilePresentation.swift` — Profile badges and built-in/custom distinctions depend on a stable core identity model.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Cross-file behavior should verify that the new symbolic mapping matches the built-in runtime catalog.

### Related ADRs
- [ADR-001: Single-Scope Personal Settings Config](adrs/adr-001.md) — Constrains the schema to personal-global portable settings only.
- [ADR-003: File-Authoritative Personal Config Projection](adrs/adr-003.md) — Requires a first-class external config artifact rather than raw SQLite export.
- [ADR-004: Stable Portable Config Schema With Built-In Agent Scope](adrs/adr-004.md) — Defines the stable DTO approach and the built-in-only agent portability boundary.

## Deliverables
- Versioned portable settings DTOs for the V1 contract.
- Shared symbolic built-in profile mapping for `plain`, `codex`, `claude`, and `opencode`.
- Portable apply-result types that downstream startup and reload flows can consume.
- Explicit exclusion rules for runtime-only and local-only fields in the external schema.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for built-in profile mapping and schema contract behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [x] JSON encode/decode round-trips a valid `PortableSettingsConfig` document without reordering or losing supported sections.
  - [x] Symbolic built-in identifiers map to the canonical `plain`, `codex`, `claude`, and `opencode` runtime targets without exposing UUIDs in the file format.
  - [x] Portable keybinding DTOs accept managed command IDs and reject unsupported command identifiers.
  - [x] Runtime-only metadata such as timestamps, override markers, and secret references do not appear in exported portable DTOs.
- Integration tests:
  - [x] A built-in default-profile selection mapped through the shared helper resolves the canonical built-in runtime target used for new session bootstrap.
  - [x] The `plain` portable default-profile symbol preserves the existing no-default/plain-shell runtime behavior and does not synthesize a fake `SessionShortcut`.
  - [x] Centralized built-in profile mapping remains consistent with the built-in catalog consumed by service- and presentation-layer code.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Atelier has a stable, versioned portable-settings schema that does not leak internal persistence details.
- Built-in default-profile portability is expressed through symbolic identifiers rather than UUIDs or custom command definitions.
- Downstream tasks can consume one shared apply-result and mapping contract instead of duplicating schema logic.
