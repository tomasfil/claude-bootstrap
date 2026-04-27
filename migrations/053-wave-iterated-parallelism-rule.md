# Migration 053 — Wave-Iterated Parallelism Rule

<!-- migration-id: 053-wave-iterated-parallelism-rule -->

> Install `.claude/rules/wave-iterated-parallelism.md` rule file (4-shape task classification — `SOLVABLE_FACT`, `SINGLE_LAYER`, `CALL_GRAPH`, `END_TO_END_FLOW`; adaptive `END_TO_END_FLOW` cap with ceiling=10; GAP Dedup Requirement; Shape Escalation; 3-state MCP-agnostic routing). Add `@import .claude/rules/wave-iterated-parallelism.md` line to client `CLAUDE.md` so the rule loads on every session. File install is additive (sentinel-guarded). The CLAUDE.md `@import` edit is destructive in-place; uses three-tier baseline-sentinel detection per `.claude/rules/general.md` Migration Preservation Discipline. Customized client `CLAUDE.md` files emit `SKIP_HAND_EDITED` + `.bak-053` backup + pointer to `## Manual-Apply-Guide`. Source content: `templates/rules/wave-iterated-parallelism.md` (172 lines).

---

## Metadata

```yaml
id: "053"
breaking: false
affects: [rules, claude-md]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Pre-output exploration in agents is currently unstructured: agents either issue a single broad batch of reads, or — more often — drift into serial one-at-a-time reads ("Read A → respond → Read B → respond"), which leaks coverage, bloats context, and misses cross-file evidence. Two known degeneration modes worsen the problem:

1. **Reflexion-style repeat-fishing** — later iterations re-list previously-read targets without surfacing new evidence, masquerading as progress while actually idling.
2. **Shape lock** — the agent classifies the task at the top (e.g., as `SINGLE_LAYER`), then refuses to upgrade even when Wave 1 evidence reveals deeper depth (e.g., a cross-subsystem boundary).

Without a shared rule, every agent reinvents the protocol independently and the failure modes recur. This migration installs a single rule file (`.claude/rules/wave-iterated-parallelism.md`) that:

- Classifies tasks by shape (`SOLVABLE_FACT`, `SINGLE_LAYER`, `CALL_GRAPH`, `END_TO_END_FLOW`, `OPEN_INVESTIGATION`) with explicit caps per shape.
- Defines the adaptive cap formula for `END_TO_END_FLOW` (`cap = max(cap, waves_completed + 2)` up to ceiling=10).
- Mandates GAP Dedup (no re-listing previously-read targets) and Shape Escalation (one-time-only upgrade after Wave 1 if gaps reveal deeper depth).
- Provides 3-state MCP-agnostic routing (Full MCP / No MCP / Partial MCP).
- Documents composed loopback annotations (`RESOURCE-BUDGET + CONVERGENCE-QUALITY` for END_TO_END_FLOW shape; plain `RESOURCE-BUDGET` for fixed-pass shapes).

The rule loads via `@import` in `CLAUDE.md` so every main-thread session and every dispatched agent inherits the protocol. Per-agent block installs (which inject the protocol into specific agent bodies) are scoped to a follow-up migration.

---

## Changes

| File | Change | Tier |
|---|---|---|
| `.claude/rules/wave-iterated-parallelism.md` | NEW rule file — full 172-line content from `templates/rules/wave-iterated-parallelism.md` | Additive (sentinel-guarded) |
| `CLAUDE.md` | Insert `@import .claude/rules/wave-iterated-parallelism.md` line after `@import .claude/rules/main-thread-orchestrator.md` | Destructive (three-tier) |

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { printf "ERROR: not a bootstrapped project — run full bootstrap first\n"; exit 1; }
[[ -d ".claude/rules" ]] || { printf "ERROR: .claude/rules/ missing — run full bootstrap first\n"; exit 1; }
[[ -f "CLAUDE.md" ]] || { printf "ERROR: CLAUDE.md missing — run full bootstrap first\n"; exit 1; }
command -v python3 >/dev/null 2>&1 || { printf "ERROR: python3 required\n"; exit 1; }
```

### Idempotency check

```bash
#!/usr/bin/env bash
set -euo pipefail

rule_installed=0
import_added=0

if [[ -f ".claude/rules/wave-iterated-parallelism.md" ]] \
  && grep -q "<!-- wave-iterated-parallelism-rule-installed -->" .claude/rules/wave-iterated-parallelism.md 2>/dev/null; then
  rule_installed=1
fi

if grep -q "^@import \.claude/rules/wave-iterated-parallelism\.md$" CLAUDE.md 2>/dev/null; then
  import_added=1
fi

if [[ "$rule_installed" -eq 1 && "$import_added" -eq 1 ]]; then
  printf "SKIP: migration 053 already applied (rule file installed + CLAUDE.md @import present)\n"
  exit 0
fi

printf "Applying migration 053: rule_installed=%s import_added=%s\n" "$rule_installed" "$import_added"
```

### Step 1 — Create `.claude/rules/wave-iterated-parallelism.md` (additive, new file)

Additive: writes the full 172-line rule content via single-quoted heredoc (no shell expansion). Sentinel-guarded — re-running with the file already present (and carrying the EOF sentinel) emits `SKIP`.

**Sentinel**: target file exists AND contains `<!-- wave-iterated-parallelism-rule-installed -->` at EOF → SKIP.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/rules/wave-iterated-parallelism.md"

if [[ -f "$TARGET" ]] \
  && grep -q "<!-- wave-iterated-parallelism-rule-installed -->" "$TARGET" 2>/dev/null \
  && grep -q "^# Wave-Iterated Parallelism" "$TARGET" 2>/dev/null \
  && grep -q "^## Task Shape Detection$" "$TARGET" 2>/dev/null; then
  printf "SKIP: %s already present with sentinel + headings (053-1)\n" "$TARGET"
else
  cat > "$TARGET" <<'RULE_EOF'
# Wave-Iterated Parallelism — Anti-Shortcut + Anti-Hallucination Wave Protocol

## Why
Pre-output exploration must read broadly first, then close gaps. Serial one-at-a-time reads
leak coverage + bloat context + miss cross-file evidence. Wave 1 batches all independent
reads in one parallel message — broad coverage in a single round-trip. Gap-check then
enumerates uncovered layers/symbols/files; Wave N targets only those gaps. Shape-aware
caps prevent dispatch sprawl: SOLVABLE_FACT skips waves entirely, SINGLE_LAYER stops at
2, CALL_GRAPH at 3, END_TO_END_FLOW extends adaptively under a hard ceiling. GAP dedup +
Shape Escalation close the two known degeneration modes (Reflexion-style repeat-fishing;
locking shape after Wave 1 reveals deeper depth).

## Rule
Agents w/ pre-output exploration phase MUST structure tool calls as named waves.
Batch-then-gap-check; never serial. Classify task shape BEFORE Wave 1; declare cap.

## Task Shape Detection

Classify from dispatch prompt signal before reading. Record: `TASK_SHAPE: {shape} | WAVE_CAP: {cap}`.

| Shape | Description | Cap |
|---|---|---|
| SOLVABLE_FACT | known-answer / single-fact lookup ("look up", "does X exist", "what is X") | wave does not apply |
| SINGLE_LAYER | one architectural layer / bounded scope ("list all", "enumerate", "find all handlers") | 2 |
| CALL_GRAPH | symbol callers/callees/inheritance ("who calls X", "callers of X", "callees") | 3 |
| END_TO_END_FLOW | cross-subsystem flow trace ("trace full flow", "from UI to DB", "across layers") | adaptive (min=5, ceiling=10) |
| OPEN_INVESTIGATION | generic investigation w/o explicit signal (researcher carve-out) | 3 |
| no signal, non-researcher | conservative default | 2 |

## Adaptive Cap (END_TO_END_FLOW)
Starts at 5. After each wave, new layers discovered → `cap = max(cap, waves_completed + 2)`.
Ceiling = 10. Ceiling MAY be exceeded only via explicit composed-annotation justification
(signal=new-layer-discovered) on a per-dispatch override; default ceiling holds.
Record after each wave: `WAVE_CAP: {current} (shape=END_TO_END_FLOW, ceiling=10)`.

## Shape Escalation

After Wave 1 gap enumeration, if gaps reveal depth beyond classified shape → upgrade
shape + cap. One-time-only; END_TO_END_FLOW is terminal. Justification log entry required.

| Current shape | Upgrade trigger (gap reveals...) | Upgraded shape | New cap |
|---|---|---|---|
| SINGLE_LAYER (cap=2) | inheritance / callers / callees of changed symbols | CALL_GRAPH | 3 |
| SINGLE_LAYER (cap=2) | cross-subsystem boundary (UI→VM→API etc.) | END_TO_END_FLOW | adaptive (min=5) |
| CALL_GRAPH (cap=3) | cross-subsystem boundary | END_TO_END_FLOW | adaptive (min=5) |
| END_TO_END_FLOW | — (terminal; no further upgrade) | — | — |

Required log entry on escalation:

```
Shape upgraded {FROM}→{TO} after Wave 1 revealed {trigger: cross-subsystem refs | inheritance depth | end-to-end flow boundary} at {evidence: file:line | symbol-qname | file1:line + file2:line (cross-subsystem)}.
```

## GAP Dedup Requirement

GAP items emitted after each wave MUST reference layers/files NOT present in any prior
wave's read list. Re-listing previously-read targets = protocol violation.

Each GAP item format:

```
GAP: {description} (target: {file_path | symbol_qname}) — {reason}
```

The `target:` field MUST be unique across all prior waves' targets. Before emitting Wave N
gaps, explicitly dedup against all prior waves' target lists; drop matches.

## Carve-Outs (wave does NOT apply)

- Single file w/ known path supplied in dispatch prompt → direct Read (Tier 1 per `main-thread-orchestrator.md`)
- SOLVABLE_FACT shape → proj-quick-check by design
- Tool result depends on prior tool result (dependency chain) → sequential is correct

## Structure

### Wave 1 — Broad Coverage
Enumerate all independent reads required. Issue ALL in one parallel message.
At least ONE read per detected layer / component / concern. MCP path first per state
routing below; text fallback if MCP absent or 0 hits.

### Gap-Check Checkpoint
After Wave 1:
1. Emit structured gaps: `GAP: {description} (target: {file_path | symbol_qname}) — {reason}`
2. Apply GAP Dedup Requirement (no repeat of prior waves' targets)
3. Empty gap list → stop (Wave N skipped)
4. Apply Shape Escalation check: gaps reveal deeper-than-classified depth → upgrade
5. END_TO_END_FLOW: update `WAVE_CAP` if new layers discovered

### Wave N — Gap-Targeted
Issue reads addressing identified gaps only. Batch all in one parallel message.
Repeat gap-check → wave cycle until: no gaps remain OR cap reached.

## MCP-Agnostic Routing (3-state)

Code-discovery routing depends on MCP availability in any reachable scope. Scope-check
sequence (5 scopes): project `.mcp.json` → user `~/.claude.json` top-level `mcpServers`
→ user `~/.claude.json` `projects.<cwd>.mcpServers` → managed `managed-settings.json` →
plugin-bundled servers. Any scope returning cmm or serena → State 1.

**State 1 — Full MCP** (cmm + serena reachable in any scope):
Lead-with: `cmm.search_graph` → `cmm.get_code_snippet` → `serena.find_referencing_symbols`
→ `serena.find_symbol`. Full routing per `mcp-routing.md` Lead-With Order. Grep Ban
applies on named symbols. Transparent fallback disclosure required on MCP failure / 0 hits.

**State 2 — No MCP**:
Direct text tools — Read known paths + Grep w/ `glob:` scope. No Grep Ban. No MCP fallback
disclosure needed (no MCP attempted).

**State 3 — Partial MCP** (other servers present, no cmm/serena):
Code discovery same as State 2. Lead-With Order dormant. Grep Ban inactive (indexed-project
gate not satisfied). Other-domain MCP servers callable per their own purpose.

## Composed Loopback Annotation

END_TO_END_FLOW shape uses two-label composition annotating both cost ceiling AND
quality-extension trigger at the same control point:

```
<!-- RESOURCE-BUDGET: ceiling=10 + CONVERGENCE-QUALITY: signal=new-layer-discovered -->
```

Fixed-pass shapes (SINGLE_LAYER cap=2, CALL_GRAPH cap=3, OPEN_INVESTIGATION cap=3)
use plain `<!-- RESOURCE-BUDGET: ... -->` only — pure cost-driven exit, no
quality-extension mechanism. Composition draws from canonical-4 labels only — no
5th label introduced. Grammar + permitted pairs in `loopback-budget.md` § Composed Forms.

## Escalation (cap reached, gaps remain)

Return:

```
SCOPE_ESCALATION_NEEDED: {shape} — cap={ceiling} reached; layers traced: {list}; remaining: {last_ref}
```

Orchestrator options: decompose per layer, re-dispatch w/ `wave_ceiling=N` override, or accept partial.

## Anti-Patterns

- `SERIAL-READ DRIFT`: Read A → respond → Read B → respond. Named violation; cross-pillar (anti-shortcut).
- `Wave N+1 fishing`: initiating a wave w/ no concrete GAP items from gap-check. Forbidden.
- `GAP REPEAT`: re-listing previously-read target in later wave's GAP list. Protocol violation.
- `SHAPE LOCK`: maintaining classified shape after Wave 1 reveals deeper depth. Apply Shape Escalation.
- `MCP-ONLY shortcut`: assumes State 1 always; fails on State 2/3 deployments.
- `TEXT-ONLY shortcut`: skips cmm/serena on State 1 indexed projects; misses callers + callees.
- `SILENT DEGRADATION`: MCP fails → fallback to text w/o disclosure (State 1 only).

## Per-Agent Wave Protocol Block

Each agent body installs a wave protocol block tailored to its task shape default. Six
target agents: `proj-researcher`, `proj-plan-writer`, `proj-code-writer-{lang}`,
`proj-test-writer-{lang}`, `proj-debugger`, `proj-code-reviewer`. Per-agent default
shapes, anchor map, sentinel, and migration script live in the migration file
(sentinel: `wave-gap-mcp-agnostic-installed`). Block content per agent: shape
classification (Step 1) → Wave 1 batch list (Step 2) → Gap Enumeration + Shape
Escalation check (Step 3) → Wave N (Step 4) → composed annotation (END_TO_END_FLOW
shapes) or plain RESOURCE-BUDGET (fixed-pass shapes).

## Enforcement

- Force-read in STEP 0 of 6 target agents (installed by migration; sentinel `wave-gap-mcp-agnostic-installed`)
- `/audit-agents` scans target agent bodies for `wave-iterated-parallelism.md` STEP 0 entry + per-insertion idempotency markers
- `/audit-agents` A8 check scans for canonical loopback label tokens in wave-protocol annotations (per `loopback-budget.md` § Composed Forms)
- `/review` rubric: Wave 1 shows multiple reads in one round; gap-check present; shape declared; GAP items include `(target:)` field; escalation log entry present when shape upgraded

## Related

- `loopback-budget.md` — canonical-4 labels + Composed Forms grammar + permitted pairs (RESOURCE-BUDGET + CONVERGENCE-QUALITY)
- `max-quality.md` §3 — full verification (cross-references resolve; build/test pass)
- `mcp-routing.md` — state-specific routing details (Lead-With Order, Grep Ban, Transparent Fallback)
- `agent-scope-lock.md` — downstream: agents stay in their listed files even when wave-discovered evidence tempts adjacent edits
- `main-thread-orchestrator.md` — Tier 1 carve-out (known-path direct Read); Tier 2 dispatch (wave protocol applies inside dispatched agent)
- `templates/agents/` — per-agent wave protocol blocks (researcher, plan-writer, code-writer, test-writer, debugger, code-reviewer)

<!-- wave-iterated-parallelism-rule-installed -->
RULE_EOF
  printf "WROTE: %s\n" "$TARGET"
fi
```

### Step 2 — Append `@import` line to `CLAUDE.md`

Read-before-write with three-tier baseline-sentinel detection:

- **Tier 1 idempotency sentinel**: `@import .claude/rules/wave-iterated-parallelism.md` line present in `CLAUDE.md` → `SKIP_ALREADY_APPLIED`
- **Tier 2 baseline sentinel**: `@import .claude/rules/main-thread-orchestrator.md` present (stock post-bootstrap state, safe to insert after) → `PATCHED` (insert new `@import` line on the line immediately following the baseline import)
- **Tier 3 neither present**: `CLAUDE.md` has been customized post-bootstrap (imports block restructured, baseline removed, or never had it) → `SKIP_HAND_EDITED` + write `.bak-053` backup if absent + pointer to `## Manual-Apply-Guide §Step-2`. Client customizations preserved.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import sys
from pathlib import Path

target = Path("CLAUDE.md")
backup = Path(str(target) + ".bak-053")

POST_053_LINE = "@import .claude/rules/wave-iterated-parallelism.md"
BASELINE_LINE = "@import .claude/rules/main-thread-orchestrator.md"

content = target.read_text(encoding="utf-8")

if POST_053_LINE in content:
    print(f"SKIP_ALREADY_APPLIED: {target} @import line already present (053-2)")
    sys.exit(0)

if BASELINE_LINE not in content:
    if not backup.exists():
        backup.write_text(content, encoding="utf-8")
    print(f"SKIP_HAND_EDITED: {target} baseline @import '{BASELINE_LINE}' absent — CLAUDE.md has been customized post-bootstrap. Manual application required. See migrations/053-wave-iterated-parallelism-rule.md §Manual-Apply-Guide §Step-2. Backup at {backup}.")
    sys.exit(0)

if not backup.exists():
    backup.write_text(content, encoding="utf-8")

# Insert the new @import line on the line immediately following the baseline @import line.
# Preserves whatever surrounding content (other @import lines, comments, etc.) the user has.
NEEDLE = BASELINE_LINE + "\n"
REPLACEMENT = BASELINE_LINE + "\n" + POST_053_LINE + "\n"

new_content = content.replace(NEEDLE, REPLACEMENT, 1)

if new_content == content:
    # Defensive: baseline grep matched but replace was no-op (happens if baseline is the
    # final line of the file with no trailing newline). Append the new line at EOF instead.
    if content.endswith("\n"):
        new_content = content + POST_053_LINE + "\n"
    else:
        new_content = content + "\n" + POST_053_LINE + "\n"

target.write_text(new_content, encoding="utf-8")
print(f"PATCHED: {target} @import line inserted after baseline (053-2)")
PY
```

### Step 3 — Update `.claude/bootstrap-state.json`

Advance `last_migration` and append to `applied[]`.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '053'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '053') or a == '053' for a in applied):
    applied.append({
        'id': '053',
        'applied_at': state['last_applied'],
        'description': 'Install wave-iterated-parallelism rule file (4-shape task classification: SOLVABLE_FACT / SINGLE_LAYER / CALL_GRAPH / END_TO_END_FLOW; adaptive END_TO_END_FLOW cap with ceiling=10; GAP Dedup Requirement; Shape Escalation; 3-state MCP-agnostic routing). Add @import line to CLAUDE.md so the rule loads on every session.'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=053')
PY
```

### Rules for migration scripts

- **Read-before-write** — every step reads the target, checks sentinel, writes only on safe-patch tier. Step 2 (CLAUDE.md edit) writes `.bak-053` backup before any destructive edit.
- **Idempotent** — re-running prints `SKIP` per step and `SKIP: migration 053 already applied` at the top when both targets carry their sentinels.
- **Self-contained** — full 172-line rule content inlined in single-quoted heredoc (`<<'RULE_EOF'`) so no shell variable / backtick / `$` expansion fires inside. CLAUDE.md edit is pure text substitution.
- **No remote fetch** — content is inlined. The rule file is net-new in client projects; no bootstrap-repo prerequisite for content.
- **Scope lock** — touches only `.claude/rules/wave-iterated-parallelism.md` (new), `CLAUDE.md` (one-line insert), `.claude/bootstrap-state.json`. No agent edits, no skill edits, no hook changes. `migrations/index.json` is appended BY MAIN THREAD outside this migration body (per `.claude/rules/agent-scope-lock.md`).
- **Heredoc safety** — single-quoted EOF token (`<<'RULE_EOF'`) prevents all expansion. The rule file content contains `${...}` and `` ` `` characters (in code block samples, qname placeholders, and shell snippets); the single-quoted heredoc ships them verbatim.

---

## Verify

```bash
#!/usr/bin/env bash
set +e
fail=0

# 1. rule file exists
if [[ -f ".claude/rules/wave-iterated-parallelism.md" ]]; then
  printf "PASS: .claude/rules/wave-iterated-parallelism.md present\n"
else
  printf "FAIL: .claude/rules/wave-iterated-parallelism.md missing\n"
  fail=1
fi

# 2. rule file carries top-level heading
if grep -q "^# Wave-Iterated Parallelism" .claude/rules/wave-iterated-parallelism.md 2>/dev/null; then
  printf "PASS: top-level heading present\n"
else
  printf "FAIL: top-level heading '# Wave-Iterated Parallelism' missing\n"
  fail=1
fi

# 3. rule file carries Task Shape Detection heading
if grep -q "^## Task Shape Detection$" .claude/rules/wave-iterated-parallelism.md 2>/dev/null; then
  printf "PASS: '## Task Shape Detection' heading present\n"
else
  printf "FAIL: '## Task Shape Detection' heading missing\n"
  fail=1
fi

# 4. rule file carries key section markers
for marker in "Adaptive Cap (END_TO_END_FLOW)" "Shape Escalation" "GAP Dedup Requirement" "MCP-Agnostic Routing" "Composed Loopback Annotation" "Anti-Patterns"; do
  if grep -q "$marker" .claude/rules/wave-iterated-parallelism.md 2>/dev/null; then
    printf "PASS: '%s' marker present\n" "$marker"
  else
    printf "FAIL: '%s' marker missing\n" "$marker"
    fail=1
  fi
done

# 5. rule file carries EOF sentinel
if grep -q "<!-- wave-iterated-parallelism-rule-installed -->" .claude/rules/wave-iterated-parallelism.md 2>/dev/null; then
  printf "PASS: rule-file EOF sentinel present\n"
else
  printf "FAIL: rule-file EOF sentinel missing\n"
  fail=1
fi

# 6. rule file line count is roughly correct (sanity check; allow ±5 line drift)
line_count=$(wc -l < .claude/rules/wave-iterated-parallelism.md)
if [[ "$line_count" -ge 165 && "$line_count" -le 185 ]]; then
  printf "PASS: rule file line count = %s (expected ~172)\n" "$line_count"
else
  printf "FAIL: rule file line count = %s (expected 167-185)\n" "$line_count"
  fail=1
fi

# 7. CLAUDE.md @import line present
if grep -q "^@import \.claude/rules/wave-iterated-parallelism\.md$" CLAUDE.md 2>/dev/null; then
  printf "PASS: CLAUDE.md @import line present\n"
else
  printf "FAIL: CLAUDE.md missing '@import .claude/rules/wave-iterated-parallelism.md' line\n"
  fail=1
fi

# 8. bootstrap-state.json updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "053" ]]; then
  printf "PASS: last_migration = 053\n"
else
  printf "FAIL: last_migration = %s (expected 053)\n" "$last"
  fail=1
fi

printf -- "---\n"
if [[ $fail -eq 0 ]]; then
  printf "Migration 053 verification: ALL PASS\n"
  printf "\nOptional cleanup: remove .bak-053 backups once you've confirmed patches are correct:\n"
  printf "  find . -maxdepth 1 -name 'CLAUDE.md.bak-053' -delete\n"
else
  printf "Migration 053 verification: FAILURES — state NOT updated\n"
  exit 1
fi
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix. `SKIP_HAND_EDITED` from Step 2 will cause verify-step 7 to fail — resolve by applying `## Manual-Apply-Guide §Step-2`, then re-run verify.

---

## State Update

On success:
- `last_migration` → `"053"`
- append `{ "id": "053", "applied_at": "<ISO8601>", "description": "Install wave-iterated-parallelism rule file (4-shape task classification: SOLVABLE_FACT / SINGLE_LAYER / CALL_GRAPH / END_TO_END_FLOW; adaptive END_TO_END_FLOW cap with ceiling=10; GAP Dedup Requirement; Shape Escalation; 3-state MCP-agnostic routing). Add @import line to CLAUDE.md so the rule loads on every session." }` to `applied[]`

---

## Idempotency

Re-running after success:
- Top-level — both rule file sentinel and CLAUDE.md @import line present → `SKIP: migration 053 already applied`
- Step 1 — `<!-- wave-iterated-parallelism-rule-installed -->` sentinel present at EOF + headings present → `SKIP`
- Step 2 — `@import .claude/rules/wave-iterated-parallelism.md` line present in `CLAUDE.md` → `SKIP_ALREADY_APPLIED`
- Step 3 — `applied[]` dedup check (migration id == `'053'`) → no duplicate append

No backups are rewritten on re-run. CLAUDE.md files that were `SKIP_HAND_EDITED` on first apply remain `SKIP_HAND_EDITED` on re-run (baseline + idempotency sentinels both absent) — manual merge per `## Manual-Apply-Guide` is still required.

---

## Rollback

```bash
#!/usr/bin/env bash
set -euo pipefail

# Step 1 — remove the new rule file
if [[ -f ".claude/rules/wave-iterated-parallelism.md" ]]; then
  rm ".claude/rules/wave-iterated-parallelism.md"
  printf "REMOVED: .claude/rules/wave-iterated-parallelism.md\n"
else
  printf "NOOP: .claude/rules/wave-iterated-parallelism.md not present\n"
fi

# Step 2 — restore CLAUDE.md from .bak-053 backup if present
if [[ -f "CLAUDE.md.bak-053" ]]; then
  mv "CLAUDE.md.bak-053" "CLAUDE.md"
  printf "Restored: CLAUDE.md from .bak-053\n"
else
  # Fallback: strip the @import line directly
  python3 <<'PY'
from pathlib import Path
target = Path("CLAUDE.md")
content = target.read_text(encoding="utf-8")
LINE = "@import .claude/rules/wave-iterated-parallelism.md\n"
if LINE in content:
    new_content = content.replace(LINE, "", 1)
    target.write_text(new_content, encoding="utf-8")
    print(f"STRIPPED: @import line removed from {target}")
else:
    print(f"NOOP: {target} has no @import line for wave-iterated-parallelism")
PY
fi

# Reset bootstrap-state.json
python3 <<'PY'
import json
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
if state.get('last_migration') == '053':
    state['last_migration'] = '052'
state['applied'] = [a for a in state.get('applied', []) if not (
    (isinstance(a, dict) and a.get('id') == '053') or a == '053'
)]
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State rolled back to last_migration=052')
PY
```

Rollback removes the rule file and restores CLAUDE.md from `.bak-053` (if Step 2 wrote one) or strips the inserted `@import` line directly. If neither path applies, the file was either fully `SKIP_ALREADY_APPLIED` (nothing to roll back) or `SKIP_HAND_EDITED` (nothing was written).

---

## Manual-Apply-Guide

Operators reach this section via the `SKIP_HAND_EDITED` guidance line emitted by Step 2. The subsection below holds the verbatim target content — copy directly into `CLAUDE.md` when automation skipped the patch.

**General procedure**:
1. Open the target file.
2. Locate the imports block.
3. Read the new content block below for the step.
4. Manually merge: preserve your project-specific customizations (additional `@import` lines, comments, ordering); incorporate the new line.
5. Save the file.
6. Run the verification snippet shown at the end of the subsection to confirm the patch landed correctly.
7. A `.bak-053` backup of the pre-migration `CLAUDE.md` exists at `CLAUDE.md.bak-053` if the migration wrote one; use `diff CLAUDE.md.bak-053 CLAUDE.md` to see exactly what changed.

---

### §Step-1 — `wave-iterated-parallelism.md` rule file install

**Target**: `.claude/rules/wave-iterated-parallelism.md` — new rule file.

**Context**: Step 1 is fully automated and additive; it does not have a `SKIP_HAND_EDITED` branch. If Step 1 reports `WROTE` it succeeded; if it reports `SKIP` the file is already present with the sentinel + headings. If Step 1 fails (disk permissions, path issue), investigate the failure cause and re-run.

**Manual recreation procedure** (only needed if Step 1 fails repeatedly):

1. Resolve the bootstrap repo slug (env var → bootstrap-state.json → canonical default — same precedence chain `/migrate-bootstrap` uses; see migration 023):
   ```bash
   BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-$(jq -r '.bootstrap_repo // "tomasfil/claude-bootstrap"' .claude/bootstrap-state.json 2>/dev/null || echo tomasfil/claude-bootstrap)}"
   printf 'Using bootstrap repo: %s\n' "$BOOTSTRAP_REPO"
   ```
2. Fetch the rule file content from the resolved bootstrap repo:
   ```bash
   gh api "repos/${BOOTSTRAP_REPO}/contents/templates/rules/wave-iterated-parallelism.md?ref=main" \
     --jq '.content' | base64 -d > .claude/rules/wave-iterated-parallelism.md
   ```
3. Append the EOF sentinel:
   ```bash
   printf "\n<!-- wave-iterated-parallelism-rule-installed -->\n" >> .claude/rules/wave-iterated-parallelism.md
   ```
4. Verify line count is in the expected range (167-185):
   ```bash
   wc -l .claude/rules/wave-iterated-parallelism.md
   ```

If `gh` is not authenticated, run `gh auth login` first. Fork users: set `BOOTSTRAP_REPO=your-handle/claude-bootstrap` in your shell or add `"bootstrap_repo": "your-handle/claude-bootstrap"` to `.claude/bootstrap-state.json` so this fetch targets your fork.

**Verification**:
```bash
grep -q "^# Wave-Iterated Parallelism" .claude/rules/wave-iterated-parallelism.md && echo "PASS"
grep -q "<!-- wave-iterated-parallelism-rule-installed -->" .claude/rules/wave-iterated-parallelism.md && echo "PASS"
```

---

### §Step-2 — `CLAUDE.md` `@import` line insertion

**Target**: `CLAUDE.md` — imports block (typically a sequence of `@import .claude/rules/*.md` lines near the top of the file).

**Context**: the migration detected that the baseline import line `@import .claude/rules/main-thread-orchestrator.md` was absent from `CLAUDE.md`, meaning the imports block has been customized post-bootstrap (baseline removed, restructured, or never had it).

**New content (verbatim — single line to add)**:

```markdown
@import .claude/rules/wave-iterated-parallelism.md
```

**Merge instructions**:
1. Open `CLAUDE.md`.
2. Locate the imports block — typically a sequence of `@import .claude/rules/*.md` lines. If your `CLAUDE.md` does not use `@import` directives at all, add the line as the FIRST `@import` directive in the file at the top (immediately after any frontmatter / introductory paragraph).
3. Insert `@import .claude/rules/wave-iterated-parallelism.md` as a new line in the imports block. Preferred position: after `@import .claude/rules/main-thread-orchestrator.md` if present; otherwise after `@import .claude/rules/max-quality.md`; otherwise as the LAST `@import` line in the block.
4. Preserve any project-specific `@import` lines, comments, or ordering you have added to the imports block.
5. Save the file.

**Verification**:
```bash
grep -q "^@import \.claude/rules/wave-iterated-parallelism\.md$" CLAUDE.md && echo "PASS"
```

---

## Post-Apply — Bootstrap Repo Self-Update

This migration targets client projects. The bootstrap repo's own `.claude/` copies are
generated output, not source of truth. To update the bootstrap repo's installed copies:

1. Run `/migrate-bootstrap` against the bootstrap repo itself, OR re-run each step manually against the bootstrap repo's `.claude/` (the template at `templates/rules/wave-iterated-parallelism.md` is already in the target state).
2. Do NOT directly edit `.claude/rules/wave-iterated-parallelism.md` in the bootstrap repo — direct edits bypass the template and create drift.

Reference: `.claude/rules/general.md` §Process — "NEVER write to this repo's `.claude/` as implementation work."

---

## Post-Migration (main-thread only per agent-scope-lock.md)

Append to `migrations/index.json`:
```json
{
  "id": "053",
  "file": "053-wave-iterated-parallelism-rule.md",
  "description": "Install wave-iterated-parallelism rule file (4-shape task classification: SOLVABLE_FACT / SINGLE_LAYER / CALL_GRAPH / END_TO_END_FLOW; adaptive END_TO_END_FLOW cap with ceiling=10; GAP Dedup Requirement; Shape Escalation; 3-state MCP-agnostic routing). Add @import line to CLAUDE.md so the rule loads on every session.",
  "breaking": false
}
```
