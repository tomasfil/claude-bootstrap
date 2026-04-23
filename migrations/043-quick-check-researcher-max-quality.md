# Migration 043 — Quick-Check Self-Refusal + Researcher Max-Quality Uncap

<!-- migration-id: 043-quick-check-researcher-max-quality -->

> Adds task-shape self-refusal gate + per-field evidence contract + output schema to `proj-quick-check.md`. Removes hard round-cap on `proj-researcher.md` + adds dedup rule + token_budget tracking + framework-idiom guard. Replaces `main-thread-orchestrator.md` Tier 2 block with explicit task-shape classifier. Updates `agent-design.md` technique w/ task-shape classification taxonomy. Destructive replace steps use baseline-sentinel hand-edit detection — customized client files get `SKIP_HAND_EDITED` + manual-merge guide, never blind-overwrite (per `general.md` Migration Preservation Discipline).

---

## Metadata

```yaml
id: "043"
breaking: false
affects: [agents, rules, techniques]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Session benchmark on a downstream client codebase using a convention-over-configuration web framework revealed `proj-quick-check` (haiku) confabulated ~20+ route values when asked for per-endpoint route + verb + base class — reading base-path constants + filename then synthesizing plausible routes. Meanwhile `proj-researcher` (sonnet) correctly identified the framework's resolution mechanism, read each configuration body, composed routes accurately.

Web research (22 searches / 3 rounds, synthesized as evidence-grounded findings) confirmed:
- Smaller models suffer systematic RLHF-induced overconfidence on structured extraction (arxiv 2502.11028, 2410.09724, 2510.26995)
- Hard round caps on research agents are contra to Anthropic's own production pattern (goal-completion stop)
- Per-field evidence provenance is the published mitigation for field fabrication (Lakera 2026, MDPI 2025)
- Runaway-cost precedent exists (production cost-runaway incident — public Nov 2025 case study — $47k unbounded-agent-loop) — budget guardrails required alongside uncap

## Rationale

1. `proj-quick-check` currently accepts multi-field enumeration tasks w/o discrimination — produces confident-wrong output. Self-refusal gate + evidence contract structurally prevent fabrication.
2. `proj-researcher` has hard `Maximum 2 search rounds total` cap — violates `max-quality.md` §1 Full Scope + §6 No Hedging. Replaced w/ goal-completion stop + dedup + token_budget safety net.
3. `main-thread-orchestrator.md` Tier 2 currently defaults to quick-check + post-hoc escalate. New rule classifies shape BEFORE dispatch — multi-field → researcher direct.
4. **Project-specific customizations MUST be preserved.** Migration's three destructive section replaces (Local Codebase Analysis in `proj-researcher.md`, Web Research in `proj-researcher.md`, Tier 2 block in `main-thread-orchestrator.md`) implement three-tier baseline-sentinel detection per `general.md` Migration Preservation Discipline: (a) post-043 sentinel present → SKIP already patched; (b) baseline (pre-043 stock) sentinel present → safe PATCH; (c) neither present → file was hand-edited post-bootstrap → `SKIP_HAND_EDITED` + `.bak-043` backup written + pointer to `## Manual-Apply-Guide`. Blind overwrite of customized content is structurally prevented.

---

## Changes

1. Injects Task-Shape Self-Refusal Gate + Per-Field Evidence Contract + Output Schema + Max-Quality Alignment sections into `.claude/agents/proj-quick-check.md`; appends fabrication-guard bullet to its Anti-Hallucination list. Marker `## Task-Shape Self-Refusal Gate`.
2. Updates `.claude/agents/proj-researcher.md`: frontmatter `maxTurns: 100` → `maxTurns: 200`; replaces Local Codebase Analysis + Web Research sections w/ uncapped goal-completion versions + framework-idiom guard; inserts Token Budget + Coverage Tracking + Max-Quality Alignment sections before Scope Lock. Marker `## Token Budget + Coverage Tracking` + `maxTurns: 200`.
3. Replaces the Tier 2 block in `.claude/rules/main-thread-orchestrator.md` w/ task-shape classifier (pre-dispatch shape classification, not post-hoc escalation). Marker `Agent selection by task shape`.
4. Appends Task-Shape Classification taxonomy section to `.claude/references/techniques/agent-design.md` (client project technique layout). Fetch updated technique content from bootstrap repo via `gh api`. Marker `## Task-Shape Classification`.
5. Advances `.claude/bootstrap-state.json` → `last_migration: "043"` + appends to `applied[]`.

Idempotent: re-run detects marker headings (`## Task-Shape Self-Refusal Gate`, `## Token Budget + Coverage Tracking`, `maxTurns: 200`, `Agent selection by task shape`, `## Task-Shape Classification`) and prints `SKIP: already patched`.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -d ".claude/agents" ]] || { echo "ERROR: no .claude/agents directory"; exit 1; }
[[ -d ".claude/rules" ]] || { echo "ERROR: no .claude/rules directory"; exit 1; }
[[ -f ".claude/agents/proj-quick-check.md" ]] || { echo "ERROR: .claude/agents/proj-quick-check.md missing"; exit 1; }
[[ -f ".claude/agents/proj-researcher.md" ]] || { echo "ERROR: .claude/agents/proj-researcher.md missing"; exit 1; }
[[ -f ".claude/rules/main-thread-orchestrator.md" ]] || { echo "ERROR: .claude/rules/main-thread-orchestrator.md missing"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI required (for technique sync)"; exit 1; }
```

### Idempotency check

```bash
#!/usr/bin/env bash
set -euo pipefail

qc_patched=0
res_patched=0
orch_patched=0
tech_patched=0

if grep -q "## Task-Shape Self-Refusal Gate" .claude/agents/proj-quick-check.md 2>/dev/null; then
  qc_patched=1
fi

if grep -q "## Token Budget + Coverage Tracking" .claude/agents/proj-researcher.md 2>/dev/null && \
   grep -q "^maxTurns: 200" .claude/agents/proj-researcher.md 2>/dev/null; then
  res_patched=1
fi

if grep -q "Agent selection by task shape" .claude/rules/main-thread-orchestrator.md 2>/dev/null; then
  orch_patched=1
fi

if [[ -f ".claude/references/techniques/agent-design.md" ]] && \
   grep -q "## Task-Shape Classification" .claude/references/techniques/agent-design.md; then
  tech_patched=1
fi

if [[ "$qc_patched" -eq 1 && "$res_patched" -eq 1 && "$orch_patched" -eq 1 && "$tech_patched" -eq 1 ]]; then
  echo "SKIP: migration 043 already applied (all four targets carry new markers)"
  exit 0
fi

echo "Applying migration 043: qc_patched=$qc_patched res_patched=$res_patched orch_patched=$orch_patched tech_patched=$tech_patched"
```

### Step 1 — Patch `.claude/agents/proj-quick-check.md`

Read-before-write: detects `## Task-Shape Self-Refusal Gate` marker; skips if present. Otherwise injects four new sections between `## Out of Scope` and `## Anti-Hallucination`, and appends fabrication-guard bullet to the existing `## Anti-Hallucination` list.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import os, sys

path = ".claude/agents/proj-quick-check.md"
marker = "## Task-Shape Self-Refusal Gate"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

if marker in content:
    print(f"SKIP: {path} already patched")
    sys.exit(0)

# Anchor for insertion: the line `## Anti-Hallucination`. New sections go BEFORE it.
anchor = "## Anti-Hallucination"
if anchor not in content:
    print(f"ERROR: {path} missing `{anchor}` anchor — cannot patch safely")
    sys.exit(1)

new_sections = '''## Task-Shape Self-Refusal Gate

Before executing, classify task shape. **REFUSE** + return structured `TASK_SHAPE_MISMATCH` when ANY of these triggers holds:

1. **Composition required** — fields compose from ≥2 files (e.g., route = group-prefix file + method-body file concatenation)
2. **Cross-subsystem mapping** — spans multiple projects, layers, execution models (e.g., "end-to-end flow across API + Workers + DB")
3. **Framework-idiom decoding** — answer requires framework convention knowledge (FastEndpoints `Configure()`, decorator routing, Rails routes.rb, Hono `.get()` chains, Django URLconf, Spring `@RequestMapping`) where plain Grep doesn't surface the field values
4. **Recall-critical enumeration where N > ~15** — large lists where silent truncation = correctness risk

Rationale: haiku pattern-completes plausible field values from filenames/base-paths when evidence commands don't directly produce the field. Confident-wrong > refuse. Sonnet (`proj-researcher`) grounds each field in source reads. Published evidence: arxiv 2502.11028 "Mind the Confidence Gap" — smaller models fail to meaningfully estimate uncertainty; arxiv 2410.09724 — RLHF-induced systematic overconfidence, amplified in smaller models.

**Refusal format** (verbatim — DO NOT paraphrase):
```
TASK_SHAPE_MISMATCH
{
  "status": "TASK_SHAPE_MISMATCH",
  "trigger": "composition | cross-subsystem | framework-idiom | recall-N>15",
  "escalate_to": "proj-researcher",
  "reason": "<one sentence why this trigger fired>"
}
```

Do NOT partial-answer. Do NOT "do the easy ones, skip the rest". Refuse cleanly — main thread re-dispatches to researcher.

**Note on multi-field tasks:** Pure multi-field enumeration with ≤15 items AND no composition / cross-subsystem / framework-idiom characteristics is IN-SHAPE for this agent — use the Per-Field Evidence Contract below. The triggers above target the failure modes (field composition from multiple files, idiom decoding, large-N recall) where haiku confabulates. Small simple lists with evidence grounding are safe.

**In-shape examples (proceed):**
- "Where is `PermissionService` defined?"
- "Does `IUserRepository` exist? Interface file?"
- "Read lines 40–80 of `Program.cs`"
- "What calls `CheckPermission`?" (single-direction, single question — delegate to MCP find_referencing_symbols)
- "List 8 error types with their catch-location file:line + exception class (≤15 items, no composition)"

**Out-of-shape examples (REFUSE):**
- "List every HTTP endpoint with route + verb" — multi-field + framework-idiom
- "Map permission-granting end-to-end" — cross-subsystem
- "Enumerate all event handlers with topic + class + retry policy" — composition + large N

## Per-Field Evidence Contract (enumeration mode)

When a task is multi-field enumeration with ≤15 items AND does NOT match any self-refusal trigger (composition / cross-subsystem / framework-idiom / N>15), use JSON output mode w/ this per-row schema. Each row MUST include:

```json
{
  "<field_name>": {
    "value": "<extracted value>",
    "evidence": {
      "tool": "<Read | Grep | mcp__serena__find_symbol | mcp__codebase-memory-mcp__get_code_snippet | etc.>",
      "query": "<exact command / tool args>",
      "raw_result_line": "<verbatim line from tool output>"
    },
    "confidence": "HIGH | MEDIUM | LOW | UNKNOWN"
  }
}
```

Fields without grounded evidence MUST be marked `"value": null, "confidence": "UNKNOWN"`. Never infer from filenames, base-path constants, or class names. Inference = fabrication.

Published support: Lakera (2026) span-level verification; MDPI (2025) post-generation quality control in multi-agent RAG; arxiv 2502.11028 — structured output improves smaller-model calibration.

## Output Schema (enumeration-mode returns only)

This schema applies to enumeration-mode returns (multi-field JSON via the Per-Field Evidence Contract above). Single-fact lookup returns use the simpler form: direct answer + `file:line` evidence + one-line confidence note. Do NOT emit the full schema for "where is X defined" style queries — that is token waste.

```
RESULT_COUNT: <N>
RAW_EVIDENCE:
  tool_call: <exact command or MCP call>
  raw_stdout_lines: <N from command>
  delta_vs_result_count: <signed integer>
CONFIDENCE_DISTRIBUTION:
  HIGH: <N>
  MEDIUM: <N>
  LOW: <N>
  UNKNOWN: <N>
COVERAGE_GAPS:
  - <field or scope NOT searched — empty list requires positive enumeration of what WAS searched>
TRUNCATED: <YES | NO>
```

`TRUNCATED: NO` is NOT a default — it requires evidence (count match OR explicit exhaustive-scope statement). Default-NO on uncertain coverage = calibration failure per arxiv 2510.26995 FermiEval.

## Max-Quality Alignment (per `.claude/rules/max-quality.md`)

- **§1 Full Scope** — answer every listed field. Never "for brevity" skip rows. `UNKNOWN` is valid; silent omission is not
- **§4 Calibrated Effort** — report coverage in observable units (RESULT_COUNT, raw_stdout_lines, fields_with_UNKNOWN count)
- **§6 No Hedging** — if task is in-shape: solve. If task is out-of-shape: refuse via self-refusal gate. Never "partial answer + see researcher for rest" — that's a hedge
- **§7 Output ≠ Instruction token rules** — your RETURN is OUTPUT. Completeness > brevity. Never elide rows, never truncate schema fields

'''

patched = content.replace(anchor, new_sections + anchor, 1)

# Append fabrication-guard bullet to Anti-Hallucination list.
# Anchor: last bullet currently in the list — "Never answer from training data".
ah_anchor = "- Never answer from training data — every answer must come from tool output this turn"
if ah_anchor not in patched:
    print(f"ERROR: {path} missing Anti-Hallucination bullet anchor — cannot append fabrication-guard bullet safely")
    sys.exit(1)

fabrication_bullet = "- Fabrication guard: never derive a field from a filename, class name, or base-path constant. If the evidence command produced a count but not the field's value → return `UNKNOWN` for that field OR run a second command that does produce it. Filename-inference = fabrication (arxiv 2504.17550 HalluLens intrinsic-hallucination taxonomy)"
patched = patched.replace(ah_anchor, ah_anchor + "\n" + fabrication_bullet, 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(patched)
print(f"PATCHED: {path}")
PY
```

### Step 2 — Patch `.claude/agents/proj-researcher.md`

Read-before-write with three-tier baseline-sentinel detection on destructive sub-edits (per `general.md` Migration Preservation Discipline). Applies four edits:
- **(a) frontmatter maxTurns bump** — line-level numeric swap (`maxTurns: 100` → `maxTurns: 200`); skipped if already 200.
- **(b) Local Codebase Analysis section replace** — DESTRUCTIVE, three-tier:
  - idempotency sentinel `Framework-idiom guard` present → `SKIP: already patched`
  - baseline sentinel `Glob for file patterns → understand project structure` present (pre-043 stock content, safe to replace) → `PATCHED`
  - neither present → `SKIP_HAND_EDITED` + write `.bak-043` backup if absent + pointer to `## Manual-Apply-Guide §Step-2b`
- **(c) Web Research section replace** — DESTRUCTIVE, three-tier:
  - idempotency sentinels `Dedup rule` + `token_budget` present → `SKIP: already patched`
  - baseline sentinel `Maximum 2 search rounds total` present (pre-043 stock content, safe to replace) → `PATCHED`
  - neither present → `SKIP_HAND_EDITED` + `.bak-043` backup + pointer to `## Manual-Apply-Guide §Step-2c`
- **(d) Insert Token Budget + Max-Quality Alignment sections before `## Scope Lock`** — additive (insert-before-anchor, not replace); missing anchor → ERROR.

File-level idempotency: detects both `## Token Budget + Coverage Tracking` marker AND `maxTurns: 200` → whole-file `SKIP: already patched`, no sub-edits attempted.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import os, sys, re
from pathlib import Path

path = ".claude/agents/proj-researcher.md"
backup = Path(path + ".bak-043")

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

if "## Token Budget + Coverage Tracking" in content and re.search(r"^maxTurns:\s*200\s*$", content, re.MULTILINE):
    print(f"SKIP: {path} already patched")
    sys.exit(0)

# Write backup before any destructive edit (once, per migration).
def ensure_backup(current_text):
    if not backup.exists():
        backup.write_text(current_text, encoding="utf-8")

# ---- (a) frontmatter maxTurns bump (line-level, minimal-risk) ----
new_content, n = re.subn(r"^maxTurns:\s*100\s*$", "maxTurns: 200", content, count=1, flags=re.MULTILINE)
if n == 0 and not re.search(r"^maxTurns:\s*200\s*$", content, re.MULTILINE):
    print(f"SKIP_HAND_EDITED: {path} frontmatter maxTurns field has been customized (neither 100 nor 200) — manual application required. See migrations/043-quick-check-researcher-max-quality.md §Manual-Apply-Guide §Step-2a.")
else:
    if n == 1:
        ensure_backup(content)
        content = new_content
        print(f"PATCHED: {path} frontmatter maxTurns → 200 (043-2a)")
    else:
        print(f"SKIP: {path} frontmatter maxTurns already at 200 (043-2a)")

# ---- (b) Local Codebase Analysis section replace (three-tier) ----
POST_043_LOCAL = "Framework-idiom guard"
BASELINE_LOCAL = "Glob for file patterns → understand project structure"

local_old_pattern = re.compile(
    r"### Local Codebase Analysis\n"
    r"1\. Glob for file patterns → understand project structure\n"
    r"2\. Read representative files per layer/component type\n"
    r"3\. Grep for patterns: naming conventions, error handling, DI, test patterns\n"
    r"4\. Map architecture: layers, dependencies, data flow\n"
    r"5\. Identify conventions: file naming, code style, framework idioms\n"
)
local_new = """### Local Codebase Analysis
1. Route code discovery through `.claude/rules/mcp-routing.md` action→tool table FIRST (cmm/serena when available); Glob/Grep/Read are fallback
2. Read representative files per layer — at least ONE example per detected layer; depth governed by task, not by round-cap
3. Map architecture: layers, dependencies, data flow — trace until endpoint / DB / storage / external-call boundary
4. Identify conventions: file naming, code style, framework idioms — cite `file:line` per convention
5. **Framework-idiom guard**: for codebases using convention-over-configuration frameworks (FastEndpoints, Rails, Django, Spring, NestJS, Hono decorators, Azure Functions attributes, etc.) — BEFORE enumerating entities, locate the framework's resolution mechanism (`Configure()` bodies, route-table builder, DI registration, middleware pipeline). Read THAT mechanism's source. Never infer entity properties (routes, handlers, topics) from filenames or base-path constants. Filename-inference = fabrication (arxiv 2504.17550 HalluLens intrinsic-hallucination taxonomy)
6. No hard cap on tool calls — `.claude/rules/max-quality.md` §1 governs. Run as many Reads/Greps/MCP queries as coverage requires. Parallel-batch per `<use_parallel_tool_calls>` for efficiency
"""

if POST_043_LOCAL in content:
    print(f"SKIP: {path} Local Codebase Analysis already patched (043-2b)")
elif BASELINE_LOCAL not in content:
    print(f"SKIP_HAND_EDITED: {path} Local Codebase Analysis section has been customized post-bootstrap — baseline sentinel absent. Manual application required. See migrations/043-quick-check-researcher-max-quality.md §Manual-Apply-Guide §Step-2b for the new section content to merge.")
    # DO NOT write; preserve existing content
else:
    # Safe to replace — baseline present, not yet patched.
    new_content, n = local_old_pattern.subn(local_new, content, count=1)
    if n == 0:
        print(f"SKIP_HAND_EDITED: {path} Local Codebase Analysis baseline sentinel present but exact 5-step form did not match — reformatted post-bootstrap. Manual application required. See migrations/043-quick-check-researcher-max-quality.md §Manual-Apply-Guide §Step-2b.")
    else:
        ensure_backup(content)
        content = new_content
        print(f"PATCHED: {path} Local Codebase Analysis (043-2b)")

# ---- (c) Web Research section replace (three-tier) ----
POST_043_WEB_A = "Dedup rule"
POST_043_WEB_B = "token_budget"
BASELINE_WEB = "Maximum 2 search rounds total"

web_old_pattern = re.compile(
    r"### Web Research\n"
    r"1\. Plan ALL searches before executing — identify gaps first\n"
    r"2\. Batch all WebSearch calls in ONE message \(parallel\)\n"
    r"3\. After results, identify specific gaps → at most ONE follow-up batch\n"
    r"4\. Maximum 2 search rounds total\n"
    r"5\. Record: source URL, date, key findings, confidence level\n"
)
web_new = """### Web Research
1. Plan all searches before executing — identify gaps first
2. Batch WebSearch calls in ONE message (parallel — no artificial round cap)
3. After each batch, identify remaining gaps → continue batching until coverage complete OR gaps are irreducibly uncertain (training-cutoff, source-unavailable, task-ambiguous)
4. **Dedup rule** (prevents runaway cost — fountaincity Nov 2025 $47k precedent): do NOT re-issue a WebSearch whose core terms appeared in a prior query THIS session. Rephrase for a new angle OR accept source exhausted and move on
5. **Diminishing-returns check**: if the last search batch yielded zero new grounded claims → stop. Do not probe the same gap from a different query shape indefinitely
6. **Stop criteria** (any fires → stop; otherwise continue):
   (a) every output-template field has a grounded source
   (b) Open Questions list is complete with disposition per entry
   (c) diminishing-returns fired (step 5)
   (d) `token_budget` passed in dispatch prompt is exhausted
7. Record per source: URL, date, key finding, confidence level. Document abandoned branches explicitly: "tried query X — 0 relevant hits, moved on"
8. **No hard cap on rounds** — `.claude/rules/max-quality.md` §1 Full Scope + §6 No Hedging govern. If the Nth batch is what coverage requires, RUN IT. Do NOT return partial w/ "more research needed" as a dodge — that's §6 violation
"""

# Detect Web Research section bounds for sentinel checks (scope the baseline probe to the section)
web_section_re = re.compile(r"### Web Research\n.*?(?=\n### |\n## |\Z)", re.DOTALL)
web_section_match = web_section_re.search(content)
web_section_text = web_section_match.group(0) if web_section_match else ""

if POST_043_WEB_A in web_section_text and POST_043_WEB_B in web_section_text:
    print(f"SKIP: {path} Web Research already patched (043-2c)")
elif BASELINE_WEB not in web_section_text:
    print(f"SKIP_HAND_EDITED: {path} Web Research section has been customized post-bootstrap — baseline sentinel absent. Manual application required. See migrations/043-quick-check-researcher-max-quality.md §Manual-Apply-Guide §Step-2c for the new section content to merge.")
    # DO NOT write; preserve existing content
else:
    # Safe to replace — baseline present, not yet patched.
    new_content, n = web_old_pattern.subn(web_new, content, count=1)
    if n == 0:
        print(f"SKIP_HAND_EDITED: {path} Web Research baseline sentinel present but exact 5-step form did not match — reformatted post-bootstrap. Manual application required. See migrations/043-quick-check-researcher-max-quality.md §Manual-Apply-Guide §Step-2c.")
    else:
        ensure_backup(content)
        content = new_content
        print(f"PATCHED: {path} Web Research (043-2c)")

# ---- (d) Insert Token Budget + Max-Quality Alignment sections BEFORE `## Scope Lock` (additive) ----
scope_anchor = "## Scope Lock"
if "## Token Budget + Coverage Tracking" in content:
    print(f"SKIP: {path} Token Budget + Max-Quality Alignment sections already inserted (043-2d)")
elif scope_anchor not in content:
    print(f"ERROR: {path} missing `{scope_anchor}` anchor — cannot insert Token Budget section safely. Manual application required. See §Manual-Apply-Guide §Step-2d.")
else:
    inserted_sections = """## Token Budget + Coverage Tracking

Dispatch prompt MAY specify `token_budget: <N>` (default: 200_000 when unspecified). Track consumption: `tokens_used = prompt_tokens + completion_tokens + tool_result_tokens`. When used ≥ 80% of budget → wind down: complete current batch, synthesize, write findings. When used ≥ 95% → stop immediately, document gaps, write partial findings w/ explicit coverage report.

Report at top of findings file:
```
token_budget: <N>
tokens_used: <N>
rounds: <N search batches>
file_reads: <N>
web_searches: <N>
open_questions: <N>
```

Published rationale: fountaincity Nov 2025 incident — 4 agents in unbounded research loop = $47,000 before kill. Budget is infrastructure-level safety cap, independent of round count.

## Max-Quality Alignment (per `.claude/rules/max-quality.md`)

This agent produces FULL grounded research. Specific applications:

- **§1 Full Scope** — every requested angle covered. Output template sections (Summary / Patterns Detected / Conventions / Recommendations / Open Questions / Sources) are MANDATORY. Empty section → explicit "None identified" bullet, never silent omit. Per `open-questions-discipline.md` if present (migration 042+); otherwise inline rule: empty section omission = Anti-Hallucination violation
- **§2 Full Implementation** — every claim grounded in evidence (`file:line` OR URL). No `TODO: research later` in delivered findings. `UNVERIFIED` label is acceptable; silent gaps are not
- **§4 Calibrated Effort** — report coverage in observable units (`tokens_used`, `file_reads`, `web_searches`, `rounds`, `open_questions`). Never "more research would be needed" as a dodge for not running it
- **§6 No Hedging** — if you CAN run another batch to close a gap: RUN IT. Don't ask user "want me to continue?" mid-solvable-task. Permission-seeking during coverage = §6 violation. Exception: genuinely `USER_DECIDES` open questions — surface via `## Open Questions` with disposition, don't block on them
- **§7 Output ≠ Instruction token rules** — findings files are OUTPUT. Completeness > token economy. Never compress OUTPUT to save tokens; compress only your own reasoning scratch

**Stopping criterion**: all task questions answered w/ evidence OR surfaced as `USER_DECIDES` in Open Questions. NOT: hit N rounds. NOT: "enough for now". The ONLY acceptable stops are (a)-(d) in Web Research step 6.

"""
    ensure_backup(content)
    content = content.replace(scope_anchor, inserted_sections + scope_anchor, 1)
    print(f"PATCHED: {path} Token Budget + Max-Quality Alignment inserted (043-2d)")

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print(f"DONE: {path}")
PY
```

### Step 3 — Replace Tier 2 block in `.claude/rules/main-thread-orchestrator.md`

Read-before-write with three-tier baseline-sentinel detection (per `general.md` Migration Preservation Discipline):
- idempotency sentinel `Agent selection by task shape` present → `SKIP: already patched`
- baseline sentinel `` `Default: `proj-quick-check` (haiku, fast, cheap, text return `` present (pre-043 stock Tier 2 block with "Default: X ... Escalate to Y" pattern, safe to replace) → `PATCHED`
- neither present → `SKIP_HAND_EDITED` + write `.bak-043` backup if absent + pointer to `## Manual-Apply-Guide §Step-3`. Client customizations preserved.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import os, sys, re
from pathlib import Path

path = ".claude/rules/main-thread-orchestrator.md"
backup = Path(path + ".bak-043")

POST_043_SENTINEL = "Agent selection by task shape"
BASELINE_SENTINEL = "Default: `proj-quick-check` (haiku, fast, cheap, text return"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

if POST_043_SENTINEL in content:
    print(f"SKIP: {path} Tier 2 block already patched (043-3)")
    sys.exit(0)

if BASELINE_SENTINEL not in content:
    print(f"SKIP_HAND_EDITED: {path} Tier 2 block has been customized post-bootstrap — baseline sentinel absent. Manual application required. See migrations/043-quick-check-researcher-max-quality.md §Manual-Apply-Guide §Step-3 for the new Tier 2 block content to merge.")
    # DO NOT write; preserve existing content
    sys.exit(0)

# Safe to replace — baseline present, not yet patched.
# Replace everything from "### Tier 2 — Dispatch (investigation)" up to (exclusive) "### Tier 3"
pattern = re.compile(
    r"### Tier 2 — Dispatch \(investigation\).*?(?=### Tier 3)",
    re.DOTALL,
)

new_tier2 = """### Tier 2 — Dispatch (investigation)
Any "where / how / find / which / what calls / trace / understand / map" question → dispatch, do not investigate on main.

**Agent selection by task shape** (classify BEFORE dispatch — not post-hoc escalation):

- **Single-fact lookups → `proj-quick-check` (haiku)**: symbol existence, single definition location, single-file targeted section read, "does X call Y" (single-direction, single question), file-count existence probe. Text return. NEVER for multi-field enumeration.
- **Multi-field enumeration / mapping / call-graph tracing → `proj-researcher` (sonnet) ALWAYS**: any per-item rows w/ ≥2 fields beyond `file:line`, route inventories, endpoint catalogs, handler/consumer enumerations, end-to-end flow mapping, framework-idiom decoding (FastEndpoints Configure, decorator routing, route DSL), cross-subsystem/cross-project tracing, recall-critical lists where N > ~15. Findings-file return.

Rationale: haiku (200k context, RLHF-calibrated) pattern-completes plausible field values from filenames when evidence commands don't directly surface fields — produces confident-but-partially-fabricated output on composition-heavy tasks (field-value confabulation, not truncation). Published: arxiv 2502.11028 "Mind the Confidence Gap", arxiv 2410.09724 RLHF overconfidence. Sonnet (1M context) grounds each field in source reads. Haiku's speed advantage evaporates on multi-field tasks (observed 13+ min on large enumeration runs in session benchmarks). **Default-to-haiku is a trap for mapping tasks.**

**Escalation paths:**
- `proj-quick-check` returns structured `TASK_SHAPE_MISMATCH` (its self-refusal gate) → orchestrator re-dispatches to `proj-researcher` with same prompt; do NOT Read on main
- `proj-quick-check` return incomplete | cross-file reasoning needed | external web research needed | downstream code-writer will consume → escalate to `proj-researcher`

Multiple sequential `proj-quick-check` calls on related-but-separate sub-questions are fine (in-shape questions only). Parallel: multiple `Agent` calls in one message = parallel foreground dispatch.

No hard dispatch-count limit. Orchestrator weighs dispatch latency (~5–15s per call) vs main-context bloat. Anything involving search, correlation, or pattern recognition across files → dispatch always wins. A single Read of one unrelated file on a known path → Tier 1, direct.

"""

new_content, n = pattern.subn(new_tier2, content, count=1)
if n == 0:
    print(f"SKIP_HAND_EDITED: {path} baseline sentinel present but Tier 2 block shape did not match expected boundaries — reformatted post-bootstrap. Manual application required. See migrations/043-quick-check-researcher-max-quality.md §Manual-Apply-Guide §Step-3.")
    sys.exit(0)

if not backup.exists():
    backup.write_text(content, encoding="utf-8")

with open(path, "w", encoding="utf-8") as f:
    f.write(new_content)
print(f"PATCHED: {path} Tier 2 block (043-3)")
PY
```

### Step 4 — Sync updated `agent-design.md` technique to `.claude/references/techniques/`

Fetch updated technique content from bootstrap repo via `gh api` (follows `general.md` Migrations rule: target `.claude/references/techniques/` for client project layout, NEVER `techniques/` at root). Read-before-write: skip if `## Task-Shape Classification` already present.

```bash
#!/usr/bin/env bash
set -euo pipefail

TECH_PATH=".claude/references/techniques/agent-design.md"
mkdir -p "$(dirname "$TECH_PATH")"

if [[ -f "$TECH_PATH" ]] && grep -q "## Task-Shape Classification" "$TECH_PATH"; then
  echo "SKIP: $TECH_PATH already contains Task-Shape Classification"
  exit 0
fi

# Fetch updated content from bootstrap repo. gh api returns base64-encoded content.
# Owner/repo intentionally unpinned here — downstream projects may have forks; set BOOTSTRAP_REPO env var to override.
BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-tomasfilip/claude-bootstrap}"

python3 <<PY
import base64, json, os, subprocess, sys

repo = "${BOOTSTRAP_REPO}"
tech_path = "${TECH_PATH}"

result = subprocess.run(
    ["gh", "api", f"repos/{repo}/contents/techniques/agent-design.md"],
    capture_output=True, text=True,
)
if result.returncode != 0:
    print(f"ERROR: gh api fetch failed: {result.stderr}")
    sys.exit(1)

payload = json.loads(result.stdout)
content = base64.b64decode(payload["content"]).decode("utf-8")

if "## Task-Shape Classification" not in content:
    print(f"ERROR: fetched agent-design.md does not contain Task-Shape Classification section — bootstrap repo not at the expected version")
    sys.exit(1)

os.makedirs(os.path.dirname(tech_path), exist_ok=True)
with open(tech_path, "w", encoding="utf-8") as f:
    f.write(content)
print(f"PATCHED: {tech_path} (synced from {repo})")
PY
```

### Step 5 — Update `.claude/bootstrap-state.json`

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '043'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '043') or a == '043' for a in applied):
    applied.append({
        'id': '043',
        'applied_at': state['last_applied'],
        'description': 'Quick-check self-refusal gate + per-field evidence contract + researcher max-quality uncap w/ dedup + token_budget + framework-idiom guard. Tier 2 orchestrator classifier. Agent-design task-shape taxonomy.'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=043')
PY
```

### Rules for migration scripts

- **Read-before-write** — every patch step reads the target file, detects an existing marker, and only writes on change.
- **Idempotent** — re-running prints `SKIP: already patched` per file and `SKIP: migration 043 already applied` at the top.
- **Self-contained** — all new content inlined in python3 heredocs; sole external dependency is `gh api` for the technique sync (required per `general.md` — techniques updated via bootstrap repo fetch, never inlined).
- **No gitignored-path fetch** — the migration fetches from the bootstrap repo's TRACKED `techniques/` directory, NOT its gitignored `.claude/`.
- **Technique sync targets client layout** — writes to `.claude/references/techniques/agent-design.md`, NOT `techniques/` at the client project root (per `general.md` Migrations rule + `modules/02-project-config.md` Step 5).
- **Abort on error** — `set -euo pipefail` in every bash block; python3 blocks exit non-zero on failure.
- **Scope lock** — touches only: `.claude/agents/proj-quick-check.md`, `.claude/agents/proj-researcher.md`, `.claude/rules/main-thread-orchestrator.md`, `.claude/references/techniques/agent-design.md`, `.claude/bootstrap-state.json`. No hook changes, no settings edits, no agent renames. `migrations/index.json` is appended BY MAIN THREAD outside this migration body (per `agent-scope-lock.md`).

---

## Verify

```bash
#!/usr/bin/env bash
set +e
fail=0

# 1. proj-quick-check.md carries Task-Shape Self-Refusal Gate
if grep -q "^## Task-Shape Self-Refusal Gate" .claude/agents/proj-quick-check.md 2>/dev/null; then
  echo "PASS: proj-quick-check.md contains Task-Shape Self-Refusal Gate"
else
  echo "FAIL: proj-quick-check.md missing Task-Shape Self-Refusal Gate"
  fail=1
fi

# 2. proj-quick-check.md carries Per-Field Evidence Contract
if grep -q "^## Per-Field Evidence Contract" .claude/agents/proj-quick-check.md 2>/dev/null; then
  echo "PASS: proj-quick-check.md contains Per-Field Evidence Contract"
else
  echo "FAIL: proj-quick-check.md missing Per-Field Evidence Contract"
  fail=1
fi

# 3. proj-quick-check.md carries Output Schema heading
if grep -q "^## Output Schema" .claude/agents/proj-quick-check.md 2>/dev/null; then
  echo "PASS: proj-quick-check.md contains Output Schema"
else
  echo "FAIL: proj-quick-check.md missing Output Schema"
  fail=1
fi

# 4. proj-quick-check.md carries fabrication-guard bullet
if grep -q "Fabrication guard: never derive a field from a filename" .claude/agents/proj-quick-check.md 2>/dev/null; then
  echo "PASS: proj-quick-check.md contains fabrication-guard bullet"
else
  echo "FAIL: proj-quick-check.md missing fabrication-guard bullet"
  fail=1
fi

# 5. proj-researcher.md carries Token Budget + Coverage Tracking
if grep -q "^## Token Budget + Coverage Tracking" .claude/agents/proj-researcher.md 2>/dev/null; then
  echo "PASS: proj-researcher.md contains Token Budget + Coverage Tracking"
else
  echo "FAIL: proj-researcher.md missing Token Budget + Coverage Tracking"
  fail=1
fi

# 6. proj-researcher.md carries maxTurns: 200
if grep -qE "^maxTurns:\s*200\s*$" .claude/agents/proj-researcher.md 2>/dev/null; then
  echo "PASS: proj-researcher.md frontmatter maxTurns: 200"
else
  echo "FAIL: proj-researcher.md missing maxTurns: 200"
  fail=1
fi

# 7. proj-researcher.md no longer carries `Maximum 2 search rounds total`
if ! grep -q "Maximum 2 search rounds total" .claude/agents/proj-researcher.md 2>/dev/null; then
  echo "PASS: proj-researcher.md no longer carries hard round cap"
else
  echo "FAIL: proj-researcher.md still contains 'Maximum 2 search rounds total'"
  fail=1
fi

# 8. proj-researcher.md carries framework-idiom guard
if grep -q "Framework-idiom guard" .claude/agents/proj-researcher.md 2>/dev/null; then
  echo "PASS: proj-researcher.md contains Framework-idiom guard"
else
  echo "FAIL: proj-researcher.md missing Framework-idiom guard"
  fail=1
fi

# 9. main-thread-orchestrator.md carries task-shape classifier
if grep -q "Agent selection by task shape" .claude/rules/main-thread-orchestrator.md 2>/dev/null; then
  echo "PASS: main-thread-orchestrator.md contains task-shape classifier"
else
  echo "FAIL: main-thread-orchestrator.md missing task-shape classifier"
  fail=1
fi

# 10. agent-design.md technique synced w/ Task-Shape Classification section
if [[ -f ".claude/references/techniques/agent-design.md" ]] && \
   grep -q "^## Task-Shape Classification" .claude/references/techniques/agent-design.md; then
  echo "PASS: .claude/references/techniques/agent-design.md contains Task-Shape Classification"
else
  echo "FAIL: .claude/references/techniques/agent-design.md missing Task-Shape Classification"
  fail=1
fi

# 10b. agent-design.md maxTurns table reflects proj-researcher = 200
if [[ -f ".claude/references/techniques/agent-design.md" ]] && \
   grep -qE '\|\s*proj-researcher\s*\|\s*200\s*\|' .claude/references/techniques/agent-design.md; then
  echo "PASS: .claude/references/techniques/agent-design.md maxTurns table shows proj-researcher = 200"
else
  printf "FAIL: agent-design.md maxTurns table does not reflect proj-researcher=200\n"
  fail=1
fi

# 11. YAML frontmatter parses for both agents
for agent in .claude/agents/proj-quick-check.md .claude/agents/proj-researcher.md; do
  if python3 -c "
import sys, yaml
with open('$agent') as f:
    parts = f.read().split('---')
if len(parts) < 3:
    sys.exit(1)
yaml.safe_load(parts[1])
" 2>/dev/null; then
    echo "PASS: $agent YAML frontmatter parses"
  else
    echo "FAIL: $agent YAML frontmatter invalid"
    fail=1
  fi
done

# 12. bootstrap-state.json updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "043" ]]; then
  echo "PASS: last_migration = 043"
else
  echo "FAIL: last_migration = $last (expected 043)"
  fail=1
fi

echo "---"
if [[ $fail -eq 0 ]]; then
  echo "Migration 043 verification: ALL PASS"
else
  echo "Migration 043 verification: FAILURES — state NOT updated"
  exit 1
fi
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix.

---

## State Update

On success:
- `last_migration` → `"043"`
- append `{ "id": "043", "applied_at": "<ISO8601>", "description": "Quick-check self-refusal gate + per-field evidence contract + researcher max-quality uncap w/ dedup + token_budget + framework-idiom guard. Tier 2 orchestrator classifier. Agent-design task-shape taxonomy." }` to `applied[]`

---

## Rollback

Restore the four patched files from version control or companion-repo snapshot:

```bash
#!/usr/bin/env bash
# Tracked strategy (files committed to project repo)
git checkout -- \
  .claude/agents/proj-quick-check.md \
  .claude/agents/proj-researcher.md \
  .claude/rules/main-thread-orchestrator.md \
  .claude/references/techniques/agent-design.md

# Companion strategy — restore from companion repo snapshot
# cp ~/.claude-configs/<project>/.claude/agents/proj-quick-check.md ./.claude/agents/
# cp ~/.claude-configs/<project>/.claude/agents/proj-researcher.md ./.claude/agents/
# cp ~/.claude-configs/<project>/.claude/rules/main-thread-orchestrator.md ./.claude/rules/
# cp ~/.claude-configs/<project>/.claude/references/techniques/agent-design.md ./.claude/references/techniques/
```

Then manually reset `last_migration` in `.claude/bootstrap-state.json` to `"042"` and remove the `043` entry from `applied[]`.

The migration is an in-place section replacement + injection across four files. Rollback via `git checkout` is safe provided the files were tracked before apply.

---

## Post-Migration (main-thread only per agent-scope-lock.md)

Append to `migrations/index.json`:
```json
{
  "id": "043",
  "file": "migrations/043-quick-check-researcher-max-quality.md",
  "description": "Quick-check self-refusal gate + per-field evidence contract + researcher max-quality uncap w/ dedup + token_budget + framework-idiom guard. Tier 2 orchestrator classifier. Agent-design task-shape taxonomy."
}
```

---

## Manual-Apply-Guide

When a destructive step reports `SKIP_HAND_EDITED: ...`, the migration detected that the target section was customized post-bootstrap (baseline sentinel absent + post-migration sentinel absent). Automatic patching is unsafe — content would be lost. This guide provides the verbatim new-content blocks plus merge instructions so you can manually integrate the new discipline while preserving your customizations.

**General procedure per skipped step**:
1. Open the target file.
2. Locate the section named in the step (heading in the file).
3. Read the new content block below for that step.
4. Manually merge: preserve your project-specific additions (extra bullets, custom examples, stop criteria tweaks, framework-specific guidance); incorporate the new structural discipline (max-quality alignment, framework-idiom guard, dedup rule, token budget, task-shape classifier).
5. Save the file.
6. Run the verification command shown at the end of each step-specific subsection.
7. A `.bak-043` backup of the pre-migration file state exists at `<path>.bak-043` if the migration wrote one; use `diff <path>.bak-043 <path>` to see exactly what the migration would have overwritten.

Step-specific new-content blocks follow, one subsection per destructive step.

---

### §Step-1 — `proj-quick-check.md` Self-Refusal Gate + Per-Field Evidence Contract + Output Schema

**Target**: `.claude/agents/proj-quick-check.md` — insert new sections BETWEEN `## Out of Scope` and `## Anti-Hallucination`; append fabrication-guard bullet to existing `## Anti-Hallucination` list.

**New content (verbatim, insert before `## Anti-Hallucination`)**:

```markdown
## Task-Shape Self-Refusal Gate

Before executing, classify task shape. **REFUSE** + return structured `TASK_SHAPE_MISMATCH` when ANY of these triggers holds:

1. **Composition required** — fields compose from ≥2 files (e.g., route = group-prefix file + method-body file concatenation)
2. **Cross-subsystem mapping** — spans multiple projects, layers, execution models (e.g., "end-to-end flow across API + Workers + DB")
3. **Framework-idiom decoding** — answer requires framework convention knowledge (FastEndpoints `Configure()`, decorator routing, Rails routes.rb, Hono `.get()` chains, Django URLconf, Spring `@RequestMapping`) where plain Grep doesn't surface the field values
4. **Recall-critical enumeration where N > ~15** — large lists where silent truncation = correctness risk

Rationale: haiku pattern-completes plausible field values from filenames/base-paths when evidence commands don't directly produce the field. Confident-wrong > refuse. Sonnet (`proj-researcher`) grounds each field in source reads. Published evidence: arxiv 2502.11028 "Mind the Confidence Gap" — smaller models fail to meaningfully estimate uncertainty; arxiv 2410.09724 — RLHF-induced systematic overconfidence, amplified in smaller models.

**Refusal format** (verbatim — DO NOT paraphrase):
` ` `
TASK_SHAPE_MISMATCH
{
  "status": "TASK_SHAPE_MISMATCH",
  "trigger": "composition | cross-subsystem | framework-idiom | recall-N>15",
  "escalate_to": "proj-researcher",
  "reason": "<one sentence why this trigger fired>"
}
` ` `

Do NOT partial-answer. Do NOT "do the easy ones, skip the rest". Refuse cleanly — main thread re-dispatches to researcher.

**Note on multi-field tasks:** Pure multi-field enumeration with ≤15 items AND no composition / cross-subsystem / framework-idiom characteristics is IN-SHAPE for this agent — use the Per-Field Evidence Contract below. The triggers above target the failure modes (field composition from multiple files, idiom decoding, large-N recall) where haiku confabulates. Small simple lists with evidence grounding are safe.

**In-shape examples (proceed):**
- "Where is `PermissionService` defined?"
- "Does `IUserRepository` exist? Interface file?"
- "Read lines 40–80 of `Program.cs`"
- "What calls `CheckPermission`?" (single-direction, single question — delegate to MCP find_referencing_symbols)
- "List 8 error types with their catch-location file:line + exception class (≤15 items, no composition)"

**Out-of-shape examples (REFUSE):**
- "List every HTTP endpoint with route + verb" — multi-field + framework-idiom
- "Map permission-granting end-to-end" — cross-subsystem
- "Enumerate all event handlers with topic + class + retry policy" — composition + large N

## Per-Field Evidence Contract (enumeration mode)

When a task is multi-field enumeration with ≤15 items AND does NOT match any self-refusal trigger (composition / cross-subsystem / framework-idiom / N>15), use JSON output mode w/ this per-row schema. Each row MUST include:

` ` `json
{
  "<field_name>": {
    "value": "<extracted value>",
    "evidence": {
      "tool": "<Read | Grep | mcp__serena__find_symbol | mcp__codebase-memory-mcp__get_code_snippet | etc.>",
      "query": "<exact command / tool args>",
      "raw_result_line": "<verbatim line from tool output>"
    },
    "confidence": "HIGH | MEDIUM | LOW | UNKNOWN"
  }
}
` ` `

Fields without grounded evidence MUST be marked `"value": null, "confidence": "UNKNOWN"`. Never infer from filenames, base-path constants, or class names. Inference = fabrication.

Published support: Lakera (2026) span-level verification; MDPI (2025) post-generation quality control in multi-agent RAG; arxiv 2502.11028 — structured output improves smaller-model calibration.

## Output Schema (enumeration-mode returns only)

This schema applies to enumeration-mode returns (multi-field JSON via the Per-Field Evidence Contract above). Single-fact lookup returns use the simpler form: direct answer + `file:line` evidence + one-line confidence note. Do NOT emit the full schema for "where is X defined" style queries — that is token waste.

` ` `
RESULT_COUNT: <N>
RAW_EVIDENCE:
  tool_call: <exact command or MCP call>
  raw_stdout_lines: <N from command>
  delta_vs_result_count: <signed integer>
CONFIDENCE_DISTRIBUTION:
  HIGH: <N>
  MEDIUM: <N>
  LOW: <N>
  UNKNOWN: <N>
COVERAGE_GAPS:
  - <field or scope NOT searched — empty list requires positive enumeration of what WAS searched>
TRUNCATED: <YES | NO>
` ` `

`TRUNCATED: NO` is NOT a default — it requires evidence (count match OR explicit exhaustive-scope statement). Default-NO on uncertain coverage = calibration failure per arxiv 2510.26995 FermiEval.

## Max-Quality Alignment (per `.claude/rules/max-quality.md`)

- **§1 Full Scope** — answer every listed field. Never "for brevity" skip rows. `UNKNOWN` is valid; silent omission is not
- **§4 Calibrated Effort** — report coverage in observable units (RESULT_COUNT, raw_stdout_lines, fields_with_UNKNOWN count)
- **§6 No Hedging** — if task is in-shape: solve. If task is out-of-shape: refuse via self-refusal gate. Never "partial answer + see researcher for rest" — that's a hedge
- **§7 Output ≠ Instruction token rules** — your RETURN is OUTPUT. Completeness > brevity. Never elide rows, never truncate schema fields
```

**Fabrication-guard bullet (verbatim, append to existing `## Anti-Hallucination` list after the `Never answer from training data` bullet)**:

```markdown
- Fabrication guard: never derive a field from a filename, class name, or base-path constant. If the evidence command produced a count but not the field's value → return `UNKNOWN` for that field OR run a second command that does produce it. Filename-inference = fabrication (arxiv 2504.17550 HalluLens intrinsic-hallucination taxonomy)
```

**Note on the triple-backtick fences inside the blocks above**: the literal fenced code blocks are shown with spaces inside the fence markers (` ` ` instead of ` ``` `) only to keep THIS guide's own markdown parseable. When you paste into `proj-quick-check.md`, REMOVE those spaces so the fences are real ` ``` ` markers.

**Merge instructions**: this is an INSERT (additive), not a replace, so the migration does not emit `SKIP_HAND_EDITED` for Step 1 — it either patches successfully or errors on the missing `## Anti-Hallucination` anchor. Use this subsection if the anchor is missing OR if you want to review the exact verbatim content being inserted. If your file already customized `## Anti-Hallucination` (e.g. added project-specific fabrication-guard bullets), keep your bullets and append the new fabrication-guard bullet alongside them.

**Verification**: `grep -q '^## Task-Shape Self-Refusal Gate' .claude/agents/proj-quick-check.md && grep -q '^## Per-Field Evidence Contract' .claude/agents/proj-quick-check.md && grep -q '^## Output Schema' .claude/agents/proj-quick-check.md && grep -q 'Fabrication guard: never derive a field' .claude/agents/proj-quick-check.md && echo OK`

---

### §Step-2a — `proj-researcher.md` frontmatter `maxTurns`

**Target**: `.claude/agents/proj-researcher.md` (YAML frontmatter, `maxTurns:` field)

**New value**: `maxTurns: 200`

**Merge instructions**: the migration bumps `maxTurns: 100` → `maxTurns: 200`. If your customization set a different value (e.g. `maxTurns: 150`), keep your value OR adopt 200 based on your own policy on researcher run length. The new Token Budget + Coverage Tracking section (inserted by Step 2d) provides a higher-resolution safety cap than maxTurns alone — with the token_budget in place, `maxTurns: 200` is a reasonable upper bound for nearly all research tasks.

**Verification**: `grep -E '^maxTurns:' .claude/agents/proj-researcher.md`

---

### §Step-2b — `proj-researcher.md` `### Local Codebase Analysis` section

**Target**: `.claude/agents/proj-researcher.md` — the `### Local Codebase Analysis` subsection under the Research Process / Workflow section.

**New content (verbatim, replace existing `### Local Codebase Analysis` block through the line before `### Web Research`)**:

```markdown
### Local Codebase Analysis
1. Route code discovery through `.claude/rules/mcp-routing.md` action→tool table FIRST (cmm/serena when available); Glob/Grep/Read are fallback
2. Read representative files per layer — at least ONE example per detected layer; depth governed by task, not by round-cap
3. Map architecture: layers, dependencies, data flow — trace until endpoint / DB / storage / external-call boundary
4. Identify conventions: file naming, code style, framework idioms — cite `file:line` per convention
5. **Framework-idiom guard**: for codebases using convention-over-configuration frameworks (FastEndpoints, Rails, Django, Spring, NestJS, Hono decorators, Azure Functions attributes, etc.) — BEFORE enumerating entities, locate the framework's resolution mechanism (`Configure()` bodies, route-table builder, DI registration, middleware pipeline). Read THAT mechanism's source. Never infer entity properties (routes, handlers, topics) from filenames or base-path constants. Filename-inference = fabrication (arxiv 2504.17550 HalluLens intrinsic-hallucination taxonomy)
6. No hard cap on tool calls — `.claude/rules/max-quality.md` §1 governs. Run as many Reads/Greps/MCP queries as coverage requires. Parallel-batch per `<use_parallel_tool_calls>` for efficiency
```

**Merge instructions**: the pre-043 form was a 5-step workflow ("Glob for file patterns → understand project structure", "Read representative files per layer/component type", "Grep for patterns", "Map architecture", "Identify conventions"). The new form keeps that 5-step structure but (a) routes through `mcp-routing.md` first (step 1), (b) adds the **Framework-idiom guard** (step 5), and (c) makes the no-hard-cap stance explicit (step 6). If your customizations added project-specific discovery bullets (e.g. "Also check .env for env-var conventions"), preserve them as additional numbered steps AFTER step 6 — or inline under the nearest matching step. If you had framework-specific guidance already (e.g. "always read `routes.rb` first for Rails"), it is compatible with and reinforced by the new Framework-idiom guard — keep it as a concrete example under step 5.

**Verification**: `grep -q 'Framework-idiom guard' .claude/agents/proj-researcher.md && echo OK`

---

### §Step-2c — `proj-researcher.md` `### Web Research` section

**Target**: `.claude/agents/proj-researcher.md` — the `### Web Research` subsection (follows `### Local Codebase Analysis`).

**New content (verbatim, replace existing `### Web Research` block through the line before the next `###` or `##` heading)**:

```markdown
### Web Research
1. Plan all searches before executing — identify gaps first
2. Batch WebSearch calls in ONE message (parallel — no artificial round cap)
3. After each batch, identify remaining gaps → continue batching until coverage complete OR gaps are irreducibly uncertain (training-cutoff, source-unavailable, task-ambiguous)
4. **Dedup rule** (prevents runaway cost — fountaincity Nov 2025 $47k precedent): do NOT re-issue a WebSearch whose core terms appeared in a prior query THIS session. Rephrase for a new angle OR accept source exhausted and move on
5. **Diminishing-returns check**: if the last search batch yielded zero new grounded claims → stop. Do not probe the same gap from a different query shape indefinitely
6. **Stop criteria** (any fires → stop; otherwise continue):
   (a) every output-template field has a grounded source
   (b) Open Questions list is complete with disposition per entry
   (c) diminishing-returns fired (step 5)
   (d) `token_budget` passed in dispatch prompt is exhausted
7. Record per source: URL, date, key finding, confidence level. Document abandoned branches explicitly: "tried query X — 0 relevant hits, moved on"
8. **No hard cap on rounds** — `.claude/rules/max-quality.md` §1 Full Scope + §6 No Hedging govern. If the Nth batch is what coverage requires, RUN IT. Do NOT return partial w/ "more research needed" as a dodge — that's §6 violation
```

**Merge instructions**: the pre-043 form had 5 steps with a HARD `Maximum 2 search rounds total` cap (step 4). The new form removes that cap and replaces it with four structural guards: Dedup rule (step 4), Diminishing-returns check (step 5), explicit Stop criteria (step 6), and `token_budget` safety cap (referenced in step 6d — the actual budget mechanism is defined in the Token Budget + Coverage Tracking section inserted by Step 2d). If your customization ADDED a stop criterion (e.g. "stop after 3 rounds on cost-sensitive tasks"), merge it into step 6 as an additional `(e)` clause — don't just re-impose a hard round cap. If your customization added a source-quality rule (e.g. "prefer docs.X.com over blog posts"), preserve it as an additional numbered step after step 7 or as a sub-bullet under step 7.

**Verification**: `grep -q 'Dedup rule' .claude/agents/proj-researcher.md && grep -q 'token_budget' .claude/agents/proj-researcher.md && echo OK`

---

### §Step-2d — `proj-researcher.md` Token Budget + Max-Quality Alignment insertion

**Target**: `.claude/agents/proj-researcher.md` — insert new sections BEFORE the existing `## Scope Lock` heading.

**New content (verbatim, insert before `## Scope Lock`)**:

```markdown
## Token Budget + Coverage Tracking

Dispatch prompt MAY specify `token_budget: <N>` (default: 200_000 when unspecified). Track consumption: `tokens_used = prompt_tokens + completion_tokens + tool_result_tokens`. When used ≥ 80% of budget → wind down: complete current batch, synthesize, write findings. When used ≥ 95% → stop immediately, document gaps, write partial findings w/ explicit coverage report.

Report at top of findings file:
` ` `
token_budget: <N>
tokens_used: <N>
rounds: <N search batches>
file_reads: <N>
web_searches: <N>
open_questions: <N>
` ` `

Published rationale: fountaincity Nov 2025 incident — 4 agents in unbounded research loop = $47,000 before kill. Budget is infrastructure-level safety cap, independent of round count.

## Max-Quality Alignment (per `.claude/rules/max-quality.md`)

This agent produces FULL grounded research. Specific applications:

- **§1 Full Scope** — every requested angle covered. Output template sections (Summary / Patterns Detected / Conventions / Recommendations / Open Questions / Sources) are MANDATORY. Empty section → explicit "None identified" bullet, never silent omit. Per `open-questions-discipline.md` if present (migration 042+); otherwise inline rule: empty section omission = Anti-Hallucination violation
- **§2 Full Implementation** — every claim grounded in evidence (`file:line` OR URL). No `TODO: research later` in delivered findings. `UNVERIFIED` label is acceptable; silent gaps are not
- **§4 Calibrated Effort** — report coverage in observable units (`tokens_used`, `file_reads`, `web_searches`, `rounds`, `open_questions`). Never "more research would be needed" as a dodge for not running it
- **§6 No Hedging** — if you CAN run another batch to close a gap: RUN IT. Don't ask user "want me to continue?" mid-solvable-task. Permission-seeking during coverage = §6 violation. Exception: genuinely `USER_DECIDES` open questions — surface via `## Open Questions` with disposition, don't block on them
- **§7 Output ≠ Instruction token rules** — findings files are OUTPUT. Completeness > token economy. Never compress OUTPUT to save tokens; compress only your own reasoning scratch

**Stopping criterion**: all task questions answered w/ evidence OR surfaced as `USER_DECIDES` in Open Questions. NOT: hit N rounds. NOT: "enough for now". The ONLY acceptable stops are (a)-(d) in Web Research step 6.
```

**Note on the triple-backtick fence inside the block above**: the literal fenced code block (` ```\ntoken_budget: <N>\n... \n``` `) is shown with spaces inside the fence markers in this guide (` ` ` instead of ` ``` `) only to keep THIS guide's own markdown parseable. When you paste into `proj-researcher.md`, REMOVE those spaces so the fence is a real ` ``` ` marker.

**Note on the blank line before `## Scope Lock`**: when you paste the block above, make sure a blank line separates the final `**Stopping criterion**: ...` line from the existing `## Scope Lock` heading below it. Adjacent headings without a blank line violate `code-standards-markdown.md` structural rules.

**Merge instructions**: this is an INSERT (additive), not a replace. If your file already has a `## Token Budget + Coverage Tracking` section, the migration skipped this step. If not, paste the block above immediately before the existing `## Scope Lock` heading. If your file lacks a `## Scope Lock` heading (customization), insert at the bottom of the file instead.

**Verification**: `grep -q '^## Token Budget + Coverage Tracking' .claude/agents/proj-researcher.md && grep -q '^## Max-Quality Alignment' .claude/agents/proj-researcher.md && echo OK`

---

### §Step-3 — `main-thread-orchestrator.md` Tier 2 block

**Target**: `.claude/rules/main-thread-orchestrator.md` — the `### Tier 2 — Dispatch (investigation)` subsection (part of `## Tiers`).

**New content (verbatim, replace existing `### Tier 2 — Dispatch (investigation)` block through the line before `### Tier 3`)**:

```markdown
### Tier 2 — Dispatch (investigation)
Any "where / how / find / which / what calls / trace / understand / map" question → dispatch, do not investigate on main.

**Agent selection by task shape** (classify BEFORE dispatch — not post-hoc escalation):

- **Single-fact lookups → `proj-quick-check` (haiku)**: symbol existence, single definition location, single-file targeted section read, "does X call Y" (single-direction, single question), file-count existence probe. Text return. NEVER for multi-field enumeration.
- **Multi-field enumeration / mapping / call-graph tracing → `proj-researcher` (sonnet) ALWAYS**: any per-item rows w/ ≥2 fields beyond `file:line`, route inventories, endpoint catalogs, handler/consumer enumerations, end-to-end flow mapping, framework-idiom decoding (FastEndpoints Configure, decorator routing, route DSL), cross-subsystem/cross-project tracing, recall-critical lists where N > ~15. Findings-file return.

Rationale: haiku (200k context, RLHF-calibrated) pattern-completes plausible field values from filenames when evidence commands don't directly surface fields — produces confident-but-partially-fabricated output on composition-heavy tasks (field-value confabulation, not truncation). Published: arxiv 2502.11028 "Mind the Confidence Gap", arxiv 2410.09724 RLHF overconfidence. Sonnet (1M context) grounds each field in source reads. Haiku's speed advantage evaporates on multi-field tasks (observed 13+ min on large enumeration runs in session benchmarks). **Default-to-haiku is a trap for mapping tasks.**

**Escalation paths:**
- `proj-quick-check` returns structured `TASK_SHAPE_MISMATCH` (its self-refusal gate) → orchestrator re-dispatches to `proj-researcher` with same prompt; do NOT Read on main
- `proj-quick-check` return incomplete | cross-file reasoning needed | external web research needed | downstream code-writer will consume → escalate to `proj-researcher`

Multiple sequential `proj-quick-check` calls on related-but-separate sub-questions are fine (in-shape questions only). Parallel: multiple `Agent` calls in one message = parallel foreground dispatch.

No hard dispatch-count limit. Orchestrator weighs dispatch latency (~5–15s per call) vs main-context bloat. Anything involving search, correlation, or pattern recognition across files → dispatch always wins. A single Read of one unrelated file on a known path → Tier 1, direct.

```

**Merge instructions**: the pre-043 form had a "Default: `proj-quick-check` + Escalate to `proj-researcher`" post-hoc escalation pattern. The new form classifies BEFORE dispatch: single-fact → quick-check; multi-field/mapping/call-graph → researcher ALWAYS. If your customization added project-specific routing rules (e.g. "all GraphQL questions → researcher", "all test-file-existence questions → quick-check"), fold them into the "Agent selection by task shape" list as extra bullets under the appropriate tier. If your customization adjusted the quick-check / researcher split boundary (e.g. lowered the recall-critical threshold from 15 to 10), preserve your boundary in the list.

**Verification**: `grep -q 'Agent selection by task shape' .claude/rules/main-thread-orchestrator.md && echo OK`

---

## Scope Lock

Touches ONLY: `.claude/agents/proj-quick-check.md`, `.claude/agents/proj-researcher.md`, `.claude/rules/main-thread-orchestrator.md`, `.claude/references/techniques/agent-design.md`, `.claude/bootstrap-state.json`. No `migrations/index.json` touch inside migration body (main-thread step per `agent-scope-lock.md`).
