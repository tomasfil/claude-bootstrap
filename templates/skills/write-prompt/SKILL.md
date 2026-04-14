---
name: write-prompt
description: >
  Best practices for writing LLM instructions. Use when creating new skills,
  agents, subagent definitions, CI prompts, or any prompt/instruction file.
  Covers structure, anti-hallucination, RCCF framework, and testing.
allowed-tools: Read Write Edit Grep Glob
model: sonnet
effort: high
# high: MULTI_STEP_SYNTHESIS
paths: ".claude/skills/**,.claude/agents/**"
---
# Skill Class: main-thread — inline generator (consequential) [latency: interactive]
<!-- Provenance: opus+medium was a drift artifact from commit 60c53a0 (LLM inference during bootstrap generation, not author-specified). Corrected 2026-04-14 per deepen-3.2. -->

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

See `.claude/references/techniques/anti-hallucination.md` for complete patterns.

### Claim-Evidence Ledger (for research-heavy skills)

When building skills that research external data and synthesize it into output,
add a **Claim-Evidence Ledger** phase to prevent presenting unverified claims as facts.

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
   No entry = claim cannot appear in output.

2. **Mandatory audit phase** (insert BEFORE synthesis/output):
   - Categorize: high-confidence corroborated (✓), single-source (⚡), uncorroborated (DROPPED)
   - Statistics require corroboration. Uncorroborated stats get prefixed with "~" and source name.
   - Low-confidence + uncorroborated = banned from output → move to GAPS section.

3. **In output format** — require source attribution inline:
   - Each claim shows: `[Claim] — [Source, Date] [✓ corroborated / ⚡ single source]`
   - GAPS section: `[Topic — queries tried — why it matters]`

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

### Token Efficiency (MUST apply to all generated content)

Skills, agents, rules, and CLAUDE.md are read by Claude, not humans.
Write all Claude-facing content in compressed telegraphic notation:

- Strip articles (a, an, the), filler, unnecessary prepositions
- Telegraphic: `READ_BEFORE_WRITE: target + 2-3 similar files` not full sentences
- Symbols: → (then) | (or) + (and) ~ (approx) × (times) w/ (with)
- Key:value + bullets over prose; merge short related rules w/ `;`
- YAML/markdown over JSON (11-20% fewer tokens)
- Legend at top for repeated abbreviations

**What stays readable:** conversation output, commits, PRs, user-facing docs, code comments.

**Impact:** Always-loaded files save 30-50% tokens per conversation.
Skills/agents save per-invocation. Compounds across all sessions + subagents.

**Quality:** Claude parses telegraphic notation identically to prose — no quality loss.
Exception: code generation prompts below 65% token retention hit a quality cliff.
Keep detailed code examples and few-shot patterns at full fidelity.

### Output Verification Gate (before saving)
Run on every generated skill, agent, or rule BEFORE writing to disk:

1. **Prose scan** — search body for full-sentence prose → rewrite telegraphic
   - Detect: lines starting w/ articles (The/A/An + verb), filler phrases
   - Action: rewrite each flagged line to telegraphic notation
2. **Article check** — no sentence-starter articles (The/A/An followed by verb)
   - Action: strip article, restructure as key:value or imperative
3. **Filler purge** — remove filler phrases
   - Banned: "Please note", "It is important", "Make sure to", "In order to", "You should"
   - Action: delete phrase, keep instruction
4. **RCCF structure** — agents/skills must have Role, Context, Constraints, Format sections
   - Missing section → add skeleton

Gate FAILS if any prose detected after rewrite attempt → manual review required.

### Principles

1. **Explicit > implicit** — don't assume the agent remembers context
2. **One responsibility** — each agent/skill does one thing well
3. **Full context** — include everything needed, reference files by path
4. **Constrain the agent** — restrict tools, define boundaries
5. **Handle the empty case** — what if there's nothing to do?
6. **Match effort** — don't use opus for a simple search
7. **Token-efficient** — compress Claude-facing content; keep user-facing readable
