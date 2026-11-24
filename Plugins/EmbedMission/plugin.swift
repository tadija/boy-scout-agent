import PackagePlugin

@main
struct EmbedMission: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let input = context.package.directoryURL.appendingPathComponent("prompt.md")
        let output = context.pluginWorkDirectoryURL.appendingPathComponent("EmbeddedMission.swift")
        return [.buildCommand(
            displayName: "Embed Boy Scout mission",
            executable: try context.tool(named: "MissionGenerator").url,
            arguments: [input.path, output.path],
            inputFiles: [input], outputFiles: [output])]
    }
}
