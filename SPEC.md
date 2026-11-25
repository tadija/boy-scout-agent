# Boy Scout Agent product specification

Boy Scout Agent (`bsa`) leaves a codebase a little better than it found it.
One iteration seeks one bounded, worthwhile improvement and produces one verified
local commit when successful. No-op is preferable to speculative churn.

## Mission

[prompt.md](Sources/bsa/prompt.md) is the canonical Boy Scout mission. Inspect the repository,
consider at most five candidates, and prioritize correctness, reliability, warnings,
maintainability, consistency, documentation, then polish. Prefer high confidence,
low risk changes, preserve public APIs and behavior, and explore neglected areas.

SwiftAgent composes this mission with its mandatory execution contract, project
guidance, and runtime history. BSA does not repeat those instructions in its mission.
Runtime prompt overrides replace the mission through the shared CLI/configuration.
The default Markdown is embedded byte-for-byte into the executable.

## Identity and compatibility

[agent.json](Sources/bsa/agent.json) supplies the product name, executable name,
version, historical commit identity and update source. The entry point assembles
the generated metadata and mission. SwiftAgent derives namespaces
and other defaults; BSA does not override them.

| Product setting | Value |
| --- | --- |
| Name / executable | Boy Scout Agent / `bsa` |
| Commit identity | `Boy Scout Agent <boy-scout-agent@localhost>` |
| Commit subject / branch | `bsa: <summary>` / `bsa/<project>` |
| Repository / global config | `bsa.json` / `$XDG_CONFIG_HOME/bsa/config.json` |
| History and schedules | `$XDG_DATA_HOME/bsa` |
| Git lock / stop marker | `bsa.lock` / `bsa.stop` |
| macOS schedule label | `local.bsa.ID` |
| Linux schedule units | `bsa-ID.service` / `bsa-ID.timer` |

XDG paths default to `~/.config` and `~/.local/share`. Existing configuration,
history, branch ownership, schedules, commands, and flags remain compatible.
Inherited session defaults are one maximum iteration, stopping after two consecutive
empty attempts or three failures. These remain configurable upstream behavior.

## Ownership

BSA depends on the published SwiftAgent `0.2.x` package. Its
[specification](https://github.com/tadija/swift-agent/blob/0.2.0/Docs/Specs.md)
is authoritative for the engine, CLI, configuration, verification, Git workflow,
harnesses, scheduling, cancellation, and operational guarantees.

BSA owns the mission and definition, executable entry point, version, trusted update
source, and independent install/distribution support. SwiftAgent owns the build
plugin, generated APIs and complete source update mechanism. Installed
binaries remain self-contained on macOS and Linux. `bsa update` retains atomic
replacement from BSA's GitHub `main`; see [installation](README.md#install).
Product assembly and compatibility are tested here; engine regressions belong
upstream. See [development](README.md#development) for coverage ownership.
