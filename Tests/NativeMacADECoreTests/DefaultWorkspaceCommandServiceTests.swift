import Foundation
import Testing
@testable import NativeMacADECore

// Suite: Default workspace command service unit behavior
// Invariant: command-service mutations keep project, session, tab, and selection state coherent.
// Boundary IN: DefaultWorkspaceCommandService with in-memory persistence and a fake terminal surface manager.
// Boundary OUT: SQLite persistence and live Ghostty surfaces, covered by integration tests.
@Suite(.serialized)
@MainActor
struct DefaultWorkspaceCommandServiceTests {
    @Test
    func openingNewProjectAddsProjectAndSelectsIt() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()

        let project = try await harness.service.openProject(path: projectPath)
        let snapshot = try await harness.persistence.loadRestoreSnapshot()

        #expect(harness.store.projects == [project])
        #expect(harness.store.selectedProjectID == project.id)
        #expect(harness.store.selectedProject == project)
        #expect(try await harness.persistence.loadProjects() == [project])
        #expect(snapshot?.selectedProjectID == project.id)
    }

    @Test
    func openingAlreadyKnownProjectReselectsExistingProjectInsteadOfDuplicatingIt() async throws {
        let harness = makeHarness()
        let firstProjectPath = try makeTemporaryProjectDirectory(named: "first-project")
        let secondProjectPath = try makeTemporaryProjectDirectory(named: "second-project")

        let firstOpen = try await harness.service.openProject(path: firstProjectPath)
        _ = try await harness.service.openProject(path: secondProjectPath)

        let reopened = try await harness.service.openProject(path: firstProjectPath)

        #expect(reopened.id == firstOpen.id)
        #expect(harness.store.projects.count == 2)
        #expect(harness.store.selectedProjectID == firstOpen.id)
    }

    @Test
    func creatingSessionAssignsDefaultTitleAndSelectsItsProject() async throws {
        let now = Date(timeIntervalSince1970: 1_717_393_500)
        let harness = makeHarness(now: { now })
        let projectPath = try makeTemporaryProjectDirectory()
        let project = try await harness.service.openProject(path: projectPath)

        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)

        #expect(session.projectID == project.id)
        #expect(session.title == WorkspaceSession.defaultTitle(for: now))
        #expect(session.isUserNamed == false)
        #expect(harness.store.selectedProjectID == project.id)
        #expect(harness.store.selectedSessionID == session.id)
    }

    @Test
    func renamingSessionUpdatesTitleAndMarksItUserNamed() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)

        try await harness.service.renameSession(sessionID: session.id, title: "  Investigate parser  \n")

        #expect(harness.store.selectedSession?.title == "Investigate parser")
        #expect(harness.store.selectedSession?.isUserNamed == true)
    }

    @Test
    func renamingSessionPreservesProjectOwnershipAndRecencyOrdering() async throws {
        let clock = DateSequence([
            Date(timeIntervalSince1970: 10),
            Date(timeIntervalSince1970: 11),
            Date(timeIntervalSince1970: 20),
            Date(timeIntervalSince1970: 21),
            Date(timeIntervalSince1970: 30),
            Date(timeIntervalSince1970: 31),
            Date(timeIntervalSince1970: 40),
            Date(timeIntervalSince1970: 41),
            Date(timeIntervalSince1970: 50),
            Date(timeIntervalSince1970: 51),
            Date(timeIntervalSince1970: 60),
            Date(timeIntervalSince1970: 61)
        ])
        let harness = makeHarness(now: clock.next)
        let firstProject = try await harness.service.openProject(path: makeTemporaryProjectDirectory(named: "first"))
        let secondProject = try await harness.service.openProject(path: makeTemporaryProjectDirectory(named: "second"))
        let olderFirstSession = try await harness.service.createSession(projectID: firstProject.id, shortcutID: nil)
        let newerFirstSession = try await harness.service.createSession(projectID: firstProject.id, shortcutID: nil)
        let secondSession = try await harness.service.createSession(projectID: secondProject.id, shortcutID: nil)

        try await harness.service.renameSession(sessionID: olderFirstSession.id, title: "Renamed first")
        let renamedSession = try #require(harness.store.sessions.first { $0.id == olderFirstSession.id })

        #expect(renamedSession.projectID == firstProject.id)
        #expect(harness.store.selectedProjectID == secondProject.id)
        #expect(harness.store.sessionsForSelectedProject.map(\.id) == [secondSession.id])

        harness.store.selectProject(id: firstProject.id)

        #expect(harness.store.sessionsForSelectedProject.map(\.id) == [newerFirstSession.id, olderFirstSession.id])
        #expect(try await harness.persistence.loadSessions().first?.id == secondSession.id)
    }

    @Test
    func creatingTabInheritsProjectSessionContextAndUpdatesSelection() async throws {
        let harness = makeHarness()
        let projectPath = try makeTemporaryProjectDirectory()
        let project = try await harness.service.openProject(path: projectPath)
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)

        let tab = try await harness.service.createTab(sessionID: session.id)

        #expect(tab.sessionID == session.id)
        #expect(tab.workingDirectory == project.path)
        #expect(tab.ordinal == 0)
        #expect(harness.store.selectedProjectID == project.id)
        #expect(harness.store.selectedSessionID == session.id)
        #expect(harness.store.selectedTabID == tab.id)
        #expect(harness.terminal.createdTabs == [tab])
    }

    private func makeHarness(now: @escaping @MainActor () -> Date = Date.init) -> CommandServiceHarness<InMemoryWorkspacePersistenceStore> {
        let store = WorkspaceStore()
        let persistence = InMemoryWorkspacePersistenceStore()
        let terminal = FakeTerminalSurfaceManager()
        let coordinator = RestoreCoordinator(persistenceStore: persistence)
        let service = DefaultWorkspaceCommandService(
            store: store,
            persistenceStore: persistence,
            restoreCoordinator: coordinator,
            terminalSurfaceManager: terminal,
            now: now
        )

        return CommandServiceHarness(
            store: store,
            persistence: persistence,
            terminal: terminal,
            service: service
        )
    }

    private func makeTemporaryProjectDirectory(named name: String = UUID().uuidString) throws -> String {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("native-mac-ade-command-service-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url.path
    }
}

@MainActor
private struct CommandServiceHarness<Persistence: WorkspacePersistenceStore> {
    let store: WorkspaceStore
    let persistence: Persistence
    let terminal: FakeTerminalSurfaceManager
    let service: DefaultWorkspaceCommandService
}

@MainActor
private final class FakeTerminalSurfaceManager: WorkspaceTerminalSurfaceManaging {
    private(set) var createdTabs: [WorkspaceTab] = []
    var surfaceCreationError: Error?

    func createSurface(for tab: WorkspaceTab) async throws -> GhosttySurfaceHandle {
        createdTabs.append(tab)
        if let surfaceCreationError {
            throw surfaceCreationError
        }
        return GhosttySurfaceHandle()
    }

    func canClose(surface: GhosttySurfaceHandle) async -> Bool {
        true
    }
}

@MainActor
private final class DateSequence {
    private var dates: [Date]

    init(_ dates: [Date]) {
        self.dates = dates
    }

    func next() -> Date {
        dates.removeFirst()
    }
}
