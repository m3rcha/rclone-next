import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(AppModel.self) private var app
    @State private var dedupeRemote: Remote?

    var body: some View {
        @Bindable var app = app
        NavigationSplitView {
            List(selection: $app.selection) {
                Section {
                    Label("Dashboard", systemImage: "gauge.with.dots.needle.33percent")
                        .tag(SidebarItem.dashboard)
                }
                Section("Remotes") {
                    ForEach(app.remotes) { remote in
                        HStack {
                            Label(remote.name,
                                  systemImage: SFIcon.forRemoteType(app.type(of: remote)))
                                .symbolRenderingMode(.hierarchical)
                            Spacer()
                            if app.mounts.isMounted(remote) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 7)).foregroundStyle(.green)
                                    .help("Mounted")
                            }
                        }
                        .tag(SidebarItem.remote(remote))
                        .contextMenu { remoteMenu(remote) }
                    }
                }
            }
            .navigationTitle("Rclone Next")
            .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            switch app.selection {
            case .dashboard, .none:
                DashboardView()
            case .remote(let remote):
                FileListView(model: BrowserModel(remote: remote, app: app)).id(remote)
            }
        }
        .task { await app.bootstrap() }
        .appSheets(app: app, mounts: app.mounts)
        .sheet(item: $dedupeRemote) { DedupeSheet(remote: $0) }
    }

    @ViewBuilder
    private func remoteMenu(_ remote: Remote) -> some View {
        Button("Mount…") { mount(remote) }
        if let mounted = app.mounts.active.first(where: { $0.remote == remote }) {
            Button("Unmount") { app.mounts.unmount(mounted) }
        }
        Divider()
        Button("Empty Trash / Cleanup") {
            if AlertHelpers.confirm(
                "Clean up “\(remote.name)”?",
                message: "Removes trashed files and old versions where the backend supports it.",
                confirmTitle: "Clean Up"
            ) {
                Task { await app.cleanup(remote) }
            }
        }
        Button("Find Duplicates (Dedupe)…") { dedupeRemote = remote }
        Divider()
        Button("Delete Remote", role: .destructive) {
            if AlertHelpers.confirm(
                "Delete remote “\(remote.name)”?",
                message: "This removes the remote from your rclone config. Files on the provider are not deleted.",
                confirmTitle: "Delete Remote",
                style: .critical
            ) {
                Task { await app.deleteRemote(remote) }
            }
        }
    }

    private func mount(_ remote: Remote) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Mount Here"
        panel.message = "Choose an empty folder to mount “\(remote.name)”."
        if panel.runModal() == .OK, let folder = panel.url {
            app.mounts.mount(remote, at: folder, remember: true)
        }
    }
}
