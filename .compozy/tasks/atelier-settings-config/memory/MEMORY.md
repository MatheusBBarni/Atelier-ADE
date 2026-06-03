# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State

## Shared Decisions

## Shared Learnings
- Do not make portable-settings file-store tests depend on JSON object key order. Foundation `JSONEncoder` did not preserve top-level keyed-container order in task 01; assert semantic keys/values and order-sensitive arrays instead.
- `PortableSettingsConfig.keybindingsSectionPresent` distinguishes an omitted keybindings section from an explicit empty `keybindings: []`; omitted means skip/preserve local runtime overrides, explicit empty means apply the section and clear managed overrides.
- Task 03 added `DefaultWorkspaceCommandService.applyPortableSettingsConfig(_:)` as the shared runtime projection/persist seam for later startup, reload, and save/export wiring.
- Task 04 made `loadAppPreferences()` file-authoritative once the portable config exists; tests that intend to verify normal settings changes should use `saveAppPreferences(_:)` or explicitly isolate/remove the portable file rather than writing SQLite preferences directly.
- Test services that may load or save preferences should inject a temp `PortableSettingsFileStore` so they do not touch the real XDG config path.

## Open Risks

## Handoffs
