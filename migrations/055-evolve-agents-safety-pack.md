# Migration 055 — /evolve-agents Safety Pack

<!-- migration-id: 055-evolve-agents-safety-pack -->

> Bundled `/evolve-agents` safety pack: (1) frontmatter `disable-model-invocation: true` blocks model auto-trigger of the consequential creation pipeline; (2) Phase 1 audit-artifact persistence (`.claude/reports/evolve-agents-audit-latest.md` w/ `## Gate Complete` token) + Phase 3 pre-flight gate (`find -newer` freshness check; sentinel `<!-- evolve-agents-gate-installed -->`) for evidence-grounded creation discipline; (3) reference-file pattern via `agent-creation-brief.md` consumed by `proj-code-writer-markdown`'s amended Before Writing block (5→7 steps + duplicate-2 fix; new step 5 enforces dispatch-prompt `#### Reference Files` reads); (4) spec-fidelity audit via `covers-skill:` YAML frontmatter convention + `audit-agents` A10 invariant. Coordinated A9 (1.1 gate audit) + A10 (1.3 spec-fidelity audit) added to `audit-agents/SKILL.md` after the existing A8 wave-protocol checks. Two new rule files: `evolve-agents-gate.md` + `spec-fidelity.md` (defensive `cp` from `templates/rules/`). Two spec frontmatter backfills (`covers-skill: evolve-agents`, `covers-skill: deep-think`). One Deviations block append documenting v6 paradigm + Step 3/Step 6 absences (INTENTIONAL classification). Per-step three-tier detection (idempotency sentinel / baseline anchor / `SKIP_HAND_EDITED` + `.bak-055` backup + `## Manual-Apply-Guide` pointer); 4-state outer idempotency. Glob discovery for the deep-think spec filename. Self-contained heredocs for all embedded content per `general.md`.

---

## Metadata

```yaml
id: "055"
breaking: false
affects: [skills, agents, rules, specs]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Field-observed assessment of `/evolve-agents` (deployed since 2026-04-01, zero execution history as of 2026-04-27 deep-think) surfaced four coordinated concerns that the deep-think process resolved into a single coordinated migration package:

1. **Invocation safety** — the skill creates agent files (consequential, multi-dispatch, opus+xhigh). It lacks `disable-model-invocation: true` in frontmatter, so the model can auto-trigger the creation pipeline from natural-language matches in conversation. No mechanism prevents accidental invocation of a consequential creation pipeline.

2. **Evidence-grounding gap** — Phase 1 (audit) feeds Phase 3 (create) inline through dispatched-agent return text only. No persistent artifact survives between phases. Phase 3 can run without prior audit evidence — "create now, audit never" is the current shape; nothing forces evidence-grounded creation discipline.

3. **Spec-vs-implementation drift** — the original spec described 6 steps with a user-approval gate (Step 3) and explicit wiring (Step 6); the deployed skill has 5 phases with neither. The v6 paradigm shift ("create-NEW not split") was present in the very first commit but never documented as a deviation. No mechanism exists at any skill class level to detect or document this kind of drift in any skill backed by a spec.

4. **Phase 3 dispatch quality** — the deployed Phase 3 consolidates research + code-writer dispatches without a structured reference-file pattern. Domain knowledge for sub-specialist agent creation is not encapsulated anywhere — every Phase 3 dispatch starts from scratch, and the consuming code-writer agent has no mechanism to load agent-creation domain rules consistently.

Pre-output exploration found two related contributing failure modes:

- **`proj-code-writer-markdown` Before Writing block defects** — pre-migration body had 5 steps with a duplicate `2.` numbering bug AND no mechanism to handle dispatch-prompt-supplied reference files, so even if `/evolve-agents` Phase 3 were updated to pass a reference file, the consuming agent would not reliably read it.
- **No project-wide convention for spec-vs-skill traceability** — specs and the skills they implement are not linked in either direction; downstream audit-time drift detection is impossible without a backward link from spec → skill.

The migration ships the four fixes as a coordinated bundle because their three-tier-detection sentinels overlap on the same `evolve-agents/SKILL.md` file (a fragmented split would create sentinel collisions and leave the skill in inconsistent intermediate states across batches).

---

## Rationale

1. **Bundle 4 proposals into a single migration** — Batches 0-4 in the implementation plan apply the changes in dependency order (Batch 0 = pre-condition for Batch 2; Batch 1 = additive parallel-safe; Batch 2 = SKILL.md combined patch; Batch 3 = rule + audit; Batch 4 = backfill). Splitting across migrations would create sentinel collisions on the same SKILL.md file across multiple migration apply windows, which violates three-tier detection invariants. A single migration with one combined SKILL.md patch (sentinel `<!-- evolve-agents-gate-installed -->`) avoids the collision class entirely.

2. **Phase 1 audit artifact uses stable filename, not timestamp glob** — `find -newer` against `.claude/reports/evolve-agents-audit-latest.md` is structurally simpler and avoids `ls -t | head -1` race conditions. The trailing `## Gate Complete` heading is the artifact-integrity token (Phase 3 gate greps for it; truncated writes fail the gate). Stable filename also enables idempotent re-runs without artifact accretion.

3. **`disable-model-invocation: true` is the frontmatter-level invocation safety mechanism** — current Claude Code spec interprets the field on skills; presence blocks model-driven natural-language matches (model cannot invoke the skill via conversation) while preserving explicit user `/evolve-agents` slash invocation. It is the structurally-correct gate: a hard-coded skill body refusal is bypassable; a frontmatter-level field is enforced by the orchestrator.

4. **Reference-file pattern via `agent-creation-brief.md` keeps the dispatched agent generic** — instead of a new agent specialized for sub-specialist creation, the existing `proj-code-writer-markdown` consumes a structured brief passed via dispatch-prompt `#### Reference Files` block. The brief encapsulates agent-creation domain knowledge (frontmatter, body skeleton, conformance checklist, anti-patterns) once. Net agent count unchanged. Per `techniques/agent-design.md:22` (subagents cannot spawn subagents), a new "agent-creation orchestrator" agent would have been impossible anyway.

5. **A9 + A10 ship together as coordinated audit additions** — A9 audits 1.1's evolve-agents gate; A10 audits 1.3's spec-fidelity convention. Both extend `audit-agents/SKILL.md` after the existing A8 wave-protocol checks. Single sentinel (`<!-- audit-agents-A9-A10-installed -->`) covers both. Adding them in separate migrations would create the same sentinel-collision class as the SKILL.md split.

6. **Spec frontmatter `covers-skill:` is single-value v1, awk-extractable** — the YAML field is parsed via a counter-based awk pattern that terminates at the second `---` unconditionally, so body-level `---` lines cannot reactivate frontmatter scanning. Multi-value form `covers-skill: [a, b]` is deferred to future-work because the v1 awk extraction returns malformed `[a,` for list form. Backfill targets the two specs known to have backing skills (evolve-agents, deep-think); future spec emissions from `/brainstorm` and `/deep-think` carry the convention forward.

7. **`templates/rules/*.md` → `.claude/rules/*.md` defensive copy** — per the spec's open question OQ-templates-rules-vs-rules-sync resolution, this migration includes explicit `cp` steps for the two new rule files instead of relying on Module 06 fetch-loop auto-sync. Defensive belt-and-suspenders posture: rule files become available even on clients that haven't run a fresh Module 06 sync since the templates were added.

8. **Deviations block is additive (sentinel-only) but documents intent** — the v6 paradigm shift and Step 3 / Step 6 absences are classified INTENTIONAL per the deep-think 1.3 E6 finding. The block lives at EOF in `evolve-agents/SKILL.md` (additive append; sentinel `<!-- evolve-agents-deviations-installed -->`). Future audit runs of A10 against the backfilled spec confirm the Deviations block is present.

9. **`proj-code-writer-markdown` Before Writing block becomes a pre-condition for Batch 2** — the new step 5 in the 7-step block ("If dispatch prompt contains a `#### Reference Files` block ... Read ALL listed paths before proceeding. No exceptions") is the consuming-side mechanism that makes the Phase 3 dispatch-prompt update functional. Without it, the dispatch-prompt `#### Reference Files` block is decorative. Batch 0 ships the agent body amendment; Batch 2 ships the dispatch-prompt update.

10. **Project-specific customizations MUST be preserved** — all destructive steps (Step 3 SKILL.md combined patch, Step 6 audit-agents A9/A10 add, Step 7 agent body Before Writing replace) implement three-tier detection per `.claude/rules/general.md` Migration Preservation Discipline. Idempotency sentinel → `SKIP_ALREADY_APPLIED`; baseline sentinel → safe `PATCHED`; neither → `SKIP_HAND_EDITED` + `.bak-055` backup + pointer to `## Manual-Apply-Guide`. Blind overwrite of customized content is structurally prevented.

---

## Changes

| File | Change | Tier |
|---|---|---|
| `.claude/agents/proj-code-writer-markdown.md` | Replace Before Writing block: 5 → 7 steps + duplicate `2.` fix; new step 5 reads dispatch-prompt `#### Reference Files` block | Destructive (three-tier; sentinel `<!-- before-writing-ref-block-installed -->`) |
| `.claude/skills/evolve-agents/SKILL.md` (frontmatter) | Append `disable-model-invocation: true` after `effort: xhigh` line | Additive (idempotency only — frontmatter field check) |
| `.claude/skills/evolve-agents/references/agent-creation-brief.md` | NEW file (~135 lines): agent-creation domain knowledge | Additive (file existence check) |
| `.claude/skills/evolve-agents/SKILL.md` (body) | Phase 1 Write call (audit artifact) + Phase 3 pre-flight gate snippet + Phase 3 step 3 dispatch prompt update with `#### Reference Files` block | Destructive (three-tier; sentinel `<!-- evolve-agents-gate-installed -->`) |
| `.claude/rules/spec-fidelity.md` | NEW file (~50 lines): A10 rule body | Additive (defensive `cp` from `templates/rules/`) |
| `.claude/rules/evolve-agents-gate.md` | NEW file (~50 lines): Phase 3 gate rule body | Additive (defensive `cp` from `templates/rules/`) |
| `.claude/skills/audit-agents/SKILL.md` | Append A9 (1.1 gate audit) + A10 (1.3 spec-fidelity audit) sections after A8 wave-protocol checks; extend YAML report schema; extend fix-guidance list | Destructive (three-tier; sentinel `<!-- audit-agents-A9-A10-installed -->`) |
| `.claude/specs/2026-04-01-evolve-agents.md` (or `.claude/specs/main/2026-04-27-evolve-agents-skill-eval-spec.md`) | Prepend `---\ncovers-skill: evolve-agents\n---\n` frontmatter | Additive on no-frontmatter case; SKIP_HAND_EDITED on existing frontmatter (idempotent via awk extraction round-trip) |
| `.claude/specs/main/*deep-think*spec*.md` (Glob-discovered) | Prepend `---\ncovers-skill: deep-think\n---\n` frontmatter | Additive on no-frontmatter case; same logic as the evolve-agents spec |
| `.claude/skills/evolve-agents/SKILL.md` (EOF append) | Append `## Deviations from spec` block documenting v6 paradigm + Step 3/Step 6 absences | Additive (idempotency only — sentinel `<!-- evolve-agents-deviations-installed -->`) |

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { printf "ERROR: not a bootstrapped project — run full bootstrap first\n"; exit 1; }
[[ -d ".claude/agents" ]] || { printf "ERROR: .claude/agents/ missing — run full bootstrap first\n"; exit 1; }
[[ -d ".claude/skills" ]] || { printf "ERROR: .claude/skills/ missing — run full bootstrap first\n"; exit 1; }
[[ -d ".claude/rules" ]] || { printf "ERROR: .claude/rules/ missing — run full bootstrap first\n"; exit 1; }
[[ -f ".claude/agents/proj-code-writer-markdown.md" ]] || { printf "ERROR: proj-code-writer-markdown agent missing — run /evolve-agents to create it first or /migrate-bootstrap to install\n"; exit 1; }
[[ -f ".claude/skills/evolve-agents/SKILL.md" ]] || { printf "ERROR: /evolve-agents skill missing — install via /migrate-bootstrap or full bootstrap\n"; exit 1; }
[[ -f ".claude/skills/audit-agents/SKILL.md" ]] || { printf "ERROR: /audit-agents skill missing — install via /migrate-bootstrap or full bootstrap\n"; exit 1; }
command -v awk >/dev/null 2>&1 || { printf "ERROR: awk required\n"; exit 1; }
command -v python3 >/dev/null 2>&1 || { printf "ERROR: python3 required\n"; exit 1; }
```

### Idempotency check (whole-migration)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Whole-migration idempotency: if every patched file already carries the appropriate sentinel,
# the migration is a no-op. Per-step state is checked again inside each step — this top-level
# check is a fast-exit for the all-applied case.

ALL_PATCHED=1
declare -a SENTINEL_CHECKS=(
  "evolve-agents-gate-installed:.claude/skills/evolve-agents/SKILL.md"
  "audit-agents-A9-A10-installed:.claude/skills/audit-agents/SKILL.md"
  "evolve-agents-deviations-installed:.claude/skills/evolve-agents/SKILL.md"
)

for entry in "${SENTINEL_CHECKS[@]}"; do
  marker="${entry%%:*}"
  file="${entry##*:}"
  if [[ ! -f "$file" ]] || ! grep -q "$marker" "$file" 2>/dev/null; then
    ALL_PATCHED=0
    break
  fi
done

# Before Writing block: accept either sentinel OR keyphrase as PASS — matches Step 1's
# two-condition idempotency. Bootstrap Module 06 sync may install the keyphrase before
# this migration runs; treating the keyphrase alone as patched prevents false re-runs.
if [[ ! -f ".claude/agents/proj-code-writer-markdown.md" ]] || \
   ! grep -qE "before-writing-ref-block-installed|Read ALL listed paths before proceeding" \
     .claude/agents/proj-code-writer-markdown.md 2>/dev/null; then
  ALL_PATCHED=0
fi

# Also check additive-file existence
[[ -f ".claude/skills/evolve-agents/references/agent-creation-brief.md" ]] || ALL_PATCHED=0
[[ -f ".claude/rules/spec-fidelity.md" ]] || ALL_PATCHED=0
[[ -f ".claude/rules/evolve-agents-gate.md" ]] || ALL_PATCHED=0

# Also check disable-model-invocation field
if ! grep -q "^disable-model-invocation: true" .claude/skills/evolve-agents/SKILL.md 2>/dev/null; then
  ALL_PATCHED=0
fi

if [[ "$ALL_PATCHED" -eq 1 ]]; then
  printf "SKIP: migration 055 already applied (all sentinels + additive files present)\n"
  exit 0
fi

printf "Applying migration 055: /evolve-agents safety pack\n"
```

### Step 1 — Patch `proj-code-writer-markdown` Before Writing block (Batch 0)

Three-tier detection. The existing 5-step block has a duplicate `2.` numbering bug that is repaired as part of the replacement. The new 7-step block adds an explicit step 5 for reading dispatch-prompt `#### Reference Files` blocks.

- **Tier 1 idempotency sentinel**: `<!-- before-writing-ref-block-installed -->` present OR `Read ALL listed paths before proceeding` (the new step 5 keyphrase) present → `SKIP_ALREADY_APPLIED`
- **Tier 2 baseline sentinel**: `If dispatch prompt contains` absent AND `Verify all cross-references` present in the Before Writing block area → safe `PATCHED`
- **Tier 3 neither**: file customized post-bootstrap → `SKIP_HAND_EDITED` + `.bak-055-batch0` backup + pointer to `## Manual-Apply-Guide §Step-1`

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import sys
from pathlib import Path

path = Path(".claude/agents/proj-code-writer-markdown.md")
backup = Path(str(path) + ".bak-055-batch0")

POST_055_SENTINEL = "<!-- before-writing-ref-block-installed -->"
POST_055_KEYPHRASE = "Read ALL listed paths before proceeding"
BASELINE_ANCHOR = "Verify all cross-references"
HANDEDIT_NEGATIVE = "If dispatch prompt contains"

content = path.read_text(encoding="utf-8")

if POST_055_SENTINEL in content or POST_055_KEYPHRASE in content:
    print(f"SKIP_ALREADY_APPLIED: {path} Before Writing block already patched (055-1)")
    sys.exit(0)

if BASELINE_ANCHOR not in content or HANDEDIT_NEGATIVE in content:
    if not backup.exists():
        backup.write_text(content, encoding="utf-8")
    print(f"SKIP_HAND_EDITED: {path} Before Writing block has been customized post-bootstrap. Manual application required. See migrations/055-evolve-agents-safety-pack.md §Manual-Apply-Guide §Step-1. Backup at {backup}.")
    sys.exit(0)

# Locate the Before Writing block. The block starts at "## Before Writing (MANDATORY)" and
# ends at the next "## " heading (typically "## Component Classification").
import re

pattern = re.compile(
    r"(## Before Writing \(MANDATORY\)\s*\n)"
    r"(.*?)"
    r"(?=^## )",
    re.DOTALL | re.MULTILINE,
)

match = pattern.search(content)
if not match:
    if not backup.exists():
        backup.write_text(content, encoding="utf-8")
    print(f"ERROR: {path} could not locate '## Before Writing (MANDATORY)' block — aborting to avoid silent drift")
    sys.exit(1)

new_block = """## Before Writing (MANDATORY)
1. If `.claude/rules/mcp-routing.md` action→tool table populated (MCP project): use MCP tools per routing table for code discovery BEFORE Grep/Read (see that rule's Lead-With Order)
2. Read target file (if modifying) | 2-3 similar files (if creating)
3. Read `.claude/rules/code-standards-markdown.md` — follow conventions exactly
4. Read applicable technique refs:
   - `techniques/prompt-engineering.md` → RCCF framework, token optimization
   - `techniques/anti-hallucination.md` → verification patterns, false-claims mitigation
   - `techniques/agent-design.md` → subagent constraints, orchestrator patterns
5. If dispatch prompt contains a `#### Reference Files` block or `Read these before writing:` directive: Read ALL listed paths before proceeding. No exceptions — reference files are part of the mandatory pre-write context.
6. Verify all cross-references — every file path mentioned must exist
7. Check module numbering — read `claude-bootstrap.md` for current module list

<!-- before-writing-ref-block-installed -->

"""

if not backup.exists():
    backup.write_text(content, encoding="utf-8")

new_content = content[:match.start()] + new_block + content[match.end():]
path.write_text(new_content, encoding="utf-8")
print(f"PATCHED: {path} Before Writing block (055-1)")
PY
```

### Step 2 — Append `disable-model-invocation: true` to evolve-agents frontmatter (Batch 1.1)

Additive — idempotency only. Inserts the field after `effort: xhigh` line in the frontmatter block.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import sys
from pathlib import Path

path = Path(".claude/skills/evolve-agents/SKILL.md")
content = path.read_text(encoding="utf-8")

# Any line of the form 'disable-model-invocation: true' is enough to consider applied.
import re
if re.search(r"^disable-model-invocation:\s*true\s*$", content, re.MULTILINE):
    print(f"SKIP_ALREADY_APPLIED: {path} disable-model-invocation already present (055-2)")
    sys.exit(0)

# Frontmatter must have an `effort:` line; insert disable-model-invocation immediately after.
EFFORT_PATTERN = re.compile(r"^(effort:\s*\S+\s*)$", re.MULTILINE)
match = EFFORT_PATTERN.search(content)
if not match:
    print(f"ERROR: {path} has no `effort:` line in frontmatter — cannot anchor insertion (055-2)")
    sys.exit(1)

insertion_point = match.end()
new_content = content[:insertion_point] + "\ndisable-model-invocation: true" + content[insertion_point:]
path.write_text(new_content, encoding="utf-8")
print(f"PATCHED: {path} disable-model-invocation: true inserted after effort: line (055-2)")
PY
```

### Step 3 — Create `agent-creation-brief.md` reference file (Batch 1.2)

Additive — file existence check. Writes the full ~135-line brief content via single-quoted heredoc (no shell expansion) so `${...}` and `` ` `` characters in the brief content ship verbatim.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/skills/evolve-agents/references/agent-creation-brief.md"

if [[ -f "$TARGET" ]]; then
  printf "SKIP_ALREADY_APPLIED: %s already present (055-3)\n" "$TARGET"
else
  mkdir -p .claude/skills/evolve-agents/references
  cat > "$TARGET" <<'BRIEF_EOF'
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
BRIEF_EOF
  printf "WROTE: %s\n" "$TARGET"
fi
```

### Step 4 — Combined `evolve-agents/SKILL.md` patch (Batch 2 — three-tier detection)

This step applies three coordinated edits to `evolve-agents/SKILL.md` under a single sentinel:

- **Edit A** — Phase 1 body: insert audit-artifact Write call (Bash heredoc producing `.claude/reports/evolve-agents-audit-latest.md` with trailing `## Gate Complete` heading)
- **Edit B** — Phase 3 body: insert pre-flight gate Bash snippet (artifact existence + `## Gate Complete` token + `find -newer` staleness check) BEFORE the existing Phase 3 dispatch steps
- **Edit C** — Phase 3 step 3 dispatch prompt: extend with `#### Reference Files` block pointing at `agent-creation-brief.md` + `markdown-analysis.md`

All three edits ship under one sentinel `<!-- evolve-agents-gate-installed -->` (placed inline at the end of the gate snippet code-fence area in Phase 3) to avoid sentinel collisions on the same file.

- **Tier 1 idempotency sentinel**: `<!-- evolve-agents-gate-installed -->` present → `SKIP_ALREADY_APPLIED`
- **Tier 2 baseline sentinel**: `### Phase 1: Audit Existing Specialists` present AND `### Phase 3: Create New Specialists` present AND `Same pipeline as Module 07:` present AND `^## Gate Complete` heading absent in body → safe `PATCHED`
- **Tier 3 neither**: file customized post-bootstrap → `SKIP_HAND_EDITED` + `.bak-055-batch2` backup + pointer to `## Manual-Apply-Guide §Step-4`

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import sys, re
from pathlib import Path

path = Path(".claude/skills/evolve-agents/SKILL.md")
backup = Path(str(path) + ".bak-055-batch2")

POST_055_SENTINEL = "<!-- evolve-agents-gate-installed -->"
BASELINE_PHASE1 = "### Phase 1: Audit Existing Specialists"
BASELINE_PHASE3 = "### Phase 3: Create New Specialists"
BASELINE_PIPELINE = "Same pipeline as Module 07:"

content = path.read_text(encoding="utf-8")

if POST_055_SENTINEL in content:
    print(f"SKIP_ALREADY_APPLIED: {path} combined SKILL.md patch already applied (055-4)")
    sys.exit(0)

# Hand-edit detection: required baseline anchors must all be present
if (BASELINE_PHASE1 not in content or
    BASELINE_PHASE3 not in content or
    BASELINE_PIPELINE not in content):
    if not backup.exists():
        backup.write_text(content, encoding="utf-8")
    print(f"SKIP_HAND_EDITED: {path} body has been customized post-bootstrap — required baseline anchors absent. Manual application required. See migrations/055-evolve-agents-safety-pack.md §Manual-Apply-Guide §Step-4. Backup at {backup}.")
    sys.exit(0)

if not backup.exists():
    backup.write_text(content, encoding="utf-8")

# ----------------------------------------------------------------------
# Edit A — Phase 1 body: insert audit-artifact Write call BEFORE Phase 2
# ----------------------------------------------------------------------
PHASE1_INSERT = """
After all 4 audit checks complete, the dispatched proj-researcher agent MUST write a persistent audit artifact via Bash heredoc:

```bash
mkdir -p .claude/reports
cat > .claude/reports/evolve-agents-audit-latest.md <<'AUDIT_EOF'
# /evolve-agents Audit — {ISO8601 timestamp}

## Version Drift Findings
{per-agent findings}

## Reference Staleness Findings
{per-reference findings}

## Missing-Pattern Findings
{per-agent findings from .learnings/log.md}

## Dispatch Frequency Findings
{per-agent usage counts from .learnings/agent-usage.log}

## Gate Complete
AUDIT_EOF
```

The trailing `## Gate Complete` heading is REQUIRED — Phase 3 pre-flight gate greps for it as the artifact integrity check. A missing or truncated artifact fails the gate.

"""

# Locate Phase 1 → Phase 2 boundary; Phase 2 heading is the insertion point.
PHASE2_PATTERN = re.compile(r"(\n### Phase 2:)", re.MULTILINE)
match_p2 = PHASE2_PATTERN.search(content)
if not match_p2:
    print(f"ERROR: {path} has no '### Phase 2:' heading — cannot anchor Edit A insertion (055-4)")
    sys.exit(1)

content = content[:match_p2.start()] + PHASE1_INSERT.rstrip() + match_p2.group(1) + content[match_p2.end():]

# ----------------------------------------------------------------------
# Edit B — Phase 3 pre-flight gate: insert BETWEEN "Same pipeline as Module 07:" and the
# numbered dispatch step list. Sentinel <!-- evolve-agents-gate-installed --> appended inline.
# ----------------------------------------------------------------------
PHASE3_GATE_INSERT = """Same pipeline as Module 07:

Before dispatching, run the pre-flight gate (Bash):

```bash
ARTIFACT=".claude/reports/evolve-agents-audit-latest.md"
if [[ ! -f "$ARTIFACT" ]]; then
  echo "BLOCK: No audit artifact found. Run /evolve-agents Phase 1 first (or pass --skip-audit-gate)."
  exit 1
fi
if ! grep -q "^## Gate Complete" "$ARTIFACT"; then
  echo "BLOCK: Audit artifact missing Gate Token (truncated write?). Re-run Phase 1."
  exit 1
fi
STALE_AGENTS=$(find .claude/agents/ -type f \\( -name 'proj-code-writer-*.md' -o -name 'proj-test-writer-*.md' \\) -newer "$ARTIFACT" 2>/dev/null)
if [[ -n "$STALE_AGENTS" ]]; then
  echo "WARN: Agent files modified after audit artifact — consider re-running Phase 1:"
  echo "$STALE_AGENTS"
fi
```
<!-- evolve-agents-gate-installed -->

Gate PASS (no exit 1) → proceed to dispatch steps.
"""

# Replace the existing "Same pipeline as Module 07:" line (and trailing blank line) with the gate-extended block.
SAME_PIPELINE_PATTERN = re.compile(r"^Same pipeline as Module 07:\s*\n", re.MULTILINE)
match_sp = SAME_PIPELINE_PATTERN.search(content)
if not match_sp:
    print(f"ERROR: {path} has no 'Same pipeline as Module 07:' line after Edit A — cannot anchor Edit B (055-4)")
    sys.exit(1)

content = content[:match_sp.start()] + PHASE3_GATE_INSERT + content[match_sp.end():]

# ----------------------------------------------------------------------
# Edit C — Phase 3 step 3 dispatch prompt: extend with #### Reference Files block
# ----------------------------------------------------------------------
# Existing line: "3. Dispatch agent via `subagent_type=\"proj-code-writer-markdown\"` → generate agent from research references"
# Followed by: "   Write to `.claude/agents/proj-code-writer-{lang}-{framework}.md`"
# Insert the #### Reference Files block immediately AFTER the Write-to line.

STEP3_WRITE_PATTERN = re.compile(
    r"(3\. Dispatch agent via `subagent_type=\"proj-code-writer-markdown\"` → generate agent from research references\s*\n"
    r"   Write to `\.claude/agents/proj-code-writer-\{lang\}-\{framework\}\.md`\s*\n)",
    re.MULTILINE,
)
match_s3 = STEP3_WRITE_PATTERN.search(content)
if not match_s3:
    print(f"ERROR: {path} step-3 dispatch prompt anchor not found — cannot anchor Edit C (055-4)")
    sys.exit(1)

STEP3_INSERT = """
   Dispatch prompt MUST include this block (triggers proj-code-writer-markdown Before Writing step 5):

   ```
   #### Reference Files
   Read these before writing:
   - `templates/skills/evolve-agents/references/agent-creation-brief.md` — agent conformance checklist + required sections; governs the generated agent's structure
   - `.claude/skills/code-write/references/markdown-analysis.md` — component classification table, tools whitelists, frontmatter field spec
   ```

"""

content = content[:match_s3.end()] + STEP3_INSERT + content[match_s3.end():]

path.write_text(content, encoding="utf-8")
print(f"PATCHED: {path} combined Phase 1 + Phase 3 + step 3 dispatch-prompt edits (055-4)")
PY
```

### Step 5 — Defensive `cp` `templates/rules/spec-fidelity.md` → `.claude/rules/spec-fidelity.md` (Batch 3.1)

Additive — file existence check. Per OQ-templates-rules-vs-rules-sync resolution, this migration includes a defensive copy step instead of relying on Module 06 fetch-loop auto-sync. The full ~50-line rule body is inlined via single-quoted heredoc.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/rules/spec-fidelity.md"

if [[ -f "$TARGET" ]]; then
  printf "SKIP_ALREADY_APPLIED: %s already present (055-5)\n" "$TARGET"
else
  cat > "$TARGET" <<'SPEC_FIDELITY_EOF'
# Spec Fidelity

## Rule
Every spec file that implements a deployed skill MUST declare its target via `covers-skill: <skill-name>` YAML frontmatter. Every skill with a backing spec MUST contain a `## Deviations from spec` block documenting any intentional or accepted divergences from the spec.

## Convention — covers-skill: frontmatter
- Field name: `covers-skill:` (single value, v1)
- Cardinality: single value only; multi-value list form `covers-skill: [a, b]` is NOT supported in v1 — the awk extraction returns only `[skill-a,` for list form (malformed); deferred to future-work
- Placement: inside the YAML frontmatter block at the TOP of the spec file, between two `---` markers; placement must precede any body content
- Value: single bare YAML string matching a deployed skill name (`evolve-agents`, `deep-think`, etc.)

## Extraction (awk)
Inline (1-line, for embedding in bash scripts):
```bash
skill_name=$(awk 'NR==1&&/^---/{d=1;next} NR==1{exit} d==1&&/^---/{d=2;next} d==2{exit} d==1&&/^covers-skill:/{print $2;exit}' "$spec_file")
```

Readable (5-line, for documentation):
```bash
skill_name=$(awk '
  NR==1 && /^---/ { d=1; next }
  NR==1           { exit }
  d==1 && /^---/ { d=2; next }
  d==2            { exit }
  d==1 && /^covers-skill:/ { print $2; exit }
' "$spec_file")
```

Counter-based awk (`d`: 0→1→2) terminates scanning at the second `---` unconditionally — body `---` lines cannot reactivate frontmatter scanning.

## A10 Audit Behavior
- For each `.claude/specs/**/*.md`: extract `covers-skill:` value via the inline awk above
- For each extracted skill name: locate `.claude/skills/{name}/SKILL.md`; absent → INFO (spec references a skill not deployed in this project)
- SKILL.md present: grep for `^## Deviations from spec` → present = PASS; absent = WARN (or FAIL after graduation criterion below)
- Output: append A10 entry to audit-agents YAML report

## Backfill List
Specs backfilled with `covers-skill:` frontmatter on rule introduction (migration 055):
- evolve-agents spec → `covers-skill: evolve-agents`
- deep-think spec → `covers-skill: deep-think`

## WARN→FAIL Graduation
WARN status until 5 migrations after the migration that installs `spec-fidelity.md` ships. After the graduation point, A10 promotes WARN to FAIL. Graduation gives time for spec authors + spec-emitting skills (/brainstorm, /deep-think) to adopt the convention before failure becomes blocking.

## Future Work
- Multi-value `covers-skill: [a, b]` support — requires awk extraction rewrite to handle YAML list parsing; defer until a spec covering multiple skills arises in practice
- Commit-hash pinning — tag the spec frontmatter with a commit hash for the skill body it implements, allowing detection of skill-side drift independent of the Deviations block
- Bidirectional link — auto-generated wikilink from skill body back to its originating spec on Deviations block creation
SPEC_FIDELITY_EOF
  printf "WROTE: %s\n" "$TARGET"
fi
```

### Step 6 — Defensive `cp` `templates/rules/evolve-agents-gate.md` → `.claude/rules/evolve-agents-gate.md` (Batch 3.2)

Additive — file existence check. Same defensive-copy pattern as Step 5.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/rules/evolve-agents-gate.md"

if [[ -f "$TARGET" ]]; then
  printf "SKIP_ALREADY_APPLIED: %s already present (055-6)\n" "$TARGET"
else
  cat > "$TARGET" <<'GATE_RULE_EOF'
# /evolve-agents Phase 3 Gate

## Rule
/evolve-agents Phase 3 (specialist creation) MUST run a pre-flight bash gate that verifies a fresh audit artifact exists. The gate BLOCKs on absent or malformed artifacts. The gate emits a non-blocking WARN if any specialist agent file is newer than the audit artifact.

## Artifact Contract
- Path: `.claude/reports/evolve-agents-audit-latest.md` (stable filename — no timestamp; `ls -t` glob NOT used)
- Producer: Phase 1 dispatched `proj-researcher` writes via Bash heredoc
- Required token: trailing `^## Gate Complete` heading at end of artifact body
- Lifetime: stable filename overwritten on each Phase 1 run; `find -newer` compares specialist agent mtimes against artifact mtime

## Gate Snippet (canonical)

```bash
## Phase 3 Pre-Flight Gate
ARTIFACT=".claude/reports/evolve-agents-audit-latest.md"
if [[ ! -f "$ARTIFACT" ]]; then
  echo "BLOCK: No audit artifact found. Run /evolve-agents Phase 1 first (or pass --skip-audit-gate)."
  exit 1
fi
if ! grep -q "^## Gate Complete" "$ARTIFACT"; then
  echo "BLOCK: Audit artifact missing Gate Token (truncated write?). Re-run Phase 1."
  exit 1
fi
STALE_AGENTS=$(find .claude/agents/ -type f \( -name 'proj-code-writer-*.md' -o -name 'proj-test-writer-*.md' \) -newer "$ARTIFACT" 2>/dev/null)
if [[ -n "$STALE_AGENTS" ]]; then
  echo "WARN: Agent files modified after audit artifact — consider re-running Phase 1:"
  echo "$STALE_AGENTS"
fi
```

## Behavior Matrix
| Condition | Outcome |
|---|---|
| Artifact missing | BLOCK (`exit 1` with diagnostic) |
| Artifact present, no `## Gate Complete` heading | BLOCK (truncated write) |
| Artifact present + complete + no specialist newer | PASS |
| Artifact present + complete + ≥1 specialist newer | WARN (non-blocking; lists stale agents) |

## A9 Audit Behavior
- Scope: only `.claude/skills/evolve-agents/SKILL.md` (not all skills)
- Check 1: grep for `<!-- evolve-agents-gate-installed -->` sentinel → presence = PASS
- Check 2: grep for the canonical gate text patterns (`evolve-agents-audit-latest.md`, `## Gate Complete`, `find .claude/agents/`) → all present = PASS
- Check 3: confirm Phase 1 contains a Write call producing the artifact path → presence of `evolve-agents-audit-latest.md` in Phase 1 body = PASS
- Failure: any check fails → A9 = FAIL with file:line evidence

## Bypass
Documented but DISCOURAGED: pass `--skip-audit-gate` arg to /evolve-agents; gate emits warning instead of BLOCK; useful only for repair scenarios (audit infrastructure broken; user manually verified state).
GATE_RULE_EOF
  printf "WROTE: %s\n" "$TARGET"
fi
```

### Step 7 — Append A9 + A10 to `audit-agents/SKILL.md` (Batch 3.3 — three-tier detection)

Inserts A9 (gate audit) + A10 (spec-fidelity audit) after the existing A8 wave-protocol checks. Extends YAML report schema and fix-guidance list.

- **Tier 1 idempotency sentinel**: `<!-- audit-agents-A9-A10-installed -->` present → `SKIP_ALREADY_APPLIED`
- **Tier 2 baseline sentinel**: `<!-- audit-agents-A8-installed -->` present AND `^### A9` absent AND `^### A10` absent → safe `PATCHED`
- **Tier 3 neither**: file customized post-bootstrap → `SKIP_HAND_EDITED` + `.bak-055-batch3` backup + pointer to `## Manual-Apply-Guide §Step-7`

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import sys, re
from pathlib import Path

path = Path(".claude/skills/audit-agents/SKILL.md")
backup = Path(str(path) + ".bak-055-batch3")

POST_055_SENTINEL = "<!-- audit-agents-A9-A10-installed -->"
BASELINE_A8_SENTINEL = "<!-- audit-agents-A8-installed -->"

content = path.read_text(encoding="utf-8")

if POST_055_SENTINEL in content:
    print(f"SKIP_ALREADY_APPLIED: {path} A9/A10 already installed (055-7)")
    sys.exit(0)

# Hand-edit detection: A8 baseline must be present AND A9/A10 must NOT yet exist
if (BASELINE_A8_SENTINEL not in content or
    re.search(r"^### A9", content, re.MULTILINE) or
    re.search(r"^### A10", content, re.MULTILINE)):
    if not backup.exists():
        backup.write_text(content, encoding="utf-8")
    print(f"SKIP_HAND_EDITED: {path} body has been customized post-bootstrap — A8 baseline absent or A9/A10 already partially present. Manual application required. See migrations/055-evolve-agents-safety-pack.md §Manual-Apply-Guide §Step-7. Backup at {backup}.")
    sys.exit(0)

if not backup.exists():
    backup.write_text(content, encoding="utf-8")

A9_A10_BLOCK = """
### A9: evolve-agents Phase 3 gate presence

Scope: `.claude/skills/evolve-agents/SKILL.md` only (skill-specific check).

Per `.claude/rules/evolve-agents-gate.md` § A9 Audit Behavior:

For `.claude/skills/evolve-agents/SKILL.md`:
1. Sentinel check: `grep -q "<!-- evolve-agents-gate-installed -->" .claude/skills/evolve-agents/SKILL.md` → PASS if hit; FAIL with file:line of frontmatter close if absent.
2. Gate text patterns: verify ALL of `evolve-agents-audit-latest`, `^## Gate Complete`, `find .claude/agents/` appear in body → PASS if all present; FAIL with first missing pattern + file:line evidence if any absent.
3. Phase 1 Write call: verify `evolve-agents-audit-latest.md` appears within the Phase 1 section body (between `### Phase 1:` heading and `### Phase 2:` heading) → PASS if hit; FAIL otherwise.

Skip if `.claude/skills/evolve-agents/SKILL.md` does not exist (project doesn't deploy /evolve-agents) → SKIP with INFO message.

Output (append to YAML report block):
```yaml
A9_evolve_agents_gate: {PASS|FAIL|SKIP}
findings:
  - check: A9
    severity: FAIL
    file: .claude/skills/evolve-agents/SKILL.md
    line: {N}
    detail: "{which check failed; missing pattern; remediation pointer}"
```

### A10: covers-skill spec-fidelity

Scope: all `.claude/specs/**/*.md` files.

Per `.claude/rules/spec-fidelity.md` § A10 Audit Behavior:

For each spec file under `.claude/specs/`:
1. Extract `covers-skill:` value via canonical awk (counter-based, terminates at 2nd `---`):
   ```bash
   skill_name=$(awk 'NR==1&&/^---/{d=1;next} NR==1{exit} d==1&&/^---/{d=2;next} d==2{exit} d==1&&/^covers-skill:/{print $2;exit}' "$spec_file")
   ```
2. If `$skill_name` empty → spec has no `covers-skill:` declaration → SKIP this spec (no fidelity contract).
3. If `$skill_name` non-empty: locate `.claude/skills/{skill_name}/SKILL.md`. If absent → INFO (spec references undeployed skill).
4. If SKILL.md present: `grep -q "^## Deviations from spec" .claude/skills/{skill_name}/SKILL.md` → PASS if hit; WARN otherwise (or FAIL after graduation per `spec-fidelity.md` § WARN→FAIL Graduation: WARN until 5 migrations after the rule's introducing migration ships, FAIL thereafter).

Multi-value `covers-skill: [a, b]` extraction returns malformed `[a,` — log INFO ("multi-value form deferred per spec-fidelity.md") and skip. Single-value form is v1 canonical.

Output (append to YAML report block):
```yaml
A10_covers_skill_fidelity: {PASS|WARN|FAIL|SKIP}
findings:
  - check: A10
    severity: WARN
    spec: .claude/specs/{path}.md
    skill: {extracted skill name}
    detail: "Skill body missing '## Deviations from spec' block — see .claude/rules/spec-fidelity.md for convention"
```
<!-- audit-agents-A9-A10-installed -->
"""

# Insert A9/A10 block AFTER the A8-installed sentinel line and BEFORE the next ### heading.
# Anchor: "<!-- audit-agents-A8-installed -->" line.
A8_PATTERN = re.compile(r"(<!-- audit-agents-A8-installed -->\s*\n)", re.MULTILINE)
match_a8 = A8_PATTERN.search(content)
if not match_a8:
    print(f"ERROR: {path} A8 sentinel anchor not found — cannot insert A9/A10 (055-7)")
    sys.exit(1)

content = content[:match_a8.end()] + A9_A10_BLOCK + content[match_a8.end():]

# Extend YAML report schema (insert A9/A10 lines before the closing ``` of the schema block).
# Anchor schema by locating "A8_wave_force_read:" line in the schema and adding A9/A10 lines after it.
SCHEMA_PATTERN = re.compile(
    r"(  A8_wave_force_read:\s+\{PASS\|FAIL\|SKIP\}\s*\n)",
    re.MULTILINE,
)
schema_match = SCHEMA_PATTERN.search(content)
if schema_match:
    schema_addition = "  A9_evolve_agents_gate:    {PASS|FAIL|SKIP}\n  A10_covers_skill_fidelity: {PASS|WARN|FAIL|SKIP}\n"
    content = content[:schema_match.end()] + schema_addition + content[schema_match.end():]
else:
    print(f"WARN: {path} YAML report schema A8_wave_force_read line not found — schema not extended (055-7)")

# Extend fix-guidance list (insert A9/A10 lines after the A8_wave_force_read fix line).
FIX_PATTERN = re.compile(
    r"(- A8_wave_force_read FAIL → add `\.claude/rules/wave-iterated-parallelism\.md` to the agent's STEP 0 force-read bullet list; see `\.claude/rules/wave-iterated-parallelism\.md` § Enforcement\s*\n)",
    re.MULTILINE,
)
fix_match = FIX_PATTERN.search(content)
if fix_match:
    fix_addition = "- A9 FAIL → check `.claude/rules/evolve-agents-gate.md` § A9 Audit Behavior for the missing pattern; re-apply migration 055 if the gate snippet was lost (sentinel `evolve-agents-gate-installed` was removed)\n- A10 WARN → add `## Deviations from spec` block to the skill body listing intentional divergences from the cited spec (or write `## Deviations from spec\\n\\nNone — implementation matches spec.\\n` if no divergences); see `.claude/rules/spec-fidelity.md`\n- A10 FAIL → same as WARN remediation; FAIL severity indicates graduation criterion has been crossed (5 migrations after 055)\n"
    content = content[:fix_match.end()] + fix_addition + content[fix_match.end():]
else:
    print(f"WARN: {path} fix-guidance A8_wave_force_read FAIL line not found — fix guidance not extended (055-7)")

path.write_text(content, encoding="utf-8")
print(f"PATCHED: {path} A9/A10 sections + schema + fix-guidance (055-7)")
PY
```

### Step 8 — Prepend `covers-skill: evolve-agents` frontmatter to evolve-agents spec (Batch 4.1)

The spec filename is locator-flexible (legacy: `.claude/specs/2026-04-01-evolve-agents.md`; current: `.claude/specs/main/2026-04-27-evolve-agents-skill-eval-spec.md`). The migration tries both paths and uses the first that exists. Idempotency via canonical awk extraction round-trip.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Try both legacy and current spec paths
SPEC_CANDIDATES=(
  ".claude/specs/2026-04-01-evolve-agents.md"
  ".claude/specs/main/2026-04-27-evolve-agents-skill-eval-spec.md"
)

SPEC_PATH=""
for candidate in "${SPEC_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    SPEC_PATH="$candidate"
    break
  fi
done

if [[ -z "$SPEC_PATH" ]]; then
  printf "SKIP: no evolve-agents spec found at any candidate path; tried: %s (055-8)\n" "${SPEC_CANDIDATES[*]}"
else
  # Idempotency: extract covers-skill via canonical awk; if value matches, SKIP.
  extracted=$(awk 'NR==1&&/^---/{d=1;next} NR==1{exit} d==1&&/^---/{d=2;next} d==2{exit} d==1&&/^covers-skill:/{print $2;exit}' "$SPEC_PATH")
  if [[ "$extracted" == "evolve-agents" ]]; then
    printf "SKIP_ALREADY_APPLIED: %s already carries covers-skill: evolve-agents (055-8)\n" "$SPEC_PATH"
  else
    # Hand-edit detection: if file starts with "---" but has different frontmatter, SKIP_HAND_EDITED
    first_line=$(head -1 "$SPEC_PATH")
    if [[ "$first_line" == "---" && -z "$extracted" ]]; then
      backup="${SPEC_PATH}.bak-055-batch4-evolve"
      [[ -f "$backup" ]] || cp "$SPEC_PATH" "$backup"
      printf "SKIP_HAND_EDITED: %s has existing frontmatter without covers-skill: evolve-agents — manual merge required. See migrations/055-evolve-agents-safety-pack.md §Manual-Apply-Guide §Step-8. Backup at %s. (055-8)\n" "$SPEC_PATH" "$backup"
    else
      tmpfile="${SPEC_PATH}.tmp-055"
      {
        printf '%s\n' "---"
        printf '%s\n' "covers-skill: evolve-agents"
        printf '%s\n' "---"
        printf '%s\n' ""
        cat "$SPEC_PATH"
      } > "$tmpfile"
      mv "$tmpfile" "$SPEC_PATH"
      printf "PATCHED: %s prepended covers-skill: evolve-agents frontmatter (055-8)\n" "$SPEC_PATH"
    fi
  fi
fi
```

### Step 9 — Prepend `covers-skill: deep-think` frontmatter to deep-think spec (Batch 4.2)

Glob discovery for the deep-think spec filename. If multiple matches OR zero matches, emit WARN and skip (do not halt the migration).

```bash
#!/usr/bin/env bash
set -euo pipefail

# Glob discovery for the deep-think spec filename
shopt -s nullglob
DEEP_THINK_CANDIDATES=( .claude/specs/main/*deep-think*spec*.md .claude/specs/*deep-think*spec*.md )
shopt -u nullglob

if [[ ${#DEEP_THINK_CANDIDATES[@]} -eq 0 ]]; then
  printf "WARN: no deep-think spec found via glob (.claude/specs/main/*deep-think*spec*.md or .claude/specs/*deep-think*spec*.md) — skipping covers-skill backfill (055-9)\n"
elif [[ ${#DEEP_THINK_CANDIDATES[@]} -gt 1 ]]; then
  printf "WARN: multiple deep-think spec candidates found (skipping to avoid wrong target):\n"
  for c in "${DEEP_THINK_CANDIDATES[@]}"; do
    printf "  - %s\n" "$c"
  done
  printf "Manual application required if covers-skill backfill desired. See migrations/055-evolve-agents-safety-pack.md §Manual-Apply-Guide §Step-9. (055-9)\n"
else
  SPEC_PATH="${DEEP_THINK_CANDIDATES[0]}"
  extracted=$(awk 'NR==1&&/^---/{d=1;next} NR==1{exit} d==1&&/^---/{d=2;next} d==2{exit} d==1&&/^covers-skill:/{print $2;exit}' "$SPEC_PATH")
  if [[ "$extracted" == "deep-think" ]]; then
    printf "SKIP_ALREADY_APPLIED: %s already carries covers-skill: deep-think (055-9)\n" "$SPEC_PATH"
  else
    first_line=$(head -1 "$SPEC_PATH")
    if [[ "$first_line" == "---" && -z "$extracted" ]]; then
      backup="${SPEC_PATH}.bak-055-batch4-deepthink"
      [[ -f "$backup" ]] || cp "$SPEC_PATH" "$backup"
      printf "SKIP_HAND_EDITED: %s has existing frontmatter without covers-skill: deep-think — manual merge required. See migrations/055-evolve-agents-safety-pack.md §Manual-Apply-Guide §Step-9. Backup at %s. (055-9)\n" "$SPEC_PATH" "$backup"
    else
      tmpfile="${SPEC_PATH}.tmp-055"
      {
        printf '%s\n' "---"
        printf '%s\n' "covers-skill: deep-think"
        printf '%s\n' "---"
        printf '%s\n' ""
        cat "$SPEC_PATH"
      } > "$tmpfile"
      mv "$tmpfile" "$SPEC_PATH"
      printf "PATCHED: %s prepended covers-skill: deep-think frontmatter (055-9)\n" "$SPEC_PATH"
    fi
  fi
fi
```

### Step 10 — Append Deviations block to `evolve-agents/SKILL.md` (Batch 4.3)

Additive — sentinel-only check. Documents the v6 paradigm shift + Step 3 / Step 6 absences as INTENTIONAL classifications.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/skills/evolve-agents/SKILL.md"

if grep -q "<!-- evolve-agents-deviations-installed -->" "$TARGET" 2>/dev/null; then
  printf "SKIP_ALREADY_APPLIED: %s Deviations block already appended (055-10)\n" "$TARGET"
else
  cat >> "$TARGET" <<'DEVIATIONS_EOF'

---

## Deviations from spec

Backing spec: `.claude/specs/2026-04-01-evolve-agents.md` (per `covers-skill:` convention defined in `.claude/rules/spec-fidelity.md`).

The deployed skill diverges from the original spec in two documented respects. Both are classified INTENTIONAL per the 2026-04-27 deep-think (round-0-evidence.md + 1.3 E6 finding):

### Deviation 1 — v6 paradigm shift (audit + create-NEW, never split)

- **Spec form**: 2026-04-01 spec described an "audit + split" semantics — when an existing agent grew too large for its scope, the skill would split it into multiple narrower specialists.
- **Deployed form**: v6 paradigm — agents are born right-sized; the skill audits + creates NEW sub-specialists for new frameworks/languages but NEVER splits existing agents.
- **Rationale**: split semantics created two failure modes — (a) loss of accumulated `Known Gotchas` content during the split, and (b) a chicken-and-egg dispatch problem where the splitting agent needed to predict the future scope of its own children. Create-NEW with right-sized initial spec is the correct shape; split is retired.
- **Classification**: INTENTIONAL — present in the FIRST commit of evolve-agents/SKILL.md (2026-04-01); the spec was the inferior design and was superseded at implementation time without an explicit deviation note. Backfilled here per 1.3 E6 finding.

### Deviation 2 — Step 3 (user-approval gate) and Step 6 (wiring) absent

- **Spec form**: 2026-04-01 spec described 6 sequential steps including a user-approval gate at Step 3 (after Phase 1 audit, before Phase 3 creation) and a wiring step at Step 6 (post-creation, registers the new agent into all dispatch maps).
- **Deployed form**: 5 phases; no explicit user-approval gate phase; wiring is folded into Phase 4 (Update Index — regenerates `agent-index.yaml` and `capability-index.md`).
- **Rationale**: The user-approval gate at Step 3 is replaced by the more general Phase 3 pre-flight gate (added by migration 055; see `.claude/rules/evolve-agents-gate.md`) — the gate enforces freshness via persistent audit artifact rather than blocking on user input. Wiring is correctly absorbed into the index-regeneration phase because the index files ARE the wiring (skills + agents discover each other through these indices).
- **Classification**: INTENTIONAL — both gaps were design simplifications, not regressions. The pre-flight gate is a stronger discipline than a one-time approval prompt (it persists across re-runs); the index-regeneration is the wiring (no separate registration step needed).

<!-- evolve-agents-deviations-installed -->
DEVIATIONS_EOF
  printf "PATCHED: %s appended Deviations block (055-10)\n" "$TARGET"
fi
```

### Step 11 — Update `.claude/bootstrap-state.json`

Advance `last_migration` and append to `applied[]`.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '055'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '055') or a == '055' for a in applied):
    applied.append({
        'id': '055',
        'applied_at': state['last_applied'],
        'description': '/evolve-agents safety pack: disable-model-invocation frontmatter + Phase 1 audit-artifact persistence + Phase 3 pre-flight gate + agent-creation-brief.md reference + spec-fidelity audit (covers-skill convention + A10 invariant) + audit-agents A9/A10 + 2 spec frontmatter backfills + Deviations block.'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=055')
PY
```

### Rules for migration scripts

- **Read-before-write** — every destructive step reads the target file, runs three-tier detection, and only writes on the safe-patch tier. Destructive writes always create `.bak-055-batchN` backup before overwrite (per `.claude/rules/general.md` Migration Preservation Discipline).
- **Idempotent** — re-running prints `SKIP_ALREADY_APPLIED` per step and `SKIP: migration 055 already applied` at the top when all sentinels + additive files are present.
- **Self-contained** — all rule bodies, brief content, gate snippets, deviations text inlined via single-quoted heredocs (`<<'EOF'`) so `${...}` and `` ` `` characters in the embedded content ship verbatim. No `gh api` fetch in this migration's body — every embedded artifact is inline.
- **No gitignored-path fetch** — migration body is fully inlined; nothing fetched from the bootstrap repo at runtime.
- **Glob deployment for spec discovery** — Step 9 uses `nullglob` shell glob for the deep-think spec filename. Multiple matches → WARN + skip (do not halt). Zero matches → WARN + skip.
- **Abort on error** — `set -euo pipefail` in every bash block; Steps 8 + 9 (spec backfills) are intentionally fail-soft (WARN + continue) on file-not-found cases.
- **Scope lock** — touches only: `.claude/agents/proj-code-writer-markdown.md`, `.claude/skills/evolve-agents/SKILL.md`, `.claude/skills/evolve-agents/references/agent-creation-brief.md` (new), `.claude/skills/audit-agents/SKILL.md`, `.claude/rules/spec-fidelity.md` (new), `.claude/rules/evolve-agents-gate.md` (new), the two backfilled spec files, `.claude/bootstrap-state.json`. No hook changes, no settings edits, no other agent or skill bodies. `migrations/index.json` and `templates/manifest.json` are appended/updated BY MAIN THREAD outside this migration body (per `.claude/rules/agent-scope-lock.md`).

---

## Verify

```bash
#!/usr/bin/env bash
set +e
fail=0

# 1. Before Writing block has 7 steps with #### Reference Files step.
# Accept EITHER sentinel OR keyphrase as PASS — matches Step 1's two-condition idempotency.
# Bootstrap Module 06 sync may install the keyphrase before this migration runs, in which case
# the sentinel will not be added but the functional content is correctly applied.
if grep -qE "before-writing-ref-block-installed|Read ALL listed paths before proceeding" \
     .claude/agents/proj-code-writer-markdown.md 2>/dev/null; then
  printf "PASS: proj-code-writer-markdown Before Writing block patched (sentinel or keyphrase present)\n"
else
  printf "FAIL: proj-code-writer-markdown Before Writing block missing both sentinel and step 5 keyphrase\n"
  fail=1
fi

# 2. disable-model-invocation field present
if grep -q "^disable-model-invocation: true" .claude/skills/evolve-agents/SKILL.md 2>/dev/null; then
  printf "PASS: evolve-agents/SKILL.md frontmatter carries disable-model-invocation: true\n"
else
  printf "FAIL: evolve-agents/SKILL.md frontmatter missing disable-model-invocation: true\n"
  fail=1
fi

# 3. agent-creation-brief.md exists
if [[ -f .claude/skills/evolve-agents/references/agent-creation-brief.md ]]; then
  printf "PASS: agent-creation-brief.md present\n"
else
  printf "FAIL: agent-creation-brief.md missing\n"
  fail=1
fi

# 4. evolve-agents combined SKILL.md patch present (gate sentinel + Phase 1 artifact + Phase 3 gate)
if grep -q "<!-- evolve-agents-gate-installed -->" .claude/skills/evolve-agents/SKILL.md 2>/dev/null; then
  printf "PASS: evolve-agents-gate-installed sentinel present\n"
else
  printf "FAIL: evolve-agents-gate-installed sentinel missing\n"
  fail=1
fi
for marker in "evolve-agents-audit-latest" "## Gate Complete" "find .claude/agents/" "agent-creation-brief.md"; do
  if grep -qF "$marker" .claude/skills/evolve-agents/SKILL.md 2>/dev/null; then
    printf "PASS: evolve-agents/SKILL.md contains '%s'\n" "$marker"
  else
    printf "FAIL: evolve-agents/SKILL.md missing '%s'\n" "$marker"
    fail=1
  fi
done

# 5. spec-fidelity.md and evolve-agents-gate.md rule files present
for rule in .claude/rules/spec-fidelity.md .claude/rules/evolve-agents-gate.md; do
  if [[ -f "$rule" ]]; then
    printf "PASS: %s present\n" "$rule"
  else
    printf "FAIL: %s missing\n" "$rule"
    fail=1
  fi
done

# 6. audit-agents A9 + A10 sections present + sentinel
if grep -q "<!-- audit-agents-A9-A10-installed -->" .claude/skills/audit-agents/SKILL.md 2>/dev/null; then
  printf "PASS: audit-agents-A9-A10-installed sentinel present\n"
else
  printf "FAIL: audit-agents-A9-A10-installed sentinel missing\n"
  fail=1
fi
for heading in "^### A9:" "^### A10:"; do
  if grep -qE "$heading" .claude/skills/audit-agents/SKILL.md 2>/dev/null; then
    printf "PASS: audit-agents/SKILL.md contains heading matching '%s'\n" "$heading"
  else
    printf "FAIL: audit-agents/SKILL.md missing heading matching '%s'\n" "$heading"
    fail=1
  fi
done

# 7. evolve-agents spec frontmatter backfilled (try both legacy and current paths)
SPEC_FOUND=0
for candidate in .claude/specs/2026-04-01-evolve-agents.md .claude/specs/main/2026-04-27-evolve-agents-skill-eval-spec.md; do
  if [[ -f "$candidate" ]]; then
    SPEC_FOUND=1
    extracted=$(awk 'NR==1&&/^---/{d=1;next} NR==1{exit} d==1&&/^---/{d=2;next} d==2{exit} d==1&&/^covers-skill:/{print $2;exit}' "$candidate")
    if [[ "$extracted" == "evolve-agents" ]]; then
      printf "PASS: %s carries covers-skill: evolve-agents\n" "$candidate"
    else
      printf "WARN: %s does not carry covers-skill: evolve-agents (extracted='%s' — may be SKIP_HAND_EDITED case)\n" "$candidate" "$extracted"
    fi
    break
  fi
done
[[ $SPEC_FOUND -eq 0 ]] && printf "WARN: no evolve-agents spec found at any candidate path — covers-skill backfill not applicable\n"

# 8. deep-think spec frontmatter backfilled (Glob discovery)
shopt -s nullglob
DEEP_CANDIDATES=( .claude/specs/main/*deep-think*spec*.md .claude/specs/*deep-think*spec*.md )
shopt -u nullglob
if [[ ${#DEEP_CANDIDATES[@]} -eq 1 ]]; then
  candidate="${DEEP_CANDIDATES[0]}"
  extracted=$(awk 'NR==1&&/^---/{d=1;next} NR==1{exit} d==1&&/^---/{d=2;next} d==2{exit} d==1&&/^covers-skill:/{print $2;exit}' "$candidate")
  if [[ "$extracted" == "deep-think" ]]; then
    printf "PASS: %s carries covers-skill: deep-think\n" "$candidate"
  else
    printf "WARN: %s does not carry covers-skill: deep-think (extracted='%s' — may be SKIP_HAND_EDITED case)\n" "$candidate" "$extracted"
  fi
else
  printf "WARN: deep-think spec glob count = %d (expected 1) — covers-skill backfill not applicable\n" "${#DEEP_CANDIDATES[@]}"
fi

# 9. Deviations block present in evolve-agents/SKILL.md
if grep -q "<!-- evolve-agents-deviations-installed -->" .claude/skills/evolve-agents/SKILL.md 2>/dev/null; then
  printf "PASS: evolve-agents-deviations-installed sentinel present\n"
else
  printf "FAIL: evolve-agents-deviations-installed sentinel missing\n"
  fail=1
fi
if grep -q "^## Deviations from spec" .claude/skills/evolve-agents/SKILL.md 2>/dev/null; then
  printf "PASS: evolve-agents/SKILL.md '## Deviations from spec' heading present\n"
else
  printf "FAIL: evolve-agents/SKILL.md '## Deviations from spec' heading missing\n"
  fail=1
fi

# 10. Awk extraction works on backfilled spec
extracted=""
for candidate in .claude/specs/2026-04-01-evolve-agents.md .claude/specs/main/2026-04-27-evolve-agents-skill-eval-spec.md; do
  [[ -f "$candidate" ]] || continue
  extracted=$(awk 'NR==1&&/^---/{d=1;next} NR==1{exit} d==1&&/^---/{d=2;next} d==2{exit} d==1&&/^covers-skill:/{print $2;exit}' "$candidate")
  break
done
if [[ "$extracted" == "evolve-agents" ]]; then
  printf "PASS: awk extraction yields 'evolve-agents'\n"
else
  printf "WARN: awk extraction yielded '%s' (expected 'evolve-agents' — may be SKIP_HAND_EDITED case)\n" "$extracted"
fi

# 11. bootstrap-state.json updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "055" ]]; then
  printf "PASS: last_migration = 055\n"
else
  printf "FAIL: last_migration = %s (expected 055)\n" "$last"
  fail=1
fi

printf -- "---\n"
if [[ $fail -eq 0 ]]; then
  printf "Migration 055 verification: ALL PASS\n"
  printf "\nOptional cleanup: remove .bak-055 backups once you've confirmed patches are correct:\n"
  printf "  find .claude -name '*.bak-055*' -delete\n"
else
  printf "Migration 055 verification: FAILURES — state NOT updated\n"
  exit 1
fi
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix. `SKIP_HAND_EDITED` from any destructive step will cause the corresponding verify-step to FAIL — resolve by applying the relevant `## Manual-Apply-Guide` section, then re-run verify.

---

## State Update

On success:
- `last_migration` → `"055"`
- append `{ "id": "055", "applied_at": "<ISO8601>", "description": "/evolve-agents safety pack: disable-model-invocation frontmatter + Phase 1 audit-artifact persistence + Phase 3 pre-flight gate + agent-creation-brief.md reference + spec-fidelity audit (covers-skill convention + A10 invariant) + audit-agents A9/A10 + 2 spec frontmatter backfills + Deviations block." }` to `applied[]`

---

## Idempotency

Re-running after success:
- Top-level — every patched file carries its sentinel + every additive file exists → `SKIP: migration 055 already applied (all sentinels + additive files present)`
- Step 1 (proj-code-writer-markdown Before Writing) — `<!-- before-writing-ref-block-installed -->` OR `Read ALL listed paths before proceeding` present → `SKIP_ALREADY_APPLIED`
- Step 2 (disable-model-invocation) — `^disable-model-invocation: true` line present → `SKIP_ALREADY_APPLIED`
- Step 3 (agent-creation-brief.md) — file exists → `SKIP_ALREADY_APPLIED`
- Step 4 (combined SKILL.md patch) — `<!-- evolve-agents-gate-installed -->` present → `SKIP_ALREADY_APPLIED`
- Step 5 (spec-fidelity.md) — file exists → `SKIP_ALREADY_APPLIED`
- Step 6 (evolve-agents-gate.md) — file exists → `SKIP_ALREADY_APPLIED`
- Step 7 (audit-agents A9/A10) — `<!-- audit-agents-A9-A10-installed -->` present → `SKIP_ALREADY_APPLIED`
- Step 8 (evolve-agents spec frontmatter) — awk extraction yields `evolve-agents` → `SKIP_ALREADY_APPLIED`
- Step 9 (deep-think spec frontmatter) — awk extraction yields `deep-think` → `SKIP_ALREADY_APPLIED`
- Step 10 (Deviations block) — `<!-- evolve-agents-deviations-installed -->` present → `SKIP_ALREADY_APPLIED`
- Step 11 (`applied[]` dedup check, migration id == `'055'`) → no duplicate append

No backups are rewritten on re-run. Files that were `SKIP_HAND_EDITED` on first apply remain `SKIP_HAND_EDITED` on re-run (baseline anchors absent or post-migration sentinel absent) — manual merge per `## Manual-Apply-Guide` is still required.

---

## Rollback

```bash
#!/usr/bin/env bash
set -euo pipefail

# Option A — restore from .bak-055 backups (written by destructive steps before overwrite)
for bak in \
  .claude/agents/proj-code-writer-markdown.md.bak-055-batch0 \
  .claude/skills/evolve-agents/SKILL.md.bak-055-batch2 \
  .claude/skills/audit-agents/SKILL.md.bak-055-batch3 \
  .claude/specs/2026-04-01-evolve-agents.md.bak-055-batch4-evolve \
  .claude/specs/main/2026-04-27-evolve-agents-skill-eval-spec.md.bak-055-batch4-evolve \
  .claude/specs/main/*deep-think*spec*.md.bak-055-batch4-deepthink \
  .claude/specs/*deep-think*spec*.md.bak-055-batch4-deepthink; do
  [[ -f "$bak" ]] || continue
  orig="${bak%.bak-055-batch0}"
  orig="${orig%.bak-055-batch2}"
  orig="${orig%.bak-055-batch3}"
  orig="${orig%.bak-055-batch4-evolve}"
  orig="${orig%.bak-055-batch4-deepthink}"
  mv "$bak" "$orig"
  printf "Restored: %s\n" "$orig"
done

# Option B — remove additive files (created net-new by this migration)
for added in \
  .claude/skills/evolve-agents/references/agent-creation-brief.md \
  .claude/rules/spec-fidelity.md \
  .claude/rules/evolve-agents-gate.md; do
  if [[ -f "$added" ]]; then
    rm -f "$added"
    printf "REMOVED: %s\n" "$added"
  fi
done

# Option C — tracked strategy (if .claude/ is committed to project repo)
# git restore .claude/agents/ .claude/skills/ .claude/rules/ .claude/specs/

# Reset bootstrap-state.json
python3 <<'PY'
import json
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
if state.get('last_migration') == '055':
    state['last_migration'] = '054'
state['applied'] = [a for a in state.get('applied', []) if not (
    (isinstance(a, dict) and a.get('id') == '055') or a == '055'
)]
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State rolled back to last_migration=054')
PY
```

Notes:
- `.bak-055-*` restore is safe because each destructive step writes the backup before overwrite. Files that hit `SKIP_HAND_EDITED` (baseline anchor absent) wrote a backup before reporting the skip — the rollback restores the original content.
- After rollback, the sentinels appended at insertion sites are gone (the entire pre-migration content is restored from backups). No manual sentinel removal needed.
- Additive files (Steps 3, 5, 6) are deleted on rollback — they were net-new in this migration.
- The Deviations block append (Step 10) is rolled back via SKILL.md backup restore from `.bak-055-batch2` (the same backup that Step 4 created, since both Step 4 and Step 10 modify the same file; Step 10's append happens after Step 4's combined patch, so the Step 4 backup captures pre-migration state for both edits).
- If no backup exists for a file, it was either `SKIP_ALREADY_APPLIED` (nothing to roll back — pre-existing post-migration state) or never touched (nothing to roll back).

---

## Post-Apply — Bootstrap Repo Self-Update

This migration targets client projects. The bootstrap repo's own `.claude/` copies are
generated output, not source of truth. To update the bootstrap repo's installed copies:

1. Run `/migrate-bootstrap` against the bootstrap repo itself, OR re-run each step manually against the bootstrap repo's `.claude/` (the templates at `templates/agents/proj-code-writer-markdown.md`, `templates/skills/evolve-agents/SKILL.md`, `templates/skills/evolve-agents/references/agent-creation-brief.md`, `templates/skills/audit-agents/SKILL.md`, `templates/rules/spec-fidelity.md`, and `templates/rules/evolve-agents-gate.md` are already in the target state after the paired bootstrap edits).
2. Do NOT directly edit any of those files in the bootstrap repo's `.claude/` directory — direct edits bypass the templates and create drift.

Reference: `.claude/rules/general.md` §Process — "NEVER write to this repo's `.claude/` as implementation work."

---

## Manual-Apply-Guide

When a step reports `SKIP_HAND_EDITED: <path>`, the migration detected that the target was customized post-bootstrap (baseline anchor absent + post-migration sentinel absent). Automatic patching is unsafe — content would be lost. This guide provides the verbatim new-content blocks plus merge instructions so you can manually integrate the changes while preserving your customizations.

**General procedure per skipped step**:
1. Open the target file.
2. Locate the section / block / anchor named in the merge instructions for that step.
3. Read the new content block below for that step.
4. Manually merge: preserve your project-specific additions (extra steps, custom comments, additional sections); incorporate the new content from the migration.
5. Save the file.
6. Append the post-migration sentinel where indicated (each section below specifies the exact sentinel string).
7. Run the verification snippet shown at the end of each subsection to confirm the patch landed correctly.
8. A `.bak-055-batchN` backup of the pre-migration file state exists at `<path>.bak-055-batchN`; use `diff <path>.bak-055-batchN <path>` to see exactly what changed.

---

### §Step-1 — `proj-code-writer-markdown.md` Before Writing block (Batch 0)

**Target**: `.claude/agents/proj-code-writer-markdown.md` — `## Before Writing (MANDATORY)` section.

**Context**: the migration detected that the file's Before Writing block has been customized post-bootstrap (either the post-migration sentinel `<!-- before-writing-ref-block-installed -->` is absent AND baseline anchor `Verify all cross-references` is absent, OR the new step 5 keyphrase `If dispatch prompt contains` is already partially present — meaning the file may be in a half-patched state).

**New content (verbatim — replace the existing `## Before Writing (MANDATORY)` block end-to-end)**:

```markdown
## Before Writing (MANDATORY)
1. If `.claude/rules/mcp-routing.md` action→tool table populated (MCP project): use MCP tools per routing table for code discovery BEFORE Grep/Read (see that rule's Lead-With Order)
2. Read target file (if modifying) | 2-3 similar files (if creating)
3. Read `.claude/rules/code-standards-markdown.md` — follow conventions exactly
4. Read applicable technique refs:
   - `techniques/prompt-engineering.md` → RCCF framework, token optimization
   - `techniques/anti-hallucination.md` → verification patterns, false-claims mitigation
   - `techniques/agent-design.md` → subagent constraints, orchestrator patterns
5. If dispatch prompt contains a `#### Reference Files` block or `Read these before writing:` directive: Read ALL listed paths before proceeding. No exceptions — reference files are part of the mandatory pre-write context.
6. Verify all cross-references — every file path mentioned must exist
7. Check module numbering — read `claude-bootstrap.md` for current module list

<!-- before-writing-ref-block-installed -->
```

**Merge instructions**:
1. Open `.claude/agents/proj-code-writer-markdown.md`.
2. Locate the `## Before Writing (MANDATORY)` section (typically lines 48-58 in stock template).
3. Replace the entire block (from `## Before Writing (MANDATORY)` through the last numbered step before the next `## ` heading) with the verbatim block above.
4. The original 5-step block had a duplicate `2.` numbering bug; the new 7-step block fixes it. If you added project-specific steps to the original block, preserve them by inserting them at semantically-correct positions in the new 7-step block (typically as additional sub-bullets under step 4 for technique refs, or as new steps after step 7).
5. Save the file.

**Verification**:
```bash
grep -q "<!-- before-writing-ref-block-installed -->" .claude/agents/proj-code-writer-markdown.md && echo "PASS"
grep -q "Read ALL listed paths before proceeding" .claude/agents/proj-code-writer-markdown.md && echo "PASS"
```

---

### §Step-4 — `evolve-agents/SKILL.md` combined patch (Batch 2)

**Target**: `.claude/skills/evolve-agents/SKILL.md` — three coordinated edits to Phase 1 body, Phase 3 body, and Phase 3 step 3 dispatch prompt.

**Context**: the migration detected that the file's body has been customized post-bootstrap — required baseline anchors (`### Phase 1: Audit Existing Specialists`, `### Phase 3: Create New Specialists`, `Same pipeline as Module 07:`) are not all present in stock form.

**Edit A — Phase 1 audit-artifact Write call** (verbatim — insert at end of Phase 1 body, immediately BEFORE `### Phase 2:` heading):

```markdown
After all 4 audit checks complete, the dispatched proj-researcher agent MUST write a persistent audit artifact via Bash heredoc:

```bash
mkdir -p .claude/reports
cat > .claude/reports/evolve-agents-audit-latest.md <<'AUDIT_EOF'
# /evolve-agents Audit — {ISO8601 timestamp}

## Version Drift Findings
{per-agent findings}

## Reference Staleness Findings
{per-reference findings}

## Missing-Pattern Findings
{per-agent findings from .learnings/log.md}

## Dispatch Frequency Findings
{per-agent usage counts from .learnings/agent-usage.log}

## Gate Complete
AUDIT_EOF
```

The trailing `## Gate Complete` heading is REQUIRED — Phase 3 pre-flight gate greps for it as the artifact integrity check. A missing or truncated artifact fails the gate.
```

**Edit B — Phase 3 pre-flight gate snippet** (verbatim — replace the existing `Same pipeline as Module 07:` line and any blank line that follows it; the sentinel `<!-- evolve-agents-gate-installed -->` is part of this block):

```markdown
Same pipeline as Module 07:

Before dispatching, run the pre-flight gate (Bash):

```bash
ARTIFACT=".claude/reports/evolve-agents-audit-latest.md"
if [[ ! -f "$ARTIFACT" ]]; then
  echo "BLOCK: No audit artifact found. Run /evolve-agents Phase 1 first (or pass --skip-audit-gate)."
  exit 1
fi
if ! grep -q "^## Gate Complete" "$ARTIFACT"; then
  echo "BLOCK: Audit artifact missing Gate Token (truncated write?). Re-run Phase 1."
  exit 1
fi
STALE_AGENTS=$(find .claude/agents/ -type f \( -name 'proj-code-writer-*.md' -o -name 'proj-test-writer-*.md' \) -newer "$ARTIFACT" 2>/dev/null)
if [[ -n "$STALE_AGENTS" ]]; then
  echo "WARN: Agent files modified after audit artifact — consider re-running Phase 1:"
  echo "$STALE_AGENTS"
fi
```
<!-- evolve-agents-gate-installed -->

Gate PASS (no exit 1) → proceed to dispatch steps.
```

**Edit C — Phase 3 step 3 dispatch prompt extension** (verbatim — insert immediately after the existing line `   Write to `.claude/agents/proj-code-writer-{lang}-{framework}.md`` in Phase 3):

```markdown

   Dispatch prompt MUST include this block (triggers proj-code-writer-markdown Before Writing step 5):

   ```
   #### Reference Files
   Read these before writing:
   - `templates/skills/evolve-agents/references/agent-creation-brief.md` — agent conformance checklist + required sections; governs the generated agent's structure
   - `.claude/skills/code-write/references/markdown-analysis.md` — component classification table, tools whitelists, frontmatter field spec
   ```
```

**Merge instructions**:
1. Open `.claude/skills/evolve-agents/SKILL.md`.
2. Apply Edit A: locate the end of Phase 1 body (just before the `### Phase 2: Detect New Frameworks` heading) and insert the audit-artifact Write call block.
3. Apply Edit B: locate the `Same pipeline as Module 07:` line in Phase 3, and replace it (plus any trailing blank line) with the gate snippet block above. The sentinel `<!-- evolve-agents-gate-installed -->` MUST be on its own line right after the gate code-fence — its presence is what marks this combined patch as applied.
4. Apply Edit C: locate the line `   Write to `.claude/agents/proj-code-writer-{lang}-{framework}.md`` in Phase 3 step 3, and insert the dispatch-prompt extension block immediately after it.
5. Preserve any project-specific Phase 1 / Phase 2 / Phase 3 / Phase 4 / Phase 5 customizations you have added.
6. Save the file.

**Verification**:
```bash
grep -q "<!-- evolve-agents-gate-installed -->" .claude/skills/evolve-agents/SKILL.md && echo "PASS sentinel"
grep -q "evolve-agents-audit-latest.md" .claude/skills/evolve-agents/SKILL.md && echo "PASS artifact path"
grep -q "^## Gate Complete" .claude/skills/evolve-agents/SKILL.md && echo "PASS gate token"
grep -q "agent-creation-brief.md" .claude/skills/evolve-agents/SKILL.md && echo "PASS brief reference"
```

---

### §Step-7 — `audit-agents/SKILL.md` A9 + A10 sections (Batch 3.3)

**Target**: `.claude/skills/audit-agents/SKILL.md` — append A9 (gate audit) + A10 (spec-fidelity audit) sections after the existing A8 wave-protocol checks; extend YAML report schema; extend fix-guidance list.

**Context**: the migration detected that the file's body has been customized post-bootstrap — either the A8 baseline sentinel `<!-- audit-agents-A8-installed -->` is absent (file is pre-A8 state — apply migration 054 first) OR an A9/A10 heading is already partially present (file is in a half-patched state — manual reconciliation required).

**New content — A9 + A10 sections** (verbatim — insert immediately after the line `<!-- audit-agents-A8-installed -->`):

```markdown

### A9: evolve-agents Phase 3 gate presence

Scope: `.claude/skills/evolve-agents/SKILL.md` only (skill-specific check).

Per `.claude/rules/evolve-agents-gate.md` § A9 Audit Behavior:

For `.claude/skills/evolve-agents/SKILL.md`:
1. Sentinel check: `grep -q "<!-- evolve-agents-gate-installed -->" .claude/skills/evolve-agents/SKILL.md` → PASS if hit; FAIL with file:line of frontmatter close if absent.
2. Gate text patterns: verify ALL of `evolve-agents-audit-latest`, `^## Gate Complete`, `find .claude/agents/` appear in body → PASS if all present; FAIL with first missing pattern + file:line evidence if any absent.
3. Phase 1 Write call: verify `evolve-agents-audit-latest.md` appears within the Phase 1 section body (between `### Phase 1:` heading and `### Phase 2:` heading) → PASS if hit; FAIL otherwise.

Skip if `.claude/skills/evolve-agents/SKILL.md` does not exist (project doesn't deploy /evolve-agents) → SKIP with INFO message.

Output (append to YAML report block):
```yaml
A9_evolve_agents_gate: {PASS|FAIL|SKIP}
findings:
  - check: A9
    severity: FAIL
    file: .claude/skills/evolve-agents/SKILL.md
    line: {N}
    detail: "{which check failed; missing pattern; remediation pointer}"
```

### A10: covers-skill spec-fidelity

Scope: all `.claude/specs/**/*.md` files.

Per `.claude/rules/spec-fidelity.md` § A10 Audit Behavior:

For each spec file under `.claude/specs/`:
1. Extract `covers-skill:` value via canonical awk (counter-based, terminates at 2nd `---`):
   ```bash
   skill_name=$(awk 'NR==1&&/^---/{d=1;next} NR==1{exit} d==1&&/^---/{d=2;next} d==2{exit} d==1&&/^covers-skill:/{print $2;exit}' "$spec_file")
   ```
2. If `$skill_name` empty → spec has no `covers-skill:` declaration → SKIP this spec (no fidelity contract).
3. If `$skill_name` non-empty: locate `.claude/skills/{skill_name}/SKILL.md`. If absent → INFO (spec references undeployed skill).
4. If SKILL.md present: `grep -q "^## Deviations from spec" .claude/skills/{skill_name}/SKILL.md` → PASS if hit; WARN otherwise (or FAIL after graduation per `spec-fidelity.md` § WARN→FAIL Graduation: WARN until 5 migrations after the rule's introducing migration ships, FAIL thereafter).

Multi-value `covers-skill: [a, b]` extraction returns malformed `[a,` — log INFO ("multi-value form deferred per spec-fidelity.md") and skip. Single-value form is v1 canonical.

Output (append to YAML report block):
```yaml
A10_covers_skill_fidelity: {PASS|WARN|FAIL|SKIP}
findings:
  - check: A10
    severity: WARN
    spec: .claude/specs/{path}.md
    skill: {extracted skill name}
    detail: "Skill body missing '## Deviations from spec' block — see .claude/rules/spec-fidelity.md for convention"
```
<!-- audit-agents-A9-A10-installed -->
```

**YAML report schema additions** (verbatim — insert in the `### Output` section's YAML block, immediately after the existing line `  A8_wave_force_read:       {PASS|FAIL|SKIP}`):

```yaml
  A9_evolve_agents_gate:    {PASS|FAIL|SKIP}
  A10_covers_skill_fidelity: {PASS|WARN|FAIL|SKIP}
```

**Fix-guidance additions** (verbatim — insert in the `### After the agent returns` list, immediately after the existing bullet `- A8_wave_force_read FAIL → ...`):

```markdown
- A9 FAIL → check `.claude/rules/evolve-agents-gate.md` § A9 Audit Behavior for the missing pattern; re-apply migration 055 if the gate snippet was lost (sentinel `evolve-agents-gate-installed` was removed)
- A10 WARN → add `## Deviations from spec` block to the skill body listing intentional divergences from the cited spec (or write `## Deviations from spec\n\nNone — implementation matches spec.\n` if no divergences); see `.claude/rules/spec-fidelity.md`
- A10 FAIL → same as WARN remediation; FAIL severity indicates graduation criterion has been crossed (5 migrations after 055)
```

**Merge instructions**:
1. Open `.claude/skills/audit-agents/SKILL.md`.
2. Insert the A9 + A10 sections block (with the closing sentinel `<!-- audit-agents-A9-A10-installed -->`) immediately after the existing `<!-- audit-agents-A8-installed -->` line. If your file does not have the A8 sentinel, apply migration 054 first.
3. Insert the YAML report schema additions in the `### Output` section's YAML block, after `A8_wave_force_read:`.
4. Insert the fix-guidance additions in the `### After the agent returns` list, after the `A8_wave_force_read FAIL` bullet.
5. Preserve any project-specific A8 / A9 / A10 customizations you have added.
6. Save the file.

**Verification**:
```bash
grep -q "<!-- audit-agents-A9-A10-installed -->" .claude/skills/audit-agents/SKILL.md && echo "PASS sentinel"
grep -qE "^### A9" .claude/skills/audit-agents/SKILL.md && echo "PASS A9 heading"
grep -qE "^### A10" .claude/skills/audit-agents/SKILL.md && echo "PASS A10 heading"
grep -q "A9_evolve_agents_gate:" .claude/skills/audit-agents/SKILL.md && echo "PASS schema A9"
grep -q "A10_covers_skill_fidelity:" .claude/skills/audit-agents/SKILL.md && echo "PASS schema A10"
```

---

### §Step-8 — evolve-agents spec frontmatter prepend (Batch 4.1)

**Target**: `.claude/specs/2026-04-01-evolve-agents.md` (legacy path) OR `.claude/specs/main/2026-04-27-evolve-agents-skill-eval-spec.md` (current path) — prepend YAML frontmatter declaring `covers-skill: evolve-agents`.

**Context**: the migration detected that the spec file has existing YAML frontmatter (first line is `---`) but the frontmatter does not contain a `covers-skill:` field. Automatic prepending would introduce a duplicate frontmatter block — manual merge required.

**New content (verbatim — to be merged into the existing frontmatter)**:

```yaml
covers-skill: evolve-agents
```

**Merge instructions**:
1. Open the spec file at whichever candidate path exists in your project.
2. If the file does NOT start with `---`: prepend a new frontmatter block by adding these 4 lines at the very top:
   ```
   ---
   covers-skill: evolve-agents
   ---

   ```
   (the trailing blank line is required to separate frontmatter from body content).
3. If the file DOES start with `---` and has an existing YAML frontmatter block: insert the line `covers-skill: evolve-agents` inside the existing frontmatter, between the two `---` markers, in alphabetical order with any other frontmatter fields. Do NOT create a second `---` block.
4. Save the file.

**Verification**:
```bash
for candidate in .claude/specs/2026-04-01-evolve-agents.md .claude/specs/main/2026-04-27-evolve-agents-skill-eval-spec.md; do
  [[ -f "$candidate" ]] || continue
  awk 'NR==1&&/^---/{d=1;next} NR==1{exit} d==1&&/^---/{d=2;next} d==2{exit} d==1&&/^covers-skill:/{print $2;exit}' "$candidate"
done
# Expected output: evolve-agents
```

---

### §Step-9 — deep-think spec frontmatter prepend (Batch 4.2)

**Target**: a deep-think spec file under `.claude/specs/main/*deep-think*spec*.md` or `.claude/specs/*deep-think*spec*.md` — prepend YAML frontmatter declaring `covers-skill: deep-think`.

**Context**: the migration detected that the deep-think spec glob returned multiple matches OR zero matches OR the matched file has existing frontmatter without a `covers-skill:` field.

**New content (verbatim — to be merged into the existing frontmatter)**:

```yaml
covers-skill: deep-think
```

**Merge instructions**:
1. Identify the canonical deep-think spec file in your project. If multiple candidates exist (multiple files matching `*deep-think*spec*.md`), choose the most-current one (typically the file in `.claude/specs/main/` with the latest date prefix).
2. Apply the same merge logic as §Step-8 above: if no existing frontmatter, prepend a new 4-line frontmatter block; if existing frontmatter, insert the `covers-skill: deep-think` line inside the existing block.
3. Save the file.

**Verification**:
```bash
shopt -s nullglob
for candidate in .claude/specs/main/*deep-think*spec*.md .claude/specs/*deep-think*spec*.md; do
  awk 'NR==1&&/^---/{d=1;next} NR==1{exit} d==1&&/^---/{d=2;next} d==2{exit} d==1&&/^covers-skill:/{print $2;exit}' "$candidate"
done
shopt -u nullglob
# Expected output: deep-think (one or more lines)
```

---

### §Step-10 — Deviations block append (Batch 4.3)

**Target**: `.claude/skills/evolve-agents/SKILL.md` — append `## Deviations from spec` block at EOF documenting v6 paradigm + Step 3 / Step 6 absences.

**Context**: this step is additive (sentinel-only); a `SKIP_HAND_EDITED` outcome is impossible by construction. If for some reason the migration did not append the block (e.g., disk error mid-write), apply manually.

**New content (verbatim — append at EOF after a blank line)**:

```markdown

---

## Deviations from spec

Backing spec: `.claude/specs/2026-04-01-evolve-agents.md` (per `covers-skill:` convention defined in `.claude/rules/spec-fidelity.md`).

The deployed skill diverges from the original spec in two documented respects. Both are classified INTENTIONAL per the 2026-04-27 deep-think (round-0-evidence.md + 1.3 E6 finding):

### Deviation 1 — v6 paradigm shift (audit + create-NEW, never split)

- **Spec form**: 2026-04-01 spec described an "audit + split" semantics — when an existing agent grew too large for its scope, the skill would split it into multiple narrower specialists.
- **Deployed form**: v6 paradigm — agents are born right-sized; the skill audits + creates NEW sub-specialists for new frameworks/languages but NEVER splits existing agents.
- **Rationale**: split semantics created two failure modes — (a) loss of accumulated `Known Gotchas` content during the split, and (b) a chicken-and-egg dispatch problem where the splitting agent needed to predict the future scope of its own children. Create-NEW with right-sized initial spec is the correct shape; split is retired.
- **Classification**: INTENTIONAL — present in the FIRST commit of evolve-agents/SKILL.md (2026-04-01); the spec was the inferior design and was superseded at implementation time without an explicit deviation note. Backfilled here per 1.3 E6 finding.

### Deviation 2 — Step 3 (user-approval gate) and Step 6 (wiring) absent

- **Spec form**: 2026-04-01 spec described 6 sequential steps including a user-approval gate at Step 3 (after Phase 1 audit, before Phase 3 creation) and a wiring step at Step 6 (post-creation, registers the new agent into all dispatch maps).
- **Deployed form**: 5 phases; no explicit user-approval gate phase; wiring is folded into Phase 4 (Update Index — regenerates `agent-index.yaml` and `capability-index.md`).
- **Rationale**: The user-approval gate at Step 3 is replaced by the more general Phase 3 pre-flight gate (added by migration 055; see `.claude/rules/evolve-agents-gate.md`) — the gate enforces freshness via persistent audit artifact rather than blocking on user input. Wiring is correctly absorbed into the index-regeneration phase because the index files ARE the wiring (skills + agents discover each other through these indices).
- **Classification**: INTENTIONAL — both gaps were design simplifications, not regressions. The pre-flight gate is a stronger discipline than a one-time approval prompt (it persists across re-runs); the index-regeneration is the wiring (no separate registration step needed).

<!-- evolve-agents-deviations-installed -->
```

**Merge instructions**:
1. Open `.claude/skills/evolve-agents/SKILL.md`.
2. Append the verbatim block above at EOF. The leading `---` separator is intentional — it cleanly visually separates the Deviations block from the body content above.
3. Save the file.

**Verification**:
```bash
grep -q "<!-- evolve-agents-deviations-installed -->" .claude/skills/evolve-agents/SKILL.md && echo "PASS"
grep -q "^## Deviations from spec" .claude/skills/evolve-agents/SKILL.md && echo "PASS"
```

---

## Verification commands

Re-stated from the spec § Verification commands block (`.claude/specs/main/2026-04-27-evolve-agents-skill-eval-spec.md`) for user-facing post-migration validation:

```bash
# Batch 0 — Before Writing block has 7 steps with #### Reference Files entry
grep -c "^#### Reference Files" templates/agents/proj-code-writer-markdown.md .claude/agents/proj-code-writer-markdown.md
# Expect: bootstrap repo bootstrap-side templates may not have a `#### Reference Files` heading verbatim;
# in client projects the deployed agent body carries the new step 5 keyphrase. Use the new keyphrase check below instead.
grep -q "Read ALL listed paths before proceeding" .claude/agents/proj-code-writer-markdown.md && echo "OK: step 5 keyphrase present"

# 3.2 — disable-model-invocation field present
grep -n "^disable-model-invocation: true" .claude/skills/evolve-agents/SKILL.md
# Expect: 1 hit

# 1.1 — Phase 3 gate snippet present + Phase 1 artifact write present
grep -nE "^## Gate Complete|find -newer|evolve-agents-audit-latest" .claude/skills/evolve-agents/SKILL.md
# Expect: ≥3 hits (gate sentinel, find idiom, artifact path)

# 2.2 — reference file exists, Phase 3 dispatch references it
test -f .claude/skills/evolve-agents/references/agent-creation-brief.md && echo OK
grep -n "agent-creation-brief.md" .claude/skills/evolve-agents/SKILL.md
# Expect: file exists; ≥1 brief reference in Phase 3

# 1.3 — covers-skill backfill, spec-fidelity rule exists, A10 added
test -f .claude/rules/spec-fidelity.md && echo OK
test -f .claude/rules/evolve-agents-gate.md && echo OK
grep -nE "^### A9|^### A10" .claude/skills/audit-agents/SKILL.md
# Expect: rule files exist; A9 + A10 present

# Awk extraction works on backfilled spec
for candidate in .claude/specs/2026-04-01-evolve-agents.md .claude/specs/main/2026-04-27-evolve-agents-skill-eval-spec.md; do
  [[ -f "$candidate" ]] || continue
  awk 'NR==1&&/^---/{d=1;next} NR==1{exit} d==1&&/^---/{d=2;next} d==2{exit} d==1&&/^covers-skill:/{print $2;exit}' "$candidate"
done
# Expect: evolve-agents
```

---

## Post-Migration (main-thread only per agent-scope-lock.md)

Append to `migrations/index.json`:
```json
{
  "id": "055",
  "file": "055-evolve-agents-safety-pack.md",
  "description": "/evolve-agents safety pack: (1) frontmatter disable-model-invocation: true blocks model auto-trigger of the consequential creation pipeline; (2) Phase 1 audit-artifact persistence (.claude/reports/evolve-agents-audit-latest.md w/ ## Gate Complete token) + Phase 3 pre-flight gate (find -newer freshness check; sentinel evolve-agents-gate-installed) for evidence-grounded creation discipline; (3) reference-file pattern via agent-creation-brief.md consumed by proj-code-writer-markdown's amended Before Writing block (5→7 steps + duplicate-2 fix; new step 5 enforces dispatch-prompt #### Reference Files reads); (4) spec-fidelity audit via covers-skill: YAML frontmatter convention + audit-agents A10 invariant. Coordinated A9 (1.1 gate audit) + A10 (1.3 spec-fidelity audit) added to audit-agents/SKILL.md after existing A8 wave-protocol checks. Two new rule files: evolve-agents-gate.md + spec-fidelity.md (cp from templates/rules/ defensive). 2 spec frontmatter backfills (covers-skill: evolve-agents, covers-skill: deep-think). 1 Deviations block append documenting v6 paradigm + Step 3/Step 6 absences (INTENTIONAL classification). 4-state outer idempotency + per-step three-tier detection (idempotency sentinel / baseline anchor / SKIP_HAND_EDITED + .bak-055 backup + Manual-Apply-Guide pointer). Manual-Apply-Guide section covers all destructive steps (Batch 0 agent body replace, Batch 2 SKILL.md combined patch, Batch 3 audit-agents A9/A10 insert, Batch 4 spec frontmatter prepends, Batch 4 Deviations append). Glob discovery for deep-think spec filename. Self-contained heredocs for all embedded content per general.md.",
  "breaking": false
}
```
