import Foundation

/// Public V1 settings file contract. This intentionally models only portable,
/// user-editable fields and never serializes raw persistence models.
public struct PortableSettingsConfig: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let supportedVersions: Set<Int> = [currentVersion]
    public static let supportedTopLevelSections: [PortableSettingsSection] = [
        .appearance,
        .behavior,
        .defaultProfile,
        .keybindings
    ]
    public static let excludedRuntimeAndLocalFieldNames: Set<String> = [
        "id",
        "updatedAt",
        "defaultSessionShortcutID",
        "launchCommand",
        "launchArgumentsJSON",
        "secretRef",
        "isBuiltIn",
        "hasUserOverride",
        "customProfiles",
        "sessions",
        "tabs",
        "workspaceRestoreState"
    ]

    public var version: Int
    public var appearance: PortableAppearanceConfig?
    public var behavior: PortableBehaviorConfig?
    public var defaultProfile: PortableDefaultProfileIdentifier?
    public var keybindings: [PortableKeybindingOverride]

    public init(
        version: Int = Self.currentVersion,
        appearance: PortableAppearanceConfig? = nil,
        behavior: PortableBehaviorConfig? = nil,
        defaultProfile: PortableDefaultProfileIdentifier? = nil,
        keybindings: [PortableKeybindingOverride] = []
    ) {
        self.version = version
        self.appearance = appearance
        self.behavior = behavior
        self.defaultProfile = defaultProfile
        self.keybindings = keybindings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        appearance = try container.decodeIfPresent(PortableAppearanceConfig.self, forKey: .appearance)
        behavior = try container.decodeIfPresent(PortableBehaviorConfig.self, forKey: .behavior)
        defaultProfile = try container.decodeIfPresent(PortableDefaultProfileIdentifier.self, forKey: .defaultProfile)
        keybindings = try container.decodeIfPresent([PortableKeybindingOverride].self, forKey: .keybindings) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(appearance, forKey: .appearance)
        try container.encodeIfPresent(behavior, forKey: .behavior)
        try container.encodeIfPresent(defaultProfile, forKey: .defaultProfile)
        try container.encode(keybindings, forKey: .keybindings)
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case appearance
        case behavior
        case defaultProfile
        case keybindings
    }
}

public enum PortableSettingsSection: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case appearance
    case behavior
    case defaultProfile
    case keybindings
}

public struct PortableAppearanceConfig: Codable, Equatable, Sendable {
    public var themeID: String
    public var terminalFontSize: Double

    public init(themeID: String, terminalFontSize: Double) {
        self.themeID = themeID
        self.terminalFontSize = terminalFontSize
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        themeID = try container.decode(String.self, forKey: .themeID)
        terminalFontSize = try container.decode(Double.self, forKey: .terminalFontSize)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(themeID, forKey: .themeID)
        try container.encode(terminalFontSize, forKey: .terminalFontSize)
    }

    private enum CodingKeys: String, CodingKey {
        case themeID
        case terminalFontSize
    }
}

public struct PortableBehaviorConfig: Codable, Equatable, Sendable {
    public var focusWorkspaceEnabled: Bool

    public init(focusWorkspaceEnabled: Bool) {
        self.focusWorkspaceEnabled = focusWorkspaceEnabled
    }
}

public enum PortableDefaultProfileIdentifier: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case plain
    case codex
    case claude
    case opencode

    public static let builtInIdentifiers: [PortableDefaultProfileIdentifier] = [
        .codex,
        .claude,
        .opencode
    ]

    public var runtimeTarget: PortableDefaultProfileRuntimeTarget {
        switch self {
        case .plain:
            return .plain
        case .codex, .claude, .opencode:
            guard let shortcut = canonicalBuiltInShortcut else {
                return .missingBuiltIn(identifier: self)
            }
            return .builtIn(shortcut)
        }
    }

    public var runtimeDefaultSessionShortcutID: UUID? {
        runtimeTarget.shortcutID
    }

    public var canonicalBuiltInShortcut: SessionShortcut? {
        switch self {
        case .plain:
            return nil
        case .codex:
            return SessionShortcut.builtInDefaults.first { $0.launchCommand == "codex" }
        case .claude:
            return SessionShortcut.builtInDefaults.first { $0.launchCommand == "claude" }
        case .opencode:
            return SessionShortcut.builtInDefaults.first { $0.launchCommand == "opencode" }
        }
    }

    public static func identifier(forDefaultSessionShortcutID shortcutID: UUID?) -> PortableDefaultProfileIdentifier? {
        guard let shortcutID else {
            return .plain
        }
        return identifier(forBuiltInShortcutID: shortcutID)
    }

    public static func identifier(forBuiltInShortcutID shortcutID: UUID) -> PortableDefaultProfileIdentifier? {
        builtInIdentifiers.first { $0.canonicalBuiltInShortcut?.id == shortcutID }
    }

    public static func identifier(forBuiltInShortcut shortcut: SessionShortcut) -> PortableDefaultProfileIdentifier? {
        identifier(forBuiltInShortcutID: shortcut.id)
    }
}

public enum PortableDefaultProfileRuntimeTarget: Equatable, Sendable {
    case plain
    case builtIn(SessionShortcut)
    case missingBuiltIn(identifier: PortableDefaultProfileIdentifier)

    public var shortcutID: UUID? {
        switch self {
        case .plain, .missingBuiltIn:
            return nil
        case .builtIn(let shortcut):
            return shortcut.id
        }
    }

    public var shortcut: SessionShortcut? {
        switch self {
        case .plain, .missingBuiltIn:
            return nil
        case .builtIn(let shortcut):
            return shortcut
        }
    }
}

public struct PortableKeybindingOverride: Codable, Equatable, Sendable {
    public var commandID: String
    public var keyEquivalent: String
    public var modifiers: [KeyModifier]

    public init(commandID: String, keyEquivalent: String, modifiers: [KeyModifier] = [.command]) {
        self.commandID = commandID
        self.keyEquivalent = keyEquivalent
        self.modifiers = modifiers
    }

    public init(_ override: KeybindingOverride) {
        self.init(
            commandID: override.commandID.rawValue,
            keyEquivalent: override.keyEquivalent,
            modifiers: override.modifiers
        )
    }

    public var managedCommandID: AppCommandID? {
        Self.managedCommandID(rawValue: commandID)
    }

    public func runtimeOverride() throws -> KeybindingOverride {
        let commandID = try Self.requireManagedCommandID(rawValue: commandID)
        return KeybindingOverride(
            commandID: commandID,
            keyEquivalent: keyEquivalent,
            modifiers: modifiers
        )
    }

    public static func runtimeOverrides(from portableOverrides: [PortableKeybindingOverride]) throws -> [AppCommandID: KeybindingOverride] {
        var overrides: [AppCommandID: KeybindingOverride] = [:]
        for portableOverride in portableOverrides {
            let commandID = try requireManagedCommandID(rawValue: portableOverride.commandID)
            guard overrides[commandID] == nil else {
                throw PortableSettingsValidationError.duplicateCommandID(commandID)
            }
            overrides[commandID] = KeybindingOverride(
                commandID: commandID,
                keyEquivalent: portableOverride.keyEquivalent,
                modifiers: portableOverride.modifiers
            )
        }
        try AppCommandRegistry.validate(overrides)
        return overrides
    }

    public static func managedCommandID(rawValue: String) -> AppCommandID? {
        guard let commandID = AppCommandID(rawValue: rawValue),
              AppCommandRegistry.managedCommandIDs.contains(commandID)
        else {
            return nil
        }
        return commandID
    }

    private static func requireManagedCommandID(rawValue: String) throws -> AppCommandID {
        guard let commandID = managedCommandID(rawValue: rawValue) else {
            throw PortableSettingsValidationError.unsupportedCommandID(rawValue)
        }
        return commandID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        commandID = try container.decode(String.self, forKey: .commandID)
        keyEquivalent = try container.decode(String.self, forKey: .keyEquivalent)
        modifiers = try container.decode([KeyModifier].self, forKey: .modifiers)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(commandID, forKey: .commandID)
        try container.encode(keyEquivalent, forKey: .keyEquivalent)
        try container.encode(modifiers, forKey: .modifiers)
    }

    private enum CodingKeys: String, CodingKey {
        case commandID
        case keyEquivalent
        case modifiers
    }
}

public enum PortableSettingsValidationError: Error, Equatable, Sendable {
    case unsupportedCommandID(String)
    case duplicateCommandID(AppCommandID)
}

public struct PortableSettingsApplyResult: Codable, Equatable, Sendable {
    public var appliedSections: [PortableSettingsSection]
    public var rejectedSections: [String: String]
    public var skippedSections: [PortableSettingsSection]
    public var seededFromSQLite: Bool
    public var fileMissing: Bool

    public init(
        appliedSections: [PortableSettingsSection] = [],
        rejectedSections: [String: String] = [:],
        skippedSections: [PortableSettingsSection] = [],
        seededFromSQLite: Bool = false,
        fileMissing: Bool = false
    ) {
        self.appliedSections = appliedSections
        self.rejectedSections = rejectedSections
        self.skippedSections = skippedSections
        self.seededFromSQLite = seededFromSQLite
        self.fileMissing = fileMissing
    }

    public var hasRejectedSections: Bool {
        !rejectedSections.isEmpty
    }

    public mutating func recordApplied(_ section: PortableSettingsSection) {
        appliedSections.append(section)
    }

    public mutating func recordRejected(_ section: PortableSettingsSection, reason: String) {
        rejectedSections[section.rawValue] = reason
    }

    public mutating func recordSkipped(_ section: PortableSettingsSection) {
        skippedSections.append(section)
    }
}

public extension SessionShortcut {
    static func canonicalBuiltInShortcut(id: UUID) -> SessionShortcut? {
        builtInDefaults.first { $0.id == id }
    }

    static func canonicalBuiltInShortcut(portableIdentifier: PortableDefaultProfileIdentifier) -> SessionShortcut? {
        portableIdentifier.canonicalBuiltInShortcut
    }

    var portableDefaultProfileIdentifier: PortableDefaultProfileIdentifier? {
        PortableDefaultProfileIdentifier.identifier(forBuiltInShortcutID: id)
    }
}
