# Tabbed File Explorer

## Overview

Tabbed File Explorer adds a right-side navigation surface for active coders inside Another ADE. It solves a concrete workflow problem: users can move between terminal work and source-file inspection without bouncing constantly to Finder or an external editor. The feature is for solo or small-context-switch developers who spend the day inside a few repositories and need fast access to relevant files while coding.

The value is not a generic IDE clone. The value is a faster, calmer session loop. V1 should be ambitious enough to reduce context switches meaningfully, but disciplined enough to preserve the product’s terminal-first wedge. The selected direction is a hybrid: keep a recognizable file tree in the right sidebar, but make a session-aware working set the primary surface and scope opened files as lightweight preview tabs instead of full editable editor tabs.

### Summary / Differentiator

Most editors already offer file trees and tabs. Another ADE can differentiate by making file navigation session-aware: show the files that matter now, keep them one gesture away from the terminal, and avoid importing the full complexity of an embedded IDE before that contract is justified.

## Problem

Another ADE currently helps users move quickly between projects, sessions, and terminal tabs, but it does not yet support file-level navigation inside the workspace. For active coders, that gap creates a repeated context break. A user may be in the correct project and session, then still need to leave the app to browse files, inspect a source file, compare two related files, or reopen something they touched a few minutes earlier. That extra hop weakens the product’s core promise of speed with confidence.

The problem is not just “there is no file tree.” The deeper problem is that the app currently stops at project and terminal context, while active coding often requires a file working set: the small cluster of files the user is reading, checking, or referencing while they work in the terminal. If Another ADE cannot surface that working set, users will keep a second tool open for orientation, which reintroduces the context-switching cost the product is trying to remove.

This matters because serious coding tools in 2025 already treat file visibility and tabbed file access as baseline ergonomics. The risk is not that Another ADE lacks parity on day one; the risk is that users decide the product is terminal-only workflow polish rather than a place they can stay open all day. At the same time, a naïve “add editable editor tabs” move would overcorrect, pulling the product toward a mini-IDE before the current session-first wedge is fully proven.

### Market Data

- Stack Overflow Developer Survey 2025 reports **75.9%** regular usage for VS Code, with **17.9%** for Cursor, **10%** for Xcode, and **7.3%** for Zed.
- The same survey reports **84%** of developers use or plan to use AI tools in development workflows.
- **45%** report that debugging AI-generated code is more time-consuming, which increases the value of fast local context inspection.
- Competitive review across VS Code, Zed, Nova, JetBrains, and Cursor shows that file explorers and tabs are table stakes; differentiation comes from working-set speed, preview behavior, and low-clutter navigation.
- A right sidebar is viable, but it is not the default market convention. Most products either keep sidebar placement flexible or make the tree secondary to faster navigation tools.

### Integration with Existing Features

| Integration Point | How |
| --- | --- |
| Project/session shell | The right sidebar extends the current terminal-first workspace instead of replacing project or session navigation |
| WorkspaceDetailView | The existing detail area is the most natural UI seam for the new right-side surface |
| Session tabs | Opened file previews should coexist with session context, but not inherit the full terminal-tab contract |
| Restore/resume | V1 should define limited, explicit restore behavior for file previews rather than broad document persistence |

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Session-Aware Working Set | Critical | The right sidebar highlights recent, pinned, and session-relevant files so the user reaches the likely next file faster than with a generic tree alone. |
| F2 | Secondary Workspace Tree | Critical | The sidebar includes an expandable folder/file tree for orientation and direct browsing, but it remains secondary to the working set. |
| F3 | Lightweight File Preview Tabs | Critical | Clicking a file opens a new tab with file content in a read-only or preview-style surface for quick inspection without committing to full editor behavior. |
| F4 | External Editor Handoff | High | Users can open the current file in their preferred external editor when they need full editing power or richer IDE features. |
| F5 | Context Sync and Quick Access | High | The sidebar and open previews stay aligned with recent activity, and common file access actions should remain fast during active coding. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Median time to open a target file from an active session | <= 5 seconds | Instrument file-open events from sidebar or quick access and measure time from sidebar interaction start to preview open |
| Weekly pilot users using the file navigator on 3+ days/week | >= 70% | Count unique pilot users with navigator activity on at least 3 separate days in a 7-day window |
| In-app file opens versus external-tool browsing by week 2 | >= 60% | Compare in-app file-open events against user-reported reliance on Finder/external editor during pilot check-ins |
| Users reporting fewer context switches | >= 80% rate 4/5 or higher | Run a pilot survey asking whether file access feels meaningfully more contained inside Another ADE |
| Sessions using 2+ file preview tabs | >= 50% of active pilot sessions | Measure session activity where at least two distinct file preview tabs are opened |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Strong |
| **Frequency** | How often would users encounter this value? | Must do |
| **Differentiation** | Does this set us apart or just match competitors? | Maybe |
| **Defensibility** | Is this easy to copy or does it compound over time? | Pass |
| **Feasibility** | Can we actually build this? | Maybe |

Leverage type: **Compounding Feature**

## Council Insights

- **Recommended approach:** Ship this as a session-aware working-set navigator with a recognizable tree and lightweight preview tabs, not as a full embedded editor.
- **Key trade-offs:** Better in-app navigation versus preserving the terminal-first wedge; recognizable file-tree ergonomics versus a more differentiated session-first model; preview convenience versus the risk of users expecting full editor semantics.
- **Risks identified:** scope creep into full IDE behavior; accidental coupling to the current terminal-tab model; unclear file-access and restore semantics; user expectation mismatch if preview behavior is not explicit.
- **Stretch goal (V2+):** richer session-aware file intelligence, including stronger relevance ranking, changed-file surfaces, and possibly editable file workflows once the product proves that file context belongs inside the workspace.

## Out of Scope (V1)

- **Full editable editor tabs** — V1 should not commit to dirty-state handling, save flows, or a broad embedded editor contract.
- **IDE-scale editing features** — Syntax-aware editing, language tooling, inline diagnostics, and full code-editing ergonomics belong to a later decision, not this idea.
- **Full file-management operations** — Create, rename, move, duplicate, and delete actions expand scope beyond the validated navigation problem.
- **Split editors and advanced multi-pane layouts** — The first version should prove file-context flow before adding complex editor choreography.
- **Deep document restore semantics** — V1 should avoid promising full restoration of file buffers or editor state across relaunch until the model is explicit.

## Architecture Decision Records

- [ADR-001: Scope tabbed-file-explorer as a session-aware working-set navigator](adrs/adr-001.md) — Establishes working-set-first navigation, secondary tree visibility, and preview-only tabs for V1.

## Open Questions

- Should the right sidebar be fixed as the default layout or become user-configurable later?
- Which file types and size limits should the preview surface support in V1?
- Should file preview tabs restore across relaunch, or stay intentionally lightweight and ephemeral at first?
- How much session relevance should be explicit in the UI: recent, pinned, changed, agent-touched, or only manually opened files?
