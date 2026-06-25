import Foundation

/// Checks this app against its GitHub Releases. Inert until `owner`/`repo` point at a
/// real repository with published releases — surfaced honestly as `.notConfigured`.
enum AppUpdate {
    // The published repository for this app.
    static let owner = "m3rcha"
    static let repo  = "rclone-next"

    /// Compares CFBundleShortVersionString against the latest GitHub release tag.
    static func check() async -> UpdateState {
        guard let url = URL(string:
            "https://api.github.com/repos/\(owner)/\(repo)/releases/latest") else {
            return .notConfigured
        }
        do {
            var req = URLRequest(url: url)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, resp) = try await URLSession.shared.data(for: req)
            if (resp as? HTTPURLResponse)?.statusCode == 404 { return .notConfigured }

            let tag = (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["tag_name"]
                as? String ?? ""
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            guard !latest.isEmpty else { return .notConfigured }

            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                as? String ?? "0"
            return latest.compare(current, options: .numeric) == .orderedDescending
                ? .available(latest) : .upToDate
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
