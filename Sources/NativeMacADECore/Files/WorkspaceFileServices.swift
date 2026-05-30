import Foundation

#if canImport(AppKit)
import AppKit
#endif

public enum WorkspaceFileAccessError: Error, Equatable, Sendable {
    case invalidProjectRoot(String)
    case invalidFilePath(String)
    case filePathOutsideProject(filePath: String, projectRoot: String)
    case unreadableFile(String)
    case unwritableFile(String)
    case unsupportedFile(String)
    case enumerationFailed(projectRoot: String, reason: String)
    case writeFailed(path: String, reason: String)
}

public enum WorkspaceFileBufferError: Error, Equatable, Sendable {
    case invalidFileTab(UUID, String)
    case missingBuffer(UUID)
}

public enum ExternalEditorError: Error, Equatable, Sendable {
    case openFailed(String)
}

public struct WorkspaceFileNode: Equatable, Sendable {
    public var reference: WorkspaceFileReference
    public var isDirectory: Bool

    public init(reference: WorkspaceFileReference, isDirectory: Bool) {
        self.reference = reference
        self.isDirectory = isDirectory
    }
}

private enum LocalWorkspaceFileIO {
    static func enumerateProjectFiles(projectRoot root: String) throws -> [WorkspaceFileNode] {
        let rootURL = URL(fileURLWithPath: root, isDirectory: true)
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw WorkspaceFileAccessError.enumerationFailed(projectRoot: root, reason: "Unable to create directory enumerator")
        }

        var nodes: [WorkspaceFileNode] = []
        while let url = enumerator.nextObject() as? URL {
            let path = url.standardizedFileURL.resolvingSymlinksInPath().path
            do {
                try ensure(path, isContainedBy: root)
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
                let isDirectory = resourceValues.isDirectory == true
                guard isDirectory || resourceValues.isRegularFile == true else { continue }
                nodes.append(WorkspaceFileNode(
                    reference: WorkspaceFileReference(path: path, projectRoot: root),
                    isDirectory: isDirectory
                ))
            } catch let error as WorkspaceFileAccessError {
                throw error
            } catch {
                throw WorkspaceFileAccessError.enumerationFailed(projectRoot: root, reason: String(describing: error))
            }
        }

        return nodes.sorted {
            if $0.reference.path == $1.reference.path { return !$0.isDirectory && $1.isDirectory }
            return $0.reference.path < $1.reference.path
        }
    }

    static func loadTextFile(at path: String) throws -> String {
        let url = URL(fileURLWithPath: path)
        do {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard let text = String(data: data, encoding: .utf8) else {
                throw WorkspaceFileAccessError.unsupportedFile(path)
            }
            return text
        } catch let error as WorkspaceFileAccessError {
            throw error
        } catch {
            throw WorkspaceFileAccessError.unreadableFile(path)
        }
    }

    static func saveTextFile(_ text: String, to path: String) throws {
        do {
            try Data(text.utf8).write(to: URL(fileURLWithPath: path), options: [.atomic])
        } catch {
            throw WorkspaceFileAccessError.writeFailed(path: path, reason: String(describing: error))
        }
    }

    private static func ensure(_ path: String, isContainedBy projectRoot: String) throws {
        guard path != projectRoot else {
            throw WorkspaceFileAccessError.filePathOutsideProject(filePath: path, projectRoot: projectRoot)
        }
        let rootPrefix = projectRoot.hasSuffix("/") ? projectRoot : "\(projectRoot)/"
        guard path.hasPrefix(rootPrefix) else {
            throw WorkspaceFileAccessError.filePathOutsideProject(filePath: path, projectRoot: projectRoot)
        }
    }
}

@MainActor
public protocol WorkspaceFileAccessing: AnyObject {
    func validatedFileReference(path: String, projectRoot: String) async throws -> WorkspaceFileReference
    func enumerateProjectFiles(projectRoot: String) async throws -> [WorkspaceFileNode]
    func loadTextFile(_ reference: WorkspaceFileReference) async throws -> String
    func saveTextFile(_ text: String, to reference: WorkspaceFileReference) async throws
}

@MainActor
public protocol WorkspaceFileBufferManaging: AnyObject {
    func loadBuffer(for tab: WorkspaceTab) async throws
    func buffer(for tabID: UUID) -> FileEditorBuffer?
    func bufferText(for tabID: UUID) -> String?
    func updateBuffer(tabID: UUID, text: String)
    func updateEditorPosition(tabID: UUID, position: FileEditorPosition)
    func isDirty(tabID: UUID) -> Bool
    func saveBuffer(tabID: UUID) async throws
    func revertBuffer(for tab: WorkspaceTab) async throws
    func discardBuffer(tabID: UUID)
}

@MainActor
public protocol ExternalEditorOpening: AnyObject {
    func openFile(at path: String) async throws
}

public struct FileEditorPosition: Equatable, Sendable {
    public var cursorOffset: Int
    public var selectionLength: Int
    public var firstVisibleLine: Int

    public init(cursorOffset: Int = 0, selectionLength: Int = 0, firstVisibleLine: Int = 0) {
        self.cursorOffset = cursorOffset
        self.selectionLength = selectionLength
        self.firstVisibleLine = firstVisibleLine
    }
}

public struct FileEditorBuffer: Identifiable, Equatable, Sendable {
    public var id: UUID { tabID }
    public let tabID: UUID
    public var fileReference: WorkspaceFileReference
    public var text: String
    public var savedText: String
    public var languageConfigurationKey: String
    public var editorPosition: FileEditorPosition
    public var lastLoadedAt: Date

    public var isDirty: Bool { text != savedText }

    public init(
        tabID: UUID,
        fileReference: WorkspaceFileReference,
        text: String,
        savedText: String,
        languageConfigurationKey: String,
        editorPosition: FileEditorPosition = FileEditorPosition(),
        lastLoadedAt: Date
    ) {
        self.tabID = tabID
        self.fileReference = fileReference
        self.text = text
        self.savedText = savedText
        self.languageConfigurationKey = languageConfigurationKey
        self.editorPosition = editorPosition
        self.lastLoadedAt = lastLoadedAt
    }
}

@MainActor
public final class LocalWorkspaceFileAccess: WorkspaceFileAccessing {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func validatedFileReference(path: String, projectRoot: String) async throws -> WorkspaceFileReference {
        let root = try validatedProjectRoot(projectRoot)
        let filePath = try standardizedAbsolutePath(path)
        try ensure(filePath, isContainedBy: root)
        try validateReadableTextFile(at: filePath)
        return WorkspaceFileReference(path: filePath, projectRoot: root)
    }

    public func enumerateProjectFiles(projectRoot: String) async throws -> [WorkspaceFileNode] {
        let root = try validatedProjectRoot(projectRoot)
        return try await Task.detached(priority: .userInitiated) {
            try LocalWorkspaceFileIO.enumerateProjectFiles(projectRoot: root)
        }.value
    }

    public func loadTextFile(_ reference: WorkspaceFileReference) async throws -> String {
        let validatedReference = try await validatedFileReference(
            path: reference.path,
            projectRoot: reference.projectRoot
        )
        return try await Task.detached(priority: .userInitiated) {
            try LocalWorkspaceFileIO.loadTextFile(at: validatedReference.path)
        }.value
    }

    public func saveTextFile(_ text: String, to reference: WorkspaceFileReference) async throws {
        let validatedReference = try await validatedFileReference(
            path: reference.path,
            projectRoot: reference.projectRoot
        )
        guard fileManager.isWritableFile(atPath: validatedReference.path) else {
            throw WorkspaceFileAccessError.unwritableFile(validatedReference.path)
        }

        try await Task.detached(priority: .userInitiated) {
            try LocalWorkspaceFileIO.saveTextFile(text, to: validatedReference.path)
        }.value
    }

    private func validatedProjectRoot(_ projectRoot: String) throws -> String {
        let root = try standardizedAbsolutePath(projectRoot, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw WorkspaceFileAccessError.invalidProjectRoot(projectRoot)
        }
        return root
    }

    private func standardizedAbsolutePath(_ path: String, isDirectory: Bool = false) throws -> String {
        guard (path as NSString).isAbsolutePath else {
            throw WorkspaceFileAccessError.invalidFilePath(path)
        }
        return URL(fileURLWithPath: path, isDirectory: isDirectory)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    private func validateReadableTextFile(at path: String) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              !isDirectory.boolValue,
              fileManager.isReadableFile(atPath: path)
        else {
            throw WorkspaceFileAccessError.unreadableFile(path)
        }
    }

    private func ensure(_ path: String, isContainedBy projectRoot: String) throws {
        guard path != projectRoot else {
            throw WorkspaceFileAccessError.filePathOutsideProject(filePath: path, projectRoot: projectRoot)
        }
        let rootPrefix = projectRoot.hasSuffix("/") ? projectRoot : "\(projectRoot)/"
        guard path.hasPrefix(rootPrefix) else {
            throw WorkspaceFileAccessError.filePathOutsideProject(filePath: path, projectRoot: projectRoot)
        }
    }
}

@MainActor
public final class WorkspaceFileBufferController: WorkspaceFileBufferManaging {
    private let fileAccess: any WorkspaceFileAccessing
    private let now: @MainActor () -> Date
    private var buffersByTabID: [UUID: FileEditorBuffer] = [:]

    public init(
        fileAccess: any WorkspaceFileAccessing,
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        self.fileAccess = fileAccess
        self.now = now
    }

    public func loadBuffer(for tab: WorkspaceTab) async throws {
        guard buffersByTabID[tab.id] == nil else { return }
        let fileReference = try requireFileReference(for: tab)
        let text = try await fileAccess.loadTextFile(fileReference)
        buffersByTabID[tab.id] = FileEditorBuffer(
            tabID: tab.id,
            fileReference: fileReference,
            text: text,
            savedText: text,
            languageConfigurationKey: Self.languageConfigurationKey(forPath: fileReference.path),
            lastLoadedAt: now()
        )
    }

    public func buffer(for tabID: UUID) -> FileEditorBuffer? {
        buffersByTabID[tabID]
    }

    public func bufferText(for tabID: UUID) -> String? {
        buffersByTabID[tabID]?.text
    }

    public func updateBuffer(tabID: UUID, text: String) {
        guard var buffer = buffersByTabID[tabID] else { return }
        buffer.text = text
        buffersByTabID[tabID] = buffer
    }

    public func updateEditorPosition(tabID: UUID, position: FileEditorPosition) {
        guard var buffer = buffersByTabID[tabID] else { return }
        buffer.editorPosition = position
        buffersByTabID[tabID] = buffer
    }

    public func isDirty(tabID: UUID) -> Bool {
        buffersByTabID[tabID]?.isDirty == true
    }

    public func saveBuffer(tabID: UUID) async throws {
        guard var buffer = buffersByTabID[tabID] else {
            throw WorkspaceFileBufferError.missingBuffer(tabID)
        }
        try await fileAccess.saveTextFile(buffer.text, to: buffer.fileReference)
        buffer.savedText = buffer.text
        buffersByTabID[tabID] = buffer
    }

    public func revertBuffer(for tab: WorkspaceTab) async throws {
        let fileReference = try requireFileReference(for: tab)
        let text = try await fileAccess.loadTextFile(fileReference)
        let existingPosition = buffersByTabID[tab.id]?.editorPosition ?? FileEditorPosition()
        buffersByTabID[tab.id] = FileEditorBuffer(
            tabID: tab.id,
            fileReference: fileReference,
            text: text,
            savedText: text,
            languageConfigurationKey: Self.languageConfigurationKey(forPath: fileReference.path),
            editorPosition: existingPosition,
            lastLoadedAt: now()
        )
    }

    public func discardBuffer(tabID: UUID) {
        buffersByTabID[tabID] = nil
    }

    private func requireFileReference(for tab: WorkspaceTab) throws -> WorkspaceFileReference {
        guard tab.kind == .file else {
            throw WorkspaceFileBufferError.invalidFileTab(tab.id, "Terminal tabs do not have file buffers")
        }
        guard let fileReference = tab.fileReference else {
            throw WorkspaceFileBufferError.invalidFileTab(tab.id, "File tab is missing file metadata")
        }
        return fileReference
    }

    nonisolated public static func languageConfigurationKey(forPath path: String) -> String {
        switch URL(fileURLWithPath: path).pathExtension.lowercased() {
        case "swift":
            return "swift"
        case "sql", "sqlite":
            return "sqlite"
        case "hs", "lhs":
            return "haskell"
        case "agda":
            return "agda"
        case "cabal":
            return "cabal"
        case "cypher", "cql":
            return "cypher"
        case "js", "jsx", "mjs", "cjs":
            return "javascript"
        case "ts", "tsx":
            return "typescript"
        case "json":
            return "json"
        case "md", "markdown":
            return "markdown"
        case "py":
            return "python"
        case "rb":
            return "ruby"
        case "rs":
            return "rust"
        case "go":
            return "go"
        case "java":
            return "java"
        case "c", "h":
            return "c"
        case "cc", "cpp", "cxx", "hpp", "hh":
            return "cpp"
        case "html", "htm":
            return "html"
        case "css":
            return "css"
        case "yml", "yaml":
            return "yaml"
        case "sh", "bash", "zsh":
            return "shell"
        default:
            return "plaintext"
        }
    }
}

@MainActor
public final class SystemExternalEditorOpener: ExternalEditorOpening {
    public init() {}

    public func openFile(at path: String) async throws {
        #if canImport(AppKit)
        let opened = NSWorkspace.shared.open(URL(fileURLWithPath: path))
        guard opened else {
            throw ExternalEditorError.openFailed(path)
        }
        #else
        throw ExternalEditorError.openFailed(path)
        #endif
    }
}
