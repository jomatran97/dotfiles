# Arbiter Engineering Doctrine

Status: active operating doctrine for this repository.

This document captures the engineering rules that keep Arbiter strict, inspectable, and resistant to agentic slop.

## Core principle

Convert agent behavior into governed state, structured artifacts, and inspectable interfaces.

If a workflow feature cannot be inspected, sorted, limited, replayed, and tested, it is not done.

## Authority boundaries

Arbiter keeps hard boundaries between orchestration layers.

- The checked-in registry decides the exact provider, agent, and model mapping.
- The workflow state machine decides phase truth.
- Repository gates decide pass/fail.
- Persisted artifacts provide evidence and handoff memory.
- Provider CLIs are execution backends, not sources of truth.

Do not weaken these boundaries with undocumented provider behavior, implicit model drift, or permissive fallbacks.

## Default build order

Every meaningful workflow feature should be built in this order:

1. Make it happen.
2. Persist the result.
3. Normalize the result.
4. Index or manifest the result when multiplicity exists.
5. Expose inspection through the CLI.
6. Add filtering, sorting, and limiting if the output is list-like.
7. Fail closed on ambiguous or unsafe behavior.
8. Add regression tests for success and failure paths.
9. Update documentation.
10. Advance real workflow state and refresh TODO/runtime artifacts.

## Contracts before prompts

Prompts are inputs, not truth.

Before adding any new agent-driven behavior, define:

- who decides truth,
- what artifact is persisted,
- what schema fields are guaranteed,
- how a user inspects the result,
- how the feature fails closed.

Prompt improvements are welcome, but a feature is not complete until its outputs land in a structured, inspectable contract.

## Machine-readable memory first

Prefer structured artifacts over prose or raw logs.

- Use JSON for persisted workflow memory.
- Include a schema version when the format matters downstream.
- Normalize fields that later phases or CLI commands must consume.
- Add a manifest or index when multiple artifacts can compete.
- Treat raw provider stdout as fallback input, not as the authoritative data model.

## Inspection is part of the feature

If a feature changes state, Arbiter should answer all of these without reading source code:

- what happened,
- why it happened,
- what artifact was selected,
- what artifacts were archived or ignored,
- what happens next,
- how to reproduce or inspect the current state.

That means new orchestration features should usually come with CLI inspection support.

## Public interface discipline

When changing code:

- preserve public contracts unless the repository explicitly migrates them,
- prefer additive metadata over breaking payload shape changes,
- keep documented CLI behavior stable,
- avoid optimistic capability reporting,
- prefer explicit errors over permissive guesses.

## Definition of done

A workflow/orchestration feature is done only when all of the following are true:

- implementation exists,
- persisted artifacts are written,
- schemas are normalized,
- inspection paths exist,
- failure paths are explicit,
- tests pass,
- docs match runtime behavior,
- TODO/workflow state reflects reality.

Passing tests alone is not sufficient.

## Anti-slop checklist

Before closing work, check:

- Is there a persisted artifact?
- Is the artifact machine-readable?
- Is there a stable schema?
- Is there a manifest/index if there are multiple candidates?
- Can a user inspect it from the CLI?
- Are filtering/sorting/limit controls needed?
- Does it fail closed?
- Are negative paths tested?
- Do docs match the actual runtime names and flags?
- Has the real workflow state been advanced if appropriate?

## Arbiter-specific heuristics

For this repository, prefer:

- registry-backed exact mappings,
- repository-aware prompts,
- structured phase handoffs,
- ranked artifact selection,
- archived low-value duplicates,
- manifest-backed downstream consumption,
- CLI-first observability,
- state-machine authority over provider output.

## One-line rule

Do not trust opaque agent behavior; trust gates, state, and artifacts.
