# Module 07 — Create /write-prompt Skill

> Best practices for writing LLM instructions — skills, agents, CI prompts.

---

## Create Skill

```bash
mkdir -p .claude/skills/write-prompt
```

Write `.claude/skills/write-prompt/SKILL.md`:

```yaml
---
name: write-prompt
description: >
  Best practices for writing LLM instructions. Use when creating new skills,
  agents, subagent definitions, CI prompts, or any prompt/instruction file.
  Covers structure, anti-hallucination, RCCF framework, and testing.
---
```

```markdown
## /write-prompt — LLM Instruction Writing Guide

### Skill Structure

```yaml
---
name: lowercase-hyphens (max 64 chars)
description: >
  Pushy description with trigger words. Start with "Use when..."
  Include specific action verbs that match how users will ask.
---
```

Body: procedure steps, decision trees, templates, verification.
References: put detailed examples in `references/` subdirectory.
Progressive disclosure: ~100 tokens metadata loaded always, full body loaded on invocation.

### Agent Structure

```yaml
---
name: lowercase-hyphens
description: >
  Pushy description. Include trigger words and component types.
tools: Read, Write, Edit, Bash, Grep, Glob, LSP
model: sonnet
effort: medium
---
```

### RCCF Framework (apply to every agent/skill)

1. **Role** — WHO: expertise, seniority, mindset
2. **Context** — WHAT: project state, frameworks, versions, patterns
3. **Constraints** — BOUNDARIES: do/don't rules, scope limits, anti-hallucination
4. **Format** — OUTPUT: expected structure, file naming, templates

### Anti-Hallucination (MUST include in every code-writing agent)

Every agent that writes code must include:

1. **Read-before-write mandate:**
   "BEFORE writing any code, read the target file and 2-3 similar files"

2. **Negative instructions:**
   "DO NOT invent APIs/methods not in this project. Verify via LSP or Grep."

3. **Build verification:**
   "AFTER writing, run {build_command}. Fix errors before presenting."

4. **Confidence routing:**
   "If unsure whether something exists, check first. Never guess."

5. **Fallback behavior:**
   "If you cannot verify a type/method exists, say so. Don't fabricate."

See `techniques/anti-hallucination.md` for complete patterns.

### Model Selection

| Purpose | Model | Effort |
|---------|-------|--------|
| Quick lookup, search | haiku | low |
| Code generation, review | sonnet | medium |
| Complex architecture, debugging | opus | high |

### Tool Restrictions

- Research agents: `tools: Read, Grep, Glob` (no write access)
- Code writers: `tools: Read, Write, Edit, Bash, Grep, Glob, LSP`
- With web access: add `WebSearch, WebFetch`
- Minimal: only list tools the agent actually needs

### Invocation Quality

Subagents can't ask for clarification. Every dispatch must include:
- Specific file paths
- Expected behavior / success criteria
- Reference files for pattern matching
- Build/test command to verify
- What to do if something unexpected is found

### Principles

1. **Explicit > implicit** — don't assume the agent remembers context
2. **One responsibility** — each agent/skill does one thing well
3. **Full context** — include everything needed, reference files by path
4. **Constrain the agent** — restrict tools, define boundaries
5. **Handle the empty case** — what if there's nothing to do?
6. **Match effort** — don't use opus for a simple search
```

## Checkpoint

```
✅ Module 07 complete — /write-prompt skill created
```
