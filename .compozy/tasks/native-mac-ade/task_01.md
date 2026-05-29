---
status: pending
title: "Scaffold native macOS app workspace"
type: infra
complexity: high
dependencies: []
---

# Task 01: Scaffold native macOS app workspace

## Overview
Create the greenfield macOS application scaffold that every later task will build on. This task establishes the single app target, test bundles, root SwiftUI shell, and minimal folder/layout conventions required by the TechSpec without over-designing the repo.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. MUST create a single native macOS app target and matching unit/integration test targets for V1.
- 2. MUST establish a minimal app-local source layout that supports the SwiftUI shell, AppKit terminal hosting, persistence, restore, and command services.
- 3. MUST wire a root SwiftUI application entry point and workspace scene shell that later tasks can extend without restructuring the repo.
- 4. MUST avoid introducing extra packages, frameworks, or modules beyond what the TechSpec requires for V1.
- 5. SHOULD add baseline app resources and repo ignores needed for a clean native macOS development workflow.
</requirements>

## Subtasks
- [ ] 1.1 Create the Xcode project, app target, and the two test bundles required by the TechSpec.
- [ ] 1.2 Add the initial source and resource folders for the app shell, feature UI, persistence, terminal hosting, restore, and shared support code.
- [ ] 1.3 Add the root SwiftUI app entry and a placeholder workspace scene that can host the sidebar and main content later.
- [ ] 1.4 Add baseline build settings, app resources, and repo ignore rules required for a native macOS project.
- [ ] 1.5 Add build-smoke tests that verify the scaffold compiles and launches the root shell successfully.

## Implementation Details
Create the baseline macOS project described in the TechSpec "Development Sequencing > Build Order" step 1 and respect the minimal app-local layering in TechSpec "System Architecture > Component Overview". Keep the scaffold aligned with ADR-003 so later tasks can add feature code without reorganizing the project structure.

### Relevant Files
- `AnotherADE.xcodeproj/project.pbxproj` — Defines the single app target and test bundles.
- `AnotherADE/App/AnotherADEApp.swift` — Native macOS app entry point.
- `AnotherADE/App/WorkspaceScene.swift` — Root SwiftUI workspace shell for later sidebar/session/tab composition.
- `AnotherADE/App/DependencyContainer.swift` — Minimal dependency wiring entry for later services and stores.
- `AnotherADE/Resources/Assets.xcassets` — Baseline asset catalog and theme resource home.
- `AnotherADETests/` — Unit test bundle root for domain and persistence tests.
- `AnotherADEIntegrationTests/` — Integration test bundle root for Ghostty host and restore flows.

### Dependent Files
- `AnotherADE/Terminal/Ghostty/` — Task 02 will attach the pinned Ghostty boundary to this scaffold.
- `AnotherADE/Workspace/` — Task 03 and task 04 will add domain models, store, and command services here.
- `AnotherADE/Features/Projects/` — Task 05 will implement the persistent project sidebar.
- `AnotherADE/Features/Tabs/` — Task 06 will add tab chrome into the app shell created here.
- `AnotherADE/Restore/` — Task 07 will plug restore bootstrap into the app lifecycle defined here.

### Related ADRs
- [ADR-003: Use a SwiftUI App Shell with AppKit Terminal Hosting](adrs/adr-003.md) — Sets the app shell and layering direction for the scaffold.
- [ADR-004: Embed Full libghostty Surfaces Inside the App](adrs/adr-004.md) — Requires the scaffold to leave room for an app-owned Ghostty boundary.
- [ADR-001: Session-First Native macOS ADE Scope for V1](adrs/adr-001.md) — Constrains V1 to the project -> session -> tab model.
- [ADR-002: Adopt a Workflow-Speed-First PRD for V1](adrs/adr-002.md) — Keeps the scaffold centered on the workflow shell rather than broader IDE scope.

## Deliverables
- A compilable macOS Xcode project with one app target and two test bundles.
- Root SwiftUI app entry, workspace scene shell, and minimal dependency container.
- Baseline folder structure, app resources, and repo ignore rules for the greenfield app.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for scaffold launch/build smoke behavior **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] App dependency container initializes without requiring feature implementations.
  - [ ] Root workspace scene can be instantiated with placeholder state without runtime errors.
  - [ ] Baseline app configuration exposes the expected target names and test bundle wiring.
- Integration tests:
  - [ ] Clean build of the app target succeeds with the new scaffold.
  - [ ] Launching the app opens the root workspace shell scene without crashing.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The repo contains a single native macOS app scaffold aligned with the TechSpec.
- Later tasks can add feature code without restructuring the app target or folder layout.
