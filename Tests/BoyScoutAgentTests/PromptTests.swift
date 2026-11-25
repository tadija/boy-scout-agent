import XCTest
import SwiftAgent
@testable import bsa

final class AgentDefinitionTests: XCTestCase {
    func testEmbeddedMissionMatchesCanonicalMarkdownExactly() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        XCTAssertEqual(AgentDefinition.boyScout.mission,
                       try String(contentsOf: root.appendingPathComponent("PROMPT.md"), encoding: .utf8))
    }

    func testBoyScoutIdentityAndPolicyDefaults() {
        let agent = AgentDefinition.boyScout
        XCTAssertEqual(agent.name, "Boy Scout Agent")
        XCTAssertEqual(agent.commitIdentity, "Boy Scout Agent <boy-scout-agent@localhost>")
        XCTAssertEqual(Configuration(agent: .boyScout).maxIterations, 1)
        XCTAssertEqual(Configuration(agent: .boyScout).failureLimit, 3)
        XCTAssertEqual(agent.executableName, "bsa")
        XCTAssertEqual(agent.branchNamespace, "bsa")
        XCTAssertEqual(agent.stateNamespace, "bsa")
        XCTAssertEqual(Configuration(agent: .boyScout).commitIdentity, agent.commitIdentity)
        XCTAssertEqual(Configuration(agent: .boyScout).saturationLimit, 2)
    }

}
