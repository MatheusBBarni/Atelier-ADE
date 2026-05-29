import Foundation

public struct AppPreferences: Equatable, Sendable {
    public static let fixedID = 1
    public static let defaultThemeID = "cursor"
    public static let supportedThemeIDs: Set<String> = [
        "dracula",
        "onedark",
        "catppuccin",
        "cursor"
    ]

    public var id: Int
    public var themeID: String
    public var defaultSessionShortcutID: UUID?
    public var keybindings: [AppCommandID: KeybindingOverride]
    public var updatedAt: Date

    public init(
        id: Int = Self.fixedID,
        themeID: String = Self.defaultThemeID,
        defaultSessionShortcutID: UUID? = nil,
        keybindings: [AppCommandID: KeybindingOverride] = [:],
        updatedAt: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.id = id
        self.themeID = themeID
        self.defaultSessionShortcutID = defaultSessionShortcutID
        self.keybindings = keybindings
        self.updatedAt = updatedAt
    }

    public static var defaults: AppPreferences {
        AppPreferences()
    }

    public var keybindingsJSON: String {
        get throws {
            let overrides = keybindings.map { commandID, override in
                var normalizedOverride = override
                normalizedOverride.commandID = commandID
                return normalizedOverride
            }.sorted { $0.commandID.rawValue < $1.commandID.rawValue }
            let data = try JSONEncoder().encode(overrides)
            return String(decoding: data, as: UTF8.self)
        }
    }

    public static func decodeKeybindingsJSON(_ json: String) throws -> [AppCommandID: KeybindingOverride] {
        let overrides = try JSONDecoder().decode([KeybindingOverride].self, from: Data(json.utf8))
        var keybindings: [AppCommandID: KeybindingOverride] = [:]
        for override in overrides {
            guard keybindings[override.commandID] == nil else {
                throw AppPreferencesSerializationError.duplicateCommandID(override.commandID)
            }
            keybindings[override.commandID] = override
        }
        return keybindings
    }
}

public enum AppPreferencesSerializationError: Error, Equatable, Sendable {
    case duplicateCommandID(AppCommandID)
}

public enum AppCommandID: String, CaseIterable, Codable, Hashable, Sendable {
    case previousTab
    case nextTab
    case previousSession
    case nextSession
    case searchSessions
    case zoomInTerminal
    case zoomOutTerminal
    case toggleRightSidebar
    case openSettings

    public var defaultKeybinding: KeybindingOverride {
        switch self {
        case .previousTab:
            KeybindingOverride(commandID: self, keyEquivalent: "[")
        case .nextTab:
            KeybindingOverride(commandID: self, keyEquivalent: "]")
        case .previousSession:
            KeybindingOverride(commandID: self, keyEquivalent: "upArrow")
        case .nextSession:
            KeybindingOverride(commandID: self, keyEquivalent: "downArrow")
        case .searchSessions:
            KeybindingOverride(commandID: self, keyEquivalent: "p")
        case .zoomInTerminal:
            KeybindingOverride(commandID: self, keyEquivalent: "+")
        case .zoomOutTerminal:
            KeybindingOverride(commandID: self, keyEquivalent: "-")
        case .toggleRightSidebar:
            KeybindingOverride(commandID: self, keyEquivalent: "l")
        case .openSettings:
            KeybindingOverride(commandID: self, keyEquivalent: ",")
        }
    }
}

public struct KeybindingOverride: Codable, Equatable, Sendable {
    public var commandID: AppCommandID
    public var keyEquivalent: String
    public var modifiers: [KeyModifier]

    public init(
        commandID: AppCommandID,
        keyEquivalent: String,
        modifiers: [KeyModifier] = [.command]
    ) {
        self.commandID = commandID
        self.keyEquivalent = keyEquivalent
        self.modifiers = modifiers
    }
}

public enum KeyModifier: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case command
    case shift
    case option
    case control
}
