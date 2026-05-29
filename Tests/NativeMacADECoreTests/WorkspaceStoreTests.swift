import Foundation
import Testing
@testable import NativeMacADECore

@MainActor
struct WorkspaceStoreTests {
    @Test
    func previewStoreUsesProjectDirectoryForInitialTab() {
        let store = WorkspaceStore.preview()

        #expect(store.projects.count == 1)
        #expect(store.sessionsForSelectedProject.count == 1)
        #expect(store.tabsForSelectedSession.count == 1)
        #expect(store.selectedTab?.workingDirectory == store.selectedProject?.path)
    }

    @Test
    func creatingPreviewTabInheritsSelectedProjectDirectory() {
        let store = WorkspaceStore.preview()

        store.createPlaceholderTab()

        #expect(store.tabsForSelectedSession.count == 2)
        #expect(store.selectedTab?.workingDirectory == store.selectedProject?.path)
    }

    @Test
    func selectingProjectUpdatesSessionAndTabTogether() {
        let store = WorkspaceStore.preview()
        store.openPlaceholderProject()

        #expect(store.selectedSession?.projectID == store.selectedProjectID)
        #expect(store.selectedTab?.sessionID == store.selectedSessionID)
    }

    @Test
    func selectingProjectFiltersSessionsAndSelectsActiveSessionTab() {
        let firstProjectID = UUID()
        let secondProjectID = UUID()
        let olderFirstSessionID = UUID()
        let newerFirstSessionID = UUID()
        let secondSessionID = UUID()
        let firstTabID = UUID()
        let secondTabID = UUID()
        let unrelatedTabID = UUID()
        let store = WorkspaceStore(
            projects: [
                WorkspaceProject(id: firstProjectID, path: "/tmp/first", displayName: "first"),
                WorkspaceProject(id: secondProjectID, path: "/tmp/second", displayName: "second")
            ],
            sessions: [
                WorkspaceSession(
                    id: olderFirstSessionID,
                    projectID: firstProjectID,
                    title: "Older first",
                    createdAt: Date(timeIntervalSince1970: 100),
                    lastActivatedAt: Date(timeIntervalSince1970: 100)
                ),
                WorkspaceSession(
                    id: newerFirstSessionID,
                    projectID: firstProjectID,
                    title: "Newer first",
                    createdAt: Date(timeIntervalSince1970: 200),
                    lastActivatedAt: Date(timeIntervalSince1970: 200)
                ),
                WorkspaceSession(
                    id: secondSessionID,
                    projectID: secondProjectID,
                    title: "Second",
                    createdAt: Date(timeIntervalSince1970: 300),
                    lastActivatedAt: Date(timeIntervalSince1970: 300)
                )
            ],
            tabs: [
                WorkspaceTab(id: secondTabID, sessionID: newerFirstSessionID, workingDirectory: "/tmp/first", ordinal: 1),
                WorkspaceTab(id: unrelatedTabID, sessionID: secondSessionID, workingDirectory: "/tmp/second", ordinal: 0),
                WorkspaceTab(id: firstTabID, sessionID: newerFirstSessionID, workingDirectory: "/tmp/first", ordinal: 0)
            ]
        )

        store.selectProject(id: firstProjectID)

        #expect(store.selectedProjectID == firstProjectID)
        #expect(store.sessionsForSelectedProject.map(\.id) == [newerFirstSessionID, olderFirstSessionID])
        #expect(store.selectedSessionID == newerFirstSessionID)
        #expect(store.tabsForSelectedSession.map(\.id) == [firstTabID, secondTabID])
        #expect(store.selectedTabID == firstTabID)

        store.selectProject(id: secondProjectID)

        #expect(store.selectedProjectID == secondProjectID)
        #expect(store.sessionsForSelectedProject.map(\.id) == [secondSessionID])
        #expect(store.selectedSessionID == secondSessionID)
        #expect(store.tabsForSelectedSession.map(\.id) == [unrelatedTabID])
        #expect(store.selectedTabID == unrelatedTabID)
    }

    @Test
    func selectingSessionDoesNotReorderDisplayedSessionList() {
        let projectID = UUID()
        let olderSessionID = UUID()
        let newerSessionID = UUID()
        let store = WorkspaceStore(
            projects: [
                WorkspaceProject(id: projectID, path: "/tmp/project", displayName: "project")
            ],
            sessions: [
                WorkspaceSession(
                    id: olderSessionID,
                    projectID: projectID,
                    title: "Older",
                    createdAt: Date(timeIntervalSince1970: 100),
                    lastActivatedAt: Date(timeIntervalSince1970: 300)
                ),
                WorkspaceSession(
                    id: newerSessionID,
                    projectID: projectID,
                    title: "Newer",
                    createdAt: Date(timeIntervalSince1970: 200),
                    lastActivatedAt: Date(timeIntervalSince1970: 200)
                )
            ]
        )

        store.selectProject(id: projectID)

        #expect(store.selectedSessionID == olderSessionID)
        #expect(store.sessionsForSelectedProject.map(\.id) == [newerSessionID, olderSessionID])

        store.selectSession(id: newerSessionID)

        #expect(store.selectedSessionID == newerSessionID)
        #expect(store.sessionsForSelectedProject.map(\.id) == [newerSessionID, olderSessionID])
    }

    @Test
    func mixedTabSnapshotPreservesSingleOrderedTabNamespace() {
        let projectID = UUID()
        let sessionID = UUID()
        let terminalTabID = UUID()
        let fileTabID = UUID()
        let secondTerminalTabID = UUID()
        let projectPath = "/tmp/project"
        let fileReference = WorkspaceFileReference(
            path: "/tmp/project/Sources/App.swift",
            projectRoot: projectPath
        )
        let store = WorkspaceStore(
            projects: [
                WorkspaceProject(id: projectID, path: projectPath, displayName: "project")
            ],
            sessions: [
                WorkspaceSession(id: sessionID, projectID: projectID, title: "Mixed")
            ],
            tabs: [
                WorkspaceTab(id: secondTerminalTabID, sessionID: sessionID, workingDirectory: projectPath, ordinal: 2),
                WorkspaceTab(
                    id: fileTabID,
                    sessionID: sessionID,
                    kind: .file,
                    workingDirectory: projectPath,
                    fileReference: fileReference,
                    ordinal: 1
                ),
                WorkspaceTab(id: terminalTabID, sessionID: sessionID, workingDirectory: projectPath, ordinal: 0)
            ],
            selectedProjectID: projectID,
            selectedSessionID: sessionID,
            selectedTabID: fileTabID
        )

        let snapshot = store.snapshot(updatedAt: Date(timeIntervalSince1970: 500))

        #expect(store.tabsForSelectedSession.map(\.id) == [terminalTabID, fileTabID, secondTerminalTabID])
        #expect(store.tabsForSelectedSession.map(\.kind) == [.terminal, .file, .terminal])
        #expect(snapshot.selectedTabID == fileTabID)
        #expect(snapshot.tabOrder == [terminalTabID, fileTabID, secondTerminalTabID])
    }

    @Test
    func selectingAndActivatingMixedFileTabKeepsOneSessionScopedOrder() {
        let projectID = UUID()
        let sessionID = UUID()
        let terminalTabID = UUID()
        let fileTabID = UUID()
        let projectPath = "/tmp/project"
        let activatedAt = Date(timeIntervalSince1970: 800)
        let terminalTab = WorkspaceTab(
            id: terminalTabID,
            sessionID: sessionID,
            workingDirectory: projectPath,
            ordinal: 0,
            lastActivatedAt: Date(timeIntervalSince1970: 100)
        )
        let fileTab = WorkspaceTab(
            id: fileTabID,
            sessionID: sessionID,
            kind: .file,
            workingDirectory: projectPath,
            fileReference: WorkspaceFileReference(
                path: "/tmp/project/Sources/App.swift",
                projectRoot: projectPath
            ),
            ordinal: 1,
            lastActivatedAt: Date(timeIntervalSince1970: 200)
        )
        let store = WorkspaceStore(
            projects: [
                WorkspaceProject(id: projectID, path: projectPath, displayName: "project")
            ],
            sessions: [
                WorkspaceSession(id: sessionID, projectID: projectID, title: "Mixed")
            ],
            tabs: [fileTab, terminalTab]
        )

        store.selectTab(id: fileTabID)
        store.markTabActivated(id: fileTabID, at: activatedAt)

        #expect(store.selectedProjectID == projectID)
        #expect(store.selectedSessionID == sessionID)
        #expect(store.selectedTabID == fileTabID)
        #expect(store.tabsForSelectedSession.map(\.id) == [terminalTabID, fileTabID])
        #expect(store.terminalTabs(in: sessionID).map(\.id) == [terminalTabID])
        #expect(store.fileTabs(in: sessionID).map(\.id) == [fileTabID])
        #expect(store.tab(id: fileTabID)?.lastActivatedAt == activatedAt)
        #expect(store.snapshot(updatedAt: activatedAt).tabOrder == [terminalTabID, fileTabID])
    }

    @Test
    func mixedTabActivationOrderProducesWorkingSetInputForRightSidebar() {
        let projectID = UUID()
        let sessionID = UUID()
        let olderFileTabID = UUID()
        let newerFileTabID = UUID()
        let terminalTabID = UUID()
        let projectPath = "/tmp/project"
        let store = WorkspaceStore(
            projects: [
                WorkspaceProject(id: projectID, path: projectPath, displayName: "project")
            ],
            sessions: [
                WorkspaceSession(id: sessionID, projectID: projectID, title: "Mixed")
            ],
            tabs: [
                WorkspaceTab(id: terminalTabID, sessionID: sessionID, workingDirectory: projectPath, ordinal: 0),
                WorkspaceTab(
                    id: newerFileTabID,
                    sessionID: sessionID,
                    kind: .file,
                    workingDirectory: projectPath,
                    fileReference: WorkspaceFileReference(path: "\(projectPath)/README.md", projectRoot: projectPath),
                    ordinal: 2,
                    lastActivatedAt: Date(timeIntervalSince1970: 300)
                ),
                WorkspaceTab(
                    id: olderFileTabID,
                    sessionID: sessionID,
                    kind: .file,
                    workingDirectory: projectPath,
                    fileReference: WorkspaceFileReference(path: "\(projectPath)/Sources/App.swift", projectRoot: projectPath),
                    ordinal: 1,
                    lastActivatedAt: Date(timeIntervalSince1970: 100)
                )
            ],
            selectedProjectID: projectID,
            selectedSessionID: sessionID,
            selectedTabID: olderFileTabID
        )

        let workingSet = store.selectedSessionFileWorkingSetEntries(dirtyTabIDs: [olderFileTabID])

        #expect(workingSet.map(\.tabID) == [newerFileTabID, olderFileTabID])
        #expect(workingSet.map(\.subtitle) == ["README.md", "Sources/App.swift"])
        #expect(workingSet.map(\.isSelected) == [false, true])
        #expect(workingSet.map(\.isDirty) == [false, true])
    }

    @Test
    func restoreCoordinatorHydratesStoreFromPersistenceBoundary() async throws {
        let projectID = UUID()
        let sessionID = UUID()
        let tabID = UUID()
        let projectURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("native-mac-ade-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        let project = WorkspaceProject(id: projectID, path: projectURL.path, displayName: "ade")
        let session = WorkspaceSession(id: sessionID, projectID: projectID, title: "05-28 10:00")
        let tab = WorkspaceTab(id: tabID, sessionID: sessionID, workingDirectory: project.path, ordinal: 0)
        let persistence = InMemoryWorkspacePersistenceStore(
            projects: [project],
            sessions: [session],
            tabs: [tab],
            restoreSnapshot: RestoreSnapshot(
                selectedProjectID: projectID,
                selectedSessionID: sessionID,
                selectedTabID: tabID,
                openTabIDs: [tabID]
            )
        )
        let coordinator = RestoreCoordinator(persistenceStore: persistence)

        let store = try await coordinator.restoreStore()

        #expect(store.selectedProjectID == projectID)
        #expect(store.selectedSessionID == sessionID)
        #expect(store.selectedTabID == tabID)
        #expect(store.selectedTab?.workingDirectory == projectURL.path)
    }
}
