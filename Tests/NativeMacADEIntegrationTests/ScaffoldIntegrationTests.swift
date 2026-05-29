import Foundation
import Testing
@testable import NativeMacADECore

@MainActor
struct ScaffoldIntegrationTests {
    @Test
    func liveContainerStartsEmptyAndWiresRequiredBoundaries() {
        let container = AppDependencyContainer.live()

        #expect(container.workspaceStore.projects.isEmpty)
        #expect(container.workspaceStore.selectedProjectID == nil)
    }

    @Test
    func terminalHostSurfacesUnavailableGhosttyAsTypedError() async {
        let host = TerminalHostController()
        let tab = WorkspaceTab(sessionID: UUID(), workingDirectory: "/tmp/ade", ordinal: 0)

        do {
            _ = try await host.createSurface(for: tab)
            Issue.record("Expected Ghostty placeholder to reject surface creation before task 02")
        } catch let error as WorkspaceCommandError {
            #expect(error == .terminalUnavailable("libghostty is not pinned or linked yet"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
