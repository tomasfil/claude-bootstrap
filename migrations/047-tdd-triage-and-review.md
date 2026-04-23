# Migration 047 — /tdd Phase 1 Triage + Phase 3 Review Integration

<!-- migration-id: 047-tdd-triage-and-review -->

> Restructure the `/tdd` skill into a three-phase pipeline that wraps the existing `proj-tdd-runner` dispatch with a Phase 1 triage step (via `proj-quick-check`) and a Phase 3 post-TDD review step (via the `/review` Skill tool, invoked only on `STATUS: GREEN`). Adds a `STATUS: GREEN|RED` first-line mandate to the `proj-tdd-runner` return contract so Phase 3 routing is a strict string match with no prose parsing. Adds a soft Post-Code-Write advisory block to `/code-write` recommending (but not enforcing) `/review` after non-trivial code-write work. Three migration steps: (a) section replace in `.claude/skills/tdd/SKILL.md` Steps block with three-tier baseline-sentinel detection (destructive); (b) additive STATUS mandate append in `.claude/agents/proj-tdd-runner.md` Pass-by-Reference Contract (additive, sentinel-guarded); (c) additive Post-Code-Write advisory in `.claude/skills/code-write/SKILL.md` (additive, sentinel-guarded). Step (a) ships with a `## Manual-Apply-Guide` providing the verbatim new Steps content for the `SKIP_HAND_EDITED` fallback path.

---

## Metadata

```yaml
id: "047"
breaking: false
affects: [skills, agents]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

The `/tdd` skill in bootstrapped Claude Code environments dispatches `proj-tdd-runner` in a single-step loop with neither pre-dispatch triage nor post-dispatch review. Three compounding failure modes surface in practice:

1. **No Phase 1 triage — redundant TDD work on already-covered features.** When a user invokes `/tdd` for a feature whose behavior is already covered by existing tests, the skill enters the full red-green-refactor cycle with no visibility that the work is redundant. The TDD runner writes a new failing test, implements code to pass it, and then discovers (or does not discover) that the asserted behavior was already asserted elsewhere. Cost: one full runner dispatch (opus, maxTurns:150) per redundancy miss, plus the cognitive cost of the user noticing the duplication after the fact. Fix: a cheap haiku triage step (`proj-quick-check`) returning a 4-field structured brief `{TEST_FILE_EXISTS, FEATURE_IN_TESTS, COVERAGE_SIGNAL, TEST_FILE_PATH}` before the runner dispatch. Binary stop condition: `TEST_FILE_EXISTS=yes AND FEATURE_IN_TESTS=yes` → emit `TRIVIALLY_COVERED` advisory and exit the skill. `COVERAGE_SIGNAL` is context enrichment for user-facing advisory text; it is NOT part of the stop condition, to keep the gate binary and low-false-negative.

2. **No Phase 3 review — TDD changes handed off to user without code-reviewer pass.** After `proj-tdd-runner` completes GREEN, the skill returns the TDD report path and the user proceeds to commit. The user must remember to invoke `/review` manually, and frequently does not. TDD-generated code is exactly the kind of code that benefits from a structured reviewer pass — fresh implementation, possibly minimal, possibly carrying RCCF / naming / cross-reference issues that the runner's "minimal change to pass test" discipline does not catch. Fix: Phase 3 inside `/tdd` invokes `/review` via the Skill tool automatically when the runner returns `STATUS: GREEN`. Skipped on `STATUS: RED` — reviewer findings against failing code are meaningless noise.

3. **No machine-readable runner return contract.** The existing `proj-tdd-runner` return summary is free-form prose (`{report path} — {summary}`, <100 chars). Phase 3 routing needs a non-ambiguous token to gate the `/review` invocation — parsing prose for "all tests pass" / "tests failing" is fragile. Fix: mandate `STATUS: GREEN` | `STATUS: RED` as the FIRST LINE of the runner's return summary. Phase 3 does a strict string match on the first line — no inference, no regex over the body.

Secondary fix: `/code-write` gets a parallel but *softer* recommendation. Unlike `/tdd`, where the freshly-generated code pattern justifies enforcing `/review`, `/code-write` handles a broader range of edit scopes (typo fixes, config tweaks, mechanical renames) where forcing reviewer dispatch creates friction without proportionate signal. The new Post-Code-Write advisory block points users toward `/review` for non-trivial changes but leaves the decision to judgment — matching the existing `/code-write` idiom of dispatching specialists sized to the scope.

---

## Changes

| File | Change |
|---|---|
| `.claude/skills/tdd/SKILL.md` | DESTRUCTIVE section replace: `### Steps` block rewritten into Phase 1 (triage via `proj-quick-check`) + Phase 2 (existing TDD cycle via `proj-tdd-runner`) + Phase 3 (invoke `/review` via Skill tool on `STATUS: GREEN`). Dispatch Map updated to add `proj-quick-check` + `/review`. Pre-flight agent existence list updated to include `proj-quick-check`. Three-tier baseline-sentinel detection per `.claude/rules/general.md` Migration Preservation Discipline — hand-edited files receive `SKIP_HAND_EDITED` + `.bak-047` + pointer to `## Manual-Apply-Guide`. |
| `.claude/agents/proj-tdd-runner.md` | ADDITIVE append: `STATUS: GREEN|RED` first-line mandate appended to `## Pass-by-Reference Contract` section. Sentinel-guarded idempotency on `STATUS: GREEN` substring. |
| `.claude/skills/code-write/SKILL.md` | ADDITIVE insert: `### Post-Code-Write (advisory — Post-Module-07 only)` block inserted immediately before `### Anti-Hallucination` at the end of the Steps section. Sentinel-guarded idempotency on `Post-Code-Write` header substring. |
| `.claude/bootstrap-state.json` | Advance `last_migration` → `"047"` + append `047` entry to `applied[]`. |

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -f ".claude/skills/tdd/SKILL.md" ]] || { echo "ERROR: .claude/skills/tdd/SKILL.md missing — run full bootstrap first"; exit 1; }
[[ -f ".claude/agents/proj-tdd-runner.md" ]] || { echo "ERROR: .claude/agents/proj-tdd-runner.md missing — run full bootstrap first"; exit 1; }
[[ -f ".claude/skills/code-write/SKILL.md" ]] || { echo "ERROR: .claude/skills/code-write/SKILL.md missing — run full bootstrap first"; exit 1; }
[[ -f ".claude/agents/proj-quick-check.md" ]] || { echo "ERROR: .claude/agents/proj-quick-check.md missing — required for Phase 1 triage (install via /migrate-bootstrap or /module-write)"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }
```

### Step 1 — Patch `.claude/skills/tdd/SKILL.md` (destructive Steps section replace)

Read-before-write with three-tier baseline-sentinel detection on the destructive section replace.

- **(a)** idempotency sentinel — `Phase 1 — Triage` substring present anywhere in the file → `SKIP: already patched`.
- **(b)** baseline sentinel — pre-047 single-dispatch Steps form present (specifically the line `Dispatch agent via \`subagent_type="proj-tdd-runner"\`` appearing as the first step line under the `### Steps` heading) → safe PATCH: replace the entire Steps section with the new Phase 1/2/3 structure + update Dispatch Map + update Pre-flight agent existence list. Write `.bak-047` backup first.
- **(c)** neither sentinel present → `SKIP_HAND_EDITED` + `.bak-047` backup + pointer to `## Manual-Apply-Guide § Step-1`.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import os, shutil, sys

path = ".claude/skills/tdd/SKILL.md"
idempotency_sentinel = "Phase 1 — Triage"
baseline_sentinel = 'Dispatch agent via `subagent_type="proj-tdd-runner"`'

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Tier (a) — idempotency
if idempotency_sentinel in content:
    print(f"SKIP: {path} already patched (Phase 1 — Triage sentinel present)")
    sys.exit(0)

# Tier (b) — baseline sentinel check (pre-047 single-dispatch form)
if baseline_sentinel not in content:
    # Tier (c) — hand-edited
    backup = path + ".bak-047"
    if not os.path.exists(backup):
        shutil.copy2(path, backup)
        print(f"BACKUP: wrote {backup}")
    print(f"SKIP_HAND_EDITED: {path} — neither idempotency sentinel nor baseline sentinel present.")
    print("This file was customized post-bootstrap. Automatic patching would lose your changes.")
    print("See '## Manual-Apply-Guide' § Step-1 in migrations/047-tdd-triage-and-review.md for the verbatim")
    print("new-content blocks + merge instructions. After manual merge, rerun this migration to advance state.")
    sys.exit(0)

# Baseline matched — safe PATCH. Write backup first.
backup = path + ".bak-047"
if not os.path.exists(backup):
    shutil.copy2(path, backup)
    print(f"BACKUP: wrote {backup}")

# Build the new file content.
# Strategy: locate frontmatter (between two `---` fences) + locate `## /tdd — Red-Green-Refactor` header,
# replace everything from there onward with the canonical Phase 1/2/3 body.

parts = content.split("---\n", 2)
if len(parts) < 3:
    print(f"FAIL: {path} missing YAML frontmatter — cannot anchor replacement")
    sys.exit(1)

prefix, frontmatter, _body = parts[0], parts[1], parts[2]

# Rewrite frontmatter comment to reflect three-phase structure.
frontmatter_new_lines = []
for line in frontmatter.splitlines():
    if line.startswith("# Skill Class:"):
        frontmatter_new_lines.append("# Skill Class: main-thread — three-phase orchestrator, dispatches proj-quick-check + proj-tdd-runner + /review")
    else:
        frontmatter_new_lines.append(line)
new_frontmatter = "\n".join(frontmatter_new_lines)
if not new_frontmatter.endswith("\n"):
    new_frontmatter += "\n"

new_body = """
## /tdd — Red-Green-Refactor

## Pre-flight (REQUIRED — before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

Agent existence check list:
- `proj-quick-check` — required for Phase 1 triage
- `proj-tdd-runner` — required for Phase 2 TDD cycle

## Dispatch Map
- Triage: `proj-quick-check`
- Red-Green-Refactor cycle: `proj-tdd-runner`
- Post-TDD review: `/review` (via Skill tool, STATUS: GREEN only)

**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: dispatch `proj-quick-check` (simple) | `proj-researcher` (deep). Read directly ONLY for known exact path (Tier 1 per main-thread-orchestrator.md). MCP-indexed projects: named-symbol lookups MUST go through cmm.search_graph (see mcp-routing.md). Never built-in `Explore` / `general-purpose` / plugin.
See `techniques/agent-design.md § Agent Dispatch Policy`.

### Steps

#### Phase 1 — Triage (proj-quick-check)

Dispatch `subagent_type="proj-quick-check"` w/ a 4-field structured brief to determine whether the feature is already test-covered before entering the TDD cycle.

Brief fields (triage agent must return these exact keys):
- `TEST_FILE_EXISTS`: `yes|no` — does any test file plausibly cover the feature's module/component?
- `FEATURE_IN_TESTS`: `yes|no` — does any existing test reference the specific feature / behavior / symbol?
- `COVERAGE_SIGNAL`: `full|partial|none` — context enrichment only (NOT used in stop condition)
- `TEST_FILE_PATH`: `<path>|null` — path to most-relevant existing test file, or null

Binary stop condition (TRIVIALLY_COVERED):
- `TEST_FILE_EXISTS=yes AND FEATURE_IN_TESTS=yes` → emit advisory: "Feature already tested at {TEST_FILE_PATH}. TRIVIALLY_COVERED. Proceed with Phase 2 only if adding new behavior beyond what existing tests assert." → exit skill.
- Any other combination → proceed to Phase 2.

Note: `COVERAGE_SIGNAL` is context enrichment for the user (shown in advisory output when relevant), NOT part of the stop condition. Do not gate Phase 2 on coverage strength.

#### Phase 2 — TDD cycle (proj-tdd-runner)

Dispatch `subagent_type="proj-tdd-runner"` w/:
- Feature/behavior specification from user
- Test conventions path: `.claude/rules/code-standards-{lang}.md`
- Build command: {build_command}
- Test single command: {test_single_command}
- Test suite command: {test_suite_command}
- Write results to `.claude/reports/tdd-{timestamp}.md`
- Return path + summary

**Return contract**: proj-tdd-runner MUST emit `STATUS: GREEN` (all tests pass, refactor clean) OR `STATUS: RED` (tests failing or skipped) as the FIRST LINE of its return summary. Phase 3 routes on this exact token — no prose parsing, no inference.

#### Phase 3 — Review (/review via Skill tool, GREEN only)

Parse first line of Phase 2 return summary:
- `STATUS: GREEN` → invoke `/review` via Skill tool to run code-reviewer over the TDD changes before handoff to user.
- `STATUS: RED` → skip /review. Report RED status + TDD report path to user. Do NOT invoke /review on failing code — reviewer findings are meaningless against broken tests.

### TDD Cycle (within Phase 2 agent)
- **RED** — write test describing expected behavior → run → must FAIL
- **GREEN** — write minimum code to pass → run → must PASS
- **REFACTOR** — clean up w/ tests green → run after each step
- Repeat per behavior/scenario

### Anti-Hallucination
- Read existing tests first → match conventions
- Test passes immediately → not testing new behavior, rethink
- Verify types/methods referenced in tests actually exist (LSP or Grep)
- Phase 1 triage must use structured 4-field return; never synthesize field values without file:line evidence
- Phase 3 routing is strict string match on `STATUS: GREEN` — do NOT invoke /review on ambiguous / missing status line
"""

new_content = prefix + "---\n" + new_frontmatter + "---\n" + new_body

with open(path, "w", encoding="utf-8") as f:
    f.write(new_content)

print(f"PATCHED: {path} (Steps section replaced with Phase 1/2/3 structure; Dispatch Map + Pre-flight updated)")
PY
```

### Step 2 — Patch `.claude/agents/proj-tdd-runner.md` (additive STATUS mandate append)

Additive append — idempotency-guarded.

- **(a)** idempotency sentinel — `STATUS: GREEN` substring already present → `SKIP: already patched`.
- **(b)** else — append the STATUS mandate block to the `## Pass-by-Reference Contract` section. No backup written (additive-only step).

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import os, sys

path = ".claude/agents/proj-tdd-runner.md"

if not os.path.exists(path):
    print(f"SKIP: {path} not present — agent not installed in this project")
    sys.exit(0)

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Tier (a) — idempotency
if "STATUS: GREEN" in content:
    print(f"SKIP: {path} already contains STATUS: GREEN sentinel")
    sys.exit(0)

# Locate the `## Pass-by-Reference Contract` section and append the STATUS mandate to it.
anchor = "## Pass-by-Reference Contract"
if anchor not in content:
    print(f"WARNING: {path} missing '## Pass-by-Reference Contract' anchor — Step 2 skipped (agent body appears hand-edited).")
    print("Migration continues — Steps 3 and 4 will still run. Hand-patch this file manually:")
    print("add the following block to the agent body after the Pass-by-Reference Contract section:")
    print("---")
    print("Return summary MUST start with: `STATUS: GREEN` (all tests pass, refactor clean) OR `STATUS: RED` (tests failing or skipped).")
    print("First line of summary is machine-readable. /tdd Phase 3 routes on this value.")
    print("Never fabricate STATUS: GREEN — if tests fail after 3 fix attempts, emit STATUS: RED with failure detail.")
    print("---")
    print("Convention: anchor-missing → non-fatal skip (per migrations 031/039/042/049). Rerun migration after manual merge to confirm sentinel.")
    sys.exit(0)

# Find the end of the Pass-by-Reference Contract block — the next blank line followed by a `## ` header, or EOF.
anchor_idx = content.index(anchor)
# Scan forward for the next `## ` (top-level heading other than the anchor) OR end-of-file.
scan_start = anchor_idx + len(anchor)
next_heading_idx = -1
search_pos = scan_start
while True:
    candidate = content.find("\n## ", search_pos)
    if candidate == -1:
        break
    next_heading_idx = candidate
    break

if next_heading_idx == -1:
    # Append at end of file (normalize trailing whitespace)
    body_before = content.rstrip() + "\n"
    body_after = ""
    insert_at = len(body_before)
    content_normalized = body_before
else:
    # Insert immediately before the next top-level heading (preserve the blank line before it).
    # Rewind to just before the blank line preceding the heading, if any.
    block_end = next_heading_idx
    # Trim trailing blank lines from the contract section to keep formatting tidy.
    while block_end > 0 and content[block_end - 1] in ("\n",):
        block_end -= 1
    insert_at = block_end
    body_before = content[:insert_at].rstrip("\n") + "\n"
    body_after = content[insert_at:]
    content_normalized = None

mandate = (
    "\nReturn summary MUST start with: `STATUS: GREEN` (all tests pass, refactor clean) OR `STATUS: RED` (tests failing or skipped).\n"
    "First line of summary is machine-readable. /tdd Phase 3 routes on this value — STATUS: GREEN invokes /review; STATUS: RED skips review.\n"
    "Never fabricate STATUS: GREEN — if tests fail after 3 fix attempts, emit STATUS: RED with failure detail in the report.\n"
)

if next_heading_idx == -1:
    new_content = body_before + mandate
else:
    new_content = body_before + mandate + "\n" + body_after

with open(path, "w", encoding="utf-8") as f:
    f.write(new_content)

print(f"PATCHED: {path} (STATUS: GREEN|RED first-line mandate appended to Pass-by-Reference Contract)")
PY
```

### Step 3 — Patch `.claude/skills/code-write/SKILL.md` (additive Post-Code-Write advisory)

Additive insert — idempotency-guarded.

- **(a)** idempotency sentinel — `Post-Code-Write` substring already present → `SKIP: already patched`.
- **(b)** else — insert the advisory block immediately before the `### Anti-Hallucination` heading at the end of the Steps section. No backup written (additive-only step).

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import os, sys

path = ".claude/skills/code-write/SKILL.md"

if not os.path.exists(path):
    print(f"SKIP: {path} not present — skill not installed in this project")
    sys.exit(0)

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Tier (a) — idempotency
if "Post-Code-Write" in content:
    print(f"SKIP: {path} already contains Post-Code-Write sentinel")
    sys.exit(0)

# Anchor: `### Anti-Hallucination` (inserted immediately before this heading).
anchor = "### Anti-Hallucination"
if anchor not in content:
    print(f"WARNING: {path} missing '### Anti-Hallucination' anchor — Step 3 skipped (skill body appears hand-edited).")
    print("Migration continues — Step 4 will still run. Hand-patch this file manually:")
    print("add the following block to the skill body immediately before the Anti-Hallucination section:")
    print("---")
    print("### Post-Code-Write (advisory — Post-Module-07 only)")
    print("- Non-trivial | cross-module changes → consider `/review` via Skill tool pre-commit")
    print("- Judgment-based, NOT mandatory — trivial edits skip review")
    print("- Contrast w/ /tdd: /tdd enforces /review on STATUS: GREEN; /code-write is soft recommendation only")
    print("---")
    print("Convention: anchor-missing → non-fatal skip (per migrations 031/039/042/049). Rerun migration after manual merge to confirm sentinel.")
    sys.exit(0)

anchor_idx = content.index(anchor)
block = (
    "### Post-Code-Write (advisory — Post-Module-07 only)\n"
    "- Non-trivial | cross-module changes → consider `/review` via Skill tool pre-commit\n"
    "- Judgment-based, NOT mandatory — trivial edits skip review\n"
    "- Contrast w/ /tdd: /tdd enforces /review on STATUS: GREEN; /code-write is soft recommendation only\n\n"
)

new_content = content[:anchor_idx] + block + content[anchor_idx:]

with open(path, "w", encoding="utf-8") as f:
    f.write(new_content)

print(f"PATCHED: {path} (Post-Code-Write advisory block inserted before Anti-Hallucination)")
PY
```

### Step 4 — Update `.claude/bootstrap-state.json`

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '047'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '047') or a == '047' for a in applied):
    applied.append({
        'id': '047',
        'applied_at': state['last_applied'],
        'description': 'Add Phase 1 triage (proj-quick-check, binary TEST_FILE_EXISTS+FEATURE_IN_TESTS stop) and Phase 3 review (/review via Skill tool on STATUS: GREEN) to /tdd skill. Mandate STATUS: GREEN|RED first line in proj-tdd-runner return summary. Add advisory post-code-write review recommendation to /code-write.'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=047')
PY
```

### Rules for migration scripts

- **Read-before-write** — Step 1 uses three-tier baseline-sentinel detection with `.bak-047` backup on destructive replace. Steps 2 and 3 are additive — sentinel guards prevent duplicate insertion on re-run, and failure-to-locate-anchor emits the verbatim block to stdout so the operator can hand-patch.
- **Idempotent** — every step re-run detects its sentinel (`Phase 1 — Triage` / `STATUS: GREEN` / `Post-Code-Write`) and emits `SKIP: already patched` without writing.
- **Self-contained** — all logic inlined via python3 heredocs; no external fetch.
- **Abort on error** — `set -euo pipefail` on every bash block; python3 blocks exit 0 on missing anchors (Steps 2, 3 emit WARNING + verbatim hand-patch block to stdout and continue, per migration 031/039/042/049 convention, so subsequent steps still land on hand-edited projects).
- **Scope lock** — touches only: `.claude/skills/tdd/SKILL.md`, `.claude/agents/proj-tdd-runner.md`, `.claude/skills/code-write/SKILL.md`, `.claude/bootstrap-state.json`. No hook changes, no settings edits, no rule file edits. `migrations/index.json` is appended BY MAIN THREAD outside this migration body (per `agent-scope-lock.md`).
- **P0 dependency note** — this migration is designed to run AFTER migration 045 (the `/review` find-paren fix). Client projects running `/migrate-bootstrap` serially will have 045 applied before 047 reaches the queue. Migration 047 does NOT touch `.claude/skills/review/SKILL.md` directly; it only invokes `/review` via the Skill tool from Phase 3 of `/tdd`. The `/review` body's current state (post-045 paren-fixed form) is the expected target at invocation time.

---

## Verify

```bash
#!/usr/bin/env bash
set +e
fail=0

# 1. tdd/SKILL.md carries Phase 1 / Phase 2 / Phase 3 markers
for phase in "Phase 1 — Triage" "Phase 2 — TDD cycle" "Phase 3 — Review"; do
  if grep -qF "$phase" .claude/skills/tdd/SKILL.md 2>/dev/null; then
    echo "PASS: tdd/SKILL.md carries '$phase' marker"
  else
    echo "FAIL: tdd/SKILL.md missing '$phase' marker"
    fail=1
  fi
done

# 2. tdd/SKILL.md Dispatch Map contains proj-quick-check AND /review
if grep -qF 'proj-quick-check' .claude/skills/tdd/SKILL.md 2>/dev/null; then
  echo "PASS: tdd/SKILL.md Dispatch Map contains proj-quick-check"
else
  echo "FAIL: tdd/SKILL.md Dispatch Map missing proj-quick-check"
  fail=1
fi
if grep -qF '/review' .claude/skills/tdd/SKILL.md 2>/dev/null; then
  echo "PASS: tdd/SKILL.md references /review"
else
  echo "FAIL: tdd/SKILL.md does not reference /review"
  fail=1
fi

# 3. tdd/SKILL.md binary stop condition present + explicitly excludes COVERAGE_SIGNAL from stop logic
if grep -qF 'TEST_FILE_EXISTS=yes AND FEATURE_IN_TESTS=yes' .claude/skills/tdd/SKILL.md 2>/dev/null; then
  echo "PASS: tdd/SKILL.md carries binary stop condition 'TEST_FILE_EXISTS=yes AND FEATURE_IN_TESTS=yes'"
else
  echo "FAIL: tdd/SKILL.md missing binary stop condition"
  fail=1
fi
if grep -qF 'NOT used in stop condition' .claude/skills/tdd/SKILL.md 2>/dev/null; then
  echo "PASS: tdd/SKILL.md clarifies COVERAGE_SIGNAL is NOT part of stop condition"
else
  echo "FAIL: tdd/SKILL.md missing COVERAGE_SIGNAL stop-condition exclusion clause"
  fail=1
fi

# 4. proj-tdd-runner.md carries STATUS: GREEN|RED mandate
if grep -qF 'STATUS: GREEN' .claude/agents/proj-tdd-runner.md 2>/dev/null; then
  echo "PASS: proj-tdd-runner.md carries STATUS: GREEN mandate"
else
  echo "FAIL: proj-tdd-runner.md missing STATUS: GREEN mandate"
  fail=1
fi
if grep -qF 'STATUS: RED' .claude/agents/proj-tdd-runner.md 2>/dev/null; then
  echo "PASS: proj-tdd-runner.md carries STATUS: RED branch"
else
  echo "FAIL: proj-tdd-runner.md missing STATUS: RED branch"
  fail=1
fi

# 5. code-write/SKILL.md carries Post-Code-Write advisory
if grep -qF 'Post-Code-Write' .claude/skills/code-write/SKILL.md 2>/dev/null; then
  echo "PASS: code-write/SKILL.md carries Post-Code-Write advisory"
else
  echo "FAIL: code-write/SKILL.md missing Post-Code-Write advisory"
  fail=1
fi

# 6. YAML frontmatter still parses on all three edited files
for f in .claude/skills/tdd/SKILL.md .claude/agents/proj-tdd-runner.md .claude/skills/code-write/SKILL.md; do
  if python3 -c "
import sys, yaml
with open('$f') as fh:
    parts = fh.read().split('---')
if len(parts) < 3:
    sys.exit(1)
yaml.safe_load(parts[1])
" 2>/dev/null; then
    echo "PASS: $f YAML frontmatter parses"
  else
    echo "FAIL: $f YAML frontmatter invalid after patch"
    fail=1
  fi
done

# 7. bootstrap-state.json updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "047" ]]; then
  echo "PASS: last_migration = 047"
else
  echo "FAIL: last_migration = $last (expected 047)"
  fail=1
fi

echo "---"
if [[ $fail -eq 0 ]]; then
  echo "Migration 047 verification: ALL PASS"
  echo ""
  echo "Optional cleanup: remove .bak-047 backups once you've confirmed the Steps section replace is correct:"
  echo "  find .claude/skills -name '*.bak-047' -delete"
else
  echo "Migration 047 verification: FAILURES — state NOT updated"
  exit 1
fi
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix.

---

## State Update

On success:
- `last_migration` → `"047"`
- append `{ "id": "047", "applied_at": "<ISO8601>", "description": "Add Phase 1 triage (proj-quick-check, binary TEST_FILE_EXISTS+FEATURE_IN_TESTS stop) and Phase 3 review (/review via Skill tool on STATUS: GREEN) to /tdd skill. Mandate STATUS: GREEN|RED first line in proj-tdd-runner return summary. Add advisory post-code-write review recommendation to /code-write." }` to `applied[]`

---

## Idempotency

Re-running after success:
- Step 1 — `Phase 1 — Triage` present → SKIP
- Step 2 — `STATUS: GREEN` present → SKIP
- Step 3 — `Post-Code-Write` present → SKIP
- Step 4 — `applied[]` dedup check (migration id == `'047'`) → no duplicate append

No backups are rewritten on re-run. Files that were `SKIP_HAND_EDITED` on first apply (Step 1 only) remain `SKIP_HAND_EDITED` on re-run (both sentinels absent) — manual merge is required per `## Manual-Apply-Guide § Step-1`.

---

## Rollback

```bash
#!/usr/bin/env bash
set -euo pipefail

# Option A — restore from .bak-047 backup (written by Step 1 destructive replace)
if [[ -f .claude/skills/tdd/SKILL.md.bak-047 ]]; then
  mv .claude/skills/tdd/SKILL.md.bak-047 .claude/skills/tdd/SKILL.md
  echo "Restored: .claude/skills/tdd/SKILL.md from .bak-047"
fi

# Steps 2 and 3 are additive with no backup — revert via git if tracked, or hand-strip the inserted blocks
git restore .claude/agents/proj-tdd-runner.md 2>/dev/null || echo "WARN: .claude/agents/proj-tdd-runner.md not git-tracked — hand-strip STATUS: GREEN block if needed"
git restore .claude/skills/code-write/SKILL.md 2>/dev/null || echo "WARN: .claude/skills/code-write/SKILL.md not git-tracked — hand-strip Post-Code-Write block if needed"

# Reset bootstrap-state.json
python3 <<'PY'
import json
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
if state.get('last_migration') == '047':
    state['last_migration'] = '046'
state['applied'] = [a for a in state.get('applied', []) if not (
    (isinstance(a, dict) and a.get('id') == '047') or a == '047'
)]
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State rolled back to last_migration=046')
PY
```

---

## Post-Apply — Bootstrap Repo Self-Update

This migration targets client projects. The bootstrap repo's own `.claude/` copies are
generated output, not source of truth. The bootstrap templates (`templates/skills/tdd/SKILL.md`,
`templates/agents/proj-tdd-runner.md`, `templates/skills/code-write/SKILL.md`) already carry
the correct post-047 state after Batch 03 of the workflow-improvements plan. No template edit
is needed; this migration exists only to propagate the fixes to already-bootstrapped client
projects whose `.claude/skills/` and `.claude/agents/` have not yet been refreshed.

Reference: `.claude/rules/general.md` §Process — "NEVER write to this repo's `.claude/` as implementation work."

---

## Manual-Apply-Guide

When Step 1 reports `SKIP_HAND_EDITED: .claude/skills/tdd/SKILL.md — neither idempotency sentinel nor baseline sentinel present`, the migration detected that the Steps section of the `/tdd` skill was customized post-bootstrap (baseline sentinel `Dispatch agent via \`subagent_type="proj-tdd-runner"\`` absent + post-migration sentinel `Phase 1 — Triage` absent). Automatic patching is unsafe — the migration does not know whether the customization is deliberate. This guide provides the verbatim new-content blocks plus merge instructions so you can manually integrate the three-phase structure while preserving your customizations.

Steps 2 and 3 are additive — if either step emits a `FAIL: <file> missing <anchor>` message because the anchor section (`## Pass-by-Reference Contract` or `### Anti-Hallucination`) has been renamed / removed, the migration script prints the verbatim block to stdout for direct hand-patching. No separate Manual-Apply-Guide section is needed for those steps; paste the printed block into the target file and rerun the migration to advance state.

---

### §Step-1 — Replace `### Steps` section in `.claude/skills/tdd/SKILL.md` with Phase 1/2/3 structure

**Target**: `.claude/skills/tdd/SKILL.md` — the `### Steps` heading and everything beneath it up to the next top-level section (typically `### Anti-Hallucination` or end of file).

**New content (verbatim — replace the current single-dispatch Steps body in full, or integrate the three-phase structure into your customized skill body)**:

The entire file body should match this structure after manual merge. The frontmatter block remains at the top (adjust the `# Skill Class:` comment if you have customized it), followed by this body:

```markdown
## /tdd — Red-Green-Refactor

## Pre-flight (REQUIRED — before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

Agent existence check list:
- `proj-quick-check` — required for Phase 1 triage
- `proj-tdd-runner` — required for Phase 2 TDD cycle

## Dispatch Map
- Triage: `proj-quick-check`
- Red-Green-Refactor cycle: `proj-tdd-runner`
- Post-TDD review: `/review` (via Skill tool, STATUS: GREEN only)

**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: dispatch `proj-quick-check` (simple) | `proj-researcher` (deep). Read directly ONLY for known exact path (Tier 1 per main-thread-orchestrator.md). MCP-indexed projects: named-symbol lookups MUST go through cmm.search_graph (see mcp-routing.md). Never built-in `Explore` / `general-purpose` / plugin.
See `techniques/agent-design.md § Agent Dispatch Policy`.

### Steps

#### Phase 1 — Triage (proj-quick-check)

Dispatch `subagent_type="proj-quick-check"` w/ a 4-field structured brief to determine whether the feature is already test-covered before entering the TDD cycle.

Brief fields (triage agent must return these exact keys):
- `TEST_FILE_EXISTS`: `yes|no` — does any test file plausibly cover the feature's module/component?
- `FEATURE_IN_TESTS`: `yes|no` — does any existing test reference the specific feature / behavior / symbol?
- `COVERAGE_SIGNAL`: `full|partial|none` — context enrichment only (NOT used in stop condition)
- `TEST_FILE_PATH`: `<path>|null` — path to most-relevant existing test file, or null

Binary stop condition (TRIVIALLY_COVERED):
- `TEST_FILE_EXISTS=yes AND FEATURE_IN_TESTS=yes` → emit advisory: "Feature already tested at {TEST_FILE_PATH}. TRIVIALLY_COVERED. Proceed with Phase 2 only if adding new behavior beyond what existing tests assert." → exit skill.
- Any other combination → proceed to Phase 2.

Note: `COVERAGE_SIGNAL` is context enrichment for the user (shown in advisory output when relevant), NOT part of the stop condition. Do not gate Phase 2 on coverage strength.

#### Phase 2 — TDD cycle (proj-tdd-runner)

Dispatch `subagent_type="proj-tdd-runner"` w/:
- Feature/behavior specification from user
- Test conventions path: `.claude/rules/code-standards-{lang}.md`
- Build command: {build_command}
- Test single command: {test_single_command}
- Test suite command: {test_suite_command}
- Write results to `.claude/reports/tdd-{timestamp}.md`
- Return path + summary

**Return contract**: proj-tdd-runner MUST emit `STATUS: GREEN` (all tests pass, refactor clean) OR `STATUS: RED` (tests failing or skipped) as the FIRST LINE of its return summary. Phase 3 routes on this exact token — no prose parsing, no inference.

#### Phase 3 — Review (/review via Skill tool, GREEN only)

Parse first line of Phase 2 return summary:
- `STATUS: GREEN` → invoke `/review` via Skill tool to run code-reviewer over the TDD changes before handoff to user.
- `STATUS: RED` → skip /review. Report RED status + TDD report path to user. Do NOT invoke /review on failing code — reviewer findings are meaningless against broken tests.

### TDD Cycle (within Phase 2 agent)
- **RED** — write test describing expected behavior → run → must FAIL
- **GREEN** — write minimum code to pass → run → must PASS
- **REFACTOR** — clean up w/ tests green → run after each step
- Repeat per behavior/scenario

### Anti-Hallucination
- Read existing tests first → match conventions
- Test passes immediately → not testing new behavior, rethink
- Verify types/methods referenced in tests actually exist (LSP or Grep)
- Phase 1 triage must use structured 4-field return; never synthesize field values without file:line evidence
- Phase 3 routing is strict string match on `STATUS: GREEN` — do NOT invoke /review on ambiguous / missing status line
```

**Merge instructions**:

1. **Locate your customized skill body.** Open `.claude/skills/tdd/SKILL.md`. Identify which elements in the body above you have customized (e.g., a project-specific test discovery heuristic, a custom refactor gate, a different report path).

2. **Decide whether to integrate each customization into the three-phase structure.**
   - **Customization belongs in Phase 1 (triage)**: extend the 4-field brief with additional return keys (document them clearly); or tighten the binary stop condition with additional `AND` conjuncts. Keep the stop condition binary — do not fold `COVERAGE_SIGNAL` into it per the G3.3 resolution.
   - **Customization belongs in Phase 2 (TDD cycle)**: add additional fields to the dispatch brief (e.g., a custom test-harness command); the runner agent handles brief extensibility.
   - **Customization belongs in Phase 3 (review)**: keep the strict string-match gate on `STATUS: GREEN`. If you want review on a different condition (e.g., always review), adjust the Phase 3 body but keep the first-line-STATUS parsing intact so the contract with `proj-tdd-runner` holds.

3. **Paste the verbatim three-phase structure above**, then re-integrate your customizations into the appropriate phase.

4. **Save the file.**

5. **Rerun the migration.** After your manual merge, the file now contains the idempotency sentinel `Phase 1 — Triage`. Rerunning `/migrate-bootstrap` will detect the sentinel in Step 1 and print `SKIP: already patched`, then proceed to Step 2 (additive proj-tdd-runner patch), Step 3 (additive code-write patch), and Step 4 (state advance). This completes the migration cleanly.

6. **Restore the backup only if needed.** If you want to abandon the manual merge and inspect the original, the migration wrote `.claude/skills/tdd/SKILL.md.bak-047` on first SKIP_HAND_EDITED encounter (and on any destructive PATCH). `cp .claude/skills/tdd/SKILL.md.bak-047 .claude/skills/tdd/SKILL.md` restores pre-migration state; you can then restart the merge or abort.

### Why this matters

The three-phase restructure converts `/tdd` from a single-dispatch loop into a triage-gated pipeline with automatic post-review handoff. Phase 1 triage (haiku cost) avoids wasted opus-runner dispatches on already-covered features. Phase 3 review (invoked only on `STATUS: GREEN`) routes freshly-generated TDD code through the code-reviewer pipeline without requiring the user to remember a manual `/review` invocation. The `STATUS: GREEN|RED` first-line mandate on `proj-tdd-runner` is the contract that makes Phase 3 routing a strict string match rather than a prose-parsing heuristic.

The binary stop condition `TEST_FILE_EXISTS=yes AND FEATURE_IN_TESTS=yes` deliberately excludes `COVERAGE_SIGNAL` — per the G3.3 resolution (the triage-routing authority for this migration), coverage strength is context enrichment for user-facing advisory text, not a gate. Folding it into the stop condition would raise false negatives (Phase 1 would skip Phase 2 on partial coverage even when the user is adding new behavior) while adding little true-positive signal over the existing two-field gate.
