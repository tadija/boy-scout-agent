# Boy Scout Agent

> Leave your codebase a little better than you found it.

Boy Scout Agent (`bsa`) finds one worthwhile improvement, checks it, and gives
you a local Git commit to review. It favors small, high confidence changes over
speculative churn: correctness first, then reliability, warnings, maintainability,
consistency, documentation, and polish. No useful candidate is a valid outcome.

## Install

Requires Swift 6.4+, Git, and macOS or Linux. Install and authenticate Codex,
Claude Code, Pi, OpenCode, or Gemini; alternatively use
[Ollama](https://github.com/tadija/swift-agent/blob/0.2.0/Docs/Configuration.md#ollama).

```sh
git clone https://github.com/tadija/boy-scout-agent.git
cd boy-scout-agent
./install.sh
export PATH="$HOME/.local/bin:$PATH"
bsa --version
```

Install elsewhere with `./install.sh /path/to/bin`; legacy `--product bsa` is supported.
The executable embeds its mission and needs no source checkout or resource bundle.

Run `bsa update` from any directory to build GitHub `main`. Installation and updates
replace the binary atomically; failed updates preserve it. Updates need Swift,
network access and a writable installation directory. See upstream
[source updates](https://github.com/tadija/swift-agent/blob/0.2.0/Docs/SourceUpdates.md)
for supported locations and guarantees. Existing configuration, history and schedules
need no migration.

## Get started

In a trusted Git repository with at least one commit:

```sh
cd ~/Projects/my-app
bsa run
bsa status
git diff HEAD...bsa/my-app
```

Swift packages need no configuration: BSA uses `swift test`. For other projects,
put your checks in `bsa.json`, for example:

```json
{
  "verification": ["python3 -m unittest discover -s tests"]
}
```

BSA works in isolated worktrees and preserves your local edits. Accepted changes
become commits on `bsa/<project>`; review the branch printed by BSA and merge when
ready. Merging and pushing are yours by default. Agent tools and checks run with
your account's privileges; use trusted projects and commands.

## Everyday examples

```sh
# Focus the Boy Scout mission
bsa run --instructions "Improve CSV importer errors; preserve public APIs."

# Try up to five improvements with your preferred agent
bsa run --count 5 --harness claude

# Bound a longer session and inspect its results
bsa run --count 100 --duration 4h
bsa history
bsa stop

# Replace the mission with your own Markdown
bsa run --prompt ./missions/improve-docs.md
```

Run again to continue the same branch. Each iteration starts a fresh agent;
repeated empty attempts or failures stop a session early. Use `bsa config` for
settings, `bsa config --prompt` for the composed prompt, and `bsa --help` for commands.

BSA uses `bsa.json`, `~/.config/bsa/config.json`, and `~/.local/share/bsa`
(with standard XDG overrides). Its commit identity is
`Boy Scout Agent <boy-scout-agent@localhost>`; use `--identity git` for yours.
All other configuration and operational behavior comes from SwiftAgent:

- [Configuration](https://github.com/tadija/swift-agent/blob/0.2.0/Docs/Configuration.md): checks, harnesses, permissions, limits, and prompt overrides.
- [Operations](https://github.com/tadija/swift-agent/blob/0.2.0/Docs/Operations.md): schedules, recovery, history, and branch adoption.

Use `bsa` in place of `swift-agent` in upstream commands and paths.

## A specialized SwiftAgent application

[SwiftAgent](https://github.com/tadija/swift-agent) provides the mechanism;
BSA provides the [mission](Sources/bsa/prompt.md). Its
[agent.json](Sources/bsa/agent.json) declares metadata, commit identity and update source;
[main.swift](Sources/bsa/main.swift) assembles the product. Upstream handles embedding,
the CLI and source updates.

To create your own agent, change the declaration, mission and package/executable name.
See the upstream [product guide](https://github.com/tadija/swift-agent/blob/0.2.0/Docs/BuildTooling.md)
and [BSA specification](SPEC.md).

## Development

Build and verify against the released remote dependency:

```sh
swift build --product bsa
swift test --parallel --num-workers 4
./install.sh /tmp/bsa-bin
sh Tests/Integration/cli-smoke.sh /tmp/bsa-bin/bsa
sh Tests/Integration/source-update-smoke.sh
```

Tests cover product assembly, compatibility, installed operation and safe source
updates without live models or paid harnesses. Generic coverage belongs
[upstream](https://github.com/tadija/swift-agent/tree/0.2.0/Tests).
CI checks macOS and Linux and packages the executable, README and license.

Keep `Package.resolved` committed. For a release, update `version` in
`Sources/bsa/agent.json`, run the checks, then commit and tag. CI stamps the optional
`build` field with the source commit; unstamped builds report name and version.
Pushing and publication are separate steps.

---

`done for fun`
