import SwiftUI
import AppKit

/// Sync / Copy / Move between any two endpoints (remote or local), with a dry-run preview.
struct JobsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var op: TransferOp = .copy
    @State private var sourceRemote = ""        // "" == local folder
    @State private var sourcePath = ""
    @State private var destRemote = ""
    @State private var destPath = ""
    @State private var dryRun = true
    @State private var running = false
    @State private var result: String?
    @State private var error: String?
    @State private var task: Task<Void, Never>?

    private let localTag = "__local__"

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Form {
                Picker("Operation", selection: $op) {
                    ForEach([TransferOp.copy, .sync, .move], id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                endpointSection("Source", remote: $sourceRemote, path: $sourcePath)
                endpointSection("Destination", remote: $destRemote, path: $destPath)

                Section {
                    Toggle("Dry run — preview changes, write nothing", isOn: $dryRun)
                    if op.isDestructive {
                        Label("\(op.title) deletes files at the destination that aren't in the source.",
                              systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }

                if let result {
                    Section("Result") { Text(result).font(.callout) }
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red).font(.callout)
                }
            }
            .formStyle(.grouped)
            Divider()
            footer
        }
        .frame(width: 540, height: 540)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 22)).foregroundStyle(.tint)
            VStack(alignment: .leading) {
                Text("Transfer Job").font(.headline)
                Text("Copy, sync, or move between remotes and local folders")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }.padding()
    }

    private func endpointSection(_ title: String, remote: Binding<String>, path: Binding<String>) -> some View {
        Section(title) {
            Picker("Location", selection: remote) {
                Text("Local folder…").tag("")
                ForEach(app.remotes) { Text($0.name).tag($0.name) }
            }
            if remote.wrappedValue.isEmpty {
                HStack {
                    TextField("Local path", text: path, prompt: Text("/Users/…")).disabled(running)
                    Button("Browse…") { browseLocal(into: path) }
                }
            } else {
                TextField("Path in remote", text: path, prompt: Text("optional/subfolder"))
                    .disabled(running)
                Text(fullPath(remote.wrappedValue, path.wrappedValue))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if running {
                ProgressView().controlSize(.small)
                Text("Running…").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel") { task?.cancel(); dismiss() }.keyboardShortcut(.cancelAction)
            Button(dryRun ? "Preview" : op.title) { task = Task { await run() } }
                .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                .disabled(running || !isValid)
        }.padding()
    }

    private var isValid: Bool {
        let src = fullPath(sourceRemote, sourcePath)
        let dst = fullPath(destRemote, destPath)
        return !src.isEmpty && !dst.isEmpty && src != dst
    }

    private func fullPath(_ remote: String, _ path: String) -> String {
        if remote.isEmpty { return path }                       // local absolute path
        return path.isEmpty ? "\(remote):" : "\(remote):\(path)"
    }

    private func browseLocal(into path: Binding<String>) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url { path.wrappedValue = url.path }
    }

    private func run() async {
        if op.isDestructive && !dryRun && !confirmDestructive() { return }
        running = true; error = nil; result = nil
        defer { running = false; app.activeTransfer = nil; app.transferLabel = nil }

        let src = fullPath(sourceRemote, sourcePath)
        let dst = fullPath(destRemote, destPath)
        app.transferLabel = "\(op.title): \(src) → \(dst)"
        app.activeTransfer = TransferProgress()
        var last = TransferProgress()
        do {
            for try await p in app.backend.transfer(op, from: src, to: dst, dryRun: dryRun) {
                app.activeTransfer = p; last = p
            }
            let moved = ByteCountFormatter.string(fromByteCount: last.bytes, countStyle: .file)
            result = dryRun
                ? "Dry run complete — \(last.transfers) item(s), \(moved) would transfer."
                : "Done — \(last.transfers) item(s), \(moved) transferred."
            await app.loadRemotes()
        } catch is CancellationError {
            result = "Cancelled."
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func confirmDestructive() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Run \(op.title) without dry-run?"
        alert.informativeText = "This can permanently delete files at the destination."
        alert.alertStyle = .warning
        alert.addButton(withTitle: op.title); alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
