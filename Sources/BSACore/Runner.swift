import Foundation

public final class Runner {
    private let commands = CommandRunner()
    public init() {}

    public func status(at directory: URL, dataDirectory: URL? = nil) throws -> Record? {
        try StateStore(repository: Repository(at: directory), dataDirectory: dataDirectory).latest
    }

    public func runSession(at directory: URL, configuration: Configuration, harness: any HarnessAdapter,
                           dataDirectory: URL? = nil, onIteration: (Record) -> Void = { _ in }) throws -> [Record] {
        try configuration.validate()
        let repo = try Repository(at: directory)
        let sessionLock = try RepositoryLock(at: repo.commonDirectory.appendingPathComponent("bsa.lock"))
        defer { sessionLock.release() }
        let store = try StateStore(repository: repo, dataDirectory: dataDirectory)
        try harness.detect(in: repo.root)
        let sessionID = UUID().uuidString.lowercased()
        var records: [Record] = []
        var failures = 0
        var empty = 0
        for _ in 0..<configuration.maxIterations {
            if Cancellation.requested != 0 { break }
            let record = try iteration(repo: repo, config: configuration, harness: harness, store: store, sessionID: sessionID)
            records.append(record)
            onIteration(record)
            failures = ["committed", "no_candidate"].contains(record.outcome) ? 0 : failures + 1
            empty = record.outcome == "no_candidate" ? empty + 1 : 0
            if record.terminal == true || failures >= configuration.failureLimit || empty >= configuration.saturationLimit || ["cancelled", "timed_out"].contains(record.outcome) { break }
        }
        return records
    }

    public func run(at directory: URL, configuration: Configuration? = nil,
                    harness: HarnessAdapter = CodexAdapter(), dataDirectory: URL? = nil) throws -> Record {
        let repo = try Repository(at: directory)
        let config = try configuration ?? Configuration.load(repository: repo)
        try config.validate()
        let store = try StateStore(repository: repo, dataDirectory: dataDirectory)
        // The lock lives in Git's common directory so different data roots cannot bypass it.
        let lock = try RepositoryLock(at: repo.commonDirectory.appendingPathComponent("bsa.lock"))
        defer { lock.release() }
        try harness.detect(in: repo.root)
        return try iteration(repo: repo, config: config, harness: harness, store: store, sessionID: UUID().uuidString.lowercased())
    }

    private func iteration(repo: Repository, config: Configuration, harness: any HarnessAdapter,
                           store: StateStore, sessionID: String) throws -> Record {
        let history = try store.latest
        if let previous = history, previous.outcome == "running" {
            throw BSAError.message("Interrupted session \(previous.id). Inspect \(store.directory.path) and its worktree before starting again; automatic recovery is deferred to stage 3.")
        }
        let base = try repo.git(["rev-parse", "--verify", "--end-of-options", (config.base ?? "HEAD") + "^{commit}"])
        let slug = repo.root.lastPathComponent.lowercased().map { $0.isASCII && ($0.isLetter || $0.isNumber) ? String($0) : "-" }.joined()
        let branch = config.branch ?? "bsa/\(slug)"
        _ = try repo.git(["check-ref-format", "--branch", branch])
        let recent = try store.recent(branch: branch)
        let target = "refs/heads/" + branch
        guard try repo.git(["rev-parse", "--symbolic-full-name", "HEAD"]) != target else {
            throw BSAError.message("Run from your development branch, not the BSA target branch")
        }
        let originalTarget = repo.ref(target)
        if let originalTarget {
            guard try store.ownedBranches()[branch] == originalTarget else {
                throw BSAError.message("Target branch is not owned by BSA or was changed externally. Choose a new --branch; existing branches are never adopted or overwritten.")
            }
        }
        let baseline = originalTarget ?? base
        if let originalTarget, !repo.isAncestor(base, originalTarget) {
            throw BSAError.message("BSA branch diverged from the configured base. Resolve it manually; BSA never rewrites history.")
        }
        try repo.requireUncheckedOut(target)
        let id = UUID().uuidString.lowercased()
        let worktree = store.directory.appendingPathComponent("worktree-" + id)
        var record = Record(id: id, repository: repo.root.path, branch: branch, started: Date(), outcome: "running", baseline: baseline)
        record.sessionID = sessionID
        record.harness = harness.name
        try store.save(record)
        var worktrees: [URL] = []
        let deadline = ProcessInfo.processInfo.systemUptime + config.timeoutSeconds
        func remaining() -> TimeInterval { max(0.001, deadline - ProcessInfo.processInfo.systemUptime) }
        func checkBudget() throws {
            if Cancellation.requested != 0 { throw BSAError.message("cancelled") }
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
            try addWorktree(worktree)
            let refs = try repo.refs()
            let verification: [String]
            if let configured = config.verification { verification = configured }
            else if FileManager.default.fileExists(atPath: worktree.appendingPathComponent("Package.swift").path) { verification = ["swift test"] }
            else { verification = [] }
            guard !verification.isEmpty else {
                record.terminal = true
                throw BSAError.message("No meaningful verification detected. Configure verification commands in bsa.json (Swift packages use swift test automatically).")
            }
            func assertGit(at directory: URL) throws {
                guard try repo.git(["rev-parse", "HEAD"], at: directory) == baseline,
                      try repo.git(["rev-parse", "--abbrev-ref", "HEAD"], at: directory) == "HEAD",
                      try repo.refs() == refs else {
                    record.terminal = true
                    throw BSAError.message("Harness or checks changed HEAD or repository refs")
                }
            }
            try checks(verification, at: worktree, baseline: true)
            try assertGit(at: worktree)
            try stage(at: worktree)
            guard try repo.git(["diff", "--cached", "--name-only"], at: worktree).isEmpty else {
                throw BSAError.message("Baseline checks modified repository files")
            }
            try checkBudget()
            let response: CommandResult
            do {
                response = try harness.run(prompt: Planner.prompt(history: config.instructions + "\nExplore neglected areas; avoid repeating unchanged failed tasks. Recent paths: " + recent.flatMap(\.paths).prefix(30).joined(separator: ", ") + "\n" + recent.map {
                    "Outcome: \($0.outcome). Task: \(($0.task ?? "none").prefix(400)). Detail: \(($0.detail ?? "none").prefix(200))"
                }.joined(separator: "\n")), cwd: worktree, timeout: remaining())
            } catch {
                record.outcome = Cancellation.requested != 0 ? "cancelled" : "harness_failed"
                throw error
            }
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
                try validate(paths: record.paths, repository: repo, worktree: worktree, limit: config.maxChangedFiles)
                let tree = try repo.git(["write-tree"], at: worktree)
                _ = try repo.git(["diff", "--cached", "--check"], at: worktree)
                try checkBudget()
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
                try repo.requireUncheckedOut(target)
                let summary = response.output.split(separator: "\n").first.map { String($0.prefix(100)) } ?? "Improve repository"
                let commit = try repo.git(["commit-tree", tree, "-p", baseline, "-m", "bsa: " + summary], at: worktree)
                // Persist the candidate before publication so an interrupted record is auditable.
                record.commit = commit
                try store.save(record)
                try checkBudget()
                try repo.git(["update-ref", "--no-deref", target, commit, originalTarget ?? String(repeating: "0", count: baseline.count)])
                record.outcome = "committed"
                try store.own(branch: branch, commit: commit)
            }
        } catch {
            if record.outcome == "running" {
                let reason = String(describing: error)
                record.outcome = ["cancelled", "timed_out"].contains(reason) ? reason : "rejected"
            }
            if record.outcome == "committed" { record.terminal = true }
            record.detail = String(describing: error)
        }
        for directory in worktrees.reversed() {
            do {
                try repo.git(["worktree", "remove", "--force", directory.path])
            } catch {
                record.terminal = true
                record.detail = (record.detail.map { $0 + "\n" } ?? "") + "Cleanup failed; inspect \(directory.path): \(error)"
            }
        }
        record.finished = Date()
        try store.save(record)
        return record
    }

    private func validate(paths: [String], repository: Repository, worktree: URL, limit: Int) throws {
        guard paths.count <= limit else { throw BSAError.message("Change exceeds maxChangedFiles") }
        let blocked = [".env", ".git", ".github", "bsa.json", "secrets", "credentials", "package.resolved", "package-lock.json", "yarn.lock", "package.swift", "makefile", "agents.md", "claude.md"]
        for path in paths {
            let parts = path.lowercased().split(separator: "/").map(String.init)
            guard !parts.contains(where: { part in blocked.contains(part) || part.hasPrefix(".env.") || part.hasSuffix(".pem") || part.hasSuffix(".key") || [".build", "node_modules", "dist", "build"].contains(part) }) else {
                throw BSAError.message("Protected or generated path: \(path)")
            }
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
