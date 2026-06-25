import Foundation

/// Thin, Sendable wrapper around the rclone CLI. All process work happens off the
/// main actor; results come back via async/await or an AsyncThrowingStream.
final class RcloneBackend: Sendable {
    static let shared = RcloneBackend()
    let executableURL: URL

    init() {
        let candidates = [
            "/opt/homebrew/bin/rclone",   // Apple Silicon Homebrew
            "/usr/local/bin/rclone",      // Intel Homebrew  (← present on this machine)
            "/usr/bin/rclone"
        ]
        self.executableURL = URL(fileURLWithPath:
            candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            ?? "/usr/local/bin/rclone")
    }

    // MARK: Generic execution

    /// Runs rclone to completion and returns stdout. Drains stderr concurrently to
    /// avoid the 64 KB pipe-buffer deadlock on large output. stdin is `/dev/null` so
    /// interactive prompts (e.g. Drive's "Shared Drive?" after OAuth) resolve to their
    /// defaults instead of blocking forever. Terminates the process on task cancellation.
    func run(_ args: [String]) async throws -> Data {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = args
        process.standardInput = FileHandle.nullDevice
        let outPipe = Pipe(), errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    // Drain stderr off-thread so stdout's readToEnd() can't deadlock.
                    let lock = NSLock()
                    var errData = Data()
                    errPipe.fileHandleForReading.readabilityHandler = { h in
                        let d = h.availableData
                        guard !d.isEmpty else { return }
                        lock.lock(); errData.append(d); lock.unlock()
                    }

                    do { try process.run() }
                    catch { cont.resume(throwing: RcloneError.binaryNotFound); return }

                    let outData = (try? outPipe.fileHandleForReading.readToEnd()) ?? Data()
                    process.waitUntilExit()
                    errPipe.fileHandleForReading.readabilityHandler = nil
                    lock.lock(); let stderr = errData; lock.unlock()

                    if process.terminationStatus == 0 {
                        cont.resume(returning: outData)
                    } else {
                        cont.resume(throwing: RcloneError.nonZeroExit(
                            code: process.terminationStatus,
                            stderr: String(decoding: stderr, as: UTF8.self)))
                    }
                }
            }
        } onCancel: {
            process.terminate()
        }
    }

    // MARK: High-level commands

    /// `rclone listremotes` → ["gdrive", "s3", …]
    func listRemotes() async throws -> [Remote] {
        let data = try await run(["listremotes"])
        return String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .map { $0.hasSuffix(":") ? String($0.dropLast()) : String($0) }
            .filter { !$0.isEmpty }
            .map(Remote.init)
    }

    /// `rclone lsjson <path>` → directory listing.
    func list(at path: String) async throws -> [RcloneItem] {
        let data = try await run(["lsjson", path])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            return Self.iso.date(from: s)
                ?? ISO8601DateFormatter().date(from: s)
                ?? .distantPast
        }
        do { return try decoder.decode([RcloneItem].self, from: data) }
        catch { throw RcloneError.decoding("\(error)") }
    }

    /// Delete a file (`deletefile`) or directory tree (`purge`).
    func delete(_ item: RcloneItem, in dir: String) async throws {
        let full = "\(dir)/\(item.name)"
        _ = try await run([item.isDir ? "purge" : "deletefile", full])
    }

    // MARK: Status & configuration

    /// First line of `rclone version` → "v1.74.3".
    func version() async throws -> String {
        let out = String(decoding: try await run(["version"]), as: UTF8.self)
        let first = out.split(whereSeparator: \.isNewline).first ?? ""
        return first.replacingOccurrences(of: "rclone ", with: "")
    }

    /// `rclone config providers` → catalog of backend types and their options.
    func providers() async throws -> [Provider] {
        let data = try await run(["config", "providers"])
        do { return try JSONDecoder().decode([Provider].self, from: data) }
        catch { throw RcloneError.decoding("\(error)") }
    }

    /// `rclone about remote: --json`. Returns nil for backends that don't support it.
    func about(_ remote: Remote) async throws -> RemoteAbout? {
        do {
            return try JSONDecoder().decode(
                RemoteAbout.self, from: try await run(["about", remote.root, "--json"]))
        } catch RcloneError.nonZeroExit { return nil }   // backend doesn't report usage
    }

    /// Non-interactive create. For OAuth backends rclone auto-opens the browser and
    /// blocks until authorization completes — `run` already waits for termination.
    func createRemote(name: String, type: String, options: [String: String]) async throws {
        var args = ["config", "create", name, type]
        for (key, value) in options { args += [key, value] }
        _ = try await run(args)
    }

    /// `rclone config delete <name>`.
    func deleteRemote(name: String) async throws {
        _ = try await run(["config", "delete", name])
    }

    // MARK: Interactive (state-machine) configuration

    /// Begin configuring a remote via rclone's non-interactive state machine. Returns the
    /// first question. Note: this already writes a partial remote section — call
    /// `deleteRemote` to clean up if the user abandons the flow.
    func configStart(name: String, type: String) async throws -> ConfigStep {
        try decodeStep(try await run(["config", "create", name, type, "--non-interactive"]))
    }

    /// Answer the previous question and get the next. For OAuth backends, this is the call
    /// that opens the browser and blocks until sign-in completes.
    func configContinue(name: String, state: String, result: String) async throws -> ConfigStep {
        try decodeStep(try await run(
            ["config", "update", name, "--non-interactive",
             "--continue", "--state", state, "--result", result]))
    }

    private func decodeStep(_ data: Data) throws -> ConfigStep {
        do { return try JSONDecoder().decode(ConfigStep.self, from: data) }
        catch { throw RcloneError.decoding("\(error)") }
    }

    /// `rclone version --check` → parsed "yours:" / "latest:" versions.
    func rcloneUpdateCheck() async throws -> (current: String, latest: String) {
        let out = String(decoding: try await run(["version", "--check"]), as: UTF8.self)
        func field(_ key: String) -> String {
            out.split(whereSeparator: \.isNewline)
               .first { $0.contains(key) }?
               .replacingOccurrences(of: key, with: "")
               .trimmingCharacters(in: .whitespaces) ?? ""
        }
        return (field("yours:"), field("latest:"))
    }

    /// Copy source → dest with streamed progress (file-level copy of one path onto another).
    /// Thin wrapper over `transfer` kept for the file browser's upload/download.
    func copy(from source: String, to dest: String)
        -> AsyncThrowingStream<TransferProgress, Error> {
        transfer(.copyto, from: source, to: dest, dryRun: false)
    }

    /// Run any of rclone's transfer subcommands with streamed JSON-stats progress.
    /// `dryRun` adds `--dry-run` so sync/move can be previewed before committing.
    func transfer(_ op: TransferOp, from source: String, to dest: String, dryRun: Bool)
        -> AsyncThrowingStream<TransferProgress, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            process.executableURL = executableURL
            process.arguments = [op.rawValue, source, dest,
                                  "--use-json-log", "--stats", "500ms", "-v"]
                + (dryRun ? ["--dry-run"] : [])
            let errPipe = Pipe()
            process.standardError = errPipe
            process.standardOutput = Pipe()
            process.standardInput = FileHandle.nullDevice

            errPipe.fileHandleForReading.readabilityHandler = { h in
                let chunk = h.availableData
                guard !chunk.isEmpty else { return }
                for line in String(decoding: chunk, as: UTF8.self)
                        .split(separator: "\n") {
                    guard let d = line.data(using: .utf8),
                          let obj = try? JSONSerialization.jsonObject(with: d)
                                          as? [String: Any],
                          let s = obj["stats"] as? [String: Any] else { continue }
                    var p = TransferProgress()
                    p.bytes      = (s["bytes"]      as? NSNumber)?.int64Value ?? 0
                    p.totalBytes = (s["totalBytes"] as? NSNumber)?.int64Value ?? 0
                    p.speed      = (s["speed"]      as? NSNumber)?.doubleValue ?? 0
                    p.transfers  = (s["transfers"]  as? NSNumber)?.intValue ?? 0
                    p.eta        = (s["eta"]        as? NSNumber)?.intValue
                    continuation.yield(p)
                }
            }
            process.terminationHandler = { proc in
                errPipe.fileHandleForReading.readabilityHandler = nil
                if proc.terminationStatus == 0 { continuation.finish() }
                else { continuation.finish(throwing: RcloneError.nonZeroExit(
                    code: proc.terminationStatus, stderr: "transfer failed")) }
            }
            do { try process.run() }
            catch { continuation.finish(throwing: RcloneError.binaryNotFound) }

            continuation.onTermination = { @Sendable _ in
                if process.isRunning { process.terminate() }   // supports cancellation
            }
        }
    }

    // MARK: Maintenance & info

    /// `rclone size <path> --json` → object count + total bytes.
    func size(of path: String) async throws -> SizeResult {
        do { return try JSONDecoder().decode(SizeResult.self, from: try await run(["size", path, "--json"])) }
        catch let e as RcloneError { throw e }
        catch { throw RcloneError.decoding("\(error)") }
    }

    /// `rclone cleanup remote:` — empties trash / removes old versions where supported.
    func cleanup(_ remote: Remote) async throws { _ = try await run(["cleanup", remote.root]) }

    /// `rclone dedupe <mode> remote:` — non-interactive duplicate resolution.
    func dedupe(_ remote: Remote, mode: DedupeMode) async throws {
        _ = try await run(["dedupe", mode.rawValue, remote.root])
    }

    // MARK: File operations

    /// `rclone config dump` → map of remote name → backend type (for provider icons).
    func configDump() async throws -> [String: String] {
        let data = try await run(["config", "dump"])
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return obj.compactMapValues { ($0 as? [String: Any])?["type"] as? String }
    }

    /// `rclone link <path>` → a public share URL (backend-dependent).
    func link(for path: String) async throws -> String {
        String(decoding: try await run(["link", path]), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `rclone mkdir <path>`.
    func mkdir(_ path: String) async throws { _ = try await run(["mkdir", path]) }

    /// `rclone moveto <src> <dst>` — used for rename within a remote.
    func moveto(from: String, to: String) async throws {
        _ = try await run(["moveto", from, to])
    }

    /// macFUSE is required for `rclone mount` on macOS.
    static var isMacFUSEInstalled: Bool {
        FileManager.default.fileExists(atPath: "/Library/Filesystems/macfuse.fs")
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
