import SwiftUI

enum UpdateScope {
    case app, rclone, both
}

/// Shared update status rows and check action (About sheet + Dashboard).
struct UpdateStatusBox: View {
    @Environment(AppModel.self) private var app
    var scope: UpdateScope = .both
    var showCheckButton: Bool = true

    var body: some View {
        VStack(spacing: 12) {
            if scope == .app || scope == .both {
                UpdateStatusRow(title: "App", state: app.appUpdateState)
            }
            if scope == .both {
                Divider()
            }
            if scope == .rclone || scope == .both {
                UpdateStatusRow(title: "rclone", state: app.rcloneUpdateState)
            }
            if showCheckButton {
                if scope == .both { Divider() }
                Button { app.checkForUpdates() } label: {
                    Label("Check for Updates", systemImage: "arrow.clockwise")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct UpdateStatusRow: View {
    let title: String
    let state: UpdateState

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            UpdateStatusLabel(state: state)
        }
        .font(.callout)
    }
}

struct UpdateStatusLabel: View {
    let state: UpdateState

    var body: some View {
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
    }
}

/// App identity line shown on Dashboard and About.
enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
