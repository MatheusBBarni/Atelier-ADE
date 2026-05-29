import Foundation
import SQLite3

public enum WorkspaceMigrationError: Error, Equatable, Sendable {
    case sqlite(String)
}

public enum WorkspaceMigrations {
    public static let currentUserVersion: Int32 = 2
    public static let metadataTables: Set<String> = [
        "projects",
        "sessions",
        "tabs",
        "session_shortcuts",
        "app_preferences",
        "restore_snapshot"
    ]

    static func bootstrap(database: OpaquePointer?) throws {
        try execute(database, "PRAGMA foreign_keys = ON")
        let existingUserVersion = try userVersion(database)
        try execute(database, projectsSQL)
        try execute(database, sessionsSQL)
        try execute(database, tabsSQL)
        try execute(database, sessionShortcutsSQL)
        try execute(database, appPreferencesSQL)
        try execute(database, restoreSnapshotSQL)
        if existingUserVersion < 2 {
            try migrateToV2(database)
        }
        if existingUserVersion <= currentUserVersion {
            try execute(database, "PRAGMA user_version = \(currentUserVersion)")
        }
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
        is_built_in INTEGER NOT NULL CHECK (is_built_in IN (0, 1)),
        has_user_override INTEGER NOT NULL DEFAULT 0 CHECK (has_user_override IN (0, 1))
    )
    """

    private static let appPreferencesSQL = """
    CREATE TABLE IF NOT EXISTS app_preferences (
        id INTEGER PRIMARY KEY NOT NULL CHECK (id = 1),
        theme_id TEXT NOT NULL,
        default_session_shortcut_id TEXT REFERENCES session_shortcuts(id) ON DELETE SET NULL,
        keybindings_json TEXT NOT NULL,
        updated_at REAL NOT NULL
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

    private static func migrateToV2(_ database: OpaquePointer?) throws {
        try execute(database, appPreferencesSQL)
        if try !table("session_shortcuts", hasColumn: "has_user_override", database: database) {
            try execute(database, "ALTER TABLE session_shortcuts ADD COLUMN has_user_override INTEGER NOT NULL DEFAULT 0 CHECK (has_user_override IN (0, 1))")
        }
        try execute(database, """
        INSERT OR IGNORE INTO app_preferences (id, theme_id, default_session_shortcut_id, keybindings_json, updated_at)
        VALUES (1, '\(AppPreferences.defaultThemeID)', NULL, '[]', 0)
        """)
    }

    private static func userVersion(_ database: OpaquePointer?) throws -> Int32 {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK else {
            throw WorkspaceMigrationError.sqlite(lastErrorMessage(database))
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw WorkspaceMigrationError.sqlite("Unable to read SQLite user_version")
        }
        return sqlite3_column_int(statement, 0)
    }

    private static func table(_ tableName: String, hasColumn columnName: String, database: OpaquePointer?) throws -> Bool {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA table_info(\(tableName))", -1, &statement, nil) == SQLITE_OK else {
            throw WorkspaceMigrationError.sqlite(lastErrorMessage(database))
        }
        defer { sqlite3_finalize(statement) }

        while true {
            let result = sqlite3_step(statement)
            switch result {
            case SQLITE_ROW:
                guard let pointer = sqlite3_column_text(statement, 1) else { continue }
                if String(cString: pointer) == columnName {
                    return true
                }
            case SQLITE_DONE:
                return false
            default:
                throw WorkspaceMigrationError.sqlite(lastErrorMessage(database))
            }
        }
    }

    private static func lastErrorMessage(_ database: OpaquePointer?) -> String {
        database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
    }
}
