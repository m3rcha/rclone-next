import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var customPath: String = RclonePathSettings.customPath() ?? ""
    @State private var status: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            Form {
                Section("rclone executable") {
                    TextField("Path to rclone", text: $customPath, prompt: Text("/opt/homebrew/bin/rclone"))
                    HStack {
                        Button("Browse…") { browse() }
                        Button("Use Auto-Detect") {
                            customPath = ""
                            apply(resetOnly: true)
                        }
                    }
                    Text("Leave empty to search Homebrew and /usr/bin automatically.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Current: \(app.rclonePath)")
                        .font(.caption).foregroundStyle(.secondary)
                    if let status {
                        Label(status, systemImage: statusIcon)
                            .font(.callout)
                            .foregroundStyle(statusColor)
                    }
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { apply(resetOnly: false) }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 480, height: 320)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 22)).foregroundStyle(.tint)
            VStack(alignment: .leading) {
                Text("Settings").font(.headline)
                Text("Configure how Rclone Next finds the rclone binary")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    private var statusIcon: String {
        status?.hasPrefix("Saved") == true ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var statusColor: Color {
        status?.hasPrefix("Saved") == true ? .green : .red
    }

    private func browse() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Choose rclone"
        if panel.runModal() == .OK, let url = panel.url {
            customPath = url.path
        }
    }

    private func apply(resetOnly: Bool) {
        let trimmed = customPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            RclonePathSettings.setCustomPath(nil)
            app.backend.refreshExecutablePath()
            status = "Saved — using auto-detect (\(app.rclonePath))"
            Task { await app.refreshRcloneVersion() }
            dismiss()
            return
        }
        guard FileManager.default.isExecutableFile(atPath: trimmed) else {
            status = "That path is not an executable rclone binary."
            return
        }
        RclonePathSettings.setCustomPath(trimmed)
        app.backend.refreshExecutablePath()
        status = "Saved — using \(trimmed)"
        Task {
            await app.refreshRcloneVersion()
            dismiss()
        }
    }
}
