# Migration: Foreground-Only Agents

> Add foreground-only agent rule to general rules and CLAUDE.md behavior section

---

```yaml
# --- Migration Metadata ---
id: "019"
name: "Foreground-Only Agents"
description: >
  Background agents (run_in_background=true) silently block on permission-gated tools.
  Adds explicit rule to general.md and CLAUDE.md to never use background agents.
  Parallel foreground dispatch (multiple Agent calls in one message) gives same concurrency safely.
base_commit: "d08718907ebbb5b88585d261a6dc153cdaa13927"
date: "2026-04-01"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| modify | `.claude/rules/general.md` | Add foreground-only agent rule to Process section |
| modify | `CLAUDE.md` | Add foreground-only agent rule to Behavior section |

---

## Actions

### Step 1 — Update general rules

Read `.claude/rules/general.md`. In the `## Process` section, after the line about dispatching agents, add:

```
- **Never use background agents** (`run_in_background: true`). Permission-gated tools block silently. Parallel foreground agents (multiple Agent calls in one message) give same concurrency safely
```

### Step 2 — Update CLAUDE.md

Read `CLAUDE.md`. In the `## Behavior` section, after the "Collaborator not executor" line, add:

```
- Never background agents (`run_in_background`). Parallel foreground (multiple Agent calls, one message) = safe concurrency
```

### Step 3 — Sync technique reference

Fetch the updated `techniques/agent-design.md` which already contains the Foreground-Only Dispatch section:

```bash
gh api repos/tomasfil/claude-bootstrap/contents/techniques/agent-design.md --jq '.content' | base64 -d > .claude/references/techniques/agent-design.md
```

### Step 4 — Wire + sync

1. Verify cross-references: `.claude/rules/general.md` and `CLAUDE.md` exist
2. Verify `techniques/agent-design.md` § Foreground-Only Dispatch section exists in reference copy

---

## Verify

- [ ] `.claude/rules/general.md` contains "Never use background agents"
- [ ] `CLAUDE.md` contains "Never background agents"
- [ ] `.claude/references/techniques/agent-design.md` contains "Foreground-Only" section
- [ ] No broken cross-references

---

Migration complete: `019` — foreground-only agent rule in rules + CLAUDE.md
