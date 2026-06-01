import Foundation
import Testing
@testable import NativeMacADECore

struct ProjectReorderPayloadTests {
    @Test
    func movingBottomProjectBeforeTopProjectBuildsCommandPayload() {
        let firstProjectID = UUID()
        let secondProjectID = UUID()
        let thirdProjectID = UUID()

        let orderedProjectIDs = ProjectReorderPayload.orderedProjectIDs(
            moving: thirdProjectID,
            to: ProjectOrderInsertion(targetProjectID: firstProjectID, edge: .before),
            in: [firstProjectID, secondProjectID, thirdProjectID]
        )

        #expect(orderedProjectIDs == [thirdProjectID, firstProjectID, secondProjectID])
    }

    @Test
    func droppingProjectBackIntoOriginalPositionAvoidsPayloadChange() {
        let firstProjectID = UUID()
        let secondProjectID = UUID()
        let thirdProjectID = UUID()
        let currentProjectIDs = [firstProjectID, secondProjectID, thirdProjectID]

        let afterPreviousProject = ProjectReorderPayload.orderedProjectIDs(
            moving: secondProjectID,
            to: ProjectOrderInsertion(targetProjectID: firstProjectID, edge: .after),
            in: currentProjectIDs
        )
        let beforeNextProject = ProjectReorderPayload.orderedProjectIDs(
            moving: secondProjectID,
            to: ProjectOrderInsertion(targetProjectID: thirdProjectID, edge: .before),
            in: currentProjectIDs
        )

        #expect(afterPreviousProject == nil)
        #expect(beforeNextProject == nil)
    }
}
