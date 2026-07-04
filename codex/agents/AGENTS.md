# Codex agents

Registry-backed Codex agents:
- implement
- build
- debug
- verify

## Usage
- Use these files as the authoritative Codex-side role prompts.
- Invoke them through Arbiter registry-backed flows such as `hcom send` or `run --agent ...`.
- Keep provider/model mappings aligned with `arbiter/agent-registry.json`.

## Constraints
- Do not add a prompt file that redefines a registered agent name with a different provider or model.
- Keep safety defaults and verification expectations consistent with Arbiter policy.
