import XCTest
@testable import BSACore

/// Real build and adapter subprocess coverage, enabled explicitly in CI and before releases.
final class ExternalIntegrationTests: RepositoryTestCase {
    override func setUpWithError() throws {
        guard ProcessInfo.processInfo.environment["BSA_INTEGRATION_TESTS"] == "1" else {
            throw XCTSkip("Run with BSA_INTEGRATION_TESTS=1 to enable external integration tests")
        }
        try super.setUpWithError()
    }

    func testZeroConfigSwiftPackageDetectsAndRunsTests() throws {
        try FileManager.default.removeItem(at: checkout.appendingPathComponent("bsa.json"))
        try write("Package.swift", """
        // swift-tools-version: 6.0
        import PackageDescription
        let package = Package(name: "Fixture", targets: [
            .target(name: "Fixture"), .testTarget(name: "FixtureTests", dependencies: ["Fixture"])
        ])
        """)
        try FileManager.default.createDirectory(at: checkout.appendingPathComponent("Sources/Fixture"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: checkout.appendingPathComponent("Tests/FixtureTests"), withIntermediateDirectories: true)
        try write("Sources/Fixture/Value.swift", "public func value() -> Int { 1 }\n")
        try write("Tests/FixtureTests/ValueTests.swift", """
        import XCTest
        @testable import Fixture
        final class ValueTests: XCTestCase {
            func testValue() { XCTAssertEqual(Fixture.value(), 2) }
        }
        """)
        try git(["add", "--all"])
        try git(["commit", "-m", "Swift package with failing test"])
        let record = try run { cwd in
            try self.write("Sources/Fixture/Value.swift", "public func value() -> Int { 2 }\n", at: cwd)
            return self.success()
        }
        XCTAssertEqual(record.outcome, "committed", (record.detail ?? "") + "\n" + (record.checks.first?.output ?? ""))
        XCTAssertNotEqual(record.baselineChecks.first?.status, 0)
        XCTAssertEqual(record.checks.first?.status, 0)
        XCTAssertEqual(record.paths, ["Sources/Fixture/Value.swift"])
    }

    func testCodexAdapterWithFakeExecutableEndToEnd() throws {
        let bin = temporary.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let executable = bin.appendingPathComponent("codex")
        let script = """
        #!/bin/sh
        [ "$1" = --ask-for-approval ] && [ "$2" = never ] || exit 6
        shift 2
        if [ "$1" = exec ] && [ "$2" = --help ]; then
          echo '--sandbox --cd --output-last-message'
          exit 0
        fi
        [ "$1" = exec ] || exit 2
        [ "$2" = --sandbox ] && [ "$3" = workspace-write ] || exit 3
        [ "$4" = --cd ] && [ "$5" -ef . ] || exit 4
        [ "$6" = --output-last-message ] || exit 5
        printf 'after\n' > value.txt
        printf 'Correct the fixture value\nVerified the change.' > "$7"
        echo 'noisy harness banner'
        """
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let previous = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        setenv("PATH", bin.path + ":" + previous, 1)
        defer { setenv("PATH", previous, 1) }
        let record = try Runner().run(at: checkout, harness: CodexAdapter(), dataDirectory: data)
        XCTAssertEqual(record.outcome, "committed", record.detail ?? "")
        XCTAssertEqual(try git(["log", "-1", "--format=%s", record.branch]), "bsa: Correct the fixture value")
        XCTAssertFalse(record.task?.contains("noisy harness") ?? true)
    }
}
