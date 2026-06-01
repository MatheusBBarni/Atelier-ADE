import Foundation

public enum TabOrderInsertionEdge: Equatable, Sendable {
    case before
    case after
}

public struct TabOrderInsertion: Equatable, Sendable {
    public var targetTabID: UUID
    public var edge: TabOrderInsertionEdge

    public init(targetTabID: UUID, edge: TabOrderInsertionEdge) {
        self.targetTabID = targetTabID
        self.edge = edge
    }
}

public enum TabReorderPayload {
    public static func orderedVisibleTabIDs(
        moving movedTabID: UUID,
        to insertion: TabOrderInsertion,
        in currentVisibleTabIDs: [UUID]
    ) -> [UUID]? {
        guard currentVisibleTabIDs.contains(movedTabID),
              currentVisibleTabIDs.contains(insertion.targetTabID)
        else {
            return nil
        }

        var reorderedIDs = currentVisibleTabIDs.filter { $0 != movedTabID }
        guard let targetIndex = reorderedIDs.firstIndex(of: insertion.targetTabID) else {
            return nil
        }

        let insertionIndex: Int
        switch insertion.edge {
        case .before:
            insertionIndex = targetIndex
        case .after:
            insertionIndex = reorderedIDs.index(after: targetIndex)
        }

        reorderedIDs.insert(movedTabID, at: insertionIndex)
        return reorderedIDs == currentVisibleTabIDs ? nil : reorderedIDs
    }
}
