# Stage 1 — Reliable Core

Implement **Stage 1 — Reliable Core** of Boy Scout Agent (BSA), using `boy-scout-agent-v1-specs.md` as the source of truth.

Establish a minimal, functional end-to-end workflow.

## Scope

- Create a Swift CLI targeting macOS and Linux.
- Discover and validate the Git repository.
- Isolate changes using Git worktrees and a dedicated BSA branch.
- Implement one iteration: inspect → discover → select → implement → verify → commit.
- Integrate Codex as the initial coding harness.
- Ensure each successful iteration produces exactly one coherent, atomic commit; failures and no-ops produce none.
- Support `bsa run`, `bsa status`, and CLI help, consistent with the spec.
- Make `bsa run` usable without configuration in a supported repository.
- Implement verification gates, error handling, and safe cleanup.
- Protect the user's working tree and uncommitted changes.
- Add automated tests for Git isolation, lifecycle outcomes, and failure paths.

## Constraints

- Minimal dependencies; prefer Swift concurrency where appropriate.
- Keep adapters and scheduling extensible without prematurely implementing them.
- Never commit changes that fail required verification.
- Never push automatically.
- No dashboard or advanced scheduling in this stage.
- Follow the specification where it is more precise than this prompt.

## Deliverables

1. Working single-iteration Swift CLI.
2. Tests for success, failure, and Git isolation.
3. README installation and usage instructions.
4. Updated `boy-scout-agent-v1-specs.md` reflecting actual decisions and justified deviations.
5. One or more logical development commits.

**Acceptance:** `bsa run` can identify, implement, verify, and commit one worthwhile improvement without modifying the user's working tree.
