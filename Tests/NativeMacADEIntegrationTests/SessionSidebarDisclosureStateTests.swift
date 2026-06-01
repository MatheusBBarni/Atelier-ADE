import Foundation
import Testing
@testable import NativeMacADE
import NativeMacADECore

@Suite
@MainActor
struct SessionSidebarDisclosureStateTests {
    @Test
    func defaultStateKeepsSessionTerminalSummariesCollapsed() {
        let sessionID = UUID()
        let summary = makeSummary(sessionID: sessionID, tabID: UUID())
        let disclosure = SessionSidebarDisclosureState()

        #expect(disclosure.isExpanded(sessionID) == false)
        #expect(disclosure.visibleSummaries(for: sessionID, summaries: [summary]).isEmpty)
    }

    @Test
    func expandedStateRevealsTerminalSummariesProducedByBuilderOnly() {
        let project = WorkspaceProject(path: "/tmp/native-mac-ade-disclosure", displayName: "Disclosure")
        let session = WorkspaceSession(projectID: project.id, title: "Disclosure")
        let firstTerminal = WorkspaceTab(
            sessionID: session.id,
            kind: .terminal,
            workingDirectory: project.path,
            launchCommand: "codex",
            ordinal: 0
        )
        let fileTab = WorkspaceTab(
            sessionID: session.id,
            kind: .file,
            workingDirectory: project.path,
            title: "File.swift",
            fileReference: WorkspaceFileReference(
                path: "\(project.path)/File.swift",
                projectRoot: project.path
            ),
            ordinal: 1
        )
        let secondTerminal = WorkspaceTab(
            sessionID: session.id,
            kind: .terminal,
            workingDirectory: project.path,
            launchCommand: "claude",
            ordinal: 2
        )
        let store = WorkspaceStore(
            projects: [project],
            sessions: [session],
            tabs: [firstTerminal, fileTab, secondTerminal],
            selectedProjectID: project.id,
            selectedSessionID: session.id,
            selectedTabID: firstTerminal.id
        )
        var disclosure = SessionSidebarDisclosureState()

        disclosure.toggle(session.id)
        let summaries = SessionTerminalSummaryBuilder(store: store).summaries(for: session)
        let visibleSummaries = disclosure.visibleSummaries(for: session.id, summaries: summaries)

        #expect(visibleSummaries.map(\.tabID) == [firstTerminal.id, secondTerminal.id])
        #expect(visibleSummaries.map(\.tabID).contains(fileTab.id) == false)
    }

    @Test
    func staleExpandedSessionIDsArePrunedWhenSessionsDisappear() {
        let retained = UUID()
        let removed = UUID()
        var disclosure = SessionSidebarDisclosureState()
        disclosure.toggle(retained)
        disclosure.toggle(removed)

        disclosure.keepOnly([retained])

        #expect(disclosure.isExpanded(retained))
        #expect(disclosure.isExpanded(removed) == false)
    }

    @Test
    func collapseRemovesOneExpandedSessionWithoutAffectingOthers() {
        let retained = UUID()
        let collapsed = UUID()
        var disclosure = SessionSidebarDisclosureState()
        disclosure.toggle(retained)
        disclosure.toggle(collapsed)

        disclosure.collapse(collapsed)

        #expect(disclosure.isExpanded(retained))
        #expect(disclosure.isExpanded(collapsed) == false)
    }

    private func makeSummary(sessionID: UUID, tabID: UUID) -> SessionTerminalSummary {
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
            isSelected: false
        )
    }
}
