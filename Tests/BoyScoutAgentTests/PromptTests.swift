import XCTest
import SwiftAgent
import BoyScoutAgent

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
        XCTAssertEqual(agent.executableName, "bsa")
        XCTAssertEqual(agent.branchNamespace, "bsa")
        XCTAssertEqual(agent.stateNamespace, "bsa")
        XCTAssertEqual(Configuration(agent: .boyScout).commitIdentity, agent.commitIdentity)
        XCTAssertEqual(Configuration(agent: .boyScout).saturationLimit, 2)
    }

}
