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
    public static let systemSelectionID = "system"
    public static let defaultSelectionID = systemSelectionID

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
        displayName: "Catppuccin Latte",
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

    public static let githubLight = AppTheme(
        id: "github-light",
        displayName: "GitHub Light",
        colorScheme: .light,
        shellPalette: ShellThemePalette(
            shellBackground: NordColorToken(hex: "#F6F8FA"),
            sidebarBackground: NordColorToken(hex: "#FFFFFF"),
            contentBackground: NordColorToken(hex: "#FFFFFF"),
            elevatedBackground: NordColorToken(hex: "#F6F8FA"),
            tabBarBackground: NordColorToken(hex: "#EAEEF2"),
            activeBackground: NordColorToken(hex: "#0969DA"),
            activeBorder: NordColorToken(hex: "#0969DA"),
            border: NordColorToken(hex: "#D0D7DE"),
            primaryText: NordColorToken(hex: "#24292F"),
            secondaryText: NordColorToken(hex: "#57606A"),
            mutedText: NordColorToken(hex: "#6E7781", opacity: 0.76),
            selectedText: NordColorToken(hex: "#FFFFFF"),
            accent: NordColorToken(hex: "#0969DA"),
            secondaryAccent: NordColorToken(hex: "#1A7F37"),
            warning: NordColorToken(hex: "#9A6700"),
            destructive: NordColorToken(hex: "#CF222E")
        ),
        terminalAppearance: TerminalAppearance(
            backgroundHex: "#FFFFFF",
            foregroundHex: "#24292F",
            cursorHex: "#0969DA",
            selectionHex: "#D0D7DE"
        )
    )

    public static let solarizedLight = AppTheme(
        id: "solarized-light",
        displayName: "Solarized Light",
        colorScheme: .light,
        shellPalette: ShellThemePalette(
            shellBackground: NordColorToken(hex: "#FDF6E3"),
            sidebarBackground: NordColorToken(hex: "#EEE8D5"),
            contentBackground: NordColorToken(hex: "#FDF6E3"),
            elevatedBackground: NordColorToken(hex: "#FFF8E8"),
            tabBarBackground: NordColorToken(hex: "#EEE8D5"),
            activeBackground: NordColorToken(hex: "#268BD2"),
            activeBorder: NordColorToken(hex: "#2AA198"),
            border: NordColorToken(hex: "#D6CEB8"),
            primaryText: NordColorToken(hex: "#586E75"),
            secondaryText: NordColorToken(hex: "#657B83"),
            mutedText: NordColorToken(hex: "#93A1A1", opacity: 0.76),
            selectedText: NordColorToken(hex: "#FDF6E3"),
            accent: NordColorToken(hex: "#268BD2"),
            secondaryAccent: NordColorToken(hex: "#2AA198"),
            warning: NordColorToken(hex: "#B58900"),
            destructive: NordColorToken(hex: "#DC322F")
        ),
        terminalAppearance: TerminalAppearance(
            backgroundHex: "#FDF6E3",
            foregroundHex: "#586E75",
            cursorHex: "#268BD2",
            selectionHex: "#EEE8D5"
        )
    )

    public static let catppuccinFrappe = AppTheme(
        id: "catppuccin-frappe",
        displayName: "Catppuccin Frappe",
        colorScheme: .dark,
        shellPalette: ShellThemePalette(
            shellBackground: NordColorToken(hex: "#303446"),
            sidebarBackground: NordColorToken(hex: "#292C3C"),
            contentBackground: NordColorToken(hex: "#303446"),
            elevatedBackground: NordColorToken(hex: "#3A3F55"),
            tabBarBackground: NordColorToken(hex: "#292C3C"),
            activeBackground: NordColorToken(hex: "#8CAAEE"),
            activeBorder: NordColorToken(hex: "#CA9EE6"),
            border: NordColorToken(hex: "#414559"),
            primaryText: NordColorToken(hex: "#C6D0F5"),
            secondaryText: NordColorToken(hex: "#B5BFE2"),
            mutedText: NordColorToken(hex: "#A5ADCE", opacity: 0.76),
            selectedText: NordColorToken(hex: "#FFFFFF"),
            accent: NordColorToken(hex: "#8CAAEE"),
            secondaryAccent: NordColorToken(hex: "#81C8BE"),
            warning: NordColorToken(hex: "#E5C890"),
            destructive: NordColorToken(hex: "#E78284")
        ),
        terminalAppearance: TerminalAppearance(
            backgroundHex: "#303446",
            foregroundHex: "#C6D0F5",
            cursorHex: "#8CAAEE",
            selectionHex: "#414559"
        )
    )

    public static let catppuccinMacchiato = AppTheme(
        id: "catppuccin-macchiato",
        displayName: "Catppuccin Macchiato",
        colorScheme: .dark,
        shellPalette: ShellThemePalette(
            shellBackground: NordColorToken(hex: "#24273A"),
            sidebarBackground: NordColorToken(hex: "#1E2030"),
            contentBackground: NordColorToken(hex: "#24273A"),
            elevatedBackground: NordColorToken(hex: "#2B2D42"),
            tabBarBackground: NordColorToken(hex: "#1E2030"),
            activeBackground: NordColorToken(hex: "#8AADF4"),
            activeBorder: NordColorToken(hex: "#C6A0F6"),
            border: NordColorToken(hex: "#494D64"),
            primaryText: NordColorToken(hex: "#CAD3F5"),
            secondaryText: NordColorToken(hex: "#B8C0E0"),
            mutedText: NordColorToken(hex: "#A5ADCB", opacity: 0.76),
            selectedText: NordColorToken(hex: "#FFFFFF"),
            accent: NordColorToken(hex: "#8AADF4"),
            secondaryAccent: NordColorToken(hex: "#8BD5CA"),
            warning: NordColorToken(hex: "#EED49F"),
            destructive: NordColorToken(hex: "#ED8796")
        ),
        terminalAppearance: TerminalAppearance(
            backgroundHex: "#24273A",
            foregroundHex: "#CAD3F5",
            cursorHex: "#8AADF4",
            selectionHex: "#494D64"
        )
    )

    public static let catppuccinMocha = AppTheme(
        id: "catppuccin-mocha",
        displayName: "Catppuccin Mocha",
        colorScheme: .dark,
        shellPalette: ShellThemePalette(
            shellBackground: NordColorToken(hex: "#1E1E2E"),
            sidebarBackground: NordColorToken(hex: "#181825"),
            contentBackground: NordColorToken(hex: "#1E1E2E"),
            elevatedBackground: NordColorToken(hex: "#313244"),
            tabBarBackground: NordColorToken(hex: "#181825"),
            activeBackground: NordColorToken(hex: "#89B4FA"),
            activeBorder: NordColorToken(hex: "#CBA6F7"),
            border: NordColorToken(hex: "#45475A"),
            primaryText: NordColorToken(hex: "#CDD6F4"),
            secondaryText: NordColorToken(hex: "#BAC2DE"),
            mutedText: NordColorToken(hex: "#A6ADC8", opacity: 0.76),
            selectedText: NordColorToken(hex: "#FFFFFF"),
            accent: NordColorToken(hex: "#89B4FA"),
            secondaryAccent: NordColorToken(hex: "#94E2D5"),
            warning: NordColorToken(hex: "#F9E2AF"),
            destructive: NordColorToken(hex: "#F38BA8")
        ),
        terminalAppearance: TerminalAppearance(
            backgroundHex: "#1E1E2E",
            foregroundHex: "#CDD6F4",
            cursorHex: "#89B4FA",
            selectionHex: "#45475A"
        )
    )

    public static let nord = AppTheme(
        id: "nord",
        displayName: "Nord",
        colorScheme: .dark,
        shellPalette: ShellThemePalette(
            shellBackground: NordColorToken(hex: "#2E3440"),
            sidebarBackground: NordColorToken(hex: "#242933"),
            contentBackground: NordColorToken(hex: "#2E3440"),
            elevatedBackground: NordColorToken(hex: "#3B4252"),
            tabBarBackground: NordColorToken(hex: "#242933"),
            activeBackground: NordColorToken(hex: "#5E81AC"),
            activeBorder: NordColorToken(hex: "#88C0D0"),
            border: NordColorToken(hex: "#4C566A"),
            primaryText: NordColorToken(hex: "#ECEFF4"),
            secondaryText: NordColorToken(hex: "#E5E9F0"),
            mutedText: NordColorToken(hex: "#D8DEE9", opacity: 0.72),
            selectedText: NordColorToken(hex: "#FFFFFF"),
            accent: NordColorToken(hex: "#88C0D0"),
            secondaryAccent: NordColorToken(hex: "#81A1C1"),
            warning: NordColorToken(hex: "#EBCB8B"),
            destructive: NordColorToken(hex: "#BF616A")
        ),
        terminalAppearance: TerminalAppearance(
            backgroundHex: "#2E3440",
            foregroundHex: "#ECEFF4",
            cursorHex: "#88C0D0",
            selectionHex: "#4C566A"
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

    /// Catalog order is a runtime contract for System selection:
    /// the first light preset resolves System in light mode, and the first dark preset resolves System in dark mode.
    public static let catalog: [AppTheme] = [
        catppuccin,
        githubLight,
        solarizedLight,
        dracula,
        oneDark,
        catppuccinFrappe,
        catppuccinMacchiato,
        catppuccinMocha,
        nord,
        cursor
    ]

    public static let defaultTheme = cursor
    public static let supportedIDs: Set<String> = Set(catalog.map(\.id))
    public static let orderedSelectionIDs: [String] = [systemSelectionID] + catalog.map(\.id)
    public static let supportedSelectionIDs: Set<String> = Set(orderedSelectionIDs)

    public static var firstLightPreset: AppTheme {
        guard let theme = catalog.first(where: { $0.colorScheme == .light }) else {
            preconditionFailure("AppTheme.catalog must contain at least one light preset")
        }
        return theme
    }

    public static var firstDarkPreset: AppTheme {
        guard let theme = catalog.first(where: { $0.colorScheme == .dark }) else {
            preconditionFailure("AppTheme.catalog must contain at least one dark preset")
        }
        return theme
    }

    public static func isSupportedSelectionID(_ id: String) -> Bool {
        supportedSelectionIDs.contains(id)
    }

    public static func resolve(id: String?) -> AppTheme {
        guard let id,
              let theme = catalog.first(where: { $0.id == id })
        else {
            return defaultTheme
        }
        return theme
    }

    public static func resolveEffective(selectionID: String?, systemScheme: ThemeColorScheme) -> AppTheme {
        guard let selectionID,
              selectionID != systemSelectionID,
              let theme = catalog.first(where: { $0.id == selectionID })
        else {
            return systemPreset(for: systemScheme)
        }
        return theme
    }

    private static func systemPreset(for scheme: ThemeColorScheme) -> AppTheme {
        switch scheme {
        case .light:
            return firstLightPreset
        case .dark:
            return firstDarkPreset
        }
    }
}
