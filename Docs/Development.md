# Developing BSA

Build and test against the versioned remote dependency:

```sh
swift build --product bsa
swift test --parallel --num-workers 4
sh Tests/Integration/embedding-smoke.sh
sh Tests/Integration/version-smoke.sh
./Scripts/install.sh /tmp/bsa-bin
sh Tests/Integration/cli-smoke.sh /tmp/bsa-bin/bsa
```

No live model or paid harness is used. CI runs these checks on macOS and Linux
and packages the installed executable. Keep `Package.resolved` committed; no
sibling checkout, local path dependency, or SwiftPM mirror is needed.

## What belongs here

- `Sources/bsa/BoyScoutAgent.swift`: definition and direct `AgentCLI.run` invocation.
- `PROMPT.md`: the mission, without the generic execution contract or history.
- `Sources/bsa/Updater.swift`: preserves the existing `bsa update` workflow.
- `Plugins/` and Swift generators in `Scripts/`: embed mission and product metadata
  without a runtime resource bundle. SwiftAgent 0.1.0 exposes no reusable tooling
  for these tasks. Git/worktree metadata tracking preserves incremental builds.
- `Scripts/install.sh`, CI, `VERSION`, and license: independent distribution.
- `Tests/`: product assembly, compatibility, updater, and distribution checks.

There is one executable target and no application library or engine wrapper.
Tests import that target directly. To specialize this example, edit the definition,
mission, package/executable name, and distribution identity. The upstream
[API guide](https://github.com/tadija/swift-agent/blob/0.1.0/Docs/API.md)
provides a minimal example without BSA's legacy self-update/metadata requirements.

## Test ownership

| BSA retains | Reason |
| --- | --- |
| Mission bytes and identity/default assertions | Correct product assembly |
| Legacy record/config and branch/commit integration | Pre-extraction BSA compatibility |
| Schedule names and wrapper | Existing BSA installations |
| Updater success/failure and symlink tests | BSA owns this implementation |
| Installed CLI smoke | Product commands, mission, paths, commit, and legacy CLI compatibility |
| Embedding and version smoke fixtures | Locally maintained build plugins and generators |

Generic coverage lives in [SwiftAgent's tests](https://github.com/tadija/swift-agent/tree/0.1.0/Tests):
`RunnerTests` covers isolation, verification, publication guards, cancellation,
locking, continuation, skipped checks, and limits; `PromptTests` covers overrides,
contract composition, protected config, and invalid files; `HarnessTests`,
`OllamaTests`, and `OllamaHTTPTests` cover adapters; `ConfigurationTests` covers
validation; `OperationsTests` and `RunnerTests` cover schedules. The upstream
`generic-cli-smoke.sh` covers shared CLI integration and `PublicAPITests` plus
`package-consumer-smoke.sh` verify specialized agents. The cancellation/locking smoke scenario and redundant
protected-config test were removed after confirming upstream coverage. The installed smoke test retains legacy harness
argument mappings, CLI flag handling, and configuration precedence: upstream 0.1.0
tests adapters generically but does not cover all built-in argument mappings or
these CLI combinations. Move those assertions upstream before deleting them here.

The retained installer and metadata tooling are intentionally independent of
another checkout. Potential upstream reusable embedding/metadata plugins and a
parameterized source updater could reduce this support code in a future release;
none is required to build BSA with 0.1.0. Upstream CLI regression coverage is
needed to safely remove the remaining legacy CLI assertions downstream. Reusable
tooling should accept product inputs, preserve atomic replacement and metadata
rebuild guarantees, and be tested upstream before replacing these implementations. BSA's installer and CI should remain
independent even if that tooling becomes available.
