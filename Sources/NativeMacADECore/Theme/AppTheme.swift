import Foundation

public enum ThemeColorScheme: String, Equatable, Sendable {
    case dark
    case light
}

public struct ShellThemePalette: Equatable, Sendable {
    public var shellBackground: NordColorToken
    public var sidebarBackground: NordColorToken
    public var contentBackground: NordColorToken
    public var elevatedBackground: NordColorToken
    public var tabBarBackground: NordColorToken
    public var activeBackground: NordColorToken
    public var activeBorder: NordColorToken
    public var border: NordColorToken
    public var primaryText: NordColorToken
    public var secondaryText: NordColorToken
    public var mutedText: NordColorToken
    public var selectedText: NordColorToken
    public var accent: NordColorToken
    public var secondaryAccent: NordColorToken
    public var warning: NordColorToken
    public var destructive: NordColorToken

    public init(
        shellBackground: NordColorToken,
        sidebarBackground: NordColorToken,
        contentBackground: NordColorToken,
        elevatedBackground: NordColorToken,
        tabBarBackground: NordColorToken,
        activeBackground: NordColorToken,
        activeBorder: NordColorToken,
        border: NordColorToken,
        primaryText: NordColorToken,
        secondaryText: NordColorToken,
        mutedText: NordColorToken,
        selectedText: NordColorToken,
        accent: NordColorToken,
        secondaryAccent: NordColorToken,
        warning: NordColorToken,
        destructive: NordColorToken
    ) {
        self.shellBackground = shellBackground
        self.sidebarBackground = sidebarBackground
        self.contentBackground = contentBackground
        self.elevatedBackground = elevatedBackground
        self.tabBarBackground = tabBarBackground
        self.activeBackground = activeBackground
        self.activeBorder = activeBorder
        self.border = border
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.mutedText = mutedText
        self.selectedText = selectedText
        self.accent = accent
        self.secondaryAccent = secondaryAccent
        self.warning = warning
        self.destructive = destructive
    }
}

public struct AppTheme: Identifiable, Equatable, Sendable {
    public static let defaultID = "cursor"

    public var id: String
    public var displayName: String
    public var colorScheme: ThemeColorScheme
    public var shellPalette: ShellThemePalette
    public var terminalAppearance: TerminalAppearance

    public init(
        id: String,
        displayName: String,
        colorScheme: ThemeColorScheme,
        shellPalette: ShellThemePalette,
        terminalAppearance: TerminalAppearance
    ) {
        self.id = id
        self.displayName = displayName
        self.colorScheme = colorScheme
        self.shellPalette = shellPalette
        self.terminalAppearance = terminalAppearance
    }

    public static let dracula = AppTheme(
        id: "dracula",
        displayName: "Dracula",
        colorScheme: .dark,
        shellPalette: ShellThemePalette(
            shellBackground: NordColorToken(hex: "#282A36"),
            sidebarBackground: NordColorToken(hex: "#21222C"),
            contentBackground: NordColorToken(hex: "#282A36"),
            elevatedBackground: NordColorToken(hex: "#343746"),
            tabBarBackground: NordColorToken(hex: "#21222C"),
            activeBackground: NordColorToken(hex: "#BD93F9"),
            activeBorder: NordColorToken(hex: "#FF79C6"),
            border: NordColorToken(hex: "#44475A"),
            primaryText: NordColorToken(hex: "#F8F8F2"),
            secondaryText: NordColorToken(hex: "#E9E9F4"),
            mutedText: NordColorToken(hex: "#BFBFD3", opacity: 0.72),
            selectedText: NordColorToken(hex: "#F8F8F2"),
            accent: NordColorToken(hex: "#BD93F9"),
            secondaryAccent: NordColorToken(hex: "#8BE9FD"),
            warning: NordColorToken(hex: "#F1FA8C"),
            destructive: NordColorToken(hex: "#FF5555")
        ),
        terminalAppearance: TerminalAppearance(
            backgroundHex: "#282A36",
            foregroundHex: "#F8F8F2",
            cursorHex: "#FF79C6",
            selectionHex: "#44475A"
        )
    )

    public static let oneDark = AppTheme(
        id: "onedark",
        displayName: "OneDark",
        colorScheme: .dark,
        shellPalette: ShellThemePalette(
            shellBackground: NordColorToken(hex: "#282C34"),
            sidebarBackground: NordColorToken(hex: "#21252B"),
            contentBackground: NordColorToken(hex: "#282C34"),
            elevatedBackground: NordColorToken(hex: "#2F343D"),
            tabBarBackground: NordColorToken(hex: "#21252B"),
            activeBackground: NordColorToken(hex: "#61AFEF"),
            activeBorder: NordColorToken(hex: "#56B6C2"),
            border: NordColorToken(hex: "#3E4451"),
            primaryText: NordColorToken(hex: "#E6EDF3"),
            secondaryText: NordColorToken(hex: "#ABB2BF"),
            mutedText: NordColorToken(hex: "#8B949E", opacity: 0.72),
            selectedText: NordColorToken(hex: "#FFFFFF"),
            accent: NordColorToken(hex: "#61AFEF"),
            secondaryAccent: NordColorToken(hex: "#56B6C2"),
            warning: NordColorToken(hex: "#E5C07B"),
            destructive: NordColorToken(hex: "#E06C75")
        ),
        terminalAppearance: TerminalAppearance(
            backgroundHex: "#282C34",
            foregroundHex: "#ABB2BF",
            cursorHex: "#528BFF",
            selectionHex: "#3E4451"
        )
    )

    public static let catppuccin = AppTheme(
        id: "catppuccin",
        displayName: "Catppuccin",
        colorScheme: .light,
        shellPalette: ShellThemePalette(
            shellBackground: NordColorToken(hex: "#EFF1F5"),
            sidebarBackground: NordColorToken(hex: "#E6E9EF"),
            contentBackground: NordColorToken(hex: "#F8F9FB"),
            elevatedBackground: NordColorToken(hex: "#FFFFFF"),
            tabBarBackground: NordColorToken(hex: "#DCE0E8"),
            activeBackground: NordColorToken(hex: "#1E66F5"),
            activeBorder: NordColorToken(hex: "#8839EF"),
            border: NordColorToken(hex: "#CCD0DA"),
            primaryText: NordColorToken(hex: "#4C4F69"),
            secondaryText: NordColorToken(hex: "#5C5F77"),
            mutedText: NordColorToken(hex: "#7C7F93", opacity: 0.74),
            selectedText: NordColorToken(hex: "#FFFFFF"),
            accent: NordColorToken(hex: "#1E66F5"),
            secondaryAccent: NordColorToken(hex: "#179299"),
            warning: NordColorToken(hex: "#DF8E1D"),
            destructive: NordColorToken(hex: "#D20F39")
        ),
        terminalAppearance: TerminalAppearance(
            backgroundHex: "#EFF1F5",
            foregroundHex: "#4C4F69",
            cursorHex: "#1E66F5",
            selectionHex: "#CCD0DA"
        )
    )

    public static let cursor = AppTheme(
        id: defaultID,
        displayName: "Cursor",
        colorScheme: .dark,
        shellPalette: ShellThemePalette(
            shellBackground: NordColorToken(hex: "#0D1117"),
            sidebarBackground: NordColorToken(hex: "#161B22"),
            contentBackground: NordColorToken(hex: "#0D1117"),
            elevatedBackground: NordColorToken(hex: "#1C2128"),
            tabBarBackground: NordColorToken(hex: "#161B22"),
            activeBackground: NordColorToken(hex: "#2F7CF6"),
            activeBorder: NordColorToken(hex: "#58A6FF"),
            border: NordColorToken(hex: "#30363D"),
            primaryText: NordColorToken(hex: "#E6EDF3"),
            secondaryText: NordColorToken(hex: "#C9D1D9"),
            mutedText: NordColorToken(hex: "#8B949E", opacity: 0.76),
            selectedText: NordColorToken(hex: "#FFFFFF"),
            accent: NordColorToken(hex: "#58A6FF"),
            secondaryAccent: NordColorToken(hex: "#3FB950"),
            warning: NordColorToken(hex: "#D29922"),
            destructive: NordColorToken(hex: "#F85149")
        ),
        terminalAppearance: .cursorDefault
    )

    public static let catalog: [AppTheme] = [
        dracula,
        oneDark,
        catppuccin,
        cursor
    ]

    public static let defaultTheme = cursor
    public static let supportedIDs: Set<String> = Set(catalog.map(\.id))

    public static func resolve(id: String?) -> AppTheme {
        guard let id,
              let theme = catalog.first(where: { $0.id == id })
        else {
            return defaultTheme
        }
        return theme
    }
}
