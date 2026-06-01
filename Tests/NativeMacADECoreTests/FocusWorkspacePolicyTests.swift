import Foundation
import Testing
@testable import NativeMacADECore

@MainActor
struct FocusWorkspacePolicyTests {
    @Test
    func focusDisabledAllowsTerminalAndFileCreationRegardlessOfCounts() {
        let state = FocusWorkspaceSessionState(
            enabled: false,
            terminalTabCount: 4,
            fileTabCount: 3,
            visibleTabCount: 7
        )

        #expect(FocusWorkspacePolicy.terminalCreationDecision(in: state) == .allowed)
        #expect(FocusWorkspacePolicy.fileOpenDecision(in: state, openingSameFile: false) == .allowed)
        #expect(FocusWorkspacePolicy.fileOpenDecision(in: state, openingSameFile: true) == .allowed)
        #expect(FocusWorkspacePolicy.canCreateTerminal(in: state))
        #expect(FocusWorkspacePolicy.canOpenFile(in: state, openingSameFile: false))
        #expect(state.isCompliant)
        #expect(!state.hasLegacyOverflow)
    }

    @Test
    func focusEnabledEmptySessionAllowsFirstTerminalAndFirstFile() {
        let state = FocusWorkspaceSessionState(
            enabled: true,
            terminalTabCount: 0,
            fileTabCount: 0
        )

        #expect(FocusWorkspacePolicy.terminalCreationDecision(in: state) == .allowed)
        #expect(FocusWorkspacePolicy.fileOpenDecision(in: state, openingSameFile: false) == .allowed)
        #expect(state.visibleTabCount == 0)
        #expect(state.isCompliant)
        #expect(!state.hasLegacyOverflow)
    }

    @Test
    func focusEnabledOneTerminalRejectsAdditionalTerminal() {
        let state = FocusWorkspaceSessionState(
            enabled: true,
            terminalTabCount: 1,
            fileTabCount: 0
        )

        #expect(
            FocusWorkspacePolicy.terminalCreationDecision(in: state)
                == .blocked(.additionalTerminalTabBlocked)
        )
        #expect(!FocusWorkspacePolicy.canCreateTerminal(in: state))
        #expect(FocusWorkspacePolicy.fileOpenDecision(in: state, openingSameFile: false) == .allowed)
        #expect(state.isCompliant)
    }

    @Test
    func focusEnabledOneTerminalAndOneFileAllowsSameFileAndRejectsDifferentFile() {
        let state = FocusWorkspaceSessionState(
            enabled: true,
            terminalTabCount: 1,
            fileTabCount: 1
        )

        #expect(FocusWorkspacePolicy.fileOpenDecision(in: state, openingSameFile: true) == .allowed)
        #expect(FocusWorkspacePolicy.canOpenFile(in: state, openingSameFile: true))
        #expect(
            FocusWorkspacePolicy.fileOpenDecision(in: state, openingSameFile: false)
                == .blocked(.additionalFileTabBlocked)
        )
        #expect(!FocusWorkspacePolicy.canOpenFile(in: state, openingSameFile: false))
        #expect(state.visibleTabCount == 2)
        #expect(state.isCompliant)
    }

    @Test
    func legacyOverflowStatesReportNonCompliantWithoutMutatingPolicyState() {
        let terminalOverflow = FocusWorkspaceSessionState(
            enabled: true,
            terminalTabCount: 2,
            fileTabCount: 0
        )
        let fileOverflow = FocusWorkspaceSessionState(
            enabled: true,
            terminalTabCount: 1,
            fileTabCount: 2
        )
        let originalTerminalOverflow = terminalOverflow
        let originalFileOverflow = fileOverflow

        _ = FocusWorkspacePolicy.terminalCreationDecision(in: terminalOverflow)
        _ = FocusWorkspacePolicy.fileOpenDecision(in: fileOverflow, openingSameFile: false)

        #expect(terminalOverflow == originalTerminalOverflow)
        #expect(fileOverflow == originalFileOverflow)
        #expect(terminalOverflow.visibleTabCount == 2)
        #expect(fileOverflow.visibleTabCount == 3)
        #expect(!terminalOverflow.isCompliant)
        #expect(!fileOverflow.isCompliant)
        #expect(terminalOverflow.hasLegacyOverflow)
        #expect(fileOverflow.hasLegacyOverflow)
    }

    @Test
    func storeBackedSelectedSessionDerivesCountsUsedByPolicyEvaluation() {
        let projectID = UUID()
        let selectedSessionID = UUID()
        let otherSessionID = UUID()
        let projectPath = "/tmp/project"
        let terminalTab = WorkspaceTab(
            sessionID: selectedSessionID,
            workingDirectory: projectPath,
            ordinal: 0
        )
        let fileTab = WorkspaceTab(
            sessionID: selectedSessionID,
            kind: .file,
            workingDirectory: projectPath,
            fileReference: WorkspaceFileReference(
                path: "\(projectPath)/Sources/App.swift",
                projectRoot: projectPath
            ),
            ordinal: 1
        )
        let unrelatedTab = WorkspaceTab(
            sessionID: otherSessionID,
            workingDirectory: projectPath,
            ordinal: 0
        )
        let store = WorkspaceStore(
            projects: [
                WorkspaceProject(id: projectID, path: projectPath, displayName: "project")
            ],
            sessions: [
                WorkspaceSession(id: selectedSessionID, projectID: projectID, title: "Selected"),
                WorkspaceSession(id: otherSessionID, projectID: projectID, title: "Other")
            ],
            tabs: [fileTab, unrelatedTab, terminalTab],
            appPreferences: AppPreferences(themeID: AppTheme.systemSelectionID, focusWorkspaceEnabled: true),
            selectedProjectID: projectID,
            selectedSessionID: selectedSessionID,
            selectedTabID: terminalTab.id
        )

        let state = store.selectedFocusWorkspaceSessionState

        #expect(state?.enabled == true)
        #expect(state?.terminalTabCount == 1)
        #expect(state?.fileTabCount == 1)
        #expect(state?.visibleTabCount == 2)
        #expect(state?.isCompliant == true)
        #expect(
            state.map(FocusWorkspacePolicy.terminalCreationDecision(in:))
                == .blocked(.additionalTerminalTabBlocked)
        )
        #expect(
            state.map { FocusWorkspacePolicy.fileOpenDecision(in: $0, openingSameFile: false) }
                == .blocked(.additionalFileTabBlocked)
        )
        #expect(
            state.map { FocusWorkspacePolicy.fileOpenDecision(in: $0, openingSameFile: true) }
                == .allowed
        )
    }

    @Test
    func restoredLegacyMultiTabStoreFixtureRemainsReadableAsOverflow() {
        let projectID = UUID()
        let sessionID = UUID()
        let projectPath = "/tmp/project"
        let terminalOne = WorkspaceTab(
            sessionID: sessionID,
            workingDirectory: projectPath,
            ordinal: 0
        )
        let fileOne = WorkspaceTab(
            sessionID: sessionID,
            kind: .file,
            workingDirectory: projectPath,
            fileReference: WorkspaceFileReference(path: "\(projectPath)/README.md", projectRoot: projectPath),
            ordinal: 1
        )
        let terminalTwo = WorkspaceTab(
            sessionID: sessionID,
            workingDirectory: projectPath,
            ordinal: 2
        )
        let fileTwo = WorkspaceTab(
            sessionID: sessionID,
            kind: .file,
            workingDirectory: projectPath,
            fileReference: WorkspaceFileReference(path: "\(projectPath)/Package.swift", projectRoot: projectPath),
            ordinal: 3
        )
        let restoredTabs = [fileTwo, terminalTwo, fileOne, terminalOne]
        let store = WorkspaceStore(
            appPreferences: AppPreferences(themeID: AppTheme.systemSelectionID, focusWorkspaceEnabled: true)
        )

        store.restore(
            projects: [
                WorkspaceProject(id: projectID, path: projectPath, displayName: "project")
            ],
            sessions: [
                WorkspaceSession(id: sessionID, projectID: projectID, title: "Legacy")
            ],
            tabs: restoredTabs,
            selection: WorkspaceSelection(projectID: projectID, sessionID: sessionID, tabID: terminalOne.id)
        )

        let state = store.selectedFocusWorkspaceSessionState

        #expect(state?.enabled == true)
        #expect(state?.terminalTabCount == 2)
        #expect(state?.fileTabCount == 2)
        #expect(state?.visibleTabCount == 4)
        #expect(state?.isCompliant == false)
        #expect(state?.hasLegacyOverflow == true)
        #expect(store.tabs(for: sessionID).map(\.id) == [
            terminalOne.id,
            fileOne.id,
            terminalTwo.id,
            fileTwo.id
        ])
    }
}
