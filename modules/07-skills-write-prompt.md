# Module 07 — Create /write-prompt Skill

> Best practices for writing LLM instructions — skills, agents, CI prompts.

---

## Idempotency

Per skill file: if exists, extract project-specific content, merge with bootstrap template, regenerate. If missing, create from template.

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

See `.claude/references/techniques/INDEX.md` for available technique references (anti-hallucination, prompt engineering, agent design).

### Claim-Evidence Ledger (for research-heavy skills)

When building skills that research external data and synthesize it into output
(reports, recommendations, competitive analysis, audits referencing docs), add a
**Claim-Evidence Ledger** phase. This prevents the most common research hallucination:
presenting unverified or fabricated claims as facts.

**When to apply:** Any skill where the output contains external claims — statistics,
dates, quotes, competitive findings, API behaviors, framework features. NOT needed
for pure code-writing agents (those use read-before-write instead).

**Structure — each claim gets a tracked entry:**
```json
{
  "id": 1,
  "claim": "The specific external claim",
  "source_url": "https://...",
  "source_name": "Name of source",
  "source_date": "2026-03-10",
  "confidence": "high|medium|low",
  "corroborated": true,
  "corroboration_source": "Second independent source (if any)"
}
```

**Integrate into skill workflow as 3 additions:**

1. **During research phase** — every external claim gets a ledger entry as discovered.
   No entry = claim cannot appear in output. No exceptions.

2. **Mandatory audit phase** (insert BEFORE synthesis/output):
   - Categorize: high-confidence corroborated (✓), high-confidence single-source (⚡),
     medium/low uncorroborated (DROPPED)
   - Statistics (any %, number, date) require corroboration. Uncorroborated stats
     get prefixed with "~" and the single source name.
   - Low-confidence + uncorroborated = banned from output → move to GAPS section.
   - State: "This step exists to catch hallucinations BEFORE they enter the output."

3. **In output format** — require source attribution inline:
   - Each claim shows: `[Claim] — [Source, Date] [✓ corroborated / ⚡ single source]`
   - GAPS section for searched-but-not-found: `[Topic — queries tried — why it matters]`

**Hallucination ban-list (include concrete BAD/GOOD examples in the skill):**
- Never fabricate a statistic — cite exact source or don't include it
- Never combine two sources into one stat — report each separately
- Never assert absence as fact — document search queries that returned nothing
- Never present single case study results as universal — label scope explicitly
- Never fill gaps from training data — write "no current data found" instead
- Never confuse dates — verify against primary/official sources

**Absence documentation:** When searches return nothing, the skill must document
what was searched and state "no results found" rather than inventing from memory.
This is the single most important rule — the temptation to fill gaps is strongest
when the output would look incomplete without them.

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

### Token Efficiency (MUST apply to all generated content)

Skills, agents, rules, CLAUDE.md → read by Claude, not humans.
Write Claude-facing content in compressed telegraphic notation:

- Strip articles/filler/prepositions
- Telegraphic: `READ_BEFORE_WRITE: target + 2-3 similar` not full sentences
- Symbols: → | + ~ × w/
- Key:value + bullets over prose; merge short rules w/ `;`
- YAML/markdown over JSON (11-20% fewer tokens)
- Legend at top for repeated abbreviations

Stays readable: conversation output, commits, PRs, user docs, code comments.
Impact: 30-50% savings on always-loaded files, compounds across sessions + subagents.
Exception: code examples + few-shot patterns → keep full fidelity (quality cliff <65%).

### Output Verification (mandatory before saving)
Before writing any generated skill/agent/rule file:
1. Scan body for full-sentence prose → rewrite telegraphic
2. No sentence-starter articles (The/A/An + verb phrase)
3. No filler: "in order to", "please note", "it is important", "your job is"
4. If violation found → rewrite compressed BEFORE saving

### Principles

1. **Explicit > implicit** — don't assume the agent remembers context
2. **One responsibility** — each agent/skill does one thing well
3. **Full context** — include everything needed, reference files by path
4. **Constrain the agent** — restrict tools, define boundaries
5. **Handle the empty case** — what if there's nothing to do?
6. **Match effort** — don't use opus for a simple search
7. **Token-efficient** — compress Claude-facing content; keep user-facing readable
8. **Compress-before-save** — ALL generated Claude-facing content MUST pass Output Verification
```

## Checkpoint

```
✅ Module 07 complete — /write-prompt skill created
```
