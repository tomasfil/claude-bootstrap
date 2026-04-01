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
File path to audit. If none given, ask.

### Process

1. Read file in full
2. Determine language from extension
3. Read `.claude/rules/code-standards-{lang}.md`
4. Read `.claude/rules/data-access.md` (if file touches data layer)
5. LSP check (if available) → type errors, undefined references
6. Scan violations against all applicable rules

### Check Categories

#### Code Standards
- Naming, structure, style per language rules
- Security + correctness violations
- Data access patterns (if applicable)

#### Claude-Facing Content (only for .claude/ files)
When auditing `.claude/agents/`, `.claude/skills/`, `.claude/rules/`:
- Telegraphic notation: no full-sentence prose (subject-verb-object patterns)
- RCCF structure: skill/agent bodies should have role/constraints/context/format where applicable
- No article sentence starters (The/A/An + verb phrase)
- No filler: "in order to", "please note", "it is important", "your job is"
- Severity: 🟡 WARNING | Rule: compression/prose

### Report Format

For each issue found:
```
[{SEVERITY}] Line {N}: {rule_name}
  Code: `{snippet}`
  Issue: {what's wrong}
  Fix: {how to fix}
```

Severity levels:
- 🔴 **ERROR** — Must fix. Hard rule violation (security, correctness, data access)
- 🟡 **WARNING** — Should fix. Convention violation (naming, structure, style)
- 🔵 **INFO** — Consider. Improvement opportunity (performance, clarity)

### Summary
```
Score: {N}/100
Issues: {errors} errors, {warnings} warnings, {info} info
Top issues: {most common violation types}
```

### Anti-Hallucination
- Only cite rules that EXIST in `.claude/rules/` — verify by reading
- Only report line numbers that EXIST — verify by reading source
- Unsure about violation → mark INFO not ERROR
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

1. Read `.learnings/log.md` — check:
   - Entries stuck `pending review` too long → suggest /reflect
   - Duplicates (same learning recorded ×2+)
   - Missing status tags; contradicting entries

2. Read `.learnings/agent-usage.log` — check:
   - Unused agents (no recent sessions)
   - High-frequency agents → optimization candidates
   - Missing entries → hook may be broken

3. Read `CLAUDE.md` — check:
   - Over 120 lines → needs trimming
   - Stale conventions/gotchas (verify still apply)
   - Missing sections (compare w/ Module 02 template)

4. Read `.claude/rules/` — check:
   - Files >40 lines → need splitting
   - Contradicting rules
   - References to files/patterns that no longer exist

5. Read `.claude/agents/` — check:
   - Missing YAML frontmatter
   - Missing tool restrictions
   - Description/function mismatch

6. Check auto-memory (if accessible):
   ```bash
   ls ~/.claude/projects/*/memory/ 2>/dev/null | head -20
   ```
   - Stale entries referencing removed files/functions
   - Duplicates; missing type | description in frontmatter

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
