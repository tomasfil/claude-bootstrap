# Migration: Technique References

> Adds .claude/references/techniques/ with compressed research knowledge for skills to reference.

---

```yaml
# --- Migration Metadata ---
id: "008"
name: "Technique References"
description: >
  Copies compressed technique reference files (prompt-engineering, anti-hallucination,
  agent-design) to .claude/references/techniques/. Updates /write-prompt, /brainstorm,
  and /reflect skill bodies to reference local copies as knowledge base.
base_commit: "5bfb366a31dbb4dc657f7d39ca93e547f020f999"
date: "2026-03-31"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| add | `.claude/references/techniques/prompt-engineering.md` | Compressed RCCF + token optimization reference |
| add | `.claude/references/techniques/anti-hallucination.md` | Compressed verification patterns reference |
| add | `.claude/references/techniques/agent-design.md` | Compressed agent design + orchestrator patterns reference |
| modify | `.claude/skills/write-prompt/SKILL.md` | Update anti-hallucination path to .claude/references/techniques/ |
| modify | `.claude/skills/brainstorm/SKILL.md` | Add knowledge base section referencing techniques |
| modify | `.claude/skills/reflect/SKILL.md` | Add technique references to reflector agent dispatch |

---

## Actions

### Step 1 — Create references directory

```bash
mkdir -p .claude/references/techniques
```

### Step 2 — Fetch compressed technique files

```bash
gh api repos/tomasfil/claude-bootstrap/contents/techniques/prompt-engineering.md --jq '.content' | base64 -d > .claude/references/techniques/prompt-engineering.md
gh api repos/tomasfil/claude-bootstrap/contents/techniques/anti-hallucination.md --jq '.content' | base64 -d > .claude/references/techniques/anti-hallucination.md
gh api repos/tomasfil/claude-bootstrap/contents/techniques/agent-design.md --jq '.content' | base64 -d > .claude/references/techniques/agent-design.md
```

Fallback if `gh` unavailable:
```
WebFetch: https://raw.githubusercontent.com/tomasfil/claude-bootstrap/main/techniques/prompt-engineering.md
WebFetch: https://raw.githubusercontent.com/tomasfil/claude-bootstrap/main/techniques/anti-hallucination.md
WebFetch: https://raw.githubusercontent.com/tomasfil/claude-bootstrap/main/techniques/agent-design.md
```

### Step 3 — Update /write-prompt skill (if exists)

**If** `.claude/skills/write-prompt/SKILL.md` exists:
- Read it
- Find: `techniques/anti-hallucination.md`
- Replace with: `.claude/references/techniques/anti-hallucination.md`
- Write updated file

**If missing**, skip.

### Step 4 — Update /brainstorm skill (if exists)

**If** `.claude/skills/brainstorm/SKILL.md` exists AND does NOT already contain `references/techniques`:
- Read it
- Insert before the `DO NOT` line:

```markdown
### Knowledge Base
Before proposing approaches, read (if they exist):
- `.claude/references/techniques/prompt-engineering.md` — RCCF, structured outputs, taxonomy-guided prompting
- `.claude/references/techniques/agent-design.md` — orchestrator patterns, agent design constraints

Use as design vocabulary for architecture/prompt-engineering tasks. Skip for unrelated tasks.
```

- Write updated file

**If missing**, skip.

### Step 5 — Update /reflect skill (if exists)

**If** `.claude/skills/reflect/SKILL.md` exists AND does NOT already contain `references/techniques`:
- Read it
- Find the paths list in "Step 1: Dispatch Agent"
- Add after the `.claude/agents/` line:
  ```
  - `.claude/references/techniques/agent-design.md` — agent design standards (for evaluating agent improvement proposals)
  - `.claude/references/techniques/prompt-engineering.md` — prompt engineering standards (for evaluating skill improvement proposals)
  ```
- Write updated file

**If missing**, skip.

### Step 6 — Wire + sync

1. Verify all three technique files exist at `.claude/references/techniques/`
2. Verify cross-references in updated skill files resolve

---

## Verify

- [ ] `.claude/references/techniques/prompt-engineering.md` exists and is non-empty
- [ ] `.claude/references/techniques/anti-hallucination.md` exists and is non-empty
- [ ] `.claude/references/techniques/agent-design.md` exists and is non-empty
- [ ] If `/write-prompt` exists: `grep "references/techniques/anti-hallucination" .claude/skills/write-prompt/SKILL.md`
- [ ] If `/brainstorm` exists: `grep "references/techniques" .claude/skills/brainstorm/SKILL.md`
- [ ] If `/reflect` exists: `grep "references/techniques" .claude/skills/reflect/SKILL.md`

---

Migration complete: `008` — Technique references added to client projects
