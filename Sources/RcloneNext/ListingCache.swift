import Foundation

/// In-memory cache of directory listings keyed by full rclone path (e.g. "gdrive:Docs").
/// Lives on AppModel so it survives BrowserModel recreation when switching remotes.
/// Entries are reused until `ttl` seconds old, so navigating back and forth doesn't
/// re-run `rclone lsjson` every time.
@MainActor
final class ListingCache {
    /// How long a listing stays fresh. Tweak to taste.
    var ttl: TimeInterval = 60

    private struct Entry { let items: [RcloneItem]; let time: Date }
    private var store: [String: Entry] = [:]

    /// Returns the cached listing for `path` if it's still within the TTL.
    func cached(_ path: String) -> [RcloneItem]? {
        guard let entry = store[path], Date().timeIntervalSince(entry.time) < ttl else { return nil }
        return entry.items
    }

    func store(_ items: [RcloneItem], for path: String) {
        store[path] = Entry(items: items, time: Date())
    }

    /// Drop one path (after a mutation there) or everything.
    func invalidate(_ path: String) { store[path] = nil }
    func clear() { store.removeAll() }
}
