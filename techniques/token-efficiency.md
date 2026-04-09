# Token & Turn Efficiency Reference

> Canonical source for compression rules. All modules/skills/agents @import this — never duplicate compression rules elsewhere.

---

## Scope

These rules apply to ALL Claude-facing content: agent bodies, skill bodies, rule files, specs,
plans, memory entries, learnings. Human-facing output (answers, commits, PRs, questions) uses
normal prose.

Applies to: CLAUDE.md, .claude/rules/, .claude/skills/, .claude/agents/, memory files, cron job instructions, specs, plans
NOT: conversation output, commit messages, PR descriptions, user-facing docs, code comments

---

## Compression Rules

- Drop articles (a, an, the), filler words, redundant context
- Use → instead of "results in" or "leads to"
- Use | instead of "or" in lists
- Use + instead of "and" in compound items
- Abbreviate common terms: config, impl, func, param, dep, env, auth, repo
- Use telegraphic style: subject-verb-object, no subordinate clauses
- Prefer YAML > JSON for configuration (less syntax overhead)
- Use TSV for flat arrays (one line vs multi-line JSON)
- Symbols: ~ (approx) × (times) w/ (with)
- Key:value + bullets over prose; merge short related rules w/ `;` separators

### Banned Filler Phrases
"Please note", "It is important", "Make sure to", "In order to", "You should",
"As mentioned", "Keep in mind", "Note that", "Remember to"

---

## Format Selection

| Data type | Preferred format | Why |
|---|---|---|
| Config/metadata | YAML frontmatter | Readable, less syntax noise |
| Flat lists | TSV or bullet points | One line per item |
| Structured data | YAML | Less bracket noise than JSON |
| Code examples | Fenced blocks | Language-tagged |
| Cross-references | Inline paths | `techniques/foo.md` not links |

---

## @import for DRY

Use `@import path/to/file.md` in CLAUDE.md to pull in detailed docs.
Keeps CLAUDE.md under 120 lines while providing full detail where needed.
Rules files in `.claude/rules/` are auto-loaded — no @import needed.

---

## Cache-Friendly Patterns

- Front-load static context (role, rules, examples) before dynamic content
- Static prefix = cacheable across turns, saves re-processing
- Put variable content (user input, current state) at the END
- Prompt structure: [system/role] → [static rules] → [examples] → [dynamic context] → [task]

---

## Compression Tiers

| Tier | Target | Apply To | Rules |
|------|--------|----------|-------|
| T1_DEFAULT | dev audience (incl. user chat) | user replies, agent defs, skills, rules, handoffs | strip articles + symbols + key:value (30-40%) |
| T2_AGGRESSIVE | always-loaded | CLAUDE.md, token-efficiency.md itself | T1 + abbreviations + merged lines via `;` (~50%) |
| T0_READABLE | public-facing | git commits, PR descriptions, external README | full sentences, no jargon |
| NEVER | protected content | code, paths, commands, few-shot, regex, URLs | passthrough — no compression |

Audience = devs → T1 default everywhere. T0 only for artifacts seen outside the project (git history, public docs).

---

## Turn Reduction Rules

Turns × tokens = total cost. Each turn re-reads full prefix — fewer turns compounds w/ compression.

- **Batch parallel calls**: independent tool calls (WebSearch, Read, Grep) → issue ALL in one message
- **Plan searches upfront**: research jobs → identify all queries first, execute in batch, max 2 rounds
- **Pre-compute over discover**: orchestrator has data → inject via pre_commands/include_files; never make agent search for injectable data
- **Scope lock outputs**: structured-output jobs → "Produce ONLY what's in Output section"; prevents generate-then-simplify loops
- **Meta-tool extraction**: tool sequence appears in >50% of runs → extract to pre_command script
- **No redundant reads**: files loaded via include_files already in context — never instruct agent to Read them

---

## Per-Role Retention Floors (handoffs + prompts)

Compression of data flowing TO an agent must respect that agent's floor:

| Role | Min Retention | Rationale |
|------|--------------|-----------|
| code-writer | ≥80% | quality cliff 55-65%, cannot fabricate API details |
| research/scout/survey | ~70% | must preserve citations + source URLs |
| reviewer/QC | ~70% | must preserve specificity of findings |
| routing/classification | ≤30% (5-10× compression safe) | tolerates aggressive compression |
| chain-of-thought | ≥80% | reasoning chains break at lower retention |

Conductor tags each handoff w/ `compression_profile` so receiving agent knows retention — prevents silent lossy chains (research 70% → code-writer expects 80% = fabrication risk).

---

## Protected Content Passthrough

Compression applies ONLY to prose regions — never to structured content:

```yaml
regions:
  prose: T1|T2 compression
  code: NEVER
  path: NEVER
  command: NEVER
  few_shot: NEVER
  regex: NEVER
  url: NEVER
  identifier: NEVER  # hashes, IDs, ULIDs
```

---

## Algorithmic Compression Tools (2025-2026)

| Tool | Compression | Quality | When to Use |
|------|------------|---------|-------------|
| LLMLingua-2 | 4-6× | 95-98% retained | variable RAG contexts |
| CompactPrompt (arXiv 2510.18043, 2025) | ~60% | <5% loss | production pipelines |
| Manual telegraphic | 30-50% | 100% | static config, always-loaded files |

Rule: static + loaded-every-turn → manual (one-time authoring, no runtime dep). Variable + large → algorithmic.

---

## Why This Matters

- Always-loaded files: 30-50% token savings compounds across all sessions
- Turn reduction: 30-50% fewer turns typical for research-heavy jobs
- Combined: token compression + turn reduction are multiplicative (not additive)
- Claude parses telegraphic notation identically to prose — no quality loss
- Exception: code generation prompts below 65% token retention hit quality cliff → keep few-shot + code examples at full fidelity
