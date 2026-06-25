import SwiftUI

/// About sheet: app + rclone versions, update status for both, and useful links.
struct AboutView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "externaldrive.connected.to.line.below.fill")
                .font(.system(size: 56)).foregroundStyle(.tint)
                .padding(.top, 24)

            VStack(spacing: 4) {
                Text("Rclone Next").font(.title2).bold()
                Text("A native macOS manager for rclone")
                    .font(.callout).foregroundStyle(.secondary)
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 2)
                Text("rclone \(app.rcloneVersion ?? "—")")
                    .font(.caption).foregroundStyle(.secondary)
            }

            GroupBox {
                VStack(spacing: 10) {
                    updateRow(title: "App", state: app.appUpdateState)
                    Divider()
                    updateRow(title: "rclone", state: app.rcloneUpdateState)
                    Divider()
                    Button {
                        app.checkForUpdates()
                    } label: {
                        Label("Check for Updates", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                }.padding(6)
            }
            .padding(.horizontal)

            HStack(spacing: 16) {
                Link("rclone.org", destination: URL(string: "https://rclone.org")!)
                Link("GitHub", destination: URL(string:
                    "https://github.com/\(AppUpdate.owner)/\(AppUpdate.repo)")!)
            }.font(.callout)

            Text("© 2026 Ege Özten. Built with SwiftUI & AppKit.\n"
               + "Not affiliated with the rclone project.")
                .font(.caption2).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()
            Button("Done") { dismiss() }.keyboardShortcut(.defaultAction).padding(.bottom)
        }
        .frame(width: 360, height: 480)
        .task { await app.bootstrap() }
    }

    @ViewBuilder
    private func updateRow(title: String, state: UpdateState) -> some View {
        HStack {
            Text(title)
            Spacer()
            switch state {
            case .idle:
                Text("Not checked").foregroundStyle(.secondary)
            case .checking:
                ProgressView().controlSize(.small)
            case .upToDate:
                Label("Up to date", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
            case .available(let v):
                Label("v\(v) available", systemImage: "arrow.down.circle.fill")
                    .foregroundStyle(.orange)
            case .notConfigured:
                Text("No releases found").foregroundStyle(.secondary)
            case .failed(let msg):
                Label("Check failed", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.secondary).help(msg)
            }
        }.font(.callout)
    }
}
