import Testing
@testable import NativeMacADECore

struct ThemeSelectionContractIntegrationTests {
    @Test
    func concretePresetIDsStillResolveToCatalogInstancesAfterExpansion() {
        let expectedThemes: [(String, AppTheme)] = [
            ("catppuccin", .catppuccin),
            ("github-light", .githubLight),
            ("solarized-light", .solarizedLight),
            ("dracula", .dracula),
            ("onedark", .oneDark),
            ("catppuccin-frappe", .catppuccinFrappe),
            ("catppuccin-macchiato", .catppuccinMacchiato),
            ("catppuccin-mocha", .catppuccinMocha),
            ("nord", .nord),
            ("cursor", .cursor)
        ]

        #expect(AppTheme.catalog.map(\.id) == expectedThemes.map(\.0))
        for (id, expectedTheme) in expectedThemes {
            #expect(AppTheme.resolve(id: id) == expectedTheme)
            #expect(AppTheme.resolveEffective(selectionID: id, systemScheme: .light) == expectedTheme)
            #expect(AppTheme.resolveEffective(selectionID: id, systemScheme: .dark) == expectedTheme)
        }
    }

    @Test
    func curatedCatalogOrderDrivesSystemLightAndDarkFallbacks() {
        #expect(AppTheme.firstLightPreset.id == "catppuccin")
        #expect(AppTheme.firstDarkPreset.id == "dracula")
        #expect(AppTheme.catalog.first { $0.colorScheme == .light } == AppTheme.firstLightPreset)
        #expect(AppTheme.catalog.first { $0.colorScheme == .dark } == AppTheme.firstDarkPreset)
        #expect(AppTheme.resolveEffective(selectionID: AppTheme.systemSelectionID, systemScheme: .light) == .catppuccin)
        #expect(AppTheme.resolveEffective(selectionID: AppTheme.systemSelectionID, systemScheme: .dark) == .dracula)
    }
}
