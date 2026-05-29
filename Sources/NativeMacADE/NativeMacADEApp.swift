import AppKit
import NativeMacADECore
import SwiftUI

@main
struct AtelierApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
        Self.installApplicationIcon()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: workspaceStore, commandService: commandService, terminalHostController: terminalHostController)
                .toolbar(removing: .title)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Toggle Sidebar") {
                    NotificationCenter.default.post(name: .toggleWorkspaceSidebar, object: nil)
                }
                .keyboardShortcut("b", modifiers: [.command])

                Button("Start Session…") {
                    NotificationCenter.default.post(name: .showSessionCommandPalette, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
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

    private static func installApplicationIcon() {
        guard let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
              let iconImage = NSImage(contentsOf: iconURL)
        else {
            return
        }

        iconImage.size = NSSize(width: 512, height: 512)
        NSApplication.shared.applicationIconImage = iconImage
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension Notification.Name {
    static let toggleWorkspaceSidebar = Notification.Name("Atelier.toggleWorkspaceSidebar")
    static let showSessionCommandPalette = Notification.Name("Atelier.showSessionCommandPalette")
}
