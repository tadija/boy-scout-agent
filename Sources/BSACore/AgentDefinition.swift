/// Product policy kept separate from execution and harness adapters.
struct AgentDefinition {
    let name: String
    let executableName: String
    let mission: String
    let commitIdentity: String
    let branchNamespace: String
    let stateNamespace: String
    let consecutiveNoCandidateLimit: Int

    static let boyScout = AgentDefinition(
        name: "Boy Scout Agent", executableName: "bsa", mission: EmbeddedMission.markdown,
        commitIdentity: "Boy Scout Agent <boy-scout-agent@localhost>",
        branchNamespace: "bsa", stateNamespace: "bsa", consecutiveNoCandidateLimit: 2)
}
