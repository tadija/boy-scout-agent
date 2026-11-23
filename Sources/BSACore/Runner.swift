import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif

public final class Runner {
    private let commands = CommandRunner()
    public init() {}

    public func prompt(at directory: URL, configuration: Configuration? = nil, dataDirectory: URL? = nil) throws -> String {
        let repo = try Repository(at: directory)
        let config = try configuration ?? Configuration.load(repository: repo)
        let store = try StateStore(repository: repo, dataDirectory: dataDirectory)
        let recent = try store.recent(branch: targetBranch(configuration: config, repository: repo))
        return Planner.prompt(instructions: config.instructions, recent: recent)
    }

    private func targetBranch(configuration: Configuration, repository: Repository) -> String {
        let slug = repository.root.lastPathComponent.lowercased().map {
            $0.isASCII && ($0.isLetter || $0.isNumber) ? String($0) : "-"
        }.joined()
        return configuration.branch ?? "bsa/\(slug)"
    }

    public func status(at directory: URL, dataDirectory: URL? = nil) throws -> Record? {
        try StateStore(repository: Repository(at: directory), dataDirectory: dataDirectory).latest
    }

    public func stop(at directory: URL) throws {
        let repo = try Repository(at: directory)
        do {
            let lock = try RepositoryLock(at: repo.commonDirectory.appendingPathComponent("bsa.lock"))
            lock.release()
            throw BSAError.message("No active BSA run for this repository")
        } catch let error as BSAError {
            guard error.description.contains("Another BSA run") else { throw error }
        }
        try Data().write(to: repo.commonDirectory.appendingPathComponent("bsa.stop"), options: .atomic)
    }

    public func history(at directory: URL, dataDirectory: URL? = nil) throws -> [Record] {
        let store = try StateStore(repository: Repository(at: directory), dataDirectory: dataDirectory)
        return try FileManager.default.contentsOfDirectory(at: store.directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" && !["latest.json", "branches.json"].contains($0.lastPathComponent) }
            .map { try JSONDecoder().decode(Record.self, from: Data(contentsOf: $0)) }
            .sorted { $0.started > $1.started }
    }

    public func runSession(at directory: URL, configuration: Configuration, harness: any HarnessAdapter,
                           dataDirectory: URL? = nil, deadline: Date? = nil, force: Bool = false, skipChecks: Bool = false, onProgress: (String) -> Void = { _ in }, onIteration: (Record) -> Void = { _ in }) throws -> [Record] {
        try configuration.validate()
        let repo = try Repository(at: directory)
        let sessionLock = try RepositoryLock(at: repo.commonDirectory.appendingPathComponent("bsa.lock"))
        defer { sessionLock.release() }
        let store = try StateStore(repository: repo, dataDirectory: dataDirectory)
        let stop = repo.commonDirectory.appendingPathComponent("bsa.stop")
        try? FileManager.default.removeItem(at: stop)
        Cancellation.stopFile = stop
        defer { Cancellation.stopFile = nil; try? FileManager.default.removeItem(at: stop) }
        try harness.detect(in: repo.root)
        let sessionID = UUID().uuidString.lowercased()
        var records: [Record] = []
        var failures = 0
        var empty = 0
        for index in 0..<configuration.maxIterations {
            if Cancellation.shouldStop || deadline.map({ Date() >= $0 }) == true { break }
            onProgress("Iteration \(index + 1) of \(configuration.maxIterations)")
            let budget = min(configuration.timeoutSeconds, deadline?.timeIntervalSinceNow ?? .infinity)
            let record = try iteration(repo: repo, config: configuration, harness: harness, store: store, sessionID: sessionID, deadline: ProcessInfo.processInfo.systemUptime + budget, force: force, skipChecks: skipChecks, onProgress: onProgress)
            records.append(record)
            onIteration(record)
            failures = ["committed", "no_candidate"].contains(record.outcome) ? 0 : failures + 1
            empty = record.outcome == "no_candidate" ? empty + 1 : 0
            if record.terminal == true || failures >= configuration.failureLimit || empty >= configuration.saturationLimit || ["cancelled", "timed_out"].contains(record.outcome) { break }
        }
        return records
    }

    public func run(at directory: URL, configuration: Configuration? = nil,
                    harness: HarnessAdapter = Harnesses.builtins[0], dataDirectory: URL? = nil, force: Bool = false, skipChecks: Bool = false, onProgress: (String) -> Void = { _ in }) throws -> Record {
        let repo = try Repository(at: directory)
        let config = try configuration ?? Configuration.load(repository: repo)
        try config.validate()
        let store = try StateStore(repository: repo, dataDirectory: dataDirectory)
        // The lock lives in Git's common directory so different data roots cannot bypass it.
        let lock = try RepositoryLock(at: repo.commonDirectory.appendingPathComponent("bsa.lock"))
        defer { lock.release() }
        let stop = repo.commonDirectory.appendingPathComponent("bsa.stop")
        try? FileManager.default.removeItem(at: stop)
        Cancellation.stopFile = stop
        defer { Cancellation.stopFile = nil; try? FileManager.default.removeItem(at: stop) }
        try harness.detect(in: repo.root)
        return try iteration(repo: repo, config: config, harness: harness, store: store, sessionID: UUID().uuidString.lowercased(), deadline: ProcessInfo.processInfo.systemUptime + config.timeoutSeconds, force: force, skipChecks: skipChecks, onProgress: onProgress)
    }

    private func iteration(repo: Repository, config: Configuration, harness: any HarnessAdapter,
                           store: StateStore, sessionID: String, deadline: TimeInterval, force: Bool, skipChecks: Bool, onProgress: (String) -> Void) throws -> Record {
        let history = try store.latest
        if let previous = history, previous.outcome == "running" {
            var recovered = previous
            if let commit = previous.commit, repo.ref("refs/heads/" + previous.branch) == commit {
                recovered.outcome = "committed"
                try store.own(branch: previous.branch, commit: commit)
            } else { recovered.outcome = "interrupted" }
            recovered.phase = nil
            recovered.finished = Date()
            recovered.detail = "Recovered after interruption. Abandoned worktrees are preserved at " + store.directory.path
            try store.save(recovered)
        }
        let base = try repo.git(["rev-parse", "--verify", "--end-of-options", (config.base ?? "HEAD") + "^{commit}"])
        let branch = targetBranch(configuration: config, repository: repo)
        _ = try repo.git(["check-ref-format", "--branch", branch])
        let recent = try store.recent(branch: branch)
        let target = "refs/heads/" + branch
        guard try repo.git(["rev-parse", "--symbolic-full-name", "HEAD"]) != target else {
            throw BSAError.message("Run from your development branch, not the BSA target branch")
        }
        let originalTarget = repo.ref(target)
        if let originalTarget, !force {
            guard try store.ownedBranches()[branch] == originalTarget else {
                throw BSAError.message("Target branch is not owned by BSA or was changed externally. Choose a new --branch or use --force to continue from the existing branch tip.")
            }
        }
        let baseline = originalTarget ?? base
        if let originalTarget, !force, !repo.isAncestor(base, originalTarget) {
            throw BSAError.message("BSA branch diverged from the configured base. Choose a new --branch or use --force to continue from its tip without rewriting history.")
        }
        try repo.requireUncheckedOut(target)
        if force, let originalTarget {
            try store.own(branch: branch, commit: originalTarget)
            onProgress("Using existing branch \(branch) at \(originalTarget.prefix(12))")
        }
        let id = UUID().uuidString.lowercased()
        let worktree = store.directory.appendingPathComponent("worktree-" + id)
        var record = Record(id: id, repository: repo.root.path, branch: branch, started: Date(), outcome: "running", baseline: baseline)
        record.sessionID = sessionID
        record.harness = harness.name
        try store.save(record)
        var phaseStarted = ProcessInfo.processInfo.systemUptime
        func finishPhase() {
            if let phase = record.phase {
                if record.phaseSeconds == nil { record.phaseSeconds = [:] }
                record.phaseSeconds?[phase] = ProcessInfo.processInfo.systemUptime - phaseStarted
            }
        }
        func beginPhase(_ phase: String) throws {
            finishPhase()
            record.phase = phase
            phaseStarted = ProcessInfo.processInfo.systemUptime
            try store.save(record)
            onProgress(phase + "…")
        }
        var worktrees: [URL] = []
        func remaining() -> TimeInterval { max(0.001, deadline - ProcessInfo.processInfo.systemUptime) }
        func checkBudget() throws {
            if Cancellation.shouldStop { throw BSAError.message("cancelled") }
            if ProcessInfo.processInfo.systemUptime >= deadline { throw BSAError.message("timed_out") }
        }
        func checks(_ values: [String], at directory: URL, baseline: Bool) throws {
            for command in values {
                try checkBudget()
                let output = try commands.run("/bin/sh", ["-c", command], cwd: directory, timeout: remaining())
                let check = Check(command: command, status: output.status, output: output.output)
                if baseline { record.baselineChecks.append(check) }
                else { record.checks.append(check) }
                try store.save(record)
                try checkBudget()
                if output.timedOut { throw BSAError.message("timed_out") }
            }
        }
        func addWorktree(_ directory: URL) throws {
            try repo.git(["worktree", "add", "--detach", directory.path, baseline])
            worktrees.append(directory)
        }
        func stage(at directory: URL) throws {
            // Git add reports errors for explicit ignored exclusions on some versions.
            let tracked = try repo.git(["ls-files", "-v", "-z"], at: directory)
            let paths = try tracked.split(separator: "\0").map { entry in
                guard entry.hasPrefix("H ") else {
                    throw BSAError.message("Unsupported index entry in isolated worktree")
                }
                return String(entry.dropFirst(2)) + "\0"
            }.joined()
            let untracked = try repo.git(["ls-files", "--others", "--exclude-standard", "-z",
                                          "--", ".", ":(exclude).build"], at: directory)
            guard !paths.isEmpty || !untracked.isEmpty else { return }
            let pathspec = store.directory.appendingPathComponent("paths-" + id)
            defer { try? FileManager.default.removeItem(at: pathspec) }
            try Data((paths + untracked).utf8).write(to: pathspec, options: .atomic)
            try repo.git(["--literal-pathspecs", "add", "--all", "--pathspec-file-nul",
                          "--pathspec-from-file=" + pathspec.path], at: directory)
        }
        do {
            try checkBudget()
            try beginPhase("Setup")
            try addWorktree(worktree)
            let refs = try repo.refs()
            let resolvedVerification: [String]
            if let configured = config.verification { resolvedVerification = configured }
            else if FileManager.default.fileExists(atPath: worktree.appendingPathComponent("Package.swift").path) { resolvedVerification = ["swift test"] }
            else { resolvedVerification = [] }
            guard skipChecks || config.verification != nil || !resolvedVerification.isEmpty else {
                record.terminal = true
                throw BSAError.message("No meaningful verification detected. Configure verification commands in bsa.json, or use --skip-checks or set verification to [] to skip them (Swift packages use swift test automatically).")
            }
            func assertGit(at directory: URL) throws {
                guard try repo.git(["rev-parse", "HEAD"], at: directory) == baseline,
                      try repo.git(["rev-parse", "--abbrev-ref", "HEAD"], at: directory) == "HEAD",
                      try repo.refs() == refs else {
                    record.terminal = true
                    throw BSAError.message("Harness or checks changed HEAD or repository refs")
                }
            }
            let verification = skipChecks ? [] : resolvedVerification
            let baselineCommands = skipChecks ? [] : (config.baseline ?? resolvedVerification)
            if baselineCommands.isEmpty { onProgress("Baseline skipped (empty command list)") }
            else {
                try beginPhase("Baseline")
                try checks(baselineCommands, at: worktree, baseline: true)
            }
            try assertGit(at: worktree)
            try stage(at: worktree)
            guard try repo.git(["diff", "--cached", "--name-only"], at: worktree).isEmpty else {
                throw BSAError.message("Baseline checks modified repository files")
            }
            try checkBudget()
            try beginPhase("Harness")
            let response: CommandResult
            do {
                response = try harness.run(prompt: Planner.prompt(instructions: config.instructions, recent: recent), cwd: worktree, timeout: remaining())
            } catch {
                record.outcome = Cancellation.shouldStop ? "cancelled" : "harness_failed"
                throw error
            }
            try beginPhase("Review")
            record.task = String(response.output.suffix(8192))
            try checkBudget()
            if response.timedOut { throw BSAError.message("timed_out") }
            guard response.status == 0 else { record.outcome = "harness_failed"; throw BSAError.message("Harness exited \(response.status): \(response.output.suffix(2000))") }
            try assertGit(at: worktree)
            try stage(at: worktree)
            record.paths = try repo.git(["diff", "--cached", "--no-renames", "--name-only", "-z"], at: worktree)
                .split(separator: "\0").map(String.init)
            if record.paths.isEmpty { record.outcome = "no_candidate" }
            else {
                try validate(paths: record.paths, repository: repo, worktree: worktree, limit: config.maxChangedFiles, protectedPaths: config.protectedPaths)
                let tree = try repo.git(["write-tree"], at: worktree)
                _ = try repo.git(["diff", "--cached", "--check"], at: worktree)
                try checkBudget()
                if verification.isEmpty { onProgress("Verification skipped (empty command list)") }
                else { try beginPhase("Verification") }
                let verificationTree = store.directory.appendingPathComponent("verify-" + id)
                try addWorktree(verificationTree)
                try repo.git(["read-tree", "--reset", "-u", tree], at: verificationTree)
                try checks(verification, at: verificationTree, baseline: false)
                try assertGit(at: verificationTree)
                guard record.checks.allSatisfy({ $0.status == 0 }) else {
                    record.outcome = "verification_failed"
                    throw BSAError.message("Required verification failed; no commit created")
                }
                try stage(at: verificationTree)
                guard try repo.git(["write-tree"], at: verificationTree) == tree else {
                    throw BSAError.message("Verification modified the proposed change")
                }
                try checkBudget()
                try beginPhase("Publication")
                try repo.requireUncheckedOut(target)
                let summary = response.output.split(separator: "\n").first.map { String($0.prefix(100)) } ?? "Improve repository"
                let commit = try repo.git(["commit-tree", tree, "-p", baseline, "-m", "bsa: " + summary], at: worktree, environment: try config.commitEnvironment())
                // Persist the candidate before publication so an interrupted record is auditable.
                record.commit = commit
                try store.save(record)
                try checkBudget()
                try repo.git(["update-ref", "--no-deref", target, commit, originalTarget ?? String(repeating: "0", count: baseline.count)])
                record.outcome = "committed"
                try store.own(branch: branch, commit: commit)
                if config.push {
                    try repo.git(["push", "--", "origin", target + ":" + target])
                }
            }
        } catch {
            if record.outcome == "running" {
                let reason = String(describing: error)
                record.outcome = ["cancelled", "timed_out"].contains(reason) ? reason : "rejected"
            }
            if record.outcome == "committed" { record.terminal = true }
            record.detail = String(describing: error)
        }
        // Cleanup must still run if persisting its phase fails.
        try? beginPhase("Cleanup")
        for directory in worktrees.reversed() {
            do {
                if ["cancelled", "timed_out"].contains(record.outcome) {
                    // Plain remove also protects ignored and untracked partial output.
                    try repo.git(["worktree", "remove", directory.path])
                } else {
                    try repo.git(["worktree", "remove", "--force", directory.path])
                }
            } catch {
                record.terminal = true
                record.detail = (record.detail.map { $0 + "\n" } ?? "") + "Cleanup failed; inspect \(directory.path): \(error)"
            }
        }
        finishPhase()
        record.phase = nil
        record.finished = Date()
        try store.save(record)
        return record
    }

    private func validate(paths: [String], repository: Repository, worktree: URL, limit: Int, protectedPaths: [String]) throws {
        guard paths.count <= limit else { throw BSAError.message("Change exceeds maxChangedFiles") }
        for path in paths {
            try ChangePolicy.validate(path: path, protectedPaths: protectedPaths)
        }
        let modes = try repository.git(["diff", "--cached", "--no-renames", "--raw"], at: worktree)
        for entry in modes.split(separator: "\n") {
            let fields = entry.split(separator: " ")
            guard fields.count >= 2,
                  ![":120000", ":160000"].contains(String(fields[0])),
                  !["120000", "160000"].contains(String(fields[1])) else {
                throw BSAError.message("Symlink or submodule changes require human review")
            }
        }
        let diff = try repository.git(["diff", "--cached", "--numstat"], at: worktree)
        guard !diff.split(separator: "\n").contains(where: { $0.hasPrefix("-\t-\t") }) else { throw BSAError.message("Binary changes require human review") }
        let patch = try repository.git(["diff", "--cached", "--no-ext-diff", "--no-textconv"], at: worktree)
        guard patch.utf8.count <= 100_000,
              !patch.contains("PRIVATE KEY-----"), !patch.contains("AKIA"), !patch.contains("ghp_"), !patch.contains("sk-proj-") else {
            throw BSAError.message("Diff exceeds safety limits or includes symlinks, submodules, or possible secrets")
        }
        // Removing tests/verification is deliberately conservative in the first stage.
        for line in patch.split(separator: "\n") where line.hasPrefix("-") && !line.hasPrefix("---") {
            if ["assert", "expect(", "test(", ".skip", "swift test"].contains(where: { line.lowercased().contains($0) }) {
                throw BSAError.message("Removal of verification requires human review")
            }
        }
    }
}
