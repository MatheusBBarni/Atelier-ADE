import Foundation

@MainActor
public protocol WorkspaceTerminalSurfaceManaging: AnyObject {
    func createSurface(for tab: WorkspaceTab) async throws -> GhosttySurfaceHandle
    func surface(for tabID: UUID) -> GhosttySurfaceHandle?
    func canClose(surface: GhosttySurfaceHandle) async -> Bool
    func focus(tabID: UUID)
    func resize(tabID: UUID, columns: Int, rows: Int)
    func hasExited(tabID: UUID) async -> Bool
    func releaseSurface(for tabID: UUID)
}

@MainActor
public final class DefaultWorkspaceCommandService: WorkspaceCommandService {
    private let store: WorkspaceStore
    private let persistenceStore: any WorkspacePersistenceStore
    private let restoreCoordinator: RestoreCoordinator
    private let terminalSurfaceManager: any WorkspaceTerminalSurfaceManaging
    private let fileManager: FileManager
    public let logger: WorkspaceLogger
    public let metrics: PerformanceMetrics
    private let now: @MainActor () -> Date
    private var surfacesByTabID: [UUID: GhosttySurfaceHandle] = [:]

    public init(
        store: WorkspaceStore,
        persistenceStore: any WorkspacePersistenceStore,
        restoreCoordinator: RestoreCoordinator,
        terminalSurfaceManager: any WorkspaceTerminalSurfaceManaging,
        fileManager: FileManager = .default,
        logger: WorkspaceLogger = WorkspaceLogger(),
        metrics: PerformanceMetrics = PerformanceMetrics(),
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        self.store = store
        self.persistenceStore = persistenceStore
        self.restoreCoordinator = restoreCoordinator
        self.terminalSurfaceManager = terminalSurfaceManager
        self.fileManager = fileManager
        self.logger = logger
        self.metrics = metrics
        self.now = now
    }

    public func openProject(path: String) async throws -> WorkspaceProject {
        let startedAt = now()
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        guard standardizedPath.hasPrefix("/"), directoryExists(at: standardizedPath) else {
            throw WorkspaceCommandError.invalidProjectPath(path)
        }

        let timestamp = now()
        let project: WorkspaceProject
        let reusedProject: Bool
        if var existing = store.project(matchingPath: standardizedPath) {
            existing.lastOpenedAt = timestamp
            project = existing
            reusedProject = true
        } else if var persistedProject = try await persistedProject(matchingPath: standardizedPath) {
            persistedProject.lastOpenedAt = timestamp
            project = persistedProject
            reusedProject = true
        } else {
            project = WorkspaceProject(
                path: standardizedPath,
                displayName: URL(fileURLWithPath: standardizedPath).lastPathComponent,
                createdAt: timestamp,
                lastOpenedAt: timestamp,
                sortIndex: store.projects.count
            )
            reusedProject = false
        }

        try await persist { try await persistenceStore.save(project: project) }
        store.upsertProject(project)
        try await persistSnapshot()
        metrics.recordProjectOpen(duration: now().timeIntervalSince(startedAt))
        logger.emit("project_opened", fields: [
            "project_id": project.id.uuidString,
            "hashed_path": WorkspacePrivacy.hashIdentifier(project.path),
            "reused_project": String(reusedProject)
        ])
        return project
    }

    public func removeProject(id: UUID) async throws {
        guard store.projects.contains(where: { $0.id == id }) else {
            let persistedProjects = try await persist { try await persistenceStore.loadProjects() }
            guard persistedProjects.contains(where: { $0.id == id }) else {
                throw WorkspaceCommandError.missingProject(id)
            }
            try await persist { try await persistenceStore.deleteProject(id: id) }
            try await persistSnapshot()
            return
        }

        let removedSessionIDs = Set(store.sessions.filter { $0.projectID == id }.map(\.id))
        let removedTabs = store.tabs.filter { removedSessionIDs.contains($0.sessionID) }
        for tab in removedTabs {
            if let surface = surfacesByTabID[tab.id] ?? terminalSurfaceManager.surface(for: tab.id) {
                guard await terminalSurfaceManager.canClose(surface: surface) else {
                    throw WorkspaceCommandError.closeRejected(tab.id)
                }
            }
        }
        let removedTabIDs = Set(removedTabs.map(\.id))

        try await persist { try await persistenceStore.deleteProject(id: id) }
        for tabID in removedTabIDs {
            terminalSurfaceManager.releaseSurface(for: tabID)
        }
        surfacesByTabID = surfacesByTabID.filter { tabID, _ in !removedTabIDs.contains(tabID) }
        store.removeProject(id: id)
        try await persistSnapshot()
    }

    public func removeSession(id: UUID) async throws {
        guard store.sessions.contains(where: { $0.id == id }) else {
            let persistedSessions = try await persist { try await persistenceStore.loadSessions() }
            guard persistedSessions.contains(where: { $0.id == id }) else {
                throw WorkspaceCommandError.missingSession(id)
            }
            try await persist { try await persistenceStore.deleteSession(id: id) }
            try await persistSnapshot()
            return
        }

        let removedTabs = store.tabs.filter { $0.sessionID == id }

        try await persist { try await persistenceStore.deleteSession(id: id) }
        for tab in removedTabs {
            terminalSurfaceManager.releaseSurface(for: tab.id)
            surfacesByTabID[tab.id] = nil
        }
        store.removeSession(id: id)
        try await persistSnapshot()
    }

    public func selectProject(id: UUID?) async throws {
        if let id, !store.projects.contains(where: { $0.id == id }) {
            throw WorkspaceCommandError.missingProject(id)
        }
        try await activateSelection { $0.selectProject(id: id) }
    }

    public func selectSession(id: UUID?) async throws {
        if let id, !store.sessions.contains(where: { $0.id == id }) {
            throw WorkspaceCommandError.missingSession(id)
        }
        try await activateSelection { $0.selectSession(id: id) }
    }

    public func selectTab(id: UUID?) async throws {
        if let id, !store.tabs.contains(where: { $0.id == id }) {
            throw WorkspaceCommandError.missingTab(id)
        }
        try await activateSelection { $0.selectTab(id: id) }
    }

    public func recordSettingsOpened(surface: String) {
        metrics.recordSettingsOpened()
        logger.emit("settings_opened", fields: [
            "surface": surface,
            "selected_project_id_present": String(store.selectedProjectID != nil)
        ])
    }

    public func loadAppPreferences() async throws -> AppPreferences {
        let preferences = try await loadNormalizedAppPreferences(healStaleReferences: true)
        store.updateAppPreferences(preferences)
        return preferences
    }

    public func saveAppPreferences(_ preferences: AppPreferences) async throws {
        let previousPreferences = store.appPreferences

        do {
            try await validateAppPreferences(preferences)
            var updatedPreferences = preferences
            updatedPreferences.id = AppPreferences.fixedID
            updatedPreferences.updatedAt = now()

            try await persistBuiltInDefaultShortcutIfNeeded(for: updatedPreferences)
            try await persist { try await persistenceStore.save(appPreferences: updatedPreferences) }
            store.updateAppPreferences(updatedPreferences)

            let changedKeybindingIDs = changedManagedKeybindingIDs(
                from: previousPreferences,
                to: updatedPreferences
            )
            metrics.recordSettingsSaved(changedKeybindingCount: updatedPreferences.keybindings.count)
            logger.emit("settings_saved", fields: [
                "theme_id": updatedPreferences.themeID,
                "default_profile_id": updatedPreferences.defaultSessionShortcutID?.uuidString ?? "none",
                "changed_keybinding_count": String(updatedPreferences.keybindings.count)
            ])

            if previousPreferences.themeID != updatedPreferences.themeID {
                metrics.recordThemeChanged()
                logger.emit("theme_applied", fields: [
                    "theme_id": updatedPreferences.themeID
                ])
            }

            if !changedKeybindingIDs.isEmpty {
                metrics.recordKeybindingsChanged(changedCommandCount: changedKeybindingIDs.count)
                logger.emit("keybinding_changed", fields: [
                    "changed_keybinding_count": String(changedKeybindingIDs.count),
                    "command_ids": changedKeybindingIDs.map(\.rawValue).joined(separator: ",")
                ])
            }
        } catch {
            recordSettingsSaveFailure(error)
            throw error
        }
    }

    public func availableSessionShortcuts() async throws -> [SessionShortcut] {
        try await loadSessionShortcutsIncludingBuiltIns()
    }

    public func saveSessionShortcut(_ shortcut: SessionShortcut) async throws -> SessionShortcut {
        try validateLaunchArgumentsJSON(shortcut.launchArgumentsJSON, shortcutID: shortcut.id)
        let savedShortcut = normalizedShortcutForSave(shortcut)

        try await persist { try await persistenceStore.save(shortcut: savedShortcut) }
        logger.emit("agent_profile_saved", fields: [
            "shortcut_id": savedShortcut.id.uuidString,
            "is_built_in": String(savedShortcut.isBuiltIn),
            "has_user_override": String(savedShortcut.hasUserOverride)
        ])
        return savedShortcut
    }

    public func deleteSessionShortcut(id: UUID) async throws {
        if Self.canonicalBuiltInShortcut(id: id) != nil {
            throw WorkspaceCommandError.builtInShortcutDeletionRejected(id)
        }

        let shortcuts = try await loadSessionShortcutsIncludingBuiltIns(seedMissingBuiltIns: false)
        guard shortcuts.contains(where: { $0.id == id }) else {
            throw WorkspaceCommandError.missingShortcut(id)
        }
        let preferencesBeforeDelete = try await loadNormalizedAppPreferences(healStaleReferences: true)

        try await persist { try await persistenceStore.deleteShortcut(id: id) }
        let preferencesAfterDelete = try await loadNormalizedAppPreferences(healStaleReferences: true)
        store.updateAppPreferences(preferencesAfterDelete)

        if preferencesBeforeDelete.defaultSessionShortcutID == id {
            logger.emit("default_profile_cleared", fields: [
                "stale_profile_id": id.uuidString,
                "reason": "deleted_profile"
            ])
        }
    }

    public func resetBuiltInSessionShortcut(id: UUID) async throws -> SessionShortcut {
        guard let canonicalShortcut = Self.canonicalBuiltInShortcut(id: id) else {
            let shortcuts = try await loadSessionShortcutsIncludingBuiltIns(seedMissingBuiltIns: false)
            if shortcuts.contains(where: { $0.id == id }) {
                throw WorkspaceCommandError.customShortcutResetRejected(id)
            }
            throw WorkspaceCommandError.missingShortcut(id)
        }

        try validateLaunchArgumentsJSON(canonicalShortcut.launchArgumentsJSON, shortcutID: canonicalShortcut.id)
        try await persist { try await persistenceStore.save(shortcut: canonicalShortcut) }
        logger.emit("agent_profile_reset", fields: [
            "shortcut_id": canonicalShortcut.id.uuidString
        ])
        return canonicalShortcut
    }

    public func createSession(projectID: UUID, shortcutID: UUID?) async throws -> WorkspaceSession {
        let startedAt = now()
        guard store.projects.contains(where: { $0.id == projectID }) else {
            throw WorkspaceCommandError.missingProject(projectID)
        }
        let project = try requireProject(id: projectID)
        let launchIntent = try await resolveLaunchIntent(explicitShortcutID: shortcutID)
        if let shortcut = launchIntent.shortcut {
            try await persist { try await persistenceStore.save(shortcut: shortcut) }
        }

        let timestamp = now()
        let session = WorkspaceSession(
            projectID: projectID,
            shortcutID: launchIntent.shortcutID,
            createdAt: timestamp,
            lastActivatedAt: timestamp
        )
        let firstTab = WorkspaceTab(
            sessionID: session.id,
            workingDirectory: project.path,
            launchCommand: launchIntent.launchCommand,
            launchArgumentsJSON: launchIntent.launchArgumentsJSON,
            ordinal: 0,
            createdAt: timestamp,
            lastActivatedAt: timestamp
        )
        let surface: GhosttySurfaceHandle
        do {
            surface = try await createSurface(for: firstTab)
        } catch {
            metrics.recordTerminalSurfaceFailure()
            logger.emit("terminal_surface_failed", fields: [
                "tab_id": firstTab.id.uuidString,
                "session_id": session.id.uuidString,
                "reason": String(describing: error)
            ])
            throw error
        }
        do {
            try await persist { try await persistenceStore.save(session: session, firstTab: firstTab) }
        } catch {
            terminalSurfaceManager.releaseSurface(for: firstTab.id)
            throw error
        }
        surfacesByTabID[firstTab.id] = surface
        store.upsertSession(session)
        store.upsertTab(firstTab)
        try await persistSnapshot()
        metrics.recordTabCreation(duration: now().timeIntervalSince(startedAt))
        metrics.recordSessionCreate()
        logger.emit("tab_created", fields: tabLogFields(
            projectID: project.id,
            sessionID: session.id,
            tabID: firstTab.id,
            launchIntent: launchIntent,
            startedAt: startedAt
        ))
        logger.emit("session_created", fields: sessionLogFields(
            projectID: projectID,
            sessionID: session.id,
            launchIntent: launchIntent
        ))
        return session
    }

    public func renameSession(sessionID: UUID, title: String) async throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw WorkspaceCommandError.invalidSessionTitle(title)
        }
        guard var session = store.sessions.first(where: { $0.id == sessionID }) else {
            throw WorkspaceCommandError.missingSession(sessionID)
        }

        session.rename(to: trimmedTitle)
        try await persist { try await persistenceStore.save(session: session) }
        store.upsertSession(session, select: store.selectedSessionID == sessionID)
        try await persistSnapshot()
    }

    public func createTab(sessionID: UUID) async throws -> WorkspaceTab {
        let startedAt = now()
        guard let session = store.sessions.first(where: { $0.id == sessionID }) else {
            throw WorkspaceCommandError.missingSession(sessionID)
        }
        guard let project = store.projects.first(where: { $0.id == session.projectID }) else {
            throw WorkspaceCommandError.missingProject(session.projectID)
        }
        let launchIntent = try await resolveStoredLaunchIntent(for: session)

        let timestamp = now()
        let tab = WorkspaceTab(
            sessionID: session.id,
            workingDirectory: project.path,
            launchCommand: launchIntent.launchCommand,
            launchArgumentsJSON: launchIntent.launchArgumentsJSON,
            ordinal: store.nextTabOrdinal(for: session.id),
            createdAt: timestamp,
            lastActivatedAt: timestamp
        )

        let surface: GhosttySurfaceHandle
        do {
            surface = try await createSurface(for: tab)
        } catch {
            metrics.recordTerminalSurfaceFailure()
            logger.emit("terminal_surface_failed", fields: [
                "tab_id": tab.id.uuidString,
                "session_id": session.id.uuidString,
                "reason": String(describing: error)
            ])
            throw error
        }
        do {
            try await persist { try await persistenceStore.save(tab: tab) }
        } catch {
            terminalSurfaceManager.releaseSurface(for: tab.id)
            throw error
        }
        surfacesByTabID[tab.id] = surface
        store.upsertTab(tab)
        try await persistSnapshot()
        metrics.recordTabCreation(duration: now().timeIntervalSince(startedAt))
        logger.emit("tab_created", fields: tabLogFields(
            projectID: project.id,
            sessionID: session.id,
            tabID: tab.id,
            launchIntent: launchIntent,
            startedAt: startedAt
        ))
        return tab
    }

    @discardableResult
    public func restoreWorkspace() async throws -> RestoreWorkspaceResult {
        let startedAt = now()
        logger.emit("restore_started", fields: [:])
        let restoreResultFromCoordinator: RestoreWorkspaceResult
        do {
            restoreResultFromCoordinator = try await persist { try await restoreCoordinator.restoreWorkspace() }
        } catch {
            metrics.recordRestore(duration: now().timeIntervalSince(startedAt), succeeded: false, skippedProjectCount: 0)
            logger.emit("restore_completed", fields: [
                "project_count": "0",
                "session_count": "0",
                "tab_count": "0",
                "skipped_project_count": "0",
                "duration_ms": String(Int((now().timeIntervalSince(startedAt) * 1_000).rounded())),
                "succeeded": "false",
                "reason": String(describing: error)
            ])
            throw error
        }
        var restoreResult = restoreResultFromCoordinator
        let restoredStore = restoreResult.store
        store.restore(
            projects: restoredStore.projects,
            sessions: restoredStore.sessions,
            tabs: restoredStore.tabs,
            selection: restoredStore.selection
        )
        surfacesByTabID.removeAll()
        for tab in store.tabs {
            let surfaceStartedAt = now()
            do {
                let surface = try await createSurface(for: tab)
                surfacesByTabID[tab.id] = surface
                metrics.recordTabCreation(duration: now().timeIntervalSince(surfaceStartedAt))
            } catch {
                metrics.recordTerminalSurfaceFailure()
                logger.emit("terminal_surface_failed", fields: [
                    "tab_id": tab.id.uuidString,
                    "session_id": tab.sessionID.uuidString,
                    "reason": String(describing: error)
                ])
                restoreResult.diagnostics.append(RestoreDiagnostic(
                    severity: .failure,
                    message: "Terminal for restored tab \(tab.id.uuidString) could not be recreated: \(String(describing: error))"
                ))
            }
        }
        for skippedProject in restoreResult.skippedProjects {
            logger.emit("restore_skipped_project", fields: [
                "project_id": skippedProject.id.uuidString,
                "hashed_path": WorkspacePrivacy.hashIdentifier(skippedProject.path),
                "reason": skippedProject.reason
            ])
        }
        let duration = now().timeIntervalSince(startedAt)
        let hasFailure = restoreResult.diagnostics.contains { $0.severity == .failure }
        metrics.recordRestore(
            duration: duration,
            succeeded: !hasFailure,
            skippedProjectCount: restoreResult.skippedProjects.count
        )
        metrics.recordLaunchToReady(duration: duration)
        logger.emit("restore_completed", fields: [
            "project_count": String(store.projects.count),
            "session_count": String(store.sessions.count),
            "tab_count": String(store.tabs.count),
            "skipped_project_count": String(restoreResult.skippedProjects.count),
            "duration_ms": String(Int((duration * 1_000).rounded())),
            "succeeded": String(!hasFailure)
        ])
        return restoreResult
    }

    public func closeTab(tabID: UUID, force: Bool) async throws {
        guard store.tabs.contains(where: { $0.id == tabID }) else {
            throw WorkspaceCommandError.missingTab(tabID)
        }
        let surface = surfacesByTabID[tabID] ?? terminalSurfaceManager.surface(for: tabID)
        if !force, let surface {
            let canClose = await terminalSurfaceManager.canClose(surface: surface)
            metrics.recordCloseConfirmation(accepted: canClose)
            guard canClose else { throw WorkspaceCommandError.closeRejected(tabID) }
        }

        try await persist { try await persistenceStore.deleteTab(id: tabID) }
        surfacesByTabID[tabID] = nil
        terminalSurfaceManager.releaseSurface(for: tabID)
        store.removeTab(id: tabID)
        try await persistSnapshot()
    }

    public func recordTerminalProcessExit(tabID: UUID, exitStatus: Int32? = nil) {
        metrics.recordTerminalProcessExit()
        var fields = [
            "tab_id": tabID.uuidString,
            "exit_status": exitStatus.map(String.init) ?? "unknown"
        ]
        if let tab = store.tabs.first(where: { $0.id == tabID }) {
            fields["session_id"] = tab.sessionID.uuidString
        }
        logger.emit("terminal_process_exited", fields: fields)
    }

    public func recentWorkspaceEvents() -> [WorkspaceLogEvent] {
        logger.events
    }

    public func pilotDiagnostics() -> PilotDiagnostics {
        metrics.diagnostics()
    }

    private func loadSessionShortcutsIncludingBuiltIns(seedMissingBuiltIns: Bool = true) async throws -> [SessionShortcut] {
        let persistedShortcuts = try await persist { try await persistenceStore.loadSessionShortcuts() }
        let persistedByID = Dictionary(uniqueKeysWithValues: persistedShortcuts.map { ($0.id, $0) })
        let builtInIDs = Set(SessionShortcut.builtInDefaults.map(\.id))

        var mergedShortcuts: [SessionShortcut] = []
        for canonicalShortcut in SessionShortcut.builtInDefaults {
            let effectiveShortcut: SessionShortcut
            if let persistedShortcut = persistedByID[canonicalShortcut.id] {
                if persistedShortcut.hasUserOverride {
                    var overriddenShortcut = persistedShortcut
                    overriddenShortcut.isBuiltIn = true
                    effectiveShortcut = overriddenShortcut
                } else {
                    effectiveShortcut = canonicalShortcut
                }
                if seedMissingBuiltIns, effectiveShortcut != persistedShortcut {
                    try await persist { try await persistenceStore.save(shortcut: effectiveShortcut) }
                }
            } else {
                effectiveShortcut = canonicalShortcut
                if seedMissingBuiltIns {
                    try await persist { try await persistenceStore.save(shortcut: canonicalShortcut) }
                }
            }
            mergedShortcuts.append(effectiveShortcut)
        }

        for persistedShortcut in persistedShortcuts where !builtInIDs.contains(persistedShortcut.id) {
            var customShortcut = persistedShortcut
            customShortcut.isBuiltIn = false
            customShortcut.hasUserOverride = false
            if seedMissingBuiltIns, customShortcut != persistedShortcut {
                try await persist { try await persistenceStore.save(shortcut: customShortcut) }
            }
            mergedShortcuts.append(customShortcut)
        }

        return sortSessionShortcuts(mergedShortcuts)
    }

    private func loadNormalizedAppPreferences(healStaleReferences: Bool) async throws -> AppPreferences {
        var preferences = try await persist { try await persistenceStore.loadAppPreferences() }
        var shouldPersistRepair = false

        if !AppPreferences.supportedThemeIDs.contains(preferences.themeID) {
            logger.emit("settings_preference_repaired", fields: [
                "field": "theme_id",
                "theme_id": preferences.themeID,
                "reason": "unknown_theme"
            ])
            preferences.themeID = AppPreferences.defaultThemeID
            shouldPersistRepair = true
        }

        if let defaultShortcutID = preferences.defaultSessionShortcutID {
            let shortcuts = try await loadSessionShortcutsIncludingBuiltIns(seedMissingBuiltIns: false)
            if !shortcuts.contains(where: { $0.id == defaultShortcutID }) {
                logger.emit("default_profile_resolution_failed", fields: [
                    "shortcut_id": defaultShortcutID.uuidString,
                    "reason": "missing_shortcut"
                ])
                logger.emit("default_profile_cleared", fields: [
                    "stale_profile_id": defaultShortcutID.uuidString,
                    "reason": "missing_shortcut"
                ])
                preferences.defaultSessionShortcutID = nil
                shouldPersistRepair = true
            }
        }

        if healStaleReferences, shouldPersistRepair {
            preferences.id = AppPreferences.fixedID
            preferences.updatedAt = now()
            try await persist { try await persistenceStore.save(appPreferences: preferences) }
        }

        return preferences
    }

    private func validateAppPreferences(_ preferences: AppPreferences) async throws {
        guard AppPreferences.supportedThemeIDs.contains(preferences.themeID) else {
            throw WorkspaceCommandError.settingsValidationFailed(.unknownThemeID(preferences.themeID))
        }

        try validateManagedKeybindings(preferences.keybindings)

        if let defaultShortcutID = preferences.defaultSessionShortcutID {
            let shortcuts = try await loadSessionShortcutsIncludingBuiltIns(seedMissingBuiltIns: false)
            guard shortcuts.contains(where: { $0.id == defaultShortcutID }) else {
                throw WorkspaceCommandError.settingsValidationFailed(.unknownDefaultSessionShortcut(defaultShortcutID))
            }
        }
    }

    private func persistBuiltInDefaultShortcutIfNeeded(for preferences: AppPreferences) async throws {
        guard let defaultShortcutID = preferences.defaultSessionShortcutID,
              let canonicalShortcut = Self.canonicalBuiltInShortcut(id: defaultShortcutID)
        else { return }

        let persistedShortcuts = try await persist { try await persistenceStore.loadSessionShortcuts() }
        if !persistedShortcuts.contains(where: { $0.id == defaultShortcutID }) {
            try await persist { try await persistenceStore.save(shortcut: canonicalShortcut) }
        }
    }

    private func validateManagedKeybindings(_ keybindings: [AppCommandID: KeybindingOverride]) throws {
        try AppCommandRegistry.validate(keybindings)
    }

    private func changedManagedKeybindingIDs(
        from previousPreferences: AppPreferences,
        to updatedPreferences: AppPreferences
    ) -> [AppCommandID] {
        AppCommandRegistry.managedCommandIDs.filter { commandID in
            AppCommandRegistry.resolvedKeybinding(for: commandID, preferences: previousPreferences) !=
                AppCommandRegistry.resolvedKeybinding(for: commandID, preferences: updatedPreferences)
        }
    }

    private func recordSettingsSaveFailure(_ error: Error) {
        metrics.recordSettingsSaveFailure()
        let fields = settingsSaveFailureFields(for: error)
        logger.emit("settings_save_failed", fields: fields)

        if case let WorkspaceCommandError.settingsValidationFailed(.duplicateManagedKeybinding(commandID, conflictingCommandID)) = error {
            logger.emit("keybinding_conflict_rejected", fields: [
                "command_id": commandID.rawValue,
                "conflicting_command_id": conflictingCommandID.rawValue
            ])
        }
    }

    private func settingsSaveFailureFields(for error: Error) -> [String: String] {
        guard case let WorkspaceCommandError.settingsValidationFailed(failure) = error else {
            return [
                "reason": String(describing: error),
                "field": "persistence"
            ]
        }

        switch failure {
        case .unknownThemeID(let themeID):
            return [
                "reason": "unknown_theme_id:\(themeID)",
                "field": "theme_id"
            ]
        case .unknownDefaultSessionShortcut(let shortcutID):
            return [
                "reason": "unknown_default_profile:\(shortcutID.uuidString)",
                "field": "default_profile_id"
            ]
        case .duplicateManagedKeybinding(let commandID, let conflictingCommandID):
            return [
                "reason": "duplicate_managed_keybinding:\(commandID.rawValue):\(conflictingCommandID.rawValue)",
                "field": "keybindings"
            ]
        case .mismatchedKeybindingCommandID(let expected, let actual):
            return [
                "reason": "mismatched_keybinding_command_id:\(expected.rawValue):\(actual.rawValue)",
                "field": "keybindings"
            ]
        case .emptyKeybinding(let commandID):
            return [
                "reason": "empty_keybinding:\(commandID.rawValue)",
                "field": "keybindings"
            ]
        case .malformedLaunchArgumentsJSON(let shortcutID):
            return [
                "reason": "malformed_launch_arguments_json:\(shortcutID.uuidString)",
                "field": "launch_arguments_json"
            ]
        }
    }

    private func validateLaunchArgumentsJSON(_ launchArgumentsJSON: String?, shortcutID: UUID) throws {
        guard let launchArgumentsJSON else { return }
        let trimmedJSON = launchArgumentsJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedJSON.isEmpty,
              let data = trimmedJSON.data(using: .utf8),
              (try? JSONDecoder().decode([String].self, from: data)) != nil
        else {
            throw WorkspaceCommandError.settingsValidationFailed(.malformedLaunchArgumentsJSON(shortcutID))
        }
    }

    private func normalizedShortcutForSave(_ shortcut: SessionShortcut) -> SessionShortcut {
        guard let canonicalShortcut = Self.canonicalBuiltInShortcut(id: shortcut.id) else {
            var customShortcut = shortcut
            customShortcut.isBuiltIn = false
            customShortcut.hasUserOverride = false
            return customShortcut
        }

        var builtInShortcut = shortcut
        builtInShortcut.isBuiltIn = true
        builtInShortcut.hasUserOverride = !Self.profileFieldsMatch(builtInShortcut, canonicalShortcut)
        return builtInShortcut
    }

    private func resolveLaunchIntent(explicitShortcutID: UUID?) async throws -> ResolvedLaunchIntent {
        if let explicitShortcutID {
            let shortcuts = try await loadSessionShortcutsIncludingBuiltIns(seedMissingBuiltIns: false)
            guard let shortcut = shortcuts.first(where: { $0.id == explicitShortcutID }) else {
                throw WorkspaceCommandError.missingShortcut(explicitShortcutID)
            }
            return ResolvedLaunchIntent(source: .explicit, shortcut: shortcut)
        }

        let preferences = try await loadNormalizedAppPreferences(healStaleReferences: true)
        store.updateAppPreferences(preferences)
        guard let defaultShortcutID = preferences.defaultSessionShortcutID else {
            return ResolvedLaunchIntent(source: .plain, shortcut: nil)
        }

        let shortcuts = try await loadSessionShortcutsIncludingBuiltIns(seedMissingBuiltIns: false)
        guard let shortcut = shortcuts.first(where: { $0.id == defaultShortcutID }) else {
            logger.emit("default_profile_resolution_failed", fields: [
                "shortcut_id": defaultShortcutID.uuidString,
                "reason": "missing_shortcut"
            ])
            return ResolvedLaunchIntent(source: .plain, shortcut: nil)
        }
        return ResolvedLaunchIntent(source: .savedDefault, shortcut: shortcut)
    }

    private func resolveStoredLaunchIntent(for session: WorkspaceSession) async throws -> ResolvedLaunchIntent {
        guard let shortcutID = session.shortcutID else {
            return ResolvedLaunchIntent(source: .plain, shortcut: nil)
        }

        let shortcuts = try await loadSessionShortcutsIncludingBuiltIns(seedMissingBuiltIns: false)
        guard let shortcut = shortcuts.first(where: { $0.id == shortcutID }) else {
            throw WorkspaceCommandError.missingShortcut(shortcutID)
        }
        return ResolvedLaunchIntent(source: .storedSession, shortcut: shortcut)
    }

    private func sessionLogFields(
        projectID: UUID,
        sessionID: UUID,
        launchIntent: ResolvedLaunchIntent
    ) -> [String: String] {
        var fields = launchIntent.logFields
        fields["project_id"] = projectID.uuidString
        fields["session_id"] = sessionID.uuidString
        return fields
    }

    private func tabLogFields(
        projectID: UUID,
        sessionID: UUID,
        tabID: UUID,
        launchIntent: ResolvedLaunchIntent,
        startedAt: Date
    ) -> [String: String] {
        var fields = launchIntent.logFields
        fields["project_id"] = projectID.uuidString
        fields["session_id"] = sessionID.uuidString
        fields["tab_id"] = tabID.uuidString
        fields["duration_ms"] = String(Int((now().timeIntervalSince(startedAt) * 1_000).rounded()))
        return fields
    }

    private func directoryExists(at path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func requireProject(id: UUID) throws -> WorkspaceProject {
        guard let project = store.projects.first(where: { $0.id == id }) else {
            throw WorkspaceCommandError.missingProject(id)
        }
        return project
    }

    private func persistedProject(matchingPath path: String) async throws -> WorkspaceProject? {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        let persistedProjects = try await persist { try await persistenceStore.loadProjects() }
        return persistedProjects.first {
            URL(fileURLWithPath: $0.path).standardizedFileURL.path == standardizedPath
        }
    }

    private func activateSelection(_ select: (WorkspaceStore) -> Void) async throws {
        let timestamp = now()
        let nextStore = WorkspaceStore(
            projects: store.projects,
            sessions: store.sessions,
            tabs: store.tabs,
            appPreferences: store.appPreferences,
            selectedProjectID: store.selectedProjectID,
            selectedSessionID: store.selectedSessionID,
            selectedTabID: store.selectedTabID
        )
        select(nextStore)
        if let selectedProjectID = nextStore.selectedProjectID {
            nextStore.markProjectOpened(id: selectedProjectID, at: timestamp)
        }
        if let selectedSessionID = nextStore.selectedSessionID {
            nextStore.markSessionActivated(id: selectedSessionID, at: timestamp)
        }
        if let selectedTabID = nextStore.selectedTabID {
            nextStore.markTabActivated(id: selectedTabID, at: timestamp)
        }
        let snapshot = nextStore.snapshot(updatedAt: timestamp)
        try await persist {
            try await persistenceStore.saveActivation(
                project: nextStore.selectedProject,
                session: nextStore.selectedSession,
                tab: nextStore.selectedTab,
                snapshot: snapshot
            )
        }
        store.restore(
            projects: nextStore.projects,
            sessions: nextStore.sessions,
            tabs: nextStore.tabs,
            selection: nextStore.selection
        )
    }

    private func createSurface(for tab: WorkspaceTab) async throws -> GhosttySurfaceHandle {
        do {
            return try await terminalSurfaceManager.createSurface(for: tab)
        } catch let error as GhosttyAdapterError {
            throw error.workspaceCommandError
        } catch let error as WorkspaceCommandError {
            throw error
        } catch {
            throw WorkspaceCommandError.terminalUnavailable(String(describing: error))
        }
    }

    private func persist<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as WorkspaceCommandError {
            throw error
        } catch {
            throw WorkspaceCommandError.persistenceFailed(String(describing: error))
        }
    }

    private func persistSnapshot() async throws {
        let snapshot = store.snapshot(updatedAt: now())
        try await persist { try await persistenceStore.save(snapshot: snapshot) }
    }

    private func sortSessionShortcuts(_ shortcuts: [SessionShortcut]) -> [SessionShortcut] {
        shortcuts.sorted {
            if $0.label == $1.label {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.label < $1.label
        }
    }

    private static func canonicalBuiltInShortcut(id: UUID) -> SessionShortcut? {
        SessionShortcut.builtInDefaults.first { $0.id == id }
    }

    private static func profileFieldsMatch(_ lhs: SessionShortcut, _ rhs: SessionShortcut) -> Bool {
        lhs.label == rhs.label &&
            lhs.launchCommand == rhs.launchCommand &&
            lhs.launchArgumentsJSON == rhs.launchArgumentsJSON &&
            lhs.secretRef == rhs.secretRef
    }
}

private enum LaunchProfileSource: String {
    case explicit
    case savedDefault = "default"
    case plain
    case storedSession = "session"
}

private struct ResolvedLaunchIntent {
    var source: LaunchProfileSource
    var shortcut: SessionShortcut?

    var shortcutID: UUID? { shortcut?.id }
    var launchCommand: String? { shortcut?.launchCommand }
    var launchArgumentsJSON: String? { shortcut?.launchArgumentsJSON }

    var logFields: [String: String] {
        var fields = [
            "launch_profile_source": source.rawValue,
            "launch_profile_label": shortcut?.label ?? "plain"
        ]
        if let shortcut {
            fields["shortcut_id"] = shortcut.id.uuidString
            fields["launch_profile_id"] = shortcut.id.uuidString
        }
        return fields
    }
}
