import AppKit
import Foundation
@preconcurrency import CGhostty

struct CGhosttyRuntime: Sendable {
    struct AppContext: Equatable, Sendable {
        let id: UInt64
    }

    struct Surface: Sendable {
        let id: UInt64
        let appContextID: UInt64
        let inheritedSurfaceID: UInt64?
        let usesNativeRenderer: Bool
        fileprivate var rawValue: ade_ghostty_surface_t
    }

    enum KeyAction: Sendable {
        case release
        case press
        case repeatKey

        var cValue: ade_ghostty_key_action_t {
            switch self {
            case .release:
                ADE_GHOSTTY_KEY_RELEASE
            case .press:
                ADE_GHOSTTY_KEY_PRESS
            case .repeatKey:
                ADE_GHOSTTY_KEY_REPEAT
            }
        }
    }

    struct KeyEvent: Sendable {
        var action: KeyAction
        var modifiers: UInt32
        var consumedModifiers: UInt32
        var keyCode: UInt32
        var text: String?
        var unshiftedCodepoint: UInt32
        var composing: Bool
    }

    static let pinnedRevision = String(cString: ade_ghostty_pinned_revision())
    static var initializeCallCount: UInt64 { ade_ghostty_initialize_call_count() }

    static func resetForTesting() {
        ade_ghostty_reset_for_testing()
    }

    private let forceInitializationFailure: Bool
    private let forceSurfaceCreationFailure: Bool

    init(forceInitializationFailure: Bool = false, forceSurfaceCreationFailure: Bool = false) {
        self.forceInitializationFailure = forceInitializationFailure
        self.forceSurfaceCreationFailure = forceSurfaceCreationFailure
    }

    func initialize() throws -> AppContext {
        let result = ade_ghostty_initialize(forceInitializationFailure)
        guard result.code == ADE_GHOSTTY_OK else {
            throw mapError(code: result.code, message: result.message)
        }
        return AppContext(id: result.app_context.id)
    }

    @MainActor
    func createSurface(
        appContext: AppContext,
        configuration: GhosttyLaunchConfiguration,
        inheritedSurfaceID: UInt64?,
        nativeView: NSView
    ) throws -> Surface {
        let argumentsJSON = String(data: try JSONEncoder().encode(configuration.arguments), encoding: .utf8) ?? "[]"
        let environmentJSON = String(data: try JSONEncoder().encode(configuration.environment), encoding: .utf8) ?? "{}"
        let inherited = inheritedSurfaceID.map(String.init)
        let commandLine = ghosttyCommandLine(configuration: configuration)
        let metrics = nativeSurfaceMetrics(for: nativeView)
        let nativeViewPointer = Unmanaged.passUnretained(nativeView).toOpaque()
        let result = configuration.workingDirectory.withCString { workingDirectoryPointer in
            withOptionalCString(commandLine) { commandPointer in
                argumentsJSON.withCString { argumentsPointer in
                    environmentJSON.withCString { environmentPointer in
                        withOptionalCString(inherited) { inheritedPointer in
                            ade_ghostty_create_surface(
                                ade_ghostty_app_context_t(id: appContext.id),
                                workingDirectoryPointer,
                                commandPointer,
                                argumentsPointer,
                                environmentPointer,
                                inheritedPointer,
                                nativeViewPointer,
                                metrics.scaleFactor,
                                metrics.widthPixels,
                                metrics.heightPixels,
                                Float(configuration.appearance.fontSize),
                                forceSurfaceCreationFailure
                            )
                        }
                    }
                }
            }
        }

        guard result.code == ADE_GHOSTTY_OK else {
            throw mapError(code: result.code, message: result.message)
        }

        return Surface(
            id: result.surface.id,
            appContextID: result.surface.app_context_id,
            inheritedSurfaceID: result.surface.has_inherited_context ? result.surface.inherited_surface_id : nil,
            usesNativeRenderer: result.surface.uses_native_renderer,
            rawValue: result.surface
        )
    }

    func focus(surface: inout Surface, focused: Bool) {
        ade_ghostty_focus_surface(&surface.rawValue, focused)
    }

    @MainActor
    func resize(surface: inout Surface, columns: Int, rows: Int, nativeView: NSView?) {
        let metrics = nativeView.map { nativeSurfaceMetrics(for: $0) } ?? NativeSurfaceMetrics(widthPixels: 1, heightPixels: 1, scaleFactor: 1)
        ade_ghostty_resize_surface(
            &surface.rawValue,
            Int32(columns),
            Int32(rows),
            metrics.widthPixels,
            metrics.heightPixels,
            metrics.scaleFactor
        )
    }

    func canClose(surface: Surface) -> Bool {
        ade_ghostty_surface_can_close(surface.rawValue)
    }

    func hasExited(surface: Surface) -> Bool {
        ade_ghostty_surface_has_exited(surface.rawValue)
    }

    func exitStatus(surface: Surface) -> Int32 {
        ade_ghostty_surface_exit_status(surface.rawValue)
    }

    func destroy(surface: inout Surface) {
        ade_ghostty_destroy_surface(&surface.rawValue)
    }

    func tick(appContext: AppContext) {
        ade_ghostty_tick_app(ade_ghostty_app_context_t(id: appContext.id))
    }

    func draw(surface: Surface) {
        ade_ghostty_draw_surface(surface.rawValue)
    }

    func sendKey(surface: Surface, event: KeyEvent) -> Bool {
        var cEvent = ade_ghostty_key_event_t()
        cEvent.action = event.action.cValue
        cEvent.mods = ade_ghostty_key_mods_t(event.modifiers)
        cEvent.consumed_mods = ade_ghostty_key_mods_t(event.consumedModifiers)
        cEvent.keycode = event.keyCode
        cEvent.unshifted_codepoint = event.unshiftedCodepoint
        cEvent.composing = event.composing

        if let text = event.text {
            return text.withCString { textPointer in
                cEvent.text = textPointer
                return ade_ghostty_send_key(surface.rawValue, cEvent)
            }
        }

        cEvent.text = nil
        return ade_ghostty_send_key(surface.rawValue, cEvent)
    }

    func sendText(surface: Surface, text: String) {
        guard !text.isEmpty else { return }
        text.withCString { textPointer in
            ade_ghostty_send_text(surface.rawValue, textPointer, UInt(text.utf8.count))
        }
    }

    private func mapError(code: ade_ghostty_error_code_t, message: UnsafePointer<CChar>?) -> GhosttyAdapterError {
        let message = message.map(String.init(cString:)) ?? "Unknown Ghostty failure"
        switch code {
        case ADE_GHOSTTY_INIT_FAILED:
            return .initializationFailed(message)
        case ADE_GHOSTTY_SURFACE_CREATE_FAILED:
            return .surfaceCreationFailed(message)
        case ADE_GHOSTTY_INVALID_APP_CONTEXT:
            return .invalidAppContext(message)
        default:
            return .unknown(message)
        }
    }
}

private struct NativeSurfaceMetrics {
    var widthPixels: UInt32
    var heightPixels: UInt32
    var scaleFactor: Double
}

@MainActor
private func nativeSurfaceMetrics(for view: NSView) -> NativeSurfaceMetrics {
    let scaleFactor = view.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
    let backingBounds = view.convertToBacking(view.bounds)
    return NativeSurfaceMetrics(
        widthPixels: UInt32(max(backingBounds.width.rounded(), 1)),
        heightPixels: UInt32(max(backingBounds.height.rounded(), 1)),
        scaleFactor: scaleFactor
    )
}

private func ghosttyCommandLine(configuration: GhosttyLaunchConfiguration) -> String? {
    if let nativeCommand = configuration.nativeCommand, !nativeCommand.isEmpty {
        return nativeCommand
    }

    guard let command = configuration.command, !command.isEmpty else { return nil }
    return ([command] + configuration.arguments)
        .map(shellQuoted)
        .joined(separator: " ")
}

private func shellQuoted(_ argument: String) -> String {
    guard !argument.isEmpty else { return "''" }

    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_+-./:=@")
    if argument.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
        return argument
    }

    return "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

private func withOptionalCString<Result>(
    _ string: String?,
    _ body: (UnsafePointer<CChar>?) -> Result
) -> Result {
    guard let string else { return body(nil) }
    return string.withCString(body)
}
