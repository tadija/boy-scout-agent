# Boy Scout Agent

> Leave your codebase a little better than you found it.

Boy Scout Agent (`bsa`) finds a worthwhile improvement, checks it, and creates
a local Git commit to review. It favors small, high confidence changes:
correctness first, then reliability, warnings, maintainability, consistency,
documentation, and polish. No useful candidate is a valid outcome.

## Install

Requires Swift, Git, and macOS or Linux. Install and authenticate Codex,
Claude Code, Pi, OpenCode, or Gemini; alternatively use
[Ollama](https://github.com/tadija/swift-agent/blob/0.2.0/Docs/Configuration.md#ollama).

```sh
git clone https://github.com/tadija/boy-scout-agent.git
cd boy-scout-agent
swift build -c release
mkdir -p "$HOME/.local/bin"
cp .build/release/bsa "$HOME/.local/bin/"
export PATH="$HOME/.local/bin:$PATH"
bsa --version
```

Or install with a temporary checkout that is removed afterward:

```sh
(src=$(mktemp -d) && trap 'rm -rf "$src"' EXIT && git clone --depth 1 https://github.com/tadija/boy-scout-agent.git "$src" && swift build --package-path "$src" -c release && mkdir -p ~/.local/bin && cp "$src/.build/release/bsa" ~/.local/bin/)
```

Requires Swift and Git; ensure `~/.local/bin` is on your `PATH`.

The installed executable needs no source checkout or resource bundle.

Run `bsa update` from any directory to build GitHub `main`. Updates need Swift,
network access, and a writable installation directory. See
[source updates](https://github.com/tadija/swift-agent/blob/0.2.0/Docs/SourceUpdates.md)
for supported locations and guarantees.

## Get started

In a trusted Git repository with at least one commit:

```sh
cd ~/Projects/my-app

bsa run
bsa status

git diff HEAD...bsa/my-app
git merge bsa/my-app
```

Swift packages need no configuration: BSA uses `swift test`. For other projects,
put your checks in `bsa.json`, for example:

```json
{
  "verification": ["python3 -m unittest discover -s tests"]
}
```

BSA uses isolated worktrees to preserve your local edits and commits accepted
changes to `bsa/<project>`. Review the printed branch, then merge and push when
ready. Agent tools and checks use your account's privileges; use trusted projects
and commands.

## Everyday examples

```sh
# Focus the Boy Scout mission
bsa run --instructions "Improve CSV importer errors; preserve public APIs."

# Try up to five improvements with your preferred agent
bsa run --count 5 --harness claude

# Prepare a nightly midnight run with a four-hour limit
bsa schedule add --at 00:00 --duration 4h
bsa schedule list

# Review results in the morning, or stop an active session
bsa history
bsa stop

# Replace the mission with your own Markdown
bsa run --prompt ./missions/improve-docs.md
```

Schedules use local time and require activation with launchd (macOS) or systemd
(Linux); see [schedule setup](https://github.com/tadija/swift-agent/blob/0.2.0/Docs/Operations.md#recurring-schedules).
Set `"maxIterations": 100` in `bsa.json` for repeated improvements within the window;
the default is one iteration. The four-hour limit may end early if no useful work remains.

Run again to continue the same branch. Each iteration starts a fresh agent;
repeated empty attempts or failures stop a session early. Use `bsa config` for
settings, `bsa config --prompt` for the composed prompt, and `bsa --help` for commands.

BSA uses `bsa.json`, `~/.config/bsa/config.json`, and `~/.local/share/bsa`
(with standard XDG overrides). Its commit identity is
`Boy Scout Agent <boy-scout-agent@localhost>`; use `--identity git` for yours.
See SwiftAgent for further details:

- [Configuration](https://github.com/tadija/swift-agent/blob/0.2.0/Docs/Configuration.md): checks, harnesses, permissions, limits, and prompt overrides.
- [Operations](https://github.com/tadija/swift-agent/blob/0.2.0/Docs/Operations.md): schedules, recovery, history, and branch adoption.

Use `bsa` in place of `swift-agent` in upstream commands and paths.

## A specialized SwiftAgent application

[SwiftAgent](https://github.com/tadija/swift-agent) handles embedding, the CLI,
and source updates. BSA supplies the [mission](Sources/bsa/prompt.md),
[product declaration](Sources/bsa/agent.json) (metadata, commit identity, and update
source), and [entry point](Sources/bsa/main.swift).

To create your own agent, change the declaration, mission and package/executable name.
See the upstream [product guide](https://github.com/tadija/swift-agent/blob/0.2.0/Docs/BuildTooling.md)
and [BSA specification](SPEC.md).

## Development

Build and verify:

```sh
swift build --product bsa
swift test --parallel --num-workers 4
swift build -c release
mkdir -p /tmp/bsa-bin
cp .build/release/bsa /tmp/bsa-bin/
sh Tests/Integration/cli-smoke.sh /tmp/bsa-bin/bsa
sh Tests/Integration/source-update-smoke.sh
```

---

`done for fun`
