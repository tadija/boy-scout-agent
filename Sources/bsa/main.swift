import Foundation
import BSACore
#if os(Linux)
import Glibc
#else
import Darwin
#endif

let help = """
Boy Scout Agent — one run, one improvement, one commit.

Usage: bsa run [--branch NAME] [--base REV]
       bsa status
       bsa --help

Stage 1 runs one Codex iteration. Swift packages use swift test automatically;
other projects need verification commands in bsa.json. No automatic pushes.
State: $XDG_DATA_HOME/bsa (default ~/.local/share/bsa).
"""

Cancellation.install()
do {
    let args = Array(CommandLine.arguments.dropFirst())
    if args.isEmpty || args == ["--help"] || args == ["-h"] || args == ["help"] || args == ["run", "--help"] || args == ["status", "--help"] {
        print(help)
    } else {
        let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let runner = Runner()
        switch args[0] {
        case "run":
            var configuration = try Configuration.load(repository: Repository(at: directory))
            var index = 1
            while index < args.count {
                guard ["--branch", "--base"].contains(args[index]), index + 1 < args.count else {
                    throw BSAError.message("Unknown or incomplete option: \(args[index]). See bsa --help.")
                }
                if args[index] == "--branch" { configuration.branch = args[index + 1] }
                else { configuration.base = args[index + 1] }
                index += 2
            }
            print("Harness: codex. Running one isolated iteration…")
            let record = try runner.run(at: directory, configuration: configuration)
            print("\(record.outcome) on \(record.branch)\(record.commit.map { " (\($0))" } ?? "")")
            if let detail = record.detail { print(detail) }
            if !["committed", "no_candidate"].contains(record.outcome) { exit(record.outcome == "cancelled" ? 130 : 1) }
        case "status":
            guard args.count == 1 else { throw BSAError.message("status takes no options") }
            if let record = try runner.status(at: directory) {
                print("Session: \(record.id)\nBranch: \(record.branch)\nOutcome: \(record.outcome)")
                if let commit = record.commit { print("Commit candidate: \(commit)") }
                if let detail = record.detail { print(detail) }
            } else { print("No BSA sessions recorded for this repository.") }
        default: throw BSAError.message("Unknown command: \(args[0]). See bsa --help.")
        }
    }
} catch {
    FileHandle.standardError.write(Data("bsa: \(error)\n".utf8))
    exit(1)
}
