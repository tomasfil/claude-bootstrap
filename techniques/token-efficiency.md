# Token & Turn Efficiency Standards

## Scope
- Applies to: CLAUDE.md, .claude/rules/, .claude/skills/, .claude/agents/, memory files, cron job instructions
- NOT: conversation output, commit messages, PR descriptions, user-facing docs

## Token Compression Rules
- Strip articles (a, an, the), filler, unnecessary prepositions
- Telegraphic style: `READ_BEFORE_WRITE: modules,techniques` not full sentences
- Symbols: → (then) | (or) + (and) ~ (approx) × (times) w/ (with)
- Key:value + bullets over prose
- Merge related short rules onto single lines w/ `;` separators
- YAML/markdown over JSON (11-20% fewer tokens)

## Turn Reduction Rules
Turns × tokens = total cost. Each turn re-reads full prefix — so fewer turns compounds w/ compression.

- **Batch parallel calls**: independent tool calls (WebSearch, Read, Grep) → issue ALL in one message
- **Plan searches upfront**: research jobs → identify all queries first, execute in batch, max 2 rounds
- **Pre-compute over discover**: if orchestrator has data → inject via pre_commands/include_files; never make agent search for injectable data
- **Scope lock outputs**: structured-output jobs → "Produce ONLY what's in Output section"; prevents generate-then-simplify loops
- **Meta-tool extraction**: tool sequence appears in >50% of runs → extract to pre_command script
- **No redundant reads**: files loaded via include_files are already in context — never instruct agent to Read them

## What Stays Readable
- Conversation replies to user
- Git commit messages + PR descriptions
- README + user-facing docs
- Code comments

## Why
- Always-loaded files: 30-50% token savings compounds across all sessions
- Turn reduction: 30-50% fewer turns typical for research-heavy jobs
- Combined: token compression + turn reduction are multiplicative (not additive)
- Claude parses telegraphic notation identically to prose — no quality loss

## Compression Tiers

| Tier | Target | Apply To | Rules |
|------|--------|----------|-------|
| T1_DEFAULT | dev audience (incl. user chat) | user replies, agent defs, skills, rules, handoffs | strip articles + symbols + key:value (30-40%) |
| T2_AGGRESSIVE | always-loaded | CLAUDE.md, token-efficiency.md itself | T1 + abbreviations + merged lines via `;` (~50%) |
| T0_READABLE | public-facing | git commits, PR descriptions, external README | full sentences, no jargon |
| NEVER | protected content | code, paths, commands, few-shot, regex, URLs | passthrough — no compression |

Audience = devs → T1 default everywhere. T0 only for artifacts seen outside the project (git history, public docs).

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

## Protected Content Passthrough

Glyph treats documents as typed regions; compression applies ONLY to prose regions:

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

Mechanically enforces never-compress list instead of relying on author discipline.

## Algorithmic Compression Tools (2025-2026)

| Tool | Compression | Quality | When to Use |
|------|------------|---------|-------------|
| LLMLingua-2 | 4-6× | 95-98% retained | variable RAG contexts |
| CompactPrompt (arXiv 2510.18043, 2025) | ~60% | <5% loss | production pipelines |
| Manual telegraphic | 30-50% | 100% | static config, always-loaded files |

Rule: static + loaded-every-turn → manual (one-time authoring, no runtime dep). Variable + large → algorithmic.
