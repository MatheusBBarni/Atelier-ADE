import Foundation

public struct Project: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var path: String
    public var bookmarkData: Data?
    public var displayName: String
    public var createdAt: Date
    public var lastOpenedAt: Date
    public var sortIndex: Int

    public init(
        id: UUID = UUID(),
        path: String,
        bookmarkData: Data? = nil,
        displayName: String,
        createdAt: Date = Date(),
        lastOpenedAt: Date = Date(),
        sortIndex: Int = 0
    ) {
        self.id = id
        self.path = path
        self.bookmarkData = bookmarkData
        self.displayName = displayName
        self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt
        self.sortIndex = sortIndex
    }
}

public typealias WorkspaceProject = Project

public struct Session: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var projectID: UUID
    public var title: String
    public var isUserNamed: Bool
    public var shortcutID: UUID?
    public var createdAt: Date
    public var lastActivatedAt: Date

    public init(
        id: UUID = UUID(),
        projectID: UUID,
        title: String? = nil,
        isUserNamed: Bool = false,
        shortcutID: UUID? = nil,
        createdAt: Date = Date(),
        lastActivatedAt: Date = Date()
    ) {
        self.id = id
        self.projectID = projectID
        self.title = title ?? Self.defaultTitle(for: createdAt)
        self.isUserNamed = isUserNamed
        self.shortcutID = shortcutID
        self.createdAt = createdAt
        self.lastActivatedAt = lastActivatedAt
    }

    public mutating func rename(to title: String) {
        self.title = title
        self.isUserNamed = true
    }

    public static func defaultTitle(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}

public typealias WorkspaceSession = Session

public struct Tab: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var sessionID: UUID
    public var workingDirectory: String
    public var launchCommand: String?
    public var launchArgumentsJSON: String?
    public var ordinal: Int
    public var createdAt: Date
    public var lastActivatedAt: Date

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        workingDirectory: String,
        launchCommand: String? = nil,
        launchArgumentsJSON: String? = nil,
        ordinal: Int,
        createdAt: Date = Date(),
        lastActivatedAt: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.workingDirectory = workingDirectory
        self.launchCommand = launchCommand
        self.launchArgumentsJSON = launchArgumentsJSON
        self.ordinal = ordinal
        self.createdAt = createdAt
        self.lastActivatedAt = lastActivatedAt
    }
}

public typealias WorkspaceTab = Tab

public struct SessionShortcut: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var label: String
    public var launchCommand: String
    public var launchArgumentsJSON: String?
    public var secretRef: String?
    public var isBuiltIn: Bool
    public var hasUserOverride: Bool

    public init(
        id: UUID = UUID(),
        label: String,
        launchCommand: String,
        launchArgumentsJSON: String? = nil,
        secretRef: String? = nil,
        isBuiltIn: Bool = false,
        hasUserOverride: Bool = false
    ) {
        self.id = id
        self.label = label
        self.launchCommand = launchCommand
        self.launchArgumentsJSON = launchArgumentsJSON
        self.secretRef = secretRef
        self.isBuiltIn = isBuiltIn
        self.hasUserOverride = hasUserOverride
    }

    public static let builtInDefaults: [SessionShortcut] = [
        SessionShortcut(
            id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            label: "Codex",
            launchCommand: "codex",
            launchArgumentsJSON: "[]",
            isBuiltIn: true
        ),
        SessionShortcut(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            label: "Claude",
            launchCommand: "claude",
            launchArgumentsJSON: "[]",
            isBuiltIn: true
        )
    ]
}

public struct RestoreSnapshot: Equatable, Sendable {
    public var id: Int
    public var selectedProjectID: UUID?
    public var selectedSessionID: UUID?
    public var selectedTabID: UUID?
    public var tabOrder: [UUID]
    public var updatedAt: Date

    public init(
        id: Int = 1,
        selectedProjectID: UUID?,
        selectedSessionID: UUID?,
        selectedTabID: UUID?,
        tabOrder: [UUID],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.selectedProjectID = selectedProjectID
        self.selectedSessionID = selectedSessionID
        self.selectedTabID = selectedTabID
        self.tabOrder = tabOrder
        self.updatedAt = updatedAt
    }

    public init(
        selectedProjectID: UUID?,
        selectedSessionID: UUID?,
        selectedTabID: UUID?,
        openTabIDs: [UUID],
        capturedAt: Date = Date()
    ) {
        self.init(
            selectedProjectID: selectedProjectID,
            selectedSessionID: selectedSessionID,
            selectedTabID: selectedTabID,
            tabOrder: openTabIDs,
            updatedAt: capturedAt
        )
    }

    public var openTabIDs: [UUID] {
        get { tabOrder }
        set { tabOrder = newValue }
    }

    public var capturedAt: Date {
        get { updatedAt }
        set { updatedAt = newValue }
    }

    public var tabOrderJSON: String {
        get throws {
            let data = try JSONEncoder().encode(tabOrder.map(\.uuidString))
            return String(decoding: data, as: UTF8.self)
        }
    }

    public static func decodeTabOrderJSON(_ json: String) throws -> [UUID] {
        let strings = try JSONDecoder().decode([String].self, from: Data(json.utf8))
        return try strings.map { value in
            guard let uuid = UUID(uuidString: value) else {
                throw RestoreSnapshotSerializationError.invalidTabID(value)
            }
            return uuid
        }
    }
}

public enum RestoreSnapshotSerializationError: Error, Equatable, Sendable {
    case invalidTabID(String)
}
