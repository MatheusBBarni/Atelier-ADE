import Testing
@testable import NativeMacADECore

@MainActor
struct AppThemeTests {
    @Test
    func knownThemeIDsResolveToExpectedCatalogEntries() {
        #expect(AppTheme.resolve(id: "dracula") == .dracula)
        #expect(AppTheme.resolve(id: "onedark") == .oneDark)
        #expect(AppTheme.resolve(id: "catppuccin") == .catppuccin)
        #expect(AppTheme.resolve(id: "github-light") == .githubLight)
        #expect(AppTheme.resolve(id: "solarized-light") == .solarizedLight)
        #expect(AppTheme.resolve(id: "catppuccin-frappe") == .catppuccinFrappe)
        #expect(AppTheme.resolve(id: "catppuccin-macchiato") == .catppuccinMacchiato)
        #expect(AppTheme.resolve(id: "catppuccin-mocha") == .catppuccinMocha)
        #expect(AppTheme.resolve(id: "nord") == .nord)
        #expect(AppTheme.resolve(id: "cursor") == .cursor)
    }

    @Test
    func concreteThemeLookupFallsBackToCursorDefault() {
        #expect(AppTheme.resolve(id: nil) == .cursor)
        #expect(AppTheme.resolve(id: "missing-theme") == .cursor)
        #expect(AppTheme.resolve(id: AppTheme.systemSelectionID) == .cursor)
        #expect(AppTheme.defaultTheme == .cursor)
    }

    @Test
    func effectiveThemeResolverKeepsConcreteSelectionsIndependentOfSystemScheme() {
        #expect(AppTheme.resolveEffective(selectionID: "catppuccin", systemScheme: .dark) == .catppuccin)
        #expect(AppTheme.resolveEffective(selectionID: "catppuccin", systemScheme: .light) == .catppuccin)
        #expect(AppTheme.resolveEffective(selectionID: "github-light", systemScheme: .dark) == .githubLight)
        #expect(AppTheme.resolveEffective(selectionID: "dracula", systemScheme: .light) == .dracula)
        #expect(AppTheme.resolveEffective(selectionID: "dracula", systemScheme: .dark) == .dracula)
    }

    @Test
    func systemSelectionResolvesToFirstPresetForRuntimeScheme() {
        #expect(AppTheme.resolveEffective(selectionID: AppTheme.systemSelectionID, systemScheme: .light) == AppTheme.firstLightPreset)
        #expect(AppTheme.resolveEffective(selectionID: AppTheme.systemSelectionID, systemScheme: .dark) == AppTheme.firstDarkPreset)
        #expect(AppTheme.resolveEffective(selectionID: nil, systemScheme: .light) == AppTheme.firstLightPreset)
        #expect(AppTheme.resolveEffective(selectionID: "missing-theme", systemScheme: .dark) == AppTheme.firstDarkPreset)
    }

    @Test
    func supportedSelectionIDsIncludeSystemAndConcreteCatalogWithoutDuplicates() {
        let concreteIDs = AppTheme.catalog.map(\.id)
        let expectedSelectionIDs = [AppTheme.systemSelectionID] + concreteIDs

        #expect(Set(concreteIDs).count == concreteIDs.count)
        #expect(Set(expectedSelectionIDs).count == expectedSelectionIDs.count)
        #expect(AppTheme.orderedSelectionIDs == expectedSelectionIDs)
        #expect(AppTheme.supportedIDs == Set(concreteIDs))
        #expect(AppTheme.supportedSelectionIDs == Set(expectedSelectionIDs))
        #expect(AppTheme.supportedSelectionIDs.count == AppTheme.catalog.count + 1)
        #expect(AppTheme.isSupportedSelectionID(AppTheme.systemSelectionID))
        #expect(AppTheme.isSupportedSelectionID("catppuccin"))
        #expect(!AppTheme.isSupportedSelectionID("missing-theme"))
    }

    @Test
    func curatedCatalogOrderDefinesSystemFallbackPresets() {
        #expect(AppTheme.catalog.map(\.id) == [
            "catppuccin",
            "github-light",
            "solarized-light",
            "dracula",
            "onedark",
            "catppuccin-frappe",
            "catppuccin-macchiato",
            "catppuccin-mocha",
            "nord",
            "cursor"
        ])
        #expect(AppTheme.firstLightPreset == .catppuccin)
        #expect(AppTheme.firstDarkPreset == .dracula)
        #expect(AppTheme.firstLightPreset.colorScheme == .light)
        #expect(AppTheme.firstDarkPreset.colorScheme == .dark)
    }

    @Test
    func workspaceStoreActiveThemeTracksPersistedPreferenceID() {
        let store = WorkspaceStore(appPreferences: AppPreferences(themeID: "catppuccin"))

        #expect(store.activeTheme.id == "catppuccin")
        #expect(store.activeTheme.colorScheme == .light)

        store.updateAppPreferences(AppPreferences(themeID: "dracula"))

        #expect(store.activeTheme.id == "dracula")
        #expect(store.activeTheme.colorScheme == .dark)
    }

    @Test
    func activeThemeUpdatesShellAndTerminalPaletteValues() {
        let store = WorkspaceStore(appPreferences: AppPreferences(themeID: "cursor"))
        let cursorTheme = store.activeTheme

        store.updateAppPreferences(AppPreferences(themeID: "catppuccin"))
        let catppuccinTheme = store.activeTheme

        #expect(cursorTheme.shellPalette.shellBackground.hex != catppuccinTheme.shellPalette.shellBackground.hex)
        #expect(cursorTheme.shellPalette.primaryText.hex != catppuccinTheme.shellPalette.primaryText.hex)
        #expect(cursorTheme.terminalAppearance.cursorHex != catppuccinTheme.terminalAppearance.cursorHex)
        #expect(catppuccinTheme.terminalAppearance.backgroundHex == "#EFF1F5")
        #expect(catppuccinTheme.terminalAppearance.foregroundHex == "#4C4F69")
        #expect(catppuccinTheme.terminalAppearance.cursorHex == "#1E66F5")

        let nordTheme = AppTheme.resolve(id: "nord")
        #expect(nordTheme.colorScheme == .dark)
        #expect(nordTheme.terminalAppearance.backgroundHex == "#2E3440")
    }
}
