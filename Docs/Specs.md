# Boy Scout Agent product specification

**Name:** Boy Scout Agent  
**CLI:** `bsa`  
**Principle:** One run. One improvement. One commit. Repeat.

BSA is a local-first, harness-agnostic continuous codebase improvement orchestrator.
It delegates one bounded improvement to a coding agent, verifies it, and records
one local Git commit per successful iteration. No-op is preferable to speculative
churn. Saturation never means objective perfection.

## Ownership

BSA is a thin downstream application of the independent SwiftAgent package.
The [upstream engine and CLI specification](https://github.com/tadija/swift-agent/blob/0.1.0/Docs/Specs.md)
is authoritative for iteration, Git isolation, protected paths, verification,
publication, cancellation, recovery, limits, scheduling, and history. BSA neither
duplicates nor overrides that implementation. Public library API is owned upstream.

BSA owns `AgentDefinition.boyScout`, the canonical [mission](../PROMPT.md), its
embedded representation, product updater, executable entry point, and metadata.
The default mission prioritizes correctness, reliability, warnings,
maintainability, consistency, documentation, and small useful polish. Preserve
public APIs and behavior unless a change is justified and verified.

## Compatibility contract

- Executable `bsa`; existing commands and flags supplied by `SwiftAgentCLI`.
- Repository `bsa.json`; global `$XDG_CONFIG_HOME/bsa/config.json`.
- History and schedules under `$XDG_DATA_HOME/bsa` with unchanged record schema.
- Default branch `bsa/<project>`, commit subject `bsa: <summary>`, identity
  `Boy Scout Agent <boy-scout-agent@localhost>`.
- One maximum iteration by default; stop after two consecutive empty attempts or
  three consecutive failures. Configurable limits retain their existing meanings.
- Repository lock/stop names `bsa.lock` and `bsa.stop`; macOS schedule labels
  `local.bsa.ID`; Linux units `bsa-ID.service` / `bsa-ID.timer`.
- Local commits only unless pushing is explicitly configured. Merge remains
  user-controlled. Existing branch ownership and history need no migration.
- `bsa update` retains its BSA GitHub `main` source destination and atomic
  executable replacement after a successful build. Failed builds preserve it.

## Mission and distribution

`PROMPT.md` is embedded byte-for-byte by the deterministic `EmbedMission` build
plugin. Markdown and generator changes invalidate the generated source. Installed
BSA requires no checkout, Markdown resource, or resource bundle for its default
mission. `VERSION` and Git revision are embedded independently for BSA.

Runtime prompt overrides retain CLI > repository > global > embedded precedence.
Paths, validation, guidance composition, and mandatory execution contracts follow
the upstream rules. Overrides cannot disable Git or verification guards.

SwiftPM consumes the upstream `SwiftAgent` and `SwiftAgentCLI` products from
`0.1.0`. No machine-specific dependency is distributed. Both products support
macOS and Linux with Swift 6+. [Configuration](Configuration.md),
[operations](Operations.md), and [installation](Installation.md) document BSA's
product names and workflows; generic details are linked upstream.

## Product acceptance

BSA must continue to run, review, and record improvements using existing settings
and history. Default mission fidelity, product identity, prompt overrides,
self-contained installation, updates, namespaces, and downstream consumption are
tested here. Shared safety/lifecycle regression tests run upstream. Creating
another agent requires a name, Markdown mission, and optional configuration,
with no modification of SwiftAgent.

The original architectural plans and Stage 1/2 completion record remain under
`Docs/Plan` as historical design context, not duplicate active engine specifications.
