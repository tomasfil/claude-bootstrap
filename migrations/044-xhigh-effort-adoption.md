# Migration 044 — xhigh Effort Adoption

<!-- migration-id: 044-xhigh-effort-adoption -->

> Adopt the `effort: xhigh` tier across all agents + skills that previously specified `effort: high`. Opus 4.7 introduces `xhigh` as the maximum reasoning-effort level; models that do not support `xhigh` silently fall back to their native maximum (validated against Sonnet/Haiku + older Opus). Blanket replace of `effort: high` → `effort: xhigh` is therefore safe across the board. Scope covers agent frontmatter, skill frontmatter, and the adjacent justification comment (`# high:` → `# xhigh:`). Procedural agents carrying `effort: medium` (`proj-verifier`, `proj-consistency-checker`) are NOT touched — the medium tier is deliberate per Anthropic agentic-coding guidance for procedural tool-use workloads. Also syncs the updated `techniques/agent-design.md` to the client-project path `.claude/references/techniques/agent-design.md` (NOT `techniques/` at client root — per `.claude/rules/general.md` §Migrations). Destructive line replaces use three-tier baseline-sentinel detection — customized client files get `SKIP_HAND_EDITED` + `.bak-044` backup + pointer to `## Manual-Apply-Guide`.

---

## Metadata

```yaml
id: "044"
breaking: false
affects: [agents, skills, techniques]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Opus 4.7 (released with the 1M-context variant) introduces `xhigh` as a new reasoning-effort level above `high`. Prior to 044, all bootstrap agents + skills that specified maximum reasoning depth used `effort: high` — the previous ceiling. The bootstrap templates and doctrine (`techniques/agent-design.md`) have been updated (Batches 01 + 02 + 03 + 03-fixup of the xhigh-effort-adoption plan) to treat `xhigh` as the new default for the "generates code / subtle error risk / multi-step synthesis / stateful memory" agent classes. Downstream client projects bootstrapped before Batch 01 merged still carry `effort: high` in every such agent + skill file. This migration propagates the adoption.

Three important invariants:

1. **Silent fallback on other models.** Models that do not implement `xhigh` interpret the field as their native maximum. There is no hard error, no warning, no quality regression for non-Opus-4.7 deployments — the field is effectively a hint. This is the central safety argument for a blanket replace.
2. **Procedural carve-out preserved.** `proj-verifier` and `proj-consistency-checker` run `effort: medium` per Anthropic agentic-coding guidance for procedural tool-use workloads (Build → Tests → Cross-refs → Frontmatter checklist). These agents MUST NOT be touched by the migration. The glob pattern-matches `^effort: high$` exclusively; `effort: medium` is invisible to it.
3. **Glob coverage for sub-specialists.** `/evolve-agents` can spawn additional `proj-code-writer-*` and `proj-test-writer-*` variants post-bootstrap (e.g., `proj-code-writer-typescript`, `proj-test-writer-python`). The migration globs `.claude/agents/*.md` unconditionally so every sub-specialist with `effort: high` gets bumped alongside the primary templates.

## Rationale

1. **Batches 01 + 02 + 03 of the plan updated the bootstrap-repo source of truth** (`templates/agents/*.md`, `templates/skills/*/SKILL.md`, `techniques/agent-design.md`, `.claude/rules/model-selection.md`). Client projects bootstrapped pre-044 still carry the old values.
2. **Three-tier baseline-sentinel detection (per `.claude/rules/general.md` Migration Preservation Discipline)** ensures client customizations are preserved: files with non-standard effort values (`effort: low`, `effort: ultra`, or effort key removed entirely) are detected and routed to `SKIP_HAND_EDITED` + `.bak-044` backup + manual-merge guidance — NEVER blind-overwrite.
3. **Technique sync** (per `.claude/rules/general.md` §Migrations — "Technique update = sync step in migration") fetches the updated `techniques/agent-design.md` from the bootstrap repo via `gh api` and writes to the client-layout path `.claude/references/techniques/agent-design.md`. The updated technique documents `xhigh` as the new default for the corresponding task classes.
4. **Justification comment sync.** Agents with `effort: high` carry an immediately-following justification comment (`# high: GENERATES_CODE`, `# high: SUBTLE_ERROR_RISK`, etc.) per migration 029's invariant. The migration rewrites the `# high:` token to `# xhigh:` so the comment tag stays in sync with the effort value — preserving the `# {effort}: {TOKEN}` invariant enforced by `/audit-agents` A7 presence check.

---

## Changes

1. Every `.claude/agents/*.md` file with frontmatter `effort: high` → `effort: xhigh`. Sentinel: presence of `^effort: xhigh$` (idempotency), `^effort: high$` (baseline), neither (hand-edited).
2. Every `.claude/skills/*/SKILL.md` file with frontmatter `effort: high` → `effort: xhigh`. Same sentinel discipline.
3. For every patched agent, adjacent `# high: <TOKEN>` justification comment (if present immediately after the effort line) → `# xhigh: <TOKEN>`. Preserves the `{effort}: {TOKEN}` invariant from migration 029.
4. Fetch updated `techniques/agent-design.md` from bootstrap repo → `.claude/references/techniques/agent-design.md`. Sentinel: `xhigh` token present.
5. Advance `.claude/bootstrap-state.json` → `last_migration: "044"` + append to `applied[]`.

Procedural agents (`proj-verifier`, `proj-consistency-checker`) carry `effort: medium` — the migration's line matcher (`^effort: high$` literal) cannot match them, so they are untouched by design.

Idempotent: re-running detects `^effort: xhigh$` on already-patched files and prints `SKIP: already patched — <path>`.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -d ".claude/agents" ]] || { echo "ERROR: no .claude/agents directory"; exit 1; }
[[ -d ".claude/skills" ]] || { echo "ERROR: no .claude/skills directory"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI required (for technique sync)"; exit 1; }
command -v sed >/dev/null 2>&1 || { echo "ERROR: sed required"; exit 1; }

BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-tomasfilip/claude-bootstrap}"
```

### Step 1 — Patch `.claude/agents/*.md` frontmatter (glob-loop, three-tier)

Read-before-write with three-tier baseline-sentinel detection per file:

- **Idempotency sentinel**: `^effort: xhigh$` present → `SKIP: already patched — <path>`
- **Baseline sentinel**: `^effort: high$` present (stock pre-044 state, safe to replace) → `PATCHED — <path>`
- **Neither sentinel**: file has been customized post-bootstrap (different effort value, or effort key absent, or unusual whitespace) → `SKIP_HAND_EDITED: <path> — manual merge required; see ## Manual-Apply-Guide §Step-1`. Writes `.bak-044` backup if not already present. Does NOT overwrite.

Glob covers primary templates + `/evolve-agents` sub-specialists (`proj-code-writer-*`, `proj-test-writer-*`, and any other `proj-*` variants). Procedural agents (`proj-verifier`, `proj-consistency-checker`) carry `effort: medium` — the `^effort: high$` literal match cannot touch them.

Justification comment sync (migration 029 invariant): when the effort line is patched, the immediately-following line matching `^# high: <TOKEN>$` is rewritten to `^# xhigh: <TOKEN>$` in the same pass. If the comment line is absent (some agents may not carry one), the step continues without error — absence does not invalidate the effort patch.

```bash
#!/usr/bin/env bash
set -euo pipefail

shopt -s nullglob
agents=(.claude/agents/*.md)
shopt -u nullglob

if [[ ${#agents[@]} -eq 0 ]]; then
  echo "SKIP: no agent files found in .claude/agents/"
  exit 0
fi

patched_count=0
skip_idempotent_count=0
skip_hand_edited_count=0

for agent in "${agents[@]}"; do
  [[ -f "$agent" ]] || continue

  # Tier 1 — Idempotency sentinel: already xhigh
  if grep -qE "^effort: xhigh\s*$" "$agent"; then
    echo "SKIP: already patched — $agent"
    skip_idempotent_count=$((skip_idempotent_count + 1))
    continue
  fi

  # Tier 2 — Baseline sentinel: stock pre-migration effort: high
  if grep -qE "^effort: high\s*$" "$agent"; then
    # Write backup once (before any destructive edit on this file)
    [[ -f "$agent.bak-044" ]] || cp "$agent" "$agent.bak-044"

    # Replace the effort line first.
    sed -i "s/^effort: high\s*$/effort: xhigh/" "$agent"

    # Then, if the adjacent justification comment exists on the immediately-following line,
    # rewrite the token. Python ensures we only touch an `# high:` line that is directly
    # adjacent to (or within 2 lines of) the effort line — never a stray `# high:` comment
    # elsewhere in the file body.
    python3 - "$agent" <<'PY'
import sys, re
path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()
# Find the effort: xhigh line (just-patched).
for i, line in enumerate(lines):
    if re.match(r'^effort:\s*xhigh\s*$', line):
        # Search the next 3 lines for the # high: justification comment.
        for j in range(i + 1, min(i + 4, len(lines))):
            m = re.match(r'^(# )high(:\s*\S.*)$', lines[j])
            if m:
                lines[j] = m.group(1) + 'xhigh' + m.group(2) + '\n' if not lines[j].endswith('\n') else m.group(1) + 'xhigh' + m.group(2) + '\n'
                # Normalize: rewrite preserving trailing newline presence
                orig_has_nl = lines[j - 0].endswith('\n')
                # Simpler: use re.sub on the single line
                break
        # Re-apply with a cleaner approach:
        break
# Cleaner single-pass: just rewrite any `# high: TOKEN` within 3 lines of an `effort: xhigh` line.
out = []
n = len(lines)
i = 0
while i < n:
    out.append(lines[i])
    if re.match(r'^effort:\s*xhigh\s*$', lines[i]):
        # Look ahead up to 3 lines for adjacent `# high: <TOKEN>` justification comment.
        for j in range(i + 1, min(i + 4, n)):
            new_line, subs = re.subn(r'^# high:', '# xhigh:', lines[j])
            if subs:
                lines[j] = new_line
                break
    i += 1
with open(path, 'w', encoding='utf-8') as f:
    f.writelines(lines)
PY

    echo "PATCHED — $agent"
    patched_count=$((patched_count + 1))
    continue
  fi

  # Tier 3 — Neither sentinel: file has been customized post-bootstrap
  [[ -f "$agent.bak-044" ]] || cp "$agent" "$agent.bak-044"
  echo "SKIP_HAND_EDITED: $agent — manual merge required (backup: $agent.bak-044; see migrations/044-xhigh-effort-adoption.md ## Manual-Apply-Guide §Step-1)"
  skip_hand_edited_count=$((skip_hand_edited_count + 1))
done

echo "---"
echo "Step 1 summary: PATCHED=$patched_count, SKIP_ALREADY=$skip_idempotent_count, SKIP_HAND_EDITED=$skip_hand_edited_count"
```

### Step 2 — Patch `.claude/skills/*/SKILL.md` frontmatter (glob-loop, three-tier)

Same three-tier pattern as Step 1, scoped to skill frontmatter. Skills do NOT carry the `# high: <TOKEN>` justification comment invariant (that is an agent-only pattern per migration 029), so the skill step only rewrites the `effort:` line itself — no adjacent-comment rewrite.

Glob `.claude/skills/*/SKILL.md` covers every skill in the project, including custom user-added skills.

```bash
#!/usr/bin/env bash
set -euo pipefail

shopt -s nullglob
skills=(.claude/skills/*/SKILL.md)
shopt -u nullglob

if [[ ${#skills[@]} -eq 0 ]]; then
  echo "SKIP: no skill files found in .claude/skills/*/SKILL.md"
  exit 0
fi

patched_count=0
skip_idempotent_count=0
skip_hand_edited_count=0

for skill in "${skills[@]}"; do
  [[ -f "$skill" ]] || continue

  # Tier 1 — Idempotency sentinel: already xhigh
  if grep -qE "^effort: xhigh\s*$" "$skill"; then
    echo "SKIP: already patched — $skill"
    skip_idempotent_count=$((skip_idempotent_count + 1))
    continue
  fi

  # Tier 2 — Baseline sentinel: stock pre-migration effort: high
  if grep -qE "^effort: high\s*$" "$skill"; then
    [[ -f "$skill.bak-044" ]] || cp "$skill" "$skill.bak-044"
    sed -i "s/^effort: high\s*$/effort: xhigh/" "$skill"
    echo "PATCHED — $skill"
    patched_count=$((patched_count + 1))
    continue
  fi

  # Tier 3 — Neither sentinel: hand-edited (effort: low, effort: medium, or effort key absent — skill carve-out)
  # Note: skills legitimately span multiple effort values (low / medium / high / xhigh per skill class per model-selection.md).
  # effort: medium or effort: low are NOT hand-edited — they are deliberate for their skill class.
  # The three-tier logic here ONLY triggers when the file had effort: high and now has something else (genuinely hand-edited)
  # OR when the effort key is entirely absent. Skills with deliberate effort: medium/low ALSO miss both sentinels
  # but are correctly left untouched — the migration's job is to bump high → xhigh, not to override deliberate tier choices.
  echo "SKIP_NO_BASELINE: $skill — skill does not carry 'effort: high' (may carry effort: medium/low/xhigh/absent deliberately); no action taken"
  skip_hand_edited_count=$((skip_hand_edited_count + 1))
done

echo "---"
echo "Step 2 summary: PATCHED=$patched_count, SKIP_ALREADY=$skip_idempotent_count, SKIP_NO_BASELINE=$skip_hand_edited_count"
```

### Step 3 — Sync updated `techniques/agent-design.md` → `.claude/references/techniques/agent-design.md`

Fetch updated technique content from bootstrap repo via `gh api`. Target the client layout path `.claude/references/techniques/agent-design.md` (NOT `techniques/` at client root — per `.claude/rules/general.md` §Migrations: "Technique update = sync step in migration" with destination being the client layout; see `modules/02-project-config.md` Step 5). Read-before-write: skip if the fetched-content sentinel (`xhigh`) is already present in the existing target file.

Authentication fallback: if `gh api` fails (not authenticated, rate-limited, or network error), the step emits a warning and continues without hard-failing the migration — the operator can manually fetch `techniques/agent-design.md` later. Per-step `set -e` is relaxed for the fetch subcommand via explicit `|| { ... }` handling.

```bash
#!/usr/bin/env bash
set -euo pipefail

TECH_PATH=".claude/references/techniques/agent-design.md"
BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-tomasfilip/claude-bootstrap}"

mkdir -p "$(dirname "$TECH_PATH")"

if [[ -f "$TECH_PATH" ]] && grep -q "xhigh" "$TECH_PATH"; then
  echo "SKIP: $TECH_PATH already contains xhigh sentinel"
  exit 0
fi

python3 <<PY
import base64, json, os, subprocess, sys

repo = "${BOOTSTRAP_REPO}"
tech_path = "${TECH_PATH}"

result = subprocess.run(
    ["gh", "api", f"repos/{repo}/contents/techniques/agent-design.md"],
    capture_output=True, text=True,
)
if result.returncode != 0:
    print(f"WARN: gh api fetch failed — technique sync skipped. Fetch manually via: gh api repos/{repo}/contents/techniques/agent-design.md --jq '.content' | base64 -d > {tech_path}")
    print(f"  stderr: {result.stderr.strip()}")
    # Fail-soft: do not hard-fail the migration; operator will manually sync.
    sys.exit(0)

payload = json.loads(result.stdout)
content = base64.b64decode(payload["content"]).decode("utf-8")

if "xhigh" not in content:
    print(f"ERROR: fetched agent-design.md does not contain 'xhigh' sentinel — bootstrap repo may not have Batch 03 merged. Re-run migration after bootstrap repo ships the xhigh-effort-adoption plan.")
    sys.exit(1)

# Write a backup of the existing technique file if present + differs.
if os.path.exists(tech_path):
    with open(tech_path, "r", encoding="utf-8") as f:
        existing = f.read()
    if existing != content:
        backup = tech_path + ".bak-044"
        if not os.path.exists(backup):
            with open(backup, "w", encoding="utf-8") as f:
                f.write(existing)

os.makedirs(os.path.dirname(tech_path), exist_ok=True)
with open(tech_path, "w", encoding="utf-8") as f:
    f.write(content)
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
state['last_migration'] = '044'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '044') or a == '044' for a in applied):
    applied.append({
        'id': '044',
        'applied_at': state['last_applied'],
        'description': 'xhigh effort adoption — replace effort: high with effort: xhigh across all agents and skills; sync agent-design.md technique; procedural effort: medium agents untouched.'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=044')
PY
```

### Rules for migration scripts

- **Read-before-write** — every patch step reads the target file, detects sentinels, and only writes on the safe-patch tier. Destructive edits always write `.bak-044` backup first.
- **Idempotent** — re-running prints `SKIP: already patched — <path>` per file. Step 3 skips on sentinel present in target.
- **Self-contained** — all logic inlined; sole external dependency is `gh api` for the technique sync (required per `general.md` — techniques updated via bootstrap repo fetch, never inlined).
- **No gitignored-path fetch** — the migration fetches from the bootstrap repo's TRACKED `techniques/` directory, NOT its gitignored `.claude/`.
- **Technique sync targets client layout** — writes to `.claude/references/techniques/agent-design.md`, NOT `techniques/` at the client project root (per `general.md` Migrations rule + `modules/02-project-config.md` Step 5). Past migrations 001/005/007 had this bug — fixed by migration 008 — do NOT repeat.
- **Abort on error** — `set -euo pipefail` in every bash block; Step 3 gh-fetch fallback is intentionally fail-soft (WARN + continue) to avoid blocking the whole migration on a transient authentication issue.
- **Procedural carve-out preserved** — `^effort: high$` literal match cannot touch `proj-verifier` or `proj-consistency-checker` (both carry `effort: medium`).
- **Glob coverage** — `.claude/agents/*.md` and `.claude/skills/*/SKILL.md` cover all sub-specialists, including those spawned by `/evolve-agents` post-bootstrap.
- **Scope lock** — touches only: `.claude/agents/*.md` (matching agents), `.claude/skills/*/SKILL.md` (matching skills), `.claude/references/techniques/agent-design.md`, `.claude/bootstrap-state.json`. `migrations/index.json` is appended BY MAIN THREAD outside this migration body (per `agent-scope-lock.md`).

---

## Verify

```bash
#!/usr/bin/env bash
set +e
fail=0

# 1. No remaining `^effort: high$` lines in agents — any remaining hits are hand-edited files (SKIP_HAND_EDITED during Step 1)
# We expect the count to equal the number of SKIP_HAND_EDITED files; for a fully stock project, this is 0.
remaining_agents=$(grep -rlE "^effort: high\s*$" .claude/agents/ 2>/dev/null | wc -l)
if [[ "$remaining_agents" -eq 0 ]]; then
  echo "PASS: no remaining 'effort: high' in .claude/agents/"
else
  echo "INFO: $remaining_agents agent file(s) retain 'effort: high' — expected if Step 1 reported SKIP_HAND_EDITED (hand-edited, preserved)"
  grep -rlE "^effort: high\s*$" .claude/agents/ 2>/dev/null | sed 's/^/  - /'
fi

# 2. No remaining `^effort: high$` lines in skills — same interpretation.
remaining_skills=$(grep -rlE "^effort: high\s*$" .claude/skills/ 2>/dev/null | wc -l)
if [[ "$remaining_skills" -eq 0 ]]; then
  echo "PASS: no remaining 'effort: high' in .claude/skills/"
else
  echo "INFO: $remaining_skills skill file(s) retain 'effort: high' — expected if Step 2 reported SKIP_HAND_EDITED"
  grep -rlE "^effort: high\s*$" .claude/skills/ 2>/dev/null | sed 's/^/  - /'
fi

# 3. Procedural carve-out preserved — proj-verifier + proj-consistency-checker still carry effort: medium
for proc_agent in .claude/agents/proj-verifier.md .claude/agents/proj-consistency-checker.md; do
  if [[ -f "$proc_agent" ]]; then
    if grep -qE "^effort: medium\s*$" "$proc_agent"; then
      echo "PASS: $proc_agent preserves effort: medium (procedural carve-out intact)"
    else
      echo "FAIL: $proc_agent no longer carries effort: medium — procedural carve-out BROKEN"
      fail=1
    fi
  else
    echo "INFO: $proc_agent not present (not installed in this project)"
  fi
done

# 4. At least one agent now carries effort: xhigh (sanity — the migration actually did something)
if grep -rlE "^effort: xhigh\s*$" .claude/agents/ 2>/dev/null | head -1 >/dev/null; then
  xhigh_count=$(grep -rlE "^effort: xhigh\s*$" .claude/agents/ 2>/dev/null | wc -l)
  echo "PASS: $xhigh_count agent file(s) carry effort: xhigh"
else
  echo "FAIL: no agent files carry effort: xhigh — migration made no changes (expected at least proj-code-writer-*, proj-researcher, proj-reflector, proj-plan-writer, proj-tdd-runner)"
  fail=1
fi

# 5. Justification comment sync — spot-check that patched agents still have `# xhigh:` tokens adjacent to `effort: xhigh` lines
# (not `# high:` orphans). This is a best-effort audit — missing comments are not a failure (some variants don't carry them).
orphan_high_comments=$(grep -rn "^# high:" .claude/agents/ 2>/dev/null | wc -l)
if [[ "$orphan_high_comments" -eq 0 ]]; then
  echo "PASS: no orphan '# high:' justification comments in .claude/agents/"
else
  echo "WARN: $orphan_high_comments '# high:' comment line(s) remain — verify they are in hand-edited files (otherwise re-run Step 1)"
  grep -rn "^# high:" .claude/agents/ 2>/dev/null | sed 's/^/  /'
fi

# 6. Technique sync landed
if [[ -f ".claude/references/techniques/agent-design.md" ]] && \
   grep -q "xhigh" .claude/references/techniques/agent-design.md; then
  echo "PASS: .claude/references/techniques/agent-design.md contains xhigh sentinel"
else
  echo "WARN: agent-design.md technique sync did not land — if Step 3 emitted WARN (gh auth), re-run manually: gh api repos/tomasfilip/claude-bootstrap/contents/techniques/agent-design.md --jq '.content' | base64 -d > .claude/references/techniques/agent-design.md"
fi

# 7. YAML frontmatter parses for all patched agents (sanity — no broken YAML after sed)
for agent in .claude/agents/*.md; do
  [[ -f "$agent" ]] || continue
  if python3 -c "
import sys, yaml
with open('$agent') as f:
    parts = f.read().split('---')
if len(parts) < 3:
    sys.exit(0)  # No frontmatter — not an error
yaml.safe_load(parts[1])
" 2>/dev/null; then
    :  # pass silently — only report failures
  else
    echo "FAIL: $agent YAML frontmatter invalid after patch"
    fail=1
  fi
done
echo "PASS: all agent YAML frontmatter parses (or no frontmatter block found)"

# 8. YAML frontmatter parses for all patched skills
for skill in .claude/skills/*/SKILL.md; do
  [[ -f "$skill" ]] || continue
  if python3 -c "
import sys, yaml
with open('$skill') as f:
    parts = f.read().split('---')
if len(parts) < 3:
    sys.exit(0)
yaml.safe_load(parts[1])
" 2>/dev/null; then
    :
  else
    echo "FAIL: $skill YAML frontmatter invalid after patch"
    fail=1
  fi
done
echo "PASS: all skill YAML frontmatter parses"

# 9. bootstrap-state.json updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "044" ]]; then
  echo "PASS: last_migration = 044"
else
  echo "FAIL: last_migration = $last (expected 044)"
  fail=1
fi

echo "---"
if [[ $fail -eq 0 ]]; then
  echo "Migration 044 verification: ALL PASS"
  echo ""
  echo "Optional cleanup: remove .bak-044 backups once you've confirmed patches are correct:"
  echo "  find .claude/agents .claude/skills .claude/references -name '*.bak-044' -delete"
else
  echo "Migration 044 verification: FAILURES — state NOT updated"
  exit 1
fi
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix.

---

## State Update

On success:
- `last_migration` → `"044"`
- append `{ "id": "044", "applied_at": "<ISO8601>", "description": "xhigh effort adoption — replace effort: high with effort: xhigh across all agents and skills; sync agent-design.md technique; procedural effort: medium agents untouched." }` to `applied[]`

---

## Idempotency

Re-running after success:
- Step 1 — every `.claude/agents/*.md` file carries `^effort: xhigh$` (or was SKIP_HAND_EDITED last run — still routes to that branch); prints `SKIP: already patched` per file
- Step 2 — every `.claude/skills/*/SKILL.md` file similarly
- Step 3 — `grep -q xhigh .claude/references/techniques/agent-design.md` passes → SKIP
- Step 4 — `applied[]` dedup check (migration id == `'044'`) → no duplicate append

No backups are rewritten on re-run. Agents/skills that were SKIP_HAND_EDITED on first apply remain SKIP_HAND_EDITED on re-run (both sentinels absent) — manual merge is still required.

---

## Rollback

```bash
#!/usr/bin/env bash
set -euo pipefail

# Option A — restore from .bak-044 backups (written by the migration itself)
for bak in .claude/agents/*.bak-044 .claude/skills/*/SKILL.md.bak-044 .claude/references/techniques/agent-design.md.bak-044; do
  [[ -f "$bak" ]] || continue
  orig="${bak%.bak-044}"
  mv "$bak" "$orig"
  echo "Restored: $orig"
done

# Option B — tracked strategy (if .claude/ is committed to project repo)
# git checkout -- .claude/agents/ .claude/skills/ .claude/references/techniques/agent-design.md

# Option C — companion strategy (restore from companion repo snapshot)
# cp -r ~/.claude-configs/<project>/.claude/agents/* ./.claude/agents/
# cp -r ~/.claude-configs/<project>/.claude/skills/ ./.claude/skills/
# cp ~/.claude-configs/<project>/.claude/references/techniques/agent-design.md ./.claude/references/techniques/

# Reset bootstrap-state.json
python3 <<'PY'
import json
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
if state.get('last_migration') == '044':
    state['last_migration'] = '043'
state['applied'] = [a for a in state.get('applied', []) if not (
    (isinstance(a, dict) and a.get('id') == '044') or a == '044'
)]
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State rolled back to last_migration=043')
PY
```

Rollback via `.bak-044` is safe because the migration writes the backup before any destructive edit. If no backup exists, the file was either SKIP_ALREADY (nothing to roll back) or SKIP_HAND_EDITED (nothing was written, so nothing to roll back).

---

## Post-Apply — Bootstrap Repo Self-Update

This migration targets client projects. The bootstrap repo's own `.claude/` copies are
generated output, not source of truth. To update the bootstrap repo's installed copies:
1. Run `/migrate-bootstrap` against the bootstrap repo itself, OR re-run each step manually against the bootstrap repo's `.claude/` (the templates at `templates/agents/*.md` + `templates/skills/*/SKILL.md` are already in the target state after Batches 01 + 02 + 03 of the xhigh-effort-adoption plan).
2. Do NOT directly edit `.claude/agents/*.md`, `.claude/skills/*/SKILL.md`, or `.claude/references/techniques/agent-design.md` in the bootstrap repo — direct edits bypass the templates and create drift.

Reference: `.claude/rules/general.md` §Process — "NEVER write to this repo's `.claude/` as implementation work."

---

## Manual-Apply-Guide

When Step 1 (agents) or Step 2 (skills) reports `SKIP_HAND_EDITED: <path>` or `SKIP_NO_BASELINE: <path>`, the migration detected that the target file's effort frontmatter field was customized post-bootstrap (baseline sentinel `^effort: high$` absent + post-migration sentinel `^effort: xhigh$` absent, OR the file carries a deliberate non-high effort value like `medium`/`low`). Automatic patching is unsafe — the migration does not know whether the customization should be preserved (deliberate tier choice) or overridden (pre-merged or pending upgrade). This guide provides the verbatim new-content blocks plus merge instructions so you can manually integrate the xhigh adoption while preserving your customizations.

**General procedure per skipped file**:
1. Open the target file.
2. Inspect the YAML frontmatter — identify the `effort:` line value.
3. Decide: does this file's effort value represent a DELIBERATE tier choice (medium for procedural agents; low for fast-lookup skills), or was it customized from `high` during ordinary work?
4. If DELIBERATE → leave it as-is. The migration correctly skipped this file. No further action.
5. If it should be `xhigh` (the file USED TO be `effort: high` before local customization, and the user wants it bumped now) → manually change the line to `effort: xhigh` AND update the adjacent `# high: <TOKEN>` justification comment (agents only) to `# xhigh: <TOKEN>`.
6. Save the file.
7. Run the verification snippet shown below to confirm the frontmatter parses and the sentinel is present.
8. A `.bak-044` backup of the pre-migration file state exists at `<path>.bak-044` if the migration wrote one; use `diff <path>.bak-044 <path>` to see what changed.

---

### §Step-1 — Agent frontmatter `effort: high` → `effort: xhigh`

**Target**: `.claude/agents/<agent>.md` frontmatter

**New content (verbatim — replace the existing effort line and, if present, its adjacent justification comment)**:

```yaml
effort: xhigh
# xhigh: GENERATES_CODE
```

(Substitute the correct token per your agent's class: `GENERATES_CODE` | `SUBTLE_ERROR_RISK` | `STATEFUL_MEMORY` | `MULTI_STEP_SYNTHESIS` | `INHERITED_DEFAULT` | `DISPATCHES_AGENTS`. Token vocabulary is fixed per `.claude/rules/model-selection.md` + migration 029. Keep your file's existing token — only the `high` → `xhigh` prefix changes.)

**Merge instructions**:
- Open `.claude/agents/<agent>.md`.
- Locate the YAML frontmatter block (between the two `---` lines at the top of the file).
- Find the line `effort: <value>`:
  - If `<value>` is `medium` (procedural agents — `proj-verifier`, `proj-consistency-checker`): **do NOT change it**. Medium is deliberate per Anthropic agentic-coding guidance.
  - If `<value>` is `low`: this is unusual for an agent — investigate whether the customization is deliberate. Leave as-is unless you specifically want to bump it.
  - If `<value>` is `high`: change to `xhigh`.
  - If `<value>` is `xhigh`: already patched; no action.
  - If the `effort:` key is absent entirely: add `effort: xhigh` as the last frontmatter line before the closing `---`, immediately followed by the adjacent comment line `# xhigh: <TOKEN>` (choose the appropriate TOKEN per agent class).
- If the line immediately after `effort:` is `# high: <TOKEN>`, rewrite to `# xhigh: <TOKEN>`.
- Save the file.

**Verification**: `python3 -c "import yaml; yaml.safe_load(open('.claude/agents/<agent>.md').read().split('---')[1]); print('OK')"` + `grep -E '^(effort|# (high|xhigh)):' .claude/agents/<agent>.md` (expected output: `effort: xhigh` and `# xhigh: <TOKEN>`)

---

### §Step-2 — Skill frontmatter `effort: high` → `effort: xhigh`

**Target**: `.claude/skills/<skill>/SKILL.md` frontmatter

**New content (verbatim — replace the existing effort line)**:

```yaml
effort: xhigh
```

(Skills do NOT carry an adjacent `# high: <TOKEN>` justification comment — that invariant is agent-only per migration 029. No comment sync needed.)

**Merge instructions**:
- Open `.claude/skills/<skill>/SKILL.md`.
- Locate the YAML frontmatter block (between the two `---` lines at the top of the file).
- Find the line `effort: <value>`:
  - If `<value>` is `low` or `medium`: skill class per `.claude/rules/model-selection.md` governs. Leave as-is unless the skill's class explicitly requires `xhigh` (per the model-selection table: main-thread orchestrator / main-thread single-dispatch / main-thread inline executor may be `high`/`xhigh`; forkable diagnostic probe is `low`; main-thread inline reads is `low`). Consult the table before changing.
  - If `<value>` is `high`: change to `xhigh`.
  - If `<value>` is `xhigh`: already patched; no action.
  - If the `effort:` key is absent entirely: add `effort: xhigh` as the last frontmatter line before the closing `---`.
- Save the file.

**Verification**: `python3 -c "import yaml; yaml.safe_load(open('.claude/skills/<skill>/SKILL.md').read().split('---')[1]); print('OK')"` + `grep -E '^effort:' .claude/skills/<skill>/SKILL.md` (expected output: `effort: xhigh` or `effort: <deliberate-non-xhigh-tier>`)

---

### §Step-3 — Technique sync fallback (gh api failure)

If Step 3 emitted `WARN: gh api fetch failed — technique sync skipped`, fetch the updated technique manually:

```bash
gh api repos/tomasfilip/claude-bootstrap/contents/techniques/agent-design.md \
  --jq '.content' | base64 -d > .claude/references/techniques/agent-design.md
grep -q "xhigh" .claude/references/techniques/agent-design.md && echo "OK: technique synced"
```

If `gh` is not authenticated: run `gh auth login` first, then retry. If the repo name is different (fork), substitute the correct `owner/repo` slug or set `BOOTSTRAP_REPO` in your environment.

---

## Post-Migration (main-thread only per agent-scope-lock.md)

Append to `migrations/index.json`:
```json
{
  "id": "044",
  "file": "044-xhigh-effort-adoption.md",
  "description": "Replace effort:high with effort:xhigh across all agents and skills — Opus 4.7 introduces xhigh effort level; silent fallback on other models means blanket replace is safe. Updates agent frontmatter, skill frontmatter, and syncs techniques/agent-design.md.",
  "breaking": false
}
```
