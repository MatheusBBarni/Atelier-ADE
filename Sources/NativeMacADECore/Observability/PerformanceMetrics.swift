import Foundation

public struct PilotDiagnostics: Equatable, Sendable {
    public var restoreFailureRate: Double
    public var terminalSurfaceFailureRate: Double
    public var medianLaunchToReadySeconds: Double?
    public var releaseBlockingReasons: [String]
}

@MainActor
public final class PerformanceMetrics {
    public private(set) var projectOpenDurations: [TimeInterval] = []
    public private(set) var launchToReadyDurations: [TimeInterval] = []
    public private(set) var tabCreationDurations: [TimeInterval] = []
    public private(set) var restoreDurations: [TimeInterval] = []
    public private(set) var restoreSuccessCount = 0
    public private(set) var restoreFailureCount = 0
    public private(set) var sessionCreateCount = 0
    public private(set) var terminalSurfaceFailureCount = 0
    public private(set) var terminalSurfaceCreationCount = 0
    public private(set) var terminalProcessExitCount = 0
    public private(set) var closeConfirmationAcceptCount = 0
    public private(set) var closeConfirmationRejectCount = 0
    public private(set) var inaccessibleRestoredProjectCount = 0
    public private(set) var settingsOpenedCount = 0
    public private(set) var settingsSavedCount = 0
    public private(set) var settingsSaveFailureCount = 0
    public private(set) var themeChangedCount = 0
    public private(set) var keybindingChangedCount = 0
    public private(set) var lastSavedChangedKeybindingCount = 0

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

    public func recordKeybindingsChanged(changedCommandCount: Int) {
        keybindingChangedCount += changedCommandCount
    }

    public func diagnostics(launchToReadyBudget: TimeInterval = 10) -> PilotDiagnostics {
        let restoreAttempts = restoreSuccessCount + restoreFailureCount
        let restoreFailureRate = restoreAttempts == 0 ? 0 : Double(restoreFailureCount) / Double(restoreAttempts)
        let terminalAttempts = terminalSurfaceCreationCount + terminalSurfaceFailureCount
        let terminalFailureRate = terminalAttempts == 0 ? 0 : Double(terminalSurfaceFailureCount) / Double(terminalAttempts)
        let medianLaunchToReady = median(launchToReadyDurations)
        var reasons: [String] = []
        if restoreFailureRate > 0.01 { reasons.append("restore failure rate above 1%") }
        if terminalFailureRate > 0.01 { reasons.append("terminal surface failure rate above 1%") }
        if let medianLaunchToReady, medianLaunchToReady > launchToReadyBudget {
            reasons.append("median launch-to-ready time above budget")
        }
        return PilotDiagnostics(
            restoreFailureRate: restoreFailureRate,
            terminalSurfaceFailureRate: terminalFailureRate,
            medianLaunchToReadySeconds: medianLaunchToReady,
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
