import AppKit
import Foundation

@MainActor
public final class TerminalHostController: WorkspaceTerminalSurfaceManaging {
    private let adapter: any GhosttyAdapter
    private var surfacesByTabID: [UUID: GhosttySurfaceHandle] = [:]
    private var hostViewsByTabID: [UUID: TerminalSurfaceHostNSView] = [:]
    private var exitMonitorsByTabID: [UUID: Task<Void, Never>] = [:]
    public var onSurfaceExited: ((UUID) -> Void)?

    public init(adapter: any GhosttyAdapter = LiveGhosttyAdapter()) {
        self.adapter = adapter
    }

    @discardableResult
    public func createSurface(for tab: WorkspaceTab) async throws -> GhosttySurfaceHandle {
        if let existing = surfacesByTabID[tab.id] { return existing }

        let configuration = GhosttyLaunchConfiguration(
            workingDirectory: tab.workingDirectory,
            command: tab.launchCommand,
            arguments: Self.decodeArguments(from: tab.launchArgumentsJSON),
            appearance: .nordDefault
        )
        try await adapter.initializeIfNeeded()
        let surface = try await adapter.createSurface(configuration: configuration)
        surfacesByTabID[tab.id] = surface
        if let hostView = hostViewsByTabID[tab.id] {
            hostView.attach(surface: surface, tab: tab, appearance: configuration.appearance)
            resizeToCurrentBounds(tabID: tab.id, hostView: hostView)
        }
        startExitMonitoring(tabID: tab.id)
        return surface
    }

    public func surface(for tabID: UUID) -> GhosttySurfaceHandle? {
        surfacesByTabID[tabID]
    }

    public func canClose(surface: GhosttySurfaceHandle) async -> Bool {
        await adapter.canClose(surface: surface)
    }

    public func focus(tabID: UUID) {
        guard let surface = surfacesByTabID[tabID] else { return }
        adapter.focus(surface: surface)
        hostViewsByTabID[tabID]?.isActiveTerminalHost = true
    }

    public func resize(tabID: UUID, columns: Int, rows: Int) {
        guard let surface = surfacesByTabID[tabID] else { return }
        adapter.resize(surface: surface, columns: columns, rows: rows)
    }

    public func hasExited(tabID: UUID) async -> Bool {
        guard let surface = surfacesByTabID[tabID] else { return false }
        return await adapter.hasExited(surface: surface)
    }

    public func releaseSurface(for tabID: UUID) {
        exitMonitorsByTabID[tabID]?.cancel()
        exitMonitorsByTabID[tabID] = nil
        surfacesByTabID[tabID] = nil
        hostViewsByTabID[tabID]?.detachSurface()
        hostViewsByTabID[tabID] = nil
    }

    public func makeHostView(for tab: WorkspaceTab, isActive: Bool) -> NSView {
        let hostView = hostViewsByTabID[tab.id] ?? TerminalSurfaceHostNSView()
        removeStaleHostMappings(for: hostView, keeping: tab.id)
        hostViewsByTabID[tab.id] = hostView
        hostView.configure(tab: tab, appearance: .nordDefault, isActive: isActive)
        configureResizeCallback(for: hostView, tabID: tab.id)
        if let surface = surfacesByTabID[tab.id] {
            hostView.attach(surface: surface, tab: tab, appearance: .nordDefault)
        }
        return hostView
    }

    public func updateHostView(_ view: NSView, tab: WorkspaceTab, isActive: Bool) {
        guard let hostView = view as? TerminalSurfaceHostNSView else { return }
        removeStaleHostMappings(for: hostView, keeping: tab.id)
        hostViewsByTabID[tab.id] = hostView
        hostView.configure(tab: tab, appearance: .nordDefault, isActive: isActive)
        configureResizeCallback(for: hostView, tabID: tab.id)
        if let surface = surfacesByTabID[tab.id] {
            hostView.attach(surface: surface, tab: tab, appearance: .nordDefault)
            resizeToCurrentBounds(tabID: tab.id, hostView: hostView)
        }
    }

    private static func decodeArguments(from json: String?) -> [String] {
        guard let json,
              let data = json.data(using: .utf8),
              let arguments = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return arguments
    }

    private func startExitMonitoring(tabID: UUID) {
        exitMonitorsByTabID[tabID]?.cancel()
        exitMonitorsByTabID[tabID] = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if await self.hasExited(tabID: tabID) {
                    self.onSurfaceExited?(tabID)
                    return
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func configureResizeCallback(for hostView: TerminalSurfaceHostNSView, tabID: UUID) {
        hostView.onResize = { [weak self] size in
            Task { @MainActor in
                self?.resize(tabID: tabID, size: size)
            }
        }
    }

    private func resizeToCurrentBounds(tabID: UUID, hostView: TerminalSurfaceHostNSView) {
        resize(tabID: tabID, size: hostView.bounds.size)
    }

    private func resize(tabID: UUID, size: CGSize) {
        let columns = max(Int(size.width / 8), 1)
        let rows = max(Int(size.height / 16), 1)
        resize(tabID: tabID, columns: columns, rows: rows)
    }

    private func removeStaleHostMappings(for hostView: TerminalSurfaceHostNSView, keeping tabID: UUID) {
        for (mappedTabID, mappedView) in hostViewsByTabID where mappedTabID != tabID && mappedView === hostView {
            hostViewsByTabID[mappedTabID] = nil
        }
    }
}

@MainActor
public final class TerminalSurfaceHostNSView: NSView {
    public private(set) var tabID: UUID?
    public private(set) var attachedSurface: GhosttySurfaceHandle?
    public private(set) var terminalAppearance: TerminalAppearance = .nordDefault
    public private(set) var embeddedSurfaceView: NSView?
    public var onResize: ((CGSize) -> Void)?
    public var isActiveTerminalHost: Bool = false {
        didSet { updateLayerStyle() }
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        updateLayerStyle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    public func configure(tab: WorkspaceTab, appearance: TerminalAppearance, isActive: Bool) {
        if let tabID, tabID != tab.id {
            detachSurface()
        }
        tabID = tab.id
        self.terminalAppearance = appearance
        isActiveTerminalHost = isActive
        toolTip = tab.workingDirectory
        updateLayerStyle()
    }

    public func attach(surface: GhosttySurfaceHandle, tab: WorkspaceTab, appearance: TerminalAppearance) {
        attachedSurface = surface
        tabID = tab.id
        self.terminalAppearance = appearance
        ensureEmbeddedSurfaceView()
        updateLayerStyle()
    }

    public func detachSurface() {
        attachedSurface = nil
        embeddedSurfaceView?.removeFromSuperview()
        embeddedSurfaceView = nil
        updateLayerStyle()
    }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        embeddedSurfaceView?.frame = bounds
        onResize?(newSize)
    }

    public override func layout() {
        super.layout()
        embeddedSurfaceView?.frame = bounds
        onResize?(bounds.size)
    }

    private func ensureEmbeddedSurfaceView() {
        guard embeddedSurfaceView == nil else { return }
        let surfaceView = NSView(frame: bounds)
        surfaceView.autoresizingMask = [.width, .height]
        surfaceView.wantsLayer = true
        surfaceView.layer?.backgroundColor = NSColor(hex: terminalAppearance.backgroundHex).cgColor
        addSubview(surfaceView)
        embeddedSurfaceView = surfaceView
    }

    private func updateLayerStyle() {
        layer?.backgroundColor = NSColor(hex: terminalAppearance.backgroundHex).cgColor
        layer?.borderWidth = isActiveTerminalHost ? 1 : 0
        layer?.borderColor = NSColor(hex: NordTheme.activeBorder.hex).cgColor
    }
}

private extension NSColor {
    convenience init(hex: String) {
        let normalized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: normalized).scanHexInt64(&value)
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
