import Foundation

struct SessionSidebarDisclosureState: Equatable {
    private(set) var expandedSessionIDs: Set<UUID> = []

    func isExpanded(_ sessionID: UUID) -> Bool {
        expandedSessionIDs.contains(sessionID)
    }

    mutating func toggle(_ sessionID: UUID) {
        if expandedSessionIDs.contains(sessionID) {
            expandedSessionIDs.remove(sessionID)
        } else {
            expandedSessionIDs.insert(sessionID)
        }
    }

    mutating func collapse(_ sessionID: UUID) {
        expandedSessionIDs.remove(sessionID)
    }

    mutating func keepOnly(_ availableSessionIDs: some Sequence<UUID>) {
        expandedSessionIDs.formIntersection(Set(availableSessionIDs))
    }

    func visibleSummaries(
        for sessionID: UUID,
        summaries: [SessionTerminalSummary]
    ) -> [SessionTerminalSummary] {
        guard isExpanded(sessionID) else {
            return []
        }

        return summaries.filter { $0.sessionID == sessionID }
    }
}
