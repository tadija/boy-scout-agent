# SwiftAgent package

SwiftAgent is a harness-agnostic Swift framework for autonomous, iterative repository agents. It remains inside the Boy Scout Agent repository for architectural extraction Stage 2.

## Products and ownership

```text
bsa ──────────── SwiftAgentCLI ─── SwiftAgent ─── ProcessSupport (C)
 └────────────── BoyScoutAgent ─── SwiftAgent
swift-agent ──── SwiftAgentCLI
```

`SwiftAgent` owns the repository lifecycle, harnesses and native Ollama integration, process execution, Git worktrees, verification, commits, session limits, configuration, history, recovery, and generated schedules. It has no CLI parsing, process exit, embedded mission, GitHub update destination, or BSA identity. Planner, change policy, state storage, and repository locking are internal.

`SwiftAgentCLI` owns the existing commands, argument parsing, terminal presentation, signal-handler installation, and return codes. `AgentCLI.run` accepts an agent, arguments (defaulting to process arguments), optional version display string (defaulting to the agent name), and optional application-owned updater callback. It returns `Int32`; only executable entry points call `exit`.

`BoyScoutAgent` is a small application support target, not a generic library product. It owns `.boyScout`, the generated embedded mission, and the existing GitHub self-updater. `bsa/main.swift` only wires these into `AgentCLI`. `swift-agent/main.swift` wires `.generic` into the same implementation and supplies build metadata. `ProcessSupport` remains an implementation dependency; its existing C symbol names are internal build details.

## Local SwiftPM consumption

Until Stage 3 establishes an upstream repository and release, depend on this checkout:

```swift
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "DocumentationAgent", platforms: [.macOS(.v13)], dependencies: [
    .package(path: "../boy-scout-agent")
], targets: [
    .executableTarget(name: "DocumentationAgent", dependencies: [
        .product(name: "SwiftAgent", package: "boy-scout-agent"),
        .product(name: "SwiftAgentCLI", package: "boy-scout-agent")
    ])
])
```

No BSA target or mission plugin is needed to consume these products. `Tests/Integration/package-consumer-smoke.sh` builds a separate package against both libraries and verifies this boundary.

## Programmatic API

```swift
import Foundation
import SwiftAgent

let directory = URL(fileURLWithPath: "/path/to/repository")
let agent = AgentDefinition(name: "Documentation Agent", executableName: "doc-agent",
                            mission: "Improve one missing or incorrect usage example.")
var configuration = try Configuration.load(repository: Repository(at: directory), agent: agent)
configuration.maxIterations = 3
let harness = try Harnesses.select(configuration: configuration, directory: directory)
let records = try Runner(agent: agent).runSession(
    at: directory, configuration: configuration, harness: harness,
    onProgress: { print($0) }, onIteration: { print($0.outcome) })
```

Use `Configuration(agent: agent)` for defaults without loading files. Passing a configuration is explicit: create/load it with the same agent to select its identity and stop defaults. `Runner.run` executes one iteration; `runSession` executes a bounded sequence. `Runner.prompt`, `status`, `history`, and `stop` expose the existing operational functions. `Record` and `Check` report results. `HarnessAdapter` permits deterministic custom implementations; `CommandHarness` and `Harnesses` provide reusable integrations, including the internal Ollama adapter. `CommandRunner`/`CommandResult` provide bounded subprocess execution. Errors use `AgentError`.

The public surface reuses the existing synchronous process/harness API. It does not introduce an async wrapper around blocking work. Cancellation remains cooperative through `Cancellation` and repository stop markers, with process-group termination and bounded grace periods. An explicit `dataDirectory` replaces the resolved state root; supply distinct roots for distinct agents when overriding it. Signal installation is opt-in for programmatic callers (`Cancellation.install()`). Cancellation state is process-wide: run one session at a time in an embedding process. Concurrent sessions within one process and task-local cancellation are not supported. A future concurrency redesign should address that state at its source.

Definitions contain a display name, executable name, optional Markdown mission, and optional commit identity, branch/state namespaces, and consecutive no-candidate limit. Executable and namespace components must be nonempty ASCII letters, digits, hyphens, or underscores. Defaults derive from the executable name; custom namespaces should be unique per agent. Explicit blank missions fail unless a prompt file replaces them. No generic mission is inferred. Avoid defining a protocol or subclass for a new mission.

## Missions and self-contained distribution

BSA's canonical root `prompt.md` is embedded by `EmbedMission`/`Scripts/embed-mission.swift` into `BoyScoutAgent` only, with explicit Markdown and generator build dependencies. UTF-8 bytes are generated as Swift source. No resource bundle or checkout is required at runtime. The generic engine and CLI do not import generated mission symbols. Specialized consumers may embed Markdown into a Swift constant using the same generation pattern or supply a runtime prompt; no generation plugin is attached to the generic libraries.

`BuildVersion` embeds `VERSION` and Git HEAD independently in each executable. The generic CLI displays Swift Agent metadata, and BSA retains its existing version display. `Scripts/install.sh` still installs BSA by default; `--product swift-agent` selects the generic executable. Both use atomic replacement after a successful release build.

The reusable CLI supports `run --prompt PATH`, count/time/harness options, overrides, operational commands, and generated schedules. Generic execution requires a mission from a file passed on the CLI or configuration. CLI paths resolve against the invocation directory; configured paths resolve against the original repository root. Mission precedence, validation, mandatory contract composition, Git isolation, protected paths, and independent verification are identical for both products.

## Compatibility and extraction readiness

BSA retains `bsa.json`, XDG `bsa` config/data directories, `bsa/<project>` branches, `bsa:` commit subjects, commit identity, no-candidate policy, JSON records, schedule filenames, and update destination. The former internal `BSACore` target has been replaced; it was not a published library product. Internal errors are renamed to `AgentError`; CLI error prefixes stay product-specific.

For Stage 3, move `SwiftAgent`, `SwiftAgentCLI`, `ProcessSupport`, the generic executable, their generic tests, and build/install tooling upstream. Keep `BoyScoutAgent`, root mission, BSA entry point, product docs, updater tests, and BSA compatibility tests downstream. The current `BSACoreTests` name identifies the preserved regression suite; several tests intentionally use the BSA compatibility fixture. Separate their fixture ownership when splitting repositories. `SwiftAgentPublicTests` and generic/external-consumer smoke tests already depend on generic products alone.

There is no upstream URL, tag, push, or remote dependency change in Stage 2. Establish provenance, upstream metadata ownership, generic installation/update policy, and an immutable tested release before downstream integration.
