import Foundation

public struct Repository {
    public let root: URL
    public let commonDirectory: URL
    let commands: CommandRunner

    public init(at directory: URL, commands: CommandRunner = CommandRunner()) throws {
        self.commands = commands
        func resolve(_ args: [String]) throws -> String {
            let result = try commands.run("/usr/bin/env", ["git"] + args, cwd: directory)
            guard result.status == 0 else { throw BSAError.message("Not a supported Git checkout: \(result.output)") }
            return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        root = URL(fileURLWithPath: try resolve(["rev-parse", "--show-toplevel"])).standardizedFileURL.resolvingSymlinksInPath()
        let common = try resolve(["rev-parse", "--git-common-dir"])
        commonDirectory = (common.hasPrefix("/") ? URL(fileURLWithPath: common) : directory.appendingPathComponent(common)).standardizedFileURL.resolvingSymlinksInPath()
        _ = try git(["rev-parse", "--verify", "HEAD^{commit}"])
    }

    @discardableResult
    public func git(_ args: [String], at cwd: URL? = nil) throws -> String {
        let result = try commands.run("/usr/bin/env", ["git", "-c", "core.hooksPath=/dev/null"] + args,
                                      cwd: cwd ?? root, environment: ["GIT_TERMINAL_PROMPT": "0"], cancellable: false)
        guard result.status == 0 else { throw BSAError.message("git \(args.first ?? ""): \(result.output)") }
        guard result.output.utf8.count < 1_048_576 else { throw BSAError.message("Git output exceeds the 1 MiB safety limit") }
        return result.output.trimmingCharacters(in: .newlines)
    }

    func ref(_ name: String) -> String? { try? git(["rev-parse", "--verify", name + "^{commit}"]) }
    func isAncestor(_ ancestor: String, _ descendant: String) -> Bool {
        (try? commands.run("/usr/bin/env", ["git", "merge-base", "--is-ancestor", ancestor, descendant], cwd: root).status) == 0
    }
    func refs() throws -> String { try git(["for-each-ref", "--format=%(refname) %(objectname)"]) }
}
