import Foundation
import NativeMacADECore

struct SessionShortcutCatalog: Equatable {
    let shortcutsByID: [UUID: SessionShortcut]

    init(shortcuts: [SessionShortcut] = SessionShortcut.builtInDefaults) {
        shortcutsByID = Self.keyedByID(shortcuts)
    }

    var shortcuts: [SessionShortcut] {
        Array(shortcutsByID.values)
    }

    func shortcut(id: UUID?) -> SessionShortcut? {
        guard let id else { return nil }
        return shortcutsByID[id]
    }

    static func keyedByID(_ shortcuts: [SessionShortcut]) -> [UUID: SessionShortcut] {
        var lookup = Dictionary(uniqueKeysWithValues: SessionShortcut.builtInDefaults.map { ($0.id, $0) })
        for shortcut in shortcuts {
            lookup[shortcut.id] = shortcut
        }
        return lookup
    }
}

struct SessionTerminalSummary: Identifiable, Equatable {
    let sessionID: UUID
    let tabID: UUID
    let title: String
    let fallbackTitle: String
    let agentLabel: String
    let shortcutID: UUID?
    let iconInput: SessionTerminalIconInput
    let lastActivatedAt: Date
    let exitObservation: TerminalExitObservation?
    let isSelected: Bool

    var id: UUID {
        tabID
    }

    var iconShortcut: SessionShortcut? {
        iconInput.shortcut
    }

    var hasExitObservation: Bool {
        exitObservation != nil
    }

    var exitStatus: Int32? {
        exitObservation?.exitStatus
    }

    func fallbackSystemImage(isActive: Bool) -> String? {
        iconInput.fallbackSystemImage(isActive: isActive)
    }
}

@MainActor
struct SessionTerminalSummaryBuilder {
    private let store: WorkspaceStore
    private let resolver: SessionTerminalPresentationResolver
    private let exitSnapshot: (UUID) -> TerminalExitObservation?

    init(
        store: WorkspaceStore,
        shortcutCatalog: SessionShortcutCatalog = SessionShortcutCatalog(),
        exitSnapshot: @escaping (UUID) -> TerminalExitObservation? = { _ in nil }
    ) {
        self.store = store
        resolver = SessionTerminalPresentationResolver(shortcuts: shortcutCatalog.shortcuts)
        self.exitSnapshot = exitSnapshot
    }

    func summaries(for session: WorkspaceSession) -> [SessionTerminalSummary] {
        let selectedTerminalTabID = selectedTerminalTabID()

        return store.terminalTabs(in: session.id).compactMap { tab in
            guard let presentation = resolver.resolve(
                tab: tab,
                legacySessionShortcutID: session.shortcutID
            ) else {
                return nil
            }

            return SessionTerminalSummary(
                sessionID: session.id,
                tabID: tab.id,
                title: presentation.title,
                fallbackTitle: presentation.fallbackTitle,
                agentLabel: presentation.agentLabel,
                shortcutID: presentation.shortcutID,
                iconInput: presentation.iconInput,
                lastActivatedAt: tab.lastActivatedAt,
                exitObservation: exitSnapshot(tab.id),
                isSelected: tab.id == selectedTerminalTabID
            )
        }
    }

    private func selectedTerminalTabID() -> UUID? {
        guard let selectedTab = store.selectedTab, selectedTab.kind == .terminal else {
            return nil
        }

        return selectedTab.id
    }
}
