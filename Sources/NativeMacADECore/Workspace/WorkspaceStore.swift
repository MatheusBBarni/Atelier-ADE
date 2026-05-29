import Foundation
import Observation

@MainActor
@Observable
public final class WorkspaceStore {
    public var projects: [WorkspaceProject]
    public var sessions: [WorkspaceSession]
    public var tabs: [WorkspaceTab]
    public var appPreferences: AppPreferences
    public private(set) var selectedProjectID: UUID?
    public private(set) var selectedSessionID: UUID?
    public private(set) var selectedTabID: UUID?

    public var selection: WorkspaceSelection {
        WorkspaceSelection(projectID: selectedProjectID, sessionID: selectedSessionID, tabID: selectedTabID)
    }

    public var activeTheme: AppTheme {
        AppTheme.resolve(id: appPreferences.themeID)
    }

    public init(
        projects: [WorkspaceProject] = [],
        sessions: [WorkspaceSession] = [],
        tabs: [WorkspaceTab] = [],
        appPreferences: AppPreferences = .defaults,
        selectedProjectID: UUID? = nil,
        selectedSessionID: UUID? = nil,
        selectedTabID: UUID? = nil
    ) {
        self.projects = projects
        self.sessions = sessions
        self.tabs = tabs
        self.appPreferences = appPreferences
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
        return orderedSessions(for: selectedProjectID)
    }

    public func orderedSessions(for projectID: UUID) -> [WorkspaceSession] {
        sessions
            .filter { $0.projectID == projectID }
            .sorted(by: Self.sessionDisplaySort)
    }

    public var tabsForSelectedSession: [WorkspaceTab] {
        guard let selectedSessionID else { return [] }
        return tabs(for: selectedSessionID)
    }

    public func tab(id: UUID) -> WorkspaceTab? {
        tabs.first { $0.id == id }
    }

    public func tabs(for sessionID: UUID) -> [WorkspaceTab] {
        tabs
            .filter { $0.sessionID == sessionID }
            .sorted(by: Self.tabDisplaySort)
    }

    public func tabs(ofKind kind: WorkspaceTabKind, in sessionID: UUID) -> [WorkspaceTab] {
        tabs(for: sessionID).filter { $0.kind == kind }
    }

    public func terminalTabs(in sessionID: UUID) -> [WorkspaceTab] {
        tabs(ofKind: .terminal, in: sessionID)
    }

    public func fileTabs(in sessionID: UUID) -> [WorkspaceTab] {
        tabs(ofKind: .file, in: sessionID)
    }

    public func tabs(forProject projectID: UUID) -> [WorkspaceTab] {
        let sessionIDs = Set(sessions.filter { $0.projectID == projectID }.map(\.id))
        return tabs
            .filter { sessionIDs.contains($0.sessionID) }
            .sorted(by: Self.tabSnapshotSort)
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

        selectedSessionID = preferredSessionID(for: id)
        ensureSelectedTabBelongsToSelectedSession()
    }

    public func restore(
        projects: [WorkspaceProject],
        sessions: [WorkspaceSession],
        tabs: [WorkspaceTab],
        selection: WorkspaceSelection
    ) {
        self.projects = projects
        self.sessions = sessions
        self.tabs = tabs
        selectedProjectID = selection.projectID
        selectedSessionID = selection.sessionID
        selectedTabID = selection.tabID
        normalizeSelection()
    }

    public func upsertProject(_ project: WorkspaceProject, select: Bool = true) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.append(project)
        }
        projects.sort {
            if $0.sortIndex == $1.sortIndex { return $0.lastOpenedAt > $1.lastOpenedAt }
            return $0.sortIndex < $1.sortIndex
        }
        if select { selectProject(id: project.id) }
    }

    public func upsertSession(_ session: WorkspaceSession, select: Bool = true) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        if select { selectSession(id: session.id) } else { normalizeSelection() }
    }

    public func upsertTab(_ tab: WorkspaceTab, select: Bool = true) {
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs[index] = tab
        } else {
            tabs.append(tab)
        }
        if select { selectTab(id: tab.id) } else { normalizeSelection() }
    }

    public func updateAppPreferences(_ preferences: AppPreferences) {
        appPreferences = preferences
    }

    public func removeTab(id: UUID) {
        let removed = tabs.first { $0.id == id }
        tabs.removeAll { $0.id == id }

        if selectedTabID == id {
            selectedTabID = nil
        }

        if let removed, selectedSessionID == removed.sessionID {
            ensureSelectedTabBelongsToSelectedSession()
        } else {
            normalizeSelection()
        }
    }

    public func removeProject(id: UUID) {
        let removedSessionIDs = Set(sessions.filter { $0.projectID == id }.map(\.id))
        projects.removeAll { $0.id == id }
        sessions.removeAll { $0.projectID == id }
        tabs.removeAll { removedSessionIDs.contains($0.sessionID) }

        if selectedProjectID == id {
            selectedProjectID = nil
            selectedSessionID = nil
            selectedTabID = nil
            return
        }

        normalizeSelection()
    }

    public func removeSession(id: UUID) {
        let removed = sessions.first { $0.id == id }
        sessions.removeAll { $0.id == id }
        tabs.removeAll { $0.sessionID == id }

        if selectedSessionID == id {
            selectedSessionID = nil
            selectedTabID = nil
        }

        if let removed, selectedProjectID == removed.projectID {
            selectedSessionID = preferredSessionID(for: removed.projectID)
            ensureSelectedTabBelongsToSelectedSession()
        } else {
            normalizeSelection()
        }
    }

    public func project(matchingPath path: String) -> WorkspaceProject? {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        return projects.first { URL(fileURLWithPath: $0.path).standardizedFileURL.path == standardizedPath }
    }

    public func nextTabOrdinal(for sessionID: UUID) -> Int {
        let ordinals = tabs.filter { $0.sessionID == sessionID }.map(\.ordinal)
        return (ordinals.max() ?? -1) + 1
    }

    public func markProjectOpened(id: UUID, at date: Date) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].lastOpenedAt = date
        projects.sort {
            if $0.sortIndex == $1.sortIndex { return $0.lastOpenedAt > $1.lastOpenedAt }
            return $0.sortIndex < $1.sortIndex
        }
    }

    public func markSessionActivated(id: UUID, at date: Date) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].lastActivatedAt = date
    }

    public func markTabActivated(id: UUID, at date: Date) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].lastActivatedAt = date
    }

    public func snapshot(updatedAt: Date = Date()) -> RestoreSnapshot {
        RestoreSnapshot(
            selectedProjectID: selectedProjectID,
            selectedSessionID: selectedSessionID,
            selectedTabID: selectedTabID,
            tabOrder: tabs.sorted(by: Self.tabSnapshotSort).map(\.id),
            updatedAt: updatedAt
        )
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

    private func normalizeSelection() {
        guard let selectedProjectID,
              projects.contains(where: { $0.id == selectedProjectID })
        else {
            self.selectedProjectID = nil
            self.selectedSessionID = nil
            self.selectedTabID = nil
            return
        }

        if let selectedSessionID,
           sessions.contains(where: { $0.id == selectedSessionID && $0.projectID == selectedProjectID }) {
            ensureSelectedTabBelongsToSelectedSession()
            return
        }

        self.selectedSessionID = preferredSessionID(for: selectedProjectID)
        ensureSelectedTabBelongsToSelectedSession()
    }

    private func preferredSessionID(for projectID: UUID) -> UUID? {
        sessions
            .filter { $0.projectID == projectID }
            .sorted(by: Self.sessionSelectionSort)
            .first?
            .id
    }

    private static func sessionDisplaySort(_ lhs: WorkspaceSession, _ rhs: WorkspaceSession) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.id.uuidString > rhs.id.uuidString
    }

    private static func sessionSelectionSort(_ lhs: WorkspaceSession, _ rhs: WorkspaceSession) -> Bool {
        if lhs.lastActivatedAt != rhs.lastActivatedAt {
            return lhs.lastActivatedAt > rhs.lastActivatedAt
        }

        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.id.uuidString > rhs.id.uuidString
    }

    private static func tabDisplaySort(_ lhs: WorkspaceTab, _ rhs: WorkspaceTab) -> Bool {
        if lhs.ordinal != rhs.ordinal {
            return lhs.ordinal < rhs.ordinal
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func tabSnapshotSort(_ lhs: WorkspaceTab, _ rhs: WorkspaceTab) -> Bool {
        if lhs.sessionID != rhs.sessionID {
            return lhs.sessionID.uuidString < rhs.sessionID.uuidString
        }

        return tabDisplaySort(lhs, rhs)
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
