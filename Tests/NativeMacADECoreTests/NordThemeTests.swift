import Testing
@testable import NativeMacADECore

// Suite: Nord theme token defaults
// Invariant: default shell, sidebar, and active theme tokens stay on their expected Nord palette hex values.
// Boundary IN: NordTheme token aliases and NordColorToken hex normalization.
// Boundary OUT: SwiftUI color rendering in app targets.
struct NordThemeTests {
    @Test
    func defaultShellSidebarAndActiveTokensUseExpectedHexValues() {
        #expect(NordTheme.shellBackground.hex == "#2E3440")
        #expect(NordTheme.sidebarBackground.hex == "#3B4252")
        #expect(NordTheme.activeBackground.hex == "#5E81AC")
        #expect(NordTheme.activeBorder.hex == "#88C0D0")
    }
}
