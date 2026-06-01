import Foundation
import Testing
@testable import NativeMacADE
import NativeMacADECore

@Suite
@MainActor
struct SessionTerminalSummaryBuilderTests {
    @Test
    func mixedSessionBuildsTerminalSummariesOnly() throws {
        let fixture = SummaryFixture()
        let terminal = fixture.terminalTab(ordinal: 0, launchCommand: "codex")
        let file = fixture.fileTab(ordinal: 1)
        let secondTerminal = fixture.terminalTab(ordinal: 2, launchCommand: "claude")
        let store = fixture.store(tabs: [terminal, file, secondTerminal])

        let summaries = SessionTerminalSummaryBuilder(store: store).summaries(for: fixture.session)

        #expect(summaries.map(\.tabID) == [terminal.id, secondTerminal.id])
        #expect(summaries.allSatisfy { $0.sessionID == fixture.session.id })
    }

    @Test
    func summaryOrderingFollowsWorkspaceTerminalTabOrderNotRecency() throws {
        let fixture = SummaryFixture()
        let olderFirst = fixture.terminalTab(
            ordinal: 0,
            launchCommand: "codex",
            lastActivatedAt: Date(timeIntervalSince1970: 10)
        )
        let newerSecond = fixture.terminalTab(
            ordinal: 1,
            launchCommand: "claude",
            lastActivatedAt: Date(timeIntervalSince1970: 100)
        )
        let store = fixture.store(tabs: [newerSecond, olderFirst])

        let summaries = SessionTerminalSummaryBuilder(store: store).summaries(for: fixture.session)

        #expect(summaries.map(\.tabID) == [olderFirst.id, newerSecond.id])
        #expect(summaries.map(\.lastActivatedAt) == [olderFirst.lastActivatedAt, newerSecond.lastActivatedAt])
    }

    @Test
    func refreshedCatalogResolvesUpdatedCustomLabelAndIconData() throws {
        let fixture = SummaryFixture()
        let shortcutID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
        let initialShortcut = SessionShortcut(
            id: shortcutID,
            label: "Review Bot",
            launchCommand: "/usr/local/bin/codex",
            launchArgumentsJSON: "[\"--review\"]"
        )
        let updatedShortcut = SessionShortcut(
            id: shortcutID,
            label: "Review Bot Fast",
            launchCommand: "/usr/local/bin/codex",
            launchArgumentsJSON: "[\"--fast\"]",
            hasUserOverride: true
        )
        let tab = fixture.terminalTab(shortcutID: shortcutID, launchCommand: "ignored")
        let store = fixture.store(tabs: [tab])

        let initial = try #require(
            SessionTerminalSummaryBuilder(
                store: store,
                shortcutCatalog: SessionShortcutCatalog(shortcuts: [initialShortcut])
            )
            .summaries(for: fixture.session)
            .first
        )
        let refreshed = try #require(
            SessionTerminalSummaryBuilder(
                store: store,
                shortcutCatalog: SessionShortcutCatalog(shortcuts: [updatedShortcut])
            )
            .summaries(for: fixture.session)
            .first
        )

        #expect(initial.agentLabel == "Review Bot")
        #expect(refreshed.agentLabel == "Review Bot Fast")
        #expect(refreshed.title == "Review Bot Fast")
        #expect(refreshed.shortcutID == shortcutID)
        #expect(refreshed.iconShortcut == updatedShortcut)
    }

    @Test
    func exitSnapshotsOnlyAffectMatchingTerminalSummaries() throws {
        let fixture = SummaryFixture()
        let first = fixture.terminalTab(ordinal: 0, launchCommand: "codex")
        let second = fixture.terminalTab(ordinal: 1, launchCommand: "claude")
        let store = fixture.store(tabs: [first, second])
        let observedExit = TerminalExitObservation(tabID: second.id, exitStatus: 42)

        let summaries = SessionTerminalSummaryBuilder(
            store: store,
            exitSnapshot: { tabID in tabID == second.id ? observedExit : nil }
        )
        .summaries(for: fixture.session)

        #expect(summaries.count == 2)
        #expect(summaries[0].tabID == first.id)
        #expect(summaries[0].hasExitObservation == false)
        #expect(summaries[0].exitStatus == nil)
        #expect(summaries[1].tabID == second.id)
        #expect(summaries[1].exitObservation == observedExit)
        #expect(summaries[1].exitStatus == 42)
    }

    @Test
    func selectedFileTabLeavesTerminalSummariesNeutral() throws {
        let fixture = SummaryFixture()
        let terminal = fixture.terminalTab(ordinal: 0, launchCommand: "codex")
        let selectedFile = fixture.fileTab(ordinal: 1)
        let store = fixture.store(tabs: [terminal, selectedFile], selectedTabID: selectedFile.id)

        let summaries = SessionTerminalSummaryBuilder(store: store).summaries(for: fixture.session)

        #expect(summaries.map(\.tabID) == [terminal.id])
        #expect(summaries.allSatisfy { $0.isSelected == false })
    }

    @Test
    func summaryRenderConvenienceFieldsExposeStableFactualValues() throws {
        let fixture = SummaryFixture()
        let codex = try #require(SessionShortcut.builtInDefaults.first { $0.label == "Codex" })
        let terminal = fixture.terminalTab(shortcutID: codex.id, launchCommand: "codex")
        let plainTerminal = fixture.terminalTab(ordinal: 1)
        let store = fixture.store(tabs: [terminal, plainTerminal], selectedTabID: terminal.id)
        let catalog = SessionShortcutCatalog(shortcuts: [codex])

        let summaries = SessionTerminalSummaryBuilder(
            store: store,
            shortcutCatalog: catalog
        )
        .summaries(for: fixture.session)

        let selectedSummary = try #require(summaries.first)
        let plainSummary = try #require(summaries.last)

        #expect(selectedSummary.id == terminal.id)
        #expect(selectedSummary.isSelected)
        #expect(selectedSummary.iconShortcut == codex)
        #expect(plainSummary.fallbackSystemImage(isActive: false) == "terminal")
        #expect(plainSummary.fallbackSystemImage(isActive: true) == "terminal.fill")
        #expect(catalog.shortcut(id: codex.id) == codex)
        #expect(catalog.shortcut(id: nil) == nil)
    }
}

@MainActor
private struct SummaryFixture {
    let project: WorkspaceProject
    let session: WorkspaceSession

    init() {
        project = WorkspaceProject(
            id: UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!,
            path: "/tmp/native-mac-ade-summary",
            displayName: "Summary"
        )
        session = WorkspaceSession(
            id: UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!,
            projectID: project.id,
            title: "Summary Session"
        )
    }

    func store(tabs: [WorkspaceTab], selectedTabID: UUID? = nil) -> WorkspaceStore {
        WorkspaceStore(
            projects: [project],
            sessions: [session],
            tabs: tabs,
            selectedProjectID: project.id,
            selectedSessionID: session.id,
            selectedTabID: selectedTabID
        )
    }

    func terminalTab(
        id: UUID = UUID(),
        ordinal: Int = 0,
        title: String? = nil,
        shortcutID: UUID? = nil,
        launchCommand: String? = nil,
        lastActivatedAt: Date = Date(timeIntervalSince1970: 0)
    ) -> WorkspaceTab {
        WorkspaceTab(
            id: id,
            sessionID: session.id,
            kind: .terminal,
            workingDirectory: project.path,
            title: title,
            shortcutID: shortcutID,
            launchCommand: launchCommand,
            ordinal: ordinal,
            lastActivatedAt: lastActivatedAt
        )
    }

    func fileTab(id: UUID = UUID(), ordinal: Int = 0) -> WorkspaceTab {
        WorkspaceTab(
            id: id,
            sessionID: session.id,
            kind: .file,
            workingDirectory: project.path,
            title: nil,
            fileReference: WorkspaceFileReference(
                path: "\(project.path)/Sources/App.swift",
                projectRoot: project.path
            ),
            ordinal: ordinal
        )
    }
}
