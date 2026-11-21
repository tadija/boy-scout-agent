# Stage 3 — Scheduling, Operations & Polish

Implement **Stage 3 — Scheduling, Operations & Polish** of Boy Scout Agent (BSA), completing `boy-scout-agent-v1-specs.md` on top of Stages 1 and 2.

## Scope

- Add time-bounded runs, including `bsa run --until HH:MM`.
- Add local recurring schedules and configurable execution windows.
- Support graceful cancellation and shutdown, including safe handling of an in-progress iteration.
- Provide status, run history, and useful operational logs.
- Prevent overlapping runs on the same repository or target branch.
- Recover safely from interruptions, stale locks, and abandoned worktrees.
- Respect iteration limits, execution timeouts, and optional cost budgets where harnesses expose usable cost data.
- Improve CLI diagnostics and ergonomics.
- Validate behavior on macOS and Linux.
- Document installation, harness configuration, schedules, troubleshooting, and limitations.
- Add integration tests for scheduling, interruption, recovery, and concurrency.

## Constraints

- Local-first and lightweight; no required server, Docker, or database service.
- Prefer native OS scheduling where appropriate.
- Never silently discard user changes or partial work.
- No automatic push unless explicitly configured.
- Preserve the one-improvement/one-commit, Git isolation, and verification guarantees.
- No web dashboard in v1.
- Follow the specification where it is more precise than this prompt.

## Deliverables

1. Scheduling and time-bounded execution.
2. Reliable operational controls, history, logging, and recovery.
3. Automated tests for unattended and failure scenarios.
4. Polished CLI help and README.
5. Updated `boy-scout-agent-v1-specs.md` documenting actual implementation.
6. Logical development commits.

**Acceptance:** BSA can run unattended overnight, make independently verified atomic improvements, respect configured limits, recover safely from interruptions, and report its work clearly.
