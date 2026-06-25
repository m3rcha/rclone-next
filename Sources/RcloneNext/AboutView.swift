import SwiftUI

/// About sheet: app + rclone versions, update status for both, and useful links.
struct AboutView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String { AppInfo.version }
    private var buildNumber: String { AppInfo.build }

    var body: some View {
        VStack(spacing: 14) {
            BrandImage.heroIcon
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
                UpdateStatusBox().padding(6)
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
}
