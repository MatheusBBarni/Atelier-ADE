import Foundation
import Testing
@testable import NativeMacADECore

struct PortableSettingsFileStoreTests {
    @Test
    func xdgConfigHomeResolvesAtelierSettingsJSONUnderEnvironmentDirectory() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let xdgConfigHome = root.appendingPathComponent("xdg", isDirectory: true)
        let home = root.appendingPathComponent("home", isDirectory: true)
        let locator = PortableSettingsConfigLocator(
            environment: [PortableSettingsConfigLocator.xdgConfigHomeEnvironmentKey: xdgConfigHome.path],
            homeDirectoryURL: home
        )

        #expect(locator.settingsURL.path == xdgConfigHome
            .appendingPathComponent("atelier", isDirectory: true)
            .appendingPathComponent("settings.json")
            .standardizedFileURL
            .path)
    }

    @Test
    func missingXDGConfigHomeFallsBackToHomeConfigAtelierSettingsJSON() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let home = root.appendingPathComponent("home", isDirectory: true)
        let locator = PortableSettingsConfigLocator(
            environment: [:],
            homeDirectoryURL: home
        )

        #expect(locator.settingsURL.path == home
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("atelier", isDirectory: true)
            .appendingPathComponent("settings.json")
            .standardizedFileURL
            .path)
    }

    @Test
    func savingValidConfigCreatesParentsAndWritesReadableJSON() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = makeStore(xdgConfigHome: root.appendingPathComponent("xdg", isDirectory: true))
        let config = sampleConfig(themeID: "dracula", terminalFontSize: 16)

        #expect(FileManager.default.fileExists(atPath: store.canonicalURL.deletingLastPathComponent().path) == false)

        try store.save(config)

        #expect(FileManager.default.fileExists(atPath: store.canonicalURL.deletingLastPathComponent().path))
        #expect(try store.load().config == config)
        #expect(try JSONDecoder().decode(
            PortableSettingsConfig.self,
            from: Data(contentsOf: store.canonicalURL)
        ) == config)
    }

    @Test
    func loadingMissingFileReturnsMissingFileResult() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = makeStore(xdgConfigHome: root.appendingPathComponent("xdg", isDirectory: true))

        let result = try store.load()

        #expect(result == .missingFile(store.canonicalURL))
        #expect(result.fileMissing)
        #expect(result.config == nil)
    }

    @Test
    func invalidJSONThrowsDecodeFailureDistinctFromMissingFile() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = makeStore(xdgConfigHome: root.appendingPathComponent("xdg", isDirectory: true))
        try FileManager.default.createDirectory(
            at: store.canonicalURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "{ invalid json".write(to: store.canonicalURL, atomically: true, encoding: .utf8)

        var didCatchDecodeFailure = false
        do {
            _ = try store.load()
        } catch let error as PortableSettingsFileStoreError {
            if case .decodeFailed(let path, let reason) = error {
                didCatchDecodeFailure = true
                #expect(path == store.canonicalURL.path)
                #expect(reason.isEmpty == false)
            }
        }

        #expect(didCatchDecodeFailure)
    }
}

private func makeStore(xdgConfigHome: URL) -> PortableSettingsFileStore {
    PortableSettingsFileStore(locator: PortableSettingsConfigLocator(
        environment: [PortableSettingsConfigLocator.xdgConfigHomeEnvironmentKey: xdgConfigHome.path],
        homeDirectoryURL: xdgConfigHome.deletingLastPathComponent().appendingPathComponent("home", isDirectory: true)
    ))
}

private func sampleConfig(themeID: String, terminalFontSize: Double) -> PortableSettingsConfig {
    PortableSettingsConfig(
        appearance: PortableAppearanceConfig(themeID: themeID, terminalFontSize: terminalFontSize),
        behavior: PortableBehaviorConfig(focusWorkspaceEnabled: true),
        defaultProfile: .codex,
        keybindings: [
            PortableKeybindingOverride(commandID: AppCommandID.openSettings.rawValue, keyEquivalent: ",")
        ]
    )
}

private func makeTemporaryDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("native-mac-ade-portable-settings-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
