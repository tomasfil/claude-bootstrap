# Module 06 — Create Audit Skills

> Create /audit-file and /audit-memory skills for code quality and memory health checks.

---

## Idempotency

Per skill: READ existing, EXTRACT project-specific content, REGENERATE with current template + extracted knowledge. Create if missing. Delete if obsolete/superseded.

## Create Directories

```bash
mkdir -p .claude/skills/audit-file .claude/skills/audit-memory
```

## 1. /audit-file Skill

Write `.claude/skills/audit-file/SKILL.md`:

```yaml
---
name: audit-file
description: >
  Audit a source file against project code standards. Use when asked to review,
  audit, or check a specific file for quality, conventions, or issues. Reports
  violations with line numbers, severity, and fixes.
---
```

```markdown
## /audit-file — Source File Audit

### Input
The user specifies a file path to audit. If no path given, ask for one.

### Process

1. **Read the file** in full
2. **Determine language** from file extension
3. **Read the matching code standards** from `.claude/rules/code-standards-{lang}.md`
4. **Read data access rules** from `.claude/rules/data-access.md` (if file touches data layer)
5. **Use LSP** (if available) to check for type errors, undefined references
6. **Scan for violations** against all applicable rules

### Report Format

For each issue found:
```
[{SEVERITY}] Line {N}: {rule_name}
  Code: `{snippet}`
  Issue: {what's wrong}
  Fix: {how to fix}
```

Severity levels:
- 🔴 **ERROR** — Must fix. Violates a hard rule (security, correctness, data access pattern)
- 🟡 **WARNING** — Should fix. Violates a convention (naming, structure, style)
- 🔵 **INFO** — Consider. Opportunity for improvement (performance, clarity)

### Summary
```
Score: {N}/100
Issues: {errors} errors, {warnings} warnings, {info} info
Top issues: {most common violation types}
```

### Anti-Hallucination
- Only cite rules that EXIST in .claude/rules/ — verify by reading the file
- Only report line numbers for lines that EXIST — verify by reading the source
- If unsure about a violation, mark it INFO not ERROR
```

## 2. /audit-memory Skill

Write `.claude/skills/audit-memory/SKILL.md`:

```yaml
---
name: audit-memory
description: >
  Audit project memory health. Use when asked to check memory, review stored
  learnings, clean up stale entries, or verify memory system integrity.
  Checks auto-memory, .learnings/, and .claude/ configuration.
---
```

```markdown
## /audit-memory — Memory Health Check

### Process

1. **Read `.learnings/log.md`** — check for:
   - Entries stuck in `pending review` for too long (suggest /reflect)
   - Duplicate entries (same learning recorded multiple times)
   - Entries without proper status tags
   - Entries that contradict each other

2. **Read `.learnings/agent-usage.log`** — check for:
   - Agents that haven't been used in recent sessions
   - Agents used very frequently (candidates for optimization)
   - Missing entries (hook might not be working)

3. **Read CLAUDE.md** — check for:
   - Over 120 lines (needs trimming)
   - Stale conventions or gotchas (verify they still apply)
   - Missing sections (compare against template from Module 02)

4. **Read `.claude/rules/`** — check for:
   - Files over 40 lines (need splitting)
   - Rules that contradict each other
   - Rules that reference files/patterns that no longer exist

5. **Read `.claude/agents/`** — check for:
   - Missing YAML frontmatter
   - Agents without proper tool restrictions
   - Agents with descriptions that don't match their actual function

6. **Check auto-memory** (if accessible):
   ```bash
   ls ~/.claude/projects/*/memory/ 2>/dev/null | head -20
   ```
   - Stale memory entries (reference files/functions that no longer exist)
   - Duplicate memories
   - Missing type or description in frontmatter

### Report

```
Memory Health: {score}/100

.learnings/log.md: {N} entries ({pending} pending, {promoted} promoted, {dismissed} dismissed)
Agent usage: {N} agents tracked, {M} unused
CLAUDE.md: {lines} lines ({over/under} budget)
Rules: {N} files, {total_lines} total lines
Agents: {N} agents, all have valid frontmatter: {yes/no}

Issues:
- [{severity}] {issue description} — {recommended action}
```
```

## Checkpoint

```
✅ Module 06 complete — /audit-file and /audit-memory skills created
```
