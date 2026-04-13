---
name: coverage
description: >
  Use when asked about test coverage, structural validation, or to verify
  bootstrap completeness. Reports coverage of files, agents, skills, hooks.
context: fork
agent: proj-consistency-checker
allowed-tools: Read Grep Glob
model: sonnet
effort: medium
# Skill Class: forkable — single bounded autonomous scan
---

## /coverage — Structural Validation Report

### Process
Scan `.claude/` directory structure:
1. Count agents: `.claude/agents/*.md` — list each w/ name, model, tools
2. Count skills: `.claude/skills/*/SKILL.md` — list each w/ name, description snippet
3. Count rules: `.claude/rules/*.md` — list each w/ line count
4. Count hooks: check `.claude/settings.json` for hook entries
5. Count techniques: `.claude/references/techniques/*.md`
6. Verify `CLAUDE.md` exists + line count
7. Verify `.learnings/` structure complete

### Report Format
```
## Coverage Report
Modules: {N}/{total} valid
Skills: {N}/{total} valid (frontmatter complete)
Agents: {N}/{total} valid (frontmatter complete)
Hooks: {N}/{total} valid (structure correct)
Config: {valid/invalid}
Cross-refs: {N} broken / {N} total checked
Overall: {score}%
```

Flag: missing components vs expected (agents from Module 05, skills from Module 06).

### Anti-Hallucination
- Only report PASS for checks where the command actually executed and output was read
- Validation command fails | produces no output → report FAIL, never assume success
- Read actual file contents before claiming validity — never infer from filename
- Never interpolate counts — extract from real command output
