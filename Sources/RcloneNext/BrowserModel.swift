import Foundation
import Observation
import AppKit

@MainActor @Observable
final class BrowserModel {
    let remote: Remote
    private unowned let app: AppModel
    private let backend = RcloneBackend.shared

    var items: [RcloneItem] = []
    var pathStack: [String] = []          // sub-folders below the remote root
    var isLoading = false
    var error: String?
    var selection: Set<RcloneItem.ID> = []

    /// Shared with the Dashboard via AppModel — non-nil while a copy is running.
    var activeTransfer: TransferProgress? { app.activeTransfer }

    init(remote: Remote, app: AppModel) { self.remote = remote; self.app = app }

    /// Full rclone path of the directory currently shown, e.g. "gdrive:Docs/2024".
    var currentPath: String {
        pathStack.isEmpty ? remote.root : "\(remote.root)\(pathStack.joined(separator: "/"))"
    }

    func load(forceRefresh: Bool = false) async {
        // Serve a recent listing instantly without re-running rclone.
        if !forceRefresh, let cached = app.cache.cached(currentPath) {
            items = cached
            return
        }
        isLoading = true; error = nil
        defer { isLoading = false }
        do {
            let fetched = try await backend.list(at: currentPath).sorted { lhs, rhs in
                lhs.isDir != rhs.isDir ? lhs.isDir
                                       : lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            items = fetched
            app.cache.store(fetched, for: currentPath)
        }
        catch { self.error = error.localizedDescription }
    }

    func open(_ item: RcloneItem) async {
        guard item.isDir else { return }
        pathStack.append(item.name)
        await load()
    }

    func goUp() async { guard !pathStack.isEmpty else { return }
        pathStack.removeLast(); await load() }

    /// Jump to an ancestor in the breadcrumb. `index` is the count of path components to keep
    /// (0 == remote root).
    func go(to index: Int) async {
        guard index >= 0, index < pathStack.count else { return }
        pathStack = Array(pathStack.prefix(index))
        await load()
    }

    /// Mount this remote at the chosen folder (persisted for auto-remount on launch).
    func mount(at folder: URL) {
        app.mounts.mount(remote, at: folder, remember: true)
    }

    /// `rclone size` on a folder → human-readable "N objects · X GB", or nil on error.
    func calculateSize(_ item: RcloneItem) async -> String? {
        do {
            let result = try await backend.size(of: "\(currentPath)/\(item.name)")
            let bytes = ByteCountFormatter.string(fromByteCount: result.bytes, countStyle: .file)
            return "\(result.count) objects · \(bytes)"
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func delete(_ items: [RcloneItem]) async {
        for item in items {
            do { try await backend.delete(item, in: currentPath) }
            catch { self.error = error.localizedDescription }
        }
        app.cache.invalidate(currentPath)
        await load(forceRefresh: true)
    }

    /// Create a folder in the current directory.
    func makeFolder(named name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do { try await backend.mkdir("\(currentPath)/\(trimmed)") }
        catch { self.error = error.localizedDescription }
        app.cache.invalidate(currentPath)
        await load(forceRefresh: true)
    }

    /// Rename an item within the current directory via `rclone moveto`.
    func rename(_ item: RcloneItem, to newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != item.name else { return }
        do { try await backend.moveto(from: "\(currentPath)/\(item.name)",
                                      to: "\(currentPath)/\(trimmed)") }
        catch { self.error = error.localizedDescription }
        app.cache.invalidate(currentPath)
        await load(forceRefresh: true)
    }

    /// Generate a public share link and return it (caller copies to the pasteboard).
    func publicLink(_ item: RcloneItem) async -> String? {
        do { return try await backend.link(for: "\(currentPath)/\(item.name)") }
        catch { self.error = error.localizedDescription; return nil }
    }

    /// Download a file to a temp dir and open it in its default app.
    func openFile(_ item: RcloneItem) async {
        guard !item.isDir else { return }
        let session = UUID().uuidString
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("RcloneNext", isDirectory: true)
            .appendingPathComponent(session, isDirectory: true)
            .appendingPathComponent(item.name)
        try? FileManager.default.createDirectory(
            at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            _ = try await app.performTransfer(
                label: "Opening \(item.name)…",
                stream: backend.copy(from: "\(currentPath)/\(item.name)", to: dest.path)
            )
            NSWorkspace.shared.open(dest)
        } catch is TransferError {
            // surfaced via AppModel.loadError
        } catch { self.error = error.localizedDescription }
    }

    func upload(localURL: URL) async {
        let dest = "\(currentPath)/\(localURL.lastPathComponent)"
        await runTransfer(from: localURL.path, to: dest)
    }

    func download(_ item: RcloneItem, to folder: URL) async {
        let source = "\(currentPath)/\(item.name)"
        await runTransfer(from: source, to: folder.appendingPathComponent(item.name).path)
    }

    private func runTransfer(from source: String, to dest: String) async {
        let name = (source as NSString).lastPathComponent
        do {
            _ = try await app.performTransfer(
                label: name,
                stream: backend.copy(from: source, to: dest)
            ) { [weak self] in
                guard let self else { return }
                self.app.cache.invalidate(self.currentPath)
                await self.load(forceRefresh: true)
            }
        } catch is TransferError {
            // surfaced via AppModel.loadError
        } catch { self.error = error.localizedDescription }
    }
}
