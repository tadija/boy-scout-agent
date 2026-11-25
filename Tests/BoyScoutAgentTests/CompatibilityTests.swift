import XCTest
import SwiftAgent
@testable import bsa

final class CompatibilityTests: RepositoryTestCase {
    func testExistingConfigurationAndHistoryRemainUsable() throws {
        let repo = try Repository(at: checkout)
        let config = try Configuration.load(repository: repo, agent: .boyScout)
        XCTAssertEqual(config.verification, ["test -s value.txt"])
        XCTAssertEqual(config.commitIdentity, "Boy Scout Agent <boy-scout-agent@localhost>")
        // Pre-extraction record shape, without newer optional session/phase fields.
        let legacy: [String: Any] = [
            "id": "legacy", "repository": checkout.path, "branch": "bsa/project",
            "started": 100.0, "finished": 101.0, "outcome": "no_candidate",
            "task": "Previous attempt", "paths": [], "baselineChecks": [], "checks": []
        ]
        let identity = repo.commonDirectory.path.utf8.map { String(format: "%02x", $0) }.joined()
        let directory = stride(from: 0, to: identity.count, by: 100).reduce(data.appendingPathComponent("repositories")) {
            $0.appendingPathComponent(String(identity.dropFirst($1).prefix(100)))
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bytes = try JSONSerialization.data(withJSONObject: legacy)
        try bytes.write(to: directory.appendingPathComponent("legacy.json"))
        try bytes.write(to: directory.appendingPathComponent("latest.json"))
        let runner = Runner(agent: .boyScout)
        XCTAssertEqual(try runner.status(at: checkout, dataDirectory: data)?.task, "Previous attempt")
        XCTAssertEqual(try runner.history(at: checkout, dataDirectory: data).map(\.id), ["legacy"])
        XCTAssertTrue(try runner.prompt(at: checkout, dataDirectory: data).contains("Previous attempt"))
        let first = try run { cwd in
            try self.write("value.txt", "after\n", at: cwd)
            return self.success()
        }
        XCTAssertEqual(first.outcome, "committed", first.detail ?? "")
        XCTAssertEqual(first.branch, "bsa/project")
        XCTAssertEqual(try git(["show", "-s", "--format=%an <%ae>|%s", first.branch]),
                       "Boy Scout Agent <boy-scout-agent@localhost>|bsa: Correct the value fixture")
        XCTAssertEqual(try run { _ in self.success() }.outcome, "no_candidate")
        XCTAssertEqual(try runner.history(at: checkout, dataDirectory: data).count, 3)
        XCTAssertEqual(try git(["status", "--porcelain"]), "")
    }

    func testScheduleNamesAndWrapperRemainCompatible() throws {
        let scheduler = try Scheduler(dataDirectory: data, agent: .boyScout)
        let schedule = try scheduler.add(repository: checkout, executable: "/usr/local/bin/bsa", at: "00:00", duration: "4h")
        let script = try String(contentsOf: scheduler.directory.appendingPathComponent(schedule.id + ".sh"), encoding: .utf8)
        XCTAssertTrue(script.contains("exec '/usr/local/bin/bsa' run --duration '4h'"))
        #if os(macOS)
        let bytes = try Data(contentsOf: scheduler.directory.appendingPathComponent(schedule.id + ".plist"))
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: bytes, format: nil) as? [String: Any])
        XCTAssertEqual(plist["Label"] as? String, "local.bsa." + schedule.id)
        #else
        XCTAssertTrue(FileManager.default.fileExists(atPath: scheduler.directory.appendingPathComponent("bsa-" + schedule.id + ".service").path))
        #endif
        try scheduler.remove(schedule.id)
        XCTAssertTrue(try scheduler.list().isEmpty)
    }
}
