import Foundation
import Testing
@testable import NativeMacADECore

@Suite(.serialized)
@MainActor
struct WorkspaceFileAccessTests {
    @Test
    func loadingTextFileInsideProjectReturnsUTF8Contents() async throws {
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/App.swift", contents: "let app = true\n")
        let access = LocalWorkspaceFileAccess()

        let reference = try await access.validatedFileReference(path: fileURL.path, projectRoot: projectPath)
        let text = try await access.loadTextFile(reference)

        #expect(reference.path == fileURL.standardizedFileURL.resolvingSymlinksInPath().path)
        #expect(reference.projectRoot == URL(fileURLWithPath: projectPath, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath().path)
        #expect(text == "let app = true\n")
    }

    @Test
    func pathsOutsideProjectRootAreRejectedForLoadAndSave() async throws {
        let projectPath = try makeTemporaryProjectDirectory()
        let outsidePath = try makeTemporaryProjectDirectory(named: "outside")
        let outsideFile = try makeTemporaryProjectFile(in: outsidePath, relativePath: "Secret.swift", contents: "let secret = true\n")
        let access = LocalWorkspaceFileAccess()
        let standardizedOutsideFile = outsideFile.standardizedFileURL.resolvingSymlinksInPath().path
        let standardizedProjectPath = URL(fileURLWithPath: projectPath, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath().path

        await #expect(throws: WorkspaceFileAccessError.filePathOutsideProject(
            filePath: standardizedOutsideFile,
            projectRoot: standardizedProjectPath
        )) {
            _ = try await access.validatedFileReference(path: outsideFile.path, projectRoot: projectPath)
        }

        await #expect(throws: WorkspaceFileAccessError.filePathOutsideProject(
            filePath: standardizedOutsideFile,
            projectRoot: standardizedProjectPath
        )) {
            try await access.saveTextFile(
                "changed\n",
                to: WorkspaceFileReference(path: outsideFile.path, projectRoot: projectPath)
            )
        }
    }

    @Test
    func unsupportedNonUTF8FileIsRejectedClearly() async throws {
        let projectPath = try makeTemporaryProjectDirectory()
        let fileURL = URL(fileURLWithPath: projectPath, isDirectory: true).appendingPathComponent("binary.dat")
        try Data([0xff, 0xfe, 0xfd]).write(to: fileURL)
        let access = LocalWorkspaceFileAccess()
        let reference = try await access.validatedFileReference(path: fileURL.path, projectRoot: projectPath)

        await #expect(throws: WorkspaceFileAccessError.unsupportedFile(reference.path)) {
            _ = try await access.loadTextFile(reference)
        }
    }

    @Test
    func enumeratingProjectFilesReturnsSortedProjectScopedNodes() async throws {
        let projectPath = try makeTemporaryProjectDirectory()
        let sourceFile = try makeTemporaryProjectFile(in: projectPath, relativePath: "Sources/App.swift", contents: "let app = true\n")
        let readmeFile = try makeTemporaryProjectFile(in: projectPath, relativePath: "README.md", contents: "# App\n")
        let access = LocalWorkspaceFileAccess()

        let nodes = try await access.enumerateProjectFiles(projectRoot: projectPath)

        #expect(nodes.map(\.reference.path).contains(sourceFile.standardizedFileURL.resolvingSymlinksInPath().path))
        #expect(nodes.map(\.reference.path).contains(readmeFile.standardizedFileURL.resolvingSymlinksInPath().path))
        #expect(nodes.map(\.reference.projectRoot).allSatisfy { $0 == URL(fileURLWithPath: projectPath, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath().path })
        #expect(nodes == nodes.sorted { $0.reference.path < $1.reference.path })
    }

    private func makeTemporaryProjectDirectory(named name: String = UUID().uuidString) throws -> String {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("native-mac-ade-file-access-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url.path
    }

    private func makeTemporaryProjectFile(in projectPath: String, relativePath: String, contents: String) throws -> URL {
        let fileURL = URL(fileURLWithPath: projectPath, isDirectory: true)
            .appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
