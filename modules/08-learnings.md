# Step 11 — Initialize .learnings/

> Mode C: if `.learnings/` exists, preserve contents.

Create the structured learning log directory for explicit, auditable improvement tracking.

## Files to Create

### .learnings/log.md

```markdown
# Learning Log

<!-- Format: date | trigger | context | correction | status -->
<!-- Status: pending review | promoted (moved to CLAUDE.md or rules) -->
```

### .learnings/agent-usage.log

```markdown
# Agent Usage Log

<!-- Populated by SubagentStop hook (track-agent.sh) -->
<!-- Format: timestamp | agent | task_summary | outcome | duration -->
```

## Log Entry Format

Each entry in `log.md` follows:

```
## YYYY-MM-DD — {brief title}
- **Trigger**: {user correction | gotcha discovered | env issue | agent candidate}
- **Context**: {what happened}
- **Correction**: {what should be done differently}
- **Status**: pending review
```

### Example Entries

```
## 2025-07-15 — Prefer named exports
- **Trigger**: user correction
- **Context**: Used default export in utility module
- **Correction**: This project uses named exports exclusively. Update code-standards.md.
- **Status**: promoted

## 2025-07-15 — Docker compose v2 syntax
- **Trigger**: gotcha discovered
- **Context**: `docker-compose` failed; system uses `docker compose` (v2, no hyphen)
- **Correction**: Always use `docker compose` (space, not hyphen) in this environment.
- **Status**: pending review

## 2025-07-16 — Node 18 required for tests
- **Trigger**: env issue
- **Context**: Test suite fails on Node 16 due to structuredClone usage
- **Correction**: Add Node >=18 check to detect-env.sh
- **Status**: pending review

## 2025-07-16 — Frequent manual test writing
- **Trigger**: agent candidate
- **Context**: User repeatedly asks for test files — good fit for test-writer agent
- **Correction**: Create test-writer.md agent if pattern continues
- **Status**: pending review
```

## Relationship to Auto Memory

Claude Code has two learning systems — they complement each other:

| System | Storage | Control | Use Case |
|--------|---------|---------|----------|
| **Auto Memory** | `~/.claude/projects/<project>/memory/MEMORY.md` | Automatic, opaque | Session-to-session recall |
| **.learnings/** | `.learnings/log.md` | Explicit, auditable | Deliberate improvement via `/reflect` |

- **Auto Memory** (enabled via `autoMemoryEnabled` setting) automatically captures patterns across sessions
- **.learnings/** provides structured, reviewable entries that `/reflect` processes into CLAUDE.md or rule updates
- To disable Auto Memory: set `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`

## Wiring Check

Verify:
1. `.learnings/log.md` exists with correct header/format
2. `.learnings/agent-usage.log` exists
3. CLAUDE.md Self-Improvement section references `.learnings/log.md`

**Checkpoint**: `.learnings/` directory initialized. Log files created with correct format. CLAUDE.md references confirmed.
