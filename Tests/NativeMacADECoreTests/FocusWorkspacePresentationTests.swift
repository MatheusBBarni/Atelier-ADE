import Foundation
import Testing
@testable import NativeMacADECore

struct FocusWorkspacePresentationTests {
    @Test
    func settingsPresentationExposesDedicatedTruthfulCopyAndPersistedToggleState() {
        let disabledPresentation = FocusWorkspaceSettingsPresentation(preferences: .defaults)
        let enabledPresentation = FocusWorkspaceSettingsPresentation(
            preferences: AppPreferences(focusWorkspaceEnabled: true)
        )

        #expect(disabledPresentation.isEnabled == false)
        #expect(disabledPresentation.status == FocusWorkspaceSettingsPresentation.disabledStatus)
        #expect(enabledPresentation.isEnabled)
        #expect(enabledPresentation.status == FocusWorkspaceSettingsPresentation.enabledStatus)
        #expect(FocusWorkspaceSettingsPresentation.title == "Focus Workspace")
        #expect(FocusWorkspaceSettingsPresentation.toggleTitle == "Enable Focus Workspace")
        #expect(FocusWorkspaceSettingsPresentation.summary.contains("one terminal tab"))
        #expect(FocusWorkspaceSettingsPresentation.summary.contains("one optional file tab"))
        #expect(FocusWorkspaceSettingsPresentation.behaviorDetail.contains("Future terminal-tab actions"))
        #expect(FocusWorkspaceSettingsPresentation.fileDetail.contains("one file tab"))
        #expect(FocusWorkspaceSettingsPresentation.legacyDetail.contains("Existing multi-tab sessions stay intact"))
        #expect(FocusWorkspaceSettingsPresentation.legacyDetail.contains("new actions"))
    }

    @Test
    func activeCueVisibilityFollowsPreferenceAndUsesBoundedLanguage() {
        let disabledCue = FocusWorkspaceActiveCuePresentation(preferences: .defaults)
        let enabledCue = FocusWorkspaceActiveCuePresentation(
            preferences: AppPreferences(focusWorkspaceEnabled: true)
        )

        #expect(disabledCue.isVisible == false)
        #expect(enabledCue.isVisible)
        #expect(FocusWorkspaceActiveCuePresentation.label == "Focus Workspace")
        #expect(FocusWorkspaceActiveCuePresentation.accessibilityLabel == "Focus Workspace active")
        #expect(FocusWorkspaceActiveCuePresentation.helpText.contains("Future actions"))
        #expect(FocusWorkspaceActiveCuePresentation.helpText.contains("one terminal tab plus one optional file tab"))
        #expect(FocusWorkspaceActiveCuePresentation.helpText.contains("existing multi-tab sessions are preserved"))
    }

    @Test
    func blockedTerminalCreationPresentationUsesCalmFeatureSpecificCopy() {
        let presentation = FocusWorkspaceBlockedActionPresentation(
            violation: .additionalTerminalTabBlocked
        )
        let errorPresentation = FocusWorkspaceBlockedActionPresentation(
            error: .focusWorkspaceRejected(.additionalTerminalTabBlocked)
        )

        #expect(presentation.title == "Focus Workspace kept this session focused")
        #expect(presentation.detail.contains("already has a terminal tab"))
        #expect(presentation.detail.contains("turn off Focus Workspace in Settings"))
        #expect(errorPresentation == presentation)
    }

    @Test
    func blockedDifferentFilePresentationUsesCalmFeatureSpecificCopy() {
        let presentation = FocusWorkspaceBlockedActionPresentation(
            violation: .additionalFileTabBlocked
        )
        let errorPresentation = FocusWorkspaceBlockedActionPresentation(
            error: .focusWorkspaceRejected(.additionalFileTabBlocked)
        )

        #expect(presentation.title == "Focus Workspace kept this file slot focused")
        #expect(presentation.detail.contains("already has a file tab"))
        #expect(presentation.detail.contains("Reopen that file"))
        #expect(presentation.detail.contains("opening a different file"))
        #expect(errorPresentation == presentation)
    }

    @Test
    func blockedPresentationIgnoresNonFocusCommandErrors() {
        #expect(FocusWorkspaceBlockedActionPresentation(error: .missingSession(UUID())) == nil)
    }
}
