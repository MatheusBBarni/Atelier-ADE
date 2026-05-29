import AppKit
import Darwin
import Foundation

@MainActor
public final class TerminalHostController: WorkspaceTerminalSurfaceManaging {
    private let adapter: any GhosttyAdapter
    private var surfacesByTabID: [UUID: GhosttySurfaceHandle] = [:]
    private var hostViewsByTabID: [UUID: TerminalSurfaceHostNSView] = [:]
    private var exitMonitorsByTabID: [UUID: Task<Void, Never>] = [:]
    private var sessionDriversByTabID: [UUID: TerminalSessionDriver] = [:]
    public var onSurfaceExited: ((UUID, Int32?) -> Void)?

    public init(adapter: any GhosttyAdapter = LiveGhosttyAdapter()) {
        self.adapter = adapter
    }

    @discardableResult
    public func createSurface(for tab: WorkspaceTab) async throws -> GhosttySurfaceHandle {
        if let existing = surfacesByTabID[tab.id] { return existing }

        let configuration = GhosttyLaunchConfiguration(tab: tab)
        try await adapter.initializeIfNeeded()
        let surface = try await adapter.createSurface(configuration: configuration)
        surfacesByTabID[tab.id] = surface
        let driver: TerminalSessionDriver?
        if adapter.usesEmbeddedSessionDriver {
            let liveDriver = sessionDriver(for: tab, appearance: configuration.appearance)
            liveDriver.startIfNeeded()
            driver = liveDriver
        } else {
            driver = nil
        }
        if let hostView = hostViewsByTabID[tab.id] {
            hostView.attach(surface: surface, tab: tab, appearance: configuration.appearance, driver: driver)
            resizeToCurrentBounds(tabID: tab.id, hostView: hostView)
        }
        startExitMonitoring(tabID: tab.id)
        return surface
    }

    public func surface(for tabID: UUID) -> GhosttySurfaceHandle? {
        surfacesByTabID[tabID]
    }

    public func canClose(surface: GhosttySurfaceHandle) async -> Bool {
        if let driver = sessionDriversBySurface(surface), driver.isRunning { return true }
        return await adapter.canClose(surface: surface)
    }

    public func focus(tabID: UUID) {
        guard let surface = surfacesByTabID[tabID] else { return }
        adapter.focus(surface: surface)
        hostViewsByTabID[tabID]?.isActiveTerminalHost = true
        hostViewsByTabID[tabID]?.focusTerminal()
    }

    public func resize(tabID: UUID, columns: Int, rows: Int) {
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
        if let surface = surfacesByTabID[tabID] {
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
        hostView.configure(tab: tab, appearance: .nordDefault, isActive: isActive)
        configureResizeCallback(for: hostView, tabID: tab.id)
        if adapter.usesEmbeddedSessionDriver {
            let driver = sessionDriver(for: tab, appearance: .nordDefault)
            driver.startIfNeeded()
            hostView.attach(driver: driver, appearance: .nordDefault)
        } else if let driver = sessionDriversByTabID[tab.id] {
            hostView.attach(driver: driver, appearance: .nordDefault)
        }
        if let surface = surfacesByTabID[tab.id] {
            hostView.attach(surface: surface, tab: tab, appearance: .nordDefault, driver: sessionDriversByTabID[tab.id])
        }
        return hostView
    }

    public func updateHostView(_ view: NSView, tab: WorkspaceTab, isActive: Bool) {
        guard let hostView = view as? TerminalSurfaceHostNSView else { return }
        removeStaleHostMappings(for: hostView, keeping: tab.id)
        hostViewsByTabID[tab.id] = hostView
        hostView.configure(tab: tab, appearance: .nordDefault, isActive: isActive)
        configureResizeCallback(for: hostView, tabID: tab.id)
        if adapter.usesEmbeddedSessionDriver {
            let driver = sessionDriver(for: tab, appearance: .nordDefault)
            driver.startIfNeeded()
            hostView.attach(driver: driver, appearance: .nordDefault)
        } else if let driver = sessionDriversByTabID[tab.id] {
            hostView.attach(driver: driver, appearance: .nordDefault)
        }
        if let surface = surfacesByTabID[tab.id] {
            hostView.attach(surface: surface, tab: tab, appearance: .nordDefault, driver: sessionDriversByTabID[tab.id])
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
    public private(set) var tabID: UUID?
    public private(set) var attachedSurface: GhosttySurfaceHandle?
    public private(set) var terminalAppearance: TerminalAppearance = .nordDefault
    public private(set) var embeddedSurfaceView: NSView?
    private(set) var terminalTextView: TerminalTextView?
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

    func attach(surface: GhosttySurfaceHandle, tab: WorkspaceTab, appearance: TerminalAppearance, driver: TerminalSessionDriver?) {
        attachedSurface = surface
        tabID = tab.id
        self.terminalAppearance = appearance
        ensureEmbeddedSurfaceView()
        if let driver {
            attach(driver: driver, appearance: appearance)
        }
        updateLayerStyle()
    }

    func attach(driver: TerminalSessionDriver, appearance: TerminalAppearance) {
        self.terminalAppearance = appearance
        let textView = ensureEmbeddedSurfaceView()
        driver.bind(to: textView)
        updateLayerStyle()
    }

    public func detachSurface() {
        terminalTextView?.onInputData = nil
        attachedSurface = nil
        embeddedSurfaceView?.removeFromSuperview()
        embeddedSurfaceView = nil
        terminalTextView = nil
        updateLayerStyle()
    }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutEmbeddedSurfaceView()
        onResize?(newSize)
    }

    public override func layout() {
        super.layout()
        layoutEmbeddedSurfaceView()
        onResize?(bounds.size)
    }

    public func focusTerminal() {
        guard let terminalTextView else { return }
        window?.makeFirstResponder(terminalTextView)
    }

    @discardableResult
    private func ensureEmbeddedSurfaceView() -> TerminalTextView {
        if let terminalTextView {
            return terminalTextView
        }

        let scrollView = NSScrollView(frame: bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false

        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let textView = TerminalTextView(frame: NSRect(origin: NSPoint.zero, size: contentSize), textContainer: textContainer)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = NSView.AutoresizingMask(rawValue: NSView.AutoresizingMask.width.rawValue)
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.applyAppearance(terminalAppearance)

        scrollView.documentView = textView
        addSubview(scrollView)
        embeddedSurfaceView = scrollView
        terminalTextView = textView
        return textView
    }

    private func updateLayerStyle() {
        layer?.backgroundColor = NSColor(hex: terminalAppearance.backgroundHex).cgColor
        layer?.borderWidth = isActiveTerminalHost ? 1 : 0
        layer?.borderColor = NSColor(hex: NordTheme.activeBorder.hex).cgColor
    }

    private func layoutEmbeddedSurfaceView() {
        embeddedSurfaceView?.frame = bounds

        guard let scrollView = embeddedSurfaceView as? NSScrollView,
              let textView = terminalTextView
        else {
            return
        }

        let contentSize = scrollView.contentSize
        let width = max(contentSize.width, 1)
        let height = max(contentSize.height, 1)

        textView.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.minSize = NSSize(width: 0, height: height)

        let usedHeight = textView.textContainer.flatMap { container in
            textView.layoutManager?.usedRect(for: container).height
        } ?? 0
        let fittedHeight = max(height, ceil(usedHeight + (textView.textContainerInset.height * 2)))

        textView.frame = NSRect(origin: .zero, size: NSSize(width: width, height: fittedHeight))
    }
}

@MainActor
final class TerminalTextView: NSTextView {
    var onInputData: ((Data) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        isEditable = false
        isSelectable = true
        allowsUndo = false
        drawsBackground = true
        insertionPointColor = .white
        textContainerInset = NSSize(width: 12, height: 12)
        textContainer?.lineFragmentPadding = 0
        font = .monospacedSystemFont(ofSize: 13, weight: .regular)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func applyAppearance(_ appearance: TerminalAppearance) {
        backgroundColor = NSColor(hex: appearance.backgroundHex)
        textColor = NSColor(hex: appearance.foregroundHex)
        insertionPointColor = NSColor(hex: appearance.cursorHex)
        font = NSFont(name: appearance.fontName, size: appearance.fontSize) ?? .monospacedSystemFont(ofSize: appearance.fontSize, weight: .regular)
    }

    func replaceContents(with text: String) {
        string = text
        scrollToEndOfDocument(nil)
    }

    func appendOutput(_ text: String) {
        textStorage?.append(NSAttributedString(string: text, attributes: [.foregroundColor: textColor ?? .textColor]))
        scrollToEndOfDocument(nil)
    }

    override func keyDown(with event: NSEvent) {
        if sendSpecialKey(for: event) { return }
        if let characters = event.characters, let data = characters.data(using: .utf8) {
            onInputData?(data)
            return
        }
        super.keyDown(with: event)
    }

    private func sendSpecialKey(for event: NSEvent) -> Bool {
        let sequence: String?
        switch event.keyCode {
        case 36, 76:
            sequence = "\n"
        case 48:
            sequence = "\t"
        case 51:
            sequence = "\u{7F}"
        case 123:
            sequence = "\u{1B}[D"
        case 124:
            sequence = "\u{1B}[C"
        case 125:
            sequence = "\u{1B}[B"
        case 126:
            sequence = "\u{1B}[A"
        default:
            sequence = nil
        }

        guard let sequence, let data = sequence.data(using: .utf8) else { return false }
        onInputData?(data)
        return true
    }
}

@MainActor
final class TerminalSessionDriver {
    let tabID: UUID
    var onExit: ((Int32?) -> Void)?
    private var tab: WorkspaceTab
    private var appearance: TerminalAppearance
    private let process = Process()
    private let inputPipe = Pipe()
    private let outputPipe = Pipe()
    private var bufferedOutput = ""
    private(set) var isStarted = false
    private(set) var hasExited = false
    private(set) var exitStatus: Int32?
    private weak var textView: TerminalTextView?

    init(tab: WorkspaceTab, appearance: TerminalAppearance) {
        self.tabID = tab.id
        self.tab = tab
        self.appearance = appearance
    }

    var isRunning: Bool {
        isStarted && !hasExited
    }

    func update(tab: WorkspaceTab, appearance: TerminalAppearance) {
        self.tab = tab
        self.appearance = appearance
        textView?.applyAppearance(appearance)
    }

    func startIfNeeded() {
        guard !isStarted else { return }
        isStarted = true
        hasExited = false
        exitStatus = nil

        appendOutput(launchBanner())

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: tab.workingDirectory, isDirectory: &isDirectory), isDirectory.boolValue else {
            hasExited = true
            appendOutput("[Directory unavailable: \(tab.workingDirectory)]\n")
            return
        }

        process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        process.currentDirectoryURL = URL(fileURLWithPath: tab.workingDirectory, isDirectory: true)
        process.environment = processEnvironment()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        process.arguments = launchArguments()
        process.qualityOfService = .userInitiated
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                guard let self else { return }
                self.hasExited = true
                self.exitStatus = process.terminationStatus
                self.appendOutput("\n[Process exited with status \(process.terminationStatus)]\n")
                self.onExit?(process.terminationStatus)
            }
        }

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            guard let self else { return }
            Task { @MainActor in
                self.appendOutput(self.sanitizedOutput(from: data))
            }
        }

        do {
            try process.run()
        } catch {
            hasExited = true
            appendOutput("[Terminal process could not start: \(error.localizedDescription)]\n")
        }
    }

    func bind(to textView: TerminalTextView) {
        self.textView = textView
        textView.applyAppearance(appearance)
        textView.replaceContents(with: bufferedOutput)
        textView.onInputData = { [weak self] data in
            self?.sendInput(data)
        }
    }

    func stop() {
        outputPipe.fileHandleForReading.readabilityHandler = nil
        textView?.onInputData = nil
        if process.isRunning {
            process.terminate()
        }
        hasExited = true
    }

    private func sendInput(_ data: Data) {
        guard process.isRunning else { return }
        try? inputPipe.fileHandleForWriting.write(contentsOf: data)
    }

    private func appendOutput(_ text: String) {
        guard !text.isEmpty else { return }
        bufferedOutput.append(text)
        textView?.appendOutput(text)
    }

    private func launchArguments() -> [String] {
        let shellPath = preferredShellPath()

        if let commandLine = launchCommandLine() {
            return ["-q", "/dev/null", shellPath, "-ilc", commandLine]
        }

        return ["-q", "/dev/null", shellPath, "-il"]
    }

    private func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["SHELL"] = preferredShellPath()
        environment["TERM"] = environment["TERM"] ?? "xterm-256color"
        environment["COLORTERM"] = environment["COLORTERM"] ?? "truecolor"
        return environment
    }

    private func launchBanner() -> String {
        let commandDescription = resolvedCommandDescription()

        return "Another ADE terminal\nWorking directory: \(tab.workingDirectory)\nCommand: \(commandDescription)\n\n"
    }

    private func sanitizedOutput(from data: Data) -> String {
        let rawString = String(decoding: data, as: UTF8.self)
        var sanitized = rawString.replacingOccurrences(of: "\r", with: "")
        sanitized = sanitized.replacingOccurrences(of: "\u{001B}\\[[0-?]*[ -/]*[@-~]", with: "", options: .regularExpression)
        sanitized = sanitized.replacingOccurrences(of: "\u{001B}\\][^\u{0007}]*\u{0007}", with: "", options: .regularExpression)
        return sanitized
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
        let environmentTokens = launchEnvironmentOverrides(for: command)
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

        return arguments
    }

    private func launchEnvironmentOverrides(for command: String) -> [String: String] {
        let executableName = URL(fileURLWithPath: command).lastPathComponent.lowercased()

        if executableName == "claude" {
            return ["CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN": "1"]
        }

        return [:]
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
