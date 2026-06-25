import SwiftUI
import AppKit

/// Compact menu-bar popover: status, every remote with its mount status (mount/unmount
/// inline), active transfer, and quick actions.
struct MenuBarPanel: View {
    @Environment(AppModel.self) private var app
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Rclone Next", systemImage: "externaldrive.connected.to.line.below")
                    .font(.headline)
                Spacer()
                Text(app.rcloneVersion ?? "").font(.caption).foregroundStyle(.secondary)
            }
            Divider()

            Text("Drives").font(.caption).foregroundStyle(.secondary)
            if app.remotes.isEmpty {
                Text("No remotes configured").font(.callout).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(app.remotes) { remoteRow($0) }
                    }
                    .padding(.trailing, 4)        // room for the scroll indicator
                }
                .frame(height: listHeight)        // concrete height so the popover doesn't clip
            }

            if let t = app.activeTransfer {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(app.transferLabel ?? "Transferring…").font(.caption).lineLimit(1)
                        Spacer()
                        Button("Cancel") { app.cancelActiveTransfer() }
                            .buttonStyle(.borderless).font(.caption)
                    }
                    ProgressView(value: t.fraction)
                }
            }

            Divider()
            HStack {
                Button { openMain(); app.showingAddRemote = true } label: {
                    Label("Add", systemImage: "plus")
                }
                Button { openMain(); app.showingJobs = true } label: {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                Spacer()
            }.buttonStyle(.borderless)

            Divider()
            HStack {
                Button("Open Rclone Next") { openMain() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 340)
        .task { await app.bootstrap() }
    }

    /// Height that fits the remotes exactly (up to ~7), then scrolls.
    private var listHeight: CGFloat {
        min(max(CGFloat(app.remotes.count), 1) * 46, 322)
    }

    // MARK: Per-remote row (mounted or not)

    @ViewBuilder
    private func remoteRow(_ remote: Remote) -> some View {
        let mount = app.mounts.active.first { $0.remote == remote }
        HStack(spacing: 8) {
            Image(systemName: icon(for: mount?.state, remote: remote))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color(for: mount?.state))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(remote.name).font(.callout)
                subtitle(for: mount)
            }
            Spacer()
            trailing(for: remote, mount: mount)
        }
    }

    @ViewBuilder
    private func subtitle(for mount: MountManager.ActiveMount?) -> some View {
        switch mount?.state {
        case .some(.mounting):
            Text("Mounting…").font(.caption2).foregroundStyle(.secondary)
        case .some(.mounted):
            Text(mount!.mountPoint.path).font(.caption2).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
        case .some(.failed(let msg)):
            Text(msg).font(.caption2).foregroundStyle(.red).lineLimit(2).truncationMode(.middle)
        case .none:
            Text("Not mounted").font(.caption2).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func trailing(for remote: Remote, mount: MountManager.ActiveMount?) -> some View {
        switch mount?.state {
        case .some(.mounting):
            ProgressView().controlSize(.small)
        case .some(.mounted):
            Button { app.mounts.reveal(mount!) } label: { Image(systemName: "arrow.up.forward.app") }
                .buttonStyle(.borderless).help("Reveal in Finder")
            Button { app.mounts.unmount(mount!) } label: { Image(systemName: "eject") }
                .buttonStyle(.borderless).help("Unmount")
        case .some(.failed):
            Button { mountRemote(remote) } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless).help("Try again")
            Button { app.mounts.dismiss(mount!) } label: { Image(systemName: "xmark.circle") }
                .buttonStyle(.borderless).help("Dismiss")
        case .none:
            Button { mountRemote(remote) } label: { Image(systemName: "arrow.up.forward.square") }
                .buttonStyle(.borderless).help("Mount…")
        }
    }

    // MARK: Helpers

    private func icon(for state: MountState?, remote: Remote) -> String {
        switch state {
        case .some(.mounted): return "externaldrive.fill"
        case .some(.failed):  return "externaldrive.badge.xmark"
        default:              return SFIcon.forRemoteType(app.type(of: remote))
        }
    }
    private func color(for state: MountState?) -> Color {
        switch state {
        case .some(.mounted): return .green
        case .some(.failed):  return .red
        default:              return .secondary
        }
    }

    private func mountRemote(_ remote: Remote) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Mount Here"
        panel.message = "Choose an empty folder to mount “\(remote.name)”."
        if panel.runModal() == .OK, let folder = panel.url {
            app.mounts.mount(remote, at: folder, remember: true)
        }
    }

    private func openMain() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
