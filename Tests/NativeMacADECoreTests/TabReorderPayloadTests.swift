import Foundation
import Testing
@testable import NativeMacADECore

struct TabReorderPayloadTests {
    @Test
    func movingTerminalTabAcrossMixedVisibleSetBuildsCommandPayload() {
        let firstTerminalTabID = UUID()
        let fileTabID = UUID()
        let secondTerminalTabID = UUID()

        let orderedVisibleTabIDs = TabReorderPayload.orderedVisibleTabIDs(
            moving: secondTerminalTabID,
            to: TabOrderInsertion(targetTabID: firstTerminalTabID, edge: .before),
            in: [firstTerminalTabID, fileTabID, secondTerminalTabID]
        )

        #expect(orderedVisibleTabIDs == [secondTerminalTabID, firstTerminalTabID, fileTabID])
    }

    @Test
    func droppingTabBackIntoOriginalPositionAvoidsPayloadChange() {
        let firstTabID = UUID()
        let secondTabID = UUID()
        let thirdTabID = UUID()
        let currentTabIDs = [firstTabID, secondTabID, thirdTabID]

        let afterPreviousTab = TabReorderPayload.orderedVisibleTabIDs(
            moving: secondTabID,
            to: TabOrderInsertion(targetTabID: firstTabID, edge: .after),
            in: currentTabIDs
        )
        let beforeNextTab = TabReorderPayload.orderedVisibleTabIDs(
            moving: secondTabID,
            to: TabOrderInsertion(targetTabID: thirdTabID, edge: .before),
            in: currentTabIDs
        )

        #expect(afterPreviousTab == nil)
        #expect(beforeNextTab == nil)
    }
}
