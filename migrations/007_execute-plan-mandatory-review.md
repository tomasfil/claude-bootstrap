# Migration: Execute-Plan Mandatory Review

> Fix execute-plan skill skipping /review after completing all tasks.

---

```yaml
id: "007"
name: execute-plan-mandatory-review
description: >
  Adds mandatory /review step to execute-plan skill. Previously, execute-plan
  would complete all tasks and say "ready to commit" without running review,
  violating the verify > review > commit pipeline.
base_commit: "55ffef60c10b6e1677709636c7c1e873bc5e5d47"
date: "2026-03-31"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| edit | `.claude/skills/execute-plan/SKILL.md` | Add step 7 (review) and post-execution section |

---

## Actions

### 1. Update execute-plan skill

Edit `.claude/skills/execute-plan/SKILL.md`:

**Add step 7 to the numbered list** (after "Final verification"):

```markdown
7. **Review** — invoke `/review` on all changed files before suggesting commit. This is mandatory, not optional.
```

**Add this section before the Anti-Hallucination section** (or at the end if no Anti-Hallucination section):

```markdown
### Post-Execution (mandatory)
After all tasks complete:
1. Run `/review` on all changed files — do NOT skip this
2. If review finds issues: fix them before proceeding
3. Only after review passes, tell the user changes are ready to `/commit`

Never say "ready to commit" without having run /review first.
```

---

## Verification

```bash
grep -q "Review.*invoke.*review" .claude/skills/execute-plan/SKILL.md && echo "✅ Step 7 present" || echo "❌ Step 7 missing"
grep -q "Post-Execution" .claude/skills/execute-plan/SKILL.md && echo "✅ Post-execution section present" || echo "❌ Post-execution section missing"
```
