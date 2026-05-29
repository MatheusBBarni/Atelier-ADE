# Atelier

Atelier is an open-source agentic development environment for macOS, built for developers who want to work with coding agents in a native, transparent workspace.

The idea is simple: keep the app out of the way, keep the state on your machine, and make it obvious what each session, tab, and agent is doing. No browser shell pretending to be a desktop app. No mystery sync layer. Just a Mac app that feels like it belongs on macOS.

## What Atelier does today

- keeps projects pinned in a persistent sidebar
- groups work into sessions so related tabs stay together
- opens terminal tabs inside a native macOS window
- supports plain shell sessions plus agent-flavoured session starts
- restores workspace state when you relaunch the app

## Why it exists

Most agent tooling still lives in the browser or in editor plugins. That works, but it also means the UI, windowing, shortcuts, and session model are borrowed from somewhere else.

Atelier takes the opposite approach. It starts with the desktop app itself and treats agents as part of the workspace, not as an overlay on top of another tool.

## Build, test, and run

```bash
swift build
swift test
./scripts/run.sh
./scripts/run.sh bundle
```

`./scripts/run.sh` also supports these modes:

```bash
./scripts/run.sh build
./scripts/run.sh bundle
./scripts/run.sh test
```

The `run` and `bundle` modes create a real macOS app bundle named `Atelier.app` inside `.build/.../debug/`.

## Project structure

- `Sources/NativeMacADE/` – the SwiftUI app shell
- `Sources/NativeMacADECore/` – workspace models, commands, restore flow, logging, and terminal hosting
- `Sources/CGhostty/` – C shim used by the current terminal integration boundary
- `Tests/` – unit and integration coverage
- `scripts/run.sh` – local build, bundle, and launch helper

## Current status

Atelier is early, but usable. The core loop is there: open a project, start a session, spawn tabs, and come back later without losing the thread.

There is still plenty of room to push the app further, especially around editor surfaces, richer agent workflows, and deeper macOS polish.

## License

This repository is open source. Add the project license here once it is finalized.
