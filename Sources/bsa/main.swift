import Foundation
import BSACore
#if os(Linux)
import Glibc
#else
import Darwin
#endif

let version = "0.1.1"

let help = """
Boy Scout Agent — one run, one improvement, one commit.

Usage: bsa <command> [options]

Commands:
  init             Create bsa.json with all built-in defaults in the current directory
  update           Download main from GitHub, build, and replace this executable
  run              Run isolated improvement iterations
  config           Print effective configuration (global + repository settings)
  status           Show the latest session and active phase
  history          List recorded iterations for this repository
  stop             Request cancellation of the active session
  doctor           Check the repository, harness, and verification configuration
  harnesses        List built-in harness availability
  schedule         Manage generated daily schedule files

Run options:
  --count N                         Maximum iterations (default: 1)
  --duration DURATION | --until HH:MM
                                    Execution window, e.g. 4h; or local stop time
  --harness NAME                    codex, claude, pi, opencode, or custom
  --branch NAME --base REV           Target branch and starting revision
  --force                           Adopt an existing target branch from its tip
  --identity VALUE                  \"Name <email>\" or git for configured Git identity
  --instructions TEXT               Override configured project guidance
  --skip-checks                     Skip both baseline and verification commands
  --yolo                            Enable the built-in harness's permissive mode

Schedule subcommands:
  add --at HH:MM --duration DURATION
                                    Generate a daily schedule (host local time)
  list                              List generated schedules
  remove ID                         Remove schedule files; unload native timers first

Options override configuration. Built-in commit identity: Boy Scout Agent <boy-scout-agent@localhost>.
Runs use Codex, Claude Code, Pi, or OpenCode in discovery order unless configured.
Swift packages use swift test automatically; other projects need verification commands
in bsa.json (or explicit [] to skip them). Push requires explicit configuration.

Help and version:
  bsa --help, bsa -h, bsa help        Show this help
  bsa <command> --help               Show this help
  bsa --version                     Show version

State: $XDG_DATA_HOME/bsa (default ~/.local/share/bsa).
"""

Cancellation.install()
do {
    let args = Array(CommandLine.arguments.dropFirst())
    let commands = ["update", "init", "run", "config", "status", "history", "stop", "doctor", "harnesses", "schedule"]
    let commandHelp = args.last == "--help" && (
        (args.count == 2 && commands.contains(args[0])) ||
        (args.count == 3 && args[0] == "schedule" && ["add", "list", "remove"].contains(args[1]))
    )
    if args.isEmpty || args == ["--help"] || args == ["-h"] || args == ["help"] || commandHelp {
        print(help)
    } else if args == ["--version"] {
        print("Boy Scout Agent \(version)")
    } else {
        let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let runner = Runner()
        switch args[0] {
        case "update":
            guard args.count == 1 else { throw BSAError.message("update takes no options") }
            guard let executable = Bundle.main.executableURL else {
                throw BSAError.message("Cannot resolve BSA executable path")
            }
            try Updater().update(executable: executable) { print($0) }
        case "init":
            guard args.count == 1 else { throw BSAError.message("init takes no options") }
            let destination = directory.appendingPathComponent("bsa.json")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            var data = try encoder.encode(Configuration())
            data.append(0x0A)
            try data.write(to: destination, options: .withoutOverwriting)
            print("Created \(destination.path)")
        case "run":
            var configuration = try Configuration.load(repository: Repository(at: directory))
            var yolo = false
            var force = false
            var skipChecks = false
            var deadline: Date?
            var index = 1
            while index < args.count {
                if args[index] == "--skip-checks" {
                    skipChecks = true
                    index += 1
                    continue
                }
                if args[index] == "--yolo" {
                    yolo = true
                    index += 1
                    continue
                }
                if args[index] == "--force" {
                    force = true
                    index += 1
                    continue
                }
                guard ["--instructions", "--identity", "--branch", "--base", "--count", "--harness", "--duration", "--until"].contains(args[index]), index + 1 < args.count else {
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
                else if args[index] == "--instructions" { configuration.instructions = args[index + 1] }
                else if args[index] == "--identity" { configuration.commitIdentity = args[index + 1] }
                else if args[index] == "--harness" { configuration.harness = args[index + 1] }
                else {
                    guard let count = Int(args[index + 1]), count > 0 else { throw BSAError.message("--count requires a positive integer") }
                    configuration.maxIterations = count
                }
                index += 2
            }
            let harness = try Harnesses.select(configuration: configuration, directory: directory, yolo: yolo)
            if yolo { print("YOLO mode enabled for \(harness.name).") }
            print("Harness: \(harness.name). Up to \(configuration.maxIterations) isolated iterations…")
            let records = try runner.runSession(at: directory, configuration: configuration, harness: harness, deadline: deadline, force: force, skipChecks: skipChecks, onProgress: { message in
                FileHandle.standardError.write(Data((message + "\n").utf8))
            }) { record in
                print("\(record.outcome) on \(record.branch)\(record.commit.map { " (\($0))" } ?? "")")
                if let finished = record.finished {
                    let phases = ["Setup", "Baseline", "Harness", "Review", "Verification", "Publication", "Cleanup"]
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
            guard args.count == 1 else { throw BSAError.message("config takes no options") }
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
            func describe(_ commands: [String]?) -> String? {
                commands.map { $0.isEmpty ? "skipped" : $0.joined(separator: "; ") }
            }
            print("Git repository OK. Harness: \(harness.name). Baseline: \(describe(configuration.baseline) ?? "same as verification"). Verification: \(describe(configuration.verification) ?? "automatic Swift detection; otherwise configure verification")")
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
