# Plan: show running agents per session and tab

## Goal

Make it obvious which agent is attached to each terminal tab without opening the session.

Target outcome:

- every expanded session shows the agents running in its tabs
- the main tab strip also reflects agent identity
- the design borrows the **summary feel** from herdr's `Agents` section and the **inline hierarchy** from Orca

## What we learned from herdr and Orca

### herdr

herdr treats agent identity as a first-class runtime concept.

- its UI has a separate `Agents` section that lists agents and state
- agent identity is derived from pane/runtime metadata, not just the tab title
- tabs and agents are related, but not the same thing

Important implication for Atelier: herdr-style accuracy comes from runtime metadata, not from simple string parsing.

### Orca

Orca surfaces context inline in the workspace/session tree.

- tabs/workspaces show agent context directly where the user navigates
- agent identity and human-readable label are separated
- the hierarchy makes it easy to scan a repo, then a session, then the active work inside it

Important implication for Atelier: the best fit is to show agent rows inside each session, not only in a separate global panel.

## Current state in Atelier

### What already exists

- `WorkspaceSession` stores a session-level `shortcutID`
- `WorkspaceTab` stores `launchCommand` and `launchArgumentsJSON`
- tab titles already infer `Codex` / `Claude` / `OpenCode` from `launchCommand`
- `AgentProfileIconView` already knows how to render built-in agent branding

### Gaps

- `WorkspaceTab` does **not** store `shortcutID`
- sidebar session rows do not show child tab/agent summaries
- terminal tabs use a generic terminal icon in the main tab strip
- runtime state is minimal: the terminal host can tell whether a process exited, but it does not expose herdr-like foreground-agent detection

## Recommendation

Build this in two layers:

1. **Ship a reliable v1 from launch metadata**
   - use the tab's agent profile / launch intent as the source of truth
   - this is enough to show "this tab is a Codex tab" or "this tab is a Claude tab"
2. **Leave room for richer runtime detection later**
   - if we later add shell integration or foreground-process detection, we can upgrade the label/state without redesigning the UI

This avoids blocking on herdr-level runtime inspection while still delivering the UX the user wants.

## Proposed UX

### 1) Expanded session rows show tab-level agent entries

When a project is expanded, each session row should render a compact nested list of its terminal tabs.

Each child row should show:

- agent icon
- agent label (`Codex`, `Claude`, `OpenCode`, custom profile name, or `Plain Shell`)
- tab label
  - custom tab title when present
  - otherwise the default terminal/file label
- optional state badge when available later

Suggested hierarchy:

- **session row** = session name
- **child rows** = tabs inside that session

Suggested child-row labeling:

- primary: tab title
- secondary: agent label

This matches the Orca-style scan pattern while still carrying the herdr idea of an explicit agent identity.

### 2) Main tab strip shows agent identity

Terminal tabs in `TabItemView` should stop using the generic terminal icon whenever an agent profile is known.

- file tabs keep file icons
- plain shell tabs keep terminal icon
- agent tabs use `AgentProfileIconView` or an equivalent resolved icon

### 3) Optional later: global Agents section

After session-level rendering ships, we can decide whether to add a separate global sidebar section like herdr.

That should be a follow-up, not part of the first slice.

## Data model changes

### Add agent identity to `WorkspaceTab`

Add:

- `shortcutID: UUID?`

Why:

- session-level `shortcutID` is not enough once a session contains mixed agent tabs
- `launchCommand` string parsing is a fallback, not a durable source of truth
- tab identity must survive restore, rename, and custom profile usage

### Persistence changes

Add `shortcut_id` to the `tabs` table.

Required work:

- bump SQLite user version
- add migration for `tabs.shortcut_id`
- load/save the new field in `SQLiteWorkspaceMetadataStore`
- keep `ON DELETE SET NULL` behavior for deleted custom profiles

### Backward compatibility

For old rows with `shortcut_id = NULL`:

- fallback to session `shortcutID` when the tab was created from the session default
- fallback to `launchCommand` heuristics for built-ins
- fallback to `Plain Shell` when no agent identity is known

## Command/service changes

Update tab creation paths so every terminal tab captures its agent identity at creation time.

Required surfaces:

- `createSession(projectID:shortcutID:)`
- `createTab(sessionID:)`
- `createDefaultAgentTab(sessionID:)`
- `createAgentTab(sessionID:shortcutID:)`
- shared `createTerminalTab(...)`

Behavior:

- tabs created from an explicit profile get that `shortcutID`
- tabs created from the stored session profile inherit that profile's `shortcutID`
- plain shell tabs keep `shortcutID = nil`

## Presentation layer changes

### Create a shared resolver

Add a small presentation helper that resolves tab identity from:

- `WorkspaceTab.shortcutID`
- known `SessionShortcut`s
- `launchCommand` fallback heuristics

The resolver should return a compact descriptor, for example:

- `agentLabel`
- `shortcut`
- `isPlainShell`
- `fallbackSystemImage`

This removes duplicated logic currently embedded in:

- `TabItemView`
- `TabRenameDraft`
- any future session-row rendering

### Session row rendering

Update `SessionRowView` so it can receive session tabs or derived descriptors.

Suggested rendering rules:

- show only terminal tabs in the nested agent list
- show up to 3 rows by default
- if more exist, show a `+N more` summary row
- clicking a child row selects that tab
- the active tab gets a stronger highlight

### Tab strip rendering

Update `TabItemView`:

- replace the generic terminal icon with the resolved agent icon for terminal tabs
- keep current title behavior, but move title/icon resolution into shared helpers

## Runtime state plan

### v1

Do **not** try to fully detect the foreground agent process.

Use:

- persisted launch identity for the label/icon
- existing terminal lifecycle knowledge only for coarse state if needed

### v2

If we want closer herdr parity, add a runtime agent state layer.

Possible sources later:

- shell integration
- terminal title metadata
- foreground process detection from the terminal boundary
- explicit agent heartbeat/status events

That future layer should enrich the UI with states like:

- running
- idle
- exited
- unknown

## Implementation phases

### Phase 1 — persist per-tab agent identity

- add `shortcutID` to `WorkspaceTab`
- migrate the SQLite schema
- update load/save/restore paths
- update creation flows to populate tab `shortcutID`

### Phase 2 — unify agent resolution

- extract a shared tab-agent resolver
- reuse `AgentProfileIconView`
- remove duplicated `launchCommand` switch logic from view code where possible

### Phase 3 — show agents inside sessions

- extend session row inputs with tab summaries
- render nested terminal-tab rows under each session
- add selection behavior for child rows

### Phase 4 — polish the tab strip

- render agent icons in the main tab strip
- ensure rename placeholders and accessibility strings stay correct

### Phase 5 — optional runtime state and global panel

- add richer live state if needed
- evaluate a separate global `Agents` section later

## Acceptance criteria

- expanded project cards show each session's terminal tabs with visible agent identity
- mixed-agent sessions are understandable at a glance
- restored tabs keep the same agent identity after relaunch
- custom profiles display their custom label, not only their raw command
- plain shell tabs remain clearly differentiated from agent tabs
- file tabs are unaffected

## Risks and open questions

### 1) "Running" vs "launched as"

The first version will know what the tab was launched as, not necessarily what is currently in the foreground process.

Decision: acceptable for v1.

### 2) How much detail to show per child row

Need a product call on whether the primary label should be:

- tab title first, agent second
- or agent first, tab second

Recommended: **tab title first, agent second**.

### 3) How many rows per session

Large sessions could get noisy.

Recommended: cap visible rows and collapse overflow.

### 4) What to do with legacy tabs

Older restored data will not always have exact tab-level agent identity.

Recommended: use fallback heuristics and avoid blocking the feature on perfect migration accuracy.

## Files most likely affected when implementation starts

- `Sources/NativeMacADECore/Workspace/WorkspaceModels.swift`
- `Sources/NativeMacADECore/Persistence/WorkspaceMigrations.swift`
- `Sources/NativeMacADECore/Persistence/SQLiteWorkspaceMetadataStore.swift`
- `Sources/NativeMacADECore/Commands/DefaultWorkspaceCommandService.swift`
- `Sources/NativeMacADE/AppShell/AgentProfileVisuals.swift`
- `Sources/NativeMacADE/AppShell/ContentView.swift`
- integration tests covering create/restore/persistence flows

## Recommended first slice

Implement **Phase 1 + Phase 2 + Phase 3** together.

That gives a complete user-visible result:

- durable per-tab agent identity
- session rows that expose it
- no need to solve runtime process detection yet

This is the smallest slice that meaningfully captures the herdr/Orca inspiration without overreaching.
