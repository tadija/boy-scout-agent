# Boy Scout Agent

Leave your codebase a little better than you found it. Boy Scout Agent (`bsa`) asks an installed coding agent to find one worthwhile improvement, checks its work, and gives you a local Git commit to review. You can run it once or give it a few more turns.

## Install

Build with Swift 6 or later on macOS or Linux. Install Git and sign in to at least one supported coding agent CLI. BSA looks for Codex, Claude Code, Pi, then OpenCode, in that order.

```sh
swift build -c release
mkdir -p ~/.local/bin
cp .build/release/bsa ~/.local/bin/bsa
export PATH="$HOME/.local/bin:$PATH"
bsa --version
```

## Improve a project

Open a trusted repository with at least one commit and a configured Git author. Swift packages use `swift test` automatically. For other projects, configure a verification command before your first run. See [repository configuration](Docs/Configuration.md).

```sh
bsa run
bsa status
git diff HEAD...bsa/my-project
```

Use the branch name printed by BSA in the diff command. BSA starts from your current commit, runs the baseline checks and gives the agent a detached worktree. Your local edits stay in your checkout. BSA inspects the diff and runs verification again against the proposed contents in a fresh worktree. Each accepted improvement adds one commit to the local BSA branch. You decide what to merge or push.

For a longer run, set an iteration limit and optionally choose the agent.

```sh
bsa run --count 10 --harness claude
```

BSA reports the current phase on stderr and prints total and per-phase timings after each iteration. `bsa status` also shows the active phase. Timings include baseline checks, harness work, and independent verification; checks run twice, and fresh worktrees may require fresh builds.

BSA starts each iteration with a fresh agent and recent run history. Run it again to continue improving the same branch.

## Tests

Run the core suite with `swift test`. External integration tests are skipped by default so routine BSA iterations avoid compiling a separate Swift fixture package. Isolation, cancellation, verification, and publication checks stay in the core suite.

Before a release, run the external integration suite and CLI smoke test too:

```sh
BSA_INTEGRATION_TESTS=1 swift test --filter ExternalIntegrationTests
swift build -c release
sh Tests/Integration/cli-smoke.sh "$(swift build -c release --show-bin-path)/bsa"
```

CI runs all three suites on macOS and Linux. External integration tests cover a real Swift package with a failing baseline that the harness fixes, and the Codex adapter using a fake executable; they never call a real model. Use `BSA_INTEGRATION_TESTS=1 swift test` to run both Swift suites together.

## Documentation

- [Repository configuration](Docs/Configuration.md) covers verification commands, harness selection, protected paths, and run limits.
- [Operations guide](Docs/Operations.md) covers overnight runs, recurring schedules, history, and recovery.
- [Specification](Docs/Specs.md) describes the iteration lifecycle, verification contract, and three development prompts.

---

`done for fun`
