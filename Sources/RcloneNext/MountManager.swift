import Foundation
import AppKit
import Observation

/// A thread-safe stderr accumulator, safe to capture in the process pipe/termination
/// closures that run off the main actor.
private final class ErrBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    func append(_ d: Data) { lock.lock(); data.append(d); lock.unlock() }
    var string: String { lock.lock(); defer { lock.unlock() }; return String(decoding: data, as: UTF8.self) }
}

/// Owns the live `rclone mount` processes (one per mounted remote) plus the persisted
/// list of mounts to auto-remount on launch. Mounts run foreground so we hold the process
/// handle and can unmount cleanly; the app unmounts everything on quit.
@MainActor @Observable
final class MountManager {
    static let shared = MountManager()

    /// One running mount. `process` is confined to the main actor with this object.
    @Observable
    final class ActiveMount: Identifiable {
        let id = UUID()
        let remote: Remote
        let mountPoint: URL
        var state: MountState
        let process: Process
        init(remote: Remote, mountPoint: URL, state: MountState, process: Process) {
            self.remote = remote; self.mountPoint = mountPoint
            self.state = state; self.process = process
        }
    }

    var active: [ActiveMount] = []
    var saved: [SavedMount] = []
    var showingMacFUSEAlert = false

    private var unmounting: Set<UUID> = []   // ids the user is unmounting (expected exit)
    private let savedKey = "savedMounts"

    init() { loadSaved() }

    static var isMacFUSEInstalled: Bool { RcloneBackend.isMacFUSEInstalled }

    func isMounted(_ remote: Remote) -> Bool {
        active.contains { $0.remote == remote && $0.state == .mounted }
    }

    // MARK: Mount / unmount

    func mount(_ remote: Remote, at folder: URL, remember: Bool) {
        guard Self.isMacFUSEInstalled else { showingMacFUSEAlert = true; return }
        guard !active.contains(where: { $0.mountPoint == folder }) else { return }

        let process = Process()
        process.executableURL = RcloneBackend.shared.executableURL
        process.arguments = ["mount", remote.root, folder.path,
                             "--vfs-cache-mode", "writes",
                             "--volname", remote.name]
        process.standardInput = FileHandle.nullDevice
        let errPipe = Pipe()
        process.standardError = errPipe

        let mount = ActiveMount(remote: remote, mountPoint: folder, state: .mounting, process: process)

        // Capture stderr (thread-safe) so a failed mount can show why.
        let errBuffer = ErrBuffer()
        errPipe.fileHandleForReading.readabilityHandler = { h in
            let d = h.availableData
            if !d.isEmpty { errBuffer.append(d) }
        }
        process.terminationHandler = { [weak self] proc in
            errPipe.fileHandleForReading.readabilityHandler = nil
            let err = errBuffer.string
            let status = proc.terminationStatus
            Task { @MainActor in
                guard let self,
                      let idx = self.active.firstIndex(where: { $0.id == mount.id }) else { return }
                if self.unmounting.contains(mount.id) {
                    self.unmounting.remove(mount.id)
                    self.active.remove(at: idx)
                } else {
                    let lastLine = err.split(whereSeparator: \.isNewline).last.map(String.init)
                    self.active[idx].state =
                        .failed(lastLine ?? (status == 0 ? "Mount ended" : "Mount failed (exit \(status))"))
                }
            }
        }

        active.append(mount)
        if remember { upsertSaved(SavedMount(remote: remote.name, path: folder.path, autoMount: true)) }

        do { try process.run() }
        catch {
            mount.state = .failed("Could not launch rclone")
            return
        }

        // Poll the real mount table; flip to .mounted only once the volume actually appears.
        Task { @MainActor in
            for _ in 0..<20 {                                  // up to ~6s
                try? await Task.sleep(for: .milliseconds(300))
                guard mount.state == .mounting else { return } // failed/removed meanwhile
                if self.isMountPoint(folder) { mount.state = .mounted; return }
                if !process.isRunning { return }               // terminationHandler will mark .failed
            }
            if mount.state == .mounting {
                mount.state = .failed("Timed out waiting for the volume to appear")
            }
        }
    }

    func unmount(_ mount: ActiveMount) {
        unmounting.insert(mount.id)
        let path = mount.mountPoint.path
        let process = mount.process
        active.removeAll { $0.id == mount.id }
        Task.detached {
            Self.forceUnmount(at: path)
            if process.isRunning { process.terminate() }
        }
    }

    /// Remove a failed entry the user has acknowledged.
    func dismiss(_ mount: ActiveMount) { active.removeAll { $0.id == mount.id } }

    func reveal(_ mount: ActiveMount) {
        NSWorkspace.shared.activateFileViewerSelecting([mount.mountPoint])
    }

    /// True when `url` sits on a different device than its parent — i.e. it's a mount point.
    private func isMountPoint(_ url: URL) -> Bool {
        var here = stat(), parent = stat()
        guard stat(url.path, &here) == 0,
              stat(url.deletingLastPathComponent().path, &parent) == 0 else { return false }
        return here.st_dev != parent.st_dev
    }

    /// Best-effort cleanup on app termination.
    func unmountAll() {
        let mounts = active
        active.removeAll()
        for mount in mounts {
            Self.forceUnmount(at: mount.mountPoint.path)
            if mount.process.isRunning { mount.process.terminate() }
        }
    }

    private nonisolated static func forceUnmount(at path: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        task.arguments = ["unmount", "force", path]
        try? task.run()
        task.waitUntilExit()
    }

    // MARK: Persistence

    func autoMountSaved(remotes: [Remote]) {
        for entry in saved where entry.autoMount {
            guard let remote = remotes.first(where: { $0.name == entry.remote }) else { continue }
            let folder = URL(fileURLWithPath: entry.path)
            guard FileManager.default.fileExists(atPath: entry.path),
                  !active.contains(where: { $0.mountPoint == folder }) else { continue }
            mount(remote, at: folder, remember: false)
        }
    }

    func forget(_ entry: SavedMount) {
        saved.removeAll { $0.id == entry.id }; persistSaved()
    }

    private func upsertSaved(_ entry: SavedMount) {
        if let idx = saved.firstIndex(where: { $0.id == entry.id }) { saved[idx] = entry }
        else { saved.append(entry) }
        persistSaved()
    }

    private func loadSaved() {
        guard let data = UserDefaults.standard.data(forKey: savedKey),
              let decoded = try? JSONDecoder().decode([SavedMount].self, from: data) else { return }
        saved = decoded
    }

    private func persistSaved() {
        guard let data = try? JSONEncoder().encode(saved) else { return }
        UserDefaults.standard.set(data, forKey: savedKey)
    }

    /// Opens the rclone mount documentation (covers the macFUSE requirement).
    static func openMountDocs() {
        NSWorkspace.shared.open(URL(string: "https://rclone.org/commands/rclone_mount/")!)
    }
}
