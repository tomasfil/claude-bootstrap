# Migration 039 — Inter-Agent Flow Compression

> Strip skill-routing.md from all agent STEP 0 blocks, strip agent-scope-lock.md from pure-report agents, dedupe legacy MCP STEP 0 prose blocks, add shell-standards.md to proj-tdd-runner, clean allowed-tools in /debug + /review, align AGENT_DISPATCH_POLICY_BLOCK fallback clause with current MCP + orchestrator doctrine.

---

## Metadata

```yaml
id: "039"
breaking: false
affects: [agents, skills]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

Fields:
- `id`: `"039"`
- `breaking`: `false` — subtractive + additive surgical edits to deployed `.claude/agents/*.md` + `.claude/skills/*/SKILL.md` files. Each step is sentinel-guarded; already-applied state SKIPs cleanly; hand-edited variants that do not match the sentinel are reported for manual review, never rewritten blindly. Backups written to `.bak039` on first patch so out-of-band rollback is possible.
- `affects`: `[agents, skills]` — patches `.claude/agents/proj-*.md` (+ `code-writer-*.md`, `test-writer-*.md` sub-specialists) and `.claude/skills/*/SKILL.md` in the deployed client project. Advances `.claude/bootstrap-state.json` → `last_migration: "039"`.
- `requires_mcp_json`: `false` — migration applies regardless of MCP presence. Fix 5c's new AGENT_DISPATCH_POLICY_BLOCK clause references `cmm.search_graph` + `mcp-routing.md` but only activates in contexts where MCP is already wired; the clause text ships to every project.
- `min_bootstrap_version`: `"6.0"` — earliest bootstrap release shipping the `.claude/agents/` + `.claude/skills/` layout this migration patches.

---

## Problem

### Source

Inter-agent flow audit (2026-04-20) graded the system B — structurally sound, but measurable waste across every sub-agent invocation and every session. Reference: `.claude/findings/inter-agent-flow-audit-2026-04-20.md` (audit report), `.claude/specs/main/2026-04-20-inter-agent-flow-compression-spec.md` (approved spec), `.claude/specs/main/2026-04-20-inter-agent-flow-compression-plan.md` (plan).

### Five waste patterns

1. **Universal `skill-routing.md` force-read.** Every sub-agent STEP 0 block force-reads `.claude/rules/skill-routing.md` despite none of them actually routing to skills. Skills are a main-thread concern: the orchestrator classifies requests and dispatches sub-agents, and dispatched sub-agents operate within their listed scope without invoking other skills. Force-reading a ~25-line rule that never applies to the sub-agent's work is a per-invocation per-session tax that compounds across every dispatch.

2. **Pure-report agents force-read `agent-scope-lock.md`.** Four agents (`proj-verifier`, `proj-consistency-checker`, `proj-reflector`, `proj-quick-check`) produce reports rather than editing files — they have no batch-file scope concept to begin with. `agent-scope-lock.md` governs executing/writer agents dispatched via `/execute-plan`, `/tdd`, `/code-write` with a `#### Files` section in their batch/task file. Pure-report agents never touch those constructs. ~35 lines of irrelevant doctrine in every invocation.

3. **Legacy MCP STEP 0 prose block duplication.** A downstream client project carries a DUPLICATE legacy STEP 0 MCP prose block in several agents (pre-doctrine residue from before the canonical STEP 0 MCP routing block stabilized). Two `## STEP 0 — MCP Routing (MANDATORY, before any other work)` headers in the same file: the first is the canonical hook-enforced block, the second is the legacy duplicate. ~130 tokens × multiple agents × every invocation.

4. **proj-tdd-runner missing `shell-standards.md`.** The TDD runner writes all files via Bash heredoc (red-green-refactor cycle with shell-constructed test files + fixtures). Its STEP 0 block force-reads `max-quality.md` + `general.md` + `agent-scope-lock.md` but NOT `shell-standards.md` — the rule that governs `#!/usr/bin/env bash`, `set -euo pipefail`, quoting, `[[ ]]` conditionals, `printf` preference. Missing rule = inconsistent shell output across TDD runs.

5. **Legacy `allowed-tools` + stale AGENT_DISPATCH_POLICY_BLOCK fallback.** A downstream client project has `Grep Glob` in `allowed-tools` for `/debug` and `/review` skills. `allowed-tools` is a pre-approval list per Claude Code spec (not a behavior whitelist — see `https://code.claude.com/docs/en/skills` §Pre-approve tools), so removal does not block Grep/Glob but does (a) remove accidental pre-approval of tools the orchestrator should not need, (b) signal intent consistent with `main-thread-orchestrator.md`, (c) cause a permission prompt on accidental misuse (enforcement via `orchestrator-nudge.sh` from migration 036). Separately, AGENT_DISPATCH_POLICY_BLOCK in all 14 deployed skill bodies contains pre-doctrine residue: `For any code exploration inside this skill: use Read/Grep/Glob directly OR dispatch proj-quick-check... / proj-researcher... — never built-in.` — this line predates three active doctrine layers: (1) `main-thread-orchestrator.md` Tier 2 (investigation → dispatch, never Grep on main), (2) `mcp-routing.md` Grep Ban on named symbols in indexed projects, (3) migration 033's `mcp-discovery-gate.sh` hook that mechanically blocks main-thread Grep on named-type patterns.

### Why a single migration

Each fix is independent — failure of one does not block the others — but all five target the same surface (deployed `.claude/agents/` + `.claude/skills/`) and share the same idempotency discipline (sentinel guard, per-file report, `.bak039` backup, SKIP on already-applied). Bundling into migration 039 matches the factoring: one migration, six independent fix steps (Fix 1, Fix 2, Fix 3, Fix 5a, Fix 5b, Fix 5c), each with its own sentinel + SKIP path. Fix 4 (Risk Classification table backport) is template-only — no migration step — because the deployed target already has the compressed form.

---

## Changes

1. **Fix 1 — strip `skill-routing.md` from every agent STEP 0.** Glob `.claude/agents/proj-*.md` + `.claude/agents/code-writer-*.md` + `.claude/agents/test-writer-*.md`. For each file, if the line `- \`.claude/rules/skill-routing.md\`` exists in the STEP 0 force-read list, delete that exact line. SKIP otherwise (already-applied | hand-edited | never-present). Per-file report: `PATCHED` | `SKIP_ALREADY_APPLIED` | `SKIP_HAND_EDITED`.

2. **Fix 2 — strip `agent-scope-lock.md` from pure-report agents.** Target only `proj-verifier.md`, `proj-consistency-checker.md`, `proj-reflector.md`, `proj-quick-check.md` (glob for these four filenames only). If the line `- \`.claude/rules/agent-scope-lock.md\`` exists, delete it. SKIP otherwise. Per-file report.

3. **Fix 3 — dedupe legacy MCP STEP 0 prose block.** Glob `.claude/agents/proj-*.md` + `.claude/agents/code-writer-*.md` + `.claude/agents/test-writer-*.md`. For each file, detect the SECOND occurrence of `## STEP 0 — MCP Routing (MANDATORY, before any other work)` (first is canonical, second is legacy duplicate). If both occurrences found AND the canonical STEP 0 Read block (containing `Before any task-specific work, Read these rule files`) is present elsewhere in the file, slice from the second header through the next `---` separator inclusive and rewrite. Safety gate: require BOTH canonical header AND second legacy header before touching; if only one found → SKIP. Per-file report.

4. **Fix 5a — add `shell-standards.md` to proj-tdd-runner STEP 0.** Target `.claude/agents/proj-tdd-runner.md`. If line `- \`.claude/rules/shell-standards.md\`` already present → SKIP. Otherwise insert the line immediately after the line containing `max-quality.md (doctrine`. If anchor line missing → FAIL_ANCHOR_MISSING (report manual-patch message, continue; other fixes unaffected).

5. **Fix 5b — clean `allowed-tools:` in `/debug` + `/review` skills.** Target `.claude/skills/debug/SKILL.md` and `.claude/skills/review/SKILL.md`. For each file, locate the `allowed-tools:` YAML frontmatter line. If it contains `Grep` OR `Glob`, rewrite to exactly `allowed-tools: Agent Read Write`. SKIP otherwise. Per-skill report.

6. **Fix 5c — rewrite AGENT_DISPATCH_POLICY_BLOCK fallback clause.** Glob every `.claude/skills/*/SKILL.md` (skip `.bak*` backup directories). For each file, if the exact legacy clause is present, replace with the new clause that aligns with Tier 1 Read discipline + MCP-indexed cmm.search_graph routing + no-built-in doctrine. SKIP if legacy clause absent (already-applied | hand-edited | never-present). No anchor drift tolerance — exact legacy string match required; hand-edited variants reported for manual review.

7. **Advance `.claude/bootstrap-state.json`** → `last_migration: "039"` + append entry to `applied[]` with ISO8601 UTC timestamp and description.

### Idempotency table

| Step | Sentinel (per target file) | Skip condition |
|---|---|---|
| 2 (Fix 1) | `grep -qF '- \`.claude/rules/skill-routing.md\`' <file>` | Line not present → already stripped or never had it. |
| 3 (Fix 2) | `grep -qF '- \`.claude/rules/agent-scope-lock.md\`' <file>` | Line not present. |
| 4 (Fix 3) | Two `## STEP 0 — MCP Routing (MANDATORY, before any other work)` headers AND canonical Read block present | Only one STEP 0 MCP header → already deduped or never duplicated. |
| 5 (Fix 5a) | `grep -qF '- \`.claude/rules/shell-standards.md\`' .claude/agents/proj-tdd-runner.md` | Line already present. |
| 6 (Fix 5b) | `allowed-tools:` line contains `Grep` or `Glob` | Already clean. |
| 7 (Fix 5c) | `grep -qF 'use Read/Grep/Glob directly OR dispatch' <file>` | Legacy clause absent → already patched or hand-edited. |
| 8 (state) | `039` already in `applied[]` in `.claude/bootstrap-state.json` | State already advanced. |

Running twice is safe — every step prints `SKIP:` for the already-applied path and exits 0. Per-step `|| true` after the report ensures one step's SKIP does not short-circuit the remaining steps.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { printf "ERROR: not a bootstrapped project — run full bootstrap first\n"; exit 1; }
[[ -d ".claude/agents" ]]                || { printf "ERROR: .claude/agents/ missing — run full bootstrap first\n"; exit 1; }
[[ -d ".claude/skills" ]]                || { printf "ERROR: .claude/skills/ missing — run full bootstrap first\n"; exit 1; }
command -v python3 >/dev/null 2>&1       || { printf "ERROR: python3 required\n"; exit 1; }
printf "OK: prerequisites satisfied\n"
```

---

### Step 1 — Prerequisite gate + already-applied detection

Require `bootstrap-state.json` present; require `last_migration >= "033"` (First-Tool Contract clause from migration 033 is a prerequisite for the Fix 3 safety gate); SKIP the entire migration if `039` is already in `applied[]`.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
import sys

STATE_FILE = ".claude/bootstrap-state.json"
with open(STATE_FILE, "r", encoding="utf-8") as f:
    state = json.load(f)

applied = state.get("applied", [])
ids_applied = set()
for a in applied:
    if isinstance(a, dict):
        ids_applied.add(a.get("id", ""))
    elif isinstance(a, str):
        ids_applied.add(a)

if "039" in ids_applied:
    print("SKIP_MIGRATION: 039 already in applied[] — nothing to do")
    sys.exit(0)

last = state.get("last_migration", "000")
try:
    last_int = int(last)
except Exception:
    last_int = 0

if last_int < 33:
    print(f"ERROR: last_migration={last!r} < 033 — migration 039 requires First-Tool Contract from migration 033 as prerequisite")
    sys.exit(1)

print(f"GATE OK: last_migration={last!r}, 039 not yet applied — proceeding")
PY
```

---

### Step 2 — Fix 1: strip `skill-routing.md` from every agent STEP 0

Glob all `proj-*.md`, `code-writer-*.md`, `test-writer-*.md` agents. Per-file sentinel check + `sed -i.bak039` delete of the exact line. Per-file report.

```bash
#!/usr/bin/env bash
set -euo pipefail

SENTINEL_LINE='- `.claude/rules/skill-routing.md`'
PATCHED=0
SKIPPED=0

shopt -s nullglob
agents=( .claude/agents/proj-*.md .claude/agents/code-writer-*.md .claude/agents/test-writer-*.md )
shopt -u nullglob

if [[ ${#agents[@]} -eq 0 ]]; then
  printf "Fix 1: no target agent files found — SKIP entire step\n"
  exit 0
fi

for agent in "${agents[@]}"; do
  [[ -f "$agent" ]] || continue
  if grep -qF "$SENTINEL_LINE" "$agent" 2>/dev/null; then
    # Write .bak039 once on first patch; sed -i.bak039 handles this atomically
    python3 - "$agent" <<'PY'
import sys
path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    content = f.read()
# .bak039 backup
import os
bak = path + ".bak039"
if not os.path.exists(bak):
    with open(bak, "w", encoding="utf-8") as b:
        b.write(content)
# Delete the exact sentinel line (keeps whole line + its trailing newline)
sentinel = '- `.claude/rules/skill-routing.md`'
lines = content.splitlines(keepends=True)
out = []
removed = False
for ln in lines:
    # Strip the line whose non-newline content equals the sentinel exactly
    if ln.rstrip("\r\n") == sentinel and not removed:
        removed = True
        continue
    out.append(ln)
if not removed:
    print(f"SKIP_NO_MATCH: {path}")
    sys.exit(0)
with open(path, "w", encoding="utf-8") as f:
    f.writelines(out)
print(f"PATCHED: {path}")
PY
    PATCHED=$((PATCHED + 1)) || true
  else
    printf "SKIP_ALREADY_APPLIED: %s\n" "$agent"
    SKIPPED=$((SKIPPED + 1)) || true
  fi
done

printf "Fix 1 summary: PATCHED=%d SKIPPED=%d TOTAL=%d\n" "$PATCHED" "$SKIPPED" "${#agents[@]}"
```

---

### Step 3 — Fix 2: strip `agent-scope-lock.md` from pure-report agents

Target only four agents. Per-file sentinel + delete.

```bash
#!/usr/bin/env bash
set -euo pipefail

SENTINEL_LINE='- `.claude/rules/agent-scope-lock.md`'
PATCHED=0
SKIPPED=0
MISSING=0

# Pure-report agent set — fixed list, not a glob pattern
TARGETS=(
  ".claude/agents/proj-verifier.md"
  ".claude/agents/proj-consistency-checker.md"
  ".claude/agents/proj-reflector.md"
  ".claude/agents/proj-quick-check.md"
)

for agent in "${TARGETS[@]}"; do
  if [[ ! -f "$agent" ]]; then
    printf "SKIP_MISSING: %s (agent file not present)\n" "$agent"
    MISSING=$((MISSING + 1)) || true
    continue
  fi
  if grep -qF "$SENTINEL_LINE" "$agent" 2>/dev/null; then
    python3 - "$agent" <<'PY'
import sys, os
path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    content = f.read()
bak = path + ".bak039"
if not os.path.exists(bak):
    with open(bak, "w", encoding="utf-8") as b:
        b.write(content)
sentinel = '- `.claude/rules/agent-scope-lock.md`'
lines = content.splitlines(keepends=True)
out = []
removed = False
for ln in lines:
    if ln.rstrip("\r\n") == sentinel and not removed:
        removed = True
        continue
    out.append(ln)
if not removed:
    print(f"SKIP_NO_MATCH: {path}")
    sys.exit(0)
with open(path, "w", encoding="utf-8") as f:
    f.writelines(out)
print(f"PATCHED: {path}")
PY
    PATCHED=$((PATCHED + 1)) || true
  else
    printf "SKIP_ALREADY_APPLIED: %s\n" "$agent"
    SKIPPED=$((SKIPPED + 1)) || true
  fi
done

printf "Fix 2 summary: PATCHED=%d SKIPPED=%d MISSING=%d\n" "$PATCHED" "$SKIPPED" "$MISSING"
```

---

### Step 4 — Fix 3: dedupe legacy MCP STEP 0 prose block

Glob all `proj-*.md`, `code-writer-*.md`, `test-writer-*.md` agents. Use python3 to detect the SECOND occurrence of the STEP 0 MCP Routing header line, verify the canonical Read block exists elsewhere in the file, slice from the second header through the next `---` separator inclusive, rewrite the file. Safety gate: require BOTH canonical Read block AND second legacy header before touching; if only one is found → SKIP (preserves idempotency + prevents miscounting hand-edited files). No action taken on files that do not match both conditions.

```bash
#!/usr/bin/env bash
set -euo pipefail

PATCHED=0
SKIPPED=0

shopt -s nullglob
agents=( .claude/agents/proj-*.md .claude/agents/code-writer-*.md .claude/agents/test-writer-*.md )
shopt -u nullglob

if [[ ${#agents[@]} -eq 0 ]]; then
  printf "Fix 3: no target agent files found — SKIP entire step\n"
  exit 0
fi

for agent in "${agents[@]}"; do
  [[ -f "$agent" ]] || continue
  result=$(python3 - "$agent" <<'PY'
import sys
import os

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

LEGACY_HEADER = "## STEP 0 — MCP Routing (MANDATORY, before any other work)"
CANONICAL_MARKER = "Before any task-specific work, Read these rule files"

# Locate all occurrences of the header line
lines = content.splitlines(keepends=False)
header_idxs = [i for i, ln in enumerate(lines) if ln.strip() == LEGACY_HEADER]

# Detect canonical Read block presence
canonical_present = CANONICAL_MARKER in content

# Safety gate: require BOTH the canonical Read block AND a SECOND legacy header.
# If only one header found OR canonical absent → SKIP (idempotent: already deduped,
# never duplicated, or hand-edited to non-canonical shape).
if len(header_idxs) < 2 or not canonical_present:
    print("SKIP_NO_DUPLICATE")
    sys.exit(0)

# Second header is the legacy duplicate. Slice from second header index to the
# next line that is exactly '---' (inclusive of both endpoints).
second_idx = header_idxs[1]
end_idx = None
for j in range(second_idx + 1, len(lines)):
    if lines[j].strip() == "---":
        end_idx = j
        break

if end_idx is None:
    # Malformed: legacy header without trailing --- separator. SKIP for manual review.
    print("SKIP_NO_SEPARATOR")
    sys.exit(0)

# Backup before mutating
bak = path + ".bak039"
if not os.path.exists(bak):
    with open(bak, "w", encoding="utf-8") as b:
        b.write(content)

# Remove lines [second_idx .. end_idx] inclusive.
# Also strip one surrounding blank line on either side if present, to avoid
# leaving a double-blank hole. Pattern typically is: blank, header, ..., ---, blank.
start = second_idx
end = end_idx + 1  # exclusive in Python slice

# Consume trailing blank line after the --- if present
while end < len(lines) and lines[end].strip() == "":
    end += 1
    # Only consume at most one trailing blank line — stop at first non-blank
    break

# Consume leading blank line before the legacy header if present
while start > 0 and lines[start - 1].strip() == "":
    start -= 1
    break

new_lines = lines[:start] + lines[end:]
new_content = "\n".join(new_lines)
if content.endswith("\n"):
    new_content += "\n"

with open(path, "w", encoding="utf-8") as f:
    f.write(new_content)

print("PATCHED")
PY
)
  case "$result" in
    PATCHED)
      printf "PATCHED: %s (legacy MCP STEP 0 block removed)\n" "$agent"
      PATCHED=$((PATCHED + 1)) || true
      ;;
    SKIP_NO_DUPLICATE)
      printf "SKIP_ALREADY_APPLIED: %s (single STEP 0 MCP header, already clean)\n" "$agent"
      SKIPPED=$((SKIPPED + 1)) || true
      ;;
    SKIP_NO_SEPARATOR)
      printf "SKIP_HAND_EDITED: %s (legacy header present but no --- separator; manual review recommended)\n" "$agent"
      SKIPPED=$((SKIPPED + 1)) || true
      ;;
    *)
      printf "SKIP_UNKNOWN: %s (result=%s)\n" "$agent" "$result"
      SKIPPED=$((SKIPPED + 1)) || true
      ;;
  esac
done

printf "Fix 3 summary: PATCHED=%d SKIPPED=%d TOTAL=%d\n" "$PATCHED" "$SKIPPED" "${#agents[@]}"
```

---

### Step 5 — Fix 5a: add `shell-standards.md` to proj-tdd-runner STEP 0

Target `.claude/agents/proj-tdd-runner.md`. Sentinel-check for the `shell-standards.md` line; SKIP if already present. Otherwise anchor-insert after the line containing `max-quality.md (doctrine`. If anchor missing → report manual-patch message, continue.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/agents/proj-tdd-runner.md"
SENTINEL='- `.claude/rules/shell-standards.md`'
ANCHOR_SUBSTR='max-quality.md (doctrine'

if [[ ! -f "$TARGET" ]]; then
  printf "SKIP_MISSING: %s (file not present — Fix 5a not applicable)\n" "$TARGET"
  exit 0
fi

if grep -qF "$SENTINEL" "$TARGET" 2>/dev/null; then
  printf "SKIP_ALREADY_APPLIED: %s (shell-standards.md already present)\n" "$TARGET"
  exit 0
fi

python3 - "$TARGET" <<'PY'
import sys
import os

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

ANCHOR_SUBSTR = "max-quality.md (doctrine"
NEW_LINE = "- `.claude/rules/shell-standards.md`"

lines = content.splitlines(keepends=False)

# Locate anchor line — first occurrence wins
anchor_idx = -1
for i, ln in enumerate(lines):
    if ANCHOR_SUBSTR in ln:
        anchor_idx = i
        break

if anchor_idx < 0:
    print("FAIL_ANCHOR_MISSING: max-quality.md (doctrine ...) anchor not found in proj-tdd-runner.md")
    print("  Action required: manually add line to STEP 0 force-read block:")
    print(f"    {NEW_LINE}")
    sys.exit(0)

# Preserve original indentation of the anchor line (list-item marker placement)
anchor_line = lines[anchor_idx]
leading_ws = ""
for ch in anchor_line:
    if ch in (" ", "\t"):
        leading_ws += ch
    else:
        break
insert_line = f"{leading_ws}{NEW_LINE}"

# Backup
bak = path + ".bak039"
if not os.path.exists(bak):
    with open(bak, "w", encoding="utf-8") as b:
        b.write(content)

new_lines = lines[: anchor_idx + 1] + [insert_line] + lines[anchor_idx + 1 :]
new_content = "\n".join(new_lines)
if content.endswith("\n"):
    new_content += "\n"

with open(path, "w", encoding="utf-8") as f:
    f.write(new_content)

print(f"PATCHED: {path} (shell-standards.md inserted after line {anchor_idx + 1})")
PY
```

---

### Step 6 — Fix 5b: clean `allowed-tools:` in `/debug` + `/review` skills

For each of the two target skills, locate the `allowed-tools:` YAML frontmatter line. If it contains `Grep` OR `Glob`, rewrite to exactly `allowed-tools: Agent Read Write`. SKIP if the line does not contain either.

```bash
#!/usr/bin/env bash
set -euo pipefail

PATCHED=0
SKIPPED=0
MISSING=0

TARGETS=(
  ".claude/skills/debug/SKILL.md"
  ".claude/skills/review/SKILL.md"
)

for skill in "${TARGETS[@]}"; do
  if [[ ! -f "$skill" ]]; then
    printf "SKIP_MISSING: %s (skill file not present)\n" "$skill"
    MISSING=$((MISSING + 1)) || true
    continue
  fi
  result=$(python3 - "$skill" <<'PY'
import sys
import os

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

lines = content.splitlines(keepends=False)
if not lines or lines[0].strip() != "---":
    print("SKIP_NO_FRONTMATTER")
    sys.exit(0)

# Locate closing '---' for the frontmatter
fm_end = -1
for i in range(1, len(lines)):
    if lines[i].strip() == "---":
        fm_end = i
        break
if fm_end < 0:
    print("SKIP_MALFORMED_FRONTMATTER")
    sys.exit(0)

# Locate allowed-tools: line inside the frontmatter
at_idx = -1
for i in range(1, fm_end):
    if lines[i].lstrip().startswith("allowed-tools:"):
        at_idx = i
        break

if at_idx < 0:
    print("SKIP_NO_ALLOWED_TOOLS")
    sys.exit(0)

current = lines[at_idx]
# Only patch if line contains Grep or Glob as a whole word in the tool list
# (skill spec: space-separated list after 'allowed-tools:')
after_colon = current.split(":", 1)[1] if ":" in current else ""
tokens = after_colon.split()
has_grep = "Grep" in tokens
has_glob = "Glob" in tokens

if not has_grep and not has_glob:
    print("SKIP_ALREADY_CLEAN")
    sys.exit(0)

# Backup
bak = path + ".bak039"
if not os.path.exists(bak):
    with open(bak, "w", encoding="utf-8") as b:
        b.write(content)

# Preserve original leading whitespace on the allowed-tools line
leading_ws = ""
for ch in current:
    if ch in (" ", "\t"):
        leading_ws += ch
    else:
        break

lines[at_idx] = f"{leading_ws}allowed-tools: Agent Read Write"

new_content = "\n".join(lines)
if content.endswith("\n"):
    new_content += "\n"

with open(path, "w", encoding="utf-8") as f:
    f.write(new_content)

print("PATCHED")
PY
)
  case "$result" in
    PATCHED)
      printf "PATCHED: %s (allowed-tools rewritten to: Agent Read Write)\n" "$skill"
      PATCHED=$((PATCHED + 1)) || true
      ;;
    SKIP_ALREADY_CLEAN)
      printf "SKIP_ALREADY_APPLIED: %s (allowed-tools has no Grep or Glob)\n" "$skill"
      SKIPPED=$((SKIPPED + 1)) || true
      ;;
    SKIP_NO_FRONTMATTER|SKIP_MALFORMED_FRONTMATTER|SKIP_NO_ALLOWED_TOOLS)
      printf "SKIP_HAND_EDITED: %s (result=%s; manual review recommended)\n" "$skill" "$result"
      SKIPPED=$((SKIPPED + 1)) || true
      ;;
    *)
      printf "SKIP_UNKNOWN: %s (result=%s)\n" "$skill" "$result"
      SKIPPED=$((SKIPPED + 1)) || true
      ;;
  esac
done

printf "Fix 5b summary: PATCHED=%d SKIPPED=%d MISSING=%d\n" "$PATCHED" "$SKIPPED" "$MISSING"
```

---

### Step 7 — Fix 5c: rewrite AGENT_DISPATCH_POLICY_BLOCK fallback clause in deployed skills

Glob every `.claude/skills/*/SKILL.md`. For each file, check for the exact legacy fallback clause. If present → replace with the new clause. If absent → SKIP (already-patched | hand-edited | never-present). Exact-string match required; no anchor drift tolerance. After replacement, verify the `NEVER substitute built-in` sentinel remains (regression guard against over-strip).

The legacy and new clauses are embedded verbatim as Python string literals to avoid any shell quoting ambiguity with backticks, pipes, and em-dashes.

```bash
#!/usr/bin/env bash
set -euo pipefail

PATCHED=0
SKIPPED=0

shopt -s nullglob
skills=( .claude/skills/*/SKILL.md )
shopt -u nullglob

if [[ ${#skills[@]} -eq 0 ]]; then
  printf "Fix 5c: no skill files found — SKIP entire step\n"
  exit 0
fi

for skill in "${skills[@]}"; do
  [[ -f "$skill" ]] || continue
  result=$(python3 - "$skill" <<'PY'
import sys
import os

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

LEGACY = "For any code exploration inside this skill: use Read/Grep/Glob directly OR dispatch `proj-quick-check` (simple) / `proj-researcher` (deep) — never built-in."
NEW = "For any code exploration inside this skill: dispatch `proj-quick-check` (simple) | `proj-researcher` (deep). Read directly ONLY for known exact path (Tier 1 per main-thread-orchestrator.md). MCP-indexed projects: named-symbol lookups MUST go through cmm.search_graph (see mcp-routing.md). Never built-in `Explore` / `general-purpose` / plugin."
SENTINEL = "NEVER substitute built-in"

if LEGACY not in content:
    print("SKIP_NO_LEGACY")
    sys.exit(0)

# Backup
bak = path + ".bak039"
if not os.path.exists(bak):
    with open(bak, "w", encoding="utf-8") as b:
        b.write(content)

new_content = content.replace(LEGACY, NEW)

# Regression guard: sentinel must still be present after replacement (unchanged text)
if SENTINEL not in new_content:
    print("FAIL_SENTINEL_LOST")
    sys.exit(0)

with open(path, "w", encoding="utf-8") as f:
    f.write(new_content)

print("PATCHED")
PY
)
  case "$result" in
    PATCHED)
      printf "PATCHED: %s (AGENT_DISPATCH_POLICY_BLOCK fallback clause rewritten)\n" "$skill"
      PATCHED=$((PATCHED + 1)) || true
      ;;
    SKIP_NO_LEGACY)
      printf "SKIP_ALREADY_APPLIED: %s (legacy clause not present)\n" "$skill"
      SKIPPED=$((SKIPPED + 1)) || true
      ;;
    FAIL_SENTINEL_LOST)
      printf "FAIL_SENTINEL_LOST: %s (NEVER substitute built-in sentinel missing after replace — manual review required)\n" "$skill"
      SKIPPED=$((SKIPPED + 1)) || true
      ;;
    *)
      printf "SKIP_UNKNOWN: %s (result=%s)\n" "$skill" "$result"
      SKIPPED=$((SKIPPED + 1)) || true
      ;;
  esac
done

printf "Fix 5c summary: PATCHED=%d SKIPPED=%d TOTAL=%d\n" "$PATCHED" "$SKIPPED" "${#skills[@]}"
```

---

### Step 8 — Advance `.claude/bootstrap-state.json`

Append entry to `applied[]`, set `last_migration` to `"039"`. Atomic write via `tempfile.mkstemp` + `os.replace` to prevent partial-write corruption.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
import os
import tempfile
from datetime import datetime, timezone

STATE_FILE = ".claude/bootstrap-state.json"
with open(STATE_FILE, "r", encoding="utf-8") as f:
    state = json.load(f)

applied = state.get("applied", [])
already = any(
    (isinstance(a, dict) and a.get("id") == "039") or a == "039"
    for a in applied
)
if already:
    print("SKIP: 039 already in applied[]")
else:
    applied.append({
        "id": "039",
        "applied_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "description": "Inter-agent flow compression — strip skill-routing.md from agent STEP 0 blocks (Fix 1), strip agent-scope-lock.md from pure-report agents (Fix 2), dedupe legacy MCP STEP 0 prose block (Fix 3), add shell-standards.md to proj-tdd-runner (Fix 5a), clean allowed-tools in /debug + /review (Fix 5b), rewrite AGENT_DISPATCH_POLICY_BLOCK fallback clause in deployed skills (Fix 5c)"
    })
    state["applied"] = applied
    state["last_migration"] = "039"

    target_dir = os.path.dirname(os.path.abspath(STATE_FILE))
    fd, tmpname = tempfile.mkstemp(prefix=".bootstrap-state.", suffix=".json.tmp", dir=target_dir)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as tmp:
            json.dump(state, tmp, indent=2)
            tmp.write("\n")
        os.replace(tmpname, STATE_FILE)
    except Exception:
        if os.path.exists(tmpname):
            os.unlink(tmpname)
        raise
    print("ADVANCED: bootstrap-state.json last_migration=039")
PY
```

---

### Rules for migration scripts

- **`set -euo pipefail`** at the top of every bash block.
- **Glob agent + skill filenames** — never hardcode `proj-code-writer-csharp.md` etc. Use `shopt -s nullglob` before the glob expansion so an empty-match does not trigger pathname failure.
- **Read-before-write** on every modification — every python3 patcher reads the file content, checks the sentinel/anchor, and only writes when the patch is warranted.
- **Idempotent** — every mutating step has a sentinel-guarded SKIP path (line presence, duplicate-header presence, legacy-clause presence, applied[] membership). Running the migration twice produces the same result.
- **`.bak039` backups on first patch only** — each python3 patcher writes `path + ".bak039"` only if the backup does not already exist. Subsequent re-runs preserve the original pre-migration content untouched.
- **Per-file / per-skill report** — every step emits one of `PATCHED` | `SKIP_ALREADY_APPLIED` | `SKIP_HAND_EDITED` | `SKIP_MISSING` | `SKIP_NO_DUPLICATE` | `SKIP_NO_SEPARATOR` | `SKIP_NO_LEGACY` | `FAIL_ANCHOR_MISSING` | `FAIL_SENTINEL_LOST` per target + a summary line per step.
- **Failure of one step does NOT block others** — steps 2–7 each operate on their own target set with their own sentinel. A SKIP or FAIL on one step does not short-circuit the remaining steps. Per-step `|| true` patterns around the report accumulator prevent `set -e` from aborting on non-zero increment edge cases.
- **Fix 3 safety gate** — the dedupe step requires BOTH the canonical STEP 0 Read block (containing `Before any task-specific work, Read these rule files`) AND a SECOND occurrence of the STEP 0 MCP Routing header before touching the file. If either condition fails, the step SKIPs — preserving idempotency and preventing miscounting on hand-edited files.
- **Fix 5c exact-string match** — no anchor drift tolerance. The legacy clause is a 183-character string with backticks, pipes, and em-dashes; any hand-edit that altered one character skips cleanly rather than rewriting unintended content.
- **Atomic state write** — Step 8 writes `bootstrap-state.json` via `tempfile.mkstemp` + `os.replace` to prevent partial-write corruption on mid-write crash.
- **No `migrations/index.json` touch from migration body** — the index.json append is a separate main-thread step performed outside this migration file (per agent-scope-lock discipline + general.md Process rule).

### Required: register in migrations/index.json

Every migration file MUST have a matching entry in `migrations/index.json`. This registration is performed as a main-thread step in the originating spec, not by the migration body.

Entry to add:

```json
{
  "id": "039",
  "file": "039-inter-agent-flow-compression.md",
  "description": "Inter-agent flow compression — strip skill-routing.md from agent STEP 0 blocks, strip agent-scope-lock.md from pure-report agents, dedupe legacy MCP STEP 0 prose blocks, add shell-standards.md to proj-tdd-runner, clean allowed-tools in /debug + /review, rewrite AGENT_DISPATCH_POLICY_BLOCK fallback clause",
  "breaking": false
}
```

---

## Verify

```bash
#!/usr/bin/env bash
set -euo pipefail

# (a) no remaining skill-routing.md force-read line in .claude/agents/*.md
shopt -s nullglob
agents_all=( .claude/agents/proj-*.md .claude/agents/code-writer-*.md .claude/agents/test-writer-*.md )
shopt -u nullglob
fail_a=0
for agent in "${agents_all[@]}"; do
  if grep -qF '- `.claude/rules/skill-routing.md`' "$agent" 2>/dev/null; then
    printf "FAIL (a): %s still contains skill-routing.md force-read line\n" "$agent"
    fail_a=1
  fi
done
[[ $fail_a -eq 0 ]] && printf "VERIFY (a): no remaining skill-routing.md in agent STEP 0 blocks\n"

# (b) no remaining agent-scope-lock.md line in the 4 pure-report agents
pure_report=(
  ".claude/agents/proj-verifier.md"
  ".claude/agents/proj-consistency-checker.md"
  ".claude/agents/proj-reflector.md"
  ".claude/agents/proj-quick-check.md"
)
fail_b=0
for agent in "${pure_report[@]}"; do
  [[ -f "$agent" ]] || continue
  if grep -qF '- `.claude/rules/agent-scope-lock.md`' "$agent" 2>/dev/null; then
    printf "FAIL (b): %s still contains agent-scope-lock.md force-read line\n" "$agent"
    fail_b=1
  fi
done
[[ $fail_b -eq 0 ]] && printf "VERIFY (b): no remaining agent-scope-lock.md in pure-report agents\n"

# (c) no file has TWO ## STEP 0 — MCP Routing (MANDATORY, before any other work) headers
fail_c=0
for agent in "${agents_all[@]}"; do
  count=$(grep -cF '## STEP 0 — MCP Routing (MANDATORY, before any other work)' "$agent" 2>/dev/null || printf "0")
  if [[ "$count" -gt 1 ]]; then
    printf "FAIL (c): %s has %d STEP 0 MCP Routing headers (expected <=1)\n" "$agent" "$count"
    fail_c=1
  fi
done
[[ $fail_c -eq 0 ]] && printf "VERIFY (c): no duplicate STEP 0 MCP Routing headers\n"

# (d) proj-tdd-runner STEP 0 contains shell-standards.md
if [[ -f ".claude/agents/proj-tdd-runner.md" ]]; then
  if grep -qF '- `.claude/rules/shell-standards.md`' .claude/agents/proj-tdd-runner.md; then
    printf "VERIFY (d): proj-tdd-runner.md contains shell-standards.md force-read line\n"
  else
    printf "FAIL (d): proj-tdd-runner.md missing shell-standards.md force-read line\n"
    exit 1
  fi
else
  printf "VERIFY (d): proj-tdd-runner.md not present — SKIP (Fix 5a not applicable)\n"
fi

# (e) /debug + /review allowed-tools = exactly 'Agent Read Write'
fail_e=0
for skill in ".claude/skills/debug/SKILL.md" ".claude/skills/review/SKILL.md"; do
  [[ -f "$skill" ]] || { printf "VERIFY (e): %s not present — SKIP\n" "$skill"; continue; }
  at_line=$(awk '/^---[[:space:]]*$/{c++; next} c==1 && /^allowed-tools:/{print; exit}' "$skill" || true)
  if [[ "$at_line" != "allowed-tools: Agent Read Write" ]]; then
    printf "FAIL (e): %s allowed-tools line is %q — expected 'allowed-tools: Agent Read Write'\n" "$skill" "$at_line"
    fail_e=1
  fi
done
[[ $fail_e -eq 0 ]] && printf "VERIFY (e): /debug + /review allowed-tools clean\n"

# (f) every proj-*.md STEP 0 still contains the First-Tool Contract clause from migration 033
fail_f=0
shopt -s nullglob
proj_agents=( .claude/agents/proj-*.md )
shopt -u nullglob
for agent in "${proj_agents[@]}"; do
  if ! grep -qF 'First-Tool Contract' "$agent" 2>/dev/null; then
    printf "FAIL (f): %s missing First-Tool Contract clause (migration 033 regression)\n" "$agent"
    fail_f=1
  fi
done
[[ $fail_f -eq 0 ]] && printf "VERIFY (f): First-Tool Contract clause preserved in all proj-*.md\n"

# (g) every proj-*.md still has exactly ONE ## STEP 0 header (regression guard against over-strip)
fail_g=0
for agent in "${proj_agents[@]}"; do
  count=$(grep -cE '^## STEP 0' "$agent" 2>/dev/null || printf "0")
  if [[ "$count" -ne 1 ]]; then
    printf "FAIL (g): %s has %d STEP 0 headers (expected exactly 1)\n" "$agent" "$count"
    fail_g=1
  fi
done
[[ $fail_g -eq 0 ]] && printf "VERIFY (g): every proj-*.md has exactly one STEP 0 header\n"

# (h) no .claude/skills/*/SKILL.md contains the legacy clause `use Read/Grep/Glob directly OR dispatch`
fail_h=0
shopt -s nullglob
all_skills=( .claude/skills/*/SKILL.md )
shopt -u nullglob
for skill in "${all_skills[@]}"; do
  if grep -qF 'use Read/Grep/Glob directly OR dispatch' "$skill" 2>/dev/null; then
    printf "FAIL (h): %s still contains legacy AGENT_DISPATCH_POLICY_BLOCK fallback clause\n" "$skill"
    fail_h=1
  fi
done
[[ $fail_h -eq 0 ]] && printf "VERIFY (h): no skill retains legacy fallback clause\n"

# (i) every skill that had AGENT_DISPATCH_POLICY_BLOCK still has the NEVER substitute built-in sentinel
fail_i=0
for skill in "${all_skills[@]}"; do
  if grep -qF 'AGENT_DISPATCH_POLICY_BLOCK' "$skill" 2>/dev/null; then
    if ! grep -qF 'NEVER substitute built-in' "$skill" 2>/dev/null; then
      printf "FAIL (i): %s has AGENT_DISPATCH_POLICY_BLOCK but lost 'NEVER substitute built-in' sentinel\n" "$skill"
      fail_i=1
    fi
  fi
done
[[ $fail_i -eq 0 ]] && printf "VERIFY (i): AGENT_DISPATCH_POLICY_BLOCK sentinel preserved in all patched skills\n"

# State check — last_migration advanced to 039
python3 -c '
import json
s = json.load(open(".claude/bootstrap-state.json"))
assert s["last_migration"] == "039", f"last_migration={s[\"last_migration\"]}, expected 039"
assert any((isinstance(a, dict) and a.get("id") == "039") or a == "039" for a in s.get("applied", [])), "039 missing from applied[]"
print("VERIFY (state): bootstrap-state.json advanced to 039")
'
```

Failure of any verify check → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after fixing.

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → `"039"`
- append `{ "id": "039", "applied_at": "{ISO8601}", "description": "Inter-agent flow compression — strip skill-routing.md from agent STEP 0 blocks (Fix 1), strip agent-scope-lock.md from pure-report agents (Fix 2), dedupe legacy MCP STEP 0 prose block (Fix 3), add shell-standards.md to proj-tdd-runner (Fix 5a), clean allowed-tools in /debug + /review (Fix 5b), rewrite AGENT_DISPATCH_POLICY_BLOCK fallback clause in deployed skills (Fix 5c)" }` to `applied[]`

---

## Rollback

Rollback-able via per-file `.bak039` backups written on first patch in each step OR via `git restore` on any tracked file.

### Option A — restore from `.bak039` backups (out-of-band, works on gitignored paths)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Restore any agent file from its .bak039 backup
shopt -s nullglob
for bak in .claude/agents/*.bak039 .claude/skills/*/*.bak039; do
  [[ -f "$bak" ]] || continue
  original="${bak%.bak039}"
  cp -f "$bak" "$original"
  printf "RESTORED: %s <- %s\n" "$original" "$bak"
done
shopt -u nullglob

# Revert bootstrap-state.json applied[] entry for 039 (manual JSON edit)
python3 - <<'PY'
import json
import os
import tempfile

STATE_FILE = ".claude/bootstrap-state.json"
with open(STATE_FILE, "r", encoding="utf-8") as f:
    state = json.load(f)

applied = state.get("applied", [])
before = len(applied)
applied = [a for a in applied if not ((isinstance(a, dict) and a.get("id") == "039") or a == "039")]
if len(applied) < before:
    state["applied"] = applied
    # Reset last_migration to the highest remaining id
    ids = []
    for a in applied:
        if isinstance(a, dict):
            ids.append(a.get("id", "000"))
        elif isinstance(a, str):
            ids.append(a)
    try:
        state["last_migration"] = max(ids, key=lambda x: int(x)) if ids else "000"
    except Exception:
        state["last_migration"] = ids[-1] if ids else "000"

    target_dir = os.path.dirname(os.path.abspath(STATE_FILE))
    fd, tmpname = tempfile.mkstemp(prefix=".bootstrap-state.", suffix=".json.tmp", dir=target_dir)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as tmp:
            json.dump(state, tmp, indent=2)
            tmp.write("\n")
        os.replace(tmpname, STATE_FILE)
    except Exception:
        if os.path.exists(tmpname):
            os.unlink(tmpname)
        raise
    print(f"REVERTED: bootstrap-state.json last_migration={state['last_migration']!r}")
else:
    print("SKIP: 039 not in applied[]")
PY

# Optional: clean up .bak039 files after restore
# shopt -s nullglob
# for bak in .claude/agents/*.bak039 .claude/skills/*/*.bak039; do rm -f "$bak"; done
# shopt -u nullglob
```

### Option B — git restore (works only on tracked files)

```bash
git restore .claude/agents .claude/skills .claude/bootstrap-state.json 2>/dev/null || true
# If any of those paths are gitignored (companion strategy), git restore is a no-op — use Option A instead.
```

Rollback is safe + reversible — all edits are text-file patches with per-file backups + no schema changes + no external state.
