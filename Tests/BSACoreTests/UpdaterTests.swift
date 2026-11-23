import XCTest
@testable import BSACore

final class UpdaterTests: XCTestCase {
    func testUpdateReplacesResolvedExecutableAndKeepsSymlink() throws {
        try withFixture { directory, executable, build in
            let link = directory.appendingPathComponent("bsa-link")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: executable)
            var calls: [[String]] = []
            var source: URL?
            try Updater().update(executable: link, onProgress: { _ in }) { arguments, cwd in
                calls.append(arguments)
                if arguments.first == "git" { source = cwd }
                let output = arguments.last == "--show-bin-path" ? build.path :
                    arguments.last == "--version" ? "Boy Scout Agent test" : ""
                return CommandResult(status: 0, output: output, timedOut: false)
            }
            XCTAssertEqual(try String(contentsOf: executable, encoding: .utf8), "new binary")
            XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: link.path), executable.path)
            XCTAssertEqual(calls.count, 4)
            XCTAssertTrue(calls[0].contains("https://github.com/tadija/boy-scout-agent.git"))
            XCTAssertEqual(calls[1], ["swift", "build", "-c", "release"])
            XCTAssertFalse(FileManager.default.fileExists(atPath: try XCTUnwrap(source).path))
            XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.hasPrefix(".bsa-update-") })
        }
    }

    func testBuildAndValidationFailuresPreserveInstalledExecutable() throws {
        for failure in ["build", "version"] {
            try withFixture { directory, executable, build in
                XCTAssertThrowsError(try Updater().update(executable: executable, onProgress: { _ in }) { args, _ in
                    if failure == "build", args == ["swift", "build", "-c", "release"] {
                        return CommandResult(status: 1, output: "compiler failed", timedOut: false)
                    }
                    return CommandResult(status: 0, output: args.last == "--show-bin-path" ? build.path : "invalid version", timedOut: false)
                })
                XCTAssertEqual(try String(contentsOf: executable, encoding: .utf8), "old binary")
                XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.hasPrefix(".bsa-update-") })
            }
        }
    }

    private func withFixture(_ body: (URL, URL, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("bsa update tests " + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appendingPathComponent("bsa")
        let build = directory.appendingPathComponent("build")
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        try Data("old binary".utf8).write(to: executable)
        try Data("new binary".utf8).write(to: build.appendingPathComponent("bsa"))
        try body(directory, executable, build)
    }
}
