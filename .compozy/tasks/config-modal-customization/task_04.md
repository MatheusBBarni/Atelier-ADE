---
status: pending
title: "Introduce runtime theme catalog and live terminal appearance"
type: frontend
complexity: high
dependencies:
  - task_01
  - task_03
---

# Task 04: Introduce runtime theme catalog and live terminal appearance

## Overview
This task replaces the app’s Nord-only runtime assumptions with a fixed persisted theme catalog containing Dracula, OneDark, Catppuccin, and Cursor. It updates both SwiftUI chrome and terminal appearance immediately without changing restore semantics or retroactively mutating stored session launch intent.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- 1. The implementation MUST introduce a small fixed theme catalog with stable persisted IDs for `dracula`, `onedark`, `catppuccin`, and `cursor`, plus a shared shell-plus-terminal runtime representation.
- 2. The implementation MUST resolve the active theme from persisted app preferences with a safe default fallback.
- 3. The implementation MUST remove the root hard-coded dark/Nord shell assumptions so supported light themes can affect app chrome immediately.
- 4. The implementation MUST apply the active terminal appearance to both new surfaces and already attached host views.
- 5. The implementation SHOULD centralize theme lookup so shell views and terminal hosting read from one runtime source of truth.
- 6. The implementation SHOULD seed `cursor` as the default persisted theme while broadening behavior beyond Nord-only assumptions.
</requirements>

## Subtasks
- [ ] 4.1 Define the runtime theme catalog and default-fallback contract.
- [ ] 4.2 Convert shell styling from direct Nord-only token usage to active-theme lookups.
- [ ] 4.3 Thread the current terminal appearance into new surface creation and live host-view refresh.
- [ ] 4.4 Bind active theme resolution to observed persisted preferences.
- [ ] 4.5 Add regression coverage for theme lookup, fallback behavior, and live runtime updates.

## Implementation Details
See the TechSpec sections **Theme Runtime**, **Data Flow**, **Testing Approach**, and **Known Risks**. Keep the theme system small and curated; do not introduce a generalized theming platform or extra persistence layers.

### Relevant Files
- `Sources/NativeMacADECore/Theme/NordTheme.swift` — Current single-theme baseline that must evolve into a runtime theme model.
- `Sources/NativeMacADECore/Theme/AppTheme.swift` — Likely new home for the fixed V1 theme catalog and shared runtime representation.
- `Sources/NativeMacADE/AppShell/ContentView.swift` — Root shell still forces `.dark` and uses hard-coded Nord tokens throughout the chrome.
- `Sources/NativeMacADECore/Ghostty/GhosttyAdapter.swift` — `GhosttyLaunchConfiguration` and `TerminalAppearance` currently default to `.nordDefault`.
- `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift` — Existing host views and surfaces are all seeded from Nord and must switch live.
- `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` — Observed preferences source for the active theme ID.
- `Tests/NativeMacADECoreTests/AppThemeTests.swift` — Best fit for catalog lookup and fallback coverage.
- `Tests/NativeMacADEIntegrationTests/TerminalHostIntegrationTests.swift` — Best fit for live terminal appearance behavior.

### Dependent Files
- `Sources/NativeMacADE/NativeMacADEApp.swift` — Later settings host work depends on a live theme being available at app scope.
- `Sources/NativeMacADE/AppShell/ConfigModalView.swift` — Later appearance UI depends on stable theme IDs and labels.
- `Sources/NativeMacADECore/App/AppDependencyContainer.swift` — Theme-aware terminal host wiring flows through the live dependency container.
- `Tests/NativeMacADECoreTests/NordThemeTests.swift` — Existing Nord-only assertions will need to broaden to catalog behavior.

### Related ADRs
- [ADR-001: Agent-First Scope for Config Modal Personalization](adrs/adr-001.md) — Keeps theme work narrow and secondary to agent control.
- [ADR-002: Guided Control Center Product Approach for Config Modal Customization](adrs/adr-002.md) — Requires a polished theme set that feels complete enough for switchers.
- [ADR-004: SQLite-Centered Global Preferences Layer](adrs/adr-004.md) — Persisted theme choice must come from shared app preferences.
- [ADR-006: Limited Keybinding Scope and Immediate Preference Application](adrs/adr-006.md) — Defines immediate application behavior for theme changes.

## Deliverables
- Fixed runtime `AppTheme` catalog with stable IDs for Dracula, OneDark, Catppuccin, and Cursor, plus a seeded default.
- Shell theme resolution driven by observed app preferences instead of hard-coded Nord-only values.
- Live terminal appearance updates for new and attached terminal hosts.
- Updated unit and integration coverage for theme lookup, fallback, and runtime behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for theme switching and terminal appearance **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Known theme IDs `dracula`, `onedark`, `catppuccin`, and `cursor` resolve to the correct catalog entries.
  - [ ] Unknown theme IDs fall back to the default theme without crashing or mutating unrelated state.
  - [ ] `GhosttyLaunchConfiguration` preserves launch metadata while honoring an injected non-default `TerminalAppearance`.
  - [ ] Theme helper logic updates background, text, and cursor palette values when the active theme changes.
- Integration tests:
  - [ ] Loading each saved non-default theme from the supported catalog updates root shell styling immediately, including light-versus-dark color-scheme behavior.
  - [ ] Changing theme after a host view exists updates that host view without creating a duplicate terminal surface.
  - [ ] Creating a new tab after a theme change passes the new `TerminalAppearance` to the terminal adapter.
  - [ ] Theme swaps do not mutate persisted session or tab launch intent.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Supported light and dark themes apply immediately to shell chrome and terminal hosts.
- Unknown or stale theme IDs fall back safely to the default theme.
- No existing restore or tab-launch behavior regresses while theming becomes runtime-driven.
