# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State

## Shared Decisions

## Shared Learnings
- `AtelierApp` deconstructs `AppDependencyContainer` during initialization rather than retaining the container; new container-owned runtime services must be explicitly retained by the app or by a long-lived callback/owner.
- Task 03 retains `TerminalExitEventSource` in `AtelierApp` and passes it into `ContentView`/`ProjectSidebarView`; follow-on sidebar UI work should reuse that injected source instead of reaching back into `AppDependencyContainer`.

## Open Risks

## Handoffs
- `SessionRowView` now accepts `terminalSummaries` for task 03 composition, but visible disclosure/child-row rendering remains scoped to task 04.
