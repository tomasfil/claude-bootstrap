# Glyph Notation Reference

Compressed-notation standard for all Claude-facing content. Primary sources: [./token-efficiency.md](./token-efficiency.md), [./prompt-engineering.md](./prompt-engineering.md), [./agent-design.md](./agent-design.md).

## Legend

Symbols used throughout Glyph-compressed content:

| Symbol | Meaning |
|--------|---------|
| `→` | then / results in / leads to |
| `\|` | or / alternative |
| `+` | and / plus |
| `~` | approximately / about |
| `w/` | with |
| `×` | times / multiplied by |

Rule: any doc using these symbols at T1/T2 MUST include a legend (validator flags absence as error).

## Compression Rules

Manual transforms applied to prose-region text.

| Rule | Before | After | Savings |
|------|--------|-------|---------|
| Strip articles | "The function that handles auth" | "Function handling auth" | ~15% |
| Symbols over words | "returns" \| "leads to" \| "produces" | `→` | ~10% |
| TSV for flat lists | Markdown table w/ headers | Tab-separated values | ~20% |
| Key:value over prose | "The database is PostgreSQL" | `db: PostgreSQL` | ~25% |
| Merge short rules | Separate bullet per rule | Rules joined w/ `;` | ~10% |
| Abbreviations | "configuration", "function", "component" | `config`, `fn`, `(c)` | ~5% |

## Compression Tiers

Target audience → compression level mapping.

| Tier | Target | Apply To | Rules | Range |
|------|--------|----------|-------|-------|
| T0_READABLE | public-facing | git commits, PR descriptions, external README | full sentences, no jargon | 0% |
| T1_DEFAULT | dev audience (incl. user chat) | user replies, agent defs, skills, rules, handoffs | strip articles + symbols + key:value | 30-40% |
| T2_AGGRESSIVE | always-loaded | CLAUDE.md, token-efficiency.md, this doc | T1 + abbreviations + merged lines via `;` | ~50% |
| NEVER | protected content | code, paths, commands, few-shot, regex, URLs, identifiers | passthrough — no compression | 0% |

Default = T1 (devs = audience). T0 only for artifacts seen outside project.

## Per-Role Retention Floors

Compression floor handoffs flowing TO agent role.

| Role | Min Retention | Rationale |
|------|---------------|-----------|
| code-writer | ≥80% | quality cliff 55-65%, cannot fabricate API details |
| research | ~70% | must preserve citations + source URLs |
| reviewer | ~70% | must preserve specificity of findings |
| routing | ≤30% (5-10× safe) | classification tolerates aggressive compression |
| chain-of-thought | ≥80% | reasoning chains break at lower retention |

Conductor tags handoff w/ `compression_profile` → prevents silent lossy chains (research 70% → code-writer expects 80% = fabrication risk).

## Protected Regions

Typed regions never compressed; passthrough.

- `code` — inline + fenced code blocks
- `path` — file paths (contain `/`|`\` + extension)
- `command` — shell commands, invocations
- `few_shot` — worked examples w/ input+output
- `regex` — regex patterns
- `url` — URLs, URIs
- `identifier` — hashes, IDs, ULIDs

Enforcement: mechanical (region-typed) not author-discipline.

## Format by Target

Output format + delimiter per LLM target.

| Target | Format | Delimiter Style | Reason |
|--------|--------|-----------------|--------|
| claude | yaml+markdown | xml | XML tags = Anthropic-preferred behavioral anchor |
| cursor | mdc | markdown | Cursor-native markdown-components format |
| copilot | markdown | markdown | only format supported |
| aider | plain | none | Aider parses loosely, no structure required |
| other | markdown | markdown | safe default |

## Compression Ranges by File Type

Safe compression per file type.

| File Type | Range | Tier | Source |
|-----------|-------|------|--------|
| agent-definition | 30-50% | T1_DEFAULT | telegraphic bullets, tokenizer-neutral |
| skill | 40-60% | T2_AGGRESSIVE | classification/routing tolerates 5-10× (NAACL 2025) |
| system-prompt | 20-35% | T1_DEFAULT | code-gen cliff <65% retention (arXiv 2503.19114) |
| always-loaded | ~50% | T2_AGGRESSIVE | amortizes infinitely across sessions |

## Handoff Schema

Essential fields for inter-agent handoffs.

Top-level fields: `id, parent_id, context_id, source, target, task, scope, context, output, budget, meta`

| Field | Required | Notes |
|-------|----------|-------|
| `id` | Y | stable chain identifier (ULID) |
| `context_id` | Y | groups multi-agent conversation |
| `source` | Y | `{agent, step?}` — routing + audit |
| `target` | Y | `{agent, role}` — compression profile lookup |
| `task` | Y | telegraphic intent |
| `parent_id` | N | chain link (A2A referenceTaskIds) |
| `scope` | N | `{include, exclude, constraints}` |
| `context` | N | `{files, prior_refs, instincts, injected}` |
| `output` | N | `{findings, evidence, unresolved, confidence}` |
| `budget` | N | `{tokens, tools}` |
| `meta` | N | `{profile, tokens_in_out, created}` |

`meta.profile` values: `code` \| `research` \| `review` \| `route`

Rule: tag `compression_profile` in meta → prevents silent lossy chains; missing profile = reject.

## Key Research Benchmarks

Compression evidence base.

- YAML vs JSON: 11-20% fewer tokens
- TOON format: 30-60% fewer for flat/tabular arrays
- Manual telegraphic: 15-40% savings (strip articles + symbols + key:value)
- Code-gen quality cliff: sharp drop <65% retention (arXiv 2503.19114)
- Classification/routing: 5-10× compression safe (NAACL 2025)
- Multiplicative: token compression × turn reduction = combined savings (not additive)

Example: 30% compression + 40% turn reduction ~ 58% total cost reduction.

## Quality Guardrails

`validateGlyph(content, tier)` rules; NEVER tier short-circuits valid.

| Rule | Severity | Check |
|------|----------|-------|
| Prose block | warning | paragraph >2 sentences at T1/T2 (skip fenced code) |
| Symbol w/o legend | error | uses `GLYPH_SYMBOLS` value w/o `Legend:` line within 20 lines (T1/T2 only) |
| Frontmatter bleeding | warning | YAML frontmatter field >120 chars, no `key: value` shape |
| Protected region violation | error | code \| path \| command containing `…` \| `[truncated]` \| `...` |

`valid: true` ⟺ zero `error` severity flags (warnings allowed).

## See Also

- [./token-efficiency.md](./token-efficiency.md) — tiers, retention floors, protected regions, benchmarks
- [./agent-design.md](./agent-design.md) — handoff schema, inter-agent formats, essential fields
- [./prompt-engineering.md](./prompt-engineering.md) — compression ranges, format selection, eval harness
- [./anti-hallucination.md](./anti-hallucination.md) — Pattern 9 evidence tracking, Pattern 10 false claims
