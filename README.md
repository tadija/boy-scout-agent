# Boy Scout Agent

Leave your codebase a little better than you found it. Boy Scout Agent (`bsa`) is a command-line tool that asks Codex to find and make one worthwhile improvement in a Git repository. Each successful run gives you one local commit to review.

## Install

You’ll need Git, Swift, and the Codex CLI on macOS or Linux. From a clone of this repository, build and install the executable:

```sh
swift build -c release
mkdir -p ~/.local/bin
cp .build/release/bsa ~/.local/bin/bsa
export PATH="$HOME/.local/bin:$PATH"
```

If you haven’t signed in to Codex yet, run `codex login`.

## Run it on a project

Open a repository you trust, with at least one commit and your Git author name and email configured. Swift packages use `swift test` automatically. For other projects, set up the checks below first.

```sh
bsa run
bsa status
```

BSA starts from your current commit and runs the project checks to get a baseline. Codex works in a separate Git worktree, so you can keep your local edits. BSA inspects the proposed diff and runs the checks again in a fresh worktree. If the change passes, BSA commits it on a local branch. If verification fails or Codex finds nothing worth changing, the run produces no branch commit.

The output shows the branch name. For a project named `my-project`, review the changes from your development branch with:

```sh
git diff HEAD...bsa/my-project
```

You decide what to merge or push. Running `bsa run` again continues on the BSA branch. If your development branch has diverged, choose a fresh target with `bsa run --branch bsa/next-improvement`.

## Set up project checks

Create a `bsa.json` at the root of your project and list the commands that should pass before you would accept a change. For example, a Python project with tests in a `tests/` directory might use:

```json
{
  "verification": ["python3 -m unittest discover -s tests"]
}
```

Commands run in order in each fresh checkout. Include any setup they need, and use commands you trust to execute on your machine.

### Stage 2 autonomy

`bsa run --count 100` runs up to 100 fresh iterations. Stops after two consecutive
empty attempts, three consecutive failures, cancellation or timeout. Each attempt
retains the Stage 1 isolated verification and atomic publication contract.

Select `--harness codex|claude|pi|opencode|custom`; automatic discovery uses that
order (excluding custom). Authenticate the chosen CLI first. Claude uses print mode
with acceptEdits; commands still require permissions configured in that CLI.
Pi and OpenCode run in print/run mode without resuming conversations.
These harnesses can execute repository code: use a trusted environment.

Configuration remains dependency-free `bsa.json`. Additional optional keys:
`harness`, `customCommand` (argument array with `{prompt}` and optional `{cwd}`),
`instructions`, `maxIterations`, `failureLimit`, `saturationLimit`.
CLI flags override repository settings. Instructions extend mandatory safety rules.
Recent ten outcomes and touched paths guide bounded candidate selection and exploration.
Failure avoidance is prompt guidance, not a deterministic semantic deduplication system.
Global configuration and YAML parsing remain deferred.
