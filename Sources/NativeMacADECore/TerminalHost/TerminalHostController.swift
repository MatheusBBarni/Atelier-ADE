import AppKit
import Foundation
import GhosttyKit

@MainActor
public final class TerminalHostController: WorkspaceTerminalSurfaceManaging {
    private let adapter: any GhosttyAdapter
    private var surfacesByTabID: [UUID: GhosttySurfaceHandle] = [:]
    private var nativeViewsByTabID: [UUID: NSView] = [:]
    private var hostViewsByTabID: [UUID: TerminalSurfaceHostNSView] = [:]
    private var exitMonitorsByTabID: [UUID: Task<Void, Never>] = [:]
    private var currentAppearance: TerminalAppearance
    public var onSurfaceExited: ((UUID, Int32?) -> Void)?

    public init(
        adapter: any GhosttyAdapter = LiveGhosttyAdapter(),
        appearance: TerminalAppearance = .cursorDefault
    ) {
        self.adapter = adapter
        self.currentAppearance = appearance
    }

    @discardableResult
    public func createSurface(for tab: WorkspaceTab) async throws -> GhosttySurfaceHandle {
        guard tab.kind == .terminal else {
            throw WorkspaceCommandError.invalidFileTab(tab.id, "File tabs do not support terminal surfaces")
        }

        if let existing = surfacesByTabID[tab.id] { return existing }

        let configuration = GhosttyLaunchConfiguration(tab: tab, appearance: currentAppearance)
        try await adapter.initializeIfNeeded()
        let surface = try await adapter.createSurface(configuration: configuration)
        guard let nativeView = adapter.nativeView(for: surface) else {
            adapter.destroySurface(surface)
            throw GhosttyAdapterError.surfaceCreationFailed("Ghostty native view unavailable")
        }

        surfacesByTabID[tab.id] = surface
        nativeViewsByTabID[tab.id] = nativeView
        if let hostView = hostViewsByTabID[tab.id] {
            hostView.attach(surface: surface, tab: tab, appearance: configuration.appearance, nativeView: nativeView)
            resizeToCurrentBounds(tabID: tab.id, hostView: hostView)
        }
        startExitMonitoring(tabID: tab.id)
        return surface
    }

    public func updateAppearance(_ appearance: TerminalAppearance) {
        guard currentAppearance != appearance else { return }
        currentAppearance = appearance

        for hostView in hostViewsByTabID.values {
            hostView.updateAppearance(appearance)
        }
    }

    public func zoomIn() {
        adjustFontSize(by: 1)
    }

    public func zoomOut() {
        adjustFontSize(by: -1)
    }

    public func surface(for tabID: UUID) -> GhosttySurfaceHandle? {
        surfacesByTabID[tabID]
    }

    public func canClose(surface: GhosttySurfaceHandle) async -> Bool {
        return await adapter.canClose(surface: surface)
    }

    public func focus(tabID: UUID) {
        hostViewsByTabID[tabID]?.isActiveTerminalHost = true
        hostViewsByTabID[tabID]?.focusTerminal()

        guard let surface = surfacesByTabID[tabID] else { return }
        adapter.focus(surface: surface)
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
        if let surface = surfacesByTabID[tabID] {
            adapter.destroySurface(surface)
        }
        surfacesByTabID[tabID] = nil
        nativeViewsByTabID[tabID] = nil
        hostViewsByTabID[tabID]?.detachSurface()
        hostViewsByTabID[tabID] = nil
    }

    public func makeHostView(for tab: WorkspaceTab, isActive: Bool) -> NSView {
        let hostView = hostViewsByTabID[tab.id] ?? TerminalSurfaceHostNSView()
        removeStaleHostMappings(for: hostView, keeping: tab.id)
        hostViewsByTabID[tab.id] = hostView
        hostView.configure(tab: tab, appearance: currentAppearance, isActive: isActive)
        configureResizeCallback(for: hostView, tabID: tab.id)
        attachSurfaceIfAvailable(for: tab, hostView: hostView)
        return hostView
    }

    public func updateHostView(_ view: NSView, tab: WorkspaceTab, isActive: Bool) {
        guard let hostView = view as? TerminalSurfaceHostNSView else { return }
        removeStaleHostMappings(for: hostView, keeping: tab.id)
        hostViewsByTabID[tab.id] = hostView
        hostView.configure(tab: tab, appearance: currentAppearance, isActive: isActive)
        configureResizeCallback(for: hostView, tabID: tab.id)
        attachSurfaceIfAvailable(for: tab, hostView: hostView)
        if surfacesByTabID[tab.id] != nil {
            resizeToCurrentBounds(tabID: tab.id, hostView: hostView)
        }
    }

    private func startExitMonitoring(tabID: UUID) {
        exitMonitorsByTabID[tabID]?.cancel()
        exitMonitorsByTabID[tabID] = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if await self.hasExited(tabID: tabID) {
                    let exitStatus = await self.exitStatus(tabID: tabID)
                    self.onSurfaceExited?(tabID, exitStatus)
                    return
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func exitStatus(tabID: UUID) async -> Int32? {
        guard let surface = surfacesByTabID[tabID] else { return nil }
        return await adapter.exitStatus(surface: surface)
    }

    private func attachSurfaceIfAvailable(for tab: WorkspaceTab, hostView: TerminalSurfaceHostNSView) {
        guard let surface = surfacesByTabID[tab.id],
              let nativeView = nativeViewsByTabID[tab.id]
        else { return }

        hostView.attach(surface: surface, tab: tab, appearance: currentAppearance, nativeView: nativeView)
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

    private func adjustFontSize(by delta: Double) {
        var appearance = currentAppearance
        appearance.fontSize = min(max(appearance.fontSize + delta, 9), 28)
        updateAppearance(appearance)
    }
}

@MainActor
public final class TerminalSurfaceHostNSView: NSView {
    private static let contentInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    public private(set) var tabID: UUID?
    public private(set) var attachedSurface: GhosttySurfaceHandle?
    public private(set) var terminalAppearance: TerminalAppearance = .cursorDefault
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

    public func updateAppearance(_ appearance: TerminalAppearance) {
        terminalAppearance = appearance
        updateLayerStyle()
    }

    func attach(surface: GhosttySurfaceHandle, tab: WorkspaceTab, appearance: TerminalAppearance, nativeView: NSView) {
        attachedSurface = surface
        tabID = tab.id
        self.terminalAppearance = appearance
        embedSurfaceView(nativeView)
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
        layoutEmbeddedSurfaceView()
        onResize?(contentBounds.size)
    }

    public override func layout() {
        super.layout()
        layoutEmbeddedSurfaceView()
        onResize?(contentBounds.size)
    }

    public func focusTerminal() {
        guard let embeddedSurfaceView else { return }
        window?.makeFirstResponder(embeddedSurfaceView)
    }

    private func updateLayerStyle() {
        layer?.backgroundColor = NSColor(hex: terminalAppearance.backgroundHex).cgColor
        layer?.borderWidth = isActiveTerminalHost ? 1 : 0
        layer?.borderColor = NSColor(hex: terminalAppearance.cursorHex).cgColor
    }

    private func layoutEmbeddedSurfaceView() {
        embeddedSurfaceView?.frame = contentBounds
    }

    private func embedSurfaceView(_ surfaceView: NSView) {
        if embeddedSurfaceView !== surfaceView {
            embeddedSurfaceView?.removeFromSuperview()
            surfaceView.removeFromSuperview()
            surfaceView.frame = contentBounds
            surfaceView.autoresizingMask = [.width, .height]
            addSubview(surfaceView)
            embeddedSurfaceView = surfaceView
        }
        layoutEmbeddedSurfaceView()
    }

    private var contentBounds: NSRect {
        bounds.insetBy(dx: Self.contentInsets.left, dy: Self.contentInsets.top)
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
