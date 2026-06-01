import Foundation
import Testing
@testable import NativeMacADE
import NativeMacADECore

@Suite
@MainActor
struct SessionTerminalPresentationResolverTests {
    @Test
    func customTabTitleOverridesShortcutAndLaunchCommandTitle() throws {
        let codex = try #require(SessionShortcut.builtInDefaults.first { $0.label == "Codex" })
        let tab = terminalTab(
            title: "Planning Thread",
            shortcutID: codex.id,
            launchCommand: "claude"
        )

        let presentation = try #require(SessionTerminalPresentationResolver().resolve(tab: tab))

        #expect(presentation.title == "Planning Thread")
        #expect(presentation.fallbackTitle == "Codex")
        #expect(presentation.agentLabel == "Codex")
        #expect(presentation.shortcutID == codex.id)

        guard case .shortcut(let iconShortcut) = presentation.iconInput else {
            Issue.record("Expected shortcut icon input")
            return
        }
        #expect(iconShortcut == codex)
    }

    @Test
    func shortcutIDResolvesBuiltInAndCustomLabelsAndIconInputs() throws {
        let claude = try #require(SessionShortcut.builtInDefaults.first { $0.label == "Claude" })
        let custom = SessionShortcut(
            id: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
            label: "Review Bot",
            launchCommand: "/usr/local/bin/codex",
            launchArgumentsJSON: "[\"--review\"]",
            isBuiltIn: false,
            hasUserOverride: true
        )
        let resolver = SessionTerminalPresentationResolver(shortcuts: [custom])

        let builtInPresentation = try #require(resolver.resolve(tab: terminalTab(shortcutID: claude.id, launchCommand: "claude")))
        let customPresentation = try #require(resolver.resolve(tab: terminalTab(shortcutID: custom.id, launchCommand: "ignored")))

        #expect(builtInPresentation.title == "Claude")
        #expect(builtInPresentation.agentLabel == "Claude")
        #expect(builtInPresentation.shortcutID == claude.id)
        guard case .shortcut(let builtInIconShortcut) = builtInPresentation.iconInput else {
            Issue.record("Expected built-in shortcut icon input")
            return
        }
        #expect(builtInIconShortcut == claude)

        #expect(customPresentation.title == "Review Bot")
        #expect(customPresentation.agentLabel == "Review Bot")
        #expect(customPresentation.shortcutID == custom.id)
        guard case .shortcut(let customIconShortcut) = customPresentation.iconInput else {
            Issue.record("Expected custom shortcut icon input")
            return
        }
        #expect(customIconShortcut == custom)
    }

    @Test
    func unknownLaunchCommandsAreHumanizedAndUseLaunchCommandIconInput() throws {
        let tab = terminalTab(launchCommand: "/opt/tools/my_agent-cli")

        let presentation = try #require(SessionTerminalPresentationResolver().resolve(tab: tab))

        #expect(presentation.title == "My Agent Cli")
        #expect(presentation.fallbackTitle == "My Agent Cli")
        #expect(presentation.agentLabel == "My Agent Cli")
        #expect(presentation.shortcutID == nil)
        #expect(presentation.fallbackSystemImage(isActive: false) == nil)
        guard case .launchCommand(let command, let label) = presentation.iconInput else {
            Issue.record("Expected launch-command icon input")
            return
        }
        #expect(command == "/opt/tools/my_agent-cli")
        #expect(label == "My Agent Cli")
        #expect(presentation.iconShortcut?.launchCommand == "/opt/tools/my_agent-cli")
    }

    @Test
    func plainShellTabsResolveToTerminalAndGenericTerminalIconPath() throws {
        let tab = terminalTab()

        let presentation = try #require(SessionTerminalPresentationResolver().resolve(tab: tab))

        #expect(presentation.title == "Terminal")
        #expect(presentation.fallbackTitle == "Terminal")
        #expect(presentation.agentLabel == "Terminal")
        #expect(presentation.shortcutID == nil)
        #expect(presentation.iconInput == .terminal)
        #expect(presentation.iconShortcut == nil)
        #expect(presentation.fallbackSystemImage(isActive: false) == "terminal")
        #expect(presentation.fallbackSystemImage(isActive: true) == "terminal.fill")
    }

    @Test
    func fileTabsDoNotRouteThroughTerminalPresentationLogic() {
        let fileTab = WorkspaceTab(
            sessionID: UUID(),
            kind: .file,
            workingDirectory: "/tmp/project",
            title: nil,
            launchCommand: "codex",
            fileReference: WorkspaceFileReference(path: "/tmp/project/Sources/App.swift", projectRoot: "/tmp/project"),
            ordinal: 0
        )

        #expect(SessionTerminalPresentationResolver().resolve(tab: fileTab) == nil)
    }

    @Test
    func tabItemViewAndRenameDraftShareTerminalFallbackOutput() throws {
        let opencode = try #require(SessionShortcut.builtInDefaults.first { $0.label == "OpenCode" })
        let tab = terminalTab(shortcutID: opencode.id, launchCommand: "opencode")
        let tabItemView = tabItemView(tab: tab)
        let renameDraft = TabRenameDraft(tab: tab)

        #expect(tabItemView.resolvedTitle == "OpenCode")
        #expect(renameDraft.placeholderTitle == "OpenCode")
        #expect(tabItemView.resolvedTitle == renameDraft.placeholderTitle)
    }

    @Test
    func legacyRestoredTerminalTabsWithoutShortcutIDResolveStableFallbackIdentity() throws {
        let codex = try #require(SessionShortcut.builtInDefaults.first { $0.label == "Codex" })
        let restoredTab = terminalTab(shortcutID: nil, launchCommand: "codex")
        let tabItemView = tabItemView(tab: restoredTab, legacySessionShortcutID: codex.id)
        let renameDraft = TabRenameDraft(tab: restoredTab, legacySessionShortcutID: codex.id)
        let presentation = try #require(
            SessionTerminalPresentationResolver().resolve(
                tab: restoredTab,
                legacySessionShortcutID: codex.id
            )
        )

        #expect(presentation.title == "Codex")
        #expect(presentation.agentLabel == "Codex")
        #expect(presentation.shortcutID == codex.id)
        #expect(tabItemView.resolvedTitle == "Codex")
        #expect(renameDraft.placeholderTitle == "Codex")
        #expect(tabItemView.resolvedTitle == renameDraft.placeholderTitle)
    }

    @Test
    func renameDraftKeepsFallbackPlaceholderSeparateFromCustomCurrentTitle() throws {
        let claude = try #require(SessionShortcut.builtInDefaults.first { $0.label == "Claude" })
        let tab = terminalTab(title: "Follow-up", shortcutID: claude.id, launchCommand: "claude")

        let renameDraft = TabRenameDraft(tab: tab)

        #expect(renameDraft.currentTitle == "Follow-up")
        #expect(renameDraft.placeholderTitle == "Claude")
    }
}

private func terminalTab(
    title: String? = nil,
    shortcutID: UUID? = nil,
    launchCommand: String? = nil
) -> WorkspaceTab {
    WorkspaceTab(
        sessionID: UUID(),
        kind: .terminal,
        workingDirectory: "/tmp/project",
        title: title,
        shortcutID: shortcutID,
        launchCommand: launchCommand,
        ordinal: 0
    )
}

@MainActor
private func tabItemView(tab: WorkspaceTab, legacySessionShortcutID: UUID? = nil) -> TabItemView {
    TabItemView(
        tab: tab,
        legacySessionShortcutID: legacySessionShortcutID,
        isActive: false,
        isDirty: false,
        isReordering: false,
        onSelect: {},
        onDragStarted: { NSItemProvider() },
        onRename: {},
        onClose: {}
    )
}
