import SwiftUI

@main
struct RcloneNextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var app = AppModel()

    var body: some Scene {
        // Always-present menu bar entry; single click opens a rich panel.
        MenuBarExtra("Rclone Next", systemImage: "externaldrive.connected.to.line.below") {
            MenuBarPanel().environment(app)
        }
        .menuBarExtraStyle(.window)

        // The full manager — a single, reopenable window (no Dock icon; see AppDelegate).
        Window("Rclone Next", id: "main") {
            ContentView()
                .environment(app)
                .frame(minWidth: 820, minHeight: 520)
                .onAppear { NSApp.activate(ignoringOtherApps: true) }
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Rclone Next") { app.showingAbout = true }
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { app.checkForUpdates() }
                Button("Settings…") { app.showingSettings = true }
                    .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {
                Button("Add Remote…") { app.showingAddRemote = true }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Sync…") { app.showingJobs = true }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .help) {
                Button("Welcome to Rclone Next") { app.showingWelcome = true }
                Button("rclone Documentation") {
                    NSWorkspace.shared.open(URL(string: "https://rclone.org/docs/")!)
                }
            }
        }
    }
}

/// Makes the app a menu-bar-only accessory (no Dock icon) and unmounts all FUSE mounts
/// before the process exits.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { MountManager.shared.unmountAll() }
    }
}
