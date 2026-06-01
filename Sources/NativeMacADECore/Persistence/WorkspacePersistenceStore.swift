import Foundation

public struct SessionTabReorderPlan: Equatable, Sendable {
    public var sessionID: UUID
    public var visibleTabIDs: [UUID]
    public var hiddenPersistedTabIDs: [UUID]

    public init(
        sessionID: UUID,
        visibleTabIDs: [UUID],
        hiddenPersistedTabIDs: [UUID] = []
    ) {
        self.sessionID = sessionID
        self.visibleTabIDs = visibleTabIDs
        self.hiddenPersistedTabIDs = hiddenPersistedTabIDs
    }

    public var orderedTabIDs: [UUID] {
        visibleTabIDs + hiddenPersistedTabIDs
    }
}

public protocol WorkspacePersistenceStore: Sendable {
    func loadProjects() async throws -> [WorkspaceProject]
    func loadSessions() async throws -> [WorkspaceSession]
    func loadTabs() async throws -> [WorkspaceTab]
    func nextTabOrdinal(for sessionID: UUID) async throws -> Int
    func loadSessionShortcuts() async throws -> [SessionShortcut]
    func loadAppPreferences() async throws -> AppPreferences
    func loadRestoreSnapshot() async throws -> RestoreSnapshot?
    func save(project: WorkspaceProject) async throws
    func save(session: WorkspaceSession) async throws
    func save(tab: WorkspaceTab) async throws
    func save(session: WorkspaceSession, firstTab: WorkspaceTab) async throws
    func saveProjectOrder(_ orderedProjectIDs: [UUID]) async throws
    func saveTabOrder(_ plan: SessionTabReorderPlan, snapshot: RestoreSnapshot) async throws
    func saveActivation(project: WorkspaceProject?, session: WorkspaceSession?, tab: WorkspaceTab?, snapshot: RestoreSnapshot) async throws
    func save(shortcut: SessionShortcut) async throws
    func save(appPreferences: AppPreferences) async throws
    func save(snapshot: RestoreSnapshot) async throws
    func deleteProject(id: UUID) async throws
    func deleteSession(id: UUID) async throws
    func deleteTab(id: UUID) async throws
    func deleteShortcut(id: UUID) async throws
}

public extension WorkspacePersistenceStore {
    func nextTabOrdinal(for sessionID: UUID) async throws -> Int {
        let ordinals = try await loadTabs()
            .filter { $0.sessionID == sessionID }
            .map(\.ordinal)
        return (ordinals.max() ?? -1) + 1
    }
}

public actor InMemoryWorkspacePersistenceStore: WorkspacePersistenceStore {
    private var projects: [WorkspaceProject]
    private var sessions: [WorkspaceSession]
    private var tabs: [WorkspaceTab]
    private var shortcuts: [SessionShortcut]
    private var appPreferences: AppPreferences
    private var restoreSnapshot: RestoreSnapshot?

    public init(
        projects: [WorkspaceProject] = [],
        sessions: [WorkspaceSession] = [],
        tabs: [WorkspaceTab] = [],
        shortcuts: [SessionShortcut] = [],
        appPreferences: AppPreferences = .defaults,
        restoreSnapshot: RestoreSnapshot? = nil
    ) {
        self.projects = projects
        self.sessions = sessions
        self.tabs = tabs
        self.shortcuts = shortcuts
        self.appPreferences = appPreferences
        self.restoreSnapshot = restoreSnapshot
    }

    public func loadProjects() async throws -> [WorkspaceProject] {
        projects.sorted {
            if $0.sortIndex == $1.sortIndex { return $0.lastOpenedAt > $1.lastOpenedAt }
            return $0.sortIndex < $1.sortIndex
        }
    }

    public func loadSessions() async throws -> [WorkspaceSession] {
        sessions.sorted {
            if $0.lastActivatedAt == $1.lastActivatedAt { return $0.createdAt > $1.createdAt }
            return $0.lastActivatedAt > $1.lastActivatedAt
        }
    }

    public func loadTabs() async throws -> [WorkspaceTab] {
        tabs.sorted {
            if $0.sessionID == $1.sessionID { return $0.ordinal < $1.ordinal }
            return $0.sessionID.uuidString < $1.sessionID.uuidString
        }
    }

    public func loadSessionShortcuts() async throws -> [SessionShortcut] {
        shortcuts.sorted { $0.label < $1.label }
    }
    public func loadAppPreferences() async throws -> AppPreferences { appPreferences }
    public func loadRestoreSnapshot() async throws -> RestoreSnapshot? { restoreSnapshot }

    public func save(project: WorkspaceProject) async throws {
        projects.removeAll { $0.id == project.id }
        projects.append(project)
    }

    public func save(session: WorkspaceSession) async throws {
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
    }

    public func save(tab: WorkspaceTab) async throws {
        tabs.removeAll { $0.id == tab.id }
        tabs.append(tab)
    }

    public func save(session: WorkspaceSession, firstTab: WorkspaceTab) async throws {
        sessions.removeAll { $0.id == session.id }
        tabs.removeAll { $0.id == firstTab.id }
        sessions.append(session)
        tabs.append(firstTab)
    }

    public func saveProjectOrder(_ orderedProjectIDs: [UUID]) async throws {
        try validateUniqueProjectIDs(orderedProjectIDs)
        let existingProjectIDs = Set(projects.map(\.id))
        guard Set(orderedProjectIDs) == existingProjectIDs else {
            throw InMemoryWorkspacePersistenceStoreError.invalidProjectOrder
        }

        let ordinalsByID = Dictionary(uniqueKeysWithValues: orderedProjectIDs.enumerated().map { index, id in
            (id, index)
        })
        for index in projects.indices {
            guard let sortIndex = ordinalsByID[projects[index].id] else {
                throw InMemoryWorkspacePersistenceStoreError.invalidProjectOrder
            }
            projects[index].sortIndex = sortIndex
        }
    }

    public func saveTabOrder(_ plan: SessionTabReorderPlan, snapshot: RestoreSnapshot) async throws {
        let orderedTabIDs = plan.orderedTabIDs
        try validateUniqueTabIDs(orderedTabIDs)
        let existingSessionTabIDs = Set(tabs.filter { $0.sessionID == plan.sessionID }.map(\.id))
        guard Set(orderedTabIDs) == existingSessionTabIDs else {
            throw InMemoryWorkspacePersistenceStoreError.invalidTabOrder
        }

        let ordinalsByID = Dictionary(uniqueKeysWithValues: orderedTabIDs.enumerated().map { index, id in
            (id, index)
        })
        for index in tabs.indices where tabs[index].sessionID == plan.sessionID {
            guard let ordinal = ordinalsByID[tabs[index].id] else {
                throw InMemoryWorkspacePersistenceStoreError.invalidTabOrder
            }
            tabs[index].ordinal = ordinal
        }
        restoreSnapshot = snapshot
    }

    public func saveActivation(
        project: WorkspaceProject?,
        session: WorkspaceSession?,
        tab: WorkspaceTab?,
        snapshot: RestoreSnapshot
    ) async throws {
        if let project {
            guard let index = projects.firstIndex(where: { $0.id == project.id }) else {
                throw InMemoryWorkspacePersistenceStoreError.missingProject(project.id)
            }
            projects[index].lastOpenedAt = project.lastOpenedAt
        }
        if let session {
            guard let index = sessions.firstIndex(where: { $0.id == session.id }) else {
                throw InMemoryWorkspacePersistenceStoreError.missingSession(session.id)
            }
            sessions[index].lastActivatedAt = session.lastActivatedAt
        }
        if let tab {
            guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else {
                throw InMemoryWorkspacePersistenceStoreError.missingTab(tab.id)
            }
            tabs[index].lastActivatedAt = tab.lastActivatedAt
        }
        restoreSnapshot = snapshot
    }

    public func save(shortcut: SessionShortcut) async throws {
        shortcuts.removeAll { $0.id == shortcut.id }
        shortcuts.append(shortcut)
    }

    public func save(appPreferences: AppPreferences) async throws {
        self.appPreferences = appPreferences
    }

    public func save(snapshot: RestoreSnapshot) async throws {
        restoreSnapshot = snapshot
    }

    public func deleteProject(id: UUID) async throws {
        projects.removeAll { $0.id == id }
        sessions.removeAll { $0.projectID == id }
        tabs.removeAll { tab in !sessions.contains { $0.id == tab.sessionID } }
    }

    public func deleteSession(id: UUID) async throws {
        sessions.removeAll { $0.id == id }
        tabs.removeAll { $0.sessionID == id }
    }

    public func deleteTab(id: UUID) async throws {
        tabs.removeAll { $0.id == id }
    }

    public func deleteShortcut(id: UUID) async throws {
        shortcuts.removeAll { $0.id == id }
        for index in sessions.indices where sessions[index].shortcutID == id {
            sessions[index].shortcutID = nil
        }
        for index in tabs.indices where tabs[index].shortcutID == id {
            tabs[index].shortcutID = nil
        }
        if appPreferences.defaultSessionShortcutID == id {
            appPreferences.defaultSessionShortcutID = nil
            appPreferences.updatedAt = Date()
        }
    }

    private func validateUniqueProjectIDs(_ ids: [UUID]) throws {
        var seen: Set<UUID> = []
        for id in ids where !seen.insert(id).inserted {
            throw InMemoryWorkspacePersistenceStoreError.duplicateProjectID(id)
        }
    }

    private func validateUniqueTabIDs(_ ids: [UUID]) throws {
        var seen: Set<UUID> = []
        for id in ids where !seen.insert(id).inserted {
            throw InMemoryWorkspacePersistenceStoreError.duplicateTabID(id)
        }
    }
}

private enum InMemoryWorkspacePersistenceStoreError: Error, Equatable, Sendable {
    case missingProject(UUID)
    case missingSession(UUID)
    case missingTab(UUID)
    case duplicateProjectID(UUID)
    case duplicateTabID(UUID)
    case invalidProjectOrder
    case invalidTabOrder
}
