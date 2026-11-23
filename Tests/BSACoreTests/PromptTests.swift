import XCTest
@testable import BSACore

final class PromptTests: RepositoryTestCase {
    func testPreviewMatchesHarnessPromptAndUsesTargetBranchHistory() throws {
        let runner = Runner()
        var configuration = Configuration()
        configuration.branch = "bsa/preview"
        configuration.instructions = "Preserve {cwd}, {prompt}, and literal project guidance."
        configuration.verification = ["test -s value.txt"]
        let initial = try runner.prompt(at: checkout, configuration: configuration, dataDirectory: data)
        XCTAssertTrue(initial.contains(configuration.instructions))
        let first = try runner.run(at: checkout, configuration: configuration, harness: FakeHarnessPromptAdapter { prompt, directory in
            XCTAssertEqual(prompt, initial)
            try self.write("value.txt", "after\n", at: directory)
            return CommandResult(status: 0, output: "Correct preview fixture", timedOut: false)
        }, dataDirectory: data)
        XCTAssertEqual(first.outcome, "committed")
        let next = try runner.prompt(at: checkout, configuration: configuration, dataDirectory: data)
        XCTAssertTrue(next.contains("Outcome: committed. Task: Correct preview fixture"))
        let second = try runner.run(at: checkout, configuration: configuration, harness: FakeHarnessPromptAdapter { prompt, _ in
            XCTAssertEqual(prompt, next)
            return CommandResult(status: 0, output: "No candidate", timedOut: false)
        }, dataDirectory: data)
        XCTAssertEqual(second.outcome, "no_candidate")
        configuration.branch = "bsa/unrelated"
        let unrelated = try runner.prompt(at: checkout, configuration: configuration, dataDirectory: data)
        XCTAssertFalse(unrelated.contains("Correct preview fixture"))
    }
}

private struct FakeHarnessPromptAdapter: HarnessAdapter {
    let name = "prompt-fixture"
    var action: (String, URL) throws -> CommandResult
    func detect(in directory: URL) throws {}
    func run(prompt: String, cwd: URL, timeout: TimeInterval) throws -> CommandResult {
        try action(prompt, cwd)
    }
}
