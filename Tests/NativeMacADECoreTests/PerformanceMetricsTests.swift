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
}
