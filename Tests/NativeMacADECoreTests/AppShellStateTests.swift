import Foundation
import Testing
@testable import NativeMacADECore

@MainActor
struct AppShellStateTests {
    @Test
    func settingsCommandAndVisibleEntryPointUseTheSameModalState() {
        let shellState = AppShellState()

        shellState.presentSettings(source: .appCommand)

        #expect(shellState.isSettingsPresented)
        #expect(shellState.settingsPresentationSource == .appCommand)

        shellState.dismissSettings()
        shellState.presentSettings(source: .visibleEntryPoint)

        #expect(shellState.isSettingsPresented)
        #expect(shellState.settingsPresentationSource == .visibleEntryPoint)
    }

    @Test
    func startupCoordinatorDoesNotRestoreBeforePreferenceLoadCompletes() async throws {
        let store = WorkspaceStore()
        let service = DelayedStartupService()
        let startupTask = Task { @MainActor in
            _ = await AppShellStartupCoordinator.run(commandService: service, store: store) {
                service.events.append("after-preferences")
            }
        }

        try await service.waitUntilLoadIsBlocked()

        #expect(service.events == ["load-start"])

        service.resumePreferenceLoad()
        _ = await startupTask.value

        #expect(service.events == ["load-start", "load-end", "after-preferences", "restore"])
    }

    @Test
    func startupCoordinatorFallsBackToDefaultPreferencesBeforeRestore() async {
        let store = WorkspaceStore(appPreferences: AppPreferences(themeID: "dracula"))
        let service = FailingPreferencesStartupService()

        let result = await AppShellStartupCoordinator.run(commandService: service, store: store) {
            service.events.append("after-preferences")
        }

        #expect(store.appPreferences == .defaults)
        #expect(result.preferenceLoadErrorDescription?.contains("preferenceUnavailable") == true)
        #expect(result.restoreErrorDescription == nil)
        #expect(service.events == ["load", "after-preferences", "restore"])
    }
}

@MainActor
private final class DelayedStartupService: AppShellStartupServicing {
    var events: [String] = []
    private var loadContinuation: CheckedContinuation<Void, Never>?

    func loadAppPreferences() async throws -> AppPreferences {
        events.append("load-start")
        await withCheckedContinuation { continuation in
            loadContinuation = continuation
        }
        events.append("load-end")
        return AppPreferences(themeID: "catppuccin")
    }

    func restoreWorkspace() async throws -> RestoreWorkspaceResult {
        events.append("restore")
        return RestoreWorkspaceResult(store: WorkspaceStore())
    }

    func pilotDiagnostics() -> PilotDiagnostics {
        PilotDiagnostics(
            restoreFailureRate: 0,
            terminalSurfaceFailureRate: 0,
            fileSaveFailureRate: 0,
            medianLaunchToReadySeconds: nil,
            medianFileOpenSeconds: nil,
            fileRestoreFailureCount: 0,
            dirtyFileCloseConfirmationAcceptCount: 0,
            dirtyFileCloseConfirmationRejectCount: 0,
            externalEditorEscalationCount: 0,
            releaseBlockingReasons: []
        )
    }

    func resumePreferenceLoad() {
        loadContinuation?.resume()
        loadContinuation = nil
    }

    func waitUntilLoadIsBlocked() async throws {
        for _ in 0..<100 where loadContinuation == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

@MainActor
private final class FailingPreferencesStartupService: AppShellStartupServicing {
    enum StartupError: Error {
        case preferenceUnavailable
    }

    var events: [String] = []

    func loadAppPreferences() async throws -> AppPreferences {
        events.append("load")
        throw StartupError.preferenceUnavailable
    }

    func restoreWorkspace() async throws -> RestoreWorkspaceResult {
        events.append("restore")
        return RestoreWorkspaceResult(store: WorkspaceStore())
    }

    func pilotDiagnostics() -> PilotDiagnostics {
        PilotDiagnostics(
            restoreFailureRate: 0,
            terminalSurfaceFailureRate: 0,
            fileSaveFailureRate: 0,
            medianLaunchToReadySeconds: nil,
            medianFileOpenSeconds: nil,
            fileRestoreFailureCount: 0,
            dirtyFileCloseConfirmationAcceptCount: 0,
            dirtyFileCloseConfirmationRejectCount: 0,
            externalEditorEscalationCount: 0,
            releaseBlockingReasons: []
        )
    }
}
