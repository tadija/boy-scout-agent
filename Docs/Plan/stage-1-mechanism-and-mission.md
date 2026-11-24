# Stage 1 — Separate mechanism from mission

Work in the existing boy-scout-agent repository. Inspect the actual implementation, tests, installation scripts and specification before changing anything. Treat existing behavior as the compatibility baseline. This is a refactoring, not a rewrite.

## Objective
Separate the Boy Scout mission from the generic repository-agent execution mechanism, without extracting a separate repository yet.

## Requirements
- Extract the Boy Scout-specific instructions from Harness.swift and any other relevant locations into a canonical PROMPT.md. Preserve their meaning and existing defaults.
- Embed the default Markdown at build time so the installed executable remains self-contained and requires no resource bundle or source checkout. Use a deterministic SwiftPM-compatible generation approach, with correct rebuild dependencies and tests for prompt fidelity. Avoid unnecessary dependencies.
- Separate prompt composition into engine-owned execution contract, mission Markdown, and per-iteration runtime context. Keep mandatory protocol instructions independent of mission overrides. Enforce actual safety invariants in code, not just prompts.
- Support a runtime prompt override via --prompt PATH and the existing repository configuration format. Resolve CLI override > repository configuration > embedded default. Resolve relative paths against documented bases; fail clearly for missing, unreadable or empty explicit prompts. Preserve existing custom instructions as a separate concept.
- Introduce a small typed agent definition for identity, executable name, mission and relevant defaults (including branch/state namespaces where applicable). Preserve existing BSA defaults and compatibility.
- Move Boy Scout-specific priorities, terminology and saturation policy out of generic orchestration where appropriate. Preserve generic no-op and stop semantics. Do not add a universal agent framework.
- Keep harness adapters, including native model integrations, independent of mission-specific wording. Ensure all supported harnesses receive the same composed contract and mission where applicable.
- Preserve Git isolation, verification, commit ownership, scheduling, history, cancellation, configuration and installation behavior. Do not rename the repository or public executable yet.

## Validation and deliverables
Add tests for prompt precedence, embedding, composition, identity defaults, invalid overrides and existing behavior. Run the full available test suite and verify the installed executable works outside the checkout without resource files. Validate macOS/Linux where available; report untested platforms honestly.
Update README and existing specification to reflect the implemented architecture. Make logical commits. Report changed boundaries, test results, compatibility concerns and remaining work for Stage 2. Do not proceed to Stage 2.
