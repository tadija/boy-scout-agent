import SwiftAgent
import SwiftAgentCLI
#if os(Linux)
import Glibc
#else
import Darwin
#endif

extension AgentDefinition {
    static let boyScout = AgentDefinition(
        name: "Boy Scout Agent", executableName: "bsa", mission: EmbeddedMission.markdown,
        commitIdentity: "Boy Scout Agent <boy-scout-agent@localhost>")
}

@main
enum BoyScoutAgent {
    static func main() {
        exit(AgentCLI.run(agent: .boyScout, version: BuildVersion.display, update: { executable in
            try Updater().update(executable: executable) { print($0) }
        }))
    }
}
