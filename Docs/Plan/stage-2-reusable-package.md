# Stage 2 — Establish the reusable SwiftAgent package

Work in the existing boy-scout-agent repository after Stage 1. Inspect the actual Stage 1 implementation and updated specification. Preserve existing BSA behavior; do not move repositories yet.

## Objective
Make the generic repository-agent engine and CLI independently consumable SwiftPM library products, with BSA as a thin client. Validate the abstraction with a second mission and a generic CLI.

## Requirements
- Establish SwiftAgent (engine library) and SwiftAgentCLI (reusable CLI library) targets/products. Retain ProcessSupport or equivalent internal boundaries where useful. The engine must not depend on the CLI or BSA. Avoid exposing implementation details unnecessarily.
- Move reusable harness adapters, native model integration, process execution, Git worktree management, iteration lifecycle, verification, commits, scheduling, configuration, history and recovery into appropriate generic targets.
- Provide a small public API for programmatic execution and a reusable CLI entry point accepting an agent definition. Prefer Swift concurrency and minimal dependencies. Keep CLI argument parsing and process-exit behavior outside the engine.
- Reduce bsa to its identity, embedded PROMPT.md, defaults and a thin entry point. Preserve existing commands, flags, config, state paths, branch naming and installation behavior.
- Add a generic swift-agent executable using the same CLI library. Support swift-agent run --prompt PATH with existing count/time/harness options. Require an explicit mission for generic execution unless supplied by configuration; do not silently use the BSA mission. Use separate documented generic state/config defaults and avoid collisions with BSA.
- Validate with a small second mission (e.g. test coverage or documentation) using the public API or generic CLI. No separate production agent repository is needed. Demonstrate that a new agent requires only identity, Markdown mission and optional defaults, not new orchestration code.
- Keep the scope restricted to iterative Git repository agents. Preserve one coherent change and at most one verified commit per iteration, no-op handling and safety gates. Do not introduce arbitrary tools, multi-agent frameworks, hosted services or UI.

## Validation and deliverables
Test public API consumption, generic CLI prompt requirements, BSA compatibility, namespace isolation, and both missions using deterministic fake harnesses. Run existing regression tests and installation smoke tests. Validate macOS/Linux where possible and disclose gaps.
Document the public API, target dependency graph, generic CLI examples and embedding approach. Update README and specification. Make logical commits and report extraction readiness, remaining BSA-specific assumptions and any breaking changes. Do not proceed to Stage 3.
