---
name: coverage-gaps
description: >
  Use when asked what's missing from the development environment, what gaps
  exist in skills/agents/rules, or to identify improvement opportunities.
context: fork
agent: proj-consistency-checker
allowed-tools: Read Grep Glob
model: sonnet
effort: medium
# Skill Class: forkable — single bounded autonomous gap analysis
---

## /coverage-gaps — Gap Identification

### Process
Compare actual state vs expected:
1. Read `CLAUDE.md` — extract referenced skills, agents, commands
2. Glob `.claude/agents/*.md` — compare against `agent-index.yaml` (if exists)
3. Glob `.claude/skills/*/SKILL.md` — compare against Module 06 skill list
4. Read `.claude/rules/` — compare against detected languages (`code-standards-{lang}.md` per language)
5. Read `.learnings/log.md` — patterns w/o corresponding rules/instincts
6. Check for languages detected in Module 01 w/o `proj-code-writer-{lang}` agent

### Gap Categories

**Missing frontmatter fields** (agents):
- Required: name, description, tools, model, effort, maxTurns

**Skills without anti-hallucination section**

**Modules without checkpoints**

**Orphaned agents** (not dispatched by any skill)

**Routing hook gaps** (skills on disk vs in `.claude/settings.json`)

### Report Format
```
## Coverage Gaps

### Missing Frontmatter ({N})
- {file}: missing {field}

### Missing Anti-Hallucination ({N})
- {file}

### Routing Hook Gaps ({N})
- /{skill-name}

### Orphaned Agents ({N})
- {agent-name}

### Priority: Fix these first
1. {highest impact gap} — {recommendation}
```

### Recommendations
Suggest which `/evolve-agents` | `/reflect` | manual action addresses each gap.
