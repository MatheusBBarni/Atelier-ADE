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
                    lastActivatedAt: Date(timeIntervalSince1970: 100)
                ),
                WorkspaceSession(
                    id: newerFirstSessionID,
                    projectID: firstProjectID,
                    title: "Newer first",
                    lastActivatedAt: Date(timeIntervalSince1970: 200)
                ),
                WorkspaceSession(
                    id: secondSessionID,
                    projectID: secondProjectID,
                    title: "Second",
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
    func restoreCoordinatorHydratesStoreFromPersistenceBoundary() async throws {
        let projectID = UUID()
        let sessionID = UUID()
        let tabID = UUID()
        let project = WorkspaceProject(id: projectID, path: "/tmp/ade", displayName: "ade")
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
        #expect(store.selectedTab?.workingDirectory == "/tmp/ade")
    }
}
