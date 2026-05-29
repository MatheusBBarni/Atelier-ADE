import Foundation
import SQLite3

public enum SQLiteWorkspaceMetadataStoreError: Error, Equatable, Sendable {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case invalidStoredValue(String)
}

public actor SQLiteWorkspaceMetadataStore: WorkspacePersistenceStore {
    private nonisolated(unsafe) let database: OpaquePointer?
    private let ownsDatabase: Bool

    public init(path: String) throws {
        var database: OpaquePointer?
        if sqlite3_open_v2(path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open SQLite database"
            sqlite3_close(database)
            throw SQLiteWorkspaceMetadataStoreError.openFailed(message)
        }
        self.database = database
        self.ownsDatabase = true
        try WorkspaceMigrations.bootstrap(database: database)
    }

    public init(inMemoryIdentifier: String = UUID().uuidString) throws {
        var database: OpaquePointer?
        let path = "file:\(inMemoryIdentifier)?mode=memory&cache=shared"
        if sqlite3_open_v2(path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_URI, nil) != SQLITE_OK {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open in-memory SQLite database"
            sqlite3_close(database)
            throw SQLiteWorkspaceMetadataStoreError.openFailed(message)
        }
        self.database = database
        self.ownsDatabase = true
        try WorkspaceMigrations.bootstrap(database: database)
    }

    deinit {
        if ownsDatabase {
            sqlite3_close(database)
        }
    }

    public func loadProjects() async throws -> [WorkspaceProject] {
        try query("SELECT id, path, bookmark_data, display_name, created_at, last_opened_at, sort_index FROM projects ORDER BY sort_index ASC, last_opened_at DESC") { statement in
            try WorkspaceProject(
                id: uuid(statement, 0),
                path: text(statement, 1),
                bookmarkData: blob(statement, 2),
                displayName: text(statement, 3),
                createdAt: date(statement, 4),
                lastOpenedAt: date(statement, 5),
                sortIndex: int(statement, 6)
            )
        }
    }

    public func loadSessions() async throws -> [WorkspaceSession] {
        try query("SELECT id, project_id, title, is_user_named, shortcut_id, created_at, last_activated_at FROM sessions ORDER BY last_activated_at DESC, created_at DESC") { statement in
            try WorkspaceSession(
                id: uuid(statement, 0),
                projectID: uuid(statement, 1),
                title: text(statement, 2),
                isUserNamed: bool(statement, 3),
                shortcutID: optionalUUID(statement, 4),
                createdAt: date(statement, 5),
                lastActivatedAt: date(statement, 6)
            )
        }
    }

    public func loadTabs() async throws -> [WorkspaceTab] {
        try query("SELECT id, session_id, working_directory, launch_command, launch_arguments_json, kind, file_path, ordinal, created_at, last_activated_at FROM tabs ORDER BY session_id ASC, ordinal ASC") { statement in
            let tabID = try uuid(statement, 0)
            let workingDirectory = try text(statement, 2)
            let kind = try workspaceTabKind(statement, 5)
            let filePath = optionalText(statement, 6)
            return try WorkspaceTab(
                id: tabID,
                sessionID: uuid(statement, 1),
                kind: kind,
                workingDirectory: workingDirectory,
                launchCommand: optionalText(statement, 3),
                launchArgumentsJSON: optionalText(statement, 4),
                fileReference: workspaceFileReference(
                    tabID: tabID,
                    kind: kind,
                    filePath: filePath,
                    workingDirectory: workingDirectory
                ),
                ordinal: int(statement, 7),
                createdAt: date(statement, 8),
                lastActivatedAt: date(statement, 9)
            )
        }
    }

    public func loadSessionShortcuts() async throws -> [SessionShortcut] {
        try query("SELECT id, label, launch_command, launch_arguments_json, secret_ref, is_built_in, has_user_override FROM session_shortcuts ORDER BY label ASC") { statement in
            try SessionShortcut(
                id: uuid(statement, 0),
                label: text(statement, 1),
                launchCommand: text(statement, 2),
                launchArgumentsJSON: optionalText(statement, 3),
                secretRef: optionalText(statement, 4),
                isBuiltIn: bool(statement, 5),
                hasUserOverride: bool(statement, 6)
            )
        }
    }

    public func loadAppPreferences() async throws -> AppPreferences {
        let preferences = try query("SELECT id, theme_id, default_session_shortcut_id, keybindings_json, updated_at FROM app_preferences WHERE id = 1") { statement in
            try AppPreferences(
                id: int(statement, 0),
                themeID: text(statement, 1),
                defaultSessionShortcutID: optionalUUID(statement, 2),
                keybindings: AppPreferences.decodeKeybindingsJSON(text(statement, 3)),
                updatedAt: date(statement, 4)
            )
        }.first
        return preferences ?? .defaults
    }

    public func loadRestoreSnapshot() async throws -> RestoreSnapshot? {
        try query("SELECT id, selected_project_id, selected_session_id, selected_tab_id, tab_order_json, updated_at FROM restore_snapshot WHERE id = 1") { statement in
            try RestoreSnapshot(
                id: int(statement, 0),
                selectedProjectID: optionalUUID(statement, 1),
                selectedSessionID: optionalUUID(statement, 2),
                selectedTabID: optionalUUID(statement, 3),
                tabOrder: RestoreSnapshot.decodeTabOrderJSON(text(statement, 4)),
                updatedAt: date(statement, 5)
            )
        }.first
    }

    public func save(project: WorkspaceProject) async throws {
        try saveProject(project)
    }

    private func saveProject(_ project: WorkspaceProject) throws {
        try execute("""
            INSERT INTO projects (id, path, bookmark_data, display_name, created_at, last_opened_at, sort_index)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                path = excluded.path,
                bookmark_data = excluded.bookmark_data,
                display_name = excluded.display_name,
                created_at = excluded.created_at,
                last_opened_at = excluded.last_opened_at,
                sort_index = excluded.sort_index
            """) { statement in
            bind(statement, project.id, 1)
            bind(statement, project.path, 2)
            bind(statement, project.bookmarkData, 3)
            bind(statement, project.displayName, 4)
            bind(statement, project.createdAt, 5)
            bind(statement, project.lastOpenedAt, 6)
            bind(statement, project.sortIndex, 7)
        }
    }

    public func save(session: WorkspaceSession) async throws {
        try saveSession(session)
    }

    private func saveSession(_ session: WorkspaceSession) throws {
        try execute("""
            INSERT INTO sessions (id, project_id, title, is_user_named, shortcut_id, created_at, last_activated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                project_id = excluded.project_id,
                title = excluded.title,
                is_user_named = excluded.is_user_named,
                shortcut_id = excluded.shortcut_id,
                created_at = excluded.created_at,
                last_activated_at = excluded.last_activated_at
            """) { statement in
            bind(statement, session.id, 1)
            bind(statement, session.projectID, 2)
            bind(statement, session.title, 3)
            bind(statement, session.isUserNamed, 4)
            bind(statement, session.shortcutID, 5)
            bind(statement, session.createdAt, 6)
            bind(statement, session.lastActivatedAt, 7)
        }
    }

    public func save(tab: WorkspaceTab) async throws {
        try saveTab(tab)
    }

    private func saveTab(_ tab: WorkspaceTab) throws {
        let filePath = try persistedFilePath(for: tab)
        try execute("""
            INSERT INTO tabs (id, session_id, working_directory, launch_command, launch_arguments_json, kind, file_path, ordinal, created_at, last_activated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                session_id = excluded.session_id,
                working_directory = excluded.working_directory,
                launch_command = excluded.launch_command,
                launch_arguments_json = excluded.launch_arguments_json,
                kind = excluded.kind,
                file_path = excluded.file_path,
                ordinal = excluded.ordinal,
                created_at = excluded.created_at,
                last_activated_at = excluded.last_activated_at
            """) { statement in
            bind(statement, tab.id, 1)
            bind(statement, tab.sessionID, 2)
            bind(statement, tab.workingDirectory, 3)
            bind(statement, tab.launchCommand, 4)
            bind(statement, tab.launchArgumentsJSON, 5)
            bind(statement, tab.kind.rawValue, 6)
            bind(statement, filePath, 7)
            bind(statement, tab.ordinal, 8)
            bind(statement, tab.createdAt, 9)
            bind(statement, tab.lastActivatedAt, 10)
        }
    }

    public func save(session: WorkspaceSession, firstTab: WorkspaceTab) async throws {
        do {
            try executeRaw("BEGIN IMMEDIATE TRANSACTION")
            try saveSession(session)
            try saveTab(firstTab)
            try executeRaw("COMMIT")
        } catch {
            try? executeRaw("ROLLBACK")
            throw error
        }
    }

    public func saveActivation(
        project: WorkspaceProject?,
        session: WorkspaceSession?,
        tab: WorkspaceTab?,
        snapshot: RestoreSnapshot
    ) async throws {
        do {
            try executeRaw("BEGIN IMMEDIATE TRANSACTION")
            if let project { try saveProject(project) }
            if let session { try saveSession(session) }
            if let tab { try saveTab(tab) }
            try saveSnapshot(snapshot)
            try executeRaw("COMMIT")
        } catch {
            try? executeRaw("ROLLBACK")
            throw error
        }
    }

    public func save(shortcut: SessionShortcut) async throws {
        try execute("""
            INSERT INTO session_shortcuts (id, label, launch_command, launch_arguments_json, secret_ref, is_built_in, has_user_override)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                label = excluded.label,
                launch_command = excluded.launch_command,
                launch_arguments_json = excluded.launch_arguments_json,
                secret_ref = excluded.secret_ref,
                is_built_in = excluded.is_built_in,
                has_user_override = excluded.has_user_override
            """) { statement in
            bind(statement, shortcut.id, 1)
            bind(statement, shortcut.label, 2)
            bind(statement, shortcut.launchCommand, 3)
            bind(statement, shortcut.launchArgumentsJSON, 4)
            bind(statement, shortcut.secretRef, 5)
            bind(statement, shortcut.isBuiltIn, 6)
            bind(statement, shortcut.hasUserOverride, 7)
        }
    }

    public func save(appPreferences: AppPreferences) async throws {
        let keybindingsJSON = try appPreferences.keybindingsJSON
        try execute("""
            INSERT INTO app_preferences (id, theme_id, default_session_shortcut_id, keybindings_json, updated_at)
            VALUES (1, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                theme_id = excluded.theme_id,
                default_session_shortcut_id = excluded.default_session_shortcut_id,
                keybindings_json = excluded.keybindings_json,
                updated_at = excluded.updated_at
            """) { statement in
            bind(statement, appPreferences.themeID, 1)
            bind(statement, appPreferences.defaultSessionShortcutID, 2)
            bind(statement, keybindingsJSON, 3)
            bind(statement, appPreferences.updatedAt, 4)
        }
    }

    public func save(snapshot: RestoreSnapshot) async throws {
        try saveSnapshot(snapshot)
    }

    private func saveSnapshot(_ snapshot: RestoreSnapshot) throws {
        let tabOrderJSON = try snapshot.tabOrderJSON
        try execute("""
            INSERT INTO restore_snapshot (id, selected_project_id, selected_session_id, selected_tab_id, tab_order_json, updated_at)
            VALUES (1, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                selected_project_id = excluded.selected_project_id,
                selected_session_id = excluded.selected_session_id,
                selected_tab_id = excluded.selected_tab_id,
                tab_order_json = excluded.tab_order_json,
                updated_at = excluded.updated_at
            """) { statement in
            bind(statement, snapshot.selectedProjectID, 1)
            bind(statement, snapshot.selectedSessionID, 2)
            bind(statement, snapshot.selectedTabID, 3)
            bind(statement, tabOrderJSON, 4)
            bind(statement, snapshot.updatedAt, 5)
        }
    }

    public func deleteProject(id: UUID) async throws {
        try execute("DELETE FROM projects WHERE id = ?") { statement in
            bind(statement, id, 1)
        }
    }

    public func deleteSession(id: UUID) async throws {
        try execute("DELETE FROM sessions WHERE id = ?") { statement in
            bind(statement, id, 1)
        }
    }

    public func deleteTab(id: UUID) async throws {
        try execute("DELETE FROM tabs WHERE id = ?") { statement in
            bind(statement, id, 1)
        }
    }

    public func deleteShortcut(id: UUID) async throws {
        do {
            try executeRaw("BEGIN IMMEDIATE TRANSACTION")
            try execute("UPDATE app_preferences SET default_session_shortcut_id = NULL, updated_at = ? WHERE default_session_shortcut_id = ?") { statement in
                bind(statement, Date(), 1)
                bind(statement, id, 2)
            }
            try execute("DELETE FROM session_shortcuts WHERE id = ?") { statement in
                bind(statement, id, 1)
            }
            try executeRaw("COMMIT")
        } catch {
            try? executeRaw("ROLLBACK")
            throw error
        }
    }

    private func execute(_ sql: String, bindValues: (OpaquePointer?) throws -> Void) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteWorkspaceMetadataStoreError.prepareFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        try bindValues(statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteWorkspaceMetadataStoreError.stepFailed(lastErrorMessage())
        }
    }

    private func executeRaw(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? lastErrorMessage()
            sqlite3_free(error)
            throw SQLiteWorkspaceMetadataStoreError.stepFailed(message)
        }
    }

    private func query<T>(_ sql: String, map: (OpaquePointer?) throws -> T) throws -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteWorkspaceMetadataStoreError.prepareFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        var values: [T] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                values.append(try map(statement))
            } else if result == SQLITE_DONE {
                return values
            } else {
                throw SQLiteWorkspaceMetadataStoreError.stepFailed(lastErrorMessage())
            }
        }
    }

    private func lastErrorMessage() -> String {
        database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
    }

    private func persistedFilePath(for tab: WorkspaceTab) throws -> String? {
        switch tab.kind {
        case .terminal:
            guard tab.fileReference == nil else {
                throw SQLiteWorkspaceMetadataStoreError.invalidStoredValue("Terminal tab \(tab.id.uuidString) cannot persist file metadata")
            }
            return nil
        case .file:
            guard let fileReference = tab.fileReference else {
                throw SQLiteWorkspaceMetadataStoreError.invalidStoredValue("File tab \(tab.id.uuidString) requires file metadata")
            }
            guard !fileReference.path.isEmpty else {
                throw SQLiteWorkspaceMetadataStoreError.invalidStoredValue("File tab \(tab.id.uuidString) requires a non-empty file path")
            }
            guard fileReference.projectRoot == tab.workingDirectory else {
                throw SQLiteWorkspaceMetadataStoreError.invalidStoredValue("File tab \(tab.id.uuidString) project root must match working_directory")
            }
            return fileReference.path
        }
    }
}

private let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func bind(_ statement: OpaquePointer?, _ value: String?, _ index: Int32) {
    if let value {
        sqlite3_bind_text(statement, index, value, -1, transientDestructor)
    } else {
        sqlite3_bind_null(statement, index)
    }
}

private func bind(_ statement: OpaquePointer?, _ value: UUID?, _ index: Int32) {
    bind(statement, value?.uuidString, index)
}

private func bind(_ statement: OpaquePointer?, _ value: Data?, _ index: Int32) {
    guard let value else {
        sqlite3_bind_null(statement, index)
        return
    }
    _ = value.withUnsafeBytes { bytes in
        sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(value.count), transientDestructor)
    }
}

private func bind(_ statement: OpaquePointer?, _ value: Date, _ index: Int32) {
    sqlite3_bind_double(statement, index, value.timeIntervalSince1970)
}

private func bind(_ statement: OpaquePointer?, _ value: Int, _ index: Int32) {
    sqlite3_bind_int64(statement, index, sqlite3_int64(value))
}

private func bind(_ statement: OpaquePointer?, _ value: Bool, _ index: Int32) {
    sqlite3_bind_int(statement, index, value ? 1 : 0)
}

private func text(_ statement: OpaquePointer?, _ index: Int32) throws -> String {
    guard let pointer = sqlite3_column_text(statement, index) else {
        throw SQLiteWorkspaceMetadataStoreError.invalidStoredValue("Expected text at column \(index)")
    }
    return String(cString: pointer)
}

private func optionalText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL,
          let pointer = sqlite3_column_text(statement, index)
    else { return nil }
    return String(cString: pointer)
}

private func uuid(_ statement: OpaquePointer?, _ index: Int32) throws -> UUID {
    let value = try text(statement, index)
    guard let uuid = UUID(uuidString: value) else {
        throw SQLiteWorkspaceMetadataStoreError.invalidStoredValue("Invalid UUID at column \(index)")
    }
    return uuid
}

private func optionalUUID(_ statement: OpaquePointer?, _ index: Int32) throws -> UUID? {
    guard let value = optionalText(statement, index) else { return nil }
    guard let uuid = UUID(uuidString: value) else {
        throw SQLiteWorkspaceMetadataStoreError.invalidStoredValue("Invalid UUID at column \(index)")
    }
    return uuid
}

private func blob(_ statement: OpaquePointer?, _ index: Int32) -> Data? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL,
          let bytes = sqlite3_column_blob(statement, index)
    else { return nil }
    return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, index)))
}

private func date(_ statement: OpaquePointer?, _ index: Int32) -> Date {
    Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
}

private func int(_ statement: OpaquePointer?, _ index: Int32) -> Int {
    Int(sqlite3_column_int64(statement, index))
}

private func bool(_ statement: OpaquePointer?, _ index: Int32) -> Bool {
    sqlite3_column_int(statement, index) != 0
}

private func workspaceTabKind(_ statement: OpaquePointer?, _ index: Int32) throws -> WorkspaceTabKind {
    let value = try text(statement, index)
    guard let kind = WorkspaceTabKind(rawValue: value) else {
        throw SQLiteWorkspaceMetadataStoreError.invalidStoredValue("Invalid workspace tab kind '\(value)' at column \(index)")
    }
    return kind
}

private func workspaceFileReference(
    tabID: UUID,
    kind: WorkspaceTabKind,
    filePath: String?,
    workingDirectory: String
) throws -> WorkspaceFileReference? {
    switch kind {
    case .terminal:
        guard filePath == nil else {
            throw SQLiteWorkspaceMetadataStoreError.invalidStoredValue("Terminal tab \(tabID.uuidString) cannot have file_path metadata")
        }
        return nil
    case .file:
        guard let filePath, !filePath.isEmpty else {
            throw SQLiteWorkspaceMetadataStoreError.invalidStoredValue("File tab \(tabID.uuidString) is missing file_path metadata")
        }
        return WorkspaceFileReference(path: filePath, projectRoot: workingDirectory)
    }
}
