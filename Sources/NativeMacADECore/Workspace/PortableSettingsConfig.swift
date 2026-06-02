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
    public var keybindingsSectionPresent: Bool

    public init(
        version: Int = Self.currentVersion,
        appearance: PortableAppearanceConfig? = nil,
        behavior: PortableBehaviorConfig? = nil,
        defaultProfile: PortableDefaultProfileIdentifier? = nil,
        keybindings: [PortableKeybindingOverride] = [],
        keybindingsSectionPresent: Bool? = nil
    ) {
        self.version = version
        self.appearance = appearance
        self.behavior = behavior
        self.defaultProfile = defaultProfile
        self.keybindings = keybindings
        self.keybindingsSectionPresent = keybindingsSectionPresent ?? !keybindings.isEmpty
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        appearance = try container.decodeIfPresent(PortableAppearanceConfig.self, forKey: .appearance)
        behavior = try container.decodeIfPresent(PortableBehaviorConfig.self, forKey: .behavior)
        defaultProfile = try container.decodeIfPresent(PortableDefaultProfileIdentifier.self, forKey: .defaultProfile)
        keybindingsSectionPresent = container.contains(.keybindings)
        keybindings = if keybindingsSectionPresent {
            try container.decode([PortableKeybindingOverride].self, forKey: .keybindings)
        } else {
            []
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(appearance, forKey: .appearance)
        try container.encodeIfPresent(behavior, forKey: .behavior)
        try container.encodeIfPresent(defaultProfile, forKey: .defaultProfile)
        if keybindingsSectionPresent {
            try container.encode(keybindings, forKey: .keybindings)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case appearance
        case behavior
        case defaultProfile
        case keybindings
    }
}

public struct PortableSettingsProjection: Equatable, Sendable {
    public var preferences: AppPreferences
    public var result: PortableSettingsApplyResult

    public init(preferences: AppPreferences, result: PortableSettingsApplyResult) {
        self.preferences = preferences
        self.result = result
    }
}

public extension PortableSettingsConfig {
    var presentSections: [PortableSettingsSection] {
        Self.supportedTopLevelSections.filter { section in
            switch section {
            case .appearance:
                return appearance != nil
            case .behavior:
                return behavior != nil
            case .defaultProfile:
                return defaultProfile != nil
            case .keybindings:
                return keybindingsSectionPresent
            }
        }
    }

    func projectedPreferences(from basePreferences: AppPreferences) -> PortableSettingsProjection {
        var preferences = basePreferences
        var result = PortableSettingsApplyResult()

        guard Self.supportedVersions.contains(version) else {
            recordUnsupportedVersionDiagnostics(into: &result)
            return PortableSettingsProjection(preferences: preferences, result: result)
        }

        if let appearance {
            do {
                try Self.validateAppearance(appearance)
                preferences.themeID = appearance.themeID
                preferences.terminalFontSize = appearance.terminalFontSize
                result.recordApplied(.appearance)
            } catch {
                result.recordRejected(.appearance, reason: Self.diagnosticReason(for: error))
            }
        } else {
            result.recordSkipped(.appearance)
        }

        if let behavior {
            preferences.focusWorkspaceEnabled = behavior.focusWorkspaceEnabled
            result.recordApplied(.behavior)
        } else {
            result.recordSkipped(.behavior)
        }

        if let defaultProfile {
            do {
                preferences.defaultSessionShortcutID = try Self.defaultSessionShortcutID(for: defaultProfile)
                result.recordApplied(.defaultProfile)
            } catch {
                result.recordRejected(.defaultProfile, reason: Self.diagnosticReason(for: error))
            }
        } else {
            result.recordSkipped(.defaultProfile)
        }

        if keybindingsSectionPresent {
            do {
                preferences.keybindings = try PortableKeybindingOverride.runtimeOverrides(from: keybindings)
                result.recordApplied(.keybindings)
            } catch {
                result.recordRejected(.keybindings, reason: Self.diagnosticReason(for: error))
            }
        } else {
            result.recordSkipped(.keybindings)
        }

        return PortableSettingsProjection(preferences: preferences, result: result)
    }

    static func exported(from preferences: AppPreferences) -> PortableSettingsConfig {
        PortableSettingsConfig(
            appearance: PortableAppearanceConfig(
                themeID: preferences.themeID,
                terminalFontSize: preferences.terminalFontSize
            ),
            behavior: PortableBehaviorConfig(
                focusWorkspaceEnabled: preferences.focusWorkspaceEnabled
            ),
            defaultProfile: PortableDefaultProfileIdentifier.identifier(
                forDefaultSessionShortcutID: preferences.defaultSessionShortcutID
            ),
            keybindings: portableKeybindings(from: preferences),
            keybindingsSectionPresent: true
        )
    }

    static func validateAppearance(_ appearance: PortableAppearanceConfig) throws {
        guard AppPreferences.isSupportedThemeSelectionID(appearance.themeID) else {
            throw PortableSettingsValidationError.unsupportedThemeID(appearance.themeID)
        }

        guard AppPreferences.isSupportedTerminalFontSize(appearance.terminalFontSize) else {
            throw PortableSettingsValidationError.terminalFontSizeOutOfBounds(
                value: appearance.terminalFontSize,
                minimum: AppPreferences.minimumTerminalFontSize,
                maximum: AppPreferences.maximumTerminalFontSize
            )
        }
    }

    static func defaultSessionShortcutID(for identifier: PortableDefaultProfileIdentifier) throws -> UUID? {
        switch identifier {
        case .plain:
            return nil
        case .codex, .claude, .opencode:
            guard let shortcutID = identifier.runtimeDefaultSessionShortcutID else {
                throw PortableSettingsValidationError.missingBuiltInDefaultProfile(identifier)
            }
            return shortcutID
        case .unsupported(let rawValue):
            throw PortableSettingsValidationError.unsupportedDefaultProfile(rawValue)
        }
    }

    static func diagnosticReason(for error: Error) -> String {
        if let validationError = error as? PortableSettingsValidationError {
            return validationError.diagnosticReason
        }

        if case let WorkspaceCommandError.settingsValidationFailed(failure) = error {
            return failure.diagnosticReason
        }

        return String(describing: error)
    }

    private static func portableKeybindings(from preferences: AppPreferences) -> [PortableKeybindingOverride] {
        AppCommandRegistry.managedCommandIDs.compactMap { commandID in
            guard let override = preferences.keybindings[commandID] else {
                return nil
            }
            return PortableKeybindingOverride(KeybindingOverride(
                commandID: commandID,
                keyEquivalent: override.keyEquivalent,
                modifiers: override.modifiers
            ))
        }
    }

    private func recordUnsupportedVersionDiagnostics(into result: inout PortableSettingsApplyResult) {
        for section in Self.supportedTopLevelSections {
            if presentSections.contains(section) {
                result.recordRejected(section, reason: PortableSettingsValidationError.unsupportedVersion(version).diagnosticReason)
            } else {
                result.recordSkipped(section)
            }
        }
    }
}

public extension AppPreferences {
    var portableSettingsConfig: PortableSettingsConfig {
        PortableSettingsConfig.exported(from: self)
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

public enum PortableDefaultProfileIdentifier: Equatable, Hashable, Sendable {
    case plain
    case codex
    case claude
    case opencode
    case unsupported(String)

    public static let builtInIdentifiers: [PortableDefaultProfileIdentifier] = [
        .codex,
        .claude,
        .opencode
    ]

    public init(rawValue: String) {
        switch rawValue {
        case Self.plain.rawValue:
            self = .plain
        case Self.codex.rawValue:
            self = .codex
        case Self.claude.rawValue:
            self = .claude
        case Self.opencode.rawValue:
            self = .opencode
        default:
            self = .unsupported(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .plain:
            return "plain"
        case .codex:
            return "codex"
        case .claude:
            return "claude"
        case .opencode:
            return "opencode"
        case .unsupported(let rawValue):
            return rawValue
        }
    }

    public var runtimeTarget: PortableDefaultProfileRuntimeTarget {
        switch self {
        case .plain:
            return .plain
        case .codex, .claude, .opencode:
            guard let shortcut = canonicalBuiltInShortcut else {
                return .missingBuiltIn(identifier: self)
            }
            return .builtIn(shortcut)
        case .unsupported(let rawValue):
            return .unsupported(rawValue: rawValue)
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
        case .unsupported:
            return nil
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

extension PortableDefaultProfileIdentifier: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = Self(rawValue: try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum PortableDefaultProfileRuntimeTarget: Equatable, Sendable {
    case plain
    case builtIn(SessionShortcut)
    case missingBuiltIn(identifier: PortableDefaultProfileIdentifier)
    case unsupported(rawValue: String)

    public var shortcutID: UUID? {
        switch self {
        case .plain, .missingBuiltIn, .unsupported:
            return nil
        case .builtIn(let shortcut):
            return shortcut.id
        }
    }

    public var shortcut: SessionShortcut? {
        switch self {
        case .plain, .missingBuiltIn, .unsupported:
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
    case unsupportedThemeID(String)
    case terminalFontSizeOutOfBounds(value: Double, minimum: Double, maximum: Double)
    case unsupportedDefaultProfile(String)
    case missingBuiltInDefaultProfile(PortableDefaultProfileIdentifier)
    case unsupportedVersion(Int)
}

public extension PortableSettingsValidationError {
    var diagnosticReason: String {
        switch self {
        case .unsupportedCommandID(let commandID):
            return "unsupported_command_id:\(commandID)"
        case .duplicateCommandID(let commandID):
            return "duplicate_command_id:\(commandID.rawValue)"
        case .unsupportedThemeID(let themeID):
            return "unknown_theme_id:\(themeID)"
        case .terminalFontSizeOutOfBounds(let value, let minimum, let maximum):
            return "terminal_font_size_out_of_range:\(value):min:\(minimum):max:\(maximum)"
        case .unsupportedDefaultProfile(let rawValue):
            return "unsupported_default_profile:\(rawValue)"
        case .missingBuiltInDefaultProfile(let identifier):
            return "missing_builtin_default_profile:\(identifier.rawValue)"
        case .unsupportedVersion(let version):
            return "unsupported_version:\(version)"
        }
    }
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
