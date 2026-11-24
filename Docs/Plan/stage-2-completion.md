# Stage 2 completion report

## Scope and Stage 1 audit

Implemented Stage 2 within the existing repository. No repository extraction, remote change, publishing, or dependency on an invented upstream release occurred.

Read all three extraction plans, the package, sources, tests, operational/configuration documentation and specification, and recent history. Stage 1's completion evidence is commit `1509eed` and its regression tests; no separate completion report was present. Commit `b4adc1f` subsequently added embedded build metadata. The existing implementation separated contract, mission, guidance and history, embedded the canonical mission, validated prompt overrides before execution, and retained code-enforced Git/verification gates. Its remaining coupling was direct access to `.boyScout` from generic configuration, runner, state and scheduler code, plus CLI parsing and product updater ownership.

## Architecture and decisions

The manifest now exports `SwiftAgent` and `SwiftAgentCLI` library products, `swift-agent`, and the existing `bsa` executable. The module graph and full API examples are in [SwiftAgent.md](../SwiftAgent.md).

- `SwiftAgent` depends on internal C `ProcessSupport` and platform libraries. It owns harnesses, native Ollama integration, subprocesses, Git isolation, iteration/session lifecycle, verification, commit publication, configuration, state/history/recovery, execution windows and schedule generation. It has no BSA mission, CLI dependency, argument parser or process exit.
- `SwiftAgentCLI` depends only on `SwiftAgent`; it owns shared command handling, terminal presentation and return codes. An optional application callback supplies self-update.
- `BoyScoutAgent` owns the BSA definition, generated embedded mission, and existing self-updater. `bsa` is a thin wiring entry point.
- `swift-agent` supplies the generic definition without a mission and uses the same CLI. It requires `--prompt PATH` or configured `prompt`. Its config/data/branch/schedule/lock/stop namespaces are independent of BSA.

BSA retains its default identity, `bsa.json`, global configuration, data/history schema and paths, branches, commit subjects, stop policy, scheduling names, flags, installation default and update destination. The mission is still embedded as deterministic Swift source; no runtime resource bundle is introduced. Both installers use atomic replacement and both executables carry embedded build metadata.

The current BSA application implementation is 84 Swift source lines: 8 for its definition, 64 for the existing updater, and 12 for the executable entry point, plus the 10-line canonical mission. Product-specific documentation, tests and metadata remain downstream concerns. The generic engine contains no Boy Scout policy; the retained C process helper's `bsa_spawn` symbol is an internal historical name.

## Public API and second agent

`AgentDefinition` supplies identity, optional Markdown mission and optional policy defaults. `Configuration(agent:)` or `Configuration.load(repository:agent:)` resolves configuration. `Runner(agent:)` exposes run/session execution and prompt/status/history/stop operations. `Harnesses` selects adapters; `HarnessAdapter` and public `CommandResult` support custom integrations. Implementation details such as planner, state store, locks, tools and diff policy remain internal.

A specialized CLI needs only its definition and the shared entry point:

```swift
import SwiftAgent
import SwiftAgentCLI
let agent = AgentDefinition(name: "Documentation Agent", executableName: "doc-agent",
                            mission: "Improve one missing or incorrect usage example.")
let status = AgentCLI.run(agent: agent)
// The executable passes status to exit().
```

[Examples/documentation.md](../../Examples/documentation.md) also works directly with `swift-agent run --prompt PATH`. Deterministic tests demonstrate a verified documentation commit, unchanged next iteration, protected configuration rejection and missing-mission rejection, without modifying the engine. A separate SwiftPM consumer builds against the two public library products without generating the BSA mission.

## Verification

Validated on macOS arm64 with Apple Swift 6.4.2. After the release CI fix, the rebased Stage 2 also passed its complete CI sequence in a Linux arm64 container with Swift 6.0.3 and all 80 tests on macOS using SwiftPM’s native build system:

- `BSA_INTEGRATION_TESTS=1 swift test`: 80 XCTest cases passed, no failures or skips (79 preserved regression/integration cases plus one public-API scenario).
- Release installation of both executables into `/tmp/swift-agent-stage2-bin`, outside the checkout.
- BSA CLI smoke suite, including fake external harnesses, mission overrides, cancellation, locking, scheduling and verification behavior.
- Generic CLI smoke suite, including required/configured missions, count/time flags, documentation changes, namespace isolation, history and scheduling.
- External package-consumer smoke suite against both public library products.
- Markdown embedding/rebuild-dependency smoke suite and version/build-metadata smoke suite.
- `git diff --check`.

No live model or paid harness was invoked. The existing macOS/Linux CI matrix runs the new suites and packages both executables. The workflow was reproduced locally in a Linux Swift 6.0 container; remote CI still requires a push.

## Deviations and Stage 3 considerations

The existing synchronous process/harness execution API was retained to keep this an incremental extraction. No async facade or concurrency dependency was added. Cancellation remains process-wide, so programmatic consumers must run one session at a time; this limitation is documented. Different agent processes have separate namespaces but should run sequentially against one repository because ref-integrity guards reject concurrent publication.

BSA's existing self-updater stays in its small application support target, preserving its source destination without embedding it in generic libraries. Generic self-update reports that it is unavailable until a real upstream source is established. The former `BSACore` target was internal, with no published library product; consumers now use `SwiftAgent`. The preserved regression target retains its historical `BSACoreTests` name.

Stage 3 must establish upstream provenance and release/version ownership, move generic modules/tooling/tests, partition the mixed regression fixture ownership, keep BSA's mission/updater/compatibility tests downstream, and integrate an actual immutable upstream reference. Decide generic installation/update ownership then. No source duplication, orchestration subclass or mission-specific adapter is needed for extraction.
