# Agent Creation Brief

> Consumed by `proj-code-writer-markdown` when `/evolve-agents` Phase 3 dispatches new specialist creation. Read in full before generating a new `proj-code-writer-{lang}-{framework}` or `proj-test-writer-{lang}-{framework}` agent file. Concentrates sub-specialist creation requirements: frontmatter, body skeleton, dispatch interface, wave protocol, conformance checklist, anti-patterns. Replaces 100+ lines of inline prompt requirements w/ a single Read + structured reference.

---

## Required Frontmatter

YAML between `---` markers; field order as below; no `tools:` line.

| Field | Value | Notes |
|---|---|---|
| `name` | `proj-code-writer-{lang}-{framework}` | exact match to filename minus `.md` |
| `description` | `>` block, starts "Use when writing {lang}/{framework} code..." | imperative voice; 2-3 sentences max |
| `model` | `opus` (GENERATES_CODE) \| `sonnet` (SUBTLE_ERROR_RISK \| ANALYZES) \| `haiku` (CHECKS) | per `.claude/rules/model-selection.md` Agent Classification Table |
| `effort` | `xhigh` | project default; blanket-safe across model tiers (silent fallback to `high` on non-Opus 4.7+) |
| justification comment | `# xhigh: GENERATES_CODE` (or relevant CLASS) | placed on line after `effort:`; required for `/audit-model-usage` |
| `maxTurns` | `100` | matches existing `proj-code-writer-*` pattern |
| `color` | unused color (check existing agents) | visual distinction in tool output |
| `skills` | optional list | preloaded domain knowledge for stateful agents |
| `memory` | `project` | optional; for stateful agents only |

OMIT `tools:` line — all agents inherit parent MCP access. Adding `tools:` creates strict whitelist excluding ALL MCP tools (`mcp__*`, all servers). Per `CLAUDE.md` Conventions §Agents.

---

## Body Skeleton

Mandatory sections in order:

1. **STEP 0 — Load critical rules** — force-read block; canonical 6-rule list (see verbatim template below)
2. **Role** — 1-2 line statement scoped to {lang}/{framework}; senior practitioner framing
3. **Pass-by-Reference Contract** — write to dispatch path; return `{path} — {summary <100 chars}`; main reads file only on need
4. **Stack** — versions from research files; cite research file paths verbatim
5. **Conventions** — framework idioms, file layout, naming patterns from research
6. **Before Writing (MANDATORY)** — read rules, read research files passed in dispatch, verify cross-refs
7. **Anti-Hallucination** — never invent framework APIs; verify via research; if unsure → say so
8. **Known Gotchas** — pre-populated from web research findings; preserved on Phase 5 refresh; "None yet" if empty
9. **Scope Lock** — exact file globs in-scope; refuse adjacent work via `SCOPE EXPANSION NEEDED`
10. **Self-Fix Protocol** — build/test loop, ≤3 attempts, report on third failure
11. **`<use_parallel_tool_calls>` block** — batch independent reads in one message

Length target: 100-200 lines body content. Hard ceiling 250.

---

## STEP 0 Force-Read Block (verbatim template)

Direct copy from this section into the new agent ensures STEP 0 boilerplate consistency. Replace `{your primary lang}` w/ the agent's language slug (e.g., `python`, `typescript`, `markdown`).

```markdown
## STEP 0 — Load critical rules (MANDATORY first action)

Output completeness > token efficiency. Full scope every time. No elision. Calibrated effort only.

Before any task-specific work, Read these rule files (in parallel where possible):
- `.claude/rules/general.md`
- `.claude/rules/token-efficiency.md`
- `.claude/rules/agent-scope-lock.md`
- `.claude/rules/mcp-routing.md` (if present)
- `.claude/rules/max-quality.md`
- `.claude/rules/code-standards-{your primary lang}.md` (if present)

Rationale: this sub-agent's body replaces the default system prompt. Explicit Read lands content as conversation context.
```

Plus the First-Tool Contract + Transparent Fallback paragraphs from `proj-code-writer-markdown.md:30-34` if MCP-indexed.

---

## Dispatch Interface

- **Pass-by-Reference**: write to path supplied in dispatch prompt. Return ONLY `{path} — {summary}` (summary <100 chars). Never inline file content in return message.
- **Reference Files block**: if dispatch prompt contains `#### Reference Files` or `Read these before writing:`, Read ALL listed paths before proceeding. No exceptions.
- **Anti-hallucination wraparound**: every cited file path must exist at write-time (verify via Glob); never fabricate paths; if a research reference is missing, return `BLOCKED: research file {path} not found` rather than inventing content.
- **Scope discipline**: agent edits ONLY files in dispatch `#### Files` block. Off-scope need → `SCOPE EXPANSION NEEDED: {file} — reason: {short}`. Per `agent-scope-lock.md`.

---

## Wave Protocol Annotation

Every code-writer / test-writer agent body MUST include a `### Wave Protocol` block w/ at least one canonical loopback-budget label per `.claude/rules/wave-iterated-parallelism.md` + `.claude/rules/loopback-budget.md`.

Recommended shape for code-writer: **SINGLE_LAYER** (cap=2). Annotation:

```markdown
### Wave Protocol
TASK_SHAPE: SINGLE_LAYER | WAVE_CAP: 2
<!-- RESOURCE-BUDGET: cap=2 -->
Wave 1: batch all independent reads (target file + 2-3 similar files + applicable technique refs).
Gap-check: any layer/file unread? Empty → stop. Else Wave 2 targets gaps.
```

For agents w/ end-to-end flow scope (rare): END_TO_END_FLOW + composed annotation `<!-- RESOURCE-BUDGET: ceiling=10 + CONVERGENCE-QUALITY: signal=new-layer-discovered -->`.

Canonical label tokens: `RESOURCE-BUDGET` | `CONVERGENCE-QUALITY` | `LOOPBACK-AUDIT` | `SINGLE-RETRY`. No 5th label.

---

## Conformance Checklist

Run BEFORE returning path + summary. ALL must pass:

1. Filename matches `proj-code-writer-{lang}-{framework}.md` exactly — no spaces, lowercase, kebab-case
2. YAML frontmatter opens w/ `---` line 1, closes w/ `---` after color field
3. All required frontmatter fields present: `name`, `description`, `model`, `effort`, justification comment, `maxTurns`, `color`
4. NO `tools:` line (whitelist would strip MCP propagation) — verify w/ `grep -n "^tools:" {file}` → 0 hits
5. STEP 0 force-read block present + lists all 6 canonical rule files
6. Role section: 1-2 lines, scoped to {lang}/{framework}
7. Pass-by-Reference Contract section present — exact wording from skeleton
8. Stack + Conventions sections cite research file paths that exist (Glob-verify)
9. Known Gotchas section present (even if empty w/ "None yet — populate from web research")
10. Scope Lock section present + lists exact file globs in-scope
11. `### Wave Protocol` block present + contains at least one canonical label token
12. `<use_parallel_tool_calls>` block present at end
13. No `TBD` / `TODO` / placeholder text in delivered file — full implementation per max-quality §2
14. All cross-referenced file paths exist (Glob-verify each `.claude/...` and `templates/...` mention)
15. Body length 100-250 lines (target 100-200)

---

## Anti-Patterns to Avoid

1. **Adding `tools:` line** — strips ALL MCP tools from inherited context; OMIT always per CLAUDE.md convention
2. **Using `effort: high` instead of `effort: xhigh`** — silent fallback on Opus 4.7+; xhigh is project default + future-proofs Sonnet/Haiku adoption
3. **Hardcoding framework version in role description** — stale after version bump; put in `## Stack` section w/ "as of {date}"
4. **Omitting STEP 0 force-read block** — rules silently fail to load; agent operates w/o discipline (max-quality, scope-lock, token-efficiency invisible)
5. **Skipping Wave Protocol annotation** — `/audit-agents` A8 check FAILs; loopback semantics undefined
6. **Inventing framework APIs without citing research file** — anti-hallucination violation; verify via passed research paths or return BLOCKED
7. **Body length >250 lines** — agent context bloat; split via `/evolve-agents` only when scope genuinely splits, never as size-reduction tactic
8. **Using built-in Explore / general-purpose / plugin agents in dispatch examples** — bypasses project evidence tracking; use `proj-quick-check` (simple) | `proj-researcher` (deep) only
9. **Fabricating file paths in cross-references** — every `.claude/...` mention must Glob-verify before save; broken refs = `/review` FAIL
10. **Treating Phase 3 research files as authoritative without cross-checking** — research may be stale; cite + date stamp every claim sourced from research
