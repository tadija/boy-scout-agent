import SwiftAgent

public extension AgentDefinition {
    static let boyScout = AgentDefinition(
        name: "Boy Scout Agent", executableName: "bsa", mission: EmbeddedMission.markdown,
        commitIdentity: "Boy Scout Agent <boy-scout-agent@localhost>",
        branchNamespace: "bsa", stateNamespace: "bsa", consecutiveNoCandidateLimit: 2)
}
