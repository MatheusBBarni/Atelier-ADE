---
status: completed
title: "Add XDG config locator and atomic portable settings file store"
type: backend
complexity: medium
dependencies:
  - task_01
---

# Task 02: Add XDG config locator and atomic portable settings file store

## Overview

This task creates the filesystem layer for portable settings. It gives the feature a predictable canonical config location plus safe read/write behavior, so Atelier can treat the portable file as a reliable cross-machine artifact instead of an ad hoc export.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The implementation MUST resolve the canonical config path from `$XDG_CONFIG_HOME/atelier/settings.json` first and fall back to `~/.config/atelier/settings.json` when `XDG_CONFIG_HOME` is unset.
- 2. The implementation MUST provide atomic read and write behavior for the portable settings document, including parent-directory creation for the canonical path.
- 3. The implementation MUST distinguish missing-file state from invalid-content failures and write failures so startup and reload flows can respond correctly.
- 4. The implementation MUST keep file IO out of the UI layer and package the config store as a reusable core seam for later service integration.
- 5. The implementation SHOULD support deterministic environment and filesystem test seams so path resolution and failure cases can be verified without live user-directory assumptions.
</requirements>

## Subtasks
- [x] 2.1 Define the canonical path-resolution contract for XDG-first portable settings storage.
- [x] 2.2 Add a dedicated core file-store seam that can load and save the versioned portable config document.
- [x] 2.3 Add missing-file detection and parent-directory bootstrap behavior for first-run and seed flows.
- [x] 2.4 Add atomic write behavior suitable for user-edited portable config files.
- [x] 2.5 Add automated coverage for path resolution, read/write success, and failure scenarios.

## Implementation Details

See the TechSpec sections **Portable Settings File Store**, **Storage Structures**, **Integration Points**, and **Testing Approach → Unit Tests**. Keep filesystem concerns in `NativeMacADECore`, follow existing file-service testing patterns where helpful, and avoid binding the store directly to app-layer views or SQLite-specific logic.

### Relevant Files
- `Sources/NativeMacADECore/Workspace/PortableSettingsFileStore.swift` — New core seam for canonical-path resolution, JSON reads, missing-file detection, and atomic writes.
- `Sources/NativeMacADECore/Workspace/PortableSettingsConfig.swift` — Portable DTO dependency that the file store must serialize and deserialize.
- `Sources/NativeMacADECore/Files/WorkspaceFileServices.swift` — Existing file-service patterns for injected `FileManager` behavior, directory creation, and safe blocking IO boundaries.
- `Sources/NativeMacADECore/Restore/RestoreCoordinator.swift` — Existing example of testable filesystem/path seams that can inform deterministic config-path handling.
- `Tests/NativeMacADECoreTests/WorkspaceFileAccessTests.swift` — Existing temp-directory and filesystem coverage patterns that fit this new store.
- `Tests/NativeMacADECoreTests/PortableSettingsFileStoreTests.swift` — Best home for new direct file-store coverage.

### Dependent Files
- `Sources/NativeMacADECore/App/AppDependencyContainer.swift` — Later service wiring will need to construct and inject the new file-store dependency.
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` — Startup bootstrap, seed, export, and reload flows will depend on this file-store seam.
- `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` — Public portable-config APIs will later depend on the file-store’s canonical URL behavior.
- `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift` — Integration coverage will need a real temp XDG directory backed by this store.

### Related ADRs
- [ADR-001: Single-Scope Personal Settings Config](adrs/adr-001.md) — Keeps the store focused on one personal-global config artifact.
- [ADR-003: File-Authoritative Personal Config Projection](adrs/adr-003.md) — Requires a canonical XDG-style config file with explicit file authority and atomic writes.

## Deliverables
- Canonical XDG-aware portable settings path-resolution logic.
- Core file-store seam for portable settings read/write and missing-file detection.
- Atomic file-write behavior and parent-directory bootstrap handling.
- Deterministic filesystem and environment coverage for the new store.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for real filesystem path resolution and round-trip behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [x] When `XDG_CONFIG_HOME` is set, the file store resolves `atelier/settings.json` under that directory.
  - [x] When `XDG_CONFIG_HOME` is unset, the file store falls back to `~/.config/atelier/settings.json`.
  - [x] Saving a valid portable config creates missing parent directories and writes a readable JSON document.
  - [x] Loading with no file returns a missing-file result instead of a decode or write failure.
  - [x] Invalid JSON content produces a decode failure that is distinct from the missing-file path.
- Integration tests:
  - [x] A portable config written to a temp XDG directory round-trips through the real filesystem with the expected canonical path.
  - [x] Repeated saves replace the existing document without leaving stale partial output at the canonical path.
  - [x] File-write failures from an unwritable temp location surface a real error instead of pretending the config was exported.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Atelier has one canonical portable-settings file location that is stable across startup, save, and reload flows.
- Portable settings reads and writes are handled by a dedicated core seam instead of app-layer code.
- Missing-file, invalid-content, and write-failure states are distinguishable for downstream orchestration.
