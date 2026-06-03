import Foundation
import Testing
@testable import NativeMacADECore

struct FocusWorkspaceContinuityRestoreSelectorTests {
    private let selector = FocusWorkspaceContinuityRestoreSelector()

    @Test
    func continuityDisabledReturnsRawRestoredSelectionUnchanged() {
        let fixture = makeMixedSessionFixture()

        let continuityOffResult = selector.resolve(
            restoredSelection: fixture.rawFileSelection,
            sessions: fixture.sessions,
            tabs: fixture.tabs,
            appPreferences: AppPreferences(
                focusWorkspaceEnabled: true,
                focusWorkspaceContinuityEnabled: false
            )
        )
        let focusOffResult = selector.resolve(
            restoredSelection: fixture.rawFileSelection,
            sessions: fixture.sessions,
            tabs: fixture.tabs,
            appPreferences: AppPreferences(
                focusWorkspaceEnabled: false,
                focusWorkspaceContinuityEnabled: true
            )
        )

        #expect(continuityOffResult == fixture.rawFileSelection)
        #expect(focusOffResult == fixture.rawFileSelection)
    }

    @Test
    func continuityEnabledReturnsNewestTerminalInSelectedSession() {
        let fixture = makeMixedSessionFixture()

        let result = selector.resolve(
            restoredSelection: fixture.rawFileSelection,
            sessions: fixture.sessions,
            tabs: fixture.tabs,
            appPreferences: .continuityEnabled
        )

        #expect(result == WorkspaceSelection(
            projectID: fixture.projectID,
            sessionID: fixture.selectedSessionID,
            tabID: fixture.newestTerminalTabID
        ))
    }

    @Test
    func continuityEnabledWithoutTerminalInSelectedSessionReturnsRawSelection() {
        let projectID = UUID()
        let selectedSessionID = UUID()
        let selectedFileTabID = UUID()
        let rawSelection = WorkspaceSelection(
            projectID: projectID,
            sessionID: selectedSessionID,
            tabID: selectedFileTabID
        )
        let sessions = [
            WorkspaceSession(id: selectedSessionID, projectID: projectID, title: "Files")
        ]
        let tabs = [
            WorkspaceTab(
                id: selectedFileTabID,
                sessionID: selectedSessionID,
                kind: .file,
                workingDirectory: "/tmp/project",
                fileReference: WorkspaceFileReference(path: "/tmp/project/App.swift", projectRoot: "/tmp/project"),
                ordinal: 0,
                lastActivatedAt: Date(timeIntervalSince1970: 300)
            )
        ]

        let result = selector.resolve(
            restoredSelection: rawSelection,
            sessions: sessions,
            tabs: tabs,
            appPreferences: .continuityEnabled
        )

        #expect(result == rawSelection)
    }

    @Test
    func terminalInDifferentSessionIsIgnoredWhenResolvingContinuityTarget() {
        let projectID = UUID()
        let selectedSessionID = UUID()
        let otherSessionID = UUID()
        let selectedFileTabID = UUID()
        let otherTerminalTabID = UUID()
        let rawSelection = WorkspaceSelection(
            projectID: projectID,
            sessionID: selectedSessionID,
            tabID: selectedFileTabID
        )
        let sessions = [
            WorkspaceSession(id: selectedSessionID, projectID: projectID, title: "Selected"),
            WorkspaceSession(id: otherSessionID, projectID: projectID, title: "Other")
        ]
        let tabs = [
            WorkspaceTab(
                id: selectedFileTabID,
                sessionID: selectedSessionID,
                kind: .file,
                workingDirectory: "/tmp/project",
                fileReference: WorkspaceFileReference(path: "/tmp/project/App.swift", projectRoot: "/tmp/project"),
                ordinal: 0,
                lastActivatedAt: Date(timeIntervalSince1970: 100)
            ),
            WorkspaceTab(
                id: otherTerminalTabID,
                sessionID: otherSessionID,
                workingDirectory: "/tmp/project",
                ordinal: 0,
                lastActivatedAt: Date(timeIntervalSince1970: 900)
            )
        ]

        let result = selector.resolve(
            restoredSelection: rawSelection,
            sessions: sessions,
            tabs: tabs,
            appPreferences: .continuityEnabled
        )

        #expect(result == rawSelection)
    }

    @Test
    func missingOrStaleSelectedSessionContextFallsBackToRawSelection() {
        let projectID = UUID()
        let selectedSessionID = UUID()
        let selectedTerminalTabID = UUID()
        let staleProjectID = UUID()
        let sessions = [
            WorkspaceSession(id: selectedSessionID, projectID: projectID, title: "Selected")
        ]
        let tabs = [
            WorkspaceTab(
                id: selectedTerminalTabID,
                sessionID: selectedSessionID,
                workingDirectory: "/tmp/project",
                ordinal: 0,
                lastActivatedAt: Date(timeIntervalSince1970: 300)
            )
        ]
        let missingSessionSelection = WorkspaceSelection(
            projectID: projectID,
            sessionID: nil,
            tabID: selectedTerminalTabID
        )
        let staleSessionSelection = WorkspaceSelection(
            projectID: projectID,
            sessionID: UUID(),
            tabID: selectedTerminalTabID
        )
        let staleProjectSelection = WorkspaceSelection(
            projectID: staleProjectID,
            sessionID: selectedSessionID,
            tabID: selectedTerminalTabID
        )

        #expect(selector.resolve(
            restoredSelection: missingSessionSelection,
            sessions: sessions,
            tabs: tabs,
            appPreferences: .continuityEnabled
        ) == missingSessionSelection)
        #expect(selector.resolve(
            restoredSelection: staleSessionSelection,
            sessions: sessions,
            tabs: tabs,
            appPreferences: .continuityEnabled
        ) == staleSessionSelection)
        #expect(selector.resolve(
            restoredSelection: staleProjectSelection,
            sessions: sessions,
            tabs: tabs,
            appPreferences: .continuityEnabled
        ) == staleProjectSelection)
    }
}

private struct MixedSessionFixture {
    let projectID: UUID
    let selectedSessionID: UUID
    let rawFileSelection: WorkspaceSelection
    let newestTerminalTabID: UUID
    let sessions: [WorkspaceSession]
    let tabs: [WorkspaceTab]
}

private func makeMixedSessionFixture() -> MixedSessionFixture {
    let projectID = UUID()
    let selectedSessionID = UUID()
    let selectedFileTabID = UUID()
    let olderTerminalTabID = UUID()
    let newestTerminalTabID = UUID()
    let projectPath = "/tmp/project"
    let sessions = [
        WorkspaceSession(id: selectedSessionID, projectID: projectID, title: "Selected")
    ]
    let tabs = [
        WorkspaceTab(
            id: selectedFileTabID,
            sessionID: selectedSessionID,
            kind: .file,
            workingDirectory: projectPath,
            fileReference: WorkspaceFileReference(path: "\(projectPath)/App.swift", projectRoot: projectPath),
            ordinal: 1,
            lastActivatedAt: Date(timeIntervalSince1970: 1_000)
        ),
        WorkspaceTab(
            id: olderTerminalTabID,
            sessionID: selectedSessionID,
            workingDirectory: projectPath,
            ordinal: 0,
            lastActivatedAt: Date(timeIntervalSince1970: 200)
        ),
        WorkspaceTab(
            id: newestTerminalTabID,
            sessionID: selectedSessionID,
            workingDirectory: projectPath,
            ordinal: 2,
            lastActivatedAt: Date(timeIntervalSince1970: 700)
        )
    ]

    return MixedSessionFixture(
        projectID: projectID,
        selectedSessionID: selectedSessionID,
        rawFileSelection: WorkspaceSelection(
            projectID: projectID,
            sessionID: selectedSessionID,
            tabID: selectedFileTabID
        ),
        newestTerminalTabID: newestTerminalTabID,
        sessions: sessions,
        tabs: tabs
    )
}

private extension AppPreferences {
    static var continuityEnabled: AppPreferences {
        AppPreferences(
            focusWorkspaceEnabled: true,
            focusWorkspaceContinuityEnabled: true
        )
    }
}
