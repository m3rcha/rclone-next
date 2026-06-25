import Foundation

struct Remote: Identifiable, Hashable, Sendable {
    let name: String            // "gdrive"
    var id: String { name }
    var root: String { "\(name):" }
}

/// One row of `rclone lsjson` output.
struct RcloneItem: Identifiable, Hashable, Sendable, Codable {
    let path: String            // relative to listed dir
    let name: String
    let size: Int64             // -1 for directories
    let mimeType: String?
    let modTime: Date?
    let isDir: Bool

    var id: String { path }

    enum CodingKeys: String, CodingKey {
        case path = "Path", name = "Name", size = "Size"
        case mimeType = "MimeType", modTime = "ModTime", isDir = "IsDir"
    }
}

struct TransferProgress: Sendable, Equatable {
    var bytes: Int64 = 0
    var totalBytes: Int64 = 0
    var speed: Double = 0       // bytes/sec
    var transfers: Int = 0
    var eta: Int? = nil
    var fraction: Double { totalBytes > 0 ? Double(bytes) / Double(totalBytes) : 0 }
}

/// What the sidebar selection points at — the status dashboard or a specific remote.
enum SidebarItem: Hashable { case dashboard; case remote(Remote) }

/// One backend type from `rclone config providers`.
struct Provider: Decodable, Identifiable, Sendable {
    let name: String
    let description: String
    let options: [ProviderOption]

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name = "Name", description = "Description", options = "Options"
    }

    /// OAuth backends expose a (hidden) "token" option; a curated set covers any
    /// the heuristic misses.
    var isOAuth: Bool {
        options.contains { $0.name == "token" } || Self.oauthTypes.contains(name)
    }

    static let oauthTypes: Set<String> = [
        "drive", "dropbox", "onedrive", "box", "pcloud", "yandex", "googlephotos",
        "premiumizeme", "putio", "sharefile", "jottacloud", "hidrive", "zoho"
    ]

    /// Required, non-advanced fields to render as credential inputs.
    var credentialFields: [ProviderOption] {
        options.filter { $0.required && !($0.advanced ?? false) }
    }
}

struct ProviderOption: Decodable, Identifiable, Sendable {
    let name: String
    let help: String?
    let required: Bool
    let isPassword: Bool?
    let advanced: Bool?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name = "Name", help = "Help", required = "Required",
             isPassword = "IsPassword", advanced = "Advanced"
    }
}

/// Output of `rclone about remote: --json` (fields are backend-dependent).
struct RemoteAbout: Decodable, Sendable {
    let total: Int64?
    let used: Int64?
    let free: Int64?
    let trashed: Int64?
}

/// One step of rclone's `--non-interactive` config state machine. Configuration is
/// finished when there is no further `option` and no `error`.
struct ConfigStep: Decodable, Sendable {
    let state: String
    let option: ConfigOption?
    let error: String

    enum CodingKeys: String, CodingKey { case state = "State", option = "Option", error = "Error" }

    var isComplete: Bool { option == nil && error.isEmpty }
}

/// A single question rclone is asking during configuration.
struct ConfigOption: Decodable, Sendable, Identifiable {
    let name: String
    let help: String?
    let defaultStr: String?
    let examples: [ConfigExample]?
    let required: Bool
    let isPassword: Bool?
    let sensitive: Bool?
    let exclusive: Bool?
    let type: String?

    var id: String { name }
    var isSecret: Bool { (isPassword ?? false) || (sensitive ?? false) }
    var isBool: Bool { type == "bool" }

    enum CodingKeys: String, CodingKey {
        case name = "Name", help = "Help", defaultStr = "DefaultStr",
             examples = "Examples", required = "Required", isPassword = "IsPassword",
             sensitive = "Sensitive", exclusive = "Exclusive", type = "Type"
    }
}

struct ConfigExample: Decodable, Sendable, Identifiable {
    let value: String
    let help: String?
    var id: String { value }
    enum CodingKeys: String, CodingKey { case value = "Value", help = "Help" }
}

/// Result of an update check, for both the rclone binary and the app itself.
enum UpdateState: Equatable, Sendable {
    case idle, checking, upToDate, available(String), failed(String), notConfigured
}

/// rclone transfer subcommands used by the Sync/Copy/Move jobs UI.
enum TransferOp: String, CaseIterable, Sendable {
    case copy, sync, move, copyto

    var title: String {
        switch self {
        case .copy: return "Copy"
        case .sync: return "Sync"
        case .move: return "Move"
        case .copyto: return "Copy"
        }
    }
    /// sync and move can delete at the destination — gate them behind confirmation.
    var isDestructive: Bool { self == .sync || self == .move }
}

/// Output of `rclone size --json`.
struct SizeResult: Decodable, Sendable {
    let count: Int64
    let bytes: Int64
}

// MARK: - Mounting

enum MountState: Equatable, Sendable { case mounting, mounted, failed(String) }

/// A persisted mount the user asked to remember (auto-remount on launch).
struct SavedMount: Codable, Identifiable, Sendable {
    let remote: String
    let path: String
    var autoMount: Bool
    /// Composite key so one remote can have multiple saved mount points.
    var id: String { "\(remote)@\(path)" }
}

/// rclone dedupe resolution modes (the non-interactive `mode` argument).
enum DedupeMode: String, CaseIterable, Identifiable {
    case newest, oldest, largest, smallest, rename, skip
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum RcloneError: LocalizedError {
    case binaryNotFound
    case nonZeroExit(code: Int32, stderr: String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "Could not locate the rclone executable. Install it via Homebrew "
                 + "(`brew install rclone`) or set its path in Settings."
        case .nonZeroExit(let code, let stderr):
            return "rclone exited with code \(code).\n\(stderr)"
        case .decoding(let msg):
            return "Failed to read rclone output: \(msg)"
        }
    }
}
