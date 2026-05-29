import NativeMacADECore
import SwiftUI

@main
struct NativeMacADEApp: App {
    @State private var workspaceStore: WorkspaceStore
    private let commandService: any WorkspaceCommandService
    private let terminalHostController: TerminalHostController

    init() {
        self.init(container: .live())
    }

    init(container: AppDependencyContainer = .live()) {
        _workspaceStore = State(initialValue: container.workspaceStore)
        commandService = container.workspaceCommandService
        terminalHostController = container.terminalHostController
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: workspaceStore, commandService: commandService, terminalHostController: terminalHostController)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Session") {
                    guard let selectedProjectID = workspaceStore.selectedProjectID else { return }
                    Task { try? await commandService.createSession(projectID: selectedProjectID, shortcutID: nil) }
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(workspaceStore.selectedProject == nil)

                Button("New Tab") {
                    guard let selectedSessionID = workspaceStore.selectedSessionID else { return }
                    Task { try? await commandService.createTab(sessionID: selectedSessionID) }
                }
                .keyboardShortcut("t", modifiers: [.command])
                .disabled(workspaceStore.selectedSession == nil)
            }
        }
    }
}
