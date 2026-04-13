---
name: audit-file
description: >
  Use when asked to review, audit, or check a specific file for quality,
  conventions, or issues. Reports violations with line numbers, severity, fixes.
argument-hint: "[filename]"
context: fork
agent: proj-code-reviewer
allowed-tools: Read Grep Glob
model: sonnet
effort: medium
# Skill Class: forkable — single bounded autonomous audit, no user interaction
---

## /audit-file — Source File Audit

### Input
File path to audit. If no path given, ask user.

### Process
1. Read file in full
2. Determine language from extension
3. Read `.claude/rules/code-standards-{lang}.md`
4. Read `.claude/rules/data-access.md` (if file touches data layer)
5. LSP check (if available) → type errors, undefined references
6. Scan violations against applicable rules

### Check Categories
- **Code standards**: naming, structure, style per language rules; security + correctness
- **Claude-facing content** (only for `.claude/` files):
  telegraphic notation, RCCF structure, no article starters, no filler
  Severity: WARNING

### Report Format (per issue)
```
[{SEVERITY}] Line {N}: {rule_name}
  Code: `{snippet}`
  Issue: {what's wrong}
  Fix: {how to fix}
```

Severity: ERROR (must fix) | WARNING (should fix) | INFO (consider)

### Summary
```
Score: {N}/100
Issues: {errors} errors, {warnings} warnings, {info} info
Top violations: {most common types}
```

### Anti-Hallucination
- Only cite rules that EXIST in `.claude/rules/` — verify by reading
- Only report line numbers that EXIST — verify by reading source
- Unsure about a violation → mark INFO not ERROR
