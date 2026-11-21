import Foundation
import BSACore
#if os(Linux)
import Glibc
#else
import Darwin
#endif

let help = """
Boy Scout Agent — one run, one improvement, one commit.

Usage: bsa run [--duration 4h | --until HH:MM] [--count N] [--harness NAME] [--branch NAME] [--base REV]
       bsa history
       bsa status
       bsa --help

Runs fresh isolated iterations with Codex, Claude Code, Pi or OpenCode. Swift packages use swift test automatically;
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
            var deadline: Date?
            var index = 1
            while index < args.count {
                guard ["--branch", "--base", "--count", "--harness", "--duration", "--until"].contains(args[index]), index + 1 < args.count else {
                    throw BSAError.message("Unknown or incomplete option: \(args[index]). See bsa --help.")
                }
                if args[index] == "--duration" { deadline = Date().addingTimeInterval(try ExecutionWindow.duration(args[index + 1])) }
                else if args[index] == "--until" { deadline = try ExecutionWindow.until(args[index + 1]) }
                else if args[index] == "--branch" { configuration.branch = args[index + 1] }
                else if args[index] == "--base" { configuration.base = args[index + 1] }
                else if args[index] == "--harness" { configuration.harness = args[index + 1] }
                else {
                    guard let count = Int(args[index + 1]), count > 0 else { throw BSAError.message("--count requires a positive integer") }
                    configuration.maxIterations = count
                }
                index += 2
            }
            let harness = try Harnesses.select(configuration: configuration, directory: directory)
            print("Harness: \(harness.name). Up to \(configuration.maxIterations) isolated iterations…")
            let records = try runner.runSession(at: directory, configuration: configuration, harness: harness, deadline: deadline) { record in
                print("\(record.outcome) on \(record.branch)\(record.commit.map { " (\($0))" } ?? "")")
                if let detail = record.detail { print(detail) }
            }
            guard Cancellation.requested == 0, let record = records.last else { exit(130) }
            if records.count < configuration.maxIterations && record.terminal != true {
                switch record.outcome {
                case "no_candidate":
                    print("Stopped after \(configuration.saturationLimit) consecutive attempts without a candidate.")
                case "harness_failed", "verification_failed", "rejected":
                    print("Stopped after \(configuration.failureLimit) consecutive failures.")
                default:
                    break
                }
            }
            if record.terminal == true { exit(1) }
            if !["committed", "no_candidate"].contains(record.outcome) { exit(record.outcome == "cancelled" ? 130 : 1) }
        case "history":
            guard args.count == 1 else { throw BSAError.message("history takes no options") }
            for record in try runner.history(at: directory) {
                print("\(record.started) \(record.outcome) \(record.branch) \(record.commit ?? "") [\(record.id)]")
            }
        case "status":
            guard args.count == 1 else { throw BSAError.message("status takes no options") }
            if let record = try runner.status(at: directory) {
                print("Session: \(record.sessionID ?? record.id)\nBranch: \(record.branch)\nOutcome: \(record.outcome)")
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
