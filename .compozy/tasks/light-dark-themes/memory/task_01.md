# Task Memory: task_01.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement the theme-domain selection contract for task_01: reserved `system` selection, central effective resolver, stable concrete catalog ordering, `AppPreferences` selection helpers, and model/integration tests.

## Important Decisions
- Keep this slice in `AppTheme` and `AppPreferences`; defer UI/runtime shell adoption, command-service observability, and persistence repair details to later tasks unless existing model helpers require compatibility.
- The light/dark task docs do not enumerate additional new preset names. To satisfy the catalog-expansion and stronger-light-coverage requirements without adding a registry, add two conservative concrete light presets directly in `AppTheme`: `github-light` and `solarized-light`.
- Preserve `catppuccin` as the first light preset and `dracula` as the first dark preset so System mode maps light to Catppuccin Latte and dark to Dracula.

## Learnings
- No repo-local `AGENTS.md` or `CLAUDE.md` exists under `/Users/matheusbbarni/projects/another-ade`.
- Pre-change signal: `AppTheme` lacks `systemSelectionID`, `defaultSelectionID`, `supportedSelectionIDs`, `resolveEffective`, `firstLightPreset`, and `firstDarkPreset`; `AppPreferences.defaultThemeID` still points at `AppTheme.defaultID`.
- Final verification: `./scripts/run.sh test --enable-code-coverage` passed with 219 tests. `Sources/NativeMacADECore` coverage reported 87.85% line / 80.44% region; touched model files reported 96.88% line / 90.91% region.

## Files / Surfaces
- Source surfaces touched: `Sources/NativeMacADECore/Theme/AppTheme.swift`, `Sources/NativeMacADECore/Workspace/AppPreferences.swift`.
- Test surfaces touched: `Tests/NativeMacADECoreTests/AppThemeTests.swift`, `Tests/NativeMacADECoreTests/WorkspaceModelsTests.swift`, `Tests/NativeMacADEIntegrationTests/ThemeSelectionContractIntegrationTests.swift`.

## Errors / Corrections
- Self-review caught that the initial diff froze the existing catalog without adding new light coverage; corrected by adding `github-light` and `solarized-light` directly to `AppTheme.catalog`.

## Ready for Next Run
- Task 01 tracking is marked complete. Commit should include only task_01 light/dark tracking, memory, source, and test changes; unrelated project-landing-page changes are pre-existing and should stay out.
