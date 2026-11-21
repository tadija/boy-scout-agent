# Stage 2 — Autonomy & Intelligence

Implement **Stage 2 — Autonomy & Intelligence** of Boy Scout Agent (BSA), using `boy-scout-agent-v1-specs.md` as the source of truth and building on completed Stage 1.

## Scope

- Implement `bsa run --count N` for repeated independent iterations.
- Start each iteration with fresh harness context, while preserving useful run history.
- Add built-in adapters for Claude Code, Pi, and OpenCode alongside Codex.
- Support configurable custom harness commands.
- Implement harness selection by CLI flag and configuration.
- Add default improvement priorities and Boy Scout rules.
- Support optional repository configuration through `bsa.json`, preserving existing configurations without adding a parser dependency.
- Prioritize high-value changes while using controlled exploration to cover neglected areas.
- Select one coherent, appropriately scoped improvement per iteration.
- Persist success, failure, rejection, and no-op outcomes.
- Supply recent failed tasks and diagnostics to the planner so it can avoid unchanged failures. Enforce a consecutive failure limit independently of planner behavior.
- Detect saturation and stop rather than inventing changes.
- Stop correctly at iteration limits and unrecoverable errors.
- Test configuration, adapters, iteration boundaries, and stopping conditions.

## Constraints

- Exactly one verified commit per successful iteration; zero for unsuccessful iterations.
- Do not reuse a single long-running agent conversation for the entire loop.
- Keep Git isolation and verification for every iteration.
- Keep the orchestrator language-agnostic and harness details encapsulated.
- Preserve zero-config usage.
- Follow the specification where it is more precise than this prompt.

## Deliverables

1. Multi-iteration autonomous improvement loop.
2. Built-in and custom harness support.
3. Configurable rules and defaults.
4. Persistent run history and saturation handling.
5. Tests, README, and example configuration.
6. Updated `boy-scout-agent-v1-specs.md` reflecting implementation.
7. Logical development commits.

**Acceptance:** `bsa run --count 100` can perform up to 100 fresh iterations, each producing at most one verified commit, and stop appropriately based on history, limits, and saturation.

Candidate discovery, selection, and self-review share the fresh agent invocation. The fixed priority order and repository instructions guide selection. Git guards and project verification determine whether a commit can be published.
