import SwiftAgent
import SwiftAgentCLI
#if os(Linux)
import Glibc
#else
import Darwin
#endif

extension AgentDefinition {
    static let boyScout = AgentDefinition(
        name: EmbeddedProduct.metadata.name, executableName: EmbeddedProduct.metadata.executableName,
        mission: EmbeddedMission.prompt,
        commitIdentity: EmbeddedProduct.metadata.commitIdentity)
}

let product = EmbeddedProduct.metadata
do {
    let update = try product.update.map {
        try SourceUpdateConfiguration(repository: $0.repository, reference: $0.reference)
    }
    exit(AgentCLI.run(agent: .boyScout, version: product.displayVersion, sourceUpdate: update))
} catch {
    print(error)
    exit(1)
}
