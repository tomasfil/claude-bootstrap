# Migration: Skill Authoring Best Practices

> Apply Anthropic's official skill authoring rules to existing project skills and agents.

---

```yaml
id: "006"
name: skill-authoring-best-practices
description: >
  Adds official Anthropic skill authoring guidelines (description format,
  body size limits, reference depth, conciseness). Client projects should
  audit existing skills/agents against these rules.
base_commit: "24cc51a9c4055aa8849f69803d726d285ce6a25f"
date: "2026-03-31"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| audit | `.claude/skills/*/SKILL.md` | Review descriptions and body size against new rules |
| audit | `.claude/agents/*.md` | Review descriptions against new rules |

---

## Actions

### Step 1 — Audit skill descriptions

For each SKILL.md in `.claude/skills/`:

1. Read the YAML frontmatter `description` field
2. Check against these rules:
   - **Voice**: Must be third person ("Processes X", "Use when Y") — not "I help you" or "You can use this"
   - **Content**: Must include BOTH what the skill does AND when to trigger it
   - **Length**: Max 1024 characters
3. Update descriptions that don't comply

**Example of a good description:**
```
Extract text and tables from PDF files, fill forms, merge documents.
Use when working with PDF files or when the user mentions PDFs, forms,
or document extraction.
```

### Step 2 — Audit skill body size

For each SKILL.md:

1. Count lines in the body (below frontmatter)
2. If approaching 500 lines, split detailed content into `references/` subdirectory
3. Keep SKILL.md as overview pointing to reference files

### Step 3 — Audit reference depth

For each skill with a `references/` directory:

1. Check that SKILL.md references files directly (one level deep)
2. If any reference file references another reference file (A→B→C), flatten to direct references from SKILL.md
3. Reference files >100 lines should have a table of contents at the top

### Step 4 — Audit agent descriptions

For each agent `.md` file in `.claude/agents/`:

1. Read the YAML frontmatter `description` field
2. Apply same voice/content rules as skills: third person, what + when
3. Update descriptions that don't comply

### Step 5 — Apply conciseness review

For skills and agents with verbose instruction bodies:

1. Check: does this instruction tell Claude something it wouldn't already know?
2. Remove explanations of standard patterns, frameworks, or idioms Claude already knows
3. Keep only: project-specific conventions, unusual constraints, non-obvious decisions
4. Test: "would Claude get this wrong without being told?" — if no, remove it

---

## Verify

- [ ] All SKILL.md `description` fields use third person voice
- [ ] All SKILL.md `description` fields include what + when
- [ ] No SKILL.md body exceeds 500 lines
- [ ] All reference file paths are one level deep from SKILL.md
- [ ] Reference files >100 lines have TOC at top
- [ ] Agent `.md` descriptions use third person voice
- [ ] Skill/agent bodies contain only project-specific conventions (no standard-pattern explanations)

---

Migration complete: `006` — Skill authoring best practices audit applied
