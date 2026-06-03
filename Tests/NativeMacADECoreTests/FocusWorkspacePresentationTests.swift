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
        #expect(FocusWorkspaceSettingsPresentation.continuityToggleTitle == "Enable continuity")
        #expect(FocusWorkspaceSettingsPresentation.summary.contains("one terminal tab"))
        #expect(FocusWorkspaceSettingsPresentation.summary.contains("one optional file tab"))
        #expect(FocusWorkspaceSettingsPresentation.behaviorDetail.contains("Future terminal-tab actions"))
        #expect(FocusWorkspaceSettingsPresentation.fileDetail.contains("one file tab"))
        #expect(FocusWorkspaceSettingsPresentation.continuityHelpText.contains("app-owned project, session, and tab context only"))
        #expect(FocusWorkspaceSettingsPresentation.continuityHelpText.contains("saved launch intent"))
        #expect(FocusWorkspaceSettingsPresentation.continuityHelpText.contains("does not reconnect to live tmux panes"))
        #expect(FocusWorkspaceSettingsPresentation.continuityHelpText.contains("external terminal processes"))
        #expect(FocusWorkspaceSettingsPresentation.legacyDetail.contains("Existing multi-tab sessions stay intact"))
        #expect(FocusWorkspaceSettingsPresentation.legacyDetail.contains("new actions"))
    }

    @Test
    func settingsPresentationNormalizesContinuityAsFocusWorkspaceChildState() {
        let unavailablePresentation = FocusWorkspaceSettingsPresentation(
            preferences: AppPreferences(
                focusWorkspaceEnabled: false,
                focusWorkspaceContinuityEnabled: true
            )
        )
        let availablePresentation = FocusWorkspaceSettingsPresentation(
            preferences: AppPreferences(focusWorkspaceEnabled: true)
        )
        let enabledPresentation = FocusWorkspaceSettingsPresentation(
            preferences: AppPreferences(
                focusWorkspaceEnabled: true,
                focusWorkspaceContinuityEnabled: true
            )
        )

        #expect(unavailablePresentation.isEnabled == false)
        #expect(unavailablePresentation.isContinuityAvailable == false)
        #expect(unavailablePresentation.isContinuityEnabled == false)
        #expect(unavailablePresentation.continuityStatus == FocusWorkspaceSettingsPresentation.continuityUnavailableStatus)
        #expect(availablePresentation.isContinuityAvailable)
        #expect(availablePresentation.isContinuityEnabled == false)
        #expect(availablePresentation.continuityStatus == FocusWorkspaceSettingsPresentation.continuityDisabledStatus)
        #expect(enabledPresentation.isContinuityAvailable)
        #expect(enabledPresentation.isContinuityEnabled)
        #expect(enabledPresentation.continuityStatus == FocusWorkspaceSettingsPresentation.continuityEnabledStatus)
    }

    @Test
    func activeCueVisibilityFollowsPreferenceAndUsesBoundedLanguage() {
        let disabledCue = FocusWorkspaceActiveCuePresentation(preferences: .defaults)
        let enabledCue = FocusWorkspaceActiveCuePresentation(
            preferences: AppPreferences(focusWorkspaceEnabled: true)
        )

        #expect(disabledCue.isVisible == false)
        #expect(enabledCue.isVisible)
        #expect(enabledCue.isContinuityEnabled == false)
        #expect(enabledCue.labelText == FocusWorkspaceActiveCuePresentation.label)
        #expect(enabledCue.accessibilityLabelText == FocusWorkspaceActiveCuePresentation.accessibilityLabel)
        #expect(enabledCue.activeHelpText == FocusWorkspaceActiveCuePresentation.helpText)
        #expect(FocusWorkspaceActiveCuePresentation.label == "Focus Workspace")
        #expect(FocusWorkspaceActiveCuePresentation.accessibilityLabel == "Focus Workspace active")
        #expect(FocusWorkspaceActiveCuePresentation.helpText.contains("Future actions"))
        #expect(FocusWorkspaceActiveCuePresentation.helpText.contains("one terminal tab plus one optional file tab"))
        #expect(FocusWorkspaceActiveCuePresentation.helpText.contains("existing multi-tab sessions are preserved"))
    }

    @Test
    func activeCueUsesContinuityWordingWithoutExternalReattachmentClaims() {
        let cue = FocusWorkspaceActiveCuePresentation(
            preferences: AppPreferences(
                focusWorkspaceEnabled: true,
                focusWorkspaceContinuityEnabled: true
            )
        )

        #expect(cue.isVisible)
        #expect(cue.isContinuityEnabled)
        #expect(cue.labelText == FocusWorkspaceActiveCuePresentation.continuityLabel)
        #expect(cue.accessibilityLabelText == FocusWorkspaceActiveCuePresentation.continuityAccessibilityLabel)
        #expect(cue.activeHelpText == FocusWorkspaceActiveCuePresentation.continuityHelpText)
        #expect(cue.activeHelpText.contains("remembered app-owned project, session, and terminal tab context"))
        #expect(cue.activeHelpText.contains("saved launch intent"))
        #expect(cue.activeHelpText.contains("does not reattach to live tmux panes"))
        #expect(cue.activeHelpText.contains("external processes"))
        #expect(cue.activeHelpText.contains("session search"))
        #expect(cue.activeHelpText.contains("session list"))
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
