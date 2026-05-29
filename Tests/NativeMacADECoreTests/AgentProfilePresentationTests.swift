import Foundation
import Testing
@testable import NativeMacADECore

struct AgentProfilePresentationTests {
    @Test
    func rowStatesIdentifyBuiltInCustomizedAndCustomActions() {
        let builtIn = SessionShortcut(
            id: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
            label: "Codex",
            launchCommand: "codex",
            isBuiltIn: true
        )
        let customizedBuiltIn = SessionShortcut(
            id: UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!,
            label: "Claude Review",
            launchCommand: "claude",
            launchArgumentsJSON: "[\"--continue\"]",
            isBuiltIn: true,
            hasUserOverride: true
        )
        let custom = SessionShortcut(
            id: UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!,
            label: "Local Tool",
            launchCommand: "local-agent"
        )

        let rows = AgentProfileSectionState.rows(
            for: [builtIn, customizedBuiltIn, custom],
            defaultSessionShortcutID: custom.id
        )

        #expect(rows[0].provenance == .builtIn)
        #expect(rows[0].provenance.title == "Built-in")
        #expect(rows[0].canEdit)
        #expect(rows[0].canReset)
        #expect(rows[0].canDelete == false)
        #expect(rows[0].canMakeDefault)
        #expect(rows[0].isDefault == false)

        #expect(rows[1].provenance == .customizedBuiltIn)
        #expect(rows[1].provenance.title == "Customized built-in")
        #expect(rows[1].canEdit)
        #expect(rows[1].canReset)
        #expect(rows[1].canDelete == false)

        #expect(rows[2].provenance == .custom)
        #expect(rows[2].provenance.title == "Custom")
        #expect(rows[2].canEdit)
        #expect(rows[2].canReset == false)
        #expect(rows[2].canDelete)
        #expect(rows[2].canMakeDefault == false)
        #expect(rows[2].isDefault)
    }

    @Test
    func staleDefaultIDReportsMissingPreferenceReference() {
        let presentProfile = SessionShortcut(label: "Codex", launchCommand: "codex")
        let staleProfileID = UUID()

        let preferences = AppPreferences(defaultSessionShortcutID: staleProfileID)

        #expect(AgentProfileSectionState.staleDefaultID(in: preferences, profiles: [presentProfile]) == staleProfileID)
        #expect(AgentProfileSectionState.staleDefaultID(
            in: AppPreferences(defaultSessionShortcutID: presentProfile.id),
            profiles: [presentProfile]
        ) == nil)
        #expect(AgentProfileSectionState.staleDefaultID(in: .defaults, profiles: [presentProfile]) == nil)
    }
}
