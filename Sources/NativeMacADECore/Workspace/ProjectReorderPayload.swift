import Foundation

public enum ProjectOrderInsertionEdge: Equatable, Sendable {
    case before
    case after
}

public struct ProjectOrderInsertion: Equatable, Sendable {
    public var targetProjectID: UUID
    public var edge: ProjectOrderInsertionEdge

    public init(targetProjectID: UUID, edge: ProjectOrderInsertionEdge) {
        self.targetProjectID = targetProjectID
        self.edge = edge
    }
}

public enum ProjectReorderPayload {
    public static func orderedProjectIDs(
        moving movedProjectID: UUID,
        to insertion: ProjectOrderInsertion,
        in currentProjectIDs: [UUID]
    ) -> [UUID]? {
        guard currentProjectIDs.contains(movedProjectID),
              currentProjectIDs.contains(insertion.targetProjectID)
        else {
            return nil
        }

        var reorderedIDs = currentProjectIDs.filter { $0 != movedProjectID }
        guard let targetIndex = reorderedIDs.firstIndex(of: insertion.targetProjectID) else {
            return nil
        }

        let insertionIndex: Int
        switch insertion.edge {
        case .before:
            insertionIndex = targetIndex
        case .after:
            insertionIndex = reorderedIDs.index(after: targetIndex)
        }

        reorderedIDs.insert(movedProjectID, at: insertionIndex)
        return reorderedIDs == currentProjectIDs ? nil : reorderedIDs
    }
}
