import Testing
@testable import NativeMacADECore

@MainActor
struct AppThemeTests {
    @Test
    func knownThemeIDsResolveToExpectedCatalogEntries() {
        #expect(AppTheme.resolve(id: "dracula") == .dracula)
        #expect(AppTheme.resolve(id: "onedark") == .oneDark)
        #expect(AppTheme.resolve(id: "catppuccin") == .catppuccin)
        #expect(AppTheme.resolve(id: "cursor") == .cursor)
    }

    @Test
    func unknownThemeIDsFallBackToCursorDefault() {
        #expect(AppTheme.resolve(id: nil) == .cursor)
        #expect(AppTheme.resolve(id: "nord") == .cursor)
        #expect(AppPreferences.defaultThemeID == "cursor")
        #expect(AppPreferences.supportedThemeIDs == ["dracula", "onedark", "catppuccin", "cursor"])
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
    }
}
