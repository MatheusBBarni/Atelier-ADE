import Foundation

public struct WorkspaceProject: Identifiable, Equatable, Sendable {
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

public struct WorkspaceSession: Identifiable, Equatable, Sendable {
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
        title: String,
        isUserNamed: Bool = false,
        shortcutID: UUID? = nil,
        createdAt: Date = Date(),
        lastActivatedAt: Date = Date()
    ) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.isUserNamed = isUserNamed
        self.shortcutID = shortcutID
        self.createdAt = createdAt
        self.lastActivatedAt = lastActivatedAt
    }
}

public struct WorkspaceTab: Identifiable, Equatable, Sendable {
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

public struct RestoreSnapshot: Equatable, Sendable {
    public var selectedProjectID: UUID?
    public var selectedSessionID: UUID?
    public var selectedTabID: UUID?
    public var openTabIDs: [UUID]
    public var capturedAt: Date

    public init(
        selectedProjectID: UUID?,
        selectedSessionID: UUID?,
        selectedTabID: UUID?,
        openTabIDs: [UUID],
        capturedAt: Date = Date()
    ) {
        self.selectedProjectID = selectedProjectID
        self.selectedSessionID = selectedSessionID
        self.selectedTabID = selectedTabID
        self.openTabIDs = openTabIDs
        self.capturedAt = capturedAt
    }
}
