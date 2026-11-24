import SwiftAgent
import SwiftAgentCLI
import BoyScoutAgent
#if os(Linux)
import Glibc
#else
import Darwin
#endif

exit(AgentCLI.run(agent: .boyScout, version: BuildVersion.display, update: { executable in
    try Updater().update(executable: executable) { print($0) }
}))
