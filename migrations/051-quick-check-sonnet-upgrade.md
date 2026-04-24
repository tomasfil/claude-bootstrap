# Migration 051 — Quick-check Sonnet Upgrade

<!-- migration-id: 051-quick-check-sonnet-upgrade -->

> Upgrade `proj-quick-check` from haiku+xhigh (`INHERITED_DEFAULT`) to sonnet+medium (`SUBTLE_ERROR_RISK`) — patches agent frontmatter (model + effort + justification comment block), rules row in `.claude/rules/model-selection.md` Agent Classification Table, and the two `proj-quick-check` references in `.claude/references/techniques/agent-design.md` (model table row + self-refusal gate rule). Destructive edits use three-tier baseline-sentinel detection — customized client files get `SKIP_HAND_EDITED` + `.bak-051` backup + pointer to `## Manual-Apply-Guide`.

---

## Metadata

```yaml
id: "051"
breaking: false
affects: [agents, rules, techniques]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

A field-observed session on a downstream client project surfaced self-contradictory findings in a single `proj-quick-check` return on a synthesis-shaped task — the agent stated evidence both present and absent for the same finding within the same structured response. Migration 043's task-shape self-refusal gate did not fire because the model did not recognize its own contradiction: the task was partially in-shape by the documented triggers (single-question framing, no explicit composition / cross-subsystem / framework-idiom marker, N ≤ 15) but the answer itself required bounded multi-source synthesis that the haiku reasoning tier could not reliably complete.

`proj-quick-check` is load-bearing: `.claude/rules/main-thread-orchestrator.md` makes it the mandatory first dispatch for every Tier 2 investigation, so unreliable returns cascade into orchestrator second-guessing + manual re-dispatch + main-thread context bloat. Published evidence (referenced in migration 043's brief) already documents haiku-tier overconfidence / calibration limits; the field observation confirmed the self-refusal gate alone cannot catch every failure case because the model's uncertainty estimation itself is miscalibrated on bounded single-pass reasoning that touches composition or idiom edges.

## Rationale

1. **Move the agent off the haiku reasoning tier** to sonnet for the reasoning-floor uplift, matching the SWE-bench / calibration gap between the two tiers on single-question synthesis tasks.
2. **Keep the bounded single-question role** — no findings file, no `WebSearch`, no multi-source synthesis (all of that still routes to `proj-researcher` per the Tier 2 classifier from migration 043). Effort drops from `xhigh` → `medium`, matching peer `SUBTLE_ERROR_RISK` agents (`proj-verifier`, `proj-consistency-checker`) which also run sonnet+medium for bounded checklist-style tool use.
3. **Retain the self-refusal gate as defensive check** — bounded single-pass reasoning still hits composition / cross-subsystem / idiom / large-N limits even on sonnet. The gate's triggers stay active; the justification comment block in the agent frontmatter documents both the tier change and the retained gate.
4. **Update the self-refusal gate rule text in the technique** so the language no longer hard-codes "haiku-tier" as the only agent class that must pre-check task shape. Generalized to "bounded single-pass lookup agent accepting Tier 2 dispatch" — haiku-tier OR sonnet-tier at medium effort scoped to single-question returns. Escalation target also broadened from "sonnet-tier agent" to "full-synthesis agent (e.g., `proj-researcher`)".
5. **Project-specific customizations MUST be preserved.** All three destructive edits (agent frontmatter, rules row, technique file overwrite) implement three-tier baseline-sentinel detection per `.claude/rules/general.md` Migration Preservation Discipline: post-migration sentinel → `SKIP_ALREADY_APPLIED`; baseline sentinel → safe `PATCHED`; neither → `SKIP_HAND_EDITED` + `.bak-051` backup + pointer to `## Manual-Apply-Guide`. Blind overwrite of customized content is structurally prevented.

---

## Changes

1. Replaces the frontmatter block of `.claude/agents/proj-quick-check.md`:
   - `model: haiku` → `model: sonnet`
   - `effort: xhigh` → `effort: medium`
   - 1-line justification comment `# xhigh: INHERITED_DEFAULT` → 6-line justification comment block starting `# medium: SUBTLE_ERROR_RISK — first-dispatch reliability floor for Tier 2 investigation returns.`
   - Agent body (everything below the closing `---`) is UNCHANGED by this migration.
2. Replaces the `proj-quick-check` row in `.claude/rules/model-selection.md` Agent Classification Table:
   - Before: `| proj-quick-check | haiku | xhigh | INHERITED_DEFAULT |`
   - After: `| proj-quick-check | sonnet | medium | SUBTLE_ERROR_RISK |`
3. Syncs `.claude/references/techniques/agent-design.md` from the bootstrap repo via `gh api`. The fetched content carries two pre-coordinated edits:
   - Model table row: `| | | proj-quick-check | haiku |` → `| | | proj-quick-check | sonnet |`
   - Self-refusal gate sentence (generalized from haiku-tier-only to any bounded single-pass lookup agent; escalation target broadened to full-synthesis agent).
4. Advances `.claude/bootstrap-state.json` → `last_migration: "051"` + appends to `applied[]`.

This migration pairs with concurrent bootstrap-repo edits to `templates/agents/proj-quick-check.md`, `templates/rules/model-selection.md`, and `techniques/agent-design.md` — those edits are the source-of-truth changes; this migration retrofits them into already-bootstrapped client projects. The three changes are coordinated (agent model/effort/comment + rules row + technique sentence + technique table row must match) — the verification block asserts all four sentinels.

Idempotent: re-running detects the three post-migration sentinels (`# medium: SUBTLE_ERROR_RISK — first-dispatch reliability floor` in the agent file, `| proj-quick-check | sonnet | medium | SUBTLE_ERROR_RISK |` in the rules file, `any bounded single-pass lookup agent` in the technique file) and prints `SKIP: already patched` per step.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { printf "ERROR: not a bootstrapped project — run full bootstrap first\n"; exit 1; }
[[ -d ".claude/agents" ]] || { printf "ERROR: no .claude/agents directory\n"; exit 1; }
[[ -d ".claude/rules" ]] || { printf "ERROR: no .claude/rules directory\n"; exit 1; }
[[ -f ".claude/agents/proj-quick-check.md" ]] || { printf "ERROR: .claude/agents/proj-quick-check.md missing\n"; exit 1; }
[[ -f ".claude/rules/model-selection.md" ]] || { printf "ERROR: .claude/rules/model-selection.md missing — migration 030 must be applied first\n"; exit 1; }
command -v python3 >/dev/null 2>&1 || { printf "ERROR: python3 required\n"; exit 1; }
command -v gh >/dev/null 2>&1 || { printf "ERROR: gh CLI required (for technique sync)\n"; exit 1; }

BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-tomasfilip/claude-bootstrap}"

# Resolve bootstrap_repo from bootstrap-state.json if env var unset + field present
if [[ -z "${BOOTSTRAP_REPO_OVERRIDE:-}" ]]; then
  state_repo=$(python3 -c "import json, sys
try:
    s = json.load(open('.claude/bootstrap-state.json'))
    print(s.get('bootstrap_repo', ''))
except Exception:
    pass" 2>/dev/null || true)
  if [[ -n "$state_repo" && "$state_repo" != "null" ]]; then
    BOOTSTRAP_REPO="$state_repo"
  fi
fi

printf "Using bootstrap repo: %s\n" "$BOOTSTRAP_REPO"
export BOOTSTRAP_REPO
```

### Idempotency check

```bash
#!/usr/bin/env bash
set -euo pipefail

qc_patched=0
rules_patched=0
tech_patched=0

if grep -q "# medium: SUBTLE_ERROR_RISK — first-dispatch reliability floor" .claude/agents/proj-quick-check.md 2>/dev/null; then
  qc_patched=1
fi

if grep -qE "^\| proj-quick-check \| sonnet \| medium \| SUBTLE_ERROR_RISK \|" .claude/rules/model-selection.md 2>/dev/null; then
  rules_patched=1
fi

if [[ -f ".claude/references/techniques/agent-design.md" ]] && \
   grep -q "any bounded single-pass lookup agent" .claude/references/techniques/agent-design.md 2>/dev/null; then
  tech_patched=1
fi

if [[ "$qc_patched" -eq 1 && "$rules_patched" -eq 1 && "$tech_patched" -eq 1 ]]; then
  printf "SKIP: migration 051 already applied (all three targets carry post-migration sentinels)\n"
  exit 0
fi

printf "Applying migration 051: qc_patched=%s rules_patched=%s tech_patched=%s\n" "$qc_patched" "$rules_patched" "$tech_patched"
```

### Step 1 — Replace frontmatter block in `.claude/agents/proj-quick-check.md`

Read-before-write with three-tier baseline-sentinel detection (per `.claude/rules/general.md` Migration Preservation Discipline):

- **Tier 1 idempotency sentinel**: `# medium: SUBTLE_ERROR_RISK — first-dispatch reliability floor` present → `SKIP_ALREADY_APPLIED`
- **Tier 2 baseline sentinel**: `# xhigh: INHERITED_DEFAULT` present (stock post-migration-044 state, safe to replace) → `PATCHED`
- **Tier 3 neither present**: frontmatter has been customized post-bootstrap → `SKIP_HAND_EDITED` + write `.bak-051` backup if absent + pointer to `## Manual-Apply-Guide §Step-1`. Client customizations preserved.

The patch replaces the entire YAML frontmatter block between the two `---` fences at the top of the file. Agent body (everything below the closing `---`) is UNCHANGED.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import sys
from pathlib import Path

path = Path(".claude/agents/proj-quick-check.md")
backup = Path(str(path) + ".bak-051")

POST_051_SENTINEL = "# medium: SUBTLE_ERROR_RISK — first-dispatch reliability floor"
BASELINE_SENTINEL = "# xhigh: INHERITED_DEFAULT"

content = path.read_text(encoding="utf-8")

if POST_051_SENTINEL in content:
    print(f"SKIP_ALREADY_APPLIED: {path} frontmatter already patched (051-1)")
    sys.exit(0)

if BASELINE_SENTINEL not in content:
    if not backup.exists():
        backup.write_text(content, encoding="utf-8")
    print(f"SKIP_HAND_EDITED: {path} frontmatter has been customized post-bootstrap — baseline sentinel '{BASELINE_SENTINEL}' absent. Manual application required. See migrations/051-quick-check-sonnet-upgrade.md §Manual-Apply-Guide §Step-1. Backup at {backup}.")
    sys.exit(0)

# Safe to replace — baseline present, not yet patched.
# Split on the frontmatter fences. Expect structure: "---\n<frontmatter>\n---\n<body>".
parts = content.split("---", 2)
if len(parts) < 3:
    print(f"ERROR: {path} does not have a parseable YAML frontmatter block (expected two `---` fences at top)")
    sys.exit(1)

prefix, _old_frontmatter, body = parts[0], parts[1], parts[2]

# Verify the structure we expect: prefix should be empty (file starts with ---) or whitespace.
if prefix.strip():
    print(f"ERROR: {path} has unexpected content before first `---` fence; cannot safely replace frontmatter")
    sys.exit(1)

new_frontmatter = """
name: proj-quick-check
description: >
  Use when doing quick file searches, checking if something exists, reading a
  specific section, or answering factual questions about the codebase. Optimized
  for speed over depth. Returns answer as text — no file output. For deep
  multi-source synthesis use proj-researcher instead.
model: sonnet
effort: medium
# medium: SUBTLE_ERROR_RISK — first-dispatch reliability floor for Tier 2 investigation returns.
#   Bounded single-question scope, not multi-source synthesis → medium effort sufficient.
#   Peers: proj-verifier, proj-consistency-checker (both sonnet+medium SUBTLE_ERROR_RISK).
#   Predecessor model was haiku+xhigh; field use surfaced self-contradictory findings on
#   synthesis-shaped tasks (see migration 051). Self-refusal gate below retained as defensive
#   check — bounded single-pass reasoning still hits composition / cross-subsystem / idiom limits.
maxTurns: 25
color: gray
"""

if not backup.exists():
    backup.write_text(content, encoding="utf-8")

new_content = "---" + new_frontmatter + "---" + body

path.write_text(new_content, encoding="utf-8")
print(f"PATCHED: {path} frontmatter (051-1)")
PY
```

### Step 2 — Replace `proj-quick-check` row in `.claude/rules/model-selection.md`

Read-before-write with three-tier baseline-sentinel detection:

- **Tier 1 idempotency sentinel**: `| proj-quick-check | sonnet | medium | SUBTLE_ERROR_RISK |` present → `SKIP_ALREADY_APPLIED`
- **Tier 2 baseline sentinel**: `| proj-quick-check | haiku | xhigh | INHERITED_DEFAULT |` present (stock post-migration-044 state, safe to replace) → `PATCHED`
- **Tier 3 neither present**: row has been customized post-bootstrap → `SKIP_HAND_EDITED` + write `.bak-051` backup if absent + pointer to `## Manual-Apply-Guide §Step-2`. Client customizations preserved.

Line-level exact-string replacement. Does NOT touch any other row in the Agent Classification Table — only the `proj-quick-check` row is in scope.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import sys
from pathlib import Path

path = Path(".claude/rules/model-selection.md")
backup = Path(str(path) + ".bak-051")

POST_051_ROW = "| proj-quick-check | sonnet | medium | SUBTLE_ERROR_RISK |"
BASELINE_ROW = "| proj-quick-check | haiku | xhigh | INHERITED_DEFAULT |"

content = path.read_text(encoding="utf-8")

if POST_051_ROW in content:
    print(f"SKIP_ALREADY_APPLIED: {path} proj-quick-check row already patched (051-2)")
    sys.exit(0)

if BASELINE_ROW not in content:
    if not backup.exists():
        backup.write_text(content, encoding="utf-8")
    print(f"SKIP_HAND_EDITED: {path} proj-quick-check row has been customized post-bootstrap — baseline row '{BASELINE_ROW}' absent. Manual application required. See migrations/051-quick-check-sonnet-upgrade.md §Manual-Apply-Guide §Step-2. Backup at {backup}.")
    sys.exit(0)

# Safe to replace — baseline row present, not yet patched.
if not backup.exists():
    backup.write_text(content, encoding="utf-8")

new_content = content.replace(BASELINE_ROW, POST_051_ROW, 1)

if new_content == content:
    # Defensive: baseline grep matched but replace was no-op (shouldn't happen; guard anyway)
    print(f"ERROR: {path} baseline row detected but replace was no-op — aborting to avoid silent drift")
    sys.exit(1)

path.write_text(new_content, encoding="utf-8")
print(f"PATCHED: {path} proj-quick-check row (051-2)")
PY
```

### Step 3 — Sync updated `techniques/agent-design.md` → `.claude/references/techniques/agent-design.md`

Fetch updated technique content from bootstrap repo via `gh api` (follows `.claude/rules/general.md` Migrations rule: target `.claude/references/techniques/` for client project layout, NEVER `techniques/` at root).

Three-tier detection on the EXISTING client file:

- **Tier 1 idempotency sentinel**: `any bounded single-pass lookup agent` present in existing client file → `SKIP_ALREADY_APPLIED` (no fetch needed)
- **Tier 2 baseline sentinels (BOTH required)**: `| | | proj-quick-check | haiku |` AND `` any haiku-tier agent accepting Tier 2 dispatch (e.g., `proj-quick-check`) `` both present → safe to fetch + overwrite; write `.bak-051` backup of current content first
- **Tier 3 either baseline sentinel absent + idempotency sentinel absent**: technique file has been customized post-bootstrap → `SKIP_HAND_EDITED` + write `.bak-051` backup if absent + pointer to `## Manual-Apply-Guide §Step-3`. Client customizations preserved.

Authentication fallback: if `gh api` fails (not authenticated, rate-limited, or network error) during a safe-fetch case, the step emits a warning and continues without hard-failing the migration — the operator can manually fetch later per the Manual-Apply-Guide.

```bash
#!/usr/bin/env bash
set -euo pipefail

TECH_PATH=".claude/references/techniques/agent-design.md"
BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-tomasfilip/claude-bootstrap}"

mkdir -p "$(dirname "$TECH_PATH")"

python3 <<PY
import base64, json, os, subprocess, sys
from pathlib import Path

tech_path = Path("${TECH_PATH}")
backup = Path(str(tech_path) + ".bak-051")
repo = "${BOOTSTRAP_REPO}"

POST_051_SENTINEL = "any bounded single-pass lookup agent"
BASELINE_TABLE_ROW = "| | | proj-quick-check | haiku |"
BASELINE_GATE_SENTENCE = "any haiku-tier agent accepting Tier 2 dispatch (e.g., \`proj-quick-check\`)"

existing = tech_path.read_text(encoding="utf-8") if tech_path.exists() else ""

# Tier 1 — idempotency
if POST_051_SENTINEL in existing:
    print(f"SKIP_ALREADY_APPLIED: {tech_path} already contains post-051 sentinel (051-3)")
    sys.exit(0)

# Tier 3 — hand-edited detection: BOTH baseline sentinels must be present for safe overwrite
if existing and (BASELINE_TABLE_ROW not in existing or BASELINE_GATE_SENTENCE not in existing):
    if not backup.exists() and existing:
        backup.write_text(existing, encoding="utf-8")
    missing = []
    if BASELINE_TABLE_ROW not in existing:
        missing.append("model table row baseline")
    if BASELINE_GATE_SENTENCE not in existing:
        missing.append("self-refusal gate sentence baseline")
    print(f"SKIP_HAND_EDITED: {tech_path} has been customized post-bootstrap — missing: {', '.join(missing)}. Manual application required. See migrations/051-quick-check-sonnet-upgrade.md §Manual-Apply-Guide §Step-3. Backup at {backup}.")
    sys.exit(0)

# Tier 2 (or empty target file) — safe to fetch + overwrite
result = subprocess.run(
    ["gh", "api", f"repos/{repo}/contents/techniques/agent-design.md"],
    capture_output=True, text=True,
)
if result.returncode != 0:
    print(f"WARN: gh api fetch failed — technique sync skipped. Fetch manually: gh api repos/{repo}/contents/techniques/agent-design.md --jq '.content' | base64 -d > {tech_path}")
    print(f"  stderr: {result.stderr.strip()}")
    # Fail-soft: do not hard-fail; operator will manually sync per Manual-Apply-Guide §Step-3.
    sys.exit(0)

try:
    payload = json.loads(result.stdout)
    fetched = base64.b64decode(payload["content"]).decode("utf-8")
except Exception as e:
    print(f"ERROR: failed to parse gh api response — {e}")
    sys.exit(1)

if POST_051_SENTINEL not in fetched:
    print(f"ERROR: fetched agent-design.md does not contain post-051 sentinel '{POST_051_SENTINEL}' — bootstrap repo has not yet shipped the migration 051 source edits. Re-run after the bootstrap repo merge lands.")
    sys.exit(1)

# Write backup of existing (if present + differs) before overwrite
if existing and existing != fetched and not backup.exists():
    backup.write_text(existing, encoding="utf-8")

tech_path.parent.mkdir(parents=True, exist_ok=True)
tech_path.write_text(fetched, encoding="utf-8")
print(f"PATCHED: {tech_path} (synced from {repo})")
PY
```

### Step 4 — Update `.claude/bootstrap-state.json`

Advance `last_migration` and append to `applied[]`.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '051'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '051') or a == '051' for a in applied):
    applied.append({
        'id': '051',
        'applied_at': state['last_applied'],
        'description': 'Upgrade proj-quick-check from haiku+xhigh INHERITED_DEFAULT to sonnet+medium SUBTLE_ERROR_RISK — field-observed self-contradictory findings on synthesis-shaped tasks motivated moving the load-bearing first-dispatch agent off the haiku reasoning tier while keeping its bounded single-question role. Patches agent frontmatter, rules row, and technique file.'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=051')
PY
```

### Rules for migration scripts

- **Read-before-write** — every step reads the target file, detects sentinels, and only writes on the safe-patch tier. Destructive edits always write `.bak-051` backup before overwrite.
- **Idempotent** — re-running prints `SKIP_ALREADY_APPLIED` per step and `SKIP: migration 051 already applied` at the top when all three sentinels are present.
- **Self-contained** — all new frontmatter + rules-row content inlined in python3 heredocs; sole external dependency is `gh api` for the technique sync (required per `.claude/rules/general.md` — techniques updated via bootstrap repo fetch, never inlined).
- **No gitignored-path fetch** — fetches from the bootstrap repo's TRACKED `techniques/` directory, NOT its gitignored `.claude/`.
- **Technique sync targets client layout** — writes to `.claude/references/techniques/agent-design.md`, NOT `techniques/` at the client project root (per `.claude/rules/general.md` Migrations rule + `modules/02-project-config.md` Step 5).
- **Abort on error** — `set -euo pipefail` in every bash block; Step 3 gh-fetch is intentionally fail-soft (WARN + continue) to avoid blocking the whole migration on a transient authentication issue.
- **Scope lock** — touches only: `.claude/agents/proj-quick-check.md`, `.claude/rules/model-selection.md`, `.claude/references/techniques/agent-design.md`, `.claude/bootstrap-state.json`. No hook changes, no settings edits, no agent renames. `migrations/index.json` is appended BY MAIN THREAD outside this migration body (per `.claude/rules/agent-scope-lock.md`).

---

## Verify

```bash
#!/usr/bin/env bash
set +e
fail=0

# 1. proj-quick-check.md carries model: sonnet
if grep -qE "^model: sonnet\s*$" .claude/agents/proj-quick-check.md 2>/dev/null; then
  printf "PASS: proj-quick-check.md frontmatter model: sonnet\n"
else
  printf "FAIL: proj-quick-check.md missing 'model: sonnet'\n"
  fail=1
fi

# 2. proj-quick-check.md carries effort: medium
if grep -qE "^effort: medium\s*$" .claude/agents/proj-quick-check.md 2>/dev/null; then
  printf "PASS: proj-quick-check.md frontmatter effort: medium\n"
else
  printf "FAIL: proj-quick-check.md missing 'effort: medium'\n"
  fail=1
fi

# 3. proj-quick-check.md carries the post-051 justification comment
if grep -q "# medium: SUBTLE_ERROR_RISK — first-dispatch reliability floor" .claude/agents/proj-quick-check.md 2>/dev/null; then
  printf "PASS: proj-quick-check.md contains post-051 justification comment\n"
else
  printf "FAIL: proj-quick-check.md missing post-051 justification comment ('# medium: SUBTLE_ERROR_RISK — first-dispatch reliability floor')\n"
  fail=1
fi

# 4. proj-quick-check.md no longer carries 'model: haiku' or 'effort: xhigh' or '# xhigh: INHERITED_DEFAULT'
if grep -qE "^model: haiku\s*$" .claude/agents/proj-quick-check.md 2>/dev/null; then
  printf "FAIL: proj-quick-check.md still carries 'model: haiku' (Step 1 patch did not land)\n"
  fail=1
else
  printf "PASS: proj-quick-check.md no longer carries 'model: haiku'\n"
fi

if grep -qE "^effort: xhigh\s*$" .claude/agents/proj-quick-check.md 2>/dev/null; then
  printf "FAIL: proj-quick-check.md still carries 'effort: xhigh' (Step 1 patch did not land)\n"
  fail=1
else
  printf "PASS: proj-quick-check.md no longer carries 'effort: xhigh'\n"
fi

if grep -q "# xhigh: INHERITED_DEFAULT" .claude/agents/proj-quick-check.md 2>/dev/null; then
  printf "FAIL: proj-quick-check.md still carries pre-051 justification comment '# xhigh: INHERITED_DEFAULT'\n"
  fail=1
else
  printf "PASS: proj-quick-check.md no longer carries pre-051 justification comment\n"
fi

# 5. model-selection.md carries post-051 proj-quick-check row
if grep -qE "^\| proj-quick-check \| sonnet \| medium \| SUBTLE_ERROR_RISK \|" .claude/rules/model-selection.md 2>/dev/null; then
  printf "PASS: model-selection.md contains post-051 proj-quick-check row (sonnet | medium | SUBTLE_ERROR_RISK)\n"
else
  printf "FAIL: model-selection.md missing post-051 proj-quick-check row\n"
  fail=1
fi

# 6. model-selection.md no longer carries baseline proj-quick-check row
if grep -qE "^\| proj-quick-check \| haiku \| xhigh \| INHERITED_DEFAULT \|" .claude/rules/model-selection.md 2>/dev/null; then
  printf "FAIL: model-selection.md still carries baseline proj-quick-check row (haiku | xhigh | INHERITED_DEFAULT)\n"
  fail=1
else
  printf "PASS: model-selection.md no longer carries baseline proj-quick-check row\n"
fi

# 7. agent-design.md technique synced — model table row shows sonnet
if [[ -f ".claude/references/techniques/agent-design.md" ]] && \
   grep -qE '\|\s*\|\s*\|\s*proj-quick-check\s*\|\s*sonnet\s*\|' .claude/references/techniques/agent-design.md 2>/dev/null; then
  printf "PASS: agent-design.md technique model table row shows proj-quick-check = sonnet\n"
else
  printf "FAIL: agent-design.md technique model table row does not show proj-quick-check = sonnet\n"
  fail=1
fi

# 8. agent-design.md technique synced — self-refusal gate rule generalized to "bounded single-pass lookup agent"
if [[ -f ".claude/references/techniques/agent-design.md" ]] && \
   grep -q "any bounded single-pass lookup agent" .claude/references/techniques/agent-design.md 2>/dev/null; then
  printf "PASS: agent-design.md technique self-refusal gate rule generalized\n"
else
  printf "FAIL: agent-design.md technique missing generalized self-refusal gate rule ('any bounded single-pass lookup agent')\n"
  fail=1
fi

# 9. YAML frontmatter parses for proj-quick-check.md
if python3 -c "
import sys, yaml
with open('.claude/agents/proj-quick-check.md') as f:
    parts = f.read().split('---')
if len(parts) < 3:
    sys.exit(1)
yaml.safe_load(parts[1])
" 2>/dev/null; then
  printf "PASS: proj-quick-check.md YAML frontmatter parses\n"
else
  printf "FAIL: proj-quick-check.md YAML frontmatter invalid after patch\n"
  fail=1
fi

# 10. bootstrap-state.json updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "051" ]]; then
  printf "PASS: last_migration = 051\n"
else
  printf "FAIL: last_migration = %s (expected 051)\n" "$last"
  fail=1
fi

printf -- "---\n"
if [[ $fail -eq 0 ]]; then
  printf "Migration 051 verification: ALL PASS\n"
  printf "\nOptional cleanup: remove .bak-051 backups once you've confirmed patches are correct:\n"
  printf "  find .claude/agents .claude/rules .claude/references -name '*.bak-051' -delete\n"
else
  printf "Migration 051 verification: FAILURES — state NOT updated\n"
  exit 1
fi
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix.

---

## State Update

On success:
- `last_migration` → `"051"`
- append `{ "id": "051", "applied_at": "<ISO8601>", "description": "Upgrade proj-quick-check from haiku+xhigh INHERITED_DEFAULT to sonnet+medium SUBTLE_ERROR_RISK — field-observed self-contradictory findings on synthesis-shaped tasks motivated moving the load-bearing first-dispatch agent off the haiku reasoning tier while keeping its bounded single-question role. Patches agent frontmatter, rules row, and technique file." }` to `applied[]`

---

## Idempotency

Re-running after success:
- Step 1 — `# medium: SUBTLE_ERROR_RISK — first-dispatch reliability floor` present in agent frontmatter → `SKIP_ALREADY_APPLIED`
- Step 2 — post-051 row present in rules file → `SKIP_ALREADY_APPLIED`
- Step 3 — post-051 sentinel present in technique file → `SKIP_ALREADY_APPLIED` (no gh api fetch attempted)
- Step 4 — `applied[]` dedup check (migration id == `'051'`) → no duplicate append

No backups are rewritten on re-run. Files that were `SKIP_HAND_EDITED` on first apply remain `SKIP_HAND_EDITED` on re-run (both sentinels absent) — manual merge per `## Manual-Apply-Guide` is still required.

---

## Rollback

Not cleanly rollback-able beyond `git restore` on the three patched files + removing the `051` entry from `applied[]` in `.claude/bootstrap-state.json`. The three changes are coordinated (agent model/effort/comment + rules row + technique sentence + technique table row must match) — partial rollback leaves inconsistent state across the agent frontmatter, the rules policy table, and the technique reference.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Option A — restore from .bak-051 backups (written by the migration itself before overwrite)
for bak in \
  .claude/agents/proj-quick-check.md.bak-051 \
  .claude/rules/model-selection.md.bak-051 \
  .claude/references/techniques/agent-design.md.bak-051; do
  [[ -f "$bak" ]] || continue
  orig="${bak%.bak-051}"
  mv "$bak" "$orig"
  printf "Restored: %s\n" "$orig"
done

# Option B — tracked strategy (if .claude/ is committed to project repo)
# git checkout -- \
#   .claude/agents/proj-quick-check.md \
#   .claude/rules/model-selection.md \
#   .claude/references/techniques/agent-design.md

# Reset bootstrap-state.json
python3 <<'PY'
import json
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
if state.get('last_migration') == '051':
    state['last_migration'] = '050'
state['applied'] = [a for a in state.get('applied', []) if not (
    (isinstance(a, dict) and a.get('id') == '051') or a == '051'
)]
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State rolled back to last_migration=050')
PY
```

Rollback via `.bak-051` is safe because the migration writes the backup before any destructive edit. If no backup exists, the file was either `SKIP_ALREADY_APPLIED` (nothing to roll back) or `SKIP_HAND_EDITED` (nothing was written, so nothing to roll back).

---

## Post-Apply — Bootstrap Repo Self-Update

This migration targets client projects. The bootstrap repo's own `.claude/` copies are
generated output, not source of truth. To update the bootstrap repo's installed copies:
1. Run `/migrate-bootstrap` against the bootstrap repo itself, OR re-run each step manually against the bootstrap repo's `.claude/` (the templates at `templates/agents/proj-quick-check.md`, `templates/rules/model-selection.md`, and `techniques/agent-design.md` are already in the target state after the paired bootstrap edits).
2. Do NOT directly edit `.claude/agents/proj-quick-check.md`, `.claude/rules/model-selection.md`, or `.claude/references/techniques/agent-design.md` in the bootstrap repo — direct edits bypass the templates and create drift.

Reference: `.claude/rules/general.md` §Process — "NEVER write to this repo's `.claude/` as implementation work."

---

## Manual-Apply-Guide

When a step reports `SKIP_HAND_EDITED: <path>`, the migration detected that the target was customized post-bootstrap (baseline sentinel absent + post-migration sentinel absent). Automatic patching is unsafe — content would be lost. This guide provides the verbatim new-content blocks plus merge instructions so you can manually integrate the tier change while preserving your customizations.

**General procedure per skipped step**:
1. Open the target file.
2. Locate the section/row/frontmatter block named in the step.
3. Read the new content block below for that step.
4. Manually merge: preserve your project-specific additions (extra frontmatter fields, extra comment lines with custom rationales, extra table rows); incorporate the tier change.
5. Save the file.
6. Run the verification snippet shown at the end of each subsection to confirm the patch landed correctly.
7. A `.bak-051` backup of the pre-migration file state exists at `<path>.bak-051` if the migration wrote one; use `diff <path>.bak-051 <path>` to see exactly what the migration would have overwritten.

If you customized the frontmatter comment for a different rationale, keep your customization and only change the `model:` and `effort:` field values — the migration's sentinel check is exact-string on the post-051 comment line, so manually kept customizations will continue to report `SKIP_HAND_EDITED` on future runs (which is correct — the migration respects your choice).

---

### §Step-1 — `proj-quick-check.md` frontmatter

**Target**: `.claude/agents/proj-quick-check.md` — YAML frontmatter block (between the two `---` fences at the top of the file). Agent body (everything below the closing `---`) is UNCHANGED by this migration.

**Context**: the migration detected that the `# xhigh: INHERITED_DEFAULT` baseline comment was absent from the frontmatter, meaning the file was customized post-bootstrap. The agent body is not in scope; only the frontmatter block is replaced.

**New content (verbatim — replace the existing frontmatter block between the `---` fences)**:

```yaml
---
name: proj-quick-check
description: >
  Use when doing quick file searches, checking if something exists, reading a
  specific section, or answering factual questions about the codebase. Optimized
  for speed over depth. Returns answer as text — no file output. For deep
  multi-source synthesis use proj-researcher instead.
model: sonnet
effort: medium
# medium: SUBTLE_ERROR_RISK — first-dispatch reliability floor for Tier 2 investigation returns.
#   Bounded single-question scope, not multi-source synthesis → medium effort sufficient.
#   Peers: proj-verifier, proj-consistency-checker (both sonnet+medium SUBTLE_ERROR_RISK).
#   Predecessor model was haiku+xhigh; field use surfaced self-contradictory findings on
#   synthesis-shaped tasks (see migration 051). Self-refusal gate below retained as defensive
#   check — bounded single-pass reasoning still hits composition / cross-subsystem / idiom limits.
maxTurns: 25
color: gray
---
```

**Merge instructions**:
1. Open `.claude/agents/proj-quick-check.md`.
2. Locate the YAML frontmatter block (between the two `---` fences at the top of the file).
3. If you have added custom frontmatter fields (e.g., `memory: project`, `skills:` list, additional comment blocks with your own rationale), preserve them. Only the `model:`, `effort:`, and `# xhigh: INHERITED_DEFAULT` / `# medium: SUBTLE_ERROR_RISK ...` comment block are in scope for this migration.
4. Change `model: haiku` → `model: sonnet`.
5. Change `effort: xhigh` → `effort: medium`.
6. Replace the `# xhigh: INHERITED_DEFAULT` comment (or whatever your current justification comment is) with the 6-line `# medium: SUBTLE_ERROR_RISK — ...` block from the verbatim content above. If you have a custom justification rationale you want to preserve, keep your comment lines alongside or in place of the migration's — the sentinel check for future runs is on the exact post-051 first-line prefix, so preserved-custom comments will continue to report `SKIP_HAND_EDITED` on future runs (expected + correct).
7. Save the file.

**Verification**:
```bash
python3 -c "import yaml; yaml.safe_load(open('.claude/agents/proj-quick-check.md').read().split('---')[1]); print('OK: YAML parses')"
grep -E '^model: sonnet$' .claude/agents/proj-quick-check.md
grep -E '^effort: medium$' .claude/agents/proj-quick-check.md
```

---

### §Step-2 — `model-selection.md` Agent Classification Table row

**Target**: `.claude/rules/model-selection.md` — the `proj-quick-check` row inside the `## Agent Classification Table` section.

**Context**: the migration detected that the baseline row `| proj-quick-check | haiku | xhigh | INHERITED_DEFAULT |` was absent from the rules file, meaning the row was customized post-bootstrap (different model, different effort, different class token, or the row was removed entirely).

**New content (verbatim — replace the `proj-quick-check` row)**:

```markdown
| proj-quick-check | sonnet | medium | SUBTLE_ERROR_RISK |
```

**Merge instructions**:
1. Open `.claude/rules/model-selection.md`.
2. Locate the `## Agent Classification Table` section.
3. Find the `| proj-quick-check | ... |` row.
4. Replace the entire row with the verbatim line above. Column order is: `Name pattern | Expected model | Expected effort | Class`.
5. If you have added additional columns to the table (project-specific extensions), preserve the leading 4 columns with the new values and append your extra column values.
6. Save the file.

**Verification**:
```bash
grep -E '^\| proj-quick-check \| sonnet \| medium \| SUBTLE_ERROR_RISK \|' .claude/rules/model-selection.md
```

---

### §Step-3 — `agent-design.md` technique file sync (model table row + self-refusal gate sentence)

**Target**: `.claude/references/techniques/agent-design.md` — two content edits inside the file.

**Context**: the migration detected that one or both of the baseline sentinels (`| | | proj-quick-check | haiku |` model table row AND `` any haiku-tier agent accepting Tier 2 dispatch (e.g., `proj-quick-check`) `` self-refusal gate sentence) was absent from the existing file, meaning the technique has been customized post-bootstrap. A blind overwrite via `gh api` fetch would lose your customizations.

**Edit 1 — Model table row** (verbatim — replace the existing row):

Locate the row in a markdown table that looks like `| ... | ... | proj-quick-check | haiku |` (exact cell order may vary depending on your table's column layout; the baseline in the bootstrap version is `| | | proj-quick-check | haiku |`).

Replace with:

```markdown
| | | proj-quick-check | sonnet |
```

**Edit 2 — Self-refusal gate sentence** (verbatim — replace the existing sentence):

Locate the existing sentence (approximate upstream location: line ~425):

> **Self-refusal gate requirement**: any haiku-tier agent accepting Tier 2 dispatch (e.g., `proj-quick-check`) MUST pre-check task shape against the MANDATORY rows above. If match → return structured `TASK_SHAPE_MISMATCH` JSON without attempting the task. Orchestrator re-dispatches to sonnet-tier agent.

Replace with:

> **Self-refusal gate requirement**: any bounded single-pass lookup agent accepting Tier 2 dispatch (haiku-tier, or sonnet-tier with medium effort scoped to single-question returns — e.g., `proj-quick-check`) MUST pre-check task shape against the MANDATORY rows above. If match → return structured `TASK_SHAPE_MISMATCH` JSON without attempting the task. Orchestrator re-dispatches to a full-synthesis agent (e.g., `proj-researcher`).

**Merge instructions**:
1. Open `.claude/references/techniques/agent-design.md`.
2. Apply Edit 1: locate the `proj-quick-check` row in the model table and change the model column from `haiku` to `sonnet`. Preserve any project-specific columns or per-row notes you have added.
3. Apply Edit 2: locate the "Self-refusal gate requirement" sentence and replace with the new broader form. Preserve any project-specific elaboration you have added after the sentence.
4. Save the file.

**Alternative — blind overwrite from bootstrap repo** (ONLY if you have NOT customized the file and just want the upstream version):

```bash
gh api repos/tomasfilip/claude-bootstrap/contents/techniques/agent-design.md \
  --jq '.content' | base64 -d > .claude/references/techniques/agent-design.md
```

This overwrites ALL local customizations to the technique file — use only if you are certain you have not added project-specific content. If `gh` is not authenticated: run `gh auth login` first, then retry. If the repo name is different (fork), substitute the correct `owner/repo` slug or set `BOOTSTRAP_REPO` in your environment.

**Verification**:
```bash
grep -E '\|\s*\|\s*\|\s*proj-quick-check\s*\|\s*sonnet\s*\|' .claude/references/techniques/agent-design.md
grep "any bounded single-pass lookup agent" .claude/references/techniques/agent-design.md
```

---

## Post-Migration (main-thread only per agent-scope-lock.md)

Append to `migrations/index.json`:
```json
{
  "id": "051",
  "file": "051-quick-check-sonnet-upgrade.md",
  "description": "Upgrade proj-quick-check from haiku+xhigh INHERITED_DEFAULT to sonnet+medium SUBTLE_ERROR_RISK — field-observed self-contradictory findings on synthesis-shaped tasks motivated moving the load-bearing first-dispatch agent off the haiku reasoning tier while keeping its bounded single-question role (no findings file, no WebSearch, no multi-source synthesis). Medium effort matches peer SUBTLE_ERROR_RISK agents (proj-verifier, proj-consistency-checker). Patches agent frontmatter (model + effort + justification comment), rules row in .claude/rules/model-selection.md Agent Classification Table, and the two proj-quick-check references in .claude/references/techniques/agent-design.md (model table row + self-refusal gate rule). Three-tier detection with SKIP_ALREADY_APPLIED / safe-patch / SKIP_HAND_EDITED branches per step; Manual-Apply-Guide for each destructive step.",
  "breaking": false
}
```
