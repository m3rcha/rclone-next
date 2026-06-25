import SwiftUI

/// Shared sheet presentation for menu-bar panel and main window.
struct AppSheets: ViewModifier {
    @Bindable var app: AppModel
    @Bindable var mounts: MountManager

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $app.showingAddRemote) { AddRemoteView() }
            .sheet(isPresented: $app.showingAbout) { AboutView() }
            .sheet(isPresented: $app.showingJobs) { JobsView() }
            .sheet(isPresented: $app.showingWelcome) { WelcomeView() }
            .sheet(isPresented: $app.showingSettings) { SettingsView() }
            .alert("rclone Error", isPresented: .constant(app.loadError != nil)) {
                Button("OK") { app.loadError = nil }
            } message: { Text(app.loadError ?? "") }
            .alert("macFUSE Required to Mount Drives", isPresented: $mounts.showingMacFUSEAlert) {
                Button("Open Instructions") { MountManager.openMountDocs() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Mounting remotes as local drives needs macFUSE. Open rclone's documentation "
                   + "for installation steps.")
            }
    }
}

extension View {
    func appSheets(app: AppModel, mounts: MountManager) -> some View {
        modifier(AppSheets(app: app, mounts: mounts))
    }
}
