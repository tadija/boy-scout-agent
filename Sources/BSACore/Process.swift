import Foundation
import ProcessSupport
#if os(Linux)
import Glibc
#else
import Darwin
#endif

public enum BSAError: Error, CustomStringConvertible {
    case message(String)
    public var description: String { switch self { case .message(let value): return value } }
}

public enum Cancellation {
    public nonisolated(unsafe) static var requested: Int32 = 0
    public static func install() {
        signal(SIGINT) { _ in Cancellation.requested = 1 }
        signal(SIGTERM) { _ in Cancellation.requested = 1 }
    }
}

public struct CommandResult {
    public let status: Int32
    public let output: String
    public let timedOut: Bool
    var outputTruncated = false
    var outputIsUTF8 = true
}

/// Files rather than pipes avoid deadlocks when a child produces large output.
public final class CommandRunner {
    public init() {}
    public func run(_ executable: String, _ arguments: [String], cwd: URL,
                    timeout: TimeInterval = 1800, environment: [String: String] = [:],
                    cancellable: Bool = true) throws -> CommandResult {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        guard FileManager.default.createFile(atPath: temporary.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
            throw BSAError.message("Cannot create command log")
        }
        let output = try FileHandle(forWritingTo: temporary)
        defer { try? output.close(); try? FileManager.default.removeItem(at: temporary) }
        let input = open("/dev/null", O_RDONLY | O_CLOEXEC)
        guard input >= 0 else { throw BSAError.message("Cannot open /dev/null") }
        defer { close(input) }
        let inherited = ProcessInfo.processInfo.environment.filter { !$0.key.hasPrefix("GIT_") }
        let environmentValues = inherited.merging(environment) { _, new in new }.map { "\($0.key)=\($0.value)" }
        let argumentPointers = ([executable] + arguments).map { strdup($0) } + [nil]
        let environmentPointers = environmentValues.map { strdup($0) } + [nil]
        defer {
            argumentPointers.forEach { free($0) }
            environmentPointers.forEach { free($0) }
        }
        var pid: pid_t = 0
        let spawnResult = argumentPointers.withUnsafeBufferPointer { argv in
            environmentPointers.withUnsafeBufferPointer { envp in
                bsa_spawn(executable, argv.baseAddress!, envp.baseAddress!, cwd.path, input, output.fileDescriptor, &pid)
            }
        }
        guard spawnResult == 0 else { throw BSAError.message("Cannot launch \(executable): \(String(cString: strerror(spawnResult)))") }
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var expired = false
        var status: Int32 = 0
        while true {
            let waited = waitpid(pid, &status, WNOHANG)
            if waited == pid { break }
            if waited == -1 {
                if errno == EINTR { continue }
                throw BSAError.message("Cannot wait for child process")
            }
            if ProcessInfo.processInfo.systemUptime >= deadline || (cancellable && Cancellation.requested != 0) {
                expired = ProcessInfo.processInfo.systemUptime >= deadline
                kill(-pid, SIGTERM)
                let grace = ProcessInfo.processInfo.systemUptime + 1
                var reaped = false
                while ProcessInfo.processInfo.systemUptime < grace {
                    if waitpid(pid, &status, WNOHANG) == pid { reaped = true; break }
                    Thread.sleep(forTimeInterval: 0.02)
                }
                kill(-pid, SIGKILL)
                if !reaped {
                    while waitpid(pid, &status, 0) == -1 && errno == EINTR {}
                }
                break
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        // Clean up ordinary background children even after the main command exited.
        kill(-pid, SIGKILL)
        let reader = try FileHandle(forReadingFrom: temporary)
        defer { try? reader.close() }
        let size = try reader.seekToEnd()
        try reader.seek(toOffset: size > 1_048_576 ? size - 1_048_576 : 0)
        let data = try reader.read(upToCount: 1_048_576) ?? Data()
        let exitCode: Int32 = (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
        return CommandResult(status: exitCode,
                             output: String(decoding: data, as: UTF8.self), timedOut: expired,
                             outputTruncated: size > 1_048_576, outputIsUTF8: String(data: data, encoding: .utf8) != nil)
    }
}
