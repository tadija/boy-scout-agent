import Foundation

public final class Runner {
    private let commands = CommandRunner()
    public init() {}

    public func status(at directory: URL, dataDirectory: URL? = nil) throws -> Record? {
        try StateStore(repository: Repository(at: directory), dataDirectory: dataDirectory).latest
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
        if let previous = try store.latest, previous.outcome == "running" {
            throw BSAError.message("Interrupted session \(previous.id). Inspect \(store.directory.path) and its worktree before starting again; automatic recovery is deferred to stage 3.")
        }
        try harness.detect(in: repo.root)
        let base = try repo.git(["rev-parse", "--verify", (config.base ?? "HEAD") + "^{commit}"])
        let slug = repo.root.lastPathComponent.lowercased().map { $0.isASCII && ($0.isLetter || $0.isNumber) ? String($0) : "-" }.joined()
        let branch = config.branch ?? "bsa/\(slug)"
        _ = try repo.git(["check-ref-format", "--branch", branch])
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
        // Ref publication must not move the HEAD of any existing worktree.
        let worktrees = try repo.git(["worktree", "list", "--porcelain"])
        guard !worktrees.components(separatedBy: "\n").contains("branch " + target) else {
            throw BSAError.message("Target branch is checked out in a worktree; switch it away before running")
        }
        let id = UUID().uuidString.lowercased()
        let worktree = store.directory.appendingPathComponent("worktree-" + id)
        var record = Record(id: id, repository: repo.root.path, branch: branch, started: Date(), outcome: "running", baseline: baseline)
        let history = try store.latest
        try store.save(record)
        var added = false
        defer {
            if added { _ = try? repo.git(["worktree", "remove", "--force", worktree.path]) }
        }
        let deadline = Date().addingTimeInterval(config.timeoutSeconds)
        func remaining() -> TimeInterval { max(0.001, deadline.timeIntervalSinceNow) }
        func checkBudget() throws {
            if Cancellation.requested != 0 { throw BSAError.message("cancelled") }
            if Date() >= deadline { throw BSAError.message("timed_out") }
        }
        func checks(_ values: [String], baseline: Bool) throws {
            for command in values {
                try checkBudget()
                let output = try commands.run("/bin/sh", ["-c", command], cwd: worktree, timeout: remaining())
                let check = Check(command: command, status: output.status, output: output.output)
                if baseline { record.baselineChecks.append(check) }
                else { record.checks.append(check) }
                try store.save(record)
                try checkBudget()
                if output.timedOut { throw BSAError.message("timed_out") }
            }
        }
        func stage() throws {
            // Enumerate eligible files first: Git add treats explicit ignored exclusions
            // as errors on some Git versions. NUL pathspecs also preserve unusual names.
            let files = try repo.git(["ls-files", "--cached", "--others", "--exclude-standard", "-z",
                                      "--", ".", ":(exclude).build"], at: worktree)
            guard !files.isEmpty else { return }
            let pathspec = store.directory.appendingPathComponent("paths-" + id)
            defer { try? FileManager.default.removeItem(at: pathspec) }
            try Data(files.utf8).write(to: pathspec, options: .atomic)
            try repo.git(["--literal-pathspecs", "add", "--all", "--pathspec-file-nul",
                          "--pathspec-from-file=" + pathspec.path], at: worktree)
        }
        do {
            try checkBudget()
            try repo.git(["worktree", "add", "--detach", worktree.path, baseline])
            added = true
            let refs = try repo.refs()
            let verification: [String]
            if let configured = config.verification { verification = configured }
            else if FileManager.default.fileExists(atPath: worktree.appendingPathComponent("Package.swift").path) { verification = ["swift test"] }
            else { verification = [] }
            guard !verification.isEmpty else {
                throw BSAError.message("No meaningful verification detected. Configure verification commands in bsa.json (Swift packages use swift test automatically).")
            }
            try checks(verification, baseline: true)
            // Baseline checks must not modify source files or HEAD; Swift build products are excluded.
            guard try repo.git(["status", "--porcelain", "--", ".", ":(exclude).build"], at: worktree).isEmpty,
                  repo.ref("HEAD") != nil,
                  try repo.git(["rev-parse", "HEAD"], at: worktree) == baseline,
                  try repo.refs() == refs else { throw BSAError.message("Baseline checks mutated Git state") }
            let response: CommandResult
            do {
                response = try harness.run(prompt: Planner.prompt(history: history.map {
                    "Outcome: \($0.outcome). Task: \($0.task ?? "none"). Detail: \($0.detail ?? "none")"
                } ?? "No previous outcome"), cwd: worktree, timeout: remaining())
            } catch {
                record.outcome = Cancellation.requested != 0 ? "cancelled" : "harness_failed"
                throw error
            }
            record.task = String(response.output.suffix(8192))
            try checkBudget()
            if response.timedOut { throw BSAError.message("timed_out") }
            guard response.status == 0 else { record.outcome = "harness_failed"; throw BSAError.message("Harness exited \(response.status): \(response.output.suffix(2000))") }
            func assertGit() throws {
                guard try repo.git(["rev-parse", "HEAD"], at: worktree) == baseline,
                      try repo.git(["rev-parse", "--abbrev-ref", "HEAD"], at: worktree) == "HEAD",
                      try repo.refs() == refs else { throw BSAError.message("Harness or checks changed HEAD or repository refs") }
            }
            try assertGit()
            try stage()
            func paths() throws -> [String] {
                try repo.git(["diff", "--cached", "--no-renames", "--name-only", "-z"], at: worktree).split(separator: "\0").map(String.init)
            }
            record.paths = try paths()
            if record.paths.isEmpty { record.outcome = "no_candidate" }
            else {
                try validate(paths: record.paths, repository: repo, worktree: worktree, limit: config.maxChangedFiles)
                let tree = try repo.git(["write-tree"], at: worktree)
                try checks(verification, baseline: false)
                try assertGit()
                guard record.checks.allSatisfy({ $0.status == 0 }) else {
                    record.outcome = "verification_failed"
                    throw BSAError.message("Required verification failed; no commit created")
                }
                try stage()
                guard try repo.git(["write-tree"], at: worktree) == tree else { throw BSAError.message("Verification modified the proposed change") }
                _ = try repo.git(["diff", "--cached", "--check"], at: worktree)
                try checkBudget()
                let currentWorktrees = try repo.git(["worktree", "list", "--porcelain"])
                guard !currentWorktrees.components(separatedBy: "\n").contains("branch " + target) else {
                    throw BSAError.message("Target branch was checked out during the iteration")
                }
                let summary = response.output.split(separator: "\n").first.map { String($0.prefix(100)) } ?? "Improve repository"
                let commit = try repo.git(["commit-tree", tree, "-p", baseline, "-m", "bsa: " + summary], at: worktree)
                // Persist the candidate before publication so an interrupted record is auditable.
                record.commit = commit
                try store.save(record)
                try repo.git(["update-ref", target, commit, originalTarget ?? String(repeating: "0", count: baseline.count)])
                record.outcome = "committed"
                try store.own(branch: branch, commit: commit)
            }
        } catch {
            if record.outcome == "running" {
                let reason = String(describing: error)
                record.outcome = ["cancelled", "timed_out"].contains(reason) ? reason : "rejected"
            }
            record.detail = String(describing: error)
        }
        if added {
            do {
                try repo.git(["worktree", "remove", "--force", worktree.path])
                added = false
            } catch {
                record.detail = (record.detail.map { $0 + "\n" } ?? "") + "Cleanup failed; inspect \(worktree.path): \(error)"
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
