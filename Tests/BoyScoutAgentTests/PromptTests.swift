import XCTest
import SwiftAgent
@testable import bsa

final class AgentDefinitionTests: XCTestCase {
    func testEmbeddedMissionMatchesCanonicalMarkdownExactly() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        XCTAssertEqual(AgentDefinition.boyScout.mission,
                       try String(contentsOf: root.appendingPathComponent("Sources/bsa/prompt.md"), encoding: .utf8))
    }

    func testGeneratedProductMatchesDeclaration() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with:
            Data(contentsOf: root.appendingPathComponent("Sources/bsa/agent.json"))) as? [String: Any])
        let product = EmbeddedProduct.metadata
        XCTAssertEqual(product.name, json["name"] as? String)
        XCTAssertEqual(product.executableName, json["executableName"] as? String)
        XCTAssertEqual(product.version, json["version"] as? String)
        XCTAssertEqual(product.build, json["build"] as? String)
        XCTAssertEqual(product.commitIdentity, json["commitIdentity"] as? String)
        XCTAssertEqual(AgentDefinition.boyScout.commitIdentity, product.commitIdentity)
        XCTAssertEqual(product.displayVersion, "Boy Scout Agent " + product.version
            + (product.build.map { " (\($0))" } ?? ""))
        XCTAssertEqual(product.update?.repository, "https://github.com/tadija/boy-scout-agent.git")
        XCTAssertEqual(product.update?.reference, "main")
    }

    func testBoyScoutIdentityAndNamespaces() {
        let agent = AgentDefinition.boyScout
        XCTAssertEqual(agent.name, "Boy Scout Agent")
        XCTAssertEqual(agent.commitIdentity, "Boy Scout Agent <boy-scout-agent@localhost>")
        XCTAssertEqual(agent.executableName, "bsa")
        XCTAssertEqual(agent.branchNamespace, "bsa")
        XCTAssertEqual(agent.stateNamespace, "bsa")
        XCTAssertEqual(Configuration(agent: .boyScout).commitIdentity, agent.commitIdentity)
    }

}
