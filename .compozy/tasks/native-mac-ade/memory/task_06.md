# Task Memory: task_06.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot

- Build Task 06 terminal tab experience: replace placeholder terminal area with SwiftUI tab chrome plus AppKit-hosted Ghostty surfaces, preserving project -> session -> tab state, cwd launch behavior, Nord appearance, focus/resize/close/exit semantics, and required tests.

## Important Decisions

- Kept Task 06 within the current app-owned `CGhostty` shim constraint: the AppKit host seam attaches a host-managed `NSView` and `GhosttySurfaceHandle`, while real upstream surface mounting remains bounded by Task 02's outstanding libghostty artifact risk.
- `TerminalHostController` is the single lifecycle owner for tab surface caching, host-view mapping, focus, resize, close checks, release, and process-exit monitoring; `DefaultWorkspaceCommandService` can fall back to this manager when its own created-surface cache lacks a restored/host-created surface.
- SwiftUI `TerminalHostView` is keyed by selected tab ID and controller stale-view mapping cleanup prevents one reused `NSView` from being cached under multiple tab IDs.

## Learnings

- No `AGENTS.md` or `CLAUDE.md` files exist under the repository root.
- Current baseline before Task 06 implementation: `WorkspaceDetailView` renders `TerminalPlaceholderView`; `TabChromeView` is selection-only; `TerminalHostController` exists but is not bridged into SwiftUI.
- Oracle review found and fixes addressed lifecycle issues around stale NSView mapping, initial resize replay, and duplicate exit polling before final verification.

## Files / Surfaces

- Expected code surfaces: `Sources/NativeMacADE/AppShell/ContentView.swift`, `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift`, `Sources/NativeMacADECore/Ghostty/GhosttyAdapter.swift`, and command-service/terminal-host tests.
- Touched app/core surfaces: `Sources/NativeMacADE/AppShell/ContentView.swift`, `Sources/NativeMacADE/NativeMacADEApp.swift`, `Sources/NativeMacADECore/App/AppDependencyContainer.swift`, `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift`, `Sources/NativeMacADECore/Ghostty/GhosttyAdapter.swift`, `Sources/NativeMacADECore/TerminalHost/TerminalHostController.swift`.
- Touched tests: `Tests/NativeMacADECoreTests/DefaultWorkspaceCommandServiceTests.swift`, `Tests/NativeMacADEIntegrationTests/DefaultWorkspaceCommandServiceIntegrationTests.swift`, `Tests/NativeMacADEIntegrationTests/TerminalHostIntegrationTests.swift`.

## Errors / Corrections

- Corrected the first host pass after review: added tab-keyed SwiftUI host identity, stale host-view mapping cleanup, current-bounds resize replay after attach, centralized exit monitoring in `TerminalHostController`, and removed the view-owned exit polling path.

## Ready for Next Run

- Fresh verification after final cleanup: `swift test --enable-code-coverage` passed 41 tests across 9 suites, and coverage reported 90.55% line coverage (2520/2783).
- Caveat to preserve: Task 06 is acceptable under the current `CGhostty` shim, but not proof of a real upstream `libghostty` render surface until Task 02's artifact/linking risk is resolved.
