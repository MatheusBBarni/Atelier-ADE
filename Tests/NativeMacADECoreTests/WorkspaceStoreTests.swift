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
