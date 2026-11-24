# Boy Scout Agent

> "Leave your codebase a little better than you found it."

Boy Scout Agent (`bsa`) asks a coding agent to find one worthwhile improvement,
checks its work, and gives you a local Git commit to review.
Run it once or let it work through a few improvements.

## Install

Requires Swift 6+, Git, and macOS or Linux. Install and sign in to a supported
agent CLI: Codex, Claude Code, Pi, OpenCode, or Gemini.
You can also use [Ollama](Docs/Configuration.md#ollama) without an external agent CLI.

From a checkout of this repository:

```sh
./Scripts/install.sh
export PATH="$HOME/.local/bin:$PATH"
bsa --version
```

To update later, run `bsa update`. See [installation and updates](Docs/Installation.md)
for custom install paths, build metadata, and update behavior.

## Try it on your project

Open a trusted Git repository with at least one commit:

```sh
cd ~/Projects/my-app
bsa run
bsa status
```

Swift packages use `swift test` automatically. For other projects, create a
`bsa.json` with your checks. For example, in a Python project:

```json
{
  "verification": ["python3 -m unittest discover -s tests"]
}
```

Checks run before the agent starts and again in a fresh worktree for its proposed
change. Include dependency setup if your checks need it. See
[configuration examples](Docs/Configuration.md#project-checks) for
Swift, Rust, and TypeScript, or use `bsa init` to generate all defaults.

BSA works in a detached Git worktree, leaving your local edits in place.
Each accepted improvement becomes a commit on a local `bsa/<project>` branch.
Review and merge using the branch name BSA prints:

```sh
# Example for a project named my-app
git diff HEAD...bsa/my-app
git merge bsa/my-app
```

BSA leaves merging and pushing to you by default. Agent tools and check commands
run with your account's permissions, so use trusted repositories and commands.

## Everyday examples

Focus a run on a specific concern:

```sh
bsa run --instructions "Improve error messages in the CSV importer; preserve public APIs."
```

Try up to five improvements with your preferred agent:

```sh
bsa run --count 5 --harness claude
```

Give a longer run a time limit, then inspect its results:

```sh
bsa run --count 100 --duration 4h
bsa history
```

Use your configured Git identity and a named review branch:

```sh
bsa run --identity git --branch bsa/importer-cleanup
```

Replace the default [Boy Scout mission](PROMPT.md) with your own Markdown file:

```sh
bsa run --prompt ./missions/improve-docs.md --count 3
```

Run `bsa run` again to continue the same branch. Each iteration starts a fresh
agent with recent run history. BSA may stop early after repeated empty attempts
or failures. See [operations](Docs/Operations.md) for stopping runs, schedules,
and adopting existing branches with `--force`.

## Powered by SwiftAgent

BSA supplies the Boy Scout mission and product defaults. The independent
[SwiftAgent](https://github.com/tadija/swift-agent) package supplies the engine
and reusable CLI. Use it to run custom Markdown missions or build your own agent.
See [the architecture](Docs/SwiftAgent.md) for dependency and ownership details.

## Documentation

- [Installation and updates](Docs/Installation.md) — requirements, install paths, and versioning.
- [Configuration](Docs/Configuration.md) — checks, agents, Ollama, permissions, and missions.
- [Operations](Docs/Operations.md) — history, overnight runs, schedules, and recovery.
- [SwiftAgent](Docs/SwiftAgent.md) — upstream package and BSA architecture.
- [Testing](Docs/Tests.md) — core tests, integration tests, and CLI smoke tests.
- [Specification](Docs/Specs.md) — Boy Scout mission and product compatibility.

---

`done for fun`
