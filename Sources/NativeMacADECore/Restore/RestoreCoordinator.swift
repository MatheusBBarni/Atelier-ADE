import Foundation

public struct RestoreWorkspaceResult {
    public var store: WorkspaceStore
    public var diagnostics: [RestoreDiagnostic]
    public var skippedProjects: [SkippedRestoredProject]

    public init(
        store: WorkspaceStore,
        diagnostics: [RestoreDiagnostic] = [],
        skippedProjects: [SkippedRestoredProject] = []
    ) {
        self.store = store
        self.diagnostics = diagnostics
        self.skippedProjects = skippedProjects
    }

    public var hasRecoveryItems: Bool { !skippedProjects.isEmpty || diagnostics.contains { $0.severity != .info } }
}

public struct RestoreDiagnostic: Equatable, Sendable {
    public enum Severity: Equatable, Sendable {
        case info
        case warning
        case failure
    }

    public var severity: Severity
    public var message: String

    public init(severity: Severity, message: String) {
        self.severity = severity
        self.message = message
    }
}

public struct SkippedRestoredProject: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var path: String
    public var displayName: String
    public var reason: String

    public init(id: UUID, path: String, displayName: String, reason: String) {
        self.id = id
        self.path = path
        self.displayName = displayName
        self.reason = reason
    }
}

@MainActor
public struct RestoreCoordinator {
    private let persistenceStore: any WorkspacePersistenceStore
    private let directoryIsAccessible: @Sendable (String) -> Bool

    public init(
        persistenceStore: any WorkspacePersistenceStore,
        directoryIsAccessible: @escaping @Sendable (String) -> Bool = { path in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    ) {
        self.persistenceStore = persistenceStore
        self.directoryIsAccessible = directoryIsAccessible
    }

    public func restoreStore() async throws -> WorkspaceStore {
        try await restoreWorkspace().store
    }

    public func restoreWorkspace() async throws -> RestoreWorkspaceResult {
        let projects = try await persistenceStore.loadProjects()
        let sessions = try await persistenceStore.loadSessions()
        let tabs = try await persistenceStore.loadTabs()
        let snapshot: RestoreSnapshot?
        var diagnostics: [RestoreDiagnostic] = []

        do {
            snapshot = try await persistenceStore.loadRestoreSnapshot()
        } catch {
            snapshot = nil
            diagnostics.append(RestoreDiagnostic(
                severity: .failure,
                message: "Restore snapshot could not be read; reopened available workspace metadata without saved selection."
            ))
        }

        let accessibleProjects = projects.filter { project in
            directoryIsAccessible(URL(fileURLWithPath: project.path).standardizedFileURL.path)
        }
        let accessibleProjectIDs = Set(accessibleProjects.map(\.id))
        let skippedProjects = projects
            .filter { !accessibleProjectIDs.contains($0.id) }
            .map { project in
                SkippedRestoredProject(
                    id: project.id,
                    path: project.path,
                    displayName: project.displayName,
                    reason: "Project folder is missing or inaccessible."
                )
            }
        diagnostics.append(contentsOf: skippedProjects.map { skippedProject in
            RestoreDiagnostic(
                severity: .warning,
                message: "Skipped inaccessible restored project: \(skippedProject.displayName)."
            )
        })

        let restoredSessions = sessions.filter { accessibleProjectIDs.contains($0.projectID) }
        let restoredSessionIDs = Set(restoredSessions.map(\.id))
        let restoredTabs = orderedTabs(tabs.filter { restoredSessionIDs.contains($0.sessionID) }, snapshot: snapshot)

        let restoredStore = WorkspaceStore()
        restoredStore.restore(
            projects: accessibleProjects,
            sessions: restoredSessions,
            tabs: restoredTabs,
            selection: WorkspaceSelection(
                projectID: snapshot?.selectedProjectID,
                sessionID: snapshot?.selectedSessionID,
                tabID: snapshot?.selectedTabID
            )
        )

        diagnostics.append(RestoreDiagnostic(
            severity: .info,
            message: "Restored \(restoredStore.projects.count) project(s), \(restoredStore.sessions.count) session(s), and \(restoredStore.tabs.count) tab(s)."
        ))

        return RestoreWorkspaceResult(
            store: restoredStore,
            diagnostics: diagnostics,
            skippedProjects: skippedProjects
        )
    }

    private func orderedTabs(_ tabs: [WorkspaceTab], snapshot: RestoreSnapshot?) -> [WorkspaceTab] {
        guard let snapshot else { return tabs }
        var snapshotOrder: [UUID: Int] = [:]
        for tabID in snapshot.tabOrder where snapshotOrder[tabID] == nil {
            snapshotOrder[tabID] = snapshotOrder.count
        }
        return tabs.sorted {
            let lhsOrder = snapshotOrder[$0.id]
            let rhsOrder = snapshotOrder[$1.id]
            switch (lhsOrder, rhsOrder) {
            case let (lhs?, rhs?):
                return lhs == rhs ? $0.ordinal < $1.ordinal : lhs < rhs
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                if $0.sessionID == $1.sessionID { return $0.ordinal < $1.ordinal }
                return $0.sessionID.uuidString < $1.sessionID.uuidString
            }
        }.enumerated().map { offset, tab in
            var orderedTab = tab
            orderedTab.ordinal = offset
            return orderedTab
        }
    }
}
