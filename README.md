# Boy Scout Agent

> "Leave your codebase a little better than you found it."  

Boy Scout Agent (`bsa`) asks a coding agent to find one worthwhile improvement, checks its work, and gives you a local Git commit to review. You can run it once or give it a few more turns.

## Install

Build with Swift 6 or later on macOS or Linux. Install Git and, for external harnesses, install and sign in to your chosen coding agent CLI. BSA looks for Codex, Claude Code, Pi, OpenCode, Gemini. It also includes a standalone [Ollama agent](Docs/Configuration.md#ollama) for inference through your Ollama server; no external agent CLI is needed for Ollama.

```sh
./Scripts/install.sh
export PATH="$HOME/.local/bin:$PATH"
bsa --version
```

To install into a different directory, run `./Scripts/install.sh /path/to/bin`.
The script builds a release executable and replaces any existing BSA installation
only after a successful build.

Update an installed BSA from any directory:

```sh
bsa update
```

This downloads the latest `main` source from `https://github.com/tadija/boy-scout-agent`,
builds it with your local Swift toolchain, and replaces the executable you invoked
(resolving symlinks). Git, Swift 6 or later, network access, and write access to the
installation directory are required. This installs the current development branch,
which may report the same version as your existing installation. A failed build
leaves your installed executable intact. Local source checkouts are unaffected.
You can also update your checkout and rerun `./Scripts/install.sh`.

## Run on any project

Open a trusted repository with at least one commit. Swift packages use `swift test` automatically. For other projects, configure verification commands or explicitly set `verification` to `[]` to skip project checks. Run `bsa init` to generate `bsa.json` with all built-in defaults, then edit it for your project. See [repository configuration](Docs/Configuration.md) for Swift, Rust, and TypeScript baseline/verification examples.

```sh
bsa run
bsa status
```

BSA starts from your current commit, runs the baseline checks and gives the agent a detached worktree. Your local edits stay in your checkout. BSA inspects the diff and runs verification again against the proposed contents in a fresh worktree. Each accepted improvement adds one commit to the local BSA branch. You decide what to merge or push (use the branch name printed by BSA in these commands).

```sh
git diff HEAD...bsa/my-project
git merge bsa/my-project
```

## Run options

To continue from an existing target branch, explicitly adopt it with `--force`. BSA adds improvements on top of its current tip, preserving existing commits. The target must be unchecked out. See [branch recovery](Docs/Operations.md) for details.

```sh
bsa run --branch bsa/my-improvements --force
```

Commits use `Boy Scout Agent <boy-scout-agent@localhost>` by default. Choose your configured Git identity or a custom one:

```sh
bsa run --identity git
bsa run --identity "Name <email>"
```

Save the preference as `commitIdentity` in [BSA configuration](Docs/Configuration.md).

For a longer run, set an iteration limit and optionally choose the agent.

```sh
bsa run --count 10 --harness claude
bsa run --harness claude --yolo
bsa run --harness gemini --yolo
bsa run --harness ollama --ollama-host http://192.168.1.50:11434 --ollama-model my-coding-model
bsa run --instructions "Focus on error handling; preserve public APIs."
bsa run --count 5 --harness codex --branch bsa/polish
bsa run --count 100 --duration 4h
```

`--yolo` selects the harness's permissive execution mode. See [harness permissions](Docs/Configuration.md#permissive-harness-mode) for each agent's behavior; BSA's Git and verification guards still apply.

BSA reports the current phase on stderr and prints total and per-phase timings after each iteration. `bsa status` also shows the active phase. Timings include baseline checks, harness work, and independent verification; by default, checks run twice, and fresh worktrees may require fresh builds. Configure `baseline` and `verification` separately, or set either to `[]` to skip its commands. For one run, use `--skip-checks` to skip both phases.

BSA starts each iteration with a fresh agent and recent run history. Run it again to continue improving the same branch.

## Documentation

- [Repository configuration](Docs/Configuration.md) covers verification commands, harness selection, protected paths, and run limits.
- [Operations guide](Docs/Operations.md) covers overnight runs, recurring schedules, history, and recovery.
- [Testing guide](Docs/Tests.md) covers core tests, external integration tests, and CLI smoke tests.
- [Specification](Docs/Specs.md) describes the iteration lifecycle, verification contract, and three development prompts.

---

`done for fun`
