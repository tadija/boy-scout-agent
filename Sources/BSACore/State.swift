import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif

struct RepositoryLock {
    let descriptor: Int32
    init(at url: URL) throws {
        descriptor = open(url.path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw BSAError.message("Cannot open repository lock") }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            throw BSAError.message("Another BSA run holds this repository's lock")
        }
    }
    func release() { flock(descriptor, LOCK_UN); close(descriptor) }
}

public struct Check: Codable {
    public let command: String
    public let status: Int32
    public let output: String
}

public struct Record: Codable {
    public let id: String
    public let repository: String
    public let branch: String
    public let started: Date
    public var finished: Date?
    public var outcome: String
    public var baseline: String?
    public var commit: String?
    public var task: String?
    public var paths: [String] = []
    public var baselineChecks: [Check] = []
    public var checks: [Check] = []
    public var detail: String?
}

struct StateStore {
    let directory: URL
    init(repository: Repository, dataDirectory: URL?) throws {
        // Hex encoding is stable and collision-free, unlike Swift's randomized Hasher.
        let identity = repository.commonDirectory.path.utf8.map { String(format: "%02x", $0) }.joined()
        // Split long identities into path components to respect filesystem component limits.
        let components = stride(from: 0, to: identity.count, by: 100).map { offset in
            String(identity.dropFirst(offset).prefix(100))
        }
        let environment = ProcessInfo.processInfo.environment
        let base = dataDirectory ?? URL(fileURLWithPath: environment["XDG_DATA_HOME"] ??
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/share").path).appendingPathComponent("bsa")
        directory = components.reduce(base.appendingPathComponent("repositories")) { $0.appendingPathComponent($1) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
    }
    var latest: Record? {
        get throws {
            let url = directory.appendingPathComponent("latest.json")
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return try JSONDecoder().decode(Record.self, from: Data(contentsOf: url))
        }
    }
    func ownedBranches() throws -> [String: String] {
        let url = directory.appendingPathComponent("branches.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }
    func own(branch: String, commit: String) throws {
        var branches = try ownedBranches()
        branches[branch] = commit
        try JSONEncoder().encode(branches).write(to: directory.appendingPathComponent("branches.json"), options: .atomic)
    }
    func save(_ record: Record) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(record)
        try data.write(to: directory.appendingPathComponent(record.id + ".json"), options: .atomic)
        try data.write(to: directory.appendingPathComponent("latest.json"), options: .atomic)
    }
}
