# Module 11 — Initialize Self-Improvement Log

> Create `.learnings/` directory with log.md and agent-usage.log.

---

## Idempotency

```
IF .learnings/ exists → PRESERVE all entries, don't overwrite
IF missing → CREATE with templates
```

## Create Directory

```bash
mkdir -p .learnings
```

## 1. Create `.learnings/log.md`

Only create if it doesn't exist:

```markdown
# Learnings Log

> Corrections, discoveries, and patterns. Managed by Self-Improvement triggers in CLAUDE.md.
> Run `/reflect` to promote pending entries to rules/CLAUDE.md.

## Format

Each entry:
```
### {date} — {category}: {summary}
Status: pending review | promoted ({destination}) | dismissed ({reason})

{Details of what was learned}
```

## Categories
- `correction` — User corrected Claude's approach
- `failure` — Command or tool failed, root cause identified
- `gotcha` — Non-obvious behavior discovered
- `agent-candidate` — Task pattern that would benefit from a dedicated agent
- `environment` — OS/tool/platform-specific discovery

---

{Entries will be added here by the Self-Improvement triggers}
```

## 2. Create `.learnings/agent-usage.log`

Only create if it doesn't exist:

```
# Agent Usage Log
# Appended by SubagentStop hook
# Format: timestamp | type=agent_type | id=agent_id
```

## Checkpoint

```
✅ Module 11 complete — .learnings/ initialized
```
