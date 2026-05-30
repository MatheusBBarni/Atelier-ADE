# Task Memory: task_04.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement task 04: replace Nord-only runtime assumptions with a fixed AppTheme catalog (`dracula`, `onedark`, `catppuccin`, `cursor`), bind shell styling to `WorkspaceStore.appPreferences.themeID`, and apply terminal appearance changes live without changing stored launch intent.

## Important Decisions
- Pre-change baseline: shell chrome still forced `.preferredColorScheme(.dark)` and hard-coded `NordTheme.*`; terminal host still used `.nordDefault` for new surfaces and host views.
- `AppTheme` is the single runtime catalog and resolver. `WorkspaceStore.activeTheme` resolves `appPreferences.themeID` with the Cursor fallback; app shell and terminal host both read from that resolved theme.
- `TerminalHostController` owns one current `TerminalAppearance`; `updateAppearance(_:)` refreshes attached host views and embedded session drivers without allocating duplicate surfaces.

## Learnings
- SwiftPM coverage JSON includes vendored SwiftTerm files, which pulls the package-wide percentage below the task target. Filtering first-party `Sources/NativeMacADECore` files from `.build/arm64-apple-macosx/debug/codecov/NativeMacADE.json` reported 2,971/3,338 lines covered (89.0%).

## Files / Surfaces
- Added `Sources/NativeMacADECore/Theme/AppTheme.swift` and `Tests/NativeMacADECoreTests/AppThemeTests.swift`.
- Updated shell theme wiring in `Sources/NativeMacADE/AppShell/ContentView.swift`.
- Updated terminal appearance defaults and live refresh in `Sources/NativeMacADECore/Ghostty/GhosttyAdapter.swift` and `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift`.
- Updated preference/theme lookup in `Sources/NativeMacADECore/Workspace/AppPreferences.swift` and `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift`.
- Added/updated theme regression coverage in core and integration tests, including terminal host live refresh and launch-intent stability.

## Errors / Corrections
- Avoided treating raw SwiftPM package coverage as the task coverage signal because it includes the vendored SwiftTerm dependency; used first-party core source coverage instead.

## Ready for Next Run
- Before tracking updates, `swift test --enable-code-coverage` passed with 111 tests and first-party core coverage at 89.0%.
