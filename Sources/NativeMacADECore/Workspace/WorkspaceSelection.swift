import Foundation

public struct WorkspaceSelection: Equatable, Sendable {
    public var projectID: UUID?
    public var sessionID: UUID?
    public var tabID: UUID?

    public init(projectID: UUID? = nil, sessionID: UUID? = nil, tabID: UUID? = nil) {
        self.projectID = projectID
        self.sessionID = sessionID
        self.tabID = tabID
    }

    public static let empty = WorkspaceSelection()
}
