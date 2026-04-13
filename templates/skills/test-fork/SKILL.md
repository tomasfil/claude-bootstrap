---
name: test-fork
description: >
  Probe whether `context: fork` + `agent:` dispatches to a named custom agent.
  Manually invoke via /test-fork only — never auto-invoke. Diagnostic skill.
context: fork
agent: proj-quick-check
allowed-tools: Bash
model: haiku
effort: low
disable-model-invocation: true
# Skill Class: forkable — diagnostic probe
---

## /test-fork — Fork Dispatch Probe

Single section; one Bash command:

```bash
echo "FORK_PROBE pid=$$ ppid=$PPID time=$(date +%s)"
```

Return output verbatim. Do NOTHING else.

### Expected Behavior
Forks to `proj-quick-check`. Quick-check has `tools:` OMIT (read-only inheritance — no Bash).
Skill body requests Bash → fork dispatches → quick-check refuses ("Bash tool not available").
Refusal IS the success signal: proves fork happened to restricted agent context.
