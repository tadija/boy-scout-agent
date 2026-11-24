import Foundation
import PackagePlugin

@main
struct EmbedMission: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let input = context.package.directoryURL.appendingPathComponent("PROMPT.md")
        let generator = context.package.directoryURL.appendingPathComponent("Scripts/embed-mission.swift")
        let output = context.pluginWorkDirectoryURL.appendingPathComponent("EmbeddedMission.swift")
        // Track the generator source directly. Older SwiftPM versions can reuse a
        // cached build-tool executable after its source changes.
        return [.buildCommand(
            displayName: "Embed Boy Scout mission",
            executable: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["swift", generator.path, input.path, output.path],
            inputFiles: [input, generator], outputFiles: [output])]
    }
}
