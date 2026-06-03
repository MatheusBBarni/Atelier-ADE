import Foundation
import Testing
@testable import NativeMacADECore

@MainActor
struct FocusWorkspaceContinuityRestoreSelectorIntegrationTests {
    private let selector = FocusWorkspaceContinuityRestoreSelector()

    @Test
    func validSelectorResultRemainsCompatibleWithWorkspaceStoreRestoreNormalization() {
        let projectID = UUID()
        let sessionID = UUID()
        let selectedFileTabID = UUID()
        let terminalTabID = UUID()
        let projectPath = "/tmp/project"
        let project = WorkspaceProject(id: projectID, path: projectPath, displayName: "project")
        let session = WorkspaceSession(id: sessionID, projectID: projectID, title: "Selected")
        let selectedFileTab = WorkspaceTab(
            id: selectedFileTabID,
            sessionID: sessionID,
            kind: .file,
            workingDirectory: projectPath,
            fileReference: WorkspaceFileReference(path: "\(projectPath)/App.swift", projectRoot: projectPath),
            ordinal: 0,
            lastActivatedAt: Date(timeIntervalSince1970: 900)
        )
        let terminalTab = WorkspaceTab(
            id: terminalTabID,
            sessionID: sessionID,
            workingDirectory: projectPath,
            ordinal: 1,
            lastActivatedAt: Date(timeIntervalSince1970: 500)
        )
        let rawSelection = WorkspaceSelection(
            projectID: projectID,
            sessionID: sessionID,
            tabID: selectedFileTabID
        )

        let resolvedSelection = selector.resolve(
            restoredSelection: rawSelection,
            sessions: [session],
            tabs: [selectedFileTab, terminalTab],
            appPreferences: .continuityEnabled
        )
        let store = WorkspaceStore()
        store.restore(
            projects: [project],
            sessions: [session],
            tabs: [selectedFileTab, terminalTab],
            selection: resolvedSelection
        )

        #expect(store.selection == WorkspaceSelection(
            projectID: projectID,
            sessionID: sessionID,
            tabID: terminalTabID
        ))
        #expect(store.tabsForSelectedSession.map(\.id) == [selectedFileTabID, terminalTabID])
    }

    @Test
    func fallbackSelectorResultPreservesRestoredTabOrderAndSelectedSessionContext() {
        let projectID = UUID()
        let selectedSessionID = UUID()
        let otherSessionID = UUID()
        let firstFileTabID = UUID()
        let secondFileTabID = UUID()
        let otherTerminalTabID = UUID()
        let projectPath = "/tmp/project"
        let project = WorkspaceProject(id: projectID, path: projectPath, displayName: "project")
        let selectedSession = WorkspaceSession(id: selectedSessionID, projectID: projectID, title: "Selected")
        let otherSession = WorkspaceSession(id: otherSessionID, projectID: projectID, title: "Other")
        let firstFileTab = WorkspaceTab(
            id: firstFileTabID,
            sessionID: selectedSessionID,
            kind: .file,
            workingDirectory: projectPath,
            fileReference: WorkspaceFileReference(path: "\(projectPath)/App.swift", projectRoot: projectPath),
            ordinal: 0,
            lastActivatedAt: Date(timeIntervalSince1970: 200)
        )
        let secondFileTab = WorkspaceTab(
            id: secondFileTabID,
            sessionID: selectedSessionID,
            kind: .file,
            workingDirectory: projectPath,
            fileReference: WorkspaceFileReference(path: "\(projectPath)/Package.swift", projectRoot: projectPath),
            ordinal: 1,
            lastActivatedAt: Date(timeIntervalSince1970: 300)
        )
        let otherTerminalTab = WorkspaceTab(
            id: otherTerminalTabID,
            sessionID: otherSessionID,
            workingDirectory: projectPath,
            ordinal: 0,
            lastActivatedAt: Date(timeIntervalSince1970: 900)
        )
        let rawSelection = WorkspaceSelection(
            projectID: projectID,
            sessionID: selectedSessionID,
            tabID: secondFileTabID
        )

        let resolvedSelection = selector.resolve(
            restoredSelection: rawSelection,
            sessions: [selectedSession, otherSession],
            tabs: [secondFileTab, otherTerminalTab, firstFileTab],
            appPreferences: .continuityEnabled
        )
        let store = WorkspaceStore()
        store.restore(
            projects: [project],
            sessions: [selectedSession, otherSession],
            tabs: [secondFileTab, otherTerminalTab, firstFileTab],
            selection: resolvedSelection
        )

        #expect(resolvedSelection == rawSelection)
        #expect(store.selectedSessionID == selectedSessionID)
        #expect(store.selectedTabID == secondFileTabID)
        #expect(store.tabsForSelectedSession.map(\.id) == [firstFileTabID, secondFileTabID])
    }
}

private extension AppPreferences {
    static var continuityEnabled: AppPreferences {
        AppPreferences(
            focusWorkspaceEnabled: true,
            focusWorkspaceContinuityEnabled: true
        )
    }
}
