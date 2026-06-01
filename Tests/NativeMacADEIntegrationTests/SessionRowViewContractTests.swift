import Foundation
import Testing
@testable import NativeMacADE
import NativeMacADECore

@Suite
@MainActor
struct SessionRowViewContractTests {
    @Test
    func secondarySessionListViewCallShapeStillBuildsCollapsedRow() {
        let session = WorkspaceSession(projectID: UUID(), title: "Secondary")

        let row = SessionRowView(
            session: session,
            isActive: false,
            showsMenu: true,
            onSelect: {},
            onRename: {},
            onDelete: {}
        )

        #expect(row.terminalSummaries.isEmpty)
        #expect(row.isExpanded == false)
        _ = row.body
    }

    @Test
    func expandedSessionRowBuildsBodyWithTerminalChildSummary() {
        let sessionID = UUID()
        let session = WorkspaceSession(id: sessionID, projectID: UUID(), title: "Expanded")
        let summary = makeSummary(sessionID: sessionID, tabID: UUID(), isSelected: true)
        let row = SessionRowView(
            session: session,
            terminalSummaries: [summary],
            isExpanded: true,
            isActive: true,
            showsMenu: false,
            onToggleDisclosure: {},
            onSelect: {},
            onSelectTerminal: { _ in },
            onRename: {},
            onDelete: {}
        )

        #expect(row.terminalSummaries.map(\.tabID) == [summary.tabID])
        #expect(row.isExpanded)
        _ = row.body
    }

    @Test
    func duplicateTerminalLabelsStillExposeDistinctChildRowSelectionTargets() {
        let sessionID = UUID()
        let firstTabID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let secondTabID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let firstSummary = makeSummary(sessionID: sessionID, tabID: firstTabID)
        let secondSummary = makeSummary(sessionID: sessionID, tabID: secondTabID)
        var selectedTabIDs: [UUID] = []
        let firstRow = SessionTerminalChildRowView(summary: firstSummary) { selectedTabIDs.append($0) }
        let secondRow = SessionTerminalChildRowView(summary: secondSummary) { selectedTabIDs.append($0) }

        firstRow.onSelect(firstRow.selectionTabID)
        secondRow.onSelect(secondRow.selectionTabID)

        #expect(firstSummary.title == secondSummary.title)
        #expect(firstRow.selectionTabID == firstTabID)
        #expect(secondRow.selectionTabID == secondTabID)
        #expect(selectedTabIDs == [firstTabID, secondTabID])
        _ = firstRow.body
    }

    private func makeSummary(
        sessionID: UUID,
        tabID: UUID,
        isSelected: Bool = false
    ) -> SessionTerminalSummary {
        SessionTerminalSummary(
            sessionID: sessionID,
            tabID: tabID,
            title: "Codex",
            fallbackTitle: "Codex",
            agentLabel: "Codex",
            shortcutID: nil,
            iconInput: .terminal,
            lastActivatedAt: Date(timeIntervalSince1970: 0),
            exitObservation: nil,
            isSelected: isSelected
        )
    }
}
