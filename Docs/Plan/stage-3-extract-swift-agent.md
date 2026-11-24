# Stage 3 — Extract SwiftAgent into an independent repository

Start from the completed Stage 2 boy-scout-agent repository. Inspect its current implementation, tests and documentation. This stage spans two repositories: swift-agent and boy-scout-agent.

## Objective
Extract the generic implementation into an independent Swift package and CLI, then make BSA consume it through SwiftPM. Preserve the existing BSA repository identity and user experience.

## Requirements
- Prepare a separate swift-agent repository (use an existing authorized checkout if available; otherwise create a local sibling repository). Do not rename or delete the BSA repository. Preserve relevant attribution, license notices and provenance; retain history where practical without exposing unrelated private material.
- Move SwiftAgent, SwiftAgentCLI, generic executable, shared process support, generic tests and required build/install tooling upstream. Keep the engine independently usable without BSA. Ensure no dependency cycle or duplicated orchestration implementation.
- Keep BSA-specific mission, identity, defaults, entry point, product documentation and integration tests in boy-scout-agent. Make it depend on SwiftAgent products via SwiftPM. Use a local dependency only during development; final distributable configuration should reference the actual upstream URL and an immutable release version or revision. Do not invent a release tag or remote.
- Preserve the self-contained executable installation for both products, including deterministic embedded Markdown generation. Preserve BSA configuration, state, branches, history, command behavior and existing installations where possible. Document any necessary migration.
- Provide generic CLI installation and usage examples, library integration examples and a minimal example of creating a specialized agent. Use the description: A harness-agnostic Swift framework for autonomous, iterative repository agents.
- Keep BSA's description and mission intact. Do not expand scope into a universal agent framework or commercial features.
- Establish clear ownership of tests and documentation. Upstream owns generic behavior; BSA owns mission-specific behavior and downstream compatibility.

## Validation and release sequencing
Run upstream tests and downstream BSA tests, including clean checkout/build, installation outside source trees, prompt overrides, generic mission execution and Git safety regression tests. Verify macOS/Linux where available. Use fake harnesses for deterministic tests; report any real-harness smoke tests separately.
Commit upstream first, then integrate downstream against the tested upstream revision. If publishing the new repository, pushing, tagging or changing remote settings requires authorization or is unavailable, stop at the relevant boundary and report exact next steps. Do not publish or push without explicit authorization. Do not claim the remote dependency works until it has actually been resolved and tested.
Update both READMEs and specifications to reflect the final architecture. Make logical commits in each repository. Report commit IDs, dependency reference, test results, remaining release steps and compatibility issues.

## Final acceptance criterion
A new specialized repository agent can be built using SwiftAgent with only a name, Markdown mission and optional configuration. BSA remains operational as a thin downstream product, and swift-agent can independently run arbitrary repository missions with the same execution guarantees.
