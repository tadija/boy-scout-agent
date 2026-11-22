import Foundation
import BSACore
#if os(Linux)
import Glibc
#else
import Darwin
#endif

let version = "0.1.0"

let help = """
Boy Scout Agent — one run, one improvement, one commit.

Usage: bsa run [--duration 4h | --until HH:MM] [--count N] [--harness NAME] [--branch NAME] [--base REV]
       bsa schedule add --at HH:MM --duration 4h | list | remove ID
       bsa stop | history | doctor | harnesses | config show
       bsa status
       bsa --help
       bsa --version

Runs fresh isolated iterations with Codex, Claude Code, Pi or OpenCode. Swift packages use swift test automatically;
other projects need verification commands in bsa.json. Push requires explicit configuration.
State: $XDG_DATA_HOME/bsa (default ~/.local/share/bsa).
"""

Cancellation.install()
do {
    let args = Array(CommandLine.arguments.dropFirst())
    if args.isEmpty || args == ["--help"] || args == ["-h"] || args == ["help"] || args == ["run", "--help"] || args == ["status", "--help"] {
        print(help)
    } else if args == ["--version"] {
        print("Boy Scout Agent \(version)")
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
                if args[index] == "--duration" {
                    guard deadline == nil else { throw BSAError.message("Specify only one execution window") }
                    deadline = Date().addingTimeInterval(try ExecutionWindow.duration(args[index + 1])) }
                else if args[index] == "--until" {
                    guard deadline == nil else { throw BSAError.message("Specify only one execution window") }
                    deadline = try ExecutionWindow.until(args[index + 1]) }
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
            let records = try runner.runSession(at: directory, configuration: configuration, harness: harness, deadline: deadline, onProgress: { message in
                FileHandle.standardError.write(Data((message + "\n").utf8))
            }) { record in
                print("\(record.outcome) on \(record.branch)\(record.commit.map { " (\($0))" } ?? "")")
                if let finished = record.finished {
                    let phases = ["Setup", "Baseline checks", "Harness", "Review", "Verification", "Publication", "Cleanup"]
                    let timings = phases.compactMap { phase in
                        record.phaseSeconds?[phase].map { "\(phase): \(String(format: "%.1fs", $0))" }
                    }
                    print("Time: \(String(format: "%.1fs", finished.timeIntervalSince(record.started))) (\(timings.joined(separator: ", ")))")
                }
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
            if record.outcome == "cancelled" { exit(130) }
            if record.terminal == true { exit(1) }
            if !["committed", "no_candidate"].contains(record.outcome) { exit(1) }
        case "schedule":
            let scheduler = try Scheduler()
            if args == ["schedule", "list"] {
                for schedule in try scheduler.list() { print("\(schedule.id) daily \(schedule.at) for \(schedule.duration) [host local time; created in \(schedule.timezone)] \(schedule.repository)") }
            } else if args.count == 3 && args[1] == "remove" {
                try scheduler.remove(args[2])
                print("Removed schedule files. Unload any installed native timer first; see README.")
            } else if args.count == 6 && args[1] == "add" && args[2] == "--at" && args[4] == "--duration" {
                guard let executable = Bundle.main.executableURL?.path else { throw BSAError.message("Cannot resolve BSA executable path") }
                let schedule = try scheduler.add(repository: directory, executable: executable, at: args[3], duration: args[5])
                print("Created \(schedule.id) in \(scheduler.directory.path). Install its native scheduler file or invoke its .sh manually; see README.")
            } else { throw BSAError.message("Use schedule add --at HH:MM --duration 4h, schedule list, or schedule remove ID") }
        case "stop":
            guard args.count == 1 else { throw BSAError.message("stop takes no options") }
            try runner.stop(at: directory)
            print("Cancellation requested.")
        case "config":
            guard args == ["config", "show"] else { throw BSAError.message("Use config show") }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(decoding: try encoder.encode(Configuration.load(repository: Repository(at: directory))), as: UTF8.self))
        case "harnesses":
            guard args.count == 1 else { throw BSAError.message("harnesses takes no options") }
            for adapter in Harnesses.builtins {
                do {
                    try adapter.detect(in: directory)
                    print("\(adapter.name): available")
                } catch { print("\(adapter.name): unavailable (\(error))") }
            }
        case "doctor":
            guard args.count == 1 else { throw BSAError.message("doctor takes no options") }
            let configuration = try Configuration.load(repository: Repository(at: directory))
            let harness = try Harnesses.select(configuration: configuration, directory: directory)
            try harness.detect(in: directory)
            print("Git repository OK. Harness: \(harness.name). Verification: \(configuration.verification?.joined(separator: "; ") ?? "automatic Swift detection; otherwise configure verification")")
        case "history":
            guard args.count == 1 else { throw BSAError.message("history takes no options") }
            for record in try runner.history(at: directory) {
                print("\(record.started) \(record.outcome) \(record.branch) \(record.commit ?? "") [\(record.id)]")
            }
        case "status":
            guard args.count == 1 else { throw BSAError.message("status takes no options") }
            if let record = try runner.status(at: directory) {
                print("Session: \(record.sessionID ?? record.id)\nBranch: \(record.branch)\nOutcome: \(record.outcome)")
                if let phase = record.phase { print("Phase: \(phase)") }
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
