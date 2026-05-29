import Foundation
import SQLite3

public enum WorkspaceMigrationError: Error, Equatable, Sendable {
    case sqlite(String)
}

public enum WorkspaceMigrations {
    public static let currentUserVersion: Int32 = 1
    public static let metadataTables: Set<String> = [
        "projects",
        "sessions",
        "tabs",
        "session_shortcuts",
        "restore_snapshot"
    ]

    static func bootstrap(database: OpaquePointer?) throws {
        try execute(database, "PRAGMA foreign_keys = ON")
        try execute(database, projectsSQL)
        try execute(database, sessionsSQL)
        try execute(database, tabsSQL)
        try execute(database, sessionShortcutsSQL)
        try execute(database, restoreSnapshotSQL)
        try execute(database, "PRAGMA user_version = \(currentUserVersion)")
    }

    static func execute(_ database: OpaquePointer?, _ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(database, sql, nil, nil, &error) != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? "Unknown SQLite error"
            sqlite3_free(error)
            throw WorkspaceMigrationError.sqlite(message)
        }
    }

    private static let projectsSQL = """
    CREATE TABLE IF NOT EXISTS projects (
        id TEXT PRIMARY KEY NOT NULL,
        path TEXT NOT NULL UNIQUE,
        bookmark_data BLOB,
        display_name TEXT NOT NULL,
        created_at REAL NOT NULL,
        last_opened_at REAL NOT NULL,
        sort_index INTEGER NOT NULL
    )
    """

    private static let sessionsSQL = """
    CREATE TABLE IF NOT EXISTS sessions (
        id TEXT PRIMARY KEY NOT NULL,
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        is_user_named INTEGER NOT NULL CHECK (is_user_named IN (0, 1)),
        shortcut_id TEXT REFERENCES session_shortcuts(id) ON DELETE SET NULL,
        created_at REAL NOT NULL,
        last_activated_at REAL NOT NULL
    )
    """

    private static let tabsSQL = """
    CREATE TABLE IF NOT EXISTS tabs (
        id TEXT PRIMARY KEY NOT NULL,
        session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        working_directory TEXT NOT NULL,
        launch_command TEXT,
        launch_arguments_json TEXT,
        ordinal INTEGER NOT NULL,
        created_at REAL NOT NULL,
        last_activated_at REAL NOT NULL,
        UNIQUE(session_id, ordinal)
    )
    """

    private static let sessionShortcutsSQL = """
    CREATE TABLE IF NOT EXISTS session_shortcuts (
        id TEXT PRIMARY KEY NOT NULL,
        label TEXT NOT NULL,
        launch_command TEXT NOT NULL,
        launch_arguments_json TEXT,
        secret_ref TEXT,
        is_built_in INTEGER NOT NULL CHECK (is_built_in IN (0, 1))
    )
    """

    private static let restoreSnapshotSQL = """
    CREATE TABLE IF NOT EXISTS restore_snapshot (
        id INTEGER PRIMARY KEY NOT NULL CHECK (id = 1),
        selected_project_id TEXT REFERENCES projects(id) ON DELETE SET NULL,
        selected_session_id TEXT REFERENCES sessions(id) ON DELETE SET NULL,
        selected_tab_id TEXT REFERENCES tabs(id) ON DELETE SET NULL,
        tab_order_json TEXT NOT NULL,
        updated_at REAL NOT NULL
    )
    """
}
