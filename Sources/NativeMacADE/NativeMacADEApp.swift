import NativeMacADECore
import SwiftUI

@main
struct NativeMacADEApp: App {
    @State private var workspaceStore: WorkspaceStore

    init() {
        self.init(container: .live())
    }

    init(container: AppDependencyContainer = .live()) {
        _workspaceStore = State(initialValue: container.workspaceStore)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: workspaceStore)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    workspaceStore.createPlaceholderTab()
                }
                .keyboardShortcut("t", modifiers: [.command])
                .disabled(workspaceStore.selectedSession == nil)
            }
        }
    }
}
