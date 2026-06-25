import SwiftUI

/// Pick a dedupe strategy for a remote and run `rclone dedupe <mode>`.
struct DedupeSheet: View {
    let remote: Remote
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var mode: DedupeMode = .newest
    @State private var running = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Find Duplicates — \(remote.name)", systemImage: "doc.on.doc")
                .font(.headline)
            Text("rclone scans for files with duplicate names and resolves them using the "
               + "selected strategy. This can delete or rename files on the remote.")
                .font(.callout).foregroundStyle(.secondary)

            Picker("Keep", selection: $mode) {
                ForEach(DedupeMode.allCases) { Text($0.title).tag($0) }
            }
            .disabled(running)

            Spacer()
            HStack {
                if running { ProgressView().controlSize(.small) }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(running)
                Button("Run Dedupe") { Task { await run() } }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).disabled(running)
            }
        }
        .padding(20)
        .frame(width: 430, height: 250)
    }

    private func run() async {
        running = true
        defer { running = false }
        await app.dedupe(remote, mode: mode)
        dismiss()
    }
}
