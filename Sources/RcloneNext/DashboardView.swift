import SwiftUI

/// Status home screen: rclone health, remotes overview, per-remote storage, and the
/// shared active transfer. Shown when the sidebar selection is `.dashboard`.
struct DashboardView: View {
    @Environment(AppModel.self) private var app

    private let columns = [GridItem(.adaptive(minimum: 240), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroHeader
                rcloneCard
                if let t = app.activeTransfer { transferCard(t) }
                mountsCard
                remotesCard
                storageSection
            }
            .padding(20)
        }
        .navigationTitle("Dashboard")
        .toolbar {
            Button { app.showingJobs = true } label: {
                Label("Sync", systemImage: "arrow.triangle.2.circlepath")
            }.help("Sync / Copy / Move…")
            Button { app.showingAddRemote = true } label: {
                Label("Add Remote", systemImage: "plus")
            }.help("Add Remote…")
        }
        .task { if app.rcloneVersion == nil { await app.bootstrap() } }
    }

    // MARK: Hero header

    private var heroHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "externaldrive.connected.to.line.below.fill")
                .font(.system(size: 34)).symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Rclone Next").font(.largeTitle.bold())
                Text("\(app.remotes.count) remote\(app.remotes.count == 1 ? "" : "s") · "
                   + "\(app.mounts.active.filter { $0.state == .mounted }.count) mounted")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: rclone status

    private var rcloneCard: some View {
        GroupBox {
            HStack(spacing: 16) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 28)).foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("rclone \(app.rcloneVersion ?? "—")").font(.headline)
                    Text(app.rclonePath).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                updateBadge(app.rcloneUpdateState)
            }
            .padding(6)
        } label: { Label("rclone", systemImage: "internaldrive") }
    }

    @ViewBuilder
    private func updateBadge(_ state: UpdateState) -> some View {
        switch state {
        case .idle, .notConfigured: EmptyView()
        case .checking: ProgressView().controlSize(.small)
        case .upToDate:
            Label("Up to date", systemImage: "checkmark.seal.fill")
                .font(.caption).foregroundStyle(.green)
        case .available(let v):
            Label("v\(v) available", systemImage: "arrow.down.circle.fill")
                .font(.caption).foregroundStyle(.orange)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Active transfer

    private func transferCard(_ t: TransferProgress) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text(app.transferLabel ?? "Transferring…").font(.subheadline)
                ProgressView(value: t.fraction)
                HStack {
                    Text("\(bytes(t.bytes)) of \(bytes(t.totalBytes))")
                    Spacer()
                    Text("\(bytes(Int64(t.speed)))/s").foregroundStyle(.secondary)
                }
                .font(.caption).monospacedDigit()
            }.padding(6)
        } label: { Label("Active Transfer", systemImage: "arrow.left.arrow.right.circle") }
    }

    // MARK: Remotes overview

    private var remotesCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(app.remotes.count) configured").foregroundStyle(.secondary)
                    Spacer()
                    Button { app.showingAddRemote = true } label: {
                        Label("Add Remote…", systemImage: "plus")
                    }.buttonStyle(.borderless)
                }
                if app.remotes.isEmpty {
                    Text("No remotes yet. Add one to get started.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(app.remotes) { remote in
                        Button { app.selection = .remote(remote) } label: {
                            Label(remote.name,
                                  systemImage: SFIcon.forRemoteType(app.type(of: remote)))
                                .symbolRenderingMode(.hierarchical)
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(6)
        } label: { Label("Remotes", systemImage: "rectangle.stack") }
    }

    // MARK: Mounts

    private var mountsCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if app.mounts.active.isEmpty && app.mounts.saved.isEmpty {
                    Text("No mounted drives. Right-click a remote → Mount…")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(app.mounts.active) { mount in
                    HStack(spacing: 10) {
                        Image(systemName: mountIcon(mount.state))
                            .foregroundStyle(mountColor(mount.state))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(mount.remote.name)
                            if case .failed(let msg) = mount.state {
                                Text(msg).font(.caption2).foregroundStyle(.red)
                                    .lineLimit(2).truncationMode(.middle)
                            } else {
                                Text(mount.mountPoint.path).font(.caption2)
                                    .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                            }
                        }
                        Spacer()
                        switch mount.state {
                        case .mounting:
                            ProgressView().controlSize(.small)
                        case .failed:
                            Button { app.mounts.dismiss(mount) } label: {
                                Image(systemName: "xmark.circle")
                            }.buttonStyle(.borderless).help("Dismiss")
                        case .mounted:
                            Button { app.mounts.reveal(mount) } label: {
                                Image(systemName: "arrow.up.forward.app")
                            }.buttonStyle(.borderless).help("Reveal in Finder")
                            Button { app.mounts.unmount(mount) } label: {
                                Image(systemName: "eject")
                            }.buttonStyle(.borderless).help("Unmount")
                        }
                    }
                }
                let activePaths = Set(app.mounts.active.map { $0.mountPoint.path })
                let inactiveSaved = app.mounts.saved.filter { !activePaths.contains($0.path) }
                if !inactiveSaved.isEmpty {
                    Divider()
                    Text("Auto-mount on launch").font(.caption).foregroundStyle(.secondary)
                    ForEach(inactiveSaved) { saved in
                        HStack {
                            Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
                            Text("\(saved.remote) → \(saved.path)")
                                .font(.caption).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Button("Forget") { app.mounts.forget(saved) }
                                .buttonStyle(.borderless).font(.caption)
                        }
                    }
                }
            }.padding(6)
        } label: { Label("Mounts", systemImage: "externaldrive.badge.checkmark") }
    }

    private func mountIcon(_ state: MountState) -> String {
        switch state {
        case .mounting: return "externaldrive"
        case .mounted:  return "externaldrive.fill"
        case .failed:   return "externaldrive.badge.xmark"
        }
    }
    private func mountColor(_ state: MountState) -> Color {
        switch state {
        case .mounting: return .secondary
        case .mounted:  return .green
        case .failed:   return .red
        }
    }

    // MARK: Storage

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Storage").font(.headline).padding(.leading, 4)
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(app.remotes) { remote in StorageCard(remote: remote) }
            }
        }
    }

    private func bytes(_ n: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
    }
}

/// One per-remote usage card; loads `rclone about` lazily and degrades gracefully.
private struct StorageCard: View {
    let remote: Remote
    @Environment(AppModel.self) private var app
    @State private var about: RemoteAbout?
    @State private var state: LoadState = .loading

    enum LoadState { case loading, loaded, unsupported }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label(remote.name, systemImage: SFIcon.forRemoteType(app.type(of: remote)))
                    .symbolRenderingMode(.hierarchical).font(.subheadline)
                switch state {
                case .loading:
                    ProgressView().controlSize(.small).frame(maxWidth: .infinity, alignment: .center)
                case .unsupported:
                    Text("Not reported").font(.caption).foregroundStyle(.secondary)
                case .loaded:
                    if let total = about?.total, total > 0, let used = about?.used {
                        Gauge(value: Double(used), in: 0...Double(total)) {
                            EmptyView()
                        } currentValueLabel: {
                            Text(percent(used, total)).font(.caption2)
                        }.gaugeStyle(.accessoryLinearCapacity)
                        Text("\(bytes(used)) of \(bytes(total)) used")
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    } else if let used = about?.used {
                        Text("\(bytes(used)) used")
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    } else {
                        Text("Not reported").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.padding(6)
        }
        .task {
            do {
                if let result = try await app.backend.about(remote) {
                    about = result; state = .loaded
                } else { state = .unsupported }
            } catch { state = .unsupported }
        }
    }

    private func percent(_ used: Int64, _ total: Int64) -> String {
        "\(Int(Double(used) / Double(total) * 100))%"
    }
    private func bytes(_ n: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
    }
}
