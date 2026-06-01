import Foundation
import Testing
@testable import NativeMacADECore

@Suite
@MainActor
struct TerminalExitEventSourceTests {
    @Test
    func initialSnapshotForUnseenTabReturnsNil() {
        let source = TerminalExitEventSource()

        #expect(source.snapshot(tabID: UUID()) == nil)
    }

    @Test
    func publishingExitStoresSnapshotForMatchingTab() throws {
        let source = TerminalExitEventSource()
        let tabID = UUID()

        source.publish(tabID: tabID, exitStatus: 42)

        let snapshot = try #require(source.snapshot(tabID: tabID))
        #expect(snapshot == TerminalExitObservation(tabID: tabID, exitStatus: 42))
        #expect(source.snapshot(tabID: UUID()) == nil)
    }

    @Test
    func multipleSubscribersReceiveSameExitEvent() {
        let source = TerminalExitEventSource()
        let tabID = UUID()
        var firstSubscriberEvents: [TerminalExitObservation] = []
        var secondSubscriberEvents: [TerminalExitObservation] = []

        source.subscribe { firstSubscriberEvents.append($0) }
        source.subscribe { secondSubscriberEvents.append($0) }
        source.publish(tabID: tabID, exitStatus: 7)

        let expected = [TerminalExitObservation(tabID: tabID, exitStatus: 7)]
        #expect(firstSubscriberEvents == expected)
        #expect(secondSubscriberEvents == expected)
    }

    @Test
    func unsubscribedListenersDoNotReceiveLaterExitEvents() {
        let source = TerminalExitEventSource()
        let tabID = UUID()
        var activeSubscriberEvents: [TerminalExitObservation] = []
        var removedSubscriberEvents: [TerminalExitObservation] = []

        source.subscribe { activeSubscriberEvents.append($0) }
        let unsubscribe = source.subscribe { removedSubscriberEvents.append($0) }

        unsubscribe()
        source.publish(tabID: tabID, exitStatus: 0)

        #expect(activeSubscriberEvents == [TerminalExitObservation(tabID: tabID, exitStatus: 0)])
        #expect(removedSubscriberEvents.isEmpty)
    }

    @Test
    func nilExitStatusIsPreservedInSnapshot() throws {
        let source = TerminalExitEventSource()
        let tabID = UUID()
        var subscriberEvents: [TerminalExitObservation] = []
        source.subscribe { subscriberEvents.append($0) }

        source.publish(tabID: tabID, exitStatus: nil)

        let snapshot = try #require(source.snapshot(tabID: tabID))
        #expect(snapshot.tabID == tabID)
        #expect(snapshot.exitStatus == nil)
        #expect(subscriberEvents == [TerminalExitObservation(tabID: tabID, exitStatus: nil)])
    }
}
