import Foundation
import OSLog

public struct WorkspaceLogEvent: Equatable, Sendable {
    public var name: String
    public var fields: [String: String]
    public var timestamp: Date

    public init(name: String, fields: [String: String], timestamp: Date = Date()) {
        self.name = name
        self.fields = fields
        self.timestamp = timestamp
    }
}

@MainActor
public final class WorkspaceLogger {
    public private(set) var events: [WorkspaceLogEvent] = []
    private let now: @MainActor () -> Date
    private let osLogger = Logger(subsystem: "Atelier", category: "Workspace")

    public init(now: @escaping @MainActor () -> Date = Date.init) {
        self.now = now
    }

    public func emit(_ name: String, fields: [String: String]) {
        events.append(WorkspaceLogEvent(name: name, fields: fields, timestamp: now()))
        let sortedFields = fields.keys.sorted().map { key in "\(key)=\(fields[key] ?? "")" }.joined(separator: " ")
        osLogger.info("event=\(name, privacy: .public) \(sortedFields, privacy: .public)")
    }

    public func clear() {
        events.removeAll()
    }
}

public enum WorkspacePrivacy {
    public static func hashIdentifier(_ value: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }
}
