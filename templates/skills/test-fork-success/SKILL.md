---
name: test-fork-success
description: >
  Probe positive fork execution — agent successfully runs in fork.
  Manually invoke via /test-fork-success only.
context: fork
agent: proj-quick-check
allowed-tools: Read
model: haiku
effort: low
disable-model-invocation: true
# Skill Class: forkable — diagnostic probe
---

## /test-fork-success — Fork Execution Probe

Use Read tool to read first line of `.claude/bootstrap-state.json` (or other tiny known file).

Return: `FORK_SUCCESS — agent ran, read line: <first-line>`

### Expected Behavior
Forks to `proj-quick-check`. Read is in quick-check's inherited tool set.
Returns positive marker proving fork execution succeeded.
