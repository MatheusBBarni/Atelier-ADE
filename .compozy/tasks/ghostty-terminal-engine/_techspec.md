# Ghostty Terminal Engine TechSpec

## Executive Summary

Replace Atelier's current SwiftTerm-backed terminal path with Ghostty-backed terminal surfaces while preserving the existing `WorkspaceTerminalSurfaceManaging` contract used by session creation, tab creation, restore, close handling, metrics, and exit events.

The primary trade-off is a clean Ghostty-only runtime versus fallback safety. We will remove SwiftTerm once Ghostty covers the MVP baseline, which keeps product behavior honest but requires focused migration tests and manual terminal QA before release.

## System Architecture

### Component Overview

- `DefaultWorkspaceCommandService`: unchanged workspace orchestrator for project, session, tab, restore, close, metrics, and logs.
- `TerminalHostController`: owns tab-to-surface identity, host view attachment, focus, resize, close checks, release, appearance updates, and exit monitoring.
- `GhosttyAdapter`: Swift-facing adapter used by `TerminalHostController`.
- New Swift Ghostty wrapper target: app-facing native Ghostty runtime module for surface creation, native view access, lifecycle, and appearance mapping.
- `CGhostty`: low-level C interop and pinned-revision scaffolding retained under the Swift wrapper.
- `TerminalSurfaceHostNSView`: AppKit container for the Ghostty native view.

Data flow:
`WorkspaceTab` -> `GhosttyLaunchConfiguration` -> Swift Ghostty wrapper -> native Ghostty surface/view -> `TerminalSurfaceHostNSView`.

## Implementation Design

### Core Interfaces

```swift
@MainActor
public protocol GhosttySurfaceRuntime {
    func initializeIfNeeded() async throws
    func createSurface(configuration: GhosttyLaunchConfiguration) async throws -> GhosttySurfaceHandle
    func nativeView(for surface: GhosttySurfaceHandle) -> NSView?
    func focus(surface: GhosttySurfaceHandle)
    func resize(surface: GhosttySurfaceHandle, columns: Int, rows: Int)
    func canClose(surface: GhosttySurfaceHandle) async -> Bool
    func hasExited(surface: GhosttySurfaceHandle) async -> Bool
    func exitStatus(surface: GhosttySurfaceHandle) async -> Int32?
    func destroySurface(_ surface: GhosttySurfaceHandle)
}
```

### Data Models

- Reuse `WorkspaceTab`; no persistence schema change.
- Reuse `GhosttyLaunchConfiguration` for working directory, launch command, launch arguments, inherited surface metadata, and appearance.
- Keep `GhosttySurfaceHandle` as the app-owned terminal identity.
- Add wrapper-level native surface state only inside the Ghostty wrapper target.

### API Endpoints

Not applicable. This is a native macOS runtime change with no network API.

## Integration Points

- Ghostty native runtime through the new Swift wrapper target.
- `CGhostty` remains the low-level interop target and pinned revision scaffold.
- SwiftPM updates remove `SwiftTerm` after Ghostty coverage is complete and add the wrapper target dependency.

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
|---|---|---|---|
| `Package.swift` | modified | Dependency graph changes from SwiftTerm to Ghostty wrapper | Add wrapper target, remove SwiftTerm when ready |
| `TerminalHostController` | modified | Main runtime migration point | Remove `TerminalSessionDriver` path and host Ghostty view |
| `TerminalSurfaceHostNSView` | modified | Must attach/focus/layout native Ghostty view | Replace SwiftTerm-specific view state |
| `GhosttyAdapter` / runtime | modified | Needs real native surface lifecycle | Route through wrapper and preserve errors |
| `CGhostty` | modified | Becomes lower-level scaffolding under wrapper | Keep pin and native interop support |
| Workspace models/persistence | unchanged | Runtime swap should not affect stored tabs | No schema migration |
| Terminal tests | modified | SwiftTerm-specific tests become Ghostty host/launch tests | Rewrite affected tests |

## Testing Approach

### Unit Tests

- `GhosttyLaunchConfiguration` preserves working directory, command, arguments, and appearance.
- Launch translation preserves plain shell and agent profile behavior.
- `CGhosttyRuntime` and wrapper errors map to `GhosttyAdapterError`.
- `TerminalHostController` creates one surface per tab and releases it correctly.
- Focus, resize, close checks, appearance updates, and exit-status polling call the Ghostty runtime.

### Integration Tests

- Session creation and tab creation still create terminal surfaces through `DefaultWorkspaceCommandService`.
- Restore recreates Ghostty surfaces for terminal tabs and leaves file tabs isolated.
- Exit events still publish through `TerminalExitEventSource`.
- SwiftTerm-specific live tests are replaced with Ghostty-host attachment tests.
- Manual QA checklist covers interactive TUIs, shell behavior, rendering fidelity, and heavy output.

## Development Sequencing

### Build Order

1. Add the Swift Ghostty wrapper target and keep `CGhostty` as interop scaffolding - no dependencies.
2. Extend `GhosttyAdapter` to use the wrapper runtime and expose native view access - depends on step 1.
3. Extract launch metadata translation out of `TerminalSessionDriver` into a testable Swift type - depends on step 2.
4. Replace `TerminalHostController`'s SwiftTerm branch with Ghostty surface/view hosting - depends on steps 2 and 3.
5. Update host, adapter, restore, launch, and exit tests for the Ghostty path - depends on step 4.
6. Remove `TerminalSessionDriver`, SwiftTerm imports, and the SwiftTerm package dependency - depends on step 5.
7. Run manual correctness baseline QA and record pass/fail evidence - depends on step 6.

### Technical Dependencies

- A usable pinned Ghostty native integration surface for macOS.
- Native view lifecycle details from the Ghostty wrapper.
- Representative manual QA commands for the correctness baseline.

## Monitoring and Observability

- Preserve `terminal_surface_failed` with tab ID, session ID, and failure reason.
- Preserve `terminal_process_exited` with tab ID, session ID, and exit status.
- Keep terminal surface failure rate below 1 percent.
- Track launch-to-ready timing through existing metrics.
- Treat terminal-start failures and baseline regressions as release blockers.

## Technical Considerations

### Key Decisions

- Keep `WorkspaceTerminalSurfaceManaging` stable to avoid workspace-layer churn.
- Replace SwiftTerm in `TerminalHostController` instead of adding a terminal-engine selector.
- Add a Swift wrapper target for app-facing Ghostty APIs while retaining `CGhostty`.
- Preserve existing launch metadata and avoid persistence migration.
- Validate with focused automated tests plus manual baseline QA.

### Known Risks

- Native Ghostty view focus and resize behavior may differ from SwiftTerm.
- Launch translation can regress agent-specific behavior if existing overrides are missed.
- Manual QA must be concrete enough to catch TUI, rendering, shell, and heavy-output issues.
- Removing SwiftTerm removes the fallback path, so incomplete Ghostty behavior blocks release.

## Architecture Decision Records

- [ADR-001: Use Ghostty as the Atelier terminal while preserving the Atelier workflow](adrs/adr-001.md) - Product scope: Ghostty terminal, current Atelier workflow.
- [ADR-002: Define MVP terminal correctness baseline across common power-user workflows](adrs/adr-002.md) - Acceptance baseline and regression bar.
- [ADR-003: Replace the SwiftTerm terminal path inside TerminalHostController with Ghostty surfaces](adrs/adr-003.md) - Main technical migration point.
- [ADR-004: Remove SwiftTerm after Ghostty covers the MVP terminal baseline](adrs/adr-004.md) - Dependency removal decision.
- [ADR-005: Add a Swift-native Ghostty wrapper target and keep CGhostty as native interop scaffolding](adrs/adr-005.md) - Native boundary shape.
- [ADR-006: Preserve existing launch metadata and translate it into Ghostty launch configuration](adrs/adr-006.md) - Launch and persistence approach.
- [ADR-007: Validate Ghostty migration with manual baseline QA and focused runtime unit tests](adrs/adr-007.md) - Validation strategy.
