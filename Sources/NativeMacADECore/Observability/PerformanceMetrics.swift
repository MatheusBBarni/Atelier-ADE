import Foundation

public struct PilotDiagnostics: Equatable, Sendable {
    public var restoreFailureRate: Double
    public var terminalSurfaceFailureRate: Double
    public var fileSaveFailureRate: Double
    public var medianLaunchToReadySeconds: Double?
    public var medianFileOpenSeconds: Double?
    public var fileRestoreFailureCount: Int
    public var dirtyFileCloseConfirmationAcceptCount: Int
    public var dirtyFileCloseConfirmationRejectCount: Int
    public var externalEditorEscalationCount: Int
    public var projectReorderCount: Int = 0
    public var tabReorderCount: Int = 0
    public var reorderValidationRejectionCount: Int = 0
    public var reorderPersistenceFailureCount: Int = 0
    public var restoreOrderMismatchCount: Int = 0
    public var focusWorkspaceEnableCount: Int = 0
    public var focusWorkspaceDisableCount: Int = 0
    public var focusWorkspaceBlockedTerminalTabCount: Int = 0
    public var focusWorkspaceBlockedFileTabCount: Int = 0
    public var releaseBlockingReasons: [String]
}

@MainActor
public final class PerformanceMetrics {
    public private(set) var projectOpenDurations: [TimeInterval] = []
    public private(set) var launchToReadyDurations: [TimeInterval] = []
    public private(set) var tabCreationDurations: [TimeInterval] = []
    public private(set) var fileOpenDurations: [TimeInterval] = []
    public private(set) var restoreDurations: [TimeInterval] = []
    public private(set) var restoreSuccessCount = 0
    public private(set) var restoreFailureCount = 0
    public private(set) var sessionCreateCount = 0
    public private(set) var terminalSurfaceFailureCount = 0
    public private(set) var terminalSurfaceCreationCount = 0
    public private(set) var terminalProcessExitCount = 0
    public private(set) var closeConfirmationAcceptCount = 0
    public private(set) var closeConfirmationRejectCount = 0
    public private(set) var fileSaveSuccessCount = 0
    public private(set) var fileSaveFailureCount = 0
    public private(set) var fileRevertSuccessCount = 0
    public private(set) var fileRevertFailureCount = 0
    public private(set) var fileRestoreFailureCount = 0
    public private(set) var dirtyFileCloseConfirmationAcceptCount = 0
    public private(set) var dirtyFileCloseConfirmationRejectCount = 0
    public private(set) var externalEditorEscalationCount = 0
    public private(set) var projectReorderCount = 0
    public private(set) var tabReorderCount = 0
    public private(set) var reorderValidationRejectionCount = 0
    public private(set) var reorderPersistenceFailureCount = 0
    public private(set) var restoreOrderMismatchCount = 0
    public private(set) var inaccessibleRestoredProjectCount = 0
    public private(set) var settingsOpenedCount = 0
    public private(set) var settingsSavedCount = 0
    public private(set) var settingsSaveFailureCount = 0
    public private(set) var themeChangedCount = 0
    public private(set) var effectiveThemeAppliedCount = 0
    public private(set) var themeRepairCount = 0
    public private(set) var keybindingChangedCount = 0
    public private(set) var lastSavedChangedKeybindingCount = 0
    public private(set) var focusWorkspaceEnableCount = 0
    public private(set) var focusWorkspaceDisableCount = 0
    public private(set) var focusWorkspaceBlockedTerminalTabCount = 0
    public private(set) var focusWorkspaceBlockedFileTabCount = 0

    public init() {}

    public func recordProjectOpen(duration: TimeInterval) {
        projectOpenDurations.append(duration)
    }

    public func recordLaunchToReady(duration: TimeInterval) {
        launchToReadyDurations.append(duration)
    }

    public func recordSessionCreate() {
        sessionCreateCount += 1
    }

    public func recordTabCreation(duration: TimeInterval) {
        terminalSurfaceCreationCount += 1
        tabCreationDurations.append(duration)
    }

    public func recordFileOpen(duration: TimeInterval) {
        fileOpenDurations.append(duration)
    }

    public func recordTerminalSurfaceFailure() {
        terminalSurfaceFailureCount += 1
    }

    public func recordRestore(duration: TimeInterval, succeeded: Bool, skippedProjectCount: Int) {
        restoreDurations.append(duration)
        if succeeded {
            restoreSuccessCount += 1
        } else {
            restoreFailureCount += 1
        }
        inaccessibleRestoredProjectCount += skippedProjectCount
    }

    public func recordCloseConfirmation(accepted: Bool) {
        if accepted {
            closeConfirmationAcceptCount += 1
        } else {
            closeConfirmationRejectCount += 1
        }
    }

    public func recordFileSave(succeeded: Bool) {
        if succeeded {
            fileSaveSuccessCount += 1
        } else {
            fileSaveFailureCount += 1
        }
    }

    public func recordFileRevert(succeeded: Bool) {
        if succeeded {
            fileRevertSuccessCount += 1
        } else {
            fileRevertFailureCount += 1
        }
    }

    public func recordFileRestoreFailure() {
        fileRestoreFailureCount += 1
    }

    public func recordDirtyFileCloseDecision(accepted: Bool) {
        if accepted {
            dirtyFileCloseConfirmationAcceptCount += 1
        } else {
            dirtyFileCloseConfirmationRejectCount += 1
        }
    }

    public func recordExternalEditorEscalation() {
        externalEditorEscalationCount += 1
    }

    public func recordProjectReorder() {
        projectReorderCount += 1
    }

    public func recordTabReorder() {
        tabReorderCount += 1
    }

    public func recordReorderValidationRejection() {
        reorderValidationRejectionCount += 1
    }

    public func recordReorderPersistenceFailure() {
        reorderPersistenceFailureCount += 1
    }

    public func recordRestoreOrderMismatch() {
        restoreOrderMismatchCount += 1
    }

    public func recordTerminalProcessExit() {
        terminalProcessExitCount += 1
    }

    public func recordSettingsOpened() {
        settingsOpenedCount += 1
    }

    public func recordSettingsSaved(changedKeybindingCount: Int) {
        settingsSavedCount += 1
        lastSavedChangedKeybindingCount = changedKeybindingCount
    }

    public func recordSettingsSaveFailure() {
        settingsSaveFailureCount += 1
    }

    public func recordThemeChanged() {
        themeChangedCount += 1
    }

    public func recordEffectiveThemeApplied() {
        effectiveThemeAppliedCount += 1
    }

    public func recordThemeRepair() {
        themeRepairCount += 1
    }

    public func recordKeybindingsChanged(changedCommandCount: Int) {
        keybindingChangedCount += changedCommandCount
    }

    public func recordFocusWorkspaceEnabled() {
        focusWorkspaceEnableCount += 1
    }

    public func recordFocusWorkspaceDisabled() {
        focusWorkspaceDisableCount += 1
    }

    public func recordFocusWorkspaceBlocked(_ violation: FocusWorkspaceViolation) {
        switch violation {
        case .additionalTerminalTabBlocked:
            focusWorkspaceBlockedTerminalTabCount += 1
        case .additionalFileTabBlocked:
            focusWorkspaceBlockedFileTabCount += 1
        }
    }

    public func diagnostics(
        launchToReadyBudget: TimeInterval = 10,
        fileOpenBudget: TimeInterval = 5
    ) -> PilotDiagnostics {
        let restoreAttempts = restoreSuccessCount + restoreFailureCount
        let restoreFailureRate = restoreAttempts == 0 ? 0 : Double(restoreFailureCount) / Double(restoreAttempts)
        let terminalAttempts = terminalSurfaceCreationCount + terminalSurfaceFailureCount
        let terminalFailureRate = terminalAttempts == 0 ? 0 : Double(terminalSurfaceFailureCount) / Double(terminalAttempts)
        let fileSaveAttempts = fileSaveSuccessCount + fileSaveFailureCount
        let fileSaveFailureRate = fileSaveAttempts == 0 ? 0 : Double(fileSaveFailureCount) / Double(fileSaveAttempts)
        let medianLaunchToReady = median(launchToReadyDurations)
        let medianFileOpen = median(fileOpenDurations)
        var reasons: [String] = []
        if restoreFailureRate > 0.01 { reasons.append("restore failure rate above 1%") }
        if terminalFailureRate > 0.01 { reasons.append("terminal surface failure rate above 1%") }
        if fileSaveFailureRate > 0.01 { reasons.append("file-save failure rate above 1%") }
        if fileRestoreFailureCount > 0 { reasons.append("file-tab restore failures detected") }
        if reorderPersistenceFailureCount > 0 { reasons.append("reorder persistence failures detected") }
        if restoreOrderMismatchCount > 0 { reasons.append("restore-order mismatches detected") }
        if let medianLaunchToReady, medianLaunchToReady > launchToReadyBudget {
            reasons.append("median launch-to-ready time above budget")
        }
        if let medianFileOpen, medianFileOpen > fileOpenBudget {
            reasons.append("median file-open time above budget")
        }
        return PilotDiagnostics(
            restoreFailureRate: restoreFailureRate,
            terminalSurfaceFailureRate: terminalFailureRate,
            fileSaveFailureRate: fileSaveFailureRate,
            medianLaunchToReadySeconds: medianLaunchToReady,
            medianFileOpenSeconds: medianFileOpen,
            fileRestoreFailureCount: fileRestoreFailureCount,
            dirtyFileCloseConfirmationAcceptCount: dirtyFileCloseConfirmationAcceptCount,
            dirtyFileCloseConfirmationRejectCount: dirtyFileCloseConfirmationRejectCount,
            externalEditorEscalationCount: externalEditorEscalationCount,
            projectReorderCount: projectReorderCount,
            tabReorderCount: tabReorderCount,
            reorderValidationRejectionCount: reorderValidationRejectionCount,
            reorderPersistenceFailureCount: reorderPersistenceFailureCount,
            restoreOrderMismatchCount: restoreOrderMismatchCount,
            focusWorkspaceEnableCount: focusWorkspaceEnableCount,
            focusWorkspaceDisableCount: focusWorkspaceDisableCount,
            focusWorkspaceBlockedTerminalTabCount: focusWorkspaceBlockedTerminalTabCount,
            focusWorkspaceBlockedFileTabCount: focusWorkspaceBlockedFileTabCount,
            releaseBlockingReasons: reasons
        )
    }

    private func median(_ values: [TimeInterval]) -> TimeInterval? {
        guard !values.isEmpty else { return nil }
        let sortedValues = values.sorted()
        let middle = sortedValues.count / 2
        if sortedValues.count.isMultiple(of: 2) {
            return (sortedValues[middle - 1] + sortedValues[middle]) / 2
        }
        return sortedValues[middle]
    }
}
