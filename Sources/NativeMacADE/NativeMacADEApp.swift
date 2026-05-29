import AppKit
import NativeMacADECore
import SwiftUI

@main
struct AtelierApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var workspaceStore: WorkspaceStore
    @State private var appShellState: AppShellState
    private let commandService: any WorkspaceCommandService
    private let terminalHostController: TerminalHostController
    private let fileAccessService: any WorkspaceFileAccessing
    private let fileBufferController: any WorkspaceFileBufferManaging

    init() {
        self.init(container: .live())
    }

    init(container: AppDependencyContainer = .live()) {
        _workspaceStore = State(initialValue: container.workspaceStore)
        _appShellState = State(initialValue: AppShellState())
        commandService = container.workspaceCommandService
        terminalHostController = container.terminalHostController
        fileAccessService = container.fileAccessService
        fileBufferController = container.fileBufferController
        Self.installApplicationIcon()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                shellState: appShellState,
                store: workspaceStore,
                commandService: commandService,
                terminalHostController: terminalHostController,
                fileAccessService: fileAccessService,
                fileBufferController: fileBufferController
            )
                .toolbar(removing: .title)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appShellState.presentSettings(source: .appCommand)
                }
                .managedKeyboardShortcut(.openSettings, preferences: workspaceStore.appPreferences)
            }

            CommandGroup(replacing: .newItem) {
                Button("Start Session…") {
                    NotificationCenter.default.post(name: .showSessionCommandPalette, object: nil)
                }
                .managedKeyboardShortcut(.searchSessions, preferences: workspaceStore.appPreferences)
                .disabled(workspaceStore.selectedProject == nil)

                Button("New Tab") {
                    guard let selectedSessionID = workspaceStore.selectedSessionID else { return }
                    Task { try? await commandService.createTab(sessionID: selectedSessionID) }
                }
                .keyboardShortcut("t", modifiers: [.command])
                .disabled(workspaceStore.selectedSession == nil)
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save File") {
                    performSelectedFileCommand(.saveFile)
                }
                .managedKeyboardShortcut(.saveFile, preferences: workspaceStore.appPreferences)
                .disabled(!selectedFileCommandEnabled(.saveFile))

                Button("Revert File") {
                    performSelectedFileCommand(.revertFile)
                }
                .managedKeyboardShortcut(.revertFile, preferences: workspaceStore.appPreferences)
                .disabled(!selectedFileCommandEnabled(.revertFile))

                Divider()

                Button("Open File in External Editor") {
                    performSelectedFileCommand(.openFileInExternalEditor)
                }
                .managedKeyboardShortcut(.openFileInExternalEditor, preferences: workspaceStore.appPreferences)
                .disabled(!selectedFileCommandEnabled(.openFileInExternalEditor))
            }

            CommandMenu("Workspace") {
                Button("Previous Tab") {
                    selectAdjacentTab(direction: -1)
                }
                .managedKeyboardShortcut(.previousTab, preferences: workspaceStore.appPreferences)
                .disabled(workspaceStore.tabsForSelectedSession.count < 2)

                Button("Next Tab") {
                    selectAdjacentTab(direction: 1)
                }
                .managedKeyboardShortcut(.nextTab, preferences: workspaceStore.appPreferences)
                .disabled(workspaceStore.tabsForSelectedSession.count < 2)

                Divider()

                Button("Previous Session") {
                    selectAdjacentSession(direction: -1)
                }
                .managedKeyboardShortcut(.previousSession, preferences: workspaceStore.appPreferences)
                .disabled(workspaceStore.sessionsForSelectedProject.count < 2)

                Button("Next Session") {
                    selectAdjacentSession(direction: 1)
                }
                .managedKeyboardShortcut(.nextSession, preferences: workspaceStore.appPreferences)
                .disabled(workspaceStore.sessionsForSelectedProject.count < 2)

                Divider()

                Button("Toggle Left Sidebar") {
                    NotificationCenter.default.post(name: .toggleWorkspaceSidebar, object: nil)
                }
                .managedKeyboardShortcut(.toggleRightSidebar, preferences: workspaceStore.appPreferences)

                Button("Zoom In Terminal") {
                    terminalHostController.zoomIn()
                }
                .managedKeyboardShortcut(.zoomInTerminal, preferences: workspaceStore.appPreferences)

                Button("Zoom Out Terminal") {
                    terminalHostController.zoomOut()
                }
                .managedKeyboardShortcut(.zoomOutTerminal, preferences: workspaceStore.appPreferences)
            }
        }
    }

    private var selectedFileTab: WorkspaceTab? {
        guard let selectedTab = workspaceStore.selectedTab, selectedTab.kind == .file else { return nil }
        return selectedTab
    }

    private var selectedFileIsDirty: Bool {
        guard let selectedFileTab else { return false }
        return fileBufferController.isDirty(tabID: selectedFileTab.id)
    }

    private func selectedFileCommandEnabled(_ commandID: AppCommandID) -> Bool {
        AppCommandRegistry.isEnabled(
            commandID,
            selectedTab: workspaceStore.selectedTab,
            selectedFileIsDirty: selectedFileIsDirty
        )
    }

    private func performSelectedFileCommand(_ commandID: AppCommandID) {
        guard selectedFileTab != nil else { return }
        NotificationCenter.default.post(name: .performSelectedFileCommand, object: commandID)
    }

    private func selectAdjacentTab(direction: Int) {
        let tabs = workspaceStore.tabsForSelectedSession
        guard tabs.count > 1 else { return }
        let currentIndex = workspaceStore.selectedTabID.flatMap { selectedTabID in
            tabs.firstIndex { $0.id == selectedTabID }
        } ?? 0
        let nextIndex = wrappedIndex(currentIndex + direction, count: tabs.count)
        let nextTabID = tabs[nextIndex].id
        Task { try? await commandService.selectTab(id: nextTabID) }
    }

    private func selectAdjacentSession(direction: Int) {
        let sessions = workspaceStore.sessionsForSelectedProject
        guard sessions.count > 1 else { return }
        let currentIndex = workspaceStore.selectedSessionID.flatMap { selectedSessionID in
            sessions.firstIndex { $0.id == selectedSessionID }
        } ?? 0
        let nextIndex = wrappedIndex(currentIndex + direction, count: sessions.count)
        let nextSessionID = sessions[nextIndex].id
        Task { try? await commandService.selectSession(id: nextSessionID) }
    }

    private func wrappedIndex(_ index: Int, count: Int) -> Int {
        (index % count + count) % count
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
    static let performSelectedFileCommand = Notification.Name("Atelier.performSelectedFileCommand")
}

private extension View {
    func managedKeyboardShortcut(_ commandID: AppCommandID, preferences: AppPreferences) -> some View {
        let keybinding = AppCommandRegistry.resolvedKeybinding(for: commandID, preferences: preferences)
        return keyboardShortcut(keybinding.swiftUIKeyEquivalent, modifiers: keybinding.swiftUIModifiers)
    }
}

private extension KeybindingOverride {
    var swiftUIKeyEquivalent: KeyEquivalent {
        switch keyEquivalent {
        case "upArrow":
            return .upArrow
        case "downArrow":
            return .downArrow
        case "leftArrow":
            return .leftArrow
        case "rightArrow":
            return .rightArrow
        default:
            return keyEquivalent.first.map { KeyEquivalent($0) } ?? " "
        }
    }

    var swiftUIModifiers: EventModifiers {
        modifiers.reduce(EventModifiers()) { result, modifier in
            switch modifier {
            case .command:
                return result.union(.command)
            case .shift:
                return result.union(.shift)
            case .option:
                return result.union(.option)
            case .control:
                return result.union(.control)
            }
        }
    }
}
