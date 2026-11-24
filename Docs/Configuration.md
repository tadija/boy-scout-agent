# BSA configuration

BSA uses the [SwiftAgent configuration schema](https://github.com/tadija/swift-agent/blob/0.1.0/Docs/Configuration.md).
Harnesses, Ollama, checks, permissions, limits, and prompt resolution are implemented
upstream. Existing `bsa.json` and global config files need no migration.

```sh
bsa init                 # Generate all built-in defaults; never overwrite
bsa config              # Inspect effective settings
bsa config --prompt     # Preview mission, contract, guidance, and history
```

## Product defaults

| Setting | BSA value |
| --- | --- |
| Repository config | `bsa.json` |
| Global config | `$XDG_CONFIG_HOME/bsa/config.json` (normally `~/.config/bsa/config.json`) |
| Data/history | `$XDG_DATA_HOME/bsa` (normally `~/.local/share/bsa`) |
| Branch | `bsa/<project>` |
| Commit identity | `Boy Scout Agent <boy-scout-agent@localhost>` |
| Commit subject | `bsa: <summary>` |
| Default mission | Embedded [PROMPT.md](../PROMPT.md) |
| Iterations / stop policy | 1 maximum; stop after 2 consecutive empty attempts or 3 failures |

CLI overrides repository config, which overrides global config and built-in
defaults. `bsa init` writes built-in defaults, independent of global settings.
[Example config](Examples/bsa.json) shows settings for a longer run.

## Project checks

Swift packages use `swift test`. For other projects configure checks explicitly:

```json
{
  "verification": ["python3 -m unittest discover -s tests"],
  "instructions": "Prioritize error handling in the CSV importer."
}
```

Baseline defaults to verification. Both phases use separate fresh worktrees;
include dependency setup in each phase that needs it. See upstream
[Swift, Rust, and TypeScript examples](https://github.com/tadija/swift-agent/blob/0.1.0/Docs/Configuration.md#baseline-and-verification).
Empty arrays explicitly skip project commands; Git and diff guards remain active.

## Mission overrides

```sh
bsa run --prompt ./missions/improve-docs.md
bsa run --instructions "Improve importer errors; preserve public APIs."
```

`--prompt` replaces the mission; `--instructions` adds separate project guidance.
For a persistent mission override set `"prompt": "missions/improve-docs.md"`.
Precedence is CLI, repository config, global config, then embedded Boy Scout mission.
CLI paths resolve from the invocation directory; configured paths resolve from
the original repository root. Repository `null` clears a global override.
Explicit invalid or blank files fail; mission overrides cannot disable engine guards.

## Agent and identity selection

```sh
bsa run --harness claude
bsa run --harness claude --yolo
bsa run --identity git
```

Persist Git identity with `"commitIdentity": "git"`. `--yolo` selects the chosen
harness's permissive mode. See upstream [permission mappings](https://github.com/tadija/swift-agent/blob/0.1.0/Docs/Configuration.md#permissive-harness-mode).

## Ollama

```sh
bsa run --harness ollama --ollama-host http://192.168.1.50:11434 --ollama-model my-coding-model
```

Use an installed model with tool support. No external agent CLI is required.
See upstream [Ollama configuration and security](https://github.com/tadija/swift-agent/blob/0.1.0/Docs/Configuration.md#ollama).
