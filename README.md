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
