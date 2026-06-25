import Foundation

/// Resolves and persists the rclone executable path.
enum RclonePathSettings {
    static let userDefaultsKey = "rcloneExecutablePath"

    static let defaultCandidates = [
        "/opt/homebrew/bin/rclone",
        "/usr/local/bin/rclone",
        "/usr/bin/rclone",
    ]

    /// User override if set and executable; otherwise the first discovered default.
    static func resolve() -> URL {
        if let custom = UserDefaults.standard.string(forKey: userDefaultsKey),
           FileManager.default.isExecutableFile(atPath: custom) {
            return URL(fileURLWithPath: custom)
        }
        return discoverDefault()
    }

    static func discoverDefault() -> URL {
        let path = defaultCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            ?? defaultCandidates[1]
        return URL(fileURLWithPath: path)
    }

    static func customPath() -> String? {
        UserDefaults.standard.string(forKey: userDefaultsKey)
    }

    static func setCustomPath(_ path: String?) {
        if let path, !path.isEmpty {
            UserDefaults.standard.set(path, forKey: userDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        }
    }

    /// Parses `rclone listremotes` stdout into remote names.
    static func parseRemoteNames(from output: String) -> [String] {
        output.split(whereSeparator: \.isNewline)
            .map { $0.hasSuffix(":") ? String($0.dropLast()) : String($0) }
            .filter { !$0.isEmpty }
    }
}
