import Foundation

public struct Configuration: Codable {
    public var push: Bool = false
    public var harness: String?
    public var customCommand: [String]?
    public var instructions: String = ""
    public var maxIterations: Int = 1
    public var failureLimit: Int = 3
    public var saturationLimit: Int = 2
    public var branch: String?
    public var base: String?
    public var verification: [String]?
    public var timeoutSeconds: Double = 1800
    public var maxChangedFiles: Int = 12
    public init() {}

    public static func load(repository: Repository) throws -> Configuration {
        let configBase = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config").path
        let urls = [URL(fileURLWithPath: configBase).appendingPathComponent("bsa/config.json"), repository.root.appendingPathComponent("bsa.json")]
        var dictionary: [String: Any] = [:]
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            guard let values = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else {
                throw BSAError.message("Configuration must be a JSON object: " + url.path)
            }
            dictionary.merge(values) { _, new in new }
        }
        guard
              Set(dictionary.keys).isSubset(of: ["branch", "base", "verification", "timeoutSeconds", "maxChangedFiles", "harness", "customCommand", "instructions", "maxIterations", "failureLimit", "saturationLimit", "push"]) else {
            throw BSAError.message("bsa.json contains unknown keys or is not an object")
        }
        let defaults: [String: Any] = ["push": false, "timeoutSeconds": 1800, "maxChangedFiles": 12, "instructions": "", "maxIterations": 1, "failureLimit": 3, "saturationLimit": 2]
        let merged = defaults.merging(dictionary) { _, new in new }
        let configuration = try JSONDecoder().decode(Configuration.self, from: JSONSerialization.data(withJSONObject: merged))
        try configuration.validate()
        return configuration
    }
    func validate() throws {
        guard maxIterations > 0, failureLimit > 0, saturationLimit > 0,
              customCommand.map({ !$0.isEmpty && !$0[0].isEmpty }) ?? true,
              timeoutSeconds.isFinite, timeoutSeconds > 0, timeoutSeconds <= 86400,
              maxChangedFiles > 0, maxChangedFiles <= 100,
              verification?.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? true else {
            throw BSAError.message("Invalid limits or empty verification command in bsa.json")
        }
    }
}
