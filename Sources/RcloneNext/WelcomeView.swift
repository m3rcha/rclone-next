import SwiftUI

/// First-run walkthrough — a simple paged intro, re-openable from the Help menu.
struct WelcomeView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private struct Step: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let blurb: String
    }

    private let steps: [Step] = [
        .init(symbol: "externaldrive.connected.to.line.below.fill",
              title: "Welcome to Rclone Next",
              blurb: "A native macOS manager for rclone — browse, transfer, and mount your "
                   + "cloud storage from a clean, fast interface."),
        .init(symbol: "plus.circle.fill",
              title: "Add a Remote",
              blurb: "Press ⌘N or the + button to connect a drive. Cloud providers like Google "
                   + "Drive and OneDrive sign in through your browser; others use credentials."),
        .init(symbol: "externaldrive.fill.badge.checkmark",
              title: "Mount Drives",
              blurb: "Mount any remote as a real folder in Finder (requires macFUSE). Right-click "
                   + "a remote → Mount…, or use the menu bar. Mounts can auto-restore on launch."),
        .init(symbol: "arrow.triangle.2.circlepath",
              title: "Sync & Transfer",
              blurb: "Press ⇧⌘S to copy, sync, or move between any two locations — with a dry-run "
                   + "preview so you can see exactly what will change before committing."),
        .init(symbol: "menubar.arrow.up.rectangle",
              title: "Always in the Menu Bar",
              blurb: "Rclone Next lives in your menu bar. Click the icon for quick access to "
                   + "mounts, transfers, and to open the full window anytime.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            stepView(steps[page])
                .frame(height: 320)
                .id(page)                       // distinct identity per step
                .transition(.opacity)           // crossfade on Back/Continue

            // Page dots
            HStack(spacing: 7) {
                ForEach(steps.indices, id: \.self) { i in
                    Circle()
                        .fill(i == page ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.vertical, 12)

            Divider()
            HStack {
                Button("Skip") { app.dismissWelcome() }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                if page > 0 {
                    Button("Back") { withAnimation { page -= 1 } }
                }
                if page < steps.count - 1 {
                    Button("Continue") { withAnimation { page += 1 } }
                        .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") { app.dismissWelcome() }
                        .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 460, height: 440)
    }

    private func stepView(_ step: Step) -> some View {
        VStack(spacing: 18) {
            Image(systemName: step.symbol)
                .font(.system(size: 64))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .padding(.top, 40)
            Text(step.title).font(.title2).bold()
            Text(step.blurb)
                .font(.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}
