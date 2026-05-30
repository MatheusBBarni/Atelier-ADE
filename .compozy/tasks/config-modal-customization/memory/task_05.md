# Task Memory: task_05.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement Task 05: main-window settings host, startup preference load before restore unblocks, and registry-driven managed app command bindings.
- Pre-change signal: `Sources/NativeMacADECore/Commands/AppCommandRegistry.swift`, `Tests/NativeMacADECoreTests/AppCommandRegistryTests.swift`, and `Sources/NativeMacADE/AppShell/ConfigModalView.swift` are absent; `ContentView` calls `restoreWorkspace()` without first loading preferences.

## Important Decisions
- Settings presentation is held in `AppShellState` and is shared by the app command and visible gear entry point; there is no separate Settings scene.
- Startup preference load is coordinated by `AppShellStartupCoordinator`, which invokes a shell callback after preference load/fallback and before restore so terminal appearance is applied before restored surfaces are recreated.
- Managed shortcut defaults and runtime resolution live in `AppCommandRegistry`; `AppCommandID.defaultKeybinding` delegates to that registry for compatibility.

## Learnings
- `ContentView`'s restore path must explicitly call `applyActiveTheme()` after preference load because restore creates terminal surfaces through the already-live `TerminalHostController`.
- SwiftUI command key equivalents need app-target conversion from persisted strings such as `upArrow`, `downArrow`, `+`, and `,` into `KeyEquivalent`.

## Files / Surfaces
- Added `Sources/NativeMacADECore/App/AppShellState.swift`, `Sources/NativeMacADECore/Commands/AppCommandRegistry.swift`, `Sources/NativeMacADE/AppShell/ConfigModalView.swift`, `Tests/NativeMacADECoreTests/AppCommandRegistryTests.swift`, and `Tests/NativeMacADECoreTests/AppShellStateTests.swift`.
- Modified `NativeMacADEApp`, `ContentView`, `WorkspaceCommandService`, `DefaultWorkspaceCommandService`, `AppPreferences`, `TerminalHostController`, `DefaultWorkspaceCommandServiceIntegrationTests`, and `TerminalHostIntegrationTests`.

## Errors / Corrections
- Fixed compile issues from the first focused run: exposed shell theme/color helpers across app-shell files, disambiguated `KeyEquivalent` creation, and made the startup-order test task return `Void`.

## Ready for Next Run
- Verification passed after final source changes: `swift test --enable-code-coverage` ran 123 tests with 0 failures, and `llvm-cov` reported 81.91% region coverage / 89.51% line coverage for source files excluding tests/build output.
