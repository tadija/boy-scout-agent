import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif

public struct Updater {
    public init() {}

    public func update(executable: URL, onProgress: (String) -> Void = { _ in }) throws {
        let commands = CommandRunner()
        try update(executable: executable, onProgress: onProgress) { arguments, directory in
            try commands.run("/usr/bin/env", arguments, cwd: directory)
        }
    }

    func update(executable: URL, onProgress: (String) -> Void,
                run: ([String], URL) throws -> CommandResult) throws {
        let files = FileManager.default
        let destination = executable.resolvingSymlinksInPath()
        let temporary = files.temporaryDirectory.appendingPathComponent("bsa-update-" + UUID().uuidString)
        try files.createDirectory(at: temporary, withIntermediateDirectories: false)
        defer { try? files.removeItem(at: temporary) }
        let source = temporary.appendingPathComponent("source")

        func checked(_ arguments: [String], at directory: URL) throws -> String {
            guard !Cancellation.shouldStop else { throw BSAError.message("Update cancelled") }
            let result = try run(arguments, directory)
            guard !Cancellation.shouldStop else { throw BSAError.message("Update cancelled") }
            guard result.status == 0, !result.timedOut else {
                throw BSAError.message("Update failed (\(arguments.prefix(2).joined(separator: " "))):\n\(result.output)")
            }
            guard !result.outputTruncated, result.outputIsUTF8 else {
                throw BSAError.message("Update command output is truncated or not UTF-8")
            }
            return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        onProgress("Downloading latest BSA source from GitHub (main)…")
        _ = try checked(["git", "clone", "--depth", "1", "--branch", "main", "--single-branch",
                         "https://github.com/tadija/boy-scout-agent.git", source.path], at: temporary)
        onProgress("Building release executable (requires Swift 6 or later)…")
        _ = try checked(["swift", "build", "-c", "release"], at: source)
        let buildPath = try checked(["swift", "build", "-c", "release", "--show-bin-path"], at: source)
        guard buildPath.hasPrefix("/"), !buildPath.contains("\n") else {
            throw BSAError.message("Swift returned an invalid build directory")
        }
        let staged = destination.deletingLastPathComponent().appendingPathComponent(".bsa-update-" + UUID().uuidString)
        defer { try? files.removeItem(at: staged) }
        try files.copyItem(at: URL(fileURLWithPath: buildPath).appendingPathComponent("bsa"), to: staged)
        try files.setAttributes([.posixPermissions: 0o755], ofItemAtPath: staged.path)
        let version = try checked([staged.path, "--version"], at: temporary)
        guard version.hasPrefix("Boy Scout Agent ") else {
            throw BSAError.message("Built executable did not report a BSA version")
        }
        // Rename on the same filesystem replaces even a running Linux executable.
        guard rename(staged.path, destination.path) == 0 else {
            throw BSAError.message("Cannot replace \(destination.path): \(String(cString: strerror(errno)))")
        }
        onProgress("Installed \(version) at \(destination.path)")
    }
}
