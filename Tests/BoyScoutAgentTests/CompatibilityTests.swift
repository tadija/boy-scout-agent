import XCTest
import SwiftAgent
@testable import bsa

final class CompatibilityTests: RepositoryTestCase {
    func testBSAConfigurationAndCommitIdentity() throws {
        let repo = try Repository(at: checkout)
        let config = try Configuration.load(repository: repo, agent: .boyScout)
        XCTAssertEqual(config.commitIdentity, "Boy Scout Agent <boy-scout-agent@localhost>")
        let first = try run { cwd in
            try self.write("value.txt", "after\n", at: cwd)
            return self.success()
        }
        XCTAssertEqual(first.outcome, "committed", first.detail ?? "")
        XCTAssertEqual(first.branch, "bsa/project")
        XCTAssertEqual(try git(["show", "-s", "--format=%an <%ae>|%s", first.branch]),
                       "Boy Scout Agent <boy-scout-agent@localhost>|bsa: Correct the value fixture")
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
    }
}
