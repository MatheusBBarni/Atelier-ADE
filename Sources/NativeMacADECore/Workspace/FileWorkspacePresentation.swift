import Foundation

public struct FileWorkspaceWorkingSetEntry: Identifiable, Equatable, Sendable {
    public var id: UUID { tabID }
    public let tabID: UUID
    public let path: String
    public let title: String
    public let subtitle: String
    public let isSelected: Bool
    public let isDirty: Bool
    public let lastActivatedAt: Date

    public init(
        tabID: UUID,
        path: String,
        title: String,
        subtitle: String,
        isSelected: Bool,
        isDirty: Bool,
        lastActivatedAt: Date
    ) {
        self.tabID = tabID
        self.path = path
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.isDirty = isDirty
        self.lastActivatedAt = lastActivatedAt
    }
}

public struct FileWorkspaceTreeEntry: Identifiable, Equatable, Sendable {
    public var id: String { path }
    public let reference: WorkspaceFileReference
    public let name: String
    public let relativePath: String
    public let depth: Int
    public let isDirectory: Bool
    public let isExpanded: Bool
    public let hasChildren: Bool

    public var path: String {
        reference.path
    }

    public init(
        reference: WorkspaceFileReference,
        name: String,
        relativePath: String,
        depth: Int,
        isDirectory: Bool,
        isExpanded: Bool,
        hasChildren: Bool
    ) {
        self.reference = reference
        self.name = name
        self.relativePath = relativePath
        self.depth = depth
        self.isDirectory = isDirectory
        self.isExpanded = isExpanded
        self.hasChildren = hasChildren
    }
}

public struct FileEditorPresentation: Equatable, Sendable {
    public let tabID: UUID
    public let path: String
    public let title: String
    public let subtitle: String
    public let languageConfigurationKey: String
    public let isDirty: Bool

    public init?(tab: WorkspaceTab, buffer: FileEditorBuffer?) {
        guard tab.kind == .file,
              let fileReference = tab.fileReference
        else {
            return nil
        }

        self.tabID = tab.id
        self.path = fileReference.path
        self.title = Self.fileName(for: fileReference.path)
        self.subtitle = Self.relativePath(for: fileReference.path, projectRoot: fileReference.projectRoot)
        self.languageConfigurationKey = buffer?.languageConfigurationKey ?? WorkspaceFileBufferController.languageConfigurationKey(forPath: fileReference.path)
        self.isDirty = buffer?.isDirty == true
    }

    public static func fileName(for path: String) -> String {
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        return fileName.isEmpty ? path : fileName
    }

    public static func relativePath(for path: String, projectRoot: String) -> String {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        let standardizedRoot = URL(fileURLWithPath: projectRoot, isDirectory: true).standardizedFileURL.path
        let rootPrefix = standardizedRoot.hasSuffix("/") ? standardizedRoot : "\(standardizedRoot)/"
        guard standardizedPath.hasPrefix(rootPrefix) else { return standardizedPath }
        return String(standardizedPath.dropFirst(rootPrefix.count))
    }
}

public enum WorkspaceFileTreeBuilder {
    public static func visibleEntries(
        projectRoot: String,
        nodes: [WorkspaceFileNode],
        expandedDirectoryPaths: Set<String>
    ) -> [FileWorkspaceTreeEntry] {
        let root = URL(fileURLWithPath: projectRoot, isDirectory: true).standardizedFileURL.path
        let rootPrefix = root.hasSuffix("/") ? root : "\(root)/"

        let childrenByParent = nodes.reduce(into: [String: [WorkspaceFileNode]]()) { result, node in
            guard node.reference.path.hasPrefix(rootPrefix) else { return }
            let parent = URL(fileURLWithPath: node.reference.path).deletingLastPathComponent().standardizedFileURL.path
            result[parent, default: []].append(node)
        }

        let sortedChildrenByParent = childrenByParent.mapValues { children in
            children.sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory && !rhs.isDirectory
                }
                return lhs.reference.path.localizedStandardCompare(rhs.reference.path) == .orderedAscending
            }
        }

        func sortedChildren(of parent: String) -> [WorkspaceFileNode] {
            sortedChildrenByParent[parent, default: []]
        }

        func appendChildren(of parent: String, depth: Int, into entries: inout [FileWorkspaceTreeEntry]) {
            for child in sortedChildren(of: parent) {
                let childChildren = sortedChildren(of: child.reference.path)
                let isExpanded = expandedDirectoryPaths.contains(child.reference.path)
                entries.append(FileWorkspaceTreeEntry(
                    reference: child.reference,
                    name: FileEditorPresentation.fileName(for: child.reference.path),
                    relativePath: FileEditorPresentation.relativePath(for: child.reference.path, projectRoot: child.reference.projectRoot),
                    depth: depth,
                    isDirectory: child.isDirectory,
                    isExpanded: isExpanded,
                    hasChildren: child.isDirectory && !childChildren.isEmpty
                ))
                if child.isDirectory, isExpanded {
                    appendChildren(of: child.reference.path, depth: depth + 1, into: &entries)
                }
            }
        }

        var entries: [FileWorkspaceTreeEntry] = []
        appendChildren(of: root, depth: 0, into: &entries)
        return entries
    }
}

public extension WorkspaceStore {
    func fileWorkingSetEntries(
        in sessionID: UUID,
        dirtyTabIDs: Set<UUID> = []
    ) -> [FileWorkspaceWorkingSetEntry] {
        fileTabs(in: sessionID)
            .filter { $0.fileReference != nil }
            .sorted { lhs, rhs in
                if lhs.lastActivatedAt != rhs.lastActivatedAt {
                    return lhs.lastActivatedAt > rhs.lastActivatedAt
                }
                if lhs.ordinal != rhs.ordinal {
                    return lhs.ordinal < rhs.ordinal
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .compactMap { tab in
                guard let fileReference = tab.fileReference else { return nil }
                return FileWorkspaceWorkingSetEntry(
                    tabID: tab.id,
                    path: fileReference.path,
                    title: FileEditorPresentation.fileName(for: fileReference.path),
                    subtitle: FileEditorPresentation.relativePath(for: fileReference.path, projectRoot: fileReference.projectRoot),
                    isSelected: tab.id == selectedTabID,
                    isDirty: dirtyTabIDs.contains(tab.id),
                    lastActivatedAt: tab.lastActivatedAt
                )
            }
    }

    func selectedSessionFileWorkingSetEntries(dirtyTabIDs: Set<UUID> = []) -> [FileWorkspaceWorkingSetEntry] {
        guard let selectedSessionID else { return [] }
        return fileWorkingSetEntries(in: selectedSessionID, dirtyTabIDs: dirtyTabIDs)
    }
}
