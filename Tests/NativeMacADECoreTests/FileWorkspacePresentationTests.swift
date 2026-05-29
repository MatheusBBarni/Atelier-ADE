import Foundation
import Testing
@testable import NativeMacADECore

@MainActor
struct FileWorkspacePresentationTests {
    @Test
    func workingSetEntriesSortByActivationAndIncludeSelectionAndDirtyState() {
        let projectID = UUID()
        let sessionID = UUID()
        let olderFileTabID = UUID()
        let newerFileTabID = UUID()
        let terminalTabID = UUID()
        let projectRoot = "/tmp/project"
        let store = WorkspaceStore(
            projects: [
                WorkspaceProject(id: projectID, path: projectRoot, displayName: "project")
            ],
            sessions: [
                WorkspaceSession(id: sessionID, projectID: projectID, title: "Session")
            ],
            tabs: [
                WorkspaceTab(id: terminalTabID, sessionID: sessionID, workingDirectory: projectRoot, ordinal: 0),
                WorkspaceTab(
                    id: olderFileTabID,
                    sessionID: sessionID,
                    kind: .file,
                    workingDirectory: projectRoot,
                    fileReference: WorkspaceFileReference(path: "\(projectRoot)/Sources/Older.swift", projectRoot: projectRoot),
                    ordinal: 1,
                    lastActivatedAt: Date(timeIntervalSince1970: 100)
                ),
                WorkspaceTab(
                    id: newerFileTabID,
                    sessionID: sessionID,
                    kind: .file,
                    workingDirectory: projectRoot,
                    fileReference: WorkspaceFileReference(path: "\(projectRoot)/README.md", projectRoot: projectRoot),
                    ordinal: 2,
                    lastActivatedAt: Date(timeIntervalSince1970: 300)
                )
            ],
            selectedProjectID: projectID,
            selectedSessionID: sessionID,
            selectedTabID: olderFileTabID
        )

        let entries = store.selectedSessionFileWorkingSetEntries(dirtyTabIDs: [olderFileTabID])

        #expect(entries.map(\.tabID) == [newerFileTabID, olderFileTabID])
        #expect(entries.map(\.title) == ["README.md", "Older.swift"])
        #expect(entries.map(\.subtitle) == ["README.md", "Sources/Older.swift"])
        #expect(entries.map(\.isSelected) == [false, true])
        #expect(entries.map(\.isDirty) == [false, true])
    }

    @Test
    func treeBuilderShowsExpandedDirectoriesAndHidesCollapsedChildren() {
        let projectRoot = "/tmp/project"
        let sources = WorkspaceFileNode(
            reference: WorkspaceFileReference(path: "\(projectRoot)/Sources", projectRoot: projectRoot),
            isDirectory: true
        )
        let nested = WorkspaceFileNode(
            reference: WorkspaceFileReference(path: "\(projectRoot)/Sources/App.swift", projectRoot: projectRoot),
            isDirectory: false
        )
        let readme = WorkspaceFileNode(
            reference: WorkspaceFileReference(path: "\(projectRoot)/README.md", projectRoot: projectRoot),
            isDirectory: false
        )

        let collapsed = WorkspaceFileTreeBuilder.visibleEntries(
            projectRoot: projectRoot,
            nodes: [nested, readme, sources],
            expandedDirectoryPaths: []
        )
        let expanded = WorkspaceFileTreeBuilder.visibleEntries(
            projectRoot: projectRoot,
            nodes: [nested, readme, sources],
            expandedDirectoryPaths: [sources.reference.path]
        )

        #expect(collapsed.map(\.relativePath) == ["Sources", "README.md"])
        #expect(collapsed.first?.hasChildren == true)
        #expect(expanded.map(\.relativePath) == ["Sources", "Sources/App.swift", "README.md"])
        #expect(expanded.map(\.depth) == [0, 1, 0])
    }

    @Test
    func editorPresentationUsesFileMetadataBufferLanguageAndDirtyState() {
        let tabID = UUID()
        let projectRoot = "/tmp/project"
        let reference = WorkspaceFileReference(path: "\(projectRoot)/Sources/App.swift", projectRoot: projectRoot)
        let tab = WorkspaceTab(
            id: tabID,
            sessionID: UUID(),
            kind: .file,
            workingDirectory: projectRoot,
            fileReference: reference,
            ordinal: 0
        )
        let buffer = FileEditorBuffer(
            tabID: tabID,
            fileReference: reference,
            text: "let changed = true\n",
            savedText: "let saved = true\n",
            languageConfigurationKey: "swift",
            lastLoadedAt: Date(timeIntervalSince1970: 10)
        )

        let presentation = FileEditorPresentation(tab: tab, buffer: buffer)
        let terminalPresentation = FileEditorPresentation(
            tab: WorkspaceTab(sessionID: UUID(), workingDirectory: projectRoot, ordinal: 0),
            buffer: nil
        )

        #expect(presentation?.title == "App.swift")
        #expect(presentation?.subtitle == "Sources/App.swift")
        #expect(presentation?.languageConfigurationKey == "swift")
        #expect(presentation?.isDirty == true)
        #expect(terminalPresentation == nil)
    }
}
