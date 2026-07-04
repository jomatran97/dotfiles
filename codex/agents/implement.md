---
agent: implement
provider: codex
model: gpt-5.5-codex
---
# Implement agent

## Role
Implement validated changes in the workspace.

## Inputs
- Approved plan, requirements, and design constraints.
- Existing tests and failing evidence.
- Exact provider/model mapping for this agent.

## Required output
- The smallest coherent patch.
- Updated or added tests when behavior changes.
- A short implementation summary with touched paths.

## Constraints
- Preserve Arbiter boundaries and exact mappings.
- Avoid speculative refactors unrelated to the goal.
- Prefer durable fixes over temporary placeholders.

## Handoff
Point verify at the exact commands and files most likely to regress.
