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
        fileprivate var rawValue: ade_ghostty_surface_t
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

    func createSurface(
        appContext: AppContext,
        configuration: GhosttyLaunchConfiguration,
        inheritedSurfaceID: UInt64?
    ) throws -> Surface {
        let argumentsJSON = String(data: try JSONEncoder().encode(configuration.arguments), encoding: .utf8) ?? "[]"
        let inherited = inheritedSurfaceID.map(String.init)
        let result = configuration.workingDirectory.withCString { workingDirectoryPointer in
            withOptionalCString(configuration.command) { commandPointer in
                argumentsJSON.withCString { argumentsPointer in
                    withOptionalCString(inherited) { inheritedPointer in
                        ade_ghostty_create_surface(
                            ade_ghostty_app_context_t(id: appContext.id),
                            workingDirectoryPointer,
                            commandPointer,
                            argumentsPointer,
                            inheritedPointer,
                            forceSurfaceCreationFailure
                        )
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
            rawValue: result.surface
        )
    }

    func focus(surface: inout Surface, focused: Bool) {
        ade_ghostty_focus_surface(&surface.rawValue, focused)
    }

    func resize(surface: inout Surface, columns: Int, rows: Int) {
        ade_ghostty_resize_surface(&surface.rawValue, Int32(columns), Int32(rows))
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

private func withOptionalCString<Result>(
    _ string: String?,
    _ body: (UnsafePointer<CChar>?) -> Result
) -> Result {
    guard let string else { return body(nil) }
    return string.withCString(body)
}
