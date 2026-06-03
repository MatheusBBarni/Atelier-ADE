import Foundation
import Testing
@testable import NativeMacADE
import NativeMacADECore

@Suite(.serialized)
@MainActor
struct SessionTerminalSummaryIntegrationTests {
    @Test
    func savingCustomProfileAndRefreshingCatalogUpdatesSummaryIdentity() async throws {
        let harness = try SummaryIntegrationHarness()
        let project = try await harness.service.openProject(path: harness.makeProjectDirectory())
        let profile = try await harness.service.saveSessionShortcut(SessionShortcut(
            label: "Review Bot",
            launchCommand: "codex",
            launchArgumentsJSON: "[\"--review\"]"
        ))
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: profile.id)

        let initialSummary = try #require(
            SessionTerminalSummaryBuilder(
                store: harness.store,
                shortcutCatalog: try await harness.shortcutCatalog()
            )
            .summaries(for: session)
            .first
        )

        var editedProfile = profile
        editedProfile.label = "Review Bot Fast"
        editedProfile.launchArgumentsJSON = "[\"--fast\"]"
        _ = try await harness.service.saveSessionShortcut(editedProfile)

        let refreshedSummary = try #require(
            SessionTerminalSummaryBuilder(
                store: harness.store,
                shortcutCatalog: try await harness.shortcutCatalog()
            )
            .summaries(for: session)
            .first
        )

        #expect(initialSummary.agentLabel == "Review Bot")
        #expect(refreshedSummary.agentLabel == "Review Bot Fast")
        #expect(refreshedSummary.shortcutID == profile.id)
        #expect(refreshedSummary.iconShortcut?.label == "Review Bot Fast")
    }

    @Test
    func resetAndDeleteProfileRefreshesKeepSummariesStableWithoutRestart() async throws {
        let harness = try SummaryIntegrationHarness()
        let project = try await harness.service.openProject(path: harness.makeProjectDirectory())
        let codex = try #require((try await harness.service.availableSessionShortcuts()).first { $0.label == "Codex" })
        var customizedCodex = codex
        customizedCodex.label = "Codex Local"
        customizedCodex.hasUserOverride = true
        _ = try await harness.service.saveSessionShortcut(customizedCodex)

        let builtInSession = try await harness.service.createSession(projectID: project.id, shortcutID: codex.id)
        let customizedSummary = try #require(
            SessionTerminalSummaryBuilder(
                store: harness.store,
                shortcutCatalog: try await harness.shortcutCatalog()
            )
            .summaries(for: builtInSession)
            .first
        )

        _ = try await harness.service.resetBuiltInSessionShortcut(id: codex.id)
        let resetSummary = try #require(
            SessionTerminalSummaryBuilder(
                store: harness.store,
                shortcutCatalog: try await harness.shortcutCatalog()
            )
            .summaries(for: builtInSession)
            .first
        )

        let customProfile = try await harness.service.saveSessionShortcut(SessionShortcut(
            label: "Temporary Reviewer",
            launchCommand: "codex",
            launchArgumentsJSON: "[]"
        ))
        let customSession = try await harness.service.createSession(projectID: project.id, shortcutID: customProfile.id)
        let customSummary = try #require(
            SessionTerminalSummaryBuilder(
                store: harness.store,
                shortcutCatalog: try await harness.shortcutCatalog()
            )
            .summaries(for: customSession)
            .first
        )

        try await harness.service.deleteSessionShortcut(id: customProfile.id)
        let afterDeleteSummary = try #require(
            SessionTerminalSummaryBuilder(
                store: harness.store,
                shortcutCatalog: try await harness.shortcutCatalog()
            )
            .summaries(for: customSession)
            .first
        )

        #expect(customizedSummary.agentLabel == "Codex Local")
        #expect(resetSummary.agentLabel == "Codex")
        #expect(resetSummary.shortcutID == codex.id)
        #expect(customSummary.agentLabel == "Temporary Reviewer")
        #expect(afterDeleteSummary.agentLabel == "Codex")
        #expect(afterDeleteSummary.shortcutID == nil)
    }

    @Test
    func summariesRemainStableForPlainDefaultAndExplicitAgentTabFlows() async throws {
        let harness = try SummaryIntegrationHarness()
        let project = try await harness.service.openProject(path: harness.makeProjectDirectory())
        let shortcuts = try await harness.service.availableSessionShortcuts()
        let codex = try #require(shortcuts.first { $0.label == "Codex" })
        let claude = try #require(shortcuts.first { $0.label == "Claude" })
        let session = try await harness.service.createSession(projectID: project.id, shortcutID: nil)

        var preferences = try await harness.service.loadAppPreferences()
        preferences.defaultSessionShortcutID = codex.id
        try await harness.service.saveAppPreferences(preferences)

        _ = try await harness.service.createDefaultAgentTab(sessionID: session.id)
        _ = try await harness.service.createAgentTab(sessionID: session.id, shortcutID: claude.id)

        let summaries = SessionTerminalSummaryBuilder(
            store: harness.store,
            shortcutCatalog: try await harness.shortcutCatalog()
        )
        .summaries(for: session)

        #expect(summaries.map(\.agentLabel) == ["Terminal", "Codex", "Claude"])
        #expect(summaries.map(\.shortcutID) == [nil, codex.id, claude.id])
        #expect(summaries.map(\.tabID) == harness.store.terminalTabs(in: session.id).map(\.id))
    }
}

@MainActor
private struct SummaryIntegrationHarness {
    let store: WorkspaceStore
    let persistence: SQLiteWorkspaceMetadataStore
    let terminal: SummaryFakeTerminalSurfaceManager
    let service: DefaultWorkspaceCommandService

    init() throws {
        store = WorkspaceStore()
        persistence = try SQLiteWorkspaceMetadataStore(path: Self.temporaryDatabasePath())
        terminal = SummaryFakeTerminalSurfaceManager()
        let fileAccess = LocalWorkspaceFileAccess()
        let fileBuffers = WorkspaceFileBufferController(fileAccess: fileAccess)
        service = DefaultWorkspaceCommandService(
            store: store,
            persistenceStore: persistence,
            portableSettingsFileStore: Self.temporaryPortableSettingsFileStore(),
            restoreCoordinator: RestoreCoordinator(persistenceStore: persistence),
            terminalSurfaceManager: terminal,
            fileAccess: fileAccess,
            fileBufferManager: fileBuffers,
            externalEditorOpener: SummaryFakeExternalEditorOpener()
        )
    }

    func shortcutCatalog() async throws -> SessionShortcutCatalog {
        SessionShortcutCatalog(shortcuts: try await service.availableSessionShortcuts())
    }

    func makeProjectDirectory() throws -> String {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("native-mac-ade-summary-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url.path
    }

    private static func temporaryDatabasePath() -> String {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("native-mac-ade-summary-\(UUID().uuidString).sqlite")
            .path
    }

    private static func temporaryPortableSettingsFileStore() -> PortableSettingsFileStore {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("native-mac-ade-summary-portable-settings-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("settings.json")
        return PortableSettingsFileStore(canonicalURL: url)
    }
}

@MainActor
private final class SummaryFakeTerminalSurfaceManager: WorkspaceTerminalSurfaceManaging {
    private var surfacesByTabID: [UUID: GhosttySurfaceHandle] = [:]

    func createSurface(for tab: WorkspaceTab) async throws -> GhosttySurfaceHandle {
        let surface = GhosttySurfaceHandle()
        surfacesByTabID[tab.id] = surface
        return surface
    }

    func surface(for tabID: UUID) -> GhosttySurfaceHandle? {
        surfacesByTabID[tabID]
    }

    func canClose(surface: GhosttySurfaceHandle) async -> Bool {
        true
    }

    func focus(tabID: UUID) {}

    func resize(tabID: UUID, columns: Int, rows: Int) {}

    func hasExited(tabID: UUID) async -> Bool {
        false
    }

    func releaseSurface(for tabID: UUID) {
        surfacesByTabID[tabID] = nil
    }
}

@MainActor
private final class SummaryFakeExternalEditorOpener: ExternalEditorOpening {
    func openFile(at path: String) async throws {}
}
