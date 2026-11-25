# Boy Scout Agent

> Leave your codebase a little better than you found it.

Boy Scout Agent (`bsa`) finds one worthwhile improvement, checks it, and gives
you a local Git commit to review. It favors small, high confidence changes over
speculative churn: correctness first, then reliability, warnings, maintainability,
consistency, documentation, and polish. No useful candidate is a valid outcome.

## Install

Requires Swift 6+, Git, and macOS or Linux. Install and authenticate Codex,
Claude Code, Pi, OpenCode, or Gemini; alternatively use
[Ollama](https://github.com/tadija/swift-agent/blob/0.1.0/Docs/Configuration.md#ollama).

```sh
git clone https://github.com/tadija/boy-scout-agent.git
cd boy-scout-agent
./Scripts/install.sh
export PATH="$HOME/.local/bin:$PATH"
bsa --version
```

Pass a destination to install elsewhere: `./Scripts/install.sh /path/to/bin`.
The installed executable embeds its mission and needs no source checkout.
Update from any directory with `bsa update`, which builds the latest GitHub `main`.
See [installation and updates](Docs/Installation.md).

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

Run again to continue the same review branch. Each iteration starts a fresh agent;
repeated empty attempts or failures stop a session early. `bsa config` shows effective
settings, `bsa config --prompt` previews the composed prompt, and `bsa --help`
lists all commands.

BSA uses `bsa.json`, `~/.config/bsa/config.json`, and `~/.local/share/bsa`
(with standard XDG overrides). Its commit identity is
`Boy Scout Agent <boy-scout-agent@localhost>`; use `--identity git` for yours.
All other configuration and operational behavior comes from SwiftAgent:

- [Configuration](https://github.com/tadija/swift-agent/blob/0.1.0/Docs/Configuration.md): checks, harnesses, permissions, limits, and prompt overrides.
- [Operations](https://github.com/tadija/swift-agent/blob/0.1.0/Docs/Operations.md): schedules, recovery, history, and branch adoption.

Use `bsa` in place of `swift-agent` in upstream commands and paths.

## A specialized SwiftAgent application

[SwiftAgent](https://github.com/tadija/swift-agent) provides the mechanism;
BSA provides the [mission](PROMPT.md). The entire product definition and shared
CLI invocation live in [BoyScoutAgent.swift](Sources/bsa/BoyScoutAgent.swift), using the versioned
remote dependency in [Package.swift](Package.swift).

To create your own agent, change the name, executable name, Markdown mission,
and any intentional defaults. No engine changes or wrappers are required.
BSA explicitly retains its historical commit email; its namespaces and stop policy
use upstream defaults. Mission embedding, build metadata, and the updater support
independent BSA distribution. See the upstream
[API guide](https://github.com/tadija/swift-agent/blob/0.1.0/Docs/API.md),
[BSA specification](Docs/Specs.md), and [development guide](Docs/Development.md).
