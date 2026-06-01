import Foundation

public struct TerminalExitObservation: Equatable, Sendable {
    public let tabID: UUID
    public let exitStatus: Int32?

    public init(tabID: UUID, exitStatus: Int32?) {
        self.tabID = tabID
        self.exitStatus = exitStatus
    }
}

@MainActor
public final class TerminalExitEventSource {
    public typealias Listener = @MainActor (TerminalExitObservation) -> Void
    public typealias Unsubscribe = @MainActor () -> Void

    private var snapshotsByTabID: [UUID: TerminalExitObservation] = [:]
    private var listenersByID: [UUID: Listener] = [:]

    public init() {}

    public func snapshot(tabID: UUID) -> TerminalExitObservation? {
        snapshotsByTabID[tabID]
    }

    public func publish(tabID: UUID, exitStatus: Int32?) {
        let observation = TerminalExitObservation(tabID: tabID, exitStatus: exitStatus)
        snapshotsByTabID[tabID] = observation

        for listener in Array(listenersByID.values) {
            listener(observation)
        }
    }

    @discardableResult
    public func subscribe(_ listener: @escaping Listener) -> Unsubscribe {
        let listenerID = UUID()
        listenersByID[listenerID] = listener

        return { [weak self] in
            self?.listenersByID[listenerID] = nil
        }
    }
}
