import AppKit
import Foundation

@MainActor
public final class LiveGhosttySurfaceRuntime: GhosttySurfaceRuntime {
    public static let pinnedRevision = CGhosttyRuntime.pinnedRevision

    private static var sharedAppContext: CGhosttyRuntime.AppContext?

    private let cRuntime: CGhosttyRuntime
    private var surfaces: [UUID: SurfaceRecord] = [:]

    public init() {
        self.cRuntime = CGhosttyRuntime()
    }

    init(bridge: CGhosttyRuntime) {
        self.cRuntime = bridge
    }

    public static func resetForTesting() {
        sharedAppContext = nil
        CGhosttyRuntime.resetForTesting()
    }

    public func initializeIfNeeded() async throws {
        if Self.sharedAppContext != nil { return }
        Self.sharedAppContext = try cRuntime.initialize()
    }

    public func createSurface(configuration: GhosttyLaunchConfiguration) async throws -> GhosttySurfaceHandle {
        try await initializeIfNeeded()

        guard let appContext = Self.sharedAppContext else {
            throw GhosttyAdapterError.invalidAppContext("Ghostty app context is not initialized")
        }

        let inheritedRawID = configuration.inheritedSurfaceID.flatMap { surfaces[$0]?.rawSurface.id }
        let rawSurface = try cRuntime.createSurface(
            appContext: appContext,
            configuration: configuration,
            inheritedSurfaceID: inheritedRawID
        )
        let handle = GhosttySurfaceHandle(
            rawSurfaceID: rawSurface.id,
            appContextID: rawSurface.appContextID,
            inheritedSurfaceRawID: rawSurface.inheritedSurfaceID
        )

        surfaces[handle.id] = SurfaceRecord(
            configuration: configuration,
            rawSurface: rawSurface,
            nativeView: GhosttySurfaceDiagnosticView(configuration: configuration, rawSurface: rawSurface),
            focused: false,
            columns: 80,
            rows: 24
        )
        return handle
    }

    public func nativeView(for surface: GhosttySurfaceHandle) -> NSView? {
        surfaces[surface.id]?.nativeView
    }

    public func focus(surface: GhosttySurfaceHandle) {
        guard var record = surfaces[surface.id] else { return }
        cRuntime.focus(surface: &record.rawSurface, focused: true)
        record.focused = true
        surfaces[surface.id] = record
    }

    public func resize(surface: GhosttySurfaceHandle, columns: Int, rows: Int) {
        guard var record = surfaces[surface.id] else { return }
        cRuntime.resize(surface: &record.rawSurface, columns: columns, rows: rows)
        record.columns = columns
        record.rows = rows
        surfaces[surface.id] = record
    }

    public func canClose(surface: GhosttySurfaceHandle) async -> Bool {
        guard let record = surfaces[surface.id] else { return true }
        return cRuntime.canClose(surface: record.rawSurface)
    }

    public func hasExited(surface: GhosttySurfaceHandle) async -> Bool {
        guard let record = surfaces[surface.id] else { return true }
        return cRuntime.hasExited(surface: record.rawSurface)
    }

    public func exitStatus(surface: GhosttySurfaceHandle) async -> Int32? {
        guard let record = surfaces[surface.id] else { return nil }
        return cRuntime.exitStatus(surface: record.rawSurface)
    }

    public func destroySurface(_ surface: GhosttySurfaceHandle) {
        guard var record = surfaces[surface.id] else { return }
        cRuntime.destroy(surface: &record.rawSurface)
        surfaces[surface.id] = nil
    }

    func configuration(for surface: GhosttySurfaceHandle) -> GhosttyLaunchConfiguration? {
        surfaces[surface.id]?.configuration
    }

    func isFocused(surface: GhosttySurfaceHandle) -> Bool {
        surfaces[surface.id]?.focused == true
    }

    func size(for surface: GhosttySurfaceHandle) -> (columns: Int, rows: Int)? {
        guard let record = surfaces[surface.id] else { return nil }
        return (record.columns, record.rows)
    }
}

@MainActor
private struct SurfaceRecord {
    var configuration: GhosttyLaunchConfiguration
    var rawSurface: CGhosttyRuntime.Surface
    var nativeView: NSView
    var focused: Bool
    var columns: Int
    var rows: Int
}

@MainActor
private final class GhosttySurfaceDiagnosticView: NSView {
    private static let accessibilityLabel = "Ghostty bridge diagnostic surface"

    init(configuration: GhosttyLaunchConfiguration, rawSurface: CGhosttyRuntime.Surface) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.ghosttyKitColor(
            hex: configuration.appearance.backgroundHex,
            fallback: .black
        ).cgColor

        setAccessibilityLabel(Self.accessibilityLabel)

        let foregroundColor = NSColor.ghosttyKitColor(
            hex: configuration.appearance.foregroundHex,
            fallback: .labelColor
        )
        let accentColor = NSColor.ghosttyKitColor(
            hex: configuration.appearance.cursorHex,
            fallback: .controlAccentColor
        )
        let baseFontSize = CGFloat(max(configuration.appearance.fontSize, 12))

        let titleLabel = Self.makeLabel(
            "Ghostty bridge initialized",
            color: foregroundColor,
            font: .monospacedSystemFont(ofSize: baseFontSize + 2, weight: .semibold)
        )
        let detailLabel = Self.makeLabel(
            "Native libghostty renderer is not linked in this build.",
            color: accentColor,
            font: .monospacedSystemFont(ofSize: baseFontSize, weight: .regular)
        )
        let surfaceLabel = Self.makeLabel(
            "Surface \(rawSurface.id) | cwd \(configuration.workingDirectory)",
            color: foregroundColor.withAlphaComponent(0.82),
            font: .monospacedSystemFont(ofSize: max(baseFontSize - 1, 11), weight: .regular)
        )
        let launchLabel = Self.makeLabel(
            "Launch \(Self.launchSummary(configuration))",
            color: foregroundColor.withAlphaComponent(0.72),
            font: .monospacedSystemFont(ofSize: max(baseFontSize - 1, 11), weight: .regular)
        )

        let stackView = NSStackView(views: [titleLabel, detailLabel, surfaceLabel, launchLabel])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 6
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -18),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private static func makeLabel(_ text: String, color: NSColor, font: NSFont) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.textColor = color
        label.font = font
        label.lineBreakMode = .byTruncatingMiddle
        label.maximumNumberOfLines = 1
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    private static func launchSummary(_ configuration: GhosttyLaunchConfiguration) -> String {
        guard let command = configuration.command, !command.isEmpty else {
            return "login shell"
        }

        let arguments = configuration.arguments.joined(separator: " ")
        guard !arguments.isEmpty else { return command }
        return "\(command) \(arguments)"
    }
}

private extension NSColor {
    static func ghosttyKitColor(hex: String, fallback: NSColor) -> NSColor {
        let normalized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard normalized.count == 6 else { return fallback }

        var value: UInt64 = 0
        guard Scanner(string: normalized).scanHexInt64(&value) else { return fallback }

        return NSColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
