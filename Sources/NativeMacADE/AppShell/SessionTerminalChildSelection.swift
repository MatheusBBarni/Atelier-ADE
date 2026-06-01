import Foundation
import NativeMacADECore

@MainActor
enum SessionTerminalChildSelection {
    static func select(
        tabID: UUID,
        commandService: any WorkspaceCommandService
    ) async throws {
        try await commandService.selectTab(id: tabID)
    }
}
