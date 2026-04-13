---
name: audit-memory
description: >
  Use when asked to check memory, review stored learnings, clean up stale
  entries, or verify memory system integrity. Checks .learnings/ and .claude/ health.
allowed-tools: Read Grep Glob
model: sonnet
effort: low
# Skill Class: main-thread — inline reads, no agent dispatch
---

## /audit-memory — Memory Health Check

### Process
1. Read `.learnings/log.md` — stuck pending, duplicates, missing status, contradictions
2. Read `.learnings/agent-usage.log` — unused agents, high-frequency optimization candidates, missing entries
3. Read `CLAUDE.md` — over 120 lines?, stale conventions, missing sections
4. Read `.claude/rules/` — files >40 lines?, contradictions, dead references
5. Read `.claude/agents/` — missing frontmatter, missing tool restrictions, description mismatch
6. Check auto-memory (if accessible): `ls ~/.claude/projects/*/memory/` — stale entries, duplicates

### Report
```
Memory Health: {score}/100

.learnings/log.md: {N} entries ({pending}/{promoted}/{dismissed})
Agent usage: {N} tracked, {M} unused
CLAUDE.md: {lines} lines ({over/under} budget)
Rules: {N} files, {total_lines} total
Agents: {N} agents, valid frontmatter: {yes/no}

Issues:
- [{severity}] {description} — {recommended action}
```

### Anti-Hallucination
- Read files before reporting status — never estimate
- Cite line numbers only after reading the file
- Unsure → flag as INFO not ERROR
