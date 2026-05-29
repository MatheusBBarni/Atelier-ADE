import NativeMacADECore
import SwiftUI

struct ContentView: View {
    let store: WorkspaceStore

    var body: some View {
        NavigationSplitView {
            ProjectSidebar(store: store)
        } content: {
            SessionList(store: store)
        } detail: {
            WorkspaceDetail(store: store)
        }
        .navigationTitle("Native Mac ADE")
        .frame(minWidth: 960, minHeight: 640)
    }
}

private struct ProjectSidebar: View {
    let store: WorkspaceStore

    var body: some View {
        List(store.projects, selection: selectedProjectBinding) { project in
            VStack(alignment: .leading, spacing: 4) {
                Text(project.displayName)
                    .font(.headline)
                Text(project.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .tag(project.id)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        .toolbar {
            ToolbarItem {
                Button("Open Project", systemImage: "folder.badge.plus") {
                    store.openPlaceholderProject()
                }
                .accessibilityHint("Adds a placeholder project to the sidebar for scaffold validation")
            }
        }
    }

    private var selectedProjectBinding: Binding<WorkspaceProject.ID?> {
        Binding(
            get: { store.selectedProjectID },
            set: { store.selectProject(id: $0) }
        )
    }
}

private struct SessionList: View {
    let store: WorkspaceStore

    var body: some View {
        List(store.sessionsForSelectedProject, selection: selectedSessionBinding) { session in
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.headline)
                Text(session.isUserNamed ? "Renamed session" : "Default session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tag(session.id)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        .toolbar {
            ToolbarItem {
                Button("New Session", systemImage: "plus.rectangle.on.folder") {
                    store.createPlaceholderSession()
                }
                .disabled(store.selectedProjectID == nil)
            }
        }
    }

    private var selectedSessionBinding: Binding<WorkspaceSession.ID?> {
        Binding(
            get: { store.selectedSessionID },
            set: { store.selectSession(id: $0) }
        )
    }
}

private struct WorkspaceDetail: View {
    let store: WorkspaceStore

    var body: some View {
        VStack(spacing: 0) {
            TabChrome(store: store)
            Divider()
            TerminalPlaceholder(selectedTab: store.selectedTab)
        }
        .toolbar {
            ToolbarItem {
                Button("New Tab", systemImage: "plus") {
                    store.createPlaceholderTab()
                }
                .disabled(store.selectedSessionID == nil)
            }
        }
    }
}

private struct TabChrome: View {
    let store: WorkspaceStore

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(store.tabsForSelectedSession) { tab in
                    Button {
                        store.selectTab(id: tab.id)
                    } label: {
                        Label(tab.workingDirectory, systemImage: tab.id == store.selectedTabID ? "terminal.fill" : "terminal")
                            .labelStyle(.titleAndIcon)
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Terminal tab in \(tab.workingDirectory)")
                }
            }
            .padding(12)
        }
        .frame(height: 56)
    }
}

private struct TerminalPlaceholder: View {
    let selectedTab: WorkspaceTab?

    var body: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
            VStack(spacing: 12) {
                Image(systemName: "terminal")
                    .font(.system(size: 42))
                    .foregroundStyle(.secondary)
                Text("Terminal host boundary")
                    .font(.title3.weight(.semibold))
                Text(selectedTab?.workingDirectory ?? "Select or create a tab")
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView(store: .preview())
}
