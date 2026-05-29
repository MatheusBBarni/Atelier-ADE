import Foundation

public enum AgentProfileProvenance: Equatable, Sendable {
    case builtIn
    case customizedBuiltIn
    case custom

    public var title: String {
        switch self {
        case .builtIn:
            return "Built-in"
        case .customizedBuiltIn:
            return "Customized built-in"
        case .custom:
            return "Custom"
        }
    }
}

public struct AgentProfileRowState: Identifiable, Equatable, Sendable {
    public var id: UUID { profile.id }
    public var profile: SessionShortcut
    public var isDefault: Bool
    public var provenance: AgentProfileProvenance

    public var canEdit: Bool { true }
    public var canReset: Bool { profile.isBuiltIn }
    public var canDelete: Bool { !profile.isBuiltIn }
    public var canMakeDefault: Bool { !isDefault }

    public init(profile: SessionShortcut, defaultSessionShortcutID: UUID?) {
        self.profile = profile
        isDefault = profile.id == defaultSessionShortcutID

        if profile.isBuiltIn, profile.hasUserOverride {
            provenance = .customizedBuiltIn
        } else if profile.isBuiltIn {
            provenance = .builtIn
        } else {
            provenance = .custom
        }
    }
}

public enum AgentProfileSectionState {
    public static func rows(
        for profiles: [SessionShortcut],
        defaultSessionShortcutID: UUID?
    ) -> [AgentProfileRowState] {
        profiles.map {
            AgentProfileRowState(profile: $0, defaultSessionShortcutID: defaultSessionShortcutID)
        }
    }

    public static func staleDefaultID(
        in preferences: AppPreferences,
        profiles: [SessionShortcut]
    ) -> UUID? {
        guard let defaultSessionShortcutID = preferences.defaultSessionShortcutID else {
            return nil
        }

        return profiles.contains(where: { $0.id == defaultSessionShortcutID }) ? nil : defaultSessionShortcutID
    }
}
