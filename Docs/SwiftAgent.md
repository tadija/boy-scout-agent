# BSA and SwiftAgent

BSA is a downstream application of [SwiftAgent](https://github.com/tadija/swift-agent),
an independent Swift package providing the engine and reusable CLI.

```text
bsa ──────────── SwiftAgentCLI ─── SwiftAgent ─── ProcessSupport (C)
 └────────────── BoyScoutAgent ─── SwiftAgent
```

The dependency uses `https://github.com/tadija/swift-agent.git`, starting at
`0.1.0` and excluding `0.2.0` (`upToNextMinor`). Generic code, tests, API documentation, and execution specifications
belong upstream. This repository retains the Boy Scout definition, embedded mission,
updater, entry point, build/install tooling, and product compatibility tests.
No local engine copy or development path dependency remains.

The public Swift API is unchanged by extraction. For generic CLI usage,
programmatic execution, and new specialized executables, see the upstream
[README](https://github.com/tadija/swift-agent#readme) and
[API guide](https://github.com/tadija/swift-agent/blob/0.1.0/Docs/API.md).
The generic executable installs from its own repository:

```sh
git clone https://github.com/tadija/swift-agent.git
cd swift-agent
./Scripts/install.sh
swift-agent run --prompt ./Docs/Examples/PROMPT.md --count 3
```

Installed BSA keeps its existing versioning and update destination. New source
builds resolve SwiftAgent through SwiftPM; the resulting executable remains
self-contained. See the [Stage 3 report](Plan/stage-3-completion.md) for local
validation and upstream publication status.
