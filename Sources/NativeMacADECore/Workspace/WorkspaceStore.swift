import Foundation
import Observation

@MainActor
@Observable
public final class WorkspaceStore {
    public var projects: [WorkspaceProject]
    public var sessions: [WorkspaceSession]
    public var tabs: [WorkspaceTab]
    public private(set) var selectedProjectID: UUID?
    public private(set) var selectedSessionID: UUID?
    public private(set) var selectedTabID: UUID?

    public init(
        projects: [WorkspaceProject] = [],
        sessions: [WorkspaceSession] = [],
        tabs: [WorkspaceTab] = [],
        selectedProjectID: UUID? = nil,
        selectedSessionID: UUID? = nil,
        selectedTabID: UUID? = nil
    ) {
        self.projects = projects
        self.sessions = sessions
        self.tabs = tabs
        self.selectedProjectID = selectedProjectID
        self.selectedSessionID = selectedSessionID
        self.selectedTabID = selectedTabID
    }

    public var selectedProject: WorkspaceProject? {
        projects.first { $0.id == selectedProjectID }
    }

    public var selectedSession: WorkspaceSession? {
        sessions.first { $0.id == selectedSessionID }
    }

    public var selectedTab: WorkspaceTab? {
        tabs.first { $0.id == selectedTabID }
    }

    public var sessionsForSelectedProject: [WorkspaceSession] {
        guard let selectedProjectID else { return [] }
        return sessions
            .filter { $0.projectID == selectedProjectID }
            .sorted { $0.lastActivatedAt > $1.lastActivatedAt }
    }

    public var tabsForSelectedSession: [WorkspaceTab] {
        guard let selectedSessionID else { return [] }
        return tabs
            .filter { $0.sessionID == selectedSessionID }
            .sorted { $0.ordinal < $1.ordinal }
    }

    public func selectProject(id: UUID?) {
        guard let id else {
            selectedProjectID = nil
            selectedSessionID = nil
            selectedTabID = nil
            return
        }

        guard projects.contains(where: { $0.id == id }) else { return }
        selectedProjectID = id

        if let selectedSessionID,
           sessions.contains(where: { $0.id == selectedSessionID && $0.projectID == id }) {
            ensureSelectedTabBelongsToSelectedSession()
            return
        }

        selectedSessionID = sessionsForSelectedProject.first?.id
        ensureSelectedTabBelongsToSelectedSession()
    }

    public func selectSession(id: UUID?) {
        guard let id else {
            selectedSessionID = nil
            selectedTabID = nil
            return
        }

        guard let session = sessions.first(where: { $0.id == id }) else { return }
        selectedProjectID = session.projectID
        selectedSessionID = session.id
        ensureSelectedTabBelongsToSelectedSession()
    }

    public func selectTab(id: UUID?) {
        guard let id else {
            selectedTabID = nil
            return
        }

        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        selectSession(id: tab.sessionID)
        selectedTabID = tab.id
    }

    public func openPlaceholderProject() {
        let index = projects.count + 1
        let project = WorkspaceProject(
            path: "/tmp/native-mac-ade-preview-\(index)",
            displayName: "Preview Project \(index)",
            sortIndex: index
        )
        projects.append(project)
        selectProject(id: project.id)
        createPlaceholderSession()
    }

    public func createPlaceholderSession() {
        guard let project = selectedProject else { return }
        let session = WorkspaceSession(
            projectID: project.id,
            title: Self.defaultSessionTitle(date: Date())
        )
        sessions.append(session)
        selectSession(id: session.id)
        createPlaceholderTab()
    }

    public func createPlaceholderTab() {
        guard let session = selectedSession,
              let project = projects.first(where: { $0.id == session.projectID })
        else { return }

        let ordinal = tabs.filter { $0.sessionID == session.id }.count
        let tab = WorkspaceTab(
            sessionID: session.id,
            workingDirectory: project.path,
            ordinal: ordinal
        )
        tabs.append(tab)
        selectTab(id: tab.id)
    }

    private func ensureSelectedTabBelongsToSelectedSession() {
        guard let selectedSessionID else {
            selectedTabID = nil
            return
        }

        if let selectedTabID,
           tabs.contains(where: { $0.id == selectedTabID && $0.sessionID == selectedSessionID }) {
            return
        }

        selectedTabID = tabsForSelectedSession.first?.id
    }

    public static func defaultSessionTitle(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    public static func preview() -> WorkspaceStore {
        let projectID = UUID()
        let sessionID = UUID()
        let tabID = UUID()
        return WorkspaceStore(
            projects: [
                WorkspaceProject(
                    id: projectID,
                    path: "/Users/example/agent-work",
                    displayName: "agent-work"
                )
            ],
            sessions: [
                WorkspaceSession(
                    id: sessionID,
                    projectID: projectID,
                    title: "05-28 09:30"
                )
            ],
            tabs: [
                WorkspaceTab(
                    id: tabID,
                    sessionID: sessionID,
                    workingDirectory: "/Users/example/agent-work",
                    ordinal: 0
                )
            ],
            selectedProjectID: projectID,
            selectedSessionID: sessionID,
            selectedTabID: tabID
        )
    }
}
