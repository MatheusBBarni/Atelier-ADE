# Single-Tab Guardrail

## Executive Summary

This TechSpec implements the PRD’s **Focus Workspace Preference**, **Single-Surface Guardrails**, **Blocked-Action Experience**, **In-Product Framing and Discoverability**, and **Restore and Resume Clarity** by extending the existing `AppPreferences` + `WorkspaceCommandService` architecture instead of introducing a new mode subsystem. The feature will be stored as an app-global boolean preference, enforced in `DefaultWorkspaceCommandService`, and surfaced through focused UI affordances in Settings, the active context banner, the tab chrome, and app commands.

The core technical trade-off is **state preservation over a strict global invariant**. The chosen approach keeps existing multi-tab sessions intact and applies the policy only to future commands. That reduces destructive reconciliation and restore complexity, but it means Focus Workspace is not a literal “one tab everywhere” rule. Technically, the invariant becomes: **at most one terminal tab plus one optional file tab per session for future actions while the preference is enabled**.

## System Architecture

### Component Overview

**1. Preferences and startup**
- `AppPreferences` remains the single source of truth for the feature flag.
- `AppShellStartupCoordinator.run(...)` already loads preferences before restore and remains the startup ordering boundary.
- `SQLiteWorkspaceMetadataStore` and `WorkspaceMigrations` persist the new setting with a v6 schema migration.

**2. Shared policy evaluation**
- Add a small pure helper in `NativeMacADECore` named `FocusWorkspacePolicy` plus a tiny derived state model such as `FocusWorkspaceSessionState`.
- The helper evaluates current session state from:
  - `AppPreferences.focusWorkspaceEnabled`
  - visible terminal/file tabs in the selected session
  - optional file-open intent details
- The helper remains side-effect free and does not mutate store state.

**3. Command-layer enforcement**
- `DefaultWorkspaceCommandService` remains the mutation owner.
- It will call the shared policy helper from:
  - `createTab(sessionID:)`
  - `createPlainTab(sessionID:)`
  - `createDefaultAgentTab(sessionID:)`
  - `createAgentTab(sessionID:shortcutID:)`
  - `openFileTab(sessionID:path:)`
- `restoreWorkspace()` will not prune or normalize legacy sessions. It restores current metadata unchanged, then future commands apply the policy.

**4. Shell/UI behavior**
- `ConfigModalView` gains a dedicated Focus Workspace settings section rather than folding this into Appearance/Shortcuts.
- `ActiveContextBanner` gains a lightweight active-state cue so the focused experience is visible without adding a heavy overlay.
- `TabChromeView` conditionally hides the plus affordance and may collapse or omit the row only when the selected session has a single visible tab. If the session has a terminal tab plus a file tab, or is a grandfathered legacy multi-tab session, the row remains visible for navigation.
- `NativeMacADEApp` conditionally hides tab-creation menu items where the shell can determine they would be disallowed.
- `ContentView` continues to use `UserMessage` alerts for blocked actions, but the message content becomes explicit and feature-specific.

**5. Observability and diagnostics**
- MVP adds only local observability.
- `PerformanceMetrics` and `WorkspaceLogger` record:
  - preference enable/disable actions
  - blocked terminal-tab creation attempts
  - blocked second-file-tab attempts
- No new analytics sink or network pipeline is introduced.

## Implementation Design

### Core Interfaces

The policy should be shared as a pure contract even though the production code will be implemented in Swift:

```go
type FocusWorkspaceSessionState struct {
    Enabled      bool
    TerminalTabs int
    FileTabs     int
    VisibleTabs  int
}

type FocusWorkspacePolicy interface {
    CanCreateTerminal(FocusWorkspaceSessionState) error
    CanOpenFile(FocusWorkspaceSessionState, sameFile bool) error
}
```

Implementation notes:
- The concrete Swift type should stay small and local to `NativeMacADECore`.
- `DefaultWorkspaceCommandService` is the only mutation owner.
- SwiftUI views may consult the same helper for affordance visibility, but must never enforce correctness independently.

### Data Models

**Modified persisted model**
- `AppPreferences`
  - add `focusWorkspaceEnabled: Bool`
  - default: `false`

**Schema change**
- `app_preferences`
  - add `focus_workspace_enabled INTEGER NOT NULL DEFAULT 0 CHECK (focus_workspace_enabled IN (0, 1))`

**New in-memory helper types**
- `FocusWorkspaceSessionState`
  - derived, not persisted
  - fields:
    - `enabled`
    - `terminalTabCount`
    - `fileTabCount`
    - `visibleTabCount`
    - optional `hasLegacyOverflow` convenience flag
- `FocusWorkspaceViolation`
  - enum used by command-service errors
  - minimum cases:
    - `additionalTerminalTabBlocked`
    - `additionalFileTabBlocked`

**Modified command error surface**
- `WorkspaceCommandError`
  - add `focusWorkspaceRejected(FocusWorkspaceViolation)`

**No persisted model changes**
- `WorkspaceSession`
- `WorkspaceTab`
- `RestoreSnapshot`

The future-only policy means no session-level exemption flags, no restore tags, and no normalization metadata are required.

### API Endpoints

This feature introduces **no network endpoints**. The relevant API surface is the in-process command service.

| Surface | Signature | Change |
| --- | --- | --- |
| Preferences load | `loadAppPreferences() async throws -> AppPreferences` | Returns `focusWorkspaceEnabled` |
| Preferences save | `saveAppPreferences(_ preferences: AppPreferences) async throws` | Persists the flag and records enable/disable metrics/logs |
| Terminal tab creation | `createTab`, `createPlainTab`, `createDefaultAgentTab`, `createAgentTab` | Throw `focusWorkspaceRejected(.additionalTerminalTabBlocked)` when Focus Workspace already has a terminal tab in that session |
| File tab open | `openFileTab(sessionID:path:) async throws -> WorkspaceTab` | Reuse same-file tab, allow first file tab, reject later different-file opens when a file tab already exists under Focus Workspace |
| Restore | `restoreWorkspace() async throws -> RestoreWorkspaceResult` | Restores unchanged metadata; does not auto-collapse or normalize legacy sessions |

## Integration Points

Not applicable for external systems. This feature integrates only with existing in-process modules: preferences, command service, persistence, restore, shell composition, and local observability.

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
|-----------|-------------|---------------------|-----------------|
| `Sources/NativeMacADECore/Workspace/AppPreferences.swift` | modified | Add persisted app-global feature flag; low risk if defaults remain stable | Add `focusWorkspaceEnabled` and update initializer/defaults |
| `Sources/NativeMacADECore/Persistence/WorkspaceMigrations.swift` | modified | Schema migration touches startup-critical metadata; medium risk | Add v6 migration and repair path for the new column |
| `Sources/NativeMacADECore/Persistence/SQLiteWorkspaceMetadataStore.swift` | modified | Query/save path must stay in lockstep with schema; medium risk | Extend load/save SQL and decoding/encoding |
| `Sources/NativeMacADECore/Workspace/FocusWorkspacePolicy.swift` | new | Small shared helper prevents policy drift; low risk | Add pure helper and isolated tests |
| `Sources/NativeMacADECore/Commands/WorkspaceCommandService.swift` | modified | Public command error surface changes; low risk | Add focus rejection error case only |
| `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift` | modified | Main correctness boundary for create/open flows; high risk | Enforce terminal/file allowance matrix, log blocked attempts, preserve restore behavior |
| `Sources/NativeMacADECore/Workspace/WorkspaceStore.swift` | modified | Read-only derived state may be useful for views; low risk | Add small convenience helpers only if they remove duplication |
| `Sources/NativeMacADE/AppShell/ConfigModalView.swift` + new focus section view | modified/new | Settings discoverability and copy are part of MVP scope; medium risk | Add dedicated Focus Workspace section and friendly copy |
| `Sources/NativeMacADE/AppShell/ContentView.swift` | modified | Affects tab chrome, active cue, and blocked-action messaging; medium risk | Hide blocked affordances where possible, keep row visible when needed, map focus errors to alert copy |
| `Sources/NativeMacADE/NativeMacADEApp.swift` | modified | Menu command visibility changes while feature is active; medium risk | Conditionally hide disallowed tab-creation commands |
| `Sources/NativeMacADECore/Observability/PerformanceMetrics.swift` | modified | Local pilot metrics expand slightly; low risk | Add counts for enable/disable and focus rejections |
| `Tests/NativeMacADECoreTests` / `Tests/NativeMacADEIntegrationTests` | modified/new | Feature needs regression coverage across migration, service policy, and restore; medium risk | Add focused unit and integration tests |

## Testing Approach

### Unit Tests

**Policy helper tests**
- Add a dedicated `FocusWorkspacePolicyTests.swift`.
- Validate the allowed-state matrix:
  - focus off => current behavior unchanged
  - focus on + no tabs => first terminal allowed
  - focus on + one terminal => new terminal blocked
  - focus on + one terminal + no file => first file allowed
  - focus on + one terminal + one file => different-file open blocked
  - same-file reopen => existing file tab reused

**Command service tests**
- Extend `DefaultWorkspaceCommandServiceTests.swift` for:
  - blocked `createTab`
  - blocked `createPlainTab`
  - blocked `createDefaultAgentTab`
  - blocked `createAgentTab`
  - allowed first file open under focus
  - blocked second different-file open under focus
  - no unintended mutation of `tabs`, `restore_snapshot`, or surfaces when blocked
  - save/load behavior for the new preference
  - logging and metrics emission for blocked attempts

**Persistence tests**
- Extend `SQLiteWorkspaceMetadataStoreTests.swift` for:
  - round-trip of `focusWorkspaceEnabled`
  - missing-row default behavior
  - v5 → v6 migration behavior

### Integration Tests

**Startup and restore**
- Extend `AppShellStateTests.swift` to ensure preferences still load before restore with the new field present.
- Extend `RestoreCoordinatorIntegrationTests.swift` or adjacent restore integration coverage to verify:
  - focus-enabled restore does not collapse legacy multi-tab sessions
  - restore of compliant terminal+file sessions remains unchanged
  - future commands after restore obey the policy

**Shell behavior**
- If existing view-test infrastructure remains absent, keep automated shell coverage light and supplement with manual verification for:
  - settings section visibility
  - hidden menu/tab-bar affordances
  - focus rejection alert copy
  - active-state cue rendering

## Development Sequencing

### Build Order

1. **Persist the feature flag** — add `focusWorkspaceEnabled` to `AppPreferences`, update `WorkspaceMigrations` to v6, and extend `SQLiteWorkspaceMetadataStore`; no dependencies.
2. **Add shared policy types** — add `FocusWorkspaceSessionState`, `FocusWorkspaceViolation`, and `FocusWorkspacePolicy`; depends on step 1.
3. **Enforce the policy in core commands** — update `WorkspaceCommandError` and `DefaultWorkspaceCommandService` create/open flows plus future-only restore behavior; depends on steps 1-2.
4. **Update shell composition and settings UI** — add the dedicated settings section, active-state cue, tab-row/plus-button logic, menu visibility, and focus-specific alert mapping; depends on steps 1-3.
5. **Extend local observability** — add metrics/log fields for enable/disable and blocked attempts; depends on steps 1-3.
6. **Add regression coverage** — implement unit and integration tests across policy, migration, persistence, command service, and restore; depends on steps 1-5.

### Technical Dependencies

- No external infrastructure is required.
- Release depends on the v6 migration being stable in fresh and upgraded databases.
- UI affordance hiding depends on shared policy evaluation being reusable from SwiftUI without duplicating rules.
- If adjacent tab/session work lands concurrently in `ContentView.swift` or `NativeMacADEApp.swift`, merge order should be coordinated to reduce conflicts.

## Monitoring and Observability

**Metrics**
- `focusWorkspaceEnableCount`
- `focusWorkspaceDisableCount`
- `focusWorkspaceBlockedTerminalTabCount`
- `focusWorkspaceBlockedFileTabCount`

**Structured log events**
- `focus_workspace_enabled`
  - fields: `source`, `selected_session_id_present`
- `focus_workspace_disabled`
  - fields: `source`, `selected_session_id_present`
- `focus_workspace_blocked`
  - fields: `session_id`, `reason`, `terminal_tab_count`, `file_tab_count`, `selected_tab_kind`

**Alerting / escalation**
- MVP adds no remote alerting.
- Treat these as pilot release blockers during QA and early rollout:
  - any new restore failures attributable to the feature
  - migration failures loading `app_preferences`
  - blocked-action crashes or raw enum descriptions leaking to users
  - policy drift where hidden affordances and command behavior disagree

## Technical Considerations

### Key Decisions

- **Decision:** Store Focus Workspace as `AppPreferences.focusWorkspaceEnabled`.  
  **Rationale:** Matches app-global product scope and current settings lifecycle.  
  **Trade-off:** Requires a metadata migration.  
  **Alternatives rejected:** session-scoped persistence, ephemeral UI-only state.

- **Decision:** Enforce focus rules in `DefaultWorkspaceCommandService`.  
  **Rationale:** Existing mutation boundary already owns durable workspace changes.  
  **Trade-off:** Legacy sessions remain possible after enablement.  
  **Alternatives rejected:** view-layer-only gating, restore-time normalization.

- **Decision:** Use a shared pure policy helper.  
  **Rationale:** Prevents drift between UI affordances and command enforcement.  
  **Trade-off:** Adds one new shared type to the core layer.  
  **Alternatives rejected:** duplicated view logic, new service subsystem.

- **Decision:** Allow one terminal tab plus one optional file tab.  
  **Rationale:** Matches the approved technical clarifications while keeping the matrix small.  
  **Trade-off:** The feature is no longer a literal single-tab invariant.  
  **Alternatives rejected:** strict single-surface mode, reusable file-slot replacement behavior.

- **Decision:** Keep observability local in MVP.  
  **Rationale:** Matches current architecture and user instruction.  
  **Trade-off:** PRD metrics are only partially observable in pilot form, not durable product analytics.  
  **Alternatives rejected:** persisted counters, analytics-ready external sink in MVP.

### Known Risks

- **Legacy-session ambiguity**  
  Legacy multi-tab sessions will still appear after enablement or restore.  
  **Mitigation:** keep UI copy explicit, keep tab row visible when more than one visible tab exists, and restrict only future growth.

- **File-tab exception weakens naming clarity**  
  “Single-tab” can become misleading once a file exception exists.  
  **Mitigation:** prefer user-facing naming like “Focus Workspace” or “Focused Session” in UI copy.

- **UI / command drift**  
  Hidden affordances can diverge from actual enforcement if views stop using the shared helper.  
  **Mitigation:** shared pure policy helper plus command-service tests remain the source of truth.

- **Migration/load failure risk**  
  Preference schema changes sit on the startup path.  
  **Mitigation:** v6 migration tests, default false, and round-trip persistence coverage.

- **Generic alert copy quality**  
  Raw `String(describing: error)` output would violate the PRD’s calm blocked-action experience.  
  **Mitigation:** add focus-specific error mapping before presenting `UserMessage`.

## Architecture Decision Records

- [ADR-001: Scope V1 as a settings-first single-tab preference with real enforcement](adrs/adr-001.md) — Establishes the original product boundary around a truthful single-tab preference.
- [ADR-002: Use a broader focus-workspace product approach for the PRD](adrs/adr-002.md) — Selects broader focus-workspace framing instead of the narrowest preference-only MVP.
- [ADR-003: Broaden MVP through in-product framing before public positioning](adrs/adr-003.md) — Keeps MVP expansion inside the app before README or website positioning.
- [ADR-004: Enforce Focus Workspace at the command layer and grandfather existing multi-tab sessions](adrs/adr-004.md) — Makes the command service the enforcement boundary and applies the rule only to future actions.
- [ADR-005: Persist Focus Workspace as an app-global preference in AppPreferences with a v6 migration](adrs/adr-005.md) — Stores the feature as durable app-global settings metadata.
- [ADR-006: Allow one terminal tab plus one optional file tab and hide blocked terminal-tab affordances](adrs/adr-006.md) — Defines the allowed tab matrix and UI behavior for blocked terminal-tab flows.
- [ADR-007: Use a shared pure Focus Workspace policy helper instead of duplicating rules in views and commands](adrs/adr-007.md) — Prevents policy drift while avoiding a new service subsystem.
