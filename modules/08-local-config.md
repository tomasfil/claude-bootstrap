# Module 08 — Local Configuration

> Create CLAUDE.local.md and ensure gitignore entries.

---

## Idempotency

```
IF CLAUDE.local.md exists → PRESERVE (personal preferences are sacred)
IF missing → CREATE with user preferences from Module 01
```

## 1. Create CLAUDE.local.md

```markdown
# Personal Preferences

## Style
{From discovery: "Direct — no fluff" or "Diplomatic — explain reasoning"}

## Workflow
- {Any personal workflow preferences from discovery}
- {e.g., "Always show me the diff before committing"}
- {e.g., "I prefer to review agent output before it's applied"}

## Model Override (optional)
To force a specific model for cost or quality reasons:
- All agents on sonnet: set model: sonnet in each agent's frontmatter
- All agents on haiku: set model: haiku (not recommended — degrades code generation quality)
Default model assignments are optimized per-agent. Only override if you have a specific reason.

## Notes
{Space for personal notes that shouldn't be in the shared CLAUDE.md}
```

## 2. Update .gitignore

Behavior depends on git_strategy from Module 01:

### If git_strategy == "track" (personal projects)

Add ONLY machine-specific files to .gitignore:
```
CLAUDE.local.md
.claude/settings.local.json
.learnings/agent-usage.log
```

### If git_strategy == "companion" or "ephemeral" (work projects)

Add ALL claude files to .gitignore:
```
CLAUDE.md
CLAUDE.local.md
.claude/
.learnings/
```

**Check if entries already exist before adding** — don't duplicate:
```bash
for entry in "CLAUDE.local.md" ".claude/settings.local.json"; do
  grep -qxF "$entry" .gitignore 2>/dev/null || echo "$entry" >> .gitignore
done
```

## Checkpoint

```
✅ Module 08 complete — CLAUDE.local.md created, .gitignore updated for {git_strategy}
```
