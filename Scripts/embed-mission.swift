import Foundation

// Byte literals preserve Markdown exactly, independent of Swift string escaping.
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let data = try Data(contentsOf: input)
guard let markdown = String(data: data, encoding: .utf8),
      !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
    fatalError("Mission must be nonempty UTF-8 Markdown: \(input.path)")
}
let bytes = data.map(String.init).joined(separator: ",")
try "// Generated from prompt.md. Do not edit.\nenum EmbeddedMission {\n    static let markdown = String(decoding: [\(bytes)] as [UInt8], as: UTF8.self)\n}\n"
    .write(to: output, atomically: true, encoding: .utf8)
