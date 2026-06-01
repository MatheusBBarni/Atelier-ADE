import Foundation
import Testing
@testable import NativeMacADECore

struct WorkspaceTabNavigationTests {
    @Test
    func adjacentTraversalFollowsReorderedMixedTabOrdinals() {
        let sessionID = UUID()
        let firstTerminalTabID = UUID()
        let fileTabID = UUID()
        let secondTerminalTabID = UUID()
        let orderedTabs = [
            WorkspaceTab(id: fileTabID, sessionID: sessionID, kind: .file, workingDirectory: "/tmp/project", ordinal: 0),
            WorkspaceTab(id: secondTerminalTabID, sessionID: sessionID, workingDirectory: "/tmp/project", ordinal: 1),
            WorkspaceTab(id: firstTerminalTabID, sessionID: sessionID, workingDirectory: "/tmp/project", ordinal: 2)
        ]

        #expect(WorkspaceTabNavigation.adjacentTabID(
            in: orderedTabs,
            selectedTabID: secondTerminalTabID,
            direction: 1
        ) == firstTerminalTabID)
        #expect(WorkspaceTabNavigation.adjacentTabID(
            in: orderedTabs,
            selectedTabID: secondTerminalTabID,
            direction: -1
        ) == fileTabID)
    }

    @Test
    func adjacentTraversalWrapsAtReorderedEdges() {
        let sessionID = UUID()
        let firstTabID = UUID()
        let secondTabID = UUID()
        let orderedTabs = [
            WorkspaceTab(id: firstTabID, sessionID: sessionID, workingDirectory: "/tmp/project", ordinal: 0),
            WorkspaceTab(id: secondTabID, sessionID: sessionID, workingDirectory: "/tmp/project", ordinal: 1)
        ]

        #expect(WorkspaceTabNavigation.adjacentTabID(
            in: orderedTabs,
            selectedTabID: firstTabID,
            direction: -1
        ) == secondTabID)
        #expect(WorkspaceTabNavigation.adjacentTabID(
            in: orderedTabs,
            selectedTabID: secondTabID,
            direction: 1
        ) == firstTabID)
    }
}
