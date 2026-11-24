# Stage 3 completion report

## Scope and baseline audit

Local extraction and downstream integration are implemented. **Remote dependency
publication and an unmirrored GitHub resolution remain pending.** The repository
was created with owner authorization; no push or release publication was authorized.

Read all three stage plans and the Stage 2 completion report, then inspected the
manifest, source/module boundaries, tests, docs/specification, build/install/CI
scripts, and recent commits. Stage 1 (`1509eed`) embeds and separates the Boy Scout
mission from the engine contract; Stage 2 (`b67443b`) provides generic engine and
CLI products with an independent definition. Those boundaries were present and
functional. The starting checkout was clean at `21c1fd6`; its README work is preserved.

The extraction preserves these implementations rather than rewriting them. The
public synchronous API, process-wide cancellation limitation, fresh-agent loop,
Git/verification guards, and state formats remain unchanged.

## Extraction strategy and structures

A local sibling repository named `swift-agent` was created. At the owner's
request it starts with **one fresh initial commit**; no BSA Git commits or refs
are transferred. The original MIT license and attribution are preserved, with
source provenance identifying BSA `21c1fd6`. BSA's own history is untouched.
The earlier local filtered-history candidate was replaced before publication.

SwiftAgent owns:

```text
Sources/SwiftAgent/          engine, configuration, harnesses, Ollama, Git,
                            checks, commits, limits, history, recovery, schedules
Sources/SwiftAgentCLI/       command parsing, presentation, return codes
Sources/ProcessSupport/      internal C process support
Sources/swift-agent/         generic executable entry point
Tests/SwiftAgentTests/       generic regressions and external integration
Tests/SwiftAgentPublicTests/ public API acceptance
Tests/Integration/          generic CLI, external consumer, build metadata
Docs/                       generic specification, API, configuration, operations
```

BSA retains:

```text
Sources/BoyScoutAgent/       definition and updater
Sources/bsa/                thin executable entry point
PROMPT.md                   canonical embedded Boy Scout mission
Plugins/EmbedMission/       product mission generation
Plugins/BSABuildVersion/    product metadata generation
Tests/BoyScoutAgentTests/    mission, identity, legacy compatibility, updater
Tests/Integration/          BSA CLI, embedding, metadata smoke tests
Docs/                       product behavior and upstream references
```

BSA-specific implementation remains **84 Swift lines**: 8 definition, 64 updater,
12 entry point, plus the unchanged 10-line Markdown mission. Build/install tools
remain product-owned. There is no local generic engine, adapter, CLI parser, or
orchestration implementation. Generic tests/examples and authoritative shared
specifications moved upstream; BSA documents its mission and compatibility.

## API, dependency, and versioning

Upstream exports `SwiftAgent`, `SwiftAgentCLI`, and `swift-agent`. The public Swift
API is unchanged. The only implementation rename is neutralizing an internal C
spawn symbol/header guard. A custom agent still needs only a definition and CLI:

```swift
let agent = AgentDefinition(name: "Documentation Agent", executableName: "doc-agent",
                            mission: "Improve one missing or incorrect usage example.")
exit(AgentCLI.run(agent: agent))
```

Programmatic callers use `Configuration.load(repository:agent:)`, `Harnesses.select`,
and `Runner(agent:).runSession`; complete manifests/examples and constraints are
owned by [upstream API docs](https://github.com/tadija/swift-agent/blob/0.1.0/Docs/API.md).

The final BSA manifest uses:

```swift
.package(url: "https://github.com/tadija/swift-agent.git", .upToNextMinor(from: "0.1.0"))
```

This admits compatible `0.1.x` releases and excludes pre-1.0 breaking minor changes.
Upstream `VERSION` is `0.1.0`; local annotated tag `0.1.0` points to tested extraction
commit **`940636027408370c4652e705bc234d24d7f6c445`**. The initial commit includes its
extraction report. Published tags must remain immutable. BSA keeps its own `VERSION`.

Validation uses this exact tag through a temporary SwiftPM mirror in disposable
checkouts/containers. No local dependency, mirror, machine path, or unpublished
revision requirement is left in BSA. `Package.resolved` is deliberately not copied
from mirrored validation: it would refer to a local, unpublished source. Generate
and commit it after genuine remote resolution.

## Compatibility and installation

No migration is required for installed BSA or existing config/history/schedules.
Preserved: `bsa`, `bsa.json`, XDG `bsa` paths, `bsa/<project>`, commit author/subject,
`bsa.lock` / `bsa.stop`, schedule filenames/labels, prompt precedence/paths, count
and stop defaults, user-facing flags, and BSA's GitHub updater destination.

The BSA installer still defaults to `bsa` and accepts `--product bsa`. The generic
executable now installs from its own repository; `--product swift-agent` belongs
there. Both independently build release binaries with atomic replacement and
embedded product metadata. BSA embeds exact default mission bytes with no runtime
resource bundle; runtime prompt overrides remain supported.

The first external-package build caught a SwiftPM target collision between both
private `BuildVersion` plugins. BSA now names its plugin `BSABuildVersion`, with
unchanged generated metadata/output. This is an extraction-required private rename.

## Verification results

Validated on macOS arm64 with Apple Swift 6.4.2 and Linux arm64 in Docker
`swift:6.0-noble` with Swift 6.0.3:

| Check | macOS | Linux |
| --- | --- | --- |
| SwiftAgent complete tests, external Swift fixture enabled | 76 passed | 76 passed |
| BSA complete product test suite | 7 passed | 7 passed |
| Generic release install and installed CLI smoke | Passed | Passed |
| BSA release install and installed CLI smoke | Passed | Passed |
| BSA mission embedding/rebuild smoke | Passed | Passed |
| Independent executable metadata/ref/archive smoke suites | Passed | Passed |
| External custom-agent package build and verified commit/no-op | Passed | Passed |

Upstream was also cloned cleanly from local `0.1.0`, tested, release-installed
outside the checkout, and smoke-tested on macOS. Linux source snapshots excluded
all local build/config caches. BSA was built in a separate Git checkout with only
its downstream files and a mirrored, version-resolved external SwiftAgent package.
Final clean commit clones verify the committed downstream state and the fresh
upstream release candidate as well.

Product tests cover byte-exact mission embedding, identity/defaults, legacy JSON
without newer optional fields, existing config, continuation/history, commit names,
mission overrides, protected config, schedule names, and updater atomicity/failure.
The existing BSA CLI smoke suite covers fake harness mappings, prompt precedence,
dirty working tree preservation, verification, cancellation, locks, and schedules.
Shared safety, isolation, publication, failure/no-op, iteration, and recovery
regressions now run upstream. A separate consumer executable creates a verified
documentation commit using only public products and a definition.

A direct upgrade experiment also ran the existing local pre-extraction BSA binary
(`0.2.1`, embedded build `590e68f`) to create a branch/history/schedule, then ran
the extracted binary against the same state. Configuration, ownership continuation,
history reads, no-op behavior, and schedule list/removal all passed.

No live model/paid CLI, remote GitHub CI, Intel host, or actual native service
activation was tested. Linux validation is container-based. No unmirrored remote
dependency resolution has succeeded, because the upstream tag is not published.
Local link targets and `git diff --check` were checked in both repositories.

## Repository, commit, tag, and publishing status

- Public GitHub repository created: `https://github.com/tadija/swift-agent`.
- Local sibling checkout has origin `git@github.com:tadija/swift-agent.git`.
- Upstream initial extraction: `9406360`; local annotated tag: `0.1.0`.
- Downstream implementation is the commit containing this report; its final hash
  is included in the user-facing completion report.
- No remote commits/tags/releases pushed or published. Existing BSA remote is unchanged.

The remote is intentionally empty. Ordinary source builds of this new BSA commit,
including `bsa update` after downstream publication, require upstream publication
first. Existing installed binaries remain operational. This limitation is explicit
in the installation docs; no alternate repository or hidden dependency is used.

## Remaining owner actions

After explicit publication authorization:

1. In SwiftAgent, push `main` and the existing `0.1.0` tag to origin.
2. In a clean BSA checkout, resolve the intended GitHub dependency with no mirrors,
   run its complete tests/install/CLI checks, and commit the real `Package.resolved`.
3. Publish downstream changes only after that resolution succeeds; inspect both
   repositories' macOS/Linux GitHub Actions runs. A GitHub release is optional
   and requires separate publication authorization.

Stage 3's local implementation is complete. Remote publication and final public
resolution are outstanding by authorization boundary, not silently substituted.
The generic updater remains intentionally unsupported: checkout + reinstall is
its independent update workflow. No unrelated features or later stage work added.

## Follow-up: uppercase mission filename

The canonical mission is now `PROMPT.md`; its bytes and runtime behavior are
unchanged. Embedding inputs, generator comments, tests, and documentation use the
new filename. All 7 BSA tests and the embedding/rebuild smoke test passed.

Since the original report, upstream `0.1.0` has become available on GitHub. This
follow-up resolved it directly without a mirror, at commit
`940636027408370c4652e705bc234d24d7f6c445`, and records the real `Package.resolved`.
The publication-boundary statements above describe the original extraction run.
The owner also requested moving SwiftAgent's example mission to
`Docs/Examples/PROMPT.md`, amending its initial commit, recreating its `0.1.0`
tag, and force-pushing the amended repositories. SwiftAgent's branch and tag
were updated with explicit leases; BSA's amended branch follows after clean
remote dependency verification. SwiftPM's previously recorded fingerprint for
the intentionally replaced `0.1.0` tag was refreshed only for this package.
No engine or CLI implementation changed during these filename/layout updates.
