import Foundation
import Testing

struct FocusWorkspaceUIContractIntegrationTests {
    @Test
    func configModalComposesDedicatedFocusWorkspaceSectionUsingPreferencesPipeline() throws {
        let configModalSource = try sourceFile("Sources/NativeMacADE/AppShell/ConfigModalView.swift")
        let focusSectionSource = try sourceFile("Sources/NativeMacADE/AppShell/ConfigModalFocusWorkspaceSection.swift")

        #expect(configModalSource.contains("ConfigModalFocusWorkspaceSection("))
        #expect(focusSectionSource.contains("FocusWorkspaceSettingsPresentation(preferences: store.appPreferences)"))
        #expect(focusSectionSource.contains("commandService.loadAppPreferences()"))
        #expect(focusSectionSource.contains("commandService.saveAppPreferences(preferences)"))
        #expect(focusSectionSource.contains("FocusWorkspaceSettingsPresentation.legacyDetail"))
        #expect(focusSectionSource.contains("FocusWorkspaceSettingsPresentation.fileDetail"))
        #expect(focusSectionSource.contains("accessibilityIdentifier(\"focus-workspace-settings-section\")"))
    }

    @Test
    func shellHeaderComposesFocusWorkspaceActiveCueFromAppPreferences() throws {
        let contentViewSource = try sourceFile("Sources/NativeMacADE/AppShell/ContentView.swift")

        #expect(contentViewSource.contains("FocusWorkspaceActiveCuePresentation(preferences: store.appPreferences)"))
        #expect(contentViewSource.contains("if focusWorkspaceCue.isVisible"))
        #expect(contentViewSource.contains("FocusWorkspaceActiveCueView()"))
        #expect(contentViewSource.contains("FocusWorkspaceActiveCuePresentation.helpText"))
    }

    private func sourceFile(_ relativePath: String) throws -> String {
        let fileURL = try packageRoot().appendingPathComponent(relativePath)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    private func packageRoot() throws -> URL {
        var directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        for _ in 0..<6 {
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("Package.swift").path) {
                return directory
            }
            directory.deleteLastPathComponent()
        }
        throw PackageRootError.notFound
    }

    private enum PackageRootError: Error {
        case notFound
    }
}
