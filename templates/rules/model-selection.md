# Model Selection Policy

Machine-readable source of truth for agent and skill model/effort expectations.
Read by `/audit-model-usage` skill. Human-editable; keep tables aligned with
techniques/agent-design.md.

## Agent Classification Table

| Name pattern | Expected model | Expected effort | Class |
|---|---|---|---|
| proj-code-writer-* | opus | high | GENERATES_CODE |
| proj-test-writer-* | opus | high | GENERATES_CODE |
| proj-tdd-runner | opus | high | GENERATES_CODE |
| proj-debugger | sonnet | high | SUBTLE_ERROR_RISK |
| proj-code-reviewer | sonnet | high | SUBTLE_ERROR_RISK |
| proj-reflector | opus | high | STATEFUL_MEMORY |
| proj-researcher | sonnet | high | MULTI_STEP_SYNTHESIS |
| proj-plan-writer | sonnet | high | MULTI_STEP_SYNTHESIS |
| proj-consistency-checker | sonnet | medium | SUBTLE_ERROR_RISK |
| proj-verifier | sonnet | medium | SUBTLE_ERROR_RISK |
| proj-quick-check | sonnet | medium | SUBTLE_ERROR_RISK |

Note: proj-reflector is currently classified as STATEFUL_MEMORY at opus+high. A follow-up deep-think session (proposal 2.3-R) is planned to reassess whether proj-reflector should be reclassified as ANALYZES (sonnet). That follow-up is tracked separately and does not affect the current COMPLIANT state of the agent against this table.

## Skill Classification Table

| # Skill Class: value | Expected model | Expected effort |
|---|---|---|
| main-thread — multi-dispatch orchestrator | opus | high |
| main-thread — single-dispatch (thin shell) | opus | high |
| main-thread — inline generator (consequential) | sonnet | medium |
| main-thread — inline executor (irreversible) | sonnet | high |
| main-thread — inline reads (low consequence) | sonnet | low |
| forkable — bounded autonomous task | sonnet | medium |
| forkable — diagnostic probe | haiku | low |
