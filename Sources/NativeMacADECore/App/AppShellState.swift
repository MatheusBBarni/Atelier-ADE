import Foundation
import Observation

public enum SettingsPresentationSource: String, Equatable, Sendable {
    case appCommand
    case visibleEntryPoint
}

@MainActor
@Observable
public final class AppShellState {
    public var isSettingsPresented: Bool
    public private(set) var settingsPresentationSource: SettingsPresentationSource?

    public init(isSettingsPresented: Bool = false) {
        self.isSettingsPresented = isSettingsPresented
    }

    public func presentSettings(source: SettingsPresentationSource) {
        settingsPresentationSource = source
        isSettingsPresented = true
    }

    public func dismissSettings() {
        isSettingsPresented = false
        settingsPresentationSource = nil
    }
}

@MainActor
public protocol AppShellStartupServicing {
    func loadAppPreferences() async throws -> AppPreferences
    @discardableResult
    func restoreWorkspace() async throws -> RestoreWorkspaceResult
    func pilotDiagnostics() -> PilotDiagnostics
}

public struct AppShellStartupResult {
    public var restoreResult: RestoreWorkspaceResult?
    public var pilotDiagnostics: PilotDiagnostics
    public var preferenceLoadErrorDescription: String?
    public var restoreErrorDescription: String?

    public init(
        restoreResult: RestoreWorkspaceResult?,
        pilotDiagnostics: PilotDiagnostics,
        preferenceLoadErrorDescription: String? = nil,
        restoreErrorDescription: String? = nil
    ) {
        self.restoreResult = restoreResult
        self.pilotDiagnostics = pilotDiagnostics
        self.preferenceLoadErrorDescription = preferenceLoadErrorDescription
        self.restoreErrorDescription = restoreErrorDescription
    }
}

public enum AppShellStartupCoordinator {
    @MainActor
    public static func run(
        commandService: any AppShellStartupServicing,
        store: WorkspaceStore,
        afterPreferencesLoaded: @MainActor () -> Void = {}
    ) async -> AppShellStartupResult {
        var preferenceLoadErrorDescription: String?
        do {
            _ = try await commandService.loadAppPreferences()
        } catch {
            store.updateAppPreferences(.defaults)
            preferenceLoadErrorDescription = String(describing: error)
        }

        afterPreferencesLoaded()

        var restoreResult: RestoreWorkspaceResult?
        var restoreErrorDescription: String?
        do {
            restoreResult = try await commandService.restoreWorkspace()
        } catch {
            restoreErrorDescription = String(describing: error)
        }

        return AppShellStartupResult(
            restoreResult: restoreResult,
            pilotDiagnostics: commandService.pilotDiagnostics(),
            preferenceLoadErrorDescription: preferenceLoadErrorDescription,
            restoreErrorDescription: restoreErrorDescription
        )
    }
}
