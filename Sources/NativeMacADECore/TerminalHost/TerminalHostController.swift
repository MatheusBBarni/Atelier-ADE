import AppKit
import Darwin
import Foundation
@preconcurrency import SwiftTerm

@MainActor
public final class TerminalHostController: WorkspaceTerminalSurfaceManaging {
    private let adapter: any GhosttyAdapter
    private var surfacesByTabID: [UUID: GhosttySurfaceHandle] = [:]
    private var hostViewsByTabID: [UUID: TerminalSurfaceHostNSView] = [:]
    private var exitMonitorsByTabID: [UUID: Task<Void, Never>] = [:]
    private var sessionDriversByTabID: [UUID: TerminalSessionDriver] = [:]
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
        if let existing = surfacesByTabID[tab.id] { return existing }

        let configuration = GhosttyLaunchConfiguration(tab: tab, appearance: currentAppearance)
        let surface: GhosttySurfaceHandle
        let driver: TerminalSessionDriver?

        if adapter.usesEmbeddedSessionDriver {
            let liveDriver = sessionDriver(for: tab, appearance: configuration.appearance)
            do {
                try liveDriver.startIfNeeded()
            } catch {
                liveDriver.stop()
                sessionDriversByTabID[tab.id] = nil
                throw error
            }
            surface = GhosttySurfaceHandle()
            driver = liveDriver
        } else {
            try await adapter.initializeIfNeeded()
            surface = try await adapter.createSurface(configuration: configuration)
            driver = nil
        }

        surfacesByTabID[tab.id] = surface
        if let hostView = hostViewsByTabID[tab.id] {
            hostView.attach(surface: surface, tab: tab, appearance: configuration.appearance, driver: driver)
            resizeToCurrentBounds(tabID: tab.id, hostView: hostView)
        }
        if !adapter.usesEmbeddedSessionDriver {
            startExitMonitoring(tabID: tab.id)
        }
        return surface
    }

    public func updateAppearance(_ appearance: TerminalAppearance) {
        guard currentAppearance != appearance else { return }
        currentAppearance = appearance

        for (tabID, driver) in sessionDriversByTabID {
            driver.update(tabID: tabID, appearance: appearance)
        }

        for (tabID, hostView) in hostViewsByTabID {
            if let driver = sessionDriversByTabID[tabID] {
                hostView.attach(driver: driver, appearance: appearance)
            } else {
                hostView.updateAppearance(appearance)
            }
        }
    }

    public func surface(for tabID: UUID) -> GhosttySurfaceHandle? {
        surfacesByTabID[tabID]
    }

    public func canClose(surface: GhosttySurfaceHandle) async -> Bool {
        if let driver = sessionDriversBySurface(surface) {
            return !driver.isRunning
        }
        return await adapter.canClose(surface: surface)
    }

    public func focus(tabID: UUID) {
        hostViewsByTabID[tabID]?.isActiveTerminalHost = true
        hostViewsByTabID[tabID]?.focusTerminal()

        guard !adapter.usesEmbeddedSessionDriver,
              let surface = surfacesByTabID[tabID]
        else {
            return
        }
        adapter.focus(surface: surface)
    }

    public func resize(tabID: UUID, columns: Int, rows: Int) {
        guard !adapter.usesEmbeddedSessionDriver else { return }
        guard let surface = surfacesByTabID[tabID] else { return }
        adapter.resize(surface: surface, columns: columns, rows: rows)
    }

    public func hasExited(tabID: UUID) async -> Bool {
        if let driver = sessionDriversByTabID[tabID] {
            return driver.hasExited
        }
        guard let surface = surfacesByTabID[tabID] else { return false }
        return await adapter.hasExited(surface: surface)
    }

    public func releaseSurface(for tabID: UUID) {
        exitMonitorsByTabID[tabID]?.cancel()
        exitMonitorsByTabID[tabID] = nil
        sessionDriversByTabID[tabID]?.stop()
        sessionDriversByTabID[tabID] = nil
        if !adapter.usesEmbeddedSessionDriver, let surface = surfacesByTabID[tabID] {
            adapter.destroySurface(surface)
        }
        surfacesByTabID[tabID] = nil
        hostViewsByTabID[tabID]?.detachSurface()
        hostViewsByTabID[tabID] = nil
    }

    public func makeHostView(for tab: WorkspaceTab, isActive: Bool) -> NSView {
        let hostView = hostViewsByTabID[tab.id] ?? TerminalSurfaceHostNSView()
        removeStaleHostMappings(for: hostView, keeping: tab.id)
        hostViewsByTabID[tab.id] = hostView
        hostView.configure(tab: tab, appearance: currentAppearance, isActive: isActive)
        configureResizeCallback(for: hostView, tabID: tab.id)
        if let driver = sessionDriversByTabID[tab.id] {
            hostView.attach(driver: driver, appearance: currentAppearance)
        }
        if let surface = surfacesByTabID[tab.id] {
            hostView.attach(surface: surface, tab: tab, appearance: currentAppearance, driver: sessionDriversByTabID[tab.id])
        }
        return hostView
    }

    public func updateHostView(_ view: NSView, tab: WorkspaceTab, isActive: Bool) {
        guard let hostView = view as? TerminalSurfaceHostNSView else { return }
        removeStaleHostMappings(for: hostView, keeping: tab.id)
        hostViewsByTabID[tab.id] = hostView
        hostView.configure(tab: tab, appearance: currentAppearance, isActive: isActive)
        configureResizeCallback(for: hostView, tabID: tab.id)
        if let driver = sessionDriversByTabID[tab.id] {
            hostView.attach(driver: driver, appearance: currentAppearance)
        }
        if let surface = surfacesByTabID[tab.id] {
            hostView.attach(surface: surface, tab: tab, appearance: currentAppearance, driver: sessionDriversByTabID[tab.id])
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
        if let driver = sessionDriversByTabID[tabID] {
            return driver.exitStatus
        }
        guard let surface = surfacesByTabID[tabID] else { return nil }
        return await adapter.exitStatus(surface: surface)
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

    private func sessionDriver(for tab: WorkspaceTab, appearance: TerminalAppearance) -> TerminalSessionDriver {
        if let existing = sessionDriversByTabID[tab.id] {
            existing.update(tab: tab, appearance: appearance)
            return existing
        }

        let driver = TerminalSessionDriver(tab: tab, appearance: appearance)
        driver.onExit = { [weak self] status in
            guard let self else { return }
            self.onSurfaceExited?(tab.id, status)
        }
        sessionDriversByTabID[tab.id] = driver
        return driver
    }

    private func sessionDriversBySurface(_ surface: GhosttySurfaceHandle) -> TerminalSessionDriver? {
        guard let tabID = surfacesByTabID.first(where: { $0.value == surface })?.key else { return nil }
        return sessionDriversByTabID[tabID]
    }
}

@MainActor
public final class TerminalSurfaceHostNSView: NSView {
    private static let contentInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    public private(set) var tabID: UUID?
    public private(set) var attachedSurface: GhosttySurfaceHandle?
    public private(set) var terminalAppearance: TerminalAppearance = .cursorDefault
    public private(set) var embeddedSurfaceView: NSView?
    public private(set) var localProcessTerminalView: LocalProcessTerminalView?
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

    func attach(surface: GhosttySurfaceHandle, tab: WorkspaceTab, appearance: TerminalAppearance, driver: TerminalSessionDriver?) {
        attachedSurface = surface
        tabID = tab.id
        self.terminalAppearance = appearance
        if let driver {
            attach(driver: driver, appearance: appearance)
        } else {
            ensurePlaceholderSurfaceView()
        }
        updateLayerStyle()
    }

    func attach(driver: TerminalSessionDriver, appearance: TerminalAppearance) {
        self.terminalAppearance = appearance
        driver.update(tabID: tabID, appearance: appearance)
        embedSurfaceView(driver.embeddedView, terminalView: driver.embeddedView)
        updateLayerStyle()
    }

    public func detachSurface() {
        attachedSurface = nil
        embeddedSurfaceView?.removeFromSuperview()
        embeddedSurfaceView = nil
        localProcessTerminalView = nil
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
        guard let localProcessTerminalView else { return }
        window?.makeFirstResponder(localProcessTerminalView)
    }

    @discardableResult
    private func ensurePlaceholderSurfaceView() -> NSView {
        if let embeddedSurfaceView {
            return embeddedSurfaceView
        }

        let placeholderView = NSView(frame: bounds)
        embedSurfaceView(placeholderView, terminalView: nil)
        return placeholderView
    }

    private func updateLayerStyle() {
        layer?.backgroundColor = NSColor(hex: terminalAppearance.backgroundHex).cgColor
        layer?.borderWidth = isActiveTerminalHost ? 1 : 0
        layer?.borderColor = NSColor(hex: terminalAppearance.cursorHex).cgColor
    }

    private func layoutEmbeddedSurfaceView() {
        embeddedSurfaceView?.frame = contentBounds
    }

    private func embedSurfaceView(_ surfaceView: NSView, terminalView: LocalProcessTerminalView?) {
        if embeddedSurfaceView !== surfaceView {
            embeddedSurfaceView?.removeFromSuperview()
            surfaceView.removeFromSuperview()
            surfaceView.frame = contentBounds
            surfaceView.autoresizingMask = [.width, .height]
            addSubview(surfaceView)
            embeddedSurfaceView = surfaceView
        }
        localProcessTerminalView = terminalView
        layoutEmbeddedSurfaceView()
    }

    private var contentBounds: NSRect {
        bounds.insetBy(dx: Self.contentInsets.left, dy: Self.contentInsets.top)
    }
}

@MainActor
final class TerminalSessionDriver: NSObject {
    let tabID: UUID
    var onExit: ((Int32?) -> Void)?
    private var tab: WorkspaceTab
    private var appearance: TerminalAppearance
    private let terminalView: LocalProcessTerminalView
    private(set) var isStarted = false
    private(set) var hasExited = false
    private(set) var exitStatus: Int32?

    init(tab: WorkspaceTab, appearance: TerminalAppearance) {
        self.tabID = tab.id
        self.tab = tab
        self.appearance = appearance
        self.terminalView = LocalProcessTerminalView(frame: .zero)
        super.init()
        terminalView.processDelegate = self
        terminalView.autoresizingMask = [.width, .height]
        applyAppearance(appearance)
    }

    var isRunning: Bool {
        terminalView.process.running && !hasExited
    }

    var embeddedView: LocalProcessTerminalView {
        terminalView
    }

    func update(tab: WorkspaceTab, appearance: TerminalAppearance) {
        self.tab = tab
        update(tabID: tab.id, appearance: appearance)
    }

    func update(tabID: UUID?, appearance: TerminalAppearance) {
        self.appearance = appearance
        applyAppearance(appearance)
    }

    func startIfNeeded() throws {
        guard !isStarted else { return }
        isStarted = true
        hasExited = false
        exitStatus = nil

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: tab.workingDirectory, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw TerminalSessionDriverError.directoryUnavailable(tab.workingDirectory)
        }

        terminalView.feed(text: launchBanner())

        terminalView.startProcess(
            executable: preferredShellPath(),
            args: launchArguments(),
            environment: processEnvironment(),
            execName: loginExecName(),
            currentDirectory: tab.workingDirectory
        )

        guard terminalView.process.running else {
            throw TerminalSessionDriverError.processCouldNotStart
        }
    }

    func stop() {
        terminalView.processDelegate = nil
        if terminalView.process.running {
            terminalView.terminate()
        }
        hasExited = true
    }

    private func launchArguments() -> [String] {
        if let commandLine = launchCommandLine() {
            return ["-ilc", commandLine]
        }

        return ["-il"]
    }

    private func processEnvironment() -> [String] {
        var environment = ProcessInfo.processInfo.environment
        environment["SHELL"] = preferredShellPath()
        environment["TERM"] = environment["TERM"] ?? "xterm-256color"
        environment["COLORTERM"] = environment["COLORTERM"] ?? "truecolor"
        for (key, value) in launchEnvironmentOverrides() {
            environment[key] = value
        }
        return environment
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
    }

    private func launchBanner() -> String {
        let commandDescription = resolvedCommandDescription()

        return "Atelier terminal\nWorking directory: \(tab.workingDirectory)\nCommand: \(commandDescription)\n\n"
    }

    private func applyAppearance(_ appearance: TerminalAppearance) {
        let background = NSColor(hex: appearance.backgroundHex)
        let foreground = NSColor(hex: appearance.foregroundHex)
        terminalView.font = NSFont(name: appearance.fontName, size: appearance.fontSize) ?? .monospacedSystemFont(ofSize: appearance.fontSize, weight: .regular)
        terminalView.nativeBackgroundColor = background
        terminalView.nativeForegroundColor = foreground
        terminalView.selectedTextBackgroundColor = NSColor(hex: appearance.selectionHex)
        terminalView.caretColor = NSColor(hex: appearance.cursorHex)
        terminalView.caretTextColor = background
    }

    private func loginExecName() -> String {
        "-\(URL(fileURLWithPath: preferredShellPath()).lastPathComponent)"
    }

    private func preferredShellPath() -> String {
        let candidates = [
            Self.userLoginShellPath(),
            ProcessInfo.processInfo.environment["SHELL"],
            "/bin/zsh"
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for candidate in candidates {
            let path = URL(fileURLWithPath: candidate).standardizedFileURL.path
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return "/bin/zsh"
    }

    private func launchCommandLine() -> String? {
        guard let command = tab.launchCommand?.trimmingCharacters(in: .whitespacesAndNewlines), !command.isEmpty else {
            return nil
        }

        let resolvedArguments = resolvedLaunchArguments(for: command)
        let commandTokens = [Self.shellEscape(command)] + resolvedArguments.map(Self.shellEscape)
        let environmentTokens = launchEnvironmentOverrides()
            .sorted { $0.key < $1.key }
            .map { key, value in
                "\(key)=\(Self.shellEscape(value))"
            }

        if environmentTokens.isEmpty {
            return (["exec"] + commandTokens).joined(separator: " ")
        }

        return (["exec", "env"] + environmentTokens + commandTokens).joined(separator: " ")
    }

    private func resolvedLaunchArguments(for command: String) -> [String] {
        var arguments = GhosttyLaunchConfiguration.decodeArguments(from: tab.launchArgumentsJSON)
        let executableName = URL(fileURLWithPath: command).lastPathComponent.lowercased()

        if executableName == "codex", !arguments.contains("--no-alt-screen") {
            arguments.append("--no-alt-screen")
        }

        if executableName == "codex", !arguments.contains("-c") {
            arguments.append(contentsOf: ["-c", "tui.raw_output_mode=true"])
        }

        if executableName == "claude", !arguments.contains("--dangerously-skip-permissions") {
            arguments.append("--dangerously-skip-permissions")
        }

        return arguments
    }

    private func launchEnvironmentOverrides() -> [String: String] {
        let executableName = tab.launchCommand.map { URL(fileURLWithPath: $0).lastPathComponent.lowercased() }
        var environment: [String: String] = [:]

        guard let executableName else {
            return environment
        }

        if executableName == "codex" {
            environment["CODEX_TUI_DISABLE_KEYBOARD_ENHANCEMENT"] = "1"
        }

        if executableName == "claude" {
            environment["CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN"] = "1"
            environment["CLAUDE_CODE_DISABLE_MOUSE"] = "1"
            environment["CLAUDE_CODE_ACCESSIBILITY"] = "1"
            environment["CLAUDE_CODE_DISABLE_TERMINAL_TITLE"] = "1"
            environment["CLAUDE_CODE_SYNTAX_HIGHLIGHT"] = "false"
        }

        return environment
    }

    private func resolvedCommandDescription() -> String {
        guard let command = tab.launchCommand?.trimmingCharacters(in: .whitespacesAndNewlines), !command.isEmpty else {
            return URL(fileURLWithPath: preferredShellPath()).lastPathComponent
        }

        return ([command] + resolvedLaunchArguments(for: command)).joined(separator: " ")
    }

    private static func userLoginShellPath() -> String? {
        guard let passwd = getpwuid(getuid()) else { return nil }
        let shell = String(cString: passwd.pointee.pw_shell)
        return shell.isEmpty ? nil : shell
    }

    private static func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}

enum TerminalSessionDriverError: Error, Equatable, Sendable, CustomStringConvertible {
    case directoryUnavailable(String)
    case processCouldNotStart

    var description: String {
        switch self {
        case .directoryUnavailable(let path):
            return "Directory unavailable: \(path)"
        case .processCouldNotStart:
            return "Terminal process could not start"
        }
    }
}

extension TerminalSessionDriver: LocalProcessTerminalViewDelegate {
    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.hasExited = true
            self.exitStatus = exitCode
            if let exitCode {
                self.terminalView.feed(text: "\n[Process exited with status \(exitCode)]\n")
            } else {
                self.terminalView.feed(text: "\n[Terminal process ended unexpectedly]\n")
            }
            self.onExit?(exitCode)
        }
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
