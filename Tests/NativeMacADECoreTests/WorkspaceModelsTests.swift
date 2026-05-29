import Foundation
import Testing
@testable import NativeMacADECore

struct WorkspaceModelsTests {
    @Test
    func defaultSessionNamingUsesMonthDayHourMinuteUntilRename() {
        let date = Date(timeIntervalSince1970: 1_717_393_500) // 2024-06-03 05:45 UTC
        let projectID = UUID()
        var session = WorkspaceSession(
            projectID: projectID,
            title: nil,
            createdAt: date,
            lastActivatedAt: date
        )

        #expect(WorkspaceSession.defaultTitle(for: date, timeZone: TimeZone(secondsFromGMT: 0)!) == "06-03 05:45")
        #expect(session.title == WorkspaceSession.defaultTitle(for: date))
        #expect(session.isUserNamed == false)

        session.rename(to: "Investigate parser")

        #expect(session.title == "Investigate parser")
        #expect(session.isUserNamed == true)
    }

    @Test
    func tabMetadataPreservesRelaunchFieldsAndOrdering() {
        let sessionID = UUID()
        let createdAt = Date(timeIntervalSince1970: 100)
        let activatedAt = Date(timeIntervalSince1970: 200)

        let tab = WorkspaceTab(
            sessionID: sessionID,
            workingDirectory: "/Users/example/project",
            launchCommand: "codex",
            launchArgumentsJSON: "[\"--ask-for-approval\",\"never\"]",
            ordinal: 2,
            createdAt: createdAt,
            lastActivatedAt: activatedAt
        )

        #expect(tab.sessionID == sessionID)
        #expect(tab.workingDirectory == "/Users/example/project")
        #expect(tab.launchCommand == "codex")
        #expect(tab.launchArgumentsJSON == "[\"--ask-for-approval\",\"never\"]")
        #expect(tab.ordinal == 2)
        #expect(tab.createdAt == createdAt)
        #expect(tab.lastActivatedAt == activatedAt)
    }

    @Test
    func restoreSnapshotSerializationPreservesSelectionAndTabOrder() throws {
        let projectID = UUID()
        let sessionID = UUID()
        let firstTabID = UUID()
        let secondTabID = UUID()
        let snapshot = RestoreSnapshot(
            selectedProjectID: projectID,
            selectedSessionID: sessionID,
            selectedTabID: secondTabID,
            tabOrder: [firstTabID, secondTabID],
            updatedAt: Date(timeIntervalSince1970: 300)
        )

        let encoded = try snapshot.tabOrderJSON
        let decoded = try RestoreSnapshot.decodeTabOrderJSON(encoded)

        #expect(snapshot.selectedProjectID == projectID)
        #expect(snapshot.selectedSessionID == sessionID)
        #expect(snapshot.selectedTabID == secondTabID)
        #expect(decoded == [firstTabID, secondTabID])
        #expect(snapshot.openTabIDs == [firstTabID, secondTabID])
    }
}
