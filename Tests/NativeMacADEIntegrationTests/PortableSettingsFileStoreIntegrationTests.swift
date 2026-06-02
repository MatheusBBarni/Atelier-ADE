import Foundation
import Testing
@testable import NativeMacADECore

struct PortableSettingsFileStoreIntegrationTests {
    @Test
    func tempXDGDirectoryRoundTripsThroughCanonicalPath() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let xdgConfigHome = root.appendingPathComponent("xdg", isDirectory: true)
        let store = makeStore(xdgConfigHome: xdgConfigHome)
        let config = sampleConfig(themeID: "nord", terminalFontSize: 15)

        try store.save(config)
        let loadResult = try store.load()

        #expect(store.canonicalURL.path == xdgConfigHome
            .appendingPathComponent("atelier", isDirectory: true)
            .appendingPathComponent("settings.json")
            .standardizedFileURL
            .path)
        #expect(loadResult.config == config)
    }

    @Test
    func repeatedSavesReplaceExistingDocumentWithoutStalePartialOutput() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = makeStore(xdgConfigHome: root.appendingPathComponent("xdg", isDirectory: true))
        let firstConfig = sampleConfig(themeID: "solarized-dark", terminalFontSize: 14)
        let replacementConfig = sampleConfig(themeID: "kanagawa", terminalFontSize: 18)

        try store.save(firstConfig)
        try store.save(replacementConfig)

        let document = try String(contentsOf: store.canonicalURL, encoding: .utf8)
        let siblingNames = try FileManager.default.contentsOfDirectory(
            at: store.canonicalURL.deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        ).map(\.lastPathComponent)

        #expect(try store.load().config == replacementConfig)
        #expect(document.contains("kanagawa"))
        #expect(document.contains("solarized-dark") == false)
        #expect(siblingNames == ["settings.json"])
    }

    @Test
    func writeFailureAtBlockedConfigLocationSurfacesWriteError() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let blockedXDGConfigHome = root.appendingPathComponent("blocked-xdg")
        try Data([0x00]).write(to: blockedXDGConfigHome)
        let store = makeStore(xdgConfigHome: blockedXDGConfigHome)

        var didCatchWriteFailure = false
        do {
            try store.save(sampleConfig(themeID: "dracula", terminalFontSize: 16))
        } catch let error as PortableSettingsFileStoreError {
            if case .writeFailed(let path, let reason) = error {
                didCatchWriteFailure = true
                #expect(path == store.canonicalURL.path)
                #expect(reason.isEmpty == false)
            }
        }

        #expect(didCatchWriteFailure)
        #expect(FileManager.default.fileExists(atPath: store.canonicalURL.path) == false)
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
        defaultProfile: .claude,
        keybindings: [
            PortableKeybindingOverride(commandID: AppCommandID.searchSessions.rawValue, keyEquivalent: "k", modifiers: [.command, .shift])
        ]
    )
}

private func makeTemporaryDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("native-mac-ade-portable-settings-integration-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
