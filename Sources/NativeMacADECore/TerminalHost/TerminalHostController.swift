import AppKit
import Foundation

@MainActor
public final class TerminalHostController {
    private let adapter: any GhosttyAdapter
    public let containerView: NSView

    public init(adapter: any GhosttyAdapter = UnavailableGhosttyAdapter()) {
        self.adapter = adapter
        self.containerView = NSView(frame: .zero)
        self.containerView.wantsLayer = true
    }

    public func createSurface(for tab: WorkspaceTab) async throws -> GhosttySurfaceHandle {
        let configuration = GhosttyLaunchConfiguration(
            workingDirectory: tab.workingDirectory,
            command: tab.launchCommand,
            arguments: Self.decodeArguments(from: tab.launchArgumentsJSON)
        )
        try await adapter.initializeIfNeeded()
        return try await adapter.createSurface(configuration: configuration)
    }

    private static func decodeArguments(from json: String?) -> [String] {
        guard let json,
              let data = json.data(using: .utf8),
              let arguments = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return arguments
    }
}
