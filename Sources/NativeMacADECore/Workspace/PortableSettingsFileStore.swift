import Foundation

public struct PortableSettingsConfigLocator: Equatable, Sendable {
    public static let xdgConfigHomeEnvironmentKey = "XDG_CONFIG_HOME"
    public static let appDirectoryName = "atelier"
    public static let settingsFileName = "settings.json"

    public var environment: [String: String]
    public var homeDirectoryURL: URL

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.environment = environment
        self.homeDirectoryURL = homeDirectoryURL
    }

    public var settingsURL: URL {
        let baseURL: URL
        if let xdgConfigHome = environment[Self.xdgConfigHomeEnvironmentKey],
           !xdgConfigHome.isEmpty {
            baseURL = URL(fileURLWithPath: xdgConfigHome, isDirectory: true)
        } else {
            baseURL = homeDirectoryURL.appendingPathComponent(".config", isDirectory: true)
        }

        return baseURL
            .appendingPathComponent(Self.appDirectoryName, isDirectory: true)
            .appendingPathComponent(Self.settingsFileName, isDirectory: false)
            .standardizedFileURL
    }
}

public enum PortableSettingsFileLoadResult: Equatable, Sendable {
    case missingFile(URL)
    case loaded(config: PortableSettingsConfig, url: URL)

    public var fileMissing: Bool {
        switch self {
        case .missingFile:
            return true
        case .loaded:
            return false
        }
    }

    public var config: PortableSettingsConfig? {
        switch self {
        case .missingFile:
            return nil
        case .loaded(let config, _):
            return config
        }
    }
}

public enum PortableSettingsFileStoreError: Error, Equatable, Sendable {
    case readFailed(path: String, reason: String)
    case decodeFailed(path: String, reason: String)
    case encodeFailed(reason: String)
    case writeFailed(path: String, reason: String)
}

public struct PortableSettingsFileStore {
    public let canonicalURL: URL

    private let fileManager: FileManager

    public init(
        locator: PortableSettingsConfigLocator = PortableSettingsConfigLocator(),
        fileManager: FileManager = .default
    ) {
        self.init(canonicalURL: locator.settingsURL, fileManager: fileManager)
    }

    public init(canonicalURL: URL, fileManager: FileManager = .default) {
        self.canonicalURL = canonicalURL.standardizedFileURL
        self.fileManager = fileManager
    }

    public func load() throws -> PortableSettingsFileLoadResult {
        guard fileManager.fileExists(atPath: canonicalURL.path) else {
            return .missingFile(canonicalURL)
        }

        let data: Data
        do {
            data = try Data(contentsOf: canonicalURL)
        } catch {
            throw PortableSettingsFileStoreError.readFailed(
                path: canonicalURL.path,
                reason: String(describing: error)
            )
        }

        do {
            let config = try Self.decoder.decode(PortableSettingsConfig.self, from: data)
            return .loaded(config: config, url: canonicalURL)
        } catch {
            throw PortableSettingsFileStoreError.decodeFailed(
                path: canonicalURL.path,
                reason: String(describing: error)
            )
        }
    }

    @discardableResult
    public func save(_ config: PortableSettingsConfig) throws -> URL {
        let data: Data
        do {
            data = try Self.encoder.encode(config)
        } catch {
            throw PortableSettingsFileStoreError.encodeFailed(reason: String(describing: error))
        }

        do {
            try fileManager.createDirectory(
                at: canonicalURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            throw PortableSettingsFileStoreError.writeFailed(
                path: canonicalURL.path,
                reason: String(describing: error)
            )
        }

        let temporaryURL = temporaryWriteURL()
        var temporaryFileExists = false
        defer {
            if temporaryFileExists {
                try? fileManager.removeItem(at: temporaryURL)
            }
        }

        do {
            try data.write(to: temporaryURL)
            temporaryFileExists = true

            if fileManager.fileExists(atPath: canonicalURL.path) {
                _ = try fileManager.replaceItemAt(
                    canonicalURL,
                    withItemAt: temporaryURL,
                    backupItemName: nil,
                    options: []
                )
            } else {
                try fileManager.moveItem(at: temporaryURL, to: canonicalURL)
            }

            temporaryFileExists = false
            return canonicalURL
        } catch {
            throw PortableSettingsFileStoreError.writeFailed(
                path: canonicalURL.path,
                reason: String(describing: error)
            )
        }
    }

    private func temporaryWriteURL() -> URL {
        canonicalURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(canonicalURL.lastPathComponent).\(UUID().uuidString).tmp")
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        JSONDecoder()
    }
}
