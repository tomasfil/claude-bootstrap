# Migration: Parallel Per-Language Specialist Generation

> Modules 16+17 merged into single Module 16 with per-language agent generation. Test writer is now per-language, not generic. Module 18 renumbered to 17. Migration re-generates specialists while preserving evolved project knowledge.

---

```yaml
# --- Migration Metadata ---
id: "018"
name: "Parallel Per-Language Specialist Generation"
description: >
  Module 16 now generates both code-writer AND test-writer agents per detected
  language (was: monolithic single-language code-writer + separate generic test-writer).
  Module 17 (was 18) is the code reviewer, now referencing per-language knowledge.
  Old Module 17 (test-writer) absorbed into Module 16. This migration re-runs the
  updated pipeline to generate per-language specialists while preserving any evolved
  project-specific gotchas from existing agents.
base_commit: "49b61ff8d34e55eca1ddf39af379b9f3f3f6a438"
date: "2026-04-01"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| modify | `.claude/agents/code-writer-*.md` | Regenerated per-language with persistent reference artifacts |
| remove | `.claude/agents/test-writer.md` | Generic test-writer replaced by per-language `test-writer-{lang}.md` |
| add | `.claude/agents/test-writer-{lang}.md` | Per-language test writer specialists |
| add | `.claude/skills/code-write/references/{lang}-analysis.md` | Local codebase analysis per language |
| add | `.claude/skills/code-write/references/{lang}-research.md` | Web research findings per language |
| modify | `.claude/agents/project-code-reviewer.md` | Updated to reference per-language knowledge files |
| modify | `.claude/skills/coverage/SKILL.md` | Regenerated with multi-language awareness |
| modify | `.claude/skills/coverage-gaps/SKILL.md` | Regenerated with multi-language awareness |

---

## Actions

### Step 1 — Extract evolved knowledge from existing agents

**CRITICAL: Do NOT delete any agent file before extracting its project-specific knowledge.**

For each existing agent file matching `.claude/agents/code-writer-*.md` and `.claude/agents/test-writer*.md`:

1. Read the file in full
2. Extract these sections into a temporary knowledge summary:
   - **Section 9: Project-Specific Knowledge (Gotchas)** from code-writer agents
   - **Section 7: Project-Specific Knowledge (Gotchas)** from test-writer agents
   - **Section 8: Mocking Gotchas** from test-writer agents
   - Any pipeline traces or component types that were refined through usage
   - Any DI patterns, error handling patterns, or naming conventions that were updated post-generation
3. Save extracted knowledge to `.claude/skills/code-write/references/evolved-knowledge-{lang}.md`

If a generic `.claude/agents/test-writer.md` exists (no language suffix):
1. Read it and extract all project-specific sections
2. The knowledge will be distributed to the appropriate per-language test-writer during regeneration

If a generic `.claude/agents/code-writer.md` exists (no language suffix):
1. Read it and extract all project-specific sections
2. The knowledge will be distributed to the appropriate per-language code-writer during regeneration

### Step 2 — Delete generic agents

After Step 1 has preserved all knowledge:

```bash
# Delete generic agents (replaced by per-language variants)
[[ -f .claude/agents/test-writer.md ]] && rm .claude/agents/test-writer.md
[[ -f .claude/agents/code-writer.md ]] && rm .claude/agents/code-writer.md
```

### Step 3 — Re-run Module 16 pipeline

Fetch the updated Module 16 from the bootstrap repo and execute it against the current project:

```bash
gh api repos/tomasfil/claude-bootstrap/contents/modules/16-code-writer.md \
  --jq '.content' | base64 -d > /tmp/16-code-writer.md
```

Execute the module. This will:
- Phase 0: Detect all languages with 3+ owned source files
- Phases 1-2 per language: Dispatch researcher agents for local analysis + web research
- Phases 3-4 per language: Dispatch code-writer-markdown agents to generate `code-writer-{lang}.md` + `test-writer-{lang}.md`
- Phase 5: Generate/update orchestrator skill
- Phase 6: Generate/update coverage skills

**Important:** When dispatching the code-writer-markdown agents in Phases 3-4, include in the prompt:
```
Read `.claude/skills/code-write/references/evolved-knowledge-{lang}.md` if it exists.
Carry forward ALL project-specific gotchas, mocking gotchas, and refined patterns
into the new agent's Gotchas/Knowledge sections. These represent real-world learnings
that were accumulated through project usage — do not discard them.
```

### Step 4 — Re-run Module 17 (code reviewer)

Fetch the updated Module 17 and execute it:

```bash
gh api repos/tomasfil/claude-bootstrap/contents/modules/17-code-reviewer.md \
  --jq '.content' | base64 -d > /tmp/17-code-reviewer.md
```

Execute the module. The code reviewer will now read per-language reference files (`{lang}-analysis.md`, `{lang}-research.md`) and incorporate language-specific knowledge into review checklists.

### Step 5 — Clean up temporary knowledge files

After regeneration is complete and verified:

```bash
# Evolved knowledge has been absorbed into the new agents — clean up temp files
rm -f .claude/skills/code-write/references/evolved-knowledge-*.md
```

### Step 6 — Wire + sync

1. Verify cross-references: every path mentioned in changed files exists
2. Verify `settings.json` routing hook includes all new agents in the agent list
3. Verify no stale "Module 18" references exist in project files

---

## Verify

```bash
# No generic agents should exist
[[ -f .claude/agents/test-writer.md ]] \
  && echo "FAIL: generic test-writer.md still exists" \
  || echo "OK: no generic test-writer"

[[ -f .claude/agents/code-writer.md ]] \
  && echo "FAIL: generic code-writer.md still exists" \
  || echo "OK: no generic code-writer"

# Per-language agents should exist (at least one)
ls .claude/agents/code-writer-*.md 2>/dev/null \
  && echo "OK: per-language code-writers found" \
  || echo "FAIL: no per-language code-writers"

ls .claude/agents/test-writer-*.md 2>/dev/null \
  && echo "OK: per-language test-writers found" \
  || echo "FAIL: no per-language test-writers"

# Reference artifacts should exist
ls .claude/skills/code-write/references/*-analysis.md 2>/dev/null \
  && echo "OK: analysis refs found" \
  || echo "FAIL: no analysis refs"

ls .claude/skills/code-write/references/*-research.md 2>/dev/null \
  && echo "OK: research refs found" \
  || echo "FAIL: no research refs"

# Coverage skills should exist
[[ -f .claude/skills/coverage/SKILL.md ]] \
  && echo "OK: coverage skill" \
  || echo "FAIL: missing coverage skill"

[[ -f .claude/skills/coverage-gaps/SKILL.md ]] \
  && echo "OK: coverage-gaps skill" \
  || echo "FAIL: missing coverage-gaps skill"

# Code reviewer should reference per-language knowledge
grep -q "{lang}-analysis\|analysis\.md\|per-language" .claude/agents/project-code-reviewer.md \
  && echo "OK: reviewer references per-language knowledge" \
  || echo "WARN: reviewer may not reference per-language files"

# All specialist agents must have color and maxTurns in frontmatter
for f in .claude/agents/code-writer-*.md .claude/agents/test-writer-*.md; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  grep -q "^color:" "$f" \
    && echo "OK: $name has color" \
    || echo "FAIL: $name missing color in frontmatter"
  grep -q "^maxTurns:" "$f" \
    && echo "OK: $name has maxTurns" \
    || echo "FAIL: $name missing maxTurns in frontmatter"
done
```

- [ ] No generic `test-writer.md` or `code-writer.md` exist
- [ ] At least one `code-writer-{lang}.md` agent exists per qualifying language
- [ ] At least one `test-writer-{lang}.md` agent exists per qualifying language
- [ ] `{lang}-analysis.md` reference files exist for each language
- [ ] `{lang}-research.md` reference files exist for each language
- [ ] Coverage skills exist and use correct commands
- [ ] Code reviewer references per-language knowledge
- [ ] Evolved gotchas from previous agents are preserved in new agents
- [ ] All specialist agents have `color` in frontmatter (code-writers: blue, test-writers: green)
- [ ] All specialist agents have `maxTurns` in frontmatter
- [ ] No broken cross-references

---

Migration complete: `018` — Per-language code-writer and test-writer agents with persistent reference artifacts
