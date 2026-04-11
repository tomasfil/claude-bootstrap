# Migration 015 — Max Quality Doctrine retrofit

<!-- migration-id: 015-max-quality-doctrine -->

> Retrofit existing client projects with the full 10-layer Max Quality Doctrine: creates `.claude/rules/max-quality.md`, `.claude/hooks/check-quality.sh` (SubagentStop literal scan), `.claude/hooks/prompt-nudge.sh` (UserPromptSubmit skill + max-quality nudge), extends `.claude/hooks/stop-verify.sh` (nudge-only), rewires `.claude/settings.json`, syncs `prompt-engineering.md` + `token-efficiency.md` techniques into `.claude/references/techniques/`, appends token-efficiency output carve-out, adds STEP 0 reinforcement line across all `proj-*` agents, adds Completeness Check § to `proj-code-reviewer*` agents, adds calibrated-effort FORBIDDEN/REQUIRED to `proj-plan-writer*` agents.

---

## Metadata

```yaml
id: "015"
breaking: false
affects: [rules, hooks, settings, techniques, agents]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Observed 2026-04-11: subagent output truncation (`...`, "for brevity", pseudocode placeholders) + effort-padding language (`weeks`, `significant time`) slipping through downstream dispatch when operating under token pressure. `token-efficiency.md` applied to OUTPUT where it should only apply to INSTRUCTIONS. No enforcement layer for completeness. Plan-writer framing LLM-executable work in human project-management time units. No Stop/SubagentStop hook scanning for elision literals. No always-loaded doctrine file. No UserPromptSubmit nudge on write/impl verbs.

Fix: 10-layer defense-in-depth Max Quality Doctrine. This migration retrofits existing client projects with all layers that belong outside the bootstrap templates (templates for new projects already produce the finalized form via Batches 01 + 02 of the Max Quality Doctrine plan).

---

## Changes

1. Writes `.claude/rules/max-quality.md` — 7-section doctrine (marker `# Max Quality Doctrine`).
2. Syncs `prompt-engineering.md` + `token-efficiency.md` from bootstrap repo → `.claude/references/techniques/` (client layout — NEVER `techniques/` at root).
3. Edits `CLAUDE.md` → adds `@import .claude/rules/max-quality.md` after `mcp-routing.md` import line.
4. Globs `.claude/agents/proj-*.md` → adds `.claude/rules/max-quality.md` to STEP 0 force-read list + inserts reinforcement line at top of STEP 0 block.
5. Appends `## Output Carve-Out` section to `.claude/rules/token-efficiency.md` (doctrine §7 companion — INSTRUCTIONS only).
6. Creates `.claude/hooks/check-quality.sh` — SubagentStop literal scan w/ self-block prevention + high-precision elision + effort-pad regex.
7. Extends `.claude/hooks/stop-verify.sh` — appends MAX QUALITY nudge text (nudge-only, no scan, no decision:block — Stop hook schema lacks `last_assistant_message`).
8. Creates `.claude/hooks/prompt-nudge.sh` — UserPromptSubmit always-on skill-check nudge + conditional MAX QUALITY nudge on write/impl verbs.
9. Edits `.claude/settings.json` — registers `check-quality.sh` under SubagentStop array alongside existing `track-agent.sh`; replaces UserPromptSubmit inline `echo` command with `bash .claude/hooks/prompt-nudge.sh`. Python JSON manipulation only (probe `python3 python py`) — no sed.
10. Globs `.claude/agents/proj-code-reviewer*.md` → adds `## Completeness Check` section w/ 5-item binary checklist + `COMPLETENESS: PASS|FAIL` instruction.
11. Globs `.claude/agents/proj-plan-writer*.md` → adds time-based-estimate ban to FORBIDDEN section + calibrated-estimate rule to REQUIRED section.
12. Advances `.claude/bootstrap-state.json` → `last_migration: "015"` + appends `"015"` to `applied[]`.

Idempotent: every step detects its marker and prints `SKIP: already applied` on re-run.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { printf "ERROR: not a bootstrapped project — run full bootstrap first\n"; exit 1; }
[[ -d ".claude/rules" ]] || { printf "ERROR: no .claude/rules directory\n"; exit 1; }
[[ -d ".claude/agents" ]] || { printf "ERROR: no .claude/agents directory\n"; exit 1; }
[[ -d ".claude/hooks" ]] || { printf "ERROR: no .claude/hooks directory\n"; exit 1; }
[[ -f ".claude/settings.json" ]] || { printf "ERROR: no .claude/settings.json\n"; exit 1; }
command -v jq >/dev/null 2>&1 || { printf "ERROR: jq required (used by check-quality.sh + prompt-nudge.sh)\n"; exit 1; }

# Probe for python (python3 → python → py) — needed for JSON manipulation.
PY=""
for cand in python3 python py; do
  if command -v "$cand" >/dev/null 2>&1; then
    PY="$cand"
    break
  fi
done
[[ -n "$PY" ]] || { printf "ERROR: no python interpreter found (need one of python3, python, py)\n"; exit 1; }
printf "OK: python found — %s\n" "$PY"

# Migration 014 must be applied — 015 builds atop the STEP 0 blocks established by 011/012 and the tools-inheritance rule from 013/014.
"$PY" - <<'PY'
import json, sys
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
applied = state.get('applied', [])
has_014 = any(
    (isinstance(a, dict) and a.get('id') == '014') or a == '014'
    for a in applied
)
if not has_014:
    print("ERROR: migration 014 not applied — cannot apply 015")
    sys.exit(1)
print("OK: migration 014 present in applied[]")
PY
```

### Pre-flight — Detect re-apply vs fresh apply

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ -f ".claude/rules/max-quality.md" ]] && grep -q "^# Max Quality Doctrine" ".claude/rules/max-quality.md"; then
  printf "INFO: .claude/rules/max-quality.md already present — this is a RE-APPLY (upgrade path: re-fetch techniques, re-glob agents, re-verify hooks)\n"
  MIGRATION_MODE="reapply"
else
  printf "INFO: .claude/rules/max-quality.md absent — FRESH apply\n"
  MIGRATION_MODE="fresh"
fi
printf "MIGRATION_MODE=%s\n" "$MIGRATION_MODE"
```

---

### Step 1 — Create `.claude/rules/max-quality.md`

Inlines the 7-point doctrine. Idempotent via tempfile compare — re-writes only on content diff.

```bash
#!/usr/bin/env bash
set -euo pipefail

DEST=".claude/rules/max-quality.md"
TMPFILE="$(mktemp)"

cat > "$TMPFILE" <<'RULE_EOF'
# Max Quality Doctrine

## Rule
Output completeness > token efficiency. Full scope every time. No elision. Calibrated effort only.

## §1 Full Scope
Every listed part addressed. All items in a checklist, every file in a Files section, every
bullet in a contract, every block in a template. No truncation. No "for brevity". No "..."
as content elision. No "rest unchanged" as a substitute for writing the rest.
Partial output = failed task, regardless of token cost.

## §2 Full Implementation
Real code, real content, real paths. No pseudocode. No `TODO:` without a linked issue
(`TODO: #123`). No `TBD` placeholders in delivered work. No "stub for later". If the scope
says "write X", X ships complete, runnable, verified. If blocked → STOP and report the
blocker; do not substitute a placeholder and keep going.

## §3 Full Verification
Build command runs + passes. Test command runs + passes. Cross-references resolve to
existing files. No "should work" without evidence. No "looks right" without running it.
Cannot verify → say so explicitly in the report; never claim PASS on unrun checks.

## §4 Calibrated Effort
Effort estimates framed in observable units: file count, dispatch count, step count,
batch count. LLM-executable work operates at machine speed (minutes to hours within a
session), not human project-management time.
BANNED phrases in effort-estimate context: `days`, `weeks`, `months`, `significant time`,
`complex effort`, `substantial effort`, `large undertaking`, `major investment`,
`considerable work`, `non-trivial amount of time`.
Carve-out: `7 days` appearing in a cron expression, retention window, or literal data
field is NOT an effort estimate and is allowed.

## §5 Full Rule Compliance
STEP 0 force-reads completed before task-specific work — every rule file in the list
actually Read, not skimmed, not assumed. Dispatch agents actually dispatched — never
substituted with inline main-thread work when the plan specifies an agent. Skill-routing
rule honored — never bypass a skill to "save a step".

## §6 No Hedging
Direct answers. Lead with the action or the finding. No "I could try..." No "should I
continue?" No "want me to keep going?" If the task is solvable, solve it. If blocked,
report the blocker precisely and stop. Permission-seeking in the middle of a solvable
task is a hedge, not collaboration.

## §7 Token Efficiency = INSTRUCTIONS only
`token-efficiency.md` applies to INSTRUCTIONS (agent bodies, rules, specs, plans,
memory files). It NEVER applies to OUTPUT (generated code, spec content, plan task
bodies, review findings, diagnosis reports, file contents written to disk).
Output completeness > token efficiency. A shorter-but-incomplete output is a worse
output, regardless of token savings. If forced to choose between fidelity and brevity
in deliverables → choose fidelity every time.
RULE_EOF

if [[ -f "$DEST" ]] && cmp -s "$TMPFILE" "$DEST"; then
  printf "SKIP: %s already up to date\n" "$DEST"
  rm "$TMPFILE"
else
  mv "$TMPFILE" "$DEST"
  printf "WROTE: %s\n" "$DEST"
fi
```

---

### Step 2 — Sync technique files → `.claude/references/techniques/`

Fetches updated `prompt-engineering.md` + `token-efficiency.md` + `agent-design.md` from the bootstrap repo into the **canonical client layout** `.claude/references/techniques/` — NOT `techniques/` at project root (see migration 008 for the path-fix rationale; CLAUDE.md gotcha). `agent-design.md` is included because the Max Quality Doctrine fix pass added three new sections to it: expanded Force-Read enforcement list (with `max-quality.md` + `agent-scope-lock.md`), Hook Input Schema Gotcha (SubagentStop vs Stop `last_assistant_message` asymmetry), Use/Mention Discipline for Banned-Phrase Rules, and Template Placeholder Conventions — all canonical knowledge bootstrapped projects must receive.

Idempotent: fetch to `.new` tempfile, `cmp -s` against existing, replace only on diff. Uses `gh api` (migrations 001/005/007/008/011 precedent). Falls back to `curl` if `gh` unavailable.

```bash
#!/usr/bin/env bash
set -euo pipefail

TECH_DIR=".claude/references/techniques"
mkdir -p "$TECH_DIR"

# Resolve python probe from pre-flight (re-probe here for independent re-run safety).
PY=""
for cand in python3 python py; do
  if command -v "$cand" >/dev/null 2>&1; then
    PY="$cand"
    break
  fi
done
[[ -n "$PY" ]] || { printf "ERROR: no python interpreter for repo resolution\n"; exit 1; }

BOOTSTRAP_REPO=$("$PY" -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['bootstrap_repo'])" 2>/dev/null || printf "%s" "tomasfil/claude-bootstrap")

RAW_BASE=$("$PY" - <<PY
repo = "${BOOTSTRAP_REPO}".rstrip('/')
if 'github.com' in repo:
    parts = repo.replace('https://github.com/', '')
    print(f'https://raw.githubusercontent.com/{parts}/main')
else:
    print(f'https://raw.githubusercontent.com/{repo}/main')
PY
)

for name in prompt-engineering token-efficiency agent-design; do
  dest="${TECH_DIR}/${name}.md"
  tmp="${dest}.new"

  if command -v gh >/dev/null 2>&1; then
    if ! gh api "repos/${BOOTSTRAP_REPO}/contents/techniques/${name}.md" --jq '.content' 2>/dev/null | base64 -d > "$tmp"; then
      rm -f "$tmp"
      printf "ERROR: gh fetch of techniques/%s.md failed\n" "$name"
      exit 1
    fi
  elif command -v curl >/dev/null 2>&1; then
    if ! curl -fsSL "${RAW_BASE}/techniques/${name}.md" -o "$tmp"; then
      rm -f "$tmp"
      printf "ERROR: curl fetch of techniques/%s.md failed\n" "$name"
      exit 1
    fi
  else
    printf "ERROR: neither gh nor curl available — cannot sync technique %s\n" "$name"
    exit 1
  fi

  if [[ ! -s "$tmp" ]]; then
    rm -f "$tmp"
    printf "ERROR: fetched %s is empty\n" "$dest"
    exit 1
  fi

  if [[ -f "$dest" ]] && cmp -s "$dest" "$tmp"; then
    rm "$tmp"
    printf "SKIP: %s already up to date\n" "$dest"
  else
    mv "$tmp" "$dest"
    printf "UPDATED: %s\n" "$dest"
  fi
done
```

---

### Step 3 — Insert `@import .claude/rules/max-quality.md` into `CLAUDE.md`

Idempotent: `grep -q` check before insertion. Inserts after the existing `@import .claude/rules/mcp-routing.md` line (anchor set by migration 011). Skip entirely if `CLAUDE.md` absent.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET="CLAUDE.md"
IMPORT_LINE="@import .claude/rules/max-quality.md"
ANCHOR="@import .claude/rules/mcp-routing.md"

if [[ ! -f "$TARGET" ]]; then
  printf "SKIP: %s not present\n" "$TARGET"
  exit 0
fi

if grep -qF "$IMPORT_LINE" "$TARGET"; then
  printf "SKIP: %s already imports max-quality.md\n" "$TARGET"
  exit 0
fi

PY=""
for cand in python3 python py; do
  command -v "$cand" >/dev/null 2>&1 && { PY="$cand"; break; }
done
[[ -n "$PY" ]] || { printf "ERROR: no python interpreter\n"; exit 1; }

"$PY" - <<PY
import sys
target = "${TARGET}"
import_line = "${IMPORT_LINE}"
anchor = "${ANCHOR}"

with open(target, "r", encoding="utf-8") as f:
    content = f.read()

if import_line in content:
    print(f"SKIP: {target} already imports max-quality.md")
    sys.exit(0)

lines = content.split("\n")

# Prefer insertion immediately after the mcp-routing.md anchor.
anchor_idx = -1
for i, line in enumerate(lines):
    if anchor in line:
        anchor_idx = i
        break

if anchor_idx >= 0:
    lines.insert(anchor_idx + 1, import_line)
    action = f"inserted after mcp-routing import (line {anchor_idx + 1})"
else:
    # Anchor not found → insert after last @import line.
    last_import_idx = -1
    for i, line in enumerate(lines):
        if line.lstrip().startswith("@import"):
            last_import_idx = i
    if last_import_idx >= 0:
        lines.insert(last_import_idx + 1, import_line)
        action = f"inserted after last @import (line {last_import_idx + 1})"
    else:
        # No @import lines at all — insert near top, after first heading if present.
        insert_at = 0
        for i, line in enumerate(lines):
            if line.startswith("# "):
                insert_at = i + 1
                break
        lines.insert(insert_at, import_line)
        action = f"inserted at line {insert_at} (no prior @import lines)"

with open(target, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))
print(f"PATCHED: {target} — {action}")
PY
```

---

### Step 4 — Retrofit `proj-*` agents: add `max-quality.md` to STEP 0 + insert reinforcement line

Globs ALL `proj-*.md` agents (covers sub-specialists created by `/evolve-agents`). For each agent:
- Inserts `.claude/rules/max-quality.md` line into the STEP 0 force-read list immediately after the `mcp-routing.md` line — if not already present.
- Inserts the reinforcement line `Output completeness > token efficiency. Full scope every time. No elision. Calibrated effort only.` as the first content line after the `## STEP 0 — Load critical rules (MANDATORY first action)` heading — if not already present.

Idempotent: both insertions are marker-guarded.

```bash
#!/usr/bin/env bash
set -euo pipefail

PY=""
for cand in python3 python py; do
  command -v "$cand" >/dev/null 2>&1 && { PY="$cand"; break; }
done
[[ -n "$PY" ]] || { printf "ERROR: no python interpreter\n"; exit 1; }

"$PY" - <<'PY'
import glob, os, sys

REINFORCEMENT_LINE = "Output completeness > token efficiency. Full scope every time. No elision. Calibrated effort only."
MAX_QUALITY_RULE_LINE = "- `.claude/rules/max-quality.md` (doctrine — output completeness > token efficiency; full scope; calibrated effort)"
MCP_ANCHOR = "- `.claude/rules/mcp-routing.md`"
STEP0_HEADING = "## STEP 0 — Load critical rules (MANDATORY first action)"

# Glob proj-*.md using shell-level glob — does NOT recurse into references/.
# Explicit path-component check as defense in depth.
candidates = []
for p in sorted(glob.glob(".claude/agents/proj-*.md")):
    norm = os.path.normpath(p).replace("\\", "/")
    if "references/" in norm:
        continue
    candidates.append(norm)

patched_rule = 0
patched_reinf = 0
skipped_norule = 0
skipped_no_step0 = 0

for path in candidates:
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    if STEP0_HEADING not in content:
        print(f"WARN: {path} — no STEP 0 heading; left unchanged (run migration 011 first)")
        skipped_no_step0 += 1
        continue

    lines = content.split("\n")
    changed = False

    # --- Insert max-quality.md rule line into force-read list ---
    if MAX_QUALITY_RULE_LINE not in content:
        inserted_rule = False
        for i, line in enumerate(lines):
            if line.startswith(MCP_ANCHOR):
                lines.insert(i + 1, MAX_QUALITY_RULE_LINE)
                inserted_rule = True
                break
        if inserted_rule:
            patched_rule += 1
            changed = True
        else:
            # mcp-routing.md anchor missing — append rule line before the closing blank line of the force-read list.
            # Find STEP 0 heading then first blank line after any list item starting with "- `.claude/rules".
            step0_idx = None
            for i, line in enumerate(lines):
                if STEP0_HEADING in line:
                    step0_idx = i
                    break
            if step0_idx is not None:
                # Walk forward to find end of rule list
                last_list_idx = step0_idx
                for j in range(step0_idx + 1, len(lines)):
                    if lines[j].startswith("- `.claude/rules/"):
                        last_list_idx = j
                    elif lines[j].strip() == "" and last_list_idx > step0_idx:
                        break
                lines.insert(last_list_idx + 1, MAX_QUALITY_RULE_LINE)
                patched_rule += 1
                changed = True
    else:
        skipped_norule += 1

    # --- Insert reinforcement line after STEP 0 heading (if not already present) ---
    content_after_rule = "\n".join(lines)
    if REINFORCEMENT_LINE not in content_after_rule:
        new_lines = []
        inserted_reinf = False
        for i, line in enumerate(lines):
            new_lines.append(line)
            if not inserted_reinf and STEP0_HEADING in line:
                # Insert blank line + reinforcement + blank line right after heading.
                new_lines.append("")
                new_lines.append(REINFORCEMENT_LINE)
                inserted_reinf = True
        if inserted_reinf:
            lines = new_lines
            patched_reinf += 1
            changed = True

    if changed:
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
        print(f"PATCHED: {path}")

print(f"SUMMARY: rule_inserted={patched_rule} reinforcement_inserted={patched_reinf} already_had_rule={skipped_norule} missing_step0={skipped_no_step0} total_candidates={len(candidates)}")
PY
```

---

### Step 5 — Append Output Carve-Out to `.claude/rules/token-efficiency.md`

Appends `## Output Carve-Out` section declaring that `token-efficiency.md` applies to INSTRUCTIONS only, not OUTPUT. Marker-guarded: `grep -q` before append.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/rules/token-efficiency.md"
MARKER="## Output Carve-Out"

if [[ ! -f "$TARGET" ]]; then
  printf "ERROR: %s missing — run Module 02 first\n" "$TARGET"
  exit 1
fi

if grep -qF "$MARKER" "$TARGET"; then
  printf "SKIP: %s already has Output Carve-Out section\n" "$TARGET"
  exit 0
fi

cat >> "$TARGET" <<'CARVE_EOF'

## Output Carve-Out
Applies to INSTRUCTIONS only (agent bodies, rules, specs, plans, memory files).
Implementation OUTPUT (code, spec content, plan steps, review findings, task bodies)
is NEVER compressed. Never abbreviate output to save tokens. Output completeness >
token efficiency. Full scope every time — elision is not a compression technique.
See `.claude/rules/max-quality.md` §7 for the governing doctrine.
CARVE_EOF

printf "PATCHED: %s — Output Carve-Out section appended\n" "$TARGET"
```

---

### Step 6 — Create `.claude/hooks/check-quality.sh` (SubagentStop literal scan)

Scans SubagentStop `last_assistant_message` for high-precision elision + effort-pad literals. Self-block prevention: if the message quotes doctrine files or the doctrine name itself, skip the scan (doctrine-quoting output should not self-block). High-precision literals only — `TODO:` + `\b(weeks?|days?)\b` are EXCLUDED and delegated to Layer 6 (`proj-code-reviewer`'s Completeness Check) because regex cannot distinguish linked/unlinked TODOs or effort-context vs cron-context usage.

Shell-standards compliant: `#!/usr/bin/env bash`, `set -euo pipefail`, read stdin via `cat`, `[[ ]]` conditionals, quoted variables, no `echo -e`. Hook output: JSON decision block on stdout (hooks communicate via stdout JSON, not exit codes for block).

```bash
#!/usr/bin/env bash
set -euo pipefail

DEST=".claude/hooks/check-quality.sh"

if [[ -f "$DEST" ]] && grep -q "Max-quality check failed" "$DEST"; then
  printf "SKIP: %s already present\n" "$DEST"
  chmod +x "$DEST"
  exit 0
fi

cat > "$DEST" <<'HOOK_EOF'
#!/usr/bin/env bash
set -euo pipefail

# SubagentStop input includes last_assistant_message (string)
INPUT=$(cat)
MSG=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // ""')

# Empty message → nothing to scan
if [[ -z "$MSG" ]]; then
  exit 0
fi

# Self-block prevention: agent quoting doctrine files or the doctrine name itself
# would false-positive every literal below. Skip scan in that case.
if printf '%s' "$MSG" | grep -q -F -e '.claude/rules/max-quality.md' \
                                   -e '.claude/hooks/check-quality.sh' \
                                   -e 'Max Quality Doctrine'; then
  exit 0
fi

# High-precision elision literals (grep -E, case-insensitive)
ELISION_RE='for brevity|\.\.\. ?\(omitted|pseudocode|abbreviated for|truncated for|similar pattern follows|etc\. \(more'

# High-precision effort-pad literals (grep -E, case-insensitive)
EFFORT_RE='significant time|complex effort|substantial effort|large undertaking'

# NOTE — EXCLUDED from hook regex (delegated to Layer 6 proj-code-reviewer):
#   TODO:          — cannot distinguish linked `TODO: #123` from bare unlinked `TODO:`
#   \b(weeks?|days?)\b — collides w/ cron/retention/date content (7 days, 30 days, 24h elapsed)
# Reviewer has context; regex does not. Keep hook high-precision.

MATCH=$(printf '%s' "$MSG" | grep -oE -i -m1 "$ELISION_RE|$EFFORT_RE" || true)

if [[ -n "$MATCH" ]]; then
  # decision:block feeds reason back to subagent; it must continue its task
  jq -n --arg r "Max-quality check failed: $MATCH. Provide full output without abbreviation or effort-padding." \
    '{decision:"block", reason:$r}'
  exit 0
fi

exit 0
HOOK_EOF

chmod +x "$DEST"
printf "WROTE: %s (chmod +x)\n" "$DEST"
```

---

### Step 7 — Extend `.claude/hooks/stop-verify.sh` with MAX QUALITY nudge

Appends the MAX QUALITY nudge text to the existing nudge echo inside `stop-verify.sh`. **NO new scan logic. NO `decision:block`. Nudge-only.**

Rationale: Stop hook input schema does NOT include `last_assistant_message` (only SubagentStop does). Field-based scanning impossible on main-thread end-of-turn. Main-thread enforcement degrades to (a) CLAUDE.md `@import` of `max-quality.md` (always-loaded doctrine context), (b) SubagentStop `check-quality.sh` (subagent literal scan), (c) `proj-code-reviewer` Completeness Check (context-sensitive violations).

Idempotent marker: `grep -q "MAX QUALITY"` before editing.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/hooks/stop-verify.sh"
MAX_QUALITY_NUDGE="MAX QUALITY: verify full scope, no elision, calibrated effort — run /review before /commit."

if [[ ! -f "$TARGET" ]]; then
  printf "ERROR: %s missing — run Module 03 first\n" "$TARGET"
  exit 1
fi

if grep -qF "MAX QUALITY" "$TARGET"; then
  printf "SKIP: %s already contains MAX QUALITY nudge\n" "$TARGET"
  exit 0
fi

PY=""
for cand in python3 python py; do
  command -v "$cand" >/dev/null 2>&1 && { PY="$cand"; break; }
done
[[ -n "$PY" ]] || { printf "ERROR: no python interpreter\n"; exit 1; }

"$PY" - <<PY
import re
target = "${TARGET}"
max_nudge = "${MAX_QUALITY_NUDGE}"

with open(target, "r", encoding="utf-8") as f:
    content = f.read()

# Heuristic: find existing echo/printf line that emits a reminder/verification nudge.
# Append max_nudge text inside the same string literal so the nudge reaches Claude as one block.
patterns = [
    (r'(echo\s+["\']([^"\']*?(reminder|verify|/verify)[^"\']*?))(["\'])', r'\1 ' + max_nudge + r'\4'),
    (r'(printf\s+["\']%s\\n["\']\s+["\']([^"\']*?(reminder|verify|/verify)[^"\']*?))(["\'])', r'\1 ' + max_nudge + r'\4'),
]

patched = False
for pat, repl in patterns:
    new_content, n = re.subn(pat, repl, content, count=1)
    if n > 0:
        content = new_content
        patched = True
        break

if not patched:
    # Fallback: append a new echo line before any final 'exit 0' at end of file.
    append_line = 'echo "' + max_nudge + '"'
    if re.search(r'\nexit 0\s*$', content):
        content = re.sub(r'\nexit 0\s*$', '\n' + append_line + '\nexit 0\n', content)
    else:
        content = content.rstrip() + "\n" + append_line + "\n"
    patched = True

with open(target, "w", encoding="utf-8") as f:
    f.write(content)

print(f"PATCHED: {target} — MAX QUALITY nudge appended")
PY
```

---

### Step 7b — Create `.claude/hooks/prompt-nudge.sh` (UserPromptSubmit)

Always-on skill-check nudge + conditional MAX QUALITY nudge on write/impl verbs. Replaces the legacy inline `echo '...'` command in `settings.json` UserPromptSubmit (see Step 8). Exit 0 always — UserPromptSubmit nudges never block.

```bash
#!/usr/bin/env bash
set -euo pipefail

DEST=".claude/hooks/prompt-nudge.sh"

if [[ -f "$DEST" ]] && grep -q "MAX QUALITY: full scope" "$DEST"; then
  printf "SKIP: %s already present\n" "$DEST"
  chmod +x "$DEST"
  exit 0
fi

cat > "$DEST" <<'HOOK_EOF'
#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // ""')

# Always-on skill routing nudge
printf '%s\n' 'SKILL CHECK: Before starting work, evaluate if a skill from the Skill tool applies. Skills orchestrate agents — do not bypass.'

# Conditional max-quality nudge on write/impl verbs (case-insensitive, word boundary)
if printf '%s' "$PROMPT" | grep -qiE '\b(write|implement|create|generate|fix|build|refactor)\b'; then
  printf '%s\n' 'MAX QUALITY: full scope, no elision, calibrated effort, verify before claiming done.'
fi

exit 0
HOOK_EOF

chmod +x "$DEST"
printf "WROTE: %s (chmod +x)\n" "$DEST"
```

---

### Step 8 — Update `.claude/settings.json` (Python JSON manipulation only — no sed)

Two edits:
- (a) Add `bash .claude/hooks/check-quality.sh` to `SubagentStop[0].hooks[]` alongside existing `track-agent.sh`.
- (b) Replace `UserPromptSubmit[0].hooks[0].command` from inline `echo '...'` to `bash .claude/hooks/prompt-nudge.sh`.

Python JSON read/write only — JSON editing with sed is fragile. Probe `python3 python py` in order (pattern from `.claude/scripts/json-val.sh`) so Windows bash environments without `python3` still work. Validate JSON structure after write via same probe.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/settings.json"

if [[ ! -f "$TARGET" ]]; then
  printf "ERROR: %s missing — run Module 03 first\n" "$TARGET"
  exit 1
fi

PY=""
for cand in python3 python py; do
  command -v "$cand" >/dev/null 2>&1 && { PY="$cand"; break; }
done
[[ -n "$PY" ]] || { printf "ERROR: no python interpreter (need python3, python, or py)\n"; exit 1; }

"$PY" - <<'PY'
import json, sys

path = ".claude/settings.json"
with open(path, "r", encoding="utf-8") as f:
    settings = json.load(f)

hooks = settings.setdefault("hooks", {})
changed = False

# --- (a) SubagentStop: add check-quality.sh alongside track-agent.sh ---
subagent_stop = hooks.setdefault("SubagentStop", [])
if not subagent_stop:
    subagent_stop.append({"hooks": []})

# Find an entry that already contains track-agent.sh (canonical group) or use first entry.
target_entry = None
for entry in subagent_stop:
    entry_hooks = entry.get("hooks", [])
    if any("track-agent.sh" in h.get("command", "") for h in entry_hooks):
        target_entry = entry
        break
if target_entry is None:
    target_entry = subagent_stop[0]
    target_entry.setdefault("hooks", [])

cmds = [h.get("command", "") for h in target_entry["hooks"]]
if not any("check-quality.sh" in c for c in cmds):
    target_entry["hooks"].append({
        "type": "command",
        "command": "bash .claude/hooks/check-quality.sh"
    })
    changed = True
    print("PATCHED: SubagentStop — check-quality.sh registered")
else:
    print("SKIP: SubagentStop — check-quality.sh already registered")

# --- (b) UserPromptSubmit: replace inline echo with prompt-nudge.sh dispatch ---
ups = hooks.setdefault("UserPromptSubmit", [])
if not ups:
    ups.append({"hooks": [{"type": "command", "command": "bash .claude/hooks/prompt-nudge.sh"}]})
    changed = True
    print("PATCHED: UserPromptSubmit — created entry dispatching prompt-nudge.sh")
else:
    for entry in ups:
        for h in entry.get("hooks", []):
            cmd = h.get("command", "")
            if "prompt-nudge.sh" in cmd:
                print("SKIP: UserPromptSubmit — already dispatches prompt-nudge.sh")
            else:
                h["command"] = "bash .claude/hooks/prompt-nudge.sh"
                changed = True
                print("PATCHED: UserPromptSubmit — command replaced with prompt-nudge.sh")

if changed:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    # Re-validate after write
    with open(path, "r", encoding="utf-8") as f:
        json.load(f)
    print(f"VALID: {path} re-parsed OK after write")
else:
    print(f"SKIP: {path} unchanged")
PY
```

---

### Step 9 — Retrofit `proj-code-reviewer*.md` agents: add `## Completeness Check` section

Globs `proj-code-reviewer*.md` (covers sub-specialists). For each agent missing the marker `## Completeness Check`, appends the 5-item binary checklist + `COMPLETENESS: PASS|FAIL` instruction to the end of the file (Section 9 per module 07 template). Idempotent via marker check.

```bash
#!/usr/bin/env bash
set -euo pipefail

PY=""
for cand in python3 python py; do
  command -v "$cand" >/dev/null 2>&1 && { PY="$cand"; break; }
done
[[ -n "$PY" ]] || { printf "ERROR: no python interpreter\n"; exit 1; }

"$PY" - <<'PY'
import glob, os

MARKER = "## Completeness Check"

COMPLETENESS_SECTION = """

## 9. Completeness Check (Max Quality Doctrine enforcement)
Reviewer is the enforcement layer for `.claude/rules/max-quality.md`. Hook-based regex
checks lack LLM context judgment — TODO-link validation and weeks/days effort-context
detection live HERE, not in any Layer 2 hook.

Binary checklist (evaluate Y/N per file reviewed):
- All listed parts addressed? (every checklist item, every Files entry, every contract
  bullet — any omission = FAIL) → Y/N
- Pseudocode substitutions present? (any `// TODO: implement`, stub return, placeholder
  body masquerading as implementation) → Y/N
- `TODO:` markers without linked issue present? (reviewer evaluates w/ LLM judgment:
  `TODO: #123` or `TODO: link-to-issue` = PASS, bare `TODO:` or `TODO: will do later`
  = FAIL) → Y/N
- "for brevity" / elision phrases present? (`...`, `rest unchanged`, `for brevity`,
  `omitted for clarity`, `you get the idea` in delivered code/content) → Y/N
- Effort-pad language in effort-estimate context? (reviewer evaluates w/ LLM context
  judgment: `7 days` in cron config = PASS, `this will take 2 weeks` in a task
  description = FAIL) → Y/N
  Banned phrases in effort context: `days`, `weeks`, `months`, `significant time`,
  `complex effort`, `substantial effort`, `large undertaking`, `major investment`,
  `considerable work`, `non-trivial amount of time`.
  Carve-out: literal data values inside code/config (cron windows, retention periods,
  sleep durations) are NOT effort estimates and do not fail this check.

Reviewer LLM context advantage: hook regex cannot distinguish `TODO: #123` from bare
`TODO:`, cannot distinguish `7 days retention` config from `this will take 2 weeks`
effort narrative. Reviewer can. This is why TODO + effort-context detection MUST live
at the reviewer layer, NOT in a Layer 2 hook. Layer 2 hook remains regex-only
(trivially detectable patterns like `for brevity`, `...` ellipsis, `rest unchanged`).

Output line (append to Report Format §7 in the final reviewer output):
`COMPLETENESS: PASS|FAIL` — PASS only if all 5 checks are N (no violations found).
Any Y answer on the checklist → COMPLETENESS: FAIL + itemize the violations in the
MUST-FIX section alongside other blocking issues.
"""

candidates = sorted(glob.glob(".claude/agents/proj-code-reviewer*.md"))
candidates = [p for p in candidates if "references/" not in os.path.normpath(p).replace("\\", "/")]

if not candidates:
    print("SKIP: no proj-code-reviewer*.md agents found")
else:
    for path in candidates:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        if MARKER in content:
            print(f"SKIP: {path} already has Completeness Check section")
            continue
        with open(path, "w", encoding="utf-8") as f:
            f.write(content.rstrip() + "\n" + COMPLETENESS_SECTION)
        print(f"PATCHED: {path} — Completeness Check section appended")
PY
```

---

### Step 10 — Retrofit `proj-plan-writer*.md` agents: add calibrated-effort FORBIDDEN + REQUIRED

Globs `proj-plan-writer*.md` (covers sub-specialists). For each agent: append a calibrated-effort discipline block to the end of the file, referencing `max-quality.md` §4 as the governing doctrine source. Idempotent via marker `FORBIDDEN in effort estimates (plan-writer output)`.

```bash
#!/usr/bin/env bash
set -euo pipefail

PY=""
for cand in python3 python py; do
  command -v "$cand" >/dev/null 2>&1 && { PY="$cand"; break; }
done
[[ -n "$PY" ]] || { printf "ERROR: no python interpreter\n"; exit 1; }

"$PY" - <<'PY'
import glob, os

MARKER = "FORBIDDEN in effort estimates (plan-writer output)"

CALIBRATED_BLOCK = """

## Calibrated Effort Discipline (Max Quality Doctrine §4)

Doctrine source: `.claude/rules/max-quality.md` §4 (Calibrated Effort) is the governing
rule for effort-estimate language in plan-writer output. The rules below are the
plan-writer-specific enforcement of that doctrine.

### FORBIDDEN in effort estimates (plan-writer output)
Time-based effort language is banned. Plan-writer dispatches LLM-executable work that
runs at machine speed within a single session. Human project-management units are
inappropriate and produce effort-padding that misleads downstream agents.

Banned phrases in effort-estimate context: `days`, `weeks`, `months`, `significant
time`, `complex effort`, `substantial effort`, `large undertaking`, `major investment`,
`considerable work`, `non-trivial amount of time`.

Carve-out: literal data values (`7 days` retention, `30 days` cron window) inside
code/config are NOT effort estimates and are allowed. The ban applies to narrative
effort framing in task descriptions, tier rationales, batch summaries, and plan
overviews.

### REQUIRED in effort estimates (plan-writer output)
Calibrated estimates in observable units only. Valid effort framings:
- file count (`touches 3 files`)
- dispatch count (`1 dispatch unit`, `3 parallel batches`)
- step count (`7 steps in task body`)
- batch count (`2 batches, serialized`)
- task count (`5 tasks, all micro`)

LLM-executable work framed as "minutes-to-hours within session". Narrative effort
context (if any) must use these units exclusively.
"""

candidates = sorted(glob.glob(".claude/agents/proj-plan-writer*.md"))
candidates = [p for p in candidates if "references/" not in os.path.normpath(p).replace("\\", "/")]

if not candidates:
    print("SKIP: no proj-plan-writer*.md agents found")
else:
    for path in candidates:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        if MARKER in content:
            print(f"SKIP: {path} already has calibrated-effort discipline block")
            continue
        with open(path, "w", encoding="utf-8") as f:
            f.write(content.rstrip() + "\n" + CALIBRATED_BLOCK)
        print(f"PATCHED: {path} — calibrated-effort discipline block appended")
PY
```

---

### Step 11 — Self-test + bootstrap-state advance

Runs 6 presence/validity checks. Emits final summary line. Updates `.claude/bootstrap-state.json` → `last_migration: "015"` + appends entry to `applied[]`.

```bash
#!/usr/bin/env bash
set -euo pipefail

fail=0
pass=0
checks=6

# 1. max-quality.md rule file
if [[ -f ".claude/rules/max-quality.md" ]] && grep -q '^# Max Quality Doctrine' .claude/rules/max-quality.md; then
  printf "PASS: .claude/rules/max-quality.md present\n"
  pass=$((pass + 1))
else
  printf "FAIL: .claude/rules/max-quality.md missing\n"
  fail=1
fi

# 2. check-quality.sh hook
if [[ -f ".claude/hooks/check-quality.sh" ]] && [[ -x ".claude/hooks/check-quality.sh" ]]; then
  printf "PASS: .claude/hooks/check-quality.sh present + executable\n"
  pass=$((pass + 1))
else
  printf "FAIL: .claude/hooks/check-quality.sh missing or not executable\n"
  fail=1
fi

# 3. prompt-nudge.sh hook
if [[ -f ".claude/hooks/prompt-nudge.sh" ]] && [[ -x ".claude/hooks/prompt-nudge.sh" ]]; then
  printf "PASS: .claude/hooks/prompt-nudge.sh present + executable\n"
  pass=$((pass + 1))
else
  printf "FAIL: .claude/hooks/prompt-nudge.sh missing or not executable\n"
  fail=1
fi

# 4. CLAUDE.md imports max-quality.md (only checked if CLAUDE.md exists)
if [[ -f "CLAUDE.md" ]]; then
  if grep -q "@import .claude/rules/max-quality.md" CLAUDE.md; then
    printf "PASS: CLAUDE.md imports max-quality.md\n"
    pass=$((pass + 1))
  else
    printf "FAIL: CLAUDE.md missing @import .claude/rules/max-quality.md\n"
    fail=1
  fi
else
  printf "SKIP: CLAUDE.md not present — @import check skipped\n"
  checks=$((checks - 1))
fi

# 5. code-writer reinforcement line (nullglob guard — glob may expand to literal if no matches)
shopt -s nullglob
files=(.claude/agents/proj-code-writer-*.md)
shopt -u nullglob
if [[ ${#files[@]} -gt 0 ]]; then
  missing=0
  for f in "${files[@]}"; do
    if ! grep -q "Output completeness" "$f"; then
      missing=$((missing + 1))
    fi
  done
  if [[ $missing -eq 0 ]]; then
    printf "PASS: all %d code-writer agents carry reinforcement line\n" "${#files[@]}"
    pass=$((pass + 1))
  else
    printf "WARN: %d of %d code-writer agents missing reinforcement line\n" "$missing" "${#files[@]}"
  fi
else
  printf "WARN: no proj-code-writer-*.md agents found (none present in this project)\n"
  checks=$((checks - 1))
fi

# 6. settings.json valid JSON + both hook wirings (python probe for Windows bash portability)
PY=""
for cand in python3 python py; do
  command -v "$cand" >/dev/null 2>&1 && { PY="$cand"; break; }
done
if [[ -z "$PY" ]]; then
  printf "FAIL: no python interpreter for settings.json validation\n"
  fail=1
else
  if "$PY" - <<'PY'
import json, sys
with open('.claude/settings.json') as f:
    settings = json.load(f)
hooks = settings.get('hooks', {})

# SubagentStop must contain check-quality.sh
ss = hooks.get('SubagentStop', [])
ss_cmds = [h.get('command', '') for entry in ss for h in entry.get('hooks', [])]
if not any('check-quality.sh' in c for c in ss_cmds):
    print("FAIL: SubagentStop missing check-quality.sh")
    sys.exit(1)

# UserPromptSubmit must dispatch prompt-nudge.sh
ups = hooks.get('UserPromptSubmit', [])
ups_cmds = [h.get('command', '') for entry in ups for h in entry.get('hooks', [])]
if not any('prompt-nudge.sh' in c for c in ups_cmds):
    print("FAIL: UserPromptSubmit missing prompt-nudge.sh")
    sys.exit(1)

print("OK: settings.json valid + SubagentStop(check-quality) + UserPromptSubmit(prompt-nudge) wired")
PY
  then
    pass=$((pass + 1))
  else
    printf "FAIL: settings.json validation failed\n"
    fail=1
  fi
fi

printf -- "---\n"
printf "015-max-quality-doctrine applied — %d/%d checks passed\n" "$pass" "$checks"

# Optional manual smoke tests (documented, not auto-run):
#   (a) Invoke /review with a prompt quoting the doctrine → verify check-quality.sh does NOT self-block
#   (b) Dispatch a throwaway subagent outputting literal "for brevity" → verify check-quality.sh DOES block

# Bootstrap-state advance (only if all hard checks passed)
if [[ $fail -eq 0 ]]; then
  "$PY" - <<'PY'
import json, sys
from datetime import datetime, timezone

path = '.claude/bootstrap-state.json'
with open(path, 'r', encoding='utf-8') as f:
    state = json.load(f)

applied = state.get('applied', [])
already = any(
    (isinstance(a, dict) and a.get('id') == '015') or a == '015'
    for a in applied
)
if already:
    print("SKIP: 015 already in applied[]")
    sys.exit(0)

state['last_migration'] = '015'
applied.append({
    'id': '015',
    'applied_at': datetime.now(timezone.utc).isoformat(),
    'description': 'Max Quality Doctrine — 10-layer defense against output truncation and effort inflation. Creates max-quality.md rule, check-quality.sh SubagentStop hook, prompt-nudge.sh UserPromptSubmit hook, stop-verify.sh extension, settings.json update, technique sync (prompt-engineering + token-efficiency + agent-design), STEP 0 reinforcement across all proj-* agents, token-efficiency Output Carve-Out, Completeness Check § in proj-code-reviewer, calibrated-effort discipline in proj-plan-writer.'
})
state['applied'] = applied

with open(path, 'w', encoding='utf-8') as f:
    json.dump(state, f, indent=2)
    f.write('\n')

print("OK: bootstrap-state.json advanced to last_migration=015")
PY
else
  printf "ABORT: failures detected — bootstrap-state.json NOT advanced\n"
  exit 1
fi
```

---

## Verify

```bash
#!/usr/bin/env bash
set -euo pipefail

fail=0

# Rule file
[[ -f ".claude/rules/max-quality.md" ]] && grep -q '^# Max Quality Doctrine' .claude/rules/max-quality.md \
  && printf "PASS: max-quality.md\n" || { printf "FAIL: max-quality.md\n"; fail=1; }

# Hooks
[[ -x ".claude/hooks/check-quality.sh" ]] && printf "PASS: check-quality.sh executable\n" || { printf "FAIL: check-quality.sh\n"; fail=1; }
[[ -x ".claude/hooks/prompt-nudge.sh" ]] && printf "PASS: prompt-nudge.sh executable\n" || { printf "FAIL: prompt-nudge.sh\n"; fail=1; }
grep -q "MAX QUALITY" .claude/hooks/stop-verify.sh && printf "PASS: stop-verify.sh has MAX QUALITY nudge\n" || { printf "FAIL: stop-verify.sh missing nudge\n"; fail=1; }

# Technique files (client layout — NOT techniques/ at root)
[[ -f ".claude/references/techniques/prompt-engineering.md" ]] && printf "PASS: prompt-engineering.md synced\n" || { printf "FAIL: prompt-engineering.md missing\n"; fail=1; }
[[ -f ".claude/references/techniques/token-efficiency.md" ]] && printf "PASS: token-efficiency.md synced\n" || { printf "FAIL: token-efficiency.md missing\n"; fail=1; }
[[ -f ".claude/references/techniques/agent-design.md" ]] && printf "PASS: agent-design.md synced\n" || { printf "FAIL: agent-design.md missing\n"; fail=1; }

# token-efficiency.md has Output Carve-Out
grep -q "## Output Carve-Out" .claude/rules/token-efficiency.md && printf "PASS: token-efficiency Output Carve-Out\n" || { printf "FAIL: token-efficiency missing Output Carve-Out\n"; fail=1; }

# CLAUDE.md import (conditional)
if [[ -f "CLAUDE.md" ]]; then
  grep -q "@import .claude/rules/max-quality.md" CLAUDE.md \
    && printf "PASS: CLAUDE.md imports max-quality.md\n" || { printf "FAIL: CLAUDE.md missing @import\n"; fail=1; }
fi

# Every proj-* agent has max-quality.md in STEP 0 force-read list
missing_mq=0
total=0
for agent in .claude/agents/proj-*.md; do
  [[ -f "$agent" ]] || continue
  case "$agent" in *references/*) continue ;; esac
  total=$((total + 1))
  if ! grep -q "\.claude/rules/max-quality\.md" "$agent"; then
    printf "  missing max-quality in STEP 0: %s\n" "$agent"
    missing_mq=$((missing_mq + 1))
  fi
done
if [[ $total -gt 0 && $missing_mq -eq 0 ]]; then
  printf "PASS: all %d proj-* agents reference max-quality.md in STEP 0\n" "$total"
elif [[ $total -eq 0 ]]; then
  printf "SKIP: no proj-*.md agents to check\n"
else
  printf "FAIL: %d of %d proj-* agents missing max-quality.md in STEP 0\n" "$missing_mq" "$total"
  fail=1
fi

# settings.json: both hook wirings
PY=""
for cand in python3 python py; do command -v "$cand" >/dev/null 2>&1 && { PY="$cand"; break; }; done
[[ -n "$PY" ]] || { printf "FAIL: no python for settings validation\n"; exit 1; }
"$PY" - <<'PY' || fail=1
import json, sys
with open('.claude/settings.json') as f:
    s = json.load(f)
hooks = s.get('hooks', {})
ss_cmds = [h['command'] for e in hooks.get('SubagentStop', []) for h in e.get('hooks', [])]
ups_cmds = [h['command'] for e in hooks.get('UserPromptSubmit', []) for h in e.get('hooks', [])]
ok = True
if not any('check-quality.sh' in c for c in ss_cmds):
    print("FAIL: SubagentStop missing check-quality.sh"); ok = False
if not any('prompt-nudge.sh' in c for c in ups_cmds):
    print("FAIL: UserPromptSubmit missing prompt-nudge.sh"); ok = False
if ok:
    print("PASS: settings.json hooks wired (SubagentStop + UserPromptSubmit)")
sys.exit(0 if ok else 1)
PY

# bootstrap-state reflects 015
"$PY" - <<'PY' || fail=1
import json, sys
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
if state.get('last_migration') != '015':
    print(f"FAIL: last_migration = {state.get('last_migration')} (expected 015)")
    sys.exit(1)
applied = state.get('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '015') or a == '015' for a in applied):
    print("FAIL: 015 not in applied[]")
    sys.exit(1)
print("PASS: bootstrap-state.json reflects 015")
PY

printf -- "---\n"
[[ $fail -eq 0 ]] && printf "Migration 015 verification: ALL PASS\n" || { printf "Migration 015 verification: FAILURES\n"; exit 1; }
```

---

## State Update

On success:
- `last_migration` → `"015"`
- append `{ "id": "015", "applied_at": "<ISO8601>", "description": "Max Quality Doctrine — 10-layer defense against output truncation and effort inflation. Creates max-quality.md rule, check-quality.sh SubagentStop hook, prompt-nudge.sh UserPromptSubmit hook, stop-verify.sh extension, settings.json update, technique sync (prompt-engineering + token-efficiency + agent-design), STEP 0 reinforcement across all proj-* agents, token-efficiency Output Carve-Out, Completeness Check § in proj-code-reviewer, calibrated-effort discipline in proj-plan-writer." }` to `applied[]`

---

## Rollback

The migration is additive (writes new files, appends sections, inserts lines). No user content deleted. If rollback is required:

```bash
# Tracked strategy
git checkout -- .claude/agents/ .claude/rules/token-efficiency.md .claude/hooks/stop-verify.sh .claude/settings.json CLAUDE.md
rm -f .claude/rules/max-quality.md
rm -f .claude/hooks/check-quality.sh
rm -f .claude/hooks/prompt-nudge.sh
git checkout -- .claude/references/techniques/prompt-engineering.md .claude/references/techniques/token-efficiency.md

# Companion strategy — restore from ~/.claude-configs/{project}/ snapshot
# cp -r ~/.claude-configs/<project>/.claude/ ./
# cp    ~/.claude-configs/<project>/CLAUDE.md ./
```

Then manually reset `last_migration` in `.claude/bootstrap-state.json` to `"014"` and remove the `015` entry from `applied[]`.
