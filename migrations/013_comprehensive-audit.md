# Migration: Comprehensive Audit — Style, Behavior, Tracking, Compression, Enforcement

> Audits all generated content against current bootstrap v5 templates. Adds Behavior section to CLAUDE.md, compresses Claude-facing content, updates agent/skill frontmatter, adds enforcement mechanisms.

---

```yaml
# --- Migration Metadata ---
id: "013"
name: "Comprehensive Audit — Style, Behavior, Tracking, Compression, Enforcement"
description: >
  Audits all generated content against current bootstrap v5 templates.
  Adds Behavior section to CLAUDE.md, compresses Claude-facing content,
  updates agent/skill frontmatter, adds enforcement mechanisms.
base_commit: "371cce3"
date: "2026-04-01"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| modify | `.claude/agents/*.md` | Complete frontmatter, compress body, add technique refs |
| modify | `.claude/skills/*/SKILL.md` | Complete frontmatter, compress body |
| modify | `.claude/rules/*.md` | Compress to telegraphic, verify anti-hallucination |
| modify | `.claude/settings.json` | Verify all hooks present + routing up to date |
| modify | `CLAUDE.md` | Add Behavior section, fix Communication, add TaskCreate |
| modify | `.claude/skills/audit-file/SKILL.md` | Add Claude-facing content check category |
| modify | `.claude/skills/review/SKILL.md` | Add compression flag step |
| modify | `.claude/skills/write-prompt/SKILL.md` | Add Output Verification gate |

---

## Phase 1 — Agents + Skills Audit

### Step 1.1 — Audit agent frontmatter

For each `.claude/agents/*.md`:

1. Read the file
2. Check YAML frontmatter for ALL required fields:
   - `name` — lowercase-hyphens
   - `description` — pushy, starts w/ trigger words
   - `tools` — comma-separated, minimal set
   - `model` — haiku | sonnet | opus
   - `effort` — low | medium | high
   - `maxTurns` — integer
   - `color` — hex or named color
3. If any field missing → add it w/ appropriate value based on agent's purpose
4. If `model` or `effort` seem mismatched to agent complexity → flag but don't change (user preference)
5. **Known fixes:**
   - `researcher.md`: if `model:` contains a descriptive placeholder (e.g., `{opus for max-quality...}`) → replace w/ `model: opus`
   - Any agent w/ `model:` containing `{` → replace w/ concrete value (opus for complex, sonnet for standard, haiku for lookups)

### Step 1.2 — Compress agent bodies

For each `.claude/agents/*.md`:

1. Read the body (everything after closing `---` of frontmatter)
2. If body contains full-sentence prose (starts w/ "You are a", "Your job is", "This agent", "The agent", "Please note", "In order to") → rewrite telegraphic:
   - Strip articles (a, an, the), filler, unnecessary prepositions
   - Use symbols: → | + ~ w/
   - Key:value + bullets over prose
   - Merge short related rules w/ `;`
3. Preserve: code examples, few-shot patterns, file paths (no compression on these)

### Step 1.3 — Add technique references to code-writing agents

For each agent that writes or modifies files (code-writer-*, or any agent w/ Write/Edit in tools list):

Check if `## Technique References` section exists. If missing → add before the final section:

```markdown
## Technique References
- `techniques/prompt-engineering.md` → RCCF, token optimization
- `techniques/anti-hallucination.md` → verification patterns, false-claims mitigation
- `techniques/agent-design.md` → subagent constraints, orchestrator patterns
```

For `code-writer-{lang}` agents specifically: verify all 9 required sections present:
1. Role
2. Context
3. Constraints
4. Format
5. Anti-Hallucination Checks
6. Plugin/LSP/MCP Requirements
7. Verification Phase
8. Technique References
9. Project-Specific Knowledge

If any missing → add from bootstrap template in `modules/16-code-writer.md`.

### Step 1.4 — Audit skill frontmatter

For each `.claude/skills/*/SKILL.md`:

1. Read the file
2. Check YAML frontmatter for required fields:
   - `name` — lowercase-hyphens
   - `description` — pushy, starts w/ "Use when..."
   - `model` — haiku | sonnet | opus
   - `effort` — low | medium | high
   - `allowed-tools` — comma-separated list
3. For orchestrator skills (skills that dispatch agents): also verify:
   - `context: fork`
   - `agent` — must be `general-purpose` if body dispatches via Agent tool (Pattern B), or specialist name if body IS the agent instructions (Pattern A)
4. If any field missing → add appropriate value

### Step 1.5 — Compress skill bodies

For each `.claude/skills/*/SKILL.md`:

1. Read the body (after closing `---`)
2. If body contains full-sentence prose → rewrite telegraphic (same rules as Step 1.2)
3. Preserve: code examples, few-shot patterns, file paths, step numbering

### Phase 1 — Verify

- [ ] All agents have complete frontmatter (name, description, tools, model, effort, maxTurns, color)
- [ ] All agent bodies are compressed telegraphic (no "You are a" prose starters)
- [ ] Code-writing agents have technique reference section
- [ ] All skills have complete frontmatter
- [ ] All skill bodies are compressed telegraphic

---

## Phase 2 — Rules + Hooks Audit

### Step 2.1 — Compress rules files

For each `.claude/rules/*.md`:

1. Read the file
2. Compare against Module 03 compressed templates (`modules/03-rules.md`)
3. If still full-sentence prose → rewrite telegraphic:
   - Strip articles, filler, prepositions
   - Use symbols: → | + ~
   - Key:value format; merge related rules w/ `;`
4. Preserve: project-specific knowledge extracted from corrections/learnings

### Step 2.2 — Verify anti-hallucination in code-standards files

For each `.claude/rules/code-standards-*.md`:

Check for `## Verification` or `## Anti-Hallucination` section containing:
- Read before write/modify mandate
- Never assume API/method/type exists
- Never fabricate import paths
- Build verification command
- "Unsure → say so, never guess"

If section missing → add from Module 03 template:

```markdown
## Verification (Anti-Hallucination)
- ALWAYS read existing files before modifying | creating similar ones
- NEVER assume API/method/type exists — verify via LSP hover | Grep
- NEVER fabricate import paths — check actual namespace/module structure
- After writing code → run build: `{build_command}`
- LSP available → hover to confirm types correct
- Unsure if something exists → say so, never guess
```

Replace `{build_command}` w/ project's actual build command from CLAUDE.md.

### Step 2.3 — Audit settings.json hooks

Read `.claude/settings.json` and verify:

**Required hooks:**

1. **UserPromptSubmit routing hook** — must list ALL current skills and agents:
   ```bash
   # Get current skills
   ls -d .claude/skills/*/SKILL.md 2>/dev/null | sed 's|.claude/skills/||;s|/SKILL.md||'
   # Get current agents
   ls .claude/agents/*.md 2>/dev/null | sed 's|.claude/agents/||;s|\.md||'
   ```
   Compare against routing hook's skill/agent lists. Add any missing entries; remove any stale references to deleted skills/agents.

2. **SessionStart env detection hook** — must be present. If missing → add per `modules/04-hooks.md`.

3. **PostToolUse failure logging hook** — must be present. If missing → add per `modules/04-hooks.md`.

For each hook: verify `type` matches expected (`command` for bash scripts, `command` for inline). Verify script paths exist.

### Phase 2 — Verify

- [ ] All rules files are compressed telegraphic
- [ ] Code-standards files have anti-hallucination section
- [ ] UserPromptSubmit routing hook is up to date (all current skills/agents listed, no stale refs)
- [ ] All required hooks present in settings.json (routing, session-start, failure-logging)

---

## Phase 3 — CLAUDE.md Audit

### Step 3.1 — Check and add Behavior section

Read `CLAUDE.md`. Check for `## Behavior` section.

If `## Behavior` missing → add after `## Communication` (or after `## Effort` if Communication is also missing):

```markdown
## Behavior
- READ_BEFORE_WRITE: read existing code/patterns before generating | modifying
- Verify before done: run build+test before claiming complete; if can't verify, say so
- No false claims: if tests fail say so; if unverified say so; never fabricate results
- Collaborator not executor: push back on bad ideas; flag adjacent bugs; use judgment
- Comments: WHY only; no redundant; no commented-out code
- Output: lead w/ answer|action; 1 sentence > 3; skip filler/preamble/transitions
- Claude-facing = compressed telegraphic (specs, plans, skills, agents, rules, memory, learnings, reasoning); human-facing = normal prose (answers, commits, PRs, questions)
```

If `## Behavior` exists but is incomplete → compare against above 7 directives, add any missing.

### Step 3.2 — Fix Communication section

Check `## Communication` section. If it contains placeholder text (e.g., `{style}`, `TODO`, or more than one line of description) → replace with:

```markdown
## Communication
Direct — lead w/ answer, no filler. Concise code.
```

If section missing entirely → add before `## Behavior`.

### Step 3.3 — Add TaskCreate to Workflow

Check `## Workflow` section for TaskCreate line. If missing → add:

```
- TaskCreate for multi-step work (3+ steps); update status across compaction
```

Add after the "Complex features → spec first" line if present, otherwise at end of Workflow section.

### Step 3.4 — Merge standalone Token Efficiency

If `## Token Efficiency` exists as its own section → remove it. The compression directive is now covered by the last bullet in `## Behavior`:
```
- Claude-facing = compressed telegraphic (specs, plans, skills, agents, rules, memory, learnings, reasoning); human-facing = normal prose (answers, commits, PRs, questions)
```

The detailed rules live in `.claude/rules/token-efficiency.md` — no need to duplicate in CLAUDE.md.

### Step 3.5 — Fix ghost agent references

If CLAUDE.md mentions "10 base agents" or references `module-writer` agent → fix:
- Change "10 base agents" → "8 base agents"
- Remove `module-writer` from agent lists (does not exist in any module)
- `project-code-reviewer` is created in Module 18, not Module 10 — if listed under Module 10, move reference

### Step 3.6 — Line count check

Count total lines in CLAUDE.md:

```bash
wc -l CLAUDE.md
```

If >120 lines → trim:
1. Remove duplicate rules already covered by `.claude/rules/` files
2. Collapse verbose sections to single-line summaries
3. Use `@import` for detailed content

### Phase 3 — Verify

- [ ] `## Behavior` section exists with all 7 directives
- [ ] `## Communication` is hardcoded (not placeholder)
- [ ] `## Workflow` has TaskCreate line
- [ ] `## Token Efficiency` merged into Behavior (no standalone section)
- [ ] Total line count <120
- [ ] No ghost agent references (module-writer removed, agent count accurate)

---

## Phase 4 — Compression + Enforcement

### Step 4.1 — Run compression compliance check

```bash
echo "=== Compression Compliance ==="
for f in .claude/agents/*.md .claude/skills/*/SKILL.md .claude/rules/*.md; do
  [ -f "$f" ] || continue
  if grep -Eq '^(You are a|Your job is|This skill|The agent|This agent|Please note|In order to)' "$f"; then
    echo "PROSE DETECTED: $f"
  else
    echo "Compressed: $f"
  fi
done
```

If any files show `PROSE DETECTED` → compress them now (apply Steps 1.2/1.5/2.1 as appropriate).

### Step 4.2 — Update /audit-file with Claude-facing content check

Read `.claude/skills/audit-file/SKILL.md`. Add a new check category for Claude-facing content. Insert the following into the audit categories list (after existing categories):

```markdown
### Claude-Facing Content (files in .claude/)
When target file is inside `.claude/` (agents/, skills/, rules/):
- Check: telegraphic notation used (no articles/filler, symbols over words)
- Check: RCCF structure present (Role, Context, Constraints, Format) for agents/skills
- Check: no full-sentence prose starters ("You are a", "This agent", "The agent")
- Severity: WARNING | Rule: compression/prose
- Fix: rewrite to telegraphic — strip articles (a/an/the), use → | + ~ w/, key:value format
```

If `/audit-file` skill doesn't exist → skip this step (skill not present in project).

### Step 4.3 — Update /review with compression flag step

Read `.claude/skills/review/SKILL.md`. Add a review step for Claude-facing content. Insert the following as an additional check step:

```markdown
### Compression Check (files in .claude/)
For files in .claude/ (agents/, skills/, rules/):
- Flag: full-sentence prose (articles, filler, "You are a" starters)
- Flag: missing RCCF structure in agents/skills
- Flag: verbose where telegraphic expected
- Severity: WARNING
- Action: list flagged files + specific lines needing compression
```

If `/review` skill doesn't exist → skip this step.

### Step 4.4 — Update /write-prompt with Output Verification gate

Read `.claude/skills/write-prompt/SKILL.md`. Add an Output Verification gate as the final step before saving any generated skill/agent/rule. Insert:

```markdown
### Output Verification Gate (before saving)
Run on every generated skill, agent, or rule BEFORE writing to disk:

1. **Prose scan** — search body for full-sentence prose → rewrite telegraphic
   - Detect: lines starting w/ articles (The/A/An + verb), filler phrases ("Please note", "In order to")
   - Action: rewrite each flagged line to telegraphic notation
2. **Article check** — no sentence-starter articles (The/A/An followed by verb)
   - Detect: `^(The|A|An)\s+\w+(s|es|ed|ing)\b`
   - Action: strip article, restructure as key:value or imperative
3. **Filler purge** — remove filler phrases
   - Banned: "Please note", "It is important", "Make sure to", "In order to", "You should"
   - Action: delete phrase, keep instruction
4. **RCCF structure** — agents/skills must have Role, Context, Constraints, Format sections (or equivalent compressed headers)
   - Missing section → add skeleton

Gate FAILS if any prose detected after rewrite attempt → manual review required.
```

If `/write-prompt` skill doesn't exist → skip this step.

### Phase 4 — Verify

- [ ] Zero prose violations in compression compliance check
- [ ] /audit-file has Claude-facing content check (if skill exists)
- [ ] /review has compression flag step (if skill exists)
- [ ] /write-prompt has Output Verification gate (if skill exists)
- [ ] All enforcement mechanisms active

---

## Final Verification

Run full compliance sweep:

```bash
echo "=== Final Compliance Sweep ==="

echo ""
echo "--- Agent Frontmatter ---"
for f in .claude/agents/*.md; do
  [ -f "$f" ] || continue
  echo "Checking: $f"
  for field in name description tools model effort maxTurns color; do
    if ! grep -q "^${field}:" "$f"; then
      echo "  MISSING: $field"
    fi
  done
done

echo ""
echo "--- Skill Frontmatter ---"
for f in .claude/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  echo "Checking: $f"
  for field in name description model effort allowed-tools; do
    if ! grep -q "^${field}:" "$f"; then
      echo "  MISSING: $field"
    fi
  done
done

echo ""
echo "--- Compression Compliance ---"
for f in .claude/agents/*.md .claude/skills/*/SKILL.md .claude/rules/*.md; do
  [ -f "$f" ] || continue
  if grep -Eq '^(You are a|Your job is|This skill|The agent|This agent|Please note|In order to)' "$f"; then
    echo "PROSE: $f"
  fi
done

echo ""
echo "--- CLAUDE.md Checks ---"
if grep -q "## Behavior" CLAUDE.md; then echo "Behavior: OK"; else echo "Behavior: MISSING"; fi
if grep -q "## Communication" CLAUDE.md; then echo "Communication: OK"; else echo "Communication: MISSING"; fi
if grep -q "TaskCreate" CLAUDE.md; then echo "TaskCreate: OK"; else echo "TaskCreate: MISSING"; fi
if grep -q "## Token Efficiency" CLAUDE.md; then echo "Token Efficiency: STILL EXISTS (should be merged)"; else echo "Token Efficiency: OK (merged)"; fi
echo "Line count: $(wc -l < CLAUDE.md)"

echo ""
echo "=== Sweep Complete ==="
```

All checks should pass. Fix any remaining issues before marking complete.

---

Migration complete: `013` — Comprehensive audit of agents, skills, rules, hooks, CLAUDE.md, and compression enforcement
