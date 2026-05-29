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
    private let fileAccess: any WorkspaceFileAccessing
    private let fileBufferManager: any WorkspaceFileBufferManaging
    private let externalEditorOpener: any ExternalEditorOpening
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
        fileAccess: (any WorkspaceFileAccessing)? = nil,
        fileBufferManager: (any WorkspaceFileBufferManaging)? = nil,
        externalEditorOpener: (any ExternalEditorOpening)? = nil,
        fileManager: FileManager = .default,
        logger: WorkspaceLogger = WorkspaceLogger(),
        metrics: PerformanceMetrics = PerformanceMetrics(),
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        let resolvedFileAccess = fileAccess ?? LocalWorkspaceFileAccess(fileManager: fileManager)
        self.store = store
        self.persistenceStore = persistenceStore
        self.restoreCoordinator = restoreCoordinator
        self.terminalSurfaceManager = terminalSurfaceManager
        self.fileAccess = resolvedFileAccess
        self.fileBufferManager = fileBufferManager ?? WorkspaceFileBufferController(fileAccess: resolvedFileAccess, now: now)
        self.externalEditorOpener = externalEditorOpener ?? SystemExternalEditorOpener()
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
            if existing.bookmarkData == nil {
                existing.bookmarkData = projectBookmarkData(for: standardizedPath)
            }
            project = existing
            reusedProject = true
        } else if var persistedProject = try await persistedProject(matchingPath: standardizedPath) {
            persistedProject.lastOpenedAt = timestamp
            if persistedProject.bookmarkData == nil {
                persistedProject.bookmarkData = projectBookmarkData(for: standardizedPath)
            }
            project = persistedProject
            reusedProject = true
        } else {
            project = WorkspaceProject(
                path: standardizedPath,
                bookmarkData: projectBookmarkData(for: standardizedPath),
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
        let removedTerminalTabs = removedTabs.filter { $0.kind == .terminal }
        for tab in removedTerminalTabs {
            if let surface = terminalSurface(for: tab) {
                guard await terminalSurfaceManager.canClose(surface: surface) else {
                    throw WorkspaceCommandError.closeRejected(tab.id)
                }
            }
        }
        let removedTerminalTabIDs = Set(removedTerminalTabs.map(\.id))

        try await persist { try await persistenceStore.deleteProject(id: id) }
        for tab in removedTabs where tab.kind == .file {
            fileBufferManager.discardBuffer(tabID: tab.id)
        }
        for tab in removedTerminalTabs {
            releaseTerminalSurface(for: tab)
        }
        surfacesByTabID = surfacesByTabID.filter { tabID, _ in !removedTerminalTabIDs.contains(tabID) }
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

        let removedTerminalTabs = store.terminalTabs(in: id)
        let removedFileTabs = store.fileTabs(in: id)

        try await persist { try await persistenceStore.deleteSession(id: id) }
        for tab in removedFileTabs {
            fileBufferManager.discardBuffer(tabID: tab.id)
        }
        for tab in removedTerminalTabs {
            releaseTerminalSurface(for: tab)
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

    public func openFileTab(sessionID: UUID, path: String) async throws -> WorkspaceTab {
        guard let session = store.sessions.first(where: { $0.id == sessionID }) else {
            throw WorkspaceCommandError.missingSession(sessionID)
        }
        guard let project = store.projects.first(where: { $0.id == session.projectID }) else {
            throw WorkspaceCommandError.missingProject(session.projectID)
        }

        let fileReference: WorkspaceFileReference
        do {
            fileReference = try await fileAccess.validatedFileReference(path: path, projectRoot: project.path)
        } catch let error as WorkspaceFileAccessError {
            throw commandError(for: error)
        }

        if let existingTab = store.fileTabs(in: session.id).first(where: { tab in
            guard let existingReference = tab.fileReference else { return false }
            return existingReference.path == fileReference.path
        }) {
            try await loadFileBuffer(for: existingTab)
            try await activateSelection { $0.selectTab(id: existingTab.id) }
            return store.tab(id: existingTab.id) ?? existingTab
        }

        let timestamp = now()
        let tab = WorkspaceTab(
            sessionID: session.id,
            kind: .file,
            workingDirectory: fileReference.projectRoot,
            fileReference: fileReference,
            ordinal: store.nextTabOrdinal(for: session.id),
            createdAt: timestamp,
            lastActivatedAt: timestamp
        )

        try await loadFileBuffer(for: tab)
        try await persist { try await persistenceStore.save(tab: tab) }
        store.upsertTab(tab)
        try await persistSnapshot()
        logger.emit("file_tab_opened", fields: [
            "project_id": project.id.uuidString,
            "session_id": session.id.uuidString,
            "tab_id": tab.id.uuidString,
            "hashed_path": WorkspacePrivacy.hashIdentifier(fileReference.path)
        ])
        return tab
    }

    public func saveFileTab(tabID: UUID) async throws {
        let tab = try requireFileTab(id: tabID)
        try await validateFileAccess(for: tab)
        if fileBufferManager.buffer(for: tabID) == nil {
            try await loadFileBuffer(for: tab)
        }
        do {
            try await fileBufferManager.saveBuffer(tabID: tabID)
        } catch let error as WorkspaceFileAccessError {
            throw commandError(for: error)
        } catch let error as WorkspaceFileBufferError {
            throw commandError(for: error)
        }
        logger.emit("file_tab_saved", fields: [
            "tab_id": tab.id.uuidString,
            "session_id": tab.sessionID.uuidString,
            "hashed_path": WorkspacePrivacy.hashIdentifier(tab.fileReference?.path ?? tab.workingDirectory)
        ])
    }

    public func revertFileTab(tabID: UUID) async throws {
        let tab = try requireFileTab(id: tabID)
        try await validateFileAccess(for: tab)
        do {
            try await fileBufferManager.revertBuffer(for: tab)
        } catch let error as WorkspaceFileAccessError {
            throw commandError(for: error)
        } catch let error as WorkspaceFileBufferError {
            throw commandError(for: error)
        }
        logger.emit("file_tab_reverted", fields: [
            "tab_id": tab.id.uuidString,
            "session_id": tab.sessionID.uuidString,
            "hashed_path": WorkspacePrivacy.hashIdentifier(tab.fileReference?.path ?? tab.workingDirectory)
        ])
    }

    public func openFileInExternalEditor(tabID: UUID) async throws {
        let tab = try requireFileTab(id: tabID)
        let fileReference = try await validateFileAccess(for: tab)
        do {
            try await externalEditorOpener.openFile(at: fileReference.path)
        } catch let error as WorkspaceFileAccessError {
            throw commandError(for: error)
        } catch let error as ExternalEditorError {
            throw WorkspaceCommandError.externalEditorFailed(String(describing: error))
        } catch {
            throw WorkspaceCommandError.externalEditorFailed(String(describing: error))
        }
        logger.emit("external_editor_opened", fields: [
            "tab_id": tab.id.uuidString,
            "session_id": tab.sessionID.uuidString,
            "hashed_path": WorkspacePrivacy.hashIdentifier(fileReference.path)
        ])
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
        for tab in store.tabs where tab.kind == .terminal {
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
        for tab in store.tabs where tab.kind == .file {
            do {
                try await loadFileBuffer(for: tab)
            } catch {
                restoreResult.diagnostics.append(RestoreDiagnostic(
                    severity: .warning,
                    message: "File buffer for restored tab \(tab.id.uuidString) could not be loaded: \(String(describing: error))"
                ))
                logger.emit("file_tab_restore_failed", fields: [
                    "tab_id": tab.id.uuidString,
                    "session_id": tab.sessionID.uuidString,
                    "reason": String(describing: error)
                ])
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
        guard let tab = store.tab(id: tabID) else {
            throw WorkspaceCommandError.missingTab(tabID)
        }
        let surface = terminalSurface(for: tab)
        if tab.kind == .terminal, !force, let surface {
            let canClose = await terminalSurfaceManager.canClose(surface: surface)
            metrics.recordCloseConfirmation(accepted: canClose)
            guard canClose else { throw WorkspaceCommandError.closeRejected(tabID) }
        }

        try await persist { try await persistenceStore.deleteTab(id: tabID) }
        if tab.kind == .file {
            fileBufferManager.discardBuffer(tabID: tabID)
        }
        releaseTerminalSurface(for: tab)
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

    private func requireFileTab(id tabID: UUID) throws -> WorkspaceTab {
        guard let tab = store.tab(id: tabID) else {
            throw WorkspaceCommandError.missingTab(tabID)
        }
        guard tab.kind == .file else {
            throw WorkspaceCommandError.invalidFileTab(tabID, "Terminal tabs do not support file commands")
        }
        guard tab.fileReference != nil else {
            throw WorkspaceCommandError.invalidFileTab(tabID, "File tab is missing file metadata")
        }
        return tab
    }

    @discardableResult
    private func validateFileAccess(for tab: WorkspaceTab) async throws -> WorkspaceFileReference {
        guard let fileReference = tab.fileReference else {
            throw WorkspaceCommandError.invalidFileTab(tab.id, "File tab is missing file metadata")
        }
        do {
            return try await fileAccess.validatedFileReference(
                path: fileReference.path,
                projectRoot: fileReference.projectRoot
            )
        } catch let error as WorkspaceFileAccessError {
            throw commandError(for: error)
        }
    }

    private func loadFileBuffer(for tab: WorkspaceTab) async throws {
        do {
            try await fileBufferManager.loadBuffer(for: tab)
        } catch let error as WorkspaceFileAccessError {
            throw commandError(for: error)
        } catch let error as WorkspaceFileBufferError {
            throw commandError(for: error)
        }
    }

    private func commandError(for error: WorkspaceFileAccessError) -> WorkspaceCommandError {
        switch error {
        case .invalidProjectRoot(let path):
            return .invalidProjectPath(path)
        case .invalidFilePath(let path), .unreadableFile(let path):
            return .invalidFilePath(path)
        case .filePathOutsideProject(let filePath, let projectRoot):
            return .filePathOutsideProject(filePath: filePath, projectRoot: projectRoot)
        case .unwritableFile, .unsupportedFile, .enumerationFailed, .writeFailed:
            return .fileAccessRejected(error)
        }
    }

    private func commandError(for error: WorkspaceFileBufferError) -> WorkspaceCommandError {
        switch error {
        case .invalidFileTab(let tabID, let reason):
            return .invalidFileTab(tabID, reason)
        case .missingBuffer(let tabID):
            return .fileBufferUnavailable(tabID)
        }
    }

    private func projectBookmarkData(for path: String) -> Data? {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        #if os(macOS)
        if let data = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil),
           !data.isEmpty {
            return data
        }
        #endif
        if let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil),
           !data.isEmpty {
            return data
        }
        return nil
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
        guard tab.kind == .terminal else {
            throw WorkspaceCommandError.invalidFileTab(tab.id, "File tabs do not support terminal surfaces")
        }

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

    private func terminalSurface(for tab: WorkspaceTab) -> GhosttySurfaceHandle? {
        guard tab.kind == .terminal else { return nil }
        return surfacesByTabID[tab.id] ?? terminalSurfaceManager.surface(for: tab.id)
    }

    private func releaseTerminalSurface(for tab: WorkspaceTab) {
        guard tab.kind == .terminal else { return }
        surfacesByTabID[tab.id] = nil
        terminalSurfaceManager.releaseSurface(for: tab.id)
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
