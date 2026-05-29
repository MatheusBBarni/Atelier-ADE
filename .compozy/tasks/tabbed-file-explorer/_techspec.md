# Tabbed File Explorer

## Executive Summary

This specification implements the PRD sections **Core Features**, **User Experience**, and **Success Metrics** by extending Another ADE’s existing session-first tab pipeline instead of adding a parallel editor subsystem. Terminal tabs and file tabs will share one session-scoped tab model, file-tab metadata will persist through the existing SQLite restore flow, and live editor buffers will stay in a new runtime controller similar in spirit to `TerminalHostController`. The editor surface will use `CodeEditorView` for syntax-aware rendering and light editing only, with diagnostics, completion, and hover left out of MVP.

The primary technical trade-off is deliberate: accept moderate schema and command-service generalization now so the app keeps one coherent tab, selection, and restore model later. In exchange, MVP avoids deeper editor-platform work by persisting only durable file metadata, using explicit save with dirty state, and reloading saved file contents from disk on restore rather than trying to recover unsaved buffers.

## System Architecture

### Component Overview

1. **WorkspaceDetailView extension**  
   `WorkspaceDetailView` remains the narrowest UI seam. It will evolve from a terminal-only center pane into a split detail area with terminal content on the left and a trailing file workspace surface on the right. The left project/session sidebar remains unchanged.

2. **Generalized shared tab model**  
   `WorkspaceTab`, `WorkspaceStore`, `RestoreSnapshot`, `DefaultWorkspaceCommandService`, and SQLite persistence become tab-kind aware. Terminal and file tabs share ordering, selection, activation timestamps, and close entry points.

3. **File navigator state**  
   A lightweight observable file navigator model will own tree expansion state, selected tree nodes, and the working-set section derived from the selected session’s open file tabs and recent activation timestamps. This state is runtime-only and is not persisted separately.

4. **Workspace file system boundary**  
   A small core file-access service will enumerate project directories, load text files, save text files, and validate that file paths stay under the selected project root. It will also provide a narrow boundary for opening files in the external editor.

5. **File editor runtime controller**  
   A new runtime controller will own live editor buffers, dirty state, per-tab editor position, supported language configuration, and lazy file loading. Durable metadata stays in `WorkspaceStore`; mutable editor state stays outside the store.

6. **Restore and persistence pipeline**  
   `SQLiteWorkspaceMetadataStore` and `RestoreCoordinator` will persist and restore mixed terminal/file tabs. Restore will recreate file tabs and reload their saved contents from disk, while unsaved buffers remain intentionally non-restorable.

### Data Flow

- The user selects a project and session using the existing flow.
- The file navigator enumerates the selected project root and derives a working set from the selected session’s file tabs.
- Opening a file invokes the command service, which validates the path, persists a file tab, updates selection, and asks the editor controller to lazily load the buffer.
- `CodeEditorView` binds to the live editor buffer for the selected file tab.
- Save and revert operations go through the command service and file-access service, then update dirty state in the editor controller.
- Restore reloads mixed tabs through the existing snapshot ordering and reopens file tabs from disk.

## Implementation Design

### Core Interfaces

Code examples use Swift because the codebase is Swift-based.

```swift
public enum WorkspaceTabKind: String, Codable, Sendable {
    case terminal
    case file
}

public struct WorkspaceFileReference: Equatable, Codable, Sendable {
    public var path: String
    public var projectRoot: String
}
```

```swift
@MainActor
public protocol WorkspaceCommandService {
    func openFileTab(sessionID: UUID, path: String) async throws -> WorkspaceTab
    func saveFileTab(tabID: UUID) async throws
    func revertFileTab(tabID: UUID) async throws
    func openFileInExternalEditor(tabID: UUID) async throws
}
```

```swift
@MainActor
public protocol WorkspaceFileBufferManaging: AnyObject {
    func loadBuffer(for tab: WorkspaceTab) async throws
    func bufferText(for tabID: UUID) -> String?
    func updateBuffer(tabID: UUID, text: String)
    func saveBuffer(tabID: UUID) async throws
    func discardBuffer(tabID: UUID)
}
```

### Data Models

#### Persistent models

- **`WorkspaceTab`**: extend the existing struct with:
  - `kind: WorkspaceTabKind`
  - `fileReference: WorkspaceFileReference?` for file tabs
  - existing `workingDirectory`, `launchCommand`, and `launchArgumentsJSON` remain the terminal payload
- **`tabs` SQLite table**:
  - add `kind TEXT NOT NULL DEFAULT 'terminal'`
  - add `file_path TEXT NULL`
  - optionally derive project root from existing `working_directory` rather than storing it twice in SQLite
- **`RestoreSnapshot`**: unchanged structurally; it continues to store selected tab ID and ordered tab IDs for both terminal and file tabs.
- **`Project.bookmarkData`**: begin populating it when a project is opened so restored file access can rely on the project-level bookmark when available.

#### Runtime-only models

- **`FileEditorBuffer`**
  - `tabID: UUID`
  - `filePath: String`
  - `text: String`
  - `savedText: String`
  - `isDirty: Bool`
  - `languageConfigurationKey: String`
  - `lastLoadedAt: Date`
- **`FileNavigatorState`**
  - expanded directory paths
  - selected file/tree path
  - working-set entries derived from open file tabs and recent activation

#### Storage strategy

- Persist only file-tab metadata and restore ordering.
- Do not persist unsaved editor buffers.
- Do not add a separate working-set table in MVP.
- Derive the working set from persisted open file tabs plus `lastActivatedAt` ordering.

### API Endpoints

No HTTP or RPC endpoints are introduced for this feature.

The MVP extends the in-process command surface instead:

| Operation | Input | Result | Notes |
| --- | --- | --- | --- |
| `openFileTab` | `sessionID`, absolute file path | `WorkspaceTab` | Validates project ownership, persists a file tab, and selects it |
| `saveFileTab` | `tabID` | none | Writes current buffer text to disk and clears dirty state |
| `revertFileTab` | `tabID` | none | Reloads saved file contents from disk and clears dirty state |
| `openFileInExternalEditor` | `tabID` | none | Launches the file in the system editor path for escalation |
| `closeTab` | existing `tabID`, `force` | none | Reuses the shared close path, with dirty-state checks for file tabs and process checks for terminal tabs |

## Integration Points

| Boundary | Purpose | Approach |
| --- | --- | --- |
| `CodeEditorView` / `LanguageSupport` | Syntax-aware editing surface | Add as SwiftPM dependencies to the app target and keep usage behind a thin wrapper view |
| Local file system | Enumerate tree, load text, save edits | Use a small injected file-access service scoped to the selected project root |
| External editor launch | Escalate beyond quick-fix scope | Use a narrow opener boundary from the command service to the system editor |
| Project bookmark data | Stable restored file access | Populate and reuse project-level bookmark data when available |

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
|-----------|-------------|---------------------|-----------------|
| `Package.swift` | modified | Add `CodeEditorView` and `LanguageSupport`; low risk | Update dependencies for `NativeMacADE` target |
| `WorkspaceModels.swift` | modified | Generalize terminal-only tab model; medium risk | Add tab kind and file metadata fields |
| `WorkspaceMigrations.swift` | modified | First real schema evolution beyond bootstrap; high risk | Add user-version 2 migration for mixed tab metadata |
| `SQLiteWorkspaceMetadataStore.swift` | modified | Load/save file tabs using same table; medium risk | Read and write new tab columns |
| `WorkspaceStore.swift` | modified | Mixed-tab ordering and working-set derivation; medium risk | Keep one tab namespace and add helpers for file tabs |
| `WorkspaceCommandService.swift` / `DefaultWorkspaceCommandService.swift` | modified | New file open/save/revert flows plus per-kind close logic; high risk | Extend command protocol and branch on tab kind |
| `RestoreCoordinator.swift` | modified | Must restore mixed tabs and handle missing files clearly; medium risk | Reload file tabs from disk and emit diagnostics for failures |
| `ContentView.swift` | modified | Main user-facing structural change; medium risk | Split detail area, render file surface, update tab chrome |
| `NativeMacADEApp.swift` | modified | Add save-related commands and shortcuts; low risk | Introduce file save/revert/open-editor menu commands |
| `Tests/*` | modified/new | Coverage gap today for file flows; medium risk | Add core, integration, and minimal UI-oriented coverage |

## Testing Approach

### Unit Tests

- Extend `WorkspaceStoreTests` for mixed terminal/file tab ordering, selection, and activation recency.
- Extend `DefaultWorkspaceCommandServiceTests` for:
  - opening a file tab in a session
  - rejecting file paths outside the project root
  - explicit save clearing dirty state
  - revert discarding unsaved changes
  - close behavior for dirty file tabs vs live terminal tabs
- Add focused tests for the file buffer controller using a fake file-access service.
- Use mocks/fakes for file system reads/writes, external editor launch, and the existing terminal surface manager.

### Integration Tests

- Add SQLite migration coverage from schema v1 to v2.
- Add restore integration coverage for mixed terminal/file sessions.
- Add restore diagnostics for missing or unreadable restored files.
- Add end-to-end persistence coverage for file open → save → relaunch → reopen from disk.
- Keep UI automation light in MVP; rely on core and integration coverage first, with smoke checks for visible mixed-tab rendering only if needed.

## Development Sequencing

### Build Order

1. Generalize `WorkspaceTab` and define the mixed-tab data model — no dependencies.
2. Add schema v2 migration and update SQLite load/save paths — depends on step 1.
3. Extend `WorkspaceStore`, `RestoreCoordinator`, and command-service contracts for file tabs — depends on steps 1 and 2.
4. Add the file-access service and file buffer controller, including explicit save/revert flows — depends on step 3.
5. Add `CodeEditorView` integration, the right-side file surface, and mixed tab chrome updates — depends on steps 3 and 4.
6. Add app commands, external-editor escalation, observability, and close-confirmation behavior — depends on steps 4 and 5.
7. Add unit and integration coverage, including migration and mixed restore cases — depends on steps 1 through 6.

### Technical Dependencies

- `CodeEditorView` and `LanguageSupport` must be added to the Swift package graph for the macOS 15 target.
- The persistence layer must move from bootstrap-only schema creation to an actual versioned migration path.
- Project bookmark data should be populated when opening a project so restored file access can avoid path-only assumptions.
- A minimal language-mapping table is required for supported source-file extensions in MVP.

## Monitoring and Observability

- **Key metrics to track**
  - file-open duration for common source files
  - file-save success/failure counts
  - file-restore failure count
  - dirty-close confirmation accept/reject counts
  - external-editor escalation count
- **Structured log events**
  - `file_tab_opened`
  - `file_tab_saved`
  - `file_tab_reverted`
  - `file_tab_restore_failed`
  - `external_editor_opened`
- **Thresholds / release gates**
  - median common-file open latency should stay comfortably below the PRD’s user-facing 5-second target
  - file-save failures should remain near zero in pilot builds
  - restore failures for accessible files should be treated as release-blocking

## Technical Considerations

### Key Decisions

- **Shared tab namespace**: one ordered session tab strip is simpler and better aligned with the current architecture than building a second file-tab system.
- **Editor dependency choice**: `CodeEditorView` provides the fastest path to syntax-aware editing, but MVP will use only highlighting and direct editing.
- **Persistence boundary**: only durable metadata is stored; unsaved buffers remain runtime-only.
- **Working-set scope**: MVP derives working-set value from open file tabs and activation recency instead of adding pinned or closed-file history storage.
- **UI seam**: the detail pane is extended internally, avoiding a full shell rewrite.

### Known Risks

- **Schema migration risk**: the codebase currently has no incremental migration path.  
  Mitigation: implement and test a user-version 2 migration before feature code depends on new columns.
- **Third-party editor risk**: `CodeEditorView` is pre-release quality.  
  Mitigation: wrap it behind a thin adapter view and keep MVP scope narrow.
- **Mixed close semantics risk**: terminal tabs and file tabs require different close protections.  
  Mitigation: centralize close branching in the command service and cover both paths with tests.
- **Restore trust risk**: reopened file tabs that discard unsaved buffers may surprise users.  
  Mitigation: show clear dirty state, confirm unsaved close, and keep relaunch restore behavior explicit.
- **Large or unsupported file risk**: editor behavior may degrade outside the common-source-file profile.  
  Mitigation: optimize for common source files first and route awkward files toward clear fallback behavior.

## Architecture Decision Records

- [ADR-001: Scope tabbed-file-explorer as a session-aware working-set navigator](adrs/adr-001.md) — Keeps the feature working-set-first and preserves the terminal-first wedge.
- [ADR-002: Adopt a working-set-first quick-fix editor approach for the PRD](adrs/adr-002.md) — Narrows MVP editing to quick fixes with syntax-aware tabs.
- [ADR-003: Extend the shared session tab model to support file tabs and terminal tabs](adrs/adr-003.md) — Reuses the existing tab ordering, selection, and restore pipeline.
- [ADR-004: Use CodeEditorView for MVP syntax-aware editing with highlighting and editing only](adrs/adr-004.md) — Chooses a narrow editor integration instead of building richer language-service features.
- [ADR-005: Persist file-tab metadata only, with explicit save and no unsaved-buffer restore](adrs/adr-005.md) — Aligns file continuity with the app’s existing metadata-first restore model.
