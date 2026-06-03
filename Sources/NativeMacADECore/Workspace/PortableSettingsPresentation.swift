import Foundation

public enum PortableSettingsScopeKind: Equatable, Sendable {
    case portableV1
    case localOnlyV1
    case mixedV1

    public var badgeTitle: String {
        switch self {
        case .portableV1:
            return "Portable V1"
        case .localOnlyV1:
            return "Local-only V1"
        case .mixedV1:
            return "Mixed scope"
        }
    }
}

public struct PortableSettingsScopeLabel: Equatable, Sendable {
    public var kind: PortableSettingsScopeKind
    public var title: String
    public var detail: String

    public init(kind: PortableSettingsScopeKind, title: String, detail: String) {
        self.kind = kind
        self.title = title
        self.detail = detail
    }
}

public extension PortableSettingsScopeLabel {
    static let appearance = PortableSettingsScopeLabel(
        kind: .portableV1,
        title: "Appearance travels",
        detail: "Theme and terminal font size are written to the personal settings file."
    )

    static let focusWorkspace = PortableSettingsScopeLabel(
        kind: .portableV1,
        title: "Focus Workspace travels",
        detail: "The Focus Workspace on/off setting is part of the portable V1 config."
    )

    static let managedShortcuts = PortableSettingsScopeLabel(
        kind: .portableV1,
        title: "Managed shortcuts travel",
        detail: "Managed app-command keyboard shortcuts are written to the personal settings file."
    )

    static let agentProfilesMixed = PortableSettingsScopeLabel(
        kind: .mixedV1,
        title: "Agent Profiles are mixed scope",
        detail: "Built-in default selection travels. Custom profiles, custom defaults, launch commands, launch arguments, and secret refs stay local-only."
    )

    static let builtInDefaultProfileSelection = PortableSettingsScopeLabel(
        kind: .portableV1,
        title: "Built-in default travels",
        detail: "Selecting this built-in profile as the default is portable."
    )

    static let customDefaultProfileSelection = PortableSettingsScopeLabel(
        kind: .localOnlyV1,
        title: "Custom default stays local",
        detail: "Choosing a custom profile as the default stays on this machine in V1."
    )

    static let agentProfileCommandDetails = PortableSettingsScopeLabel(
        kind: .localOnlyV1,
        title: "Command details stay local",
        detail: "Profile definitions, launch commands, launch arguments, and secret refs stay on this machine."
    )
}

public extension PortableSettingsSection {
    var displayTitle: String {
        switch self {
        case .appearance:
            return "Appearance"
        case .behavior:
            return "Focus Workspace"
        case .defaultProfile:
            return "Built-in default profile"
        case .keybindings:
            return "Keyboard Shortcuts"
        }
    }
}

public struct PortableSettingsApplyStatusPresentation: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case idle
        case success
        case partial
        case missingFile
        case failure
    }

    public var kind: Kind
    public var title: String
    public var summary: String
    public var appliedSectionDetails: [String]
    public var rejectedSectionDetails: [String]

    public init(
        kind: Kind,
        title: String,
        summary: String,
        appliedSectionDetails: [String] = [],
        rejectedSectionDetails: [String] = []
    ) {
        self.kind = kind
        self.title = title
        self.summary = summary
        self.appliedSectionDetails = appliedSectionDetails
        self.rejectedSectionDetails = rejectedSectionDetails
    }

    public static let idle = PortableSettingsApplyStatusPresentation(
        kind: .idle,
        title: "No reload run",
        summary: "Manual reload results will appear here."
    )

    public init(result: PortableSettingsApplyResult) {
        let applied = result.appliedSections.map(\.displayTitle)
        let rejected = result.rejectedSectionDetails

        if result.fileMissing {
            self.init(
                kind: .missingFile,
                title: "Portable file not found",
                summary: "No portable settings file exists yet. Supported settings will create it when saved.",
                appliedSectionDetails: applied,
                rejectedSectionDetails: rejected
            )
            return
        }

        if !rejected.isEmpty {
            self.init(
                kind: applied.isEmpty ? .failure : .partial,
                title: applied.isEmpty ? "Reload rejected" : "Partial reload applied",
                summary: applied.isEmpty
                    ? "No portable sections were applied. Rejected sections need edits in settings.json."
                    : "Some portable sections applied. Rejected sections need edits in settings.json.",
                appliedSectionDetails: applied,
                rejectedSectionDetails: rejected
            )
            return
        }

        let summary = applied.isEmpty
            ? "Reload finished with no portable sections to apply."
            : "Applied \(applied.joined(separator: ", "))."
        self.init(
            kind: .success,
            title: result.seededFromSQLite ? "Portable file seeded" : "Portable settings applied",
            summary: summary,
            appliedSectionDetails: applied
        )
    }

    public static func failure(message: String) -> PortableSettingsApplyStatusPresentation {
        PortableSettingsApplyStatusPresentation(
            kind: .failure,
            title: "Reload failed",
            summary: message,
            rejectedSectionDetails: [message]
        )
    }
}

public extension PortableSettingsApplyResult {
    var rejectedSectionDetails: [String] {
        rejectedSections.keys.sorted().map { sectionKey in
            let title = PortableSettingsSection(rawValue: sectionKey)?.displayTitle ?? sectionKey
            let reason = rejectedSections[sectionKey] ?? ""
            return reason.isEmpty ? title : "\(title): \(reason)"
        }
    }
}
