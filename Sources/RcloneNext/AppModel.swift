import Foundation
import Observation

/// App-wide state, created once at the root and shared via `.environment(...)`.
/// Owns the remote list, sidebar selection, the single active transfer (so the
/// Dashboard and the file browser stay in sync), and update-check results.
@MainActor @Observable
final class AppModel {
    let backend = RcloneBackend.shared
    let mounts = MountManager.shared
    let cache = ListingCache()

    var remotes: [Remote] = []
    var remoteTypes: [String: String] = [:]   // remote name → backend type (for icons)
    var selection: SidebarItem? = .dashboard
    var rcloneVersion: String?
    var loadError: String?

    // Shared transfer state (written by BrowserModel, read by Dashboard + file view).
    var activeTransfer: TransferProgress?
    var transferLabel: String?

    // Update checks.
    var appUpdateState: UpdateState = .idle
    var rcloneUpdateState: UpdateState = .idle

    // Sheet presentation, toggled from the menu bar commands.
    var showingAddRemote = false
    var showingAbout = false
    var showingJobs = false
    var showingWelcome = false

    private let welcomeKey = "hasSeenWelcome"
    func dismissWelcome() {
        UserDefaults.standard.set(true, forKey: welcomeKey)
        showingWelcome = false
    }

    /// Path of the resolved rclone binary, shown on the dashboard / about screens.
    var rclonePath: String { backend.executableURL.path }

    func bootstrap() async {
        if !UserDefaults.standard.bool(forKey: welcomeKey) { showingWelcome = true }
        async let version = try? backend.version()
        await loadRemotes()
        rcloneVersion = await version
        mounts.autoMountSaved(remotes: remotes)   // re-establish persisted mounts
    }

    /// Backend type for a remote, e.g. "drive" / "onedrive" (for provider icons).
    func type(of remote: Remote) -> String? { remoteTypes[remote.name] }

    // MARK: Remote maintenance

    func cleanup(_ remote: Remote) async {
        do { try await backend.cleanup(remote) }
        catch { loadError = error.localizedDescription }
    }

    func dedupe(_ remote: Remote, mode: DedupeMode) async {
        do { try await backend.dedupe(remote, mode: mode) }
        catch { loadError = error.localizedDescription }
    }

    func loadRemotes() async {
        do {
            remotes = try await backend.listRemotes()
            remoteTypes = (try? await backend.configDump()) ?? remoteTypes
        }
        catch { loadError = error.localizedDescription }
    }

    func deleteRemote(_ remote: Remote) async {
        do {
            try await backend.deleteRemote(name: remote.name)
            if selection == .remote(remote) { selection = .dashboard }
            await loadRemotes()
        } catch { loadError = error.localizedDescription }
    }

    /// Runs both update checks concurrently and stores their results.
    func checkForUpdates() {
        appUpdateState = .checking
        rcloneUpdateState = .checking
        Task {
            async let app = AppUpdate.check()
            async let rclone = rcloneState()
            appUpdateState = await app
            rcloneUpdateState = await rclone
        }
    }

    private func rcloneState() async -> UpdateState {
        do {
            let (current, latest) = try await backend.rcloneUpdateCheck()
            guard !latest.isEmpty else { return .failed("No version reported") }
            return latest.compare(current, options: .numeric) == .orderedDescending
                ? .available(latest) : .upToDate
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
