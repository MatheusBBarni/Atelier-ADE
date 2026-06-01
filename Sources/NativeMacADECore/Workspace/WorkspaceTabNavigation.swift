import Foundation

public enum WorkspaceTabNavigation {
    public static func adjacentTabID(
        in orderedTabs: [WorkspaceTab],
        selectedTabID: UUID?,
        direction: Int
    ) -> UUID? {
        guard orderedTabs.count > 1 else { return nil }
        let currentIndex = selectedTabID.flatMap { selectedTabID in
            orderedTabs.firstIndex { $0.id == selectedTabID }
        } ?? 0
        let nextIndex = wrappedIndex(currentIndex + direction, count: orderedTabs.count)
        return orderedTabs[nextIndex].id
    }

    private static func wrappedIndex(_ index: Int, count: Int) -> Int {
        (index % count + count) % count
    }
}
