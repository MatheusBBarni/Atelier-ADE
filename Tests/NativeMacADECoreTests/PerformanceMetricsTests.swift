import Foundation
import Testing
@testable import NativeMacADECore

@MainActor
struct PerformanceMetricsTests {
    @Test
    func pilotDiagnosticsUsesLaunchToReadyDurationsNotTabCreationDurations() {
        let metrics = PerformanceMetrics()

        metrics.recordTabCreation(duration: 100)
        metrics.recordLaunchToReady(duration: 2)

        let diagnostics = metrics.diagnostics(launchToReadyBudget: 10)

        #expect(diagnostics.medianLaunchToReadySeconds == 2)
        #expect(diagnostics.releaseBlockingReasons.contains("median launch-to-ready time above budget") == false)
    }

    @Test
    func settingsCountersTrackOpenedSavedFailuresThemeAndKeybindingChanges() {
        let metrics = PerformanceMetrics()

        metrics.recordSettingsOpened()
        metrics.recordSettingsSaved(changedKeybindingCount: 3)
        metrics.recordSettingsSaveFailure()
        metrics.recordThemeChanged()
        metrics.recordKeybindingsChanged(changedCommandCount: 3)

        #expect(metrics.settingsOpenedCount == 1)
        #expect(metrics.settingsSavedCount == 1)
        #expect(metrics.settingsSaveFailureCount == 1)
        #expect(metrics.themeChangedCount == 1)
        #expect(metrics.keybindingChangedCount == 3)
        #expect(metrics.lastSavedChangedKeybindingCount == 3)
    }

    @Test
    func fileWorkflowCountersRollIntoPilotDiagnostics() {
        let metrics = PerformanceMetrics()

        metrics.recordFileOpen(duration: 6)
        metrics.recordFileSave(succeeded: true)
        metrics.recordFileSave(succeeded: false)
        metrics.recordFileRevert(succeeded: true)
        metrics.recordFileRevert(succeeded: false)
        metrics.recordFileRestoreFailure()
        metrics.recordDirtyFileCloseDecision(accepted: true)
        metrics.recordDirtyFileCloseDecision(accepted: false)
        metrics.recordExternalEditorEscalation()

        let diagnostics = metrics.diagnostics(fileOpenBudget: 5)

        #expect(metrics.fileOpenDurations == [6])
        #expect(metrics.fileSaveSuccessCount == 1)
        #expect(metrics.fileSaveFailureCount == 1)
        #expect(metrics.fileRevertSuccessCount == 1)
        #expect(metrics.fileRevertFailureCount == 1)
        #expect(diagnostics.fileSaveFailureRate == 0.5)
        #expect(diagnostics.medianFileOpenSeconds == 6)
        #expect(diagnostics.fileRestoreFailureCount == 1)
        #expect(diagnostics.dirtyFileCloseConfirmationAcceptCount == 1)
        #expect(diagnostics.dirtyFileCloseConfirmationRejectCount == 1)
        #expect(diagnostics.externalEditorEscalationCount == 1)
        #expect(diagnostics.releaseBlockingReasons.contains("file-save failure rate above 1%"))
        #expect(diagnostics.releaseBlockingReasons.contains("file-tab restore failures detected"))
        #expect(diagnostics.releaseBlockingReasons.contains("median file-open time above budget"))
    }
}
