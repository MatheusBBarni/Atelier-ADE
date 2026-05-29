import Foundation
import Testing
@testable import NativeMacADECore

@Suite(.serialized)
@MainActor
struct WorkspaceFileBufferControllerTests {
    @Test
    func editingMarksBufferDirtyAndSuccessfulSaveClearsDirtyState() async throws {
        let tab = makeFileTab(path: "/tmp/project/Sources/App.swift", projectRoot: "/tmp/project")
        let access = FakeWorkspaceFileAccess(loadText: "let value = 1\n")
        let controller = WorkspaceFileBufferController(fileAccess: access)

        try await controller.loadBuffer(for: tab)
        controller.updateBuffer(tabID: tab.id, text: "let value = 2\n")

        #expect(controller.isDirty(tabID: tab.id))
        #expect(controller.buffer(for: tab.id)?.savedText == "let value = 1\n")

        try await controller.saveBuffer(tabID: tab.id)

        #expect(controller.isDirty(tabID: tab.id) == false)
        #expect(controller.bufferText(for: tab.id) == "let value = 2\n")
        #expect(controller.buffer(for: tab.id)?.savedText == "let value = 2\n")
        #expect(access.savedTexts == ["let value = 2\n"])
    }

    @Test
    func failedSavePreservesUnsavedTextAndDirtyState() async throws {
        let tab = makeFileTab(path: "/tmp/project/Sources/App.swift", projectRoot: "/tmp/project")
        let access = FakeWorkspaceFileAccess(loadText: "saved\n")
        access.saveError = WorkspaceFileAccessError.unwritableFile(tab.fileReference?.path ?? "")
        let controller = WorkspaceFileBufferController(fileAccess: access)

        try await controller.loadBuffer(for: tab)
        controller.updateBuffer(tabID: tab.id, text: "unsaved\n")

        await #expect(throws: WorkspaceFileAccessError.unwritableFile(tab.fileReference?.path ?? "")) {
            try await controller.saveBuffer(tabID: tab.id)
        }

        #expect(controller.bufferText(for: tab.id) == "unsaved\n")
        #expect(controller.buffer(for: tab.id)?.savedText == "saved\n")
        #expect(controller.isDirty(tabID: tab.id))
    }

    @Test
    func successfulRevertReloadsDiskTextAndClearsDirtyState() async throws {
        let tab = makeFileTab(path: "/tmp/project/Sources/App.swift", projectRoot: "/tmp/project")
        let access = FakeWorkspaceFileAccess(loadText: "disk one\n")
        let controller = WorkspaceFileBufferController(fileAccess: access)

        try await controller.loadBuffer(for: tab)
        controller.updateBuffer(tabID: tab.id, text: "unsaved\n")
        controller.updateEditorPosition(tabID: tab.id, position: FileEditorPosition(cursorOffset: 7, selectionLength: 2, firstVisibleLine: 3))
        access.loadText = "disk two\n"

        try await controller.revertBuffer(for: tab)

        #expect(controller.bufferText(for: tab.id) == "disk two\n")
        #expect(controller.buffer(for: tab.id)?.savedText == "disk two\n")
        #expect(controller.buffer(for: tab.id)?.editorPosition == FileEditorPosition(cursorOffset: 7, selectionLength: 2, firstVisibleLine: 3))
        #expect(controller.isDirty(tabID: tab.id) == false)
    }

    @Test
    func failedRevertPreservesUnsavedTextAndDirtyState() async throws {
        let tab = makeFileTab(path: "/tmp/project/Sources/App.swift", projectRoot: "/tmp/project")
        let access = FakeWorkspaceFileAccess(loadText: "disk one\n")
        let controller = WorkspaceFileBufferController(fileAccess: access)

        try await controller.loadBuffer(for: tab)
        controller.updateBuffer(tabID: tab.id, text: "unsaved\n")
        access.loadError = WorkspaceFileAccessError.unreadableFile(tab.fileReference?.path ?? "")

        await #expect(throws: WorkspaceFileAccessError.unreadableFile(tab.fileReference?.path ?? "")) {
            try await controller.revertBuffer(for: tab)
        }

        #expect(controller.bufferText(for: tab.id) == "unsaved\n")
        #expect(controller.buffer(for: tab.id)?.savedText == "disk one\n")
        #expect(controller.isDirty(tabID: tab.id))
    }

    private func makeFileTab(path: String, projectRoot: String) -> WorkspaceTab {
        WorkspaceTab(
            sessionID: UUID(),
            kind: .file,
            workingDirectory: projectRoot,
            fileReference: WorkspaceFileReference(path: path, projectRoot: projectRoot),
            ordinal: 0
        )
    }
}

@MainActor
private final class FakeWorkspaceFileAccess: WorkspaceFileAccessing {
    var loadText: String
    var loadError: (any Error)?
    var saveError: (any Error)?
    private(set) var savedTexts: [String] = []

    init(loadText: String) {
        self.loadText = loadText
    }

    func validatedFileReference(path: String, projectRoot: String) async throws -> WorkspaceFileReference {
        WorkspaceFileReference(path: path, projectRoot: projectRoot)
    }

    func enumerateProjectFiles(projectRoot: String) async throws -> [WorkspaceFileNode] {
        []
    }

    func loadTextFile(_ reference: WorkspaceFileReference) async throws -> String {
        if let loadError { throw loadError }
        return loadText
    }

    func saveTextFile(_ text: String, to reference: WorkspaceFileReference) async throws {
        if let saveError { throw saveError }
        savedTexts.append(text)
    }
}
