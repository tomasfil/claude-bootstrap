# Migration 054 — Wave-Protocol Agent Blocks

<!-- migration-id: 054-wave-protocol-agent-blocks -->

> Install Wave Protocol body blocks into 6 client-project agent body types (`proj-researcher`, `proj-plan-writer`, `proj-debugger` w/ extra `## SOLVABLE-GATE`, `proj-code-reviewer`, `code-writer-*` glob, `test-writer-*` glob). Each block is inserted at a per-agent verbatim anchor (verified at lines 56–114 of stock templates). Debugger receives TWO insertions: Wave Protocol after Process step 3, then SOLVABLE-GATE before `## Self-Fix Protocol`. Per-agent insertion uses three-tier detection (idempotency marker / anchor verbatim / hand-edited path with `.bak-054` backup + `## Manual-Apply-Guide` pointer). Outer migration is 4-state (per gap-resolution-6-N R5-H6): State 1 new sentinel present → SKIP; State 2 old sentinel `wave-gap-agent-body-installed` only → MCP-routing-diff only; State 3 neither → fresh full install; State 4 old sentinel + MCP routing marker already present → validate + set new sentinel. Sentinel: `wave-gap-mcp-agnostic-installed`. Prerequisite: client `.claude/rules/loopback-budget.md` must contain `## Composed Forms` section (migration 052). All 7 heredocs carry the 9-U §3 escalation log placeholder amendment applied at migration-write time (6 of 7 amended; `DEBUGGER_SOLVABLE_GATE_BLOCK` carries no shape-escalation logic so requires no amendment). Glob deployment for `code-writer-*` and `test-writer-*` per `.claude/rules/general.md` Migrations rule — sub-specialists created by `/evolve-agents` are covered automatically.

---

## Metadata

```yaml
id: "054"
breaking: false
affects: [agents]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Migrations 050 / 052 / 053 install the loopback-budget vocabulary, the composed-form grammar, and the wave-iterated-parallelism rule file. The rule file (`.claude/rules/wave-iterated-parallelism.md`) loads via `@import` on every session, so every main-thread turn and every dispatched agent inherits the abstract protocol. Without a per-agent body block, however, agents only have abstract guidance — they do not have agent-shaped wave instructions inside their own body, where pre-output exploration discipline lives. The two failure modes from migration 053's rationale (Reflexion-style repeat-fishing; shape lock) recur unless each agent body carries the protocol expressed in its own task vocabulary (researcher: codebase exploration; plan-writer: spec-to-codebase verification; debugger: root-cause hunt; reviewer: caller + shared-module reads; code-writer: target-file + dependency reads; test-writer: implementation + adjacent test reads).

`proj-debugger` additionally needs a **`## SOLVABLE-GATE` classification block** placed BEFORE the existing `## Self-Fix Protocol` heading. The SOLVABLE-GATE block specifies how the agent classifies blockers as `DIAGNOSABLE` (continue hypothesis-elimination via Local Source Exhaustion Checklist) vs `USER_DECIDES` (escalate immediately because the root cause requires user-only knowledge). Without an explicit classification gate, the debugger conflates "I cannot find the root cause yet" (DIAGNOSABLE — keep going) with "the root cause requires user-only knowledge" (USER_DECIDES — escalate now), producing both over-escalation (returning USER_DECIDES early to skip a third hypothesis pass) and under-escalation (looping on a USER_DECIDES blocker that no amount of local exhaustion can resolve).

The migration is the agent-body counterpart to 053's rule-file install. It targets all 6 affected agent body types via per-agent anchors plus glob-matching for `code-writer-*` and `test-writer-*` (so language-specialist sub-agents created by `/evolve-agents` receive the same install). The 4-state outer logic handles three real-world cases: fresh client (State 3 — full install); pre-merged client carrying an older sentinel from a superseded migration (State 2 — apply MCP-routing diff only, do NOT double-patch the wave block; or State 4 — old sentinel + MCP routing already present from a manual edit, validate and set new sentinel). State 1 (new sentinel already present) is the idempotency case — re-running the migration after a successful first apply is a no-op.

## Rationale

1. **Per-agent block is the missing layer between the rule file and agent action.** Migration 053's rule file is loaded into context but does not specify wave shapes per agent. The agent body is where agent-specific procedure lives — inserting the block there means every dispatch starts with the protocol pre-expanded for that agent's task type.

2. **9-U §3 escalation log placeholder amendment must be applied BEFORE shipping the migration.** 8-S § 2 heredocs are byte-faithful to source (6-M / 7-R) which carry the OLD or condensed escalation log placeholder text. 9-U §3 specifies a corrected format (`Log: \`Shape upgraded {FROM}→{TO} after Wave 1 revealed {trigger} at {evidence: file:line | symbol-qname | file1:line + file2:line (cross-subsystem)}\``) that adds the missing `{trigger}` field and a structured `evidence` schema. 6 of 7 heredocs carry shape-escalation logic and require the amendment; `DEBUGGER_SOLVABLE_GATE_BLOCK` is a pre-wave classification block with no shape-escalation logic and requires no amendment. Per 9-U §5 integration order, the amendment is applied at migration-write time so the 6 amended heredocs ship verbatim.

3. **Per-agent anchor map is verbatim from gap-resolution-7-Q § Section 2.** Each anchor was verified `grep -c = 1` in stock template files. Step-numbered anchors (e.g., `6. No hard cap on tool calls...`) are MODERATE stability — a future template edit that renumbers steps would invalidate the anchor — so the migration includes a stripped-prefix fallback (anchor without leading `N. ` digits) per 7-Q § Section 7.

4. **Three-tier detection per insertion preserves project customizations.** Per `.claude/rules/general.md` Migration Preservation Discipline: idempotency marker present (post-migration sentinel from a prior apply) → `SKIP_ALREADY_APPLIED`; anchor verbatim text present (stock pre-migration baseline) → safe `PATCHED`; neither present (file customized post-bootstrap) → `SKIP_HAND_EDITED` + `.bak-054` backup if absent + pointer to `## Manual-Apply-Guide`. Anchor-fallback (stripped-prefix form) runs as a defensive second-pass before deciding `SKIP_HAND_EDITED`.

5. **Glob deployment for `code-writer-*` and `test-writer-*`.** Sub-specialists created by `/evolve-agents` (e.g., `proj-code-writer-csharp.md`, `proj-test-writer-python.md`) inherit the same wave block installer because the migration globs the filenames rather than hard-coding suffixes (per `.claude/rules/general.md`: "Migrations must glob agent filenames").

---

## Changes

| File | Change | Tier |
|---|---|---|
| `.claude/agents/proj-researcher.md` | Insert `### Wave Protocol (codebase exploration)` block after Local Codebase Analysis step 6 | Destructive (three-tier per insertion + outer 4-state) |
| `.claude/agents/proj-plan-writer.md` | Insert `### Wave Protocol (spec-to-codebase verification)` block after Process step 2 | Destructive (three-tier per insertion + outer 4-state) |
| `.claude/agents/proj-debugger.md` | Insert `### Wave Protocol (root-cause hunt)` block after Process step 3, AND insert `## SOLVABLE-GATE` block before `## Self-Fix Protocol` heading | Destructive (three-tier per insertion + outer 4-state; TWO insertions) |
| `.claude/agents/proj-code-reviewer.md` | Insert `### Wave Protocol (caller + shared module reads)` block after Pre-Review item 10 | Destructive (three-tier per insertion + outer 4-state) |
| `.claude/agents/code-writer-*.md` and `.claude/agents/proj-code-writer-*.md` (glob) | Insert code-writer Wave Protocol block (no `### Wave Protocol` heading; integrates into Before Writing flow) after Before Writing step 2 | Destructive (three-tier per insertion + outer 4-state) — glob deployment |
| `.claude/agents/test-writer-*.md` and `.claude/agents/proj-test-writer-*.md` (glob) | Insert `### Wave Protocol (test discovery)` block after Before Writing step 5 | Destructive (three-tier per insertion + outer 4-state) — glob deployment |
| Each patched agent file | Append `<!-- wave-gap-mcp-agnostic-installed -->` sentinel at EOF after both insertions succeed (debugger only after BOTH insertions) | Additive (one sentinel append per file) |

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { printf "ERROR: not a bootstrapped project — run full bootstrap first\n"; exit 1; }
[[ -d ".claude/agents" ]] || { printf "ERROR: .claude/agents/ missing — run full bootstrap first\n"; exit 1; }
[[ -d ".claude/rules" ]] || { printf "ERROR: .claude/rules/ missing — run full bootstrap first\n"; exit 1; }
[[ -f ".claude/rules/loopback-budget.md" ]] || { printf "ERROR: .claude/rules/loopback-budget.md missing — migration 050 must be applied first\n"; exit 1; }
[[ -f ".claude/rules/wave-iterated-parallelism.md" ]] || { printf "ERROR: .claude/rules/wave-iterated-parallelism.md missing — migration 053 must be applied first\n"; exit 1; }
command -v python3 >/dev/null 2>&1 || { printf "ERROR: python3 required\n"; exit 1; }

# Composed Forms prerequisite check (migration 052 must be applied first — composed loopback annotations
# in END_TO_END_FLOW wave blocks rely on the BNF grammar installed by 052).
if ! grep -q "^## Composed Forms" .claude/rules/loopback-budget.md 2>/dev/null; then
  printf "ERROR: .claude/rules/loopback-budget.md is missing the '## Composed Forms' section.\n"
  printf "       Apply migration 052 (loopback-budget-composed-forms) first; then re-run migration 054.\n"
  exit 2
fi
```

### Idempotency check (whole-migration)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Whole-migration idempotency: if every patched agent already carries the new sentinel,
# the migration is a no-op. Per-agent state is checked again inside migrate_agent() — this
# top-level check is a fast-exit for the all-applied case.

ALL_PATCHED=1
for agent in \
  .claude/agents/proj-researcher.md \
  .claude/agents/proj-plan-writer.md \
  .claude/agents/proj-debugger.md \
  .claude/agents/proj-code-reviewer.md \
  .claude/agents/code-writer-*.md \
  .claude/agents/proj-code-writer-*.md \
  .claude/agents/test-writer-*.md \
  .claude/agents/proj-test-writer-*.md; do
  [[ -f "$agent" ]] || continue
  if ! grep -q "wave-gap-mcp-agnostic-installed" "$agent" 2>/dev/null; then
    ALL_PATCHED=0
    break
  fi
done

if [[ "$ALL_PATCHED" -eq 1 ]]; then
  printf "SKIP: migration 054 already applied (all present agent files carry wave-gap-mcp-agnostic-installed sentinel)\n"
  exit 0
fi

printf "Applying migration 054: wave-protocol agent body blocks\n"
```

### Step 1 — Define heredocs and anchor map

The 7 wave block heredocs are defined inline. Six of seven (`RESEARCHER_WAVE_BLOCK`, `PLAN_WRITER_WAVE_BLOCK`, `CODE_WRITER_WAVE_BLOCK`, `TEST_WRITER_WAVE_BLOCK`, `DEBUGGER_WAVE_BLOCK`, `REVIEWER_WAVE_BLOCK`) carry the 9-U §3 escalation log placeholder amendment applied at migration-write time. `DEBUGGER_SOLVABLE_GATE_BLOCK` is unchanged from 8-S § 2 Block 6 (pre-wave classification block; no shape-escalation logic).

```bash
#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------------------------------------
# Block 1: RESEARCHER_WAVE_BLOCK
#   Source: gap-resolution-6-M lines 159–209 (researcher wave block)
#   Insertion: AFTER `6. No hard cap on tool calls — \`.claude/rules/max-quality.md\` §1 governs...`
#   Idempotency marker: `### Wave Protocol (codebase exploration)`
#   9-U §3 amendment APPLIED: escalation log placeholder upgraded.
# ----------------------------------------------------------------------
RESEARCHER_WAVE_BLOCK=$(cat <<'WAVE_BLOCK_EOF'
### Wave Protocol (codebase exploration)

**Step 1 — Classify task shape** before reading (see wave-iterated-parallelism.md §Task Shape → Default Cap):

| Shape | Prompt signal | Cap |
|---|---|---|
| SOLVABLE_FACT | "look up", "does X exist" | wave does not apply |
| SINGLE_LAYER | "list all", "enumerate", "find all handlers" | 2 |
| CALL_GRAPH | "who calls X", "callers of X" | 3 |
| END_TO_END_FLOW | "trace full flow", "from UI to DB", "across layers" | adaptive min=5, ceiling=10 |
| OPEN_INVESTIGATION | no explicit signal / generic investigation | 3 |

Record shape + initial cap: `TASK_SHAPE: {shape} | WAVE_CAP: {cap}`

**Step 2 — Wave 1** — batch ALL entry-point reads in one parallel message:
- Framework resolution mechanism (Configure(), route-table, DI registration)
- Primary module file + one representative file per detected architectural layer
- Any file explicitly named in dispatch prompt

Tool routing per mcp-routing.md Lead-With Order (cmm.search_graph → cmm.get_code_snippet → serena.find_referencing_symbols → serena.find_symbol).
No MCP available: Read known paths directly + Glob for entry-point patterns.
Transparent fallback disclosure required if MCP attempted + 0 hits.

**Step 3 — Gap Enumeration** after Wave 1 (per wave-iterated-parallelism.md §Gap-Check Checkpoint):

a) Emit structured gaps (GAP Dedup Requirement applies — see §GAP Dedup Requirement):
   `GAP: {layer|subsystem|call-target} (target: {file_path | symbol_qname}) — {reason: zero reads | unresolved reference | cross-subsystem dependency}`
   Each `target:` must be unique across all prior waves' targets. Dedup explicitly before emitting.

b) Shape Escalation check (per wave-iterated-parallelism.md §Shape Escalation):
   - SINGLE_LAYER gaps reference callers/callees/inheritance → upgrade to CALL_GRAPH (cap=3)
   - SINGLE_LAYER or CALL_GRAPH gaps cross subsystem boundaries → upgrade to END_TO_END_FLOW (adaptive min=5)
   - Log: `Shape upgraded {FROM}→{TO} after Wave 1 revealed {trigger} at {evidence: file:line | symbol-qname | file1:line + file2:line (cross-subsystem)}`
   - END_TO_END_FLOW is terminal — no further upgrades

c) If END_TO_END_FLOW: new layers discovered → update `WAVE_CAP: max(cap, waves_completed + 2)`
d) If gap list empty → skip Wave 2

**Step 4 — Wave N** (repeat until cap or no gaps) — batch reads targeting ONLY enumerated gaps:
- Layers with zero reads (from gap list)
- Unresolved call targets or referenced files not yet read
- Cross-subsystem boundary files

After each wave: re-apply gap enumeration (Steps 3a–3d).
After cap reached → proceed to synthesis. Document unresolved gaps in `## Open Questions` with `disposition: AGENT_DECIDED`.

<!-- RESOURCE-BUDGET: ceiling=10 + CONVERGENCE-QUALITY: signal=new-layer-discovered -->
<!-- For END_TO_END_FLOW shape. Fixed-pass shapes (SINGLE_LAYER/CALL_GRAPH/OPEN_INVESTIGATION)
     use pure RESOURCE-BUDGET (cost-driven exit at cap). See wave-iterated-parallelism.md. -->
WAVE_BLOCK_EOF
)

# ----------------------------------------------------------------------
# Block 2: PLAN_WRITER_WAVE_BLOCK
#   Source: gap-resolution-6-M lines 217–247 (plan-writer wave block)
#   Insertion: AFTER `2. Scan codebase for affected files + patterns (Grep/Glob)`
#   Idempotency marker: `### Wave Protocol (spec-to-codebase verification)`
#   9-U §3 amendment APPLIED: Shape Escalation prose corrected (caps at CALL_GRAPH per
#   8-S §6 doctrine — adaptive END_TO_END_FLOW does not apply to spec-reading) +
#   escalation log placeholder upgraded.
# ----------------------------------------------------------------------
PLAN_WRITER_WAVE_BLOCK=$(cat <<'WAVE_BLOCK_EOF'
### Wave Protocol (spec-to-codebase verification)

**Step 1 — Classify task shape:** plan-writer shape = SINGLE_LAYER by default (cap=2) unless spec explicitly covers cross-layer flow, in which case → CALL_GRAPH (cap=3).
Record: `TASK_SHAPE: SINGLE_LAYER | WAVE_CAP: 2`

**Step 2 — Wave 1** — batch reads in one parallel message:
- The spec file (collect all `## Components` entries)
- Every file path listed in `## Components` that resolves to a concrete path

Tool routing per mcp-routing.md Lead-With Order: verify symbol existence via cmm.search_graph before assuming a file contains what the spec claims.
No MCP available: Glob for file paths listed in spec; Read each found file.
Transparent fallback disclosure required if MCP attempted + 0 hits.

**Step 3 — Gap Enumeration** after Wave 1 (GAP Dedup Requirement applies):
`GAP: {component-name} (target: {file_path | symbol_qname}) — {reason: file-not-found | path-ambiguous | not-yet-read}`
Each `target:` must be unique across all prior waves' targets. Dedup before emitting.

Shape Escalation check: if gaps reveal cross-subsystem spec references not anticipated by SINGLE_LAYER classification → upgrade to CALL_GRAPH (cap=3).
Log: `Shape upgraded {FROM}→{TO} after Wave 1 revealed {trigger: cross-subsystem refs} at {evidence: file:line | symbol-qname | file1:line + file2:line (cross-subsystem)}`
If gap list empty → proceed to task breakdown (Wave 2 skipped).

**Step 4 — Wave 2** — resolve gaps:
- `file-not-found`: Glob to find actual file; if found → read; if not → `INSUFFICIENT_CONTEXT` in task
- `path-ambiguous`: read most likely candidate + confirm matches component intent
- `not-yet-read`: read the file

NEVER write a task that references a file not read during Wave 1 or Wave 2.
Unresolvable gaps → `INSUFFICIENT_CONTEXT` flag in task `#### Context` section.

<!-- RESOURCE-BUDGET: wave re-scan cap=2 (SINGLE_LAYER) or cap=3 (CALL_GRAPH) — see loopback-budget.md and wave-iterated-parallelism.md -->
WAVE_BLOCK_EOF
)

# ----------------------------------------------------------------------
# Block 3: CODE_WRITER_WAVE_BLOCK
#   Source: gap-resolution-6-M lines 253–286 (code-writer wave block)
#   Insertion: AFTER `2. Read target file if modifying | 2-3 similar files if creating`
#   Idempotency marker: `**Step 1 — Classify task shape:** code-writer shape = SINGLE_LAYER by default`
#   9-U §3 amendment APPLIED: escalation log placeholder upgraded with
#   {trigger: inheritance depth | cross-subsystem refs} + structured evidence schema.
#   Note: code-writer block has NO `### Wave Protocol` heading — integrates directly into
#   the Before Writing section flow (per 8-S § 2 Block 3 source note).
# ----------------------------------------------------------------------
CODE_WRITER_WAVE_BLOCK=$(cat <<'WAVE_BLOCK_EOF'
**Step 1 — Classify task shape:** code-writer shape = SINGLE_LAYER by default (cap=2). If task description mentions cross-layer impact (callers, shared module, interface change) → classify CALL_GRAPH (cap=3) immediately.
Record: `TASK_SHAPE: {shape} | WAVE_CAP: {cap}`

**Step 2 — Wave 1** — batch in one parallel message:
- Target file (if modifying) OR 2–3 most similar files (if creating)
- Direct imports/dependencies of the target file
- `.claude/rules/code-standards-{lang}.md` if present
- `.claude/skills/code-write/references/{lang}-analysis.md` for project patterns

Tool routing per mcp-routing.md Lead-With Order: use cmm.get_code_snippet for target symbol; serena.find_referencing_symbols for callers.
No MCP available: Read target file + 2–3 similar files + Grep for imports.
Transparent fallback disclosure required if MCP attempted + 0 hits.

**Step 3 — Gap Enumeration** after Wave 1 (GAP Dedup Requirement applies):
`GAP: {import|type|method} (target: {file_path | symbol_qname}) — unresolved: not found in Wave 1 reads`
Each `target:` must be unique across all prior waves' targets. Dedup before emitting.

Shape Escalation check: if gaps reveal callers/callees/inheritance of changed symbols → upgrade SINGLE_LAYER→CALL_GRAPH (cap=3). If gaps cross subsystem boundary → upgrade to END_TO_END_FLOW (adaptive min=5).
Log: `Shape upgraded {FROM}→{TO} after Wave 1 revealed {trigger: inheritance depth | cross-subsystem refs} at {evidence: file:line | symbol-qname | file1:line + file2:line (cross-subsystem)}`
If gap list empty → proceed to writing (Wave 2 skipped).

**Step 4 — Wave 2** — batch in one parallel message:
- Transitive dependencies: files defining unresolved types/methods from Wave 1
- Callers of function being modified (must remain compatible)

After Wave 2 → write. If type/method still unresolved → STOP:
`SCOPE EXPANSION NEEDED: {type/file} — cannot verify API without reading {path}`

<!-- RESOURCE-BUDGET: ceiling=10 + CONVERGENCE-QUALITY: signal=new-layer-discovered -->
<!-- For END_TO_END_FLOW only. SINGLE_LAYER (cap=2) and CALL_GRAPH (cap=3) use pure RESOURCE-BUDGET.
     See wave-iterated-parallelism.md. -->
WAVE_BLOCK_EOF
)

# ----------------------------------------------------------------------
# Block 4: TEST_WRITER_WAVE_BLOCK
#   Source: gap-resolution-6-M lines 293–324 (test-writer wave block)
#   Insertion: AFTER `5. Verify implementation code exists before writing tests against it`
#   Idempotency marker: `### Wave Protocol (test discovery)`
#   9-U §3 amendment APPLIED: bare `Log escalation.` upgraded with
#   {trigger: cross-subsystem refs} + structured evidence schema.
# ----------------------------------------------------------------------
TEST_WRITER_WAVE_BLOCK=$(cat <<'WAVE_BLOCK_EOF'
### Wave Protocol (test discovery)

**Step 1 — Classify task shape:** test-writer shape = SINGLE_LAYER (cap=2). Test tasks enumerate an existing implementation's API surface — one layer.
Record: `TASK_SHAPE: SINGLE_LAYER | WAVE_CAP: 2`

**Step 2 — Wave 1** — batch in one parallel message:
- Implementation file under test (verify public API surface + branches)
- 3–5 existing test files for the same module or adjacent modules
- `.claude/skills/code-write/references/{lang}-analysis.md` test-patterns section

Tool routing per mcp-routing.md Lead-With Order: cmm.search_graph for implementation symbols; serena.find_referencing_symbols to find existing test files that reference the implementation.
No MCP available: Read implementation file + Glob `tests/**/*{module_name}*` for test files.
Transparent fallback disclosure required if MCP attempted + 0 hits.

**Step 3 — Gap Enumeration** after Wave 1 (GAP Dedup Requirement applies):
`GAP: {pattern} (target: {file_path | symbol_qname}) — not yet seen in read tests (mocking | parametrize | fixture | async)`
Each `target:` must be unique across all prior waves' targets. Dedup before emitting.

Shape Escalation check: if gaps reveal that the implementation under test calls across subsystem boundaries → upgrade SINGLE_LAYER→CALL_GRAPH (cap=3).
Log: `Shape upgraded SINGLE_LAYER→CALL_GRAPH after Wave 1 revealed {trigger: cross-subsystem refs} at {evidence: file:line | symbol-qname | file1:line + file2:line (cross-subsystem)}` (END_TO_END_FLOW rare for test-writer; escalate only if implementation reaches multiple external services.)
If gap list empty → proceed to writing (Wave 2 skipped).

**Step 4 — Wave 2** — batch in one parallel message:
- Test files demonstrating each gap pattern (Glob test directory if needed)
- Additional branches/edge cases in implementation file not covered by Wave 1 read

After Wave 2 → write tests. NEVER mock a type not verified to exist in implementation.
If implementation file absent → STOP: `SCOPE EXPANSION NEEDED: {path} — source not found`

<!-- RESOURCE-BUDGET: wave re-scan cap=2 (SINGLE_LAYER) — see loopback-budget.md and wave-iterated-parallelism.md -->
WAVE_BLOCK_EOF
)

# ----------------------------------------------------------------------
# Block 5: DEBUGGER_WAVE_BLOCK
#   Source: gap-resolution-7-R Section 2 Block 2 (lines 103–144) — supersedes 6-M for debugger
#   Insertion: AFTER `3. Grep for related patterns, trace type relationships + call chains`
#   Idempotency marker: `### Wave Protocol (root-cause hunt)`
#   9-U §3 amendment APPLIED: `- CALL_GRAPH gaps cross subsystem boundary → ... Log escalation.`
#   upgraded with structured Log line.
# ----------------------------------------------------------------------
DEBUGGER_WAVE_BLOCK=$(cat <<'WAVE_BLOCK_EOF'
### Wave Protocol (root-cause hunt)

**Step 1 — Classify task shape:** debug tasks = CALL_GRAPH by default (cap=3). If error spans architectural layers (UI→service→DB) → classify END_TO_END_FLOW upfront (adaptive, min=5).
Record: `TASK_SHAPE: {shape} | WAVE_CAP: {cap}`

**Step 2 — Wave 1** — batch in one parallel message:
- Failing code file + immediate caller
- Error output / stack trace files (if available)
- Test file that surfaces the failure

MCP routing (3-state):
- State 1 (Full MCP — cmm+serena reachable): Lead-With cmm.search_graph → cmm.get_code_snippet
  → serena.find_referencing_symbols → serena.find_symbol (per mcp-routing.md Lead-With Order).
- State 2 (No MCP): Read failing file + Grep for error pattern in known directories.
- State 3 (Partial MCP — other servers present, no cmm/serena): text tools same as State 2.
Transparent fallback disclosure required if MCP attempted + 0 hits.

**Step 3 — Gap Enumeration** after Wave 1 (GAP Dedup Requirement applies):
- YES root cause identified → skip Wave N, proceed to diagnosis
- NO → emit gaps:
  `GAP: {call-chain node|shared dependency|config file} (target: {file_path | symbol_qname}) — not yet read, blocks root cause`
  Each `target:` must be unique across all prior waves' targets. Dedup before emitting.

Shape Escalation check (per wave-iterated-parallelism.md §Shape Escalation):
- CALL_GRAPH gaps cross subsystem boundary → upgrade to END_TO_END_FLOW (adaptive min=5).
  Log: `Shape upgraded CALL_GRAPH→END_TO_END_FLOW after Wave 1 revealed {trigger: cross-subsystem refs} at {evidence: file:line | symbol-qname | file1:line + file2:line (cross-subsystem)}`
- END_TO_END_FLOW is terminal.

If END_TO_END_FLOW: new layers discovered → update `WAVE_CAP: max(cap, waves_completed + 2)`.

**Step 4 — Wave N** (repeat until root cause identified or cap reached):
- Files in GAP list; shared utilities in failing call path; config files if misconfiguration indicated

After cap reached without root cause → apply SOLVABLE-GATE LSEC steps 4–5.
If still unresolved → return `UNRESOLVED: {read list, unknown gaps}`.

<!-- RESOURCE-BUDGET: ceiling=10 + CONVERGENCE-QUALITY: signal=new-layer-discovered -->
<!-- For END_TO_END_FLOW shape. CALL_GRAPH (cap=3) uses pure RESOURCE-BUDGET.
     See wave-iterated-parallelism.md and loopback-budget.md. -->
WAVE_BLOCK_EOF
)

# ----------------------------------------------------------------------
# Block 6: DEBUGGER_SOLVABLE_GATE_BLOCK
#   Source: gap-resolution-7-R Section 2 Block 1 (lines 63–101) — supersedes 6-M and 6-N
#   Insertion: BEFORE `## Self-Fix Protocol`
#   Idempotency marker: `## SOLVABLE-GATE`
#   9-U §3 amendment NOT APPLIED — this block is pre-wave classification (LSEC checklist) and
#   contains no shape-escalation logic. Per 9-U §3 audit table, this block is the only one
#   of the 7 that does NOT require the escalation log placeholder upgrade.
# ----------------------------------------------------------------------
DEBUGGER_SOLVABLE_GATE_BLOCK=$(cat <<'WAVE_BLOCK_EOF'
## SOLVABLE-GATE
Before returning any blocker to the caller, classify it using the Local Source Exhaustion
Checklist (LSEC). Applies to root-cause diagnosis, not fix application (this agent is
diagnosis-only — fix application is the caller's responsibility). "SOLVABLE" = root cause
is DIAGNOSABLE, not fixable.

**DIAGNOSABLE (continue hypothesis-elimination):** root cause is reachable from local sources.
Local sources — exhaust ALL in order before classifying as USER_DECIDES:
1. Failing file + its direct imports/callers (Process steps 2–3)
   MCP routing (3-state):
   - State 1 (Full MCP — cmm+serena reachable): Lead-With cmm.search_graph → cmm.get_code_snippet
     → serena.find_referencing_symbols → serena.find_symbol.
     Full routing policy in mcp-routing.md Lead-With Order (loaded in STEP 0).
   - State 2 (No MCP): Read failing file + Grep for related patterns in known directories.
   - State 3 (Partial MCP — other servers present, no cmm/serena): text tools same as State 2
     for code discovery; other MCP servers may be used per their own purpose.
   Transparent fallback disclosure required if MCP attempted + 0 hits on Step 1 discovery.
2. `CLAUDE.md` Gotchas section — known project-specific traps
3. `.learnings/log.md` — prior logged instances of this error class
4. Relevant rule file (e.g., `mcp-routing.md` for MCP errors, `general.md` for build errors)
5. Web search (mandatory after 2 failed hypothesis passes per `general.md`: "2 failed fix
   attempts → search web"; in diagnosis context: 2 failed hypothesis-elimination passes)

**USER_DECIDES (escalate):** root cause requires a value or decision only the user can provide.
Escalate IMMEDIATELY (skip LSEC, do not attempt hypothesis-elimination):
- Root cause requires credentials, API keys, or user-specific env vars to surface
- Conflicting spec requirements — two authoritative sources disagree; cannot pick without user
- External service down (HTTP 429/503, network unreachable)
- Architectural decision required (two contradicting implementation approaches, no evidence favors either)

Return: `disposition=USER_DECIDES` + evidence of why diagnosis is externally blocked.

NEVER classify as USER_DECIDES to avoid a second or third hypothesis-elimination pass.
Classification requires evidence that the diagnosis is externally blocked, not merely that
you have not yet identified the root cause.
WAVE_BLOCK_EOF
)

# ----------------------------------------------------------------------
# Block 7: REVIEWER_WAVE_BLOCK
#   Source: gap-resolution-6-M lines 405–439 (reviewer wave block)
#   Insertion: AFTER `10. Read \`.learnings/log.md\` — extract recurring bug patterns`
#   Idempotency marker: `### Wave Protocol (caller + shared module reads)`
#   9-U §3 amendment APPLIED: bare `Log escalation.` upgraded with
#   {trigger: cross-subsystem refs} + structured evidence schema.
# ----------------------------------------------------------------------
REVIEWER_WAVE_BLOCK=$(cat <<'WAVE_BLOCK_EOF'
### Wave Protocol (caller + shared module reads)

After completing items 1–10 above (Wave 1), enumerate caller coverage.

**Step 1 — Classify task shape:** review tasks = CALL_GRAPH by default (cap=3). Cap covers: changed files (Wave 1 items 1–10) + callers + shared modules. If review reveals changes span multiple subsystems → upgrade to END_TO_END_FLOW (adaptive min=5). Log escalation.
Record: `TASK_SHAPE: CALL_GRAPH | WAVE_CAP: 3`

**Step 2 — Gap Enumeration** after Wave 1 (items 1–10) (GAP Dedup Requirement applies):
For each function/method/symbol MODIFIED in the target file:
`GAP: {symbol} (target: {caller_file_path | caller_symbol_qname}) — has callers in {file(s)} not yet read`
Each `target:` must be unique across all prior waves' targets. Dedup before emitting.

Shape Escalation check: if callers exist in a different subsystem than the modified file → upgrade CALL_GRAPH→END_TO_END_FLOW (adaptive min=5).
Log: `Shape upgraded CALL_GRAPH→END_TO_END_FLOW after Wave 1 revealed {trigger: cross-subsystem refs} at {evidence: file:line | symbol-qname | file1:line + file2:line (cross-subsystem)}`

Tool routing per mcp-routing.md: `serena.find_referencing_symbols` is the canonical caller-discovery tool.
No MCP available: Grep for symbol name in source directories.
Transparent fallback disclosure required if MCP attempted + 0 hits.
If no callers found OR all callers already in Wave 1 reads → Wave 2 skipped.

**Step 3 — Wave 2** — batch in one parallel message:
- Files that CALL the modified symbols (callers)
- Shared modules referenced in target file not covered by Wave 1 items 1–10

**Step 4 — Wave 3** (CALL_GRAPH cap=3; END_TO_END_FLOW adaptive):
If Wave 2 gap enumeration reveals additional uncovered layers → batch reads for those layers.
Apply GAP Dedup: no target from Wave 1 or Wave 2 may reappear.

Report caller incompatibilities found in Wave 2/3 as `MUST FIX` items in review report.
Wave findings feed directly into `## 3. Review Checklist` impact assessment.

<!-- RESOURCE-BUDGET: ceiling=10 + CONVERGENCE-QUALITY: signal=new-layer-discovered -->
<!-- For END_TO_END_FLOW escalated reviews. Default CALL_GRAPH (cap=3) uses pure RESOURCE-BUDGET.
     See wave-iterated-parallelism.md. -->
WAVE_BLOCK_EOF
)

export RESEARCHER_WAVE_BLOCK PLAN_WRITER_WAVE_BLOCK CODE_WRITER_WAVE_BLOCK \
       TEST_WRITER_WAVE_BLOCK DEBUGGER_WAVE_BLOCK DEBUGGER_SOLVABLE_GATE_BLOCK REVIEWER_WAVE_BLOCK
```

### Step 2 — Define `apply_full_wave_section`, `apply_mcp_routing_diff`, and `apply_debugger_solvable_gate` functions

The `apply_full_wave_section` function dispatches per-agent based on filename, looks up the corresponding anchor + idempotency marker, and inserts the block. Anchor-fallback (stripped-prefix form) runs before deciding `SKIP_HAND_EDITED`. The `apply_mcp_routing_diff` function applies a minimal MCP-routing addition to an existing wave block (used for State 2 — old sentinel only, content otherwise unchanged). The `apply_debugger_solvable_gate` function handles the debugger's second insertion before `## Self-Fix Protocol`.

```bash
#!/usr/bin/env bash
set -euo pipefail

apply_full_wave_section() {
  local file="$1"
  local agent_name
  agent_name="$(basename "$file" .md)"

  python3 - "$file" "$agent_name" <<'PY'
import os, sys

file_path  = sys.argv[1]
agent_name = sys.argv[2]

with open(file_path, encoding="utf-8") as f:
    content = f.read()

# Per-agent anchor configuration.
# Each entry: (idempotency_marker, anchor_string, insert_side)
AGENT_CONFIG = {
    "proj-researcher": (
        "### Wave Protocol (codebase exploration)",
        "6. No hard cap on tool calls — `.claude/rules/max-quality.md` §1 governs. Run as many Reads/Greps/MCP queries as coverage requires. Parallel-batch per `<use_parallel_tool_calls>` for efficiency",
        "after",
    ),
    "proj-plan-writer": (
        "### Wave Protocol (spec-to-codebase verification)",
        "2. Scan codebase for affected files + patterns (Grep/Glob)",
        "after",
    ),
    "proj-code-reviewer": (
        "### Wave Protocol (caller + shared module reads)",
        "10. Read `.learnings/log.md` — extract recurring bug patterns",
        "after",
    ),
    "proj-debugger": (
        "### Wave Protocol (root-cause hunt)",
        "3. Grep for related patterns, trace type relationships + call chains",
        "after",
    ),
}

# code-writer-* and test-writer-* variants matched by prefix.
CODE_WRITER_CONFIG = (
    "**Step 1 — Classify task shape:** code-writer shape = SINGLE_LAYER by default",
    "2. Read target file if modifying | 2-3 similar files if creating",
    "after",
)
TEST_WRITER_CONFIG = (
    "### Wave Protocol (test discovery)",
    "5. Verify implementation code exists before writing tests against it",
    "after",
)

# Select config by exact-name then prefix-match.
if agent_name in AGENT_CONFIG:
    idempotency_marker, anchor, side = AGENT_CONFIG[agent_name]
elif agent_name.startswith("code-writer") or agent_name.startswith("proj-code-writer"):
    idempotency_marker, anchor, side = CODE_WRITER_CONFIG
elif agent_name.startswith("test-writer") or agent_name.startswith("proj-test-writer"):
    idempotency_marker, anchor, side = TEST_WRITER_CONFIG
else:
    print(f"ERROR: no anchor config for agent '{agent_name}' — cannot determine insertion point.", file=sys.stderr)
    sys.exit(1)

block_text = os.environ.get("_WAVE_BLOCK", "")
if not block_text:
    print("ERROR: _WAVE_BLOCK env var not set — caller must export the per-agent block before invoking.", file=sys.stderr)
    sys.exit(1)

# Tier 1: idempotency check (post-migration marker present)
if idempotency_marker in content:
    print(f"SKIP_ALREADY_APPLIED: {file_path} — wave block already present (idempotency marker '{idempotency_marker[:60]}' detected)")
    sys.exit(0)

# Tier 2: anchor verbatim text present (stock baseline) — safe to PATCH
# Tier 3: neither anchor nor idempotency marker present → SKIP_HAND_EDITED
# Anchor fallback: try exact anchor; on failure, try stripped form (no leading "N. " digits).
anchor_used = anchor
pos = content.find(anchor)
if pos == -1:
    anchor_stripped = anchor.lstrip("0123456789. ")
    if anchor_stripped != anchor and anchor_stripped:
        pos_stripped = content.find(anchor_stripped)
        if pos_stripped != -1:
            anchor_used = anchor_stripped
            pos = pos_stripped

if pos == -1:
    # Tier 3: file has been customized post-bootstrap.
    backup_path = file_path + ".bak-054"
    if not os.path.exists(backup_path):
        with open(backup_path, "w", encoding="utf-8") as bf:
            bf.write(content)
    print(f"SKIP_HAND_EDITED: {file_path} — anchor not found ('{anchor[:60]}...'). File has been customized post-bootstrap. Manual application required. See migrations/054-wave-protocol-agent-blocks.md §Manual-Apply-Guide for verbatim block content. Backup at {backup_path}.")
    sys.exit(0)

# Tier 2: PATCH — insertion using anchor_used
if side == "after":
    anchor_line_end = content.index(anchor_used) + len(anchor_used)
    newline_pos = content.find("\n", anchor_line_end)
    if newline_pos == -1:
        insert_pos = len(content)
        prefix = content
        suffix = ""
    else:
        insert_pos = newline_pos + 1
        prefix = content[:insert_pos]
        suffix = content[insert_pos:]
    patched = prefix + "\n" + block_text.strip("\n") + "\n\n" + suffix
elif side == "before":
    anchor_pos = content.index(anchor_used)
    line_start = content.rfind("\n", 0, anchor_pos)
    line_start = line_start + 1 if line_start != -1 else 0
    prefix = content[:line_start]
    suffix = content[line_start:]
    patched = prefix + block_text.strip("\n") + "\n\n" + suffix
else:
    print(f"ERROR: unknown insert_side '{side}'", file=sys.stderr)
    sys.exit(1)

# Write .bak-054 backup before destructive write (per .claude/rules/general.md §Migrations).
backup_path = file_path + ".bak-054"
if not os.path.exists(backup_path):
    with open(backup_path, "w", encoding="utf-8") as bf:
        bf.write(content)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(patched)

print(f"PATCHED: {file_path} — wave block inserted ({side} anchor '{anchor_used[:60]}...')")
PY
}

apply_mcp_routing_diff() {
  # Apply ONLY the MCP routing diff to an existing (pre-MCP-aware) wave section.
  # Used for State 2 (old sentinel `wave-gap-agent-body-installed` present, MCP-routing marker
  # absent). Does NOT re-insert the full wave block (that would double-patch).
  local file="$1"
  python3 - "$file" <<'PY'
import os, sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    content = f.read()

MARKER = "Tool routing per mcp-routing.md Lead-With Order"
if MARKER in content:
    print(f"SKIP_ALREADY_APPLIED: {path} — MCP routing marker already present")
    sys.exit(0)

# Insert MCP routing annotation after first "**Wave 1**" occurrence.
ROUTING_BLOCK = (
    "\nTool routing per mcp-routing.md Lead-With Order: cmm.search_graph → cmm.get_code_snippet"
    " → serena.find_referencing_symbols → serena.find_symbol.\n"
    "No MCP available: Read known paths directly + Grep/Glob for entry-point patterns.\n"
    "Transparent fallback disclosure required if MCP attempted + 0 hits.\n"
)
if "**Wave 1**" not in content:
    print(f"SKIP_HAND_EDITED: {path} — '**Wave 1**' anchor not found in existing wave block; manual apply required. See migrations/054-wave-protocol-agent-blocks.md §Manual-Apply-Guide.")
    sys.exit(0)

# Backup before destructive write.
backup_path = path + ".bak-054"
if not os.path.exists(backup_path):
    with open(backup_path, "w", encoding="utf-8") as bf:
        bf.write(content)

patched = content.replace("**Wave 1**", "**Wave 1**" + ROUTING_BLOCK, 1)
with open(path, "w", encoding="utf-8") as f:
    f.write(patched)
print(f"PATCHED: {path} — MCP routing diff applied (State 2 — old sentinel only)")
PY
}

apply_debugger_solvable_gate() {
  local file="$1"

  python3 - "$file" <<'PY'
import os, sys

file_path  = sys.argv[1]
IDEMPOTENCY_MARKER = "## SOLVABLE-GATE"
ANCHOR             = "## Self-Fix Protocol"

with open(file_path, encoding="utf-8") as f:
    content = f.read()

if IDEMPOTENCY_MARKER in content:
    print(f"SKIP_ALREADY_APPLIED: {file_path} — SOLVABLE-GATE already present")
    sys.exit(0)

if ANCHOR not in content:
    backup_path = file_path + ".bak-054"
    if not os.path.exists(backup_path):
        with open(backup_path, "w", encoding="utf-8") as bf:
            bf.write(content)
    print(f"SKIP_HAND_EDITED: {file_path} — '## Self-Fix Protocol' anchor not found. File has been customized post-bootstrap. Manual application required. See migrations/054-wave-protocol-agent-blocks.md §Manual-Apply-Guide §SOLVABLE-GATE. Backup at {backup_path}.")
    sys.exit(0)

block_text = os.environ.get("_SOLVABLE_GATE_BLOCK", "")
if not block_text:
    print("ERROR: _SOLVABLE_GATE_BLOCK env var not set.", file=sys.stderr)
    sys.exit(1)

# Insert BEFORE the '## Self-Fix Protocol' heading line
anchor_pos = content.index(ANCHOR)
line_start = content.rfind("\n", 0, anchor_pos)
line_start = line_start + 1 if line_start != -1 else 0
prefix = content[:line_start]
suffix = content[line_start:]
patched = prefix + block_text.strip("\n") + "\n\n" + suffix

# Backup before destructive write.
backup_path = file_path + ".bak-054"
if not os.path.exists(backup_path):
    with open(backup_path, "w", encoding="utf-8") as bf:
        bf.write(content)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(patched)

print(f"PATCHED: {file_path} — SOLVABLE-GATE inserted before '## Self-Fix Protocol'")
PY
}

export -f apply_full_wave_section apply_mcp_routing_diff apply_debugger_solvable_gate
```

### Step 3 — Define `migrate_agent` 4-state function and per-agent dispatch

The 4-state logic per gap-resolution-6-N R5-H6 handles all real-world client states. State 3 (fresh install) is the dominant case for new bootstraps. State 1 (new sentinel present) is the idempotency case on re-run. States 2 and 4 cover pre-merged clients carrying an older sentinel from a superseded migration.

```bash
#!/usr/bin/env bash
set -euo pipefail

OLD_SENTINEL="wave-gap-agent-body-installed"
NEW_SENTINEL="wave-gap-mcp-agnostic-installed"
VALIDATION_MARKER="Tool routing per mcp-routing.md Lead-With Order"

migrate_agent() {
  local agent_file="$1"
  local agent_name
  agent_name="$(basename "$agent_file" .md)"

  if [[ ! -f "$agent_file" ]]; then
    printf 'SKIP (absent): %s\n' "$agent_file"
    return 0
  fi

  local has_old has_new has_mcp_routing
  has_old=$(grep -q "$OLD_SENTINEL" "$agent_file" 2>/dev/null && printf 'yes' || printf 'no')
  has_new=$(grep -q "$NEW_SENTINEL" "$agent_file" 2>/dev/null && printf 'yes' || printf 'no')
  has_mcp_routing=$(grep -qF "$VALIDATION_MARKER" "$agent_file" 2>/dev/null && printf 'yes' || printf 'no')

  # State 1: NEW sentinel present → SKIP.
  if [[ "$has_new" == "yes" ]]; then
    printf 'SKIP (State 1 — new sentinel present): %s\n' "$agent_file"
    return 0
  fi

  # State 2 or State 4 — old sentinel present.
  if [[ "$has_old" == "yes" && "$has_new" == "no" ]]; then
    if [[ "$has_mcp_routing" == "yes" ]]; then
      # State 4: old sentinel + MCP routing already present (manual edit / intermediate patch).
      # Validate content; set new sentinel; SKIP re-patch.
      printf 'VALIDATE+SET (State 4 — old sentinel + MCP routing already present): %s\n' "$agent_file"
      printf '\n<!-- %s -->\n' "$NEW_SENTINEL" >> "$agent_file"
      return 0
    else
      # State 2: old sentinel only — apply MCP routing diff; set new sentinel.
      printf 'DIFF-ONLY (State 2 — old sentinel, MCP routing absent): %s\n' "$agent_file"
      apply_mcp_routing_diff "$agent_file"
      printf '\n<!-- %s -->\n' "$NEW_SENTINEL" >> "$agent_file"
      return 0
    fi
  fi

  # State 3: NEITHER sentinel present → fresh full install.
  if [[ "$has_old" == "no" && "$has_new" == "no" ]]; then
    printf 'FRESH INSTALL (State 3): %s\n' "$agent_file"

    # Per-agent dispatch — wire _WAVE_BLOCK based on agent name (glob prefix match for code-writer-*
    # and test-writer-* per .claude/rules/general.md "Migrations must glob agent filenames").
    case "$agent_name" in
      proj-researcher)
        export _WAVE_BLOCK="$RESEARCHER_WAVE_BLOCK"
        ;;
      proj-plan-writer)
        export _WAVE_BLOCK="$PLAN_WRITER_WAVE_BLOCK"
        ;;
      proj-debugger)
        export _WAVE_BLOCK="$DEBUGGER_WAVE_BLOCK"
        export _SOLVABLE_GATE_BLOCK="$DEBUGGER_SOLVABLE_GATE_BLOCK"
        ;;
      proj-code-reviewer)
        export _WAVE_BLOCK="$REVIEWER_WAVE_BLOCK"
        ;;
      code-writer-*|proj-code-writer-*)
        export _WAVE_BLOCK="$CODE_WRITER_WAVE_BLOCK"
        ;;
      test-writer-*|proj-test-writer-*)
        export _WAVE_BLOCK="$TEST_WRITER_WAVE_BLOCK"
        ;;
      *)
        printf 'WARN: unknown agent %s — no wave block defined; skipping\n' "$agent_name" >&2
        return 0
        ;;
    esac

    # Insertion 1 — Wave Protocol block (all agents)
    apply_full_wave_section "$agent_file"

    # Insertion 2 — debugger-only SOLVABLE-GATE block (must run AFTER Wave Protocol per
    # 7-Q § Section 5 order-of-operations rationale).
    if [[ "$agent_name" == "proj-debugger" ]]; then
      apply_debugger_solvable_gate "$agent_file"
      unset _SOLVABLE_GATE_BLOCK
    fi

    unset _WAVE_BLOCK

    # Append outer sentinel ONLY after both insertions (or single insertion for non-debugger) succeed.
    printf '\n<!-- %s -->\n' "$NEW_SENTINEL" >> "$agent_file"
    return 0
  fi

  # Unreachable: all 4 states covered above.
  printf 'WARN: unhandled state for %s (has_old=%s has_new=%s has_mcp_routing=%s)\n' \
    "$agent_file" "$has_old" "$has_new" "$has_mcp_routing" >&2
  return 0
}

export -f migrate_agent
```

### Step 4 — Main loop: invoke `migrate_agent` for each in-scope agent file

Glob deployment for `code-writer-*` and `test-writer-*` per `.claude/rules/general.md`. Fixed-name agents (`proj-researcher`, `proj-plan-writer`, `proj-debugger`, `proj-code-reviewer`) are processed first; then glob loops cover all language-specialist sub-agents.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Fixed-name agents (singletons)
for agent in \
  .claude/agents/proj-researcher.md \
  .claude/agents/proj-plan-writer.md \
  .claude/agents/proj-debugger.md \
  .claude/agents/proj-code-reviewer.md; do
  migrate_agent "$agent"
done

# code-writer-* glob (covers proj-code-writer-{lang} sub-specialists from /evolve-agents)
for agent in .claude/agents/code-writer-*.md .claude/agents/proj-code-writer-*.md; do
  [[ -f "$agent" ]] || continue
  migrate_agent "$agent"
done

# test-writer-* glob (covers proj-test-writer-{lang} sub-specialists from /evolve-agents)
for agent in .claude/agents/test-writer-*.md .claude/agents/proj-test-writer-*.md; do
  [[ -f "$agent" ]] || continue
  migrate_agent "$agent"
done

printf -- "---\n"
printf "Per-agent migration complete; running verification sweep.\n"
```

### Step 5 — `verify_all_agents` sweep

Per gap-resolution-7-Q § Section 6 contract: greps each patched agent for the outer sentinel + per-insertion idempotency marker + `Tool routing per mcp-routing.md Lead-With Order` validation marker. Debugger additionally checks `## SOLVABLE-GATE`. Any FAIL aborts before bootstrap-state.json update.

```bash
#!/usr/bin/env bash
set +e

NEW_SENTINEL="wave-gap-mcp-agnostic-installed"
VALIDATION_MARKER="Tool routing per mcp-routing.md Lead-With Order"

verify_all_agents() {
  local agents_dir="${1:-.claude/agents}"
  local fail=0
  local expected=0
  local actual=0

  declare -a AGENT_CHECKS=(
    "proj-researcher.md:${NEW_SENTINEL}:### Wave Protocol (codebase exploration):${VALIDATION_MARKER}"
    "proj-plan-writer.md:${NEW_SENTINEL}:### Wave Protocol (spec-to-codebase verification):${VALIDATION_MARKER}"
    "proj-debugger.md:${NEW_SENTINEL}:## SOLVABLE-GATE:### Wave Protocol (root-cause hunt):${VALIDATION_MARKER}"
    "proj-code-reviewer.md:${NEW_SENTINEL}:### Wave Protocol (caller + shared module reads):${VALIDATION_MARKER}"
  )

  # Fixed-name agent checks
  for check in "${AGENT_CHECKS[@]}"; do
    IFS=':' read -r -a parts <<< "$check"
    local glob="${parts[0]}"
    local agent_path="${agents_dir}/${glob}"

    if [[ ! -f "$agent_path" ]]; then
      printf 'SKIP (absent): %s\n' "$agent_path"
      continue
    fi

    (( expected++ )) || true
    local agent_fail=0

    for (( i=1; i<${#parts[@]}; i++ )); do
      local marker="${parts[$i]}"
      if ! grep -qF "$marker" "$agent_path" 2>/dev/null; then
        printf 'FAIL: %s — marker not found: %s\n' "$agent_path" "$marker"
        agent_fail=1
        fail=1
      fi
    done

    if [[ $agent_fail -eq 0 ]]; then
      printf 'PASS: %s\n' "$agent_path"
      (( actual++ )) || true
    fi
  done

  # code-writer-* glob check
  local cw_found=0
  for agent_path in "${agents_dir}"/code-writer-*.md "${agents_dir}"/proj-code-writer-*.md; do
    [[ -f "$agent_path" ]] || continue
    cw_found=1
    (( expected++ )) || true
    local agent_fail=0
    for marker in "$NEW_SENTINEL" \
                  "**Step 1 — Classify task shape:** code-writer shape = SINGLE_LAYER by default" \
                  "$VALIDATION_MARKER"; do
      if ! grep -qF "$marker" "$agent_path" 2>/dev/null; then
        printf 'FAIL: %s — marker not found: %s\n' "$agent_path" "$marker"
        agent_fail=1
        fail=1
      fi
    done
    [[ $agent_fail -eq 0 ]] && { printf 'PASS: %s\n' "$agent_path"; (( actual++ )) || true; }
  done
  [[ $cw_found -eq 0 ]] && printf 'SKIP (absent): no code-writer-*.md agents found\n'

  # test-writer-* glob check
  local tw_found=0
  for agent_path in "${agents_dir}"/test-writer-*.md "${agents_dir}"/proj-test-writer-*.md; do
    [[ -f "$agent_path" ]] || continue
    tw_found=1
    (( expected++ )) || true
    local agent_fail=0
    for marker in "$NEW_SENTINEL" \
                  "### Wave Protocol (test discovery)" \
                  "$VALIDATION_MARKER"; do
      if ! grep -qF "$marker" "$agent_path" 2>/dev/null; then
        printf 'FAIL: %s — marker not found: %s\n' "$agent_path" "$marker"
        agent_fail=1
        fail=1
      fi
    done
    [[ $agent_fail -eq 0 ]] && { printf 'PASS: %s\n' "$agent_path"; (( actual++ )) || true; }
  done
  [[ $tw_found -eq 0 ]] && printf 'SKIP (absent): no test-writer-*.md agents found\n'

  printf -- '---\n'
  printf 'Agents checked: %d expected, %d PASS\n' "$expected" "$actual"

  if [[ $fail -ne 0 ]]; then
    printf 'FAIL: wave protocol installation incomplete — see FAIL lines above\n'
    return 1
  else
    printf 'PASS: all present agents carry wave protocol markers\n'
    return 0
  fi
}

verify_all_agents ".claude/agents"
verify_status=$?

if [[ $verify_status -ne 0 ]]; then
  printf "ERROR: verify_all_agents reported FAIL — aborting before bootstrap-state.json update\n" >&2
  exit 1
fi
```

### Step 6 — Post-install amendment verification (9-U §3 zero-hits sweep)

Per gap-resolution-9-U §3 post-install verification snippet. Confirms no patched agent body retains a pre-amendment escalation log placeholder form (old condensed `revealed {evidence}`, bare `Log escalation.`, bare `Log escalation reason.`). The amendment was applied to the heredocs at migration-write time; this sweep is defense-in-depth confirming the heredocs were correctly amended.

```bash
#!/usr/bin/env bash
set +e

FAIL=0
for agent in \
  .claude/agents/proj-researcher.md \
  .claude/agents/proj-plan-writer.md \
  .claude/agents/proj-debugger.md \
  .claude/agents/proj-code-reviewer.md \
  .claude/agents/code-writer-*.md \
  .claude/agents/proj-code-writer-*.md \
  .claude/agents/test-writer-*.md \
  .claude/agents/proj-test-writer-*.md; do
  [[ -f "$agent" ]] || continue
  # Check for old condensed form (researcher pre-9-U-§3)
  if grep -q "revealed {evidence}" "$agent" 2>/dev/null; then
    printf 'ERROR: %s contains pre-amendment condensed escalation placeholder ("revealed {evidence}")\n' "$agent" >&2
    FAIL=1
  fi
  # Check for bare "Log escalation." without amended format
  if grep -qE "^[[:space:]]*Log escalation\.[[:space:]]*$" "$agent" 2>/dev/null; then
    printf 'ERROR: %s contains bare "Log escalation." without amended format\n' "$agent" >&2
    FAIL=1
  fi
  # Check for bare "Log escalation reason."
  if grep -qE "^[[:space:]]*Log escalation reason\.[[:space:]]*$" "$agent" 2>/dev/null; then
    printf 'ERROR: %s contains bare "Log escalation reason." without amended format\n' "$agent" >&2
    FAIL=1
  fi
done

if [[ "$FAIL" -eq 1 ]]; then
  printf "FAIL: pre-amendment escalation log placeholder found in agent bodies\n" >&2
  exit 3
fi
printf "OK: all agent bodies use amended escalation log format (9-U §3 verified)\n"
```

### Step 7 — Update `.claude/bootstrap-state.json`

Advance `last_migration` and append to `applied[]`.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '054'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '054') or a == '054' for a in applied):
    applied.append({
        'id': '054',
        'applied_at': state['last_applied'],
        'description': 'Install wave-protocol body blocks into 6 agent body types (researcher, plan-writer, debugger w/ extra SOLVABLE-GATE, code-reviewer, code-writer-* glob, test-writer-* glob). 4-state migration logic handles fresh / old-sentinel-only / new-sentinel-already-set / manual-edit. Sentinel: wave-gap-mcp-agnostic-installed. Prerequisite: composed-forms section in loopback-budget.md.'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=054')
PY
```

### Rules for migration scripts

- **Read-before-write** — every per-agent insertion reads the target file, runs three-tier detection, and only writes on the safe-patch tier. Destructive writes always create `.bak-054` backup before overwrite (per `.claude/rules/general.md` Migration Preservation Discipline).
- **Idempotent** — re-running prints `SKIP (State 1 — new sentinel present)` per agent and `SKIP: migration 054 already applied` at the top when all agent files carry the new sentinel.
- **Self-contained** — all 7 wave block heredocs inlined in bash here-docs; no external fetch. Sole external dependency is `python3` (used for anchor-targeted insertions).
- **No gitignored-path fetch** — migration body is fully inlined; nothing fetched from the bootstrap repo at runtime.
- **Glob agent filenames** — `code-writer-*` and `test-writer-*` are matched via shell glob, never hardcoded suffixes. Sub-specialists created by `/evolve-agents` are covered automatically (per `.claude/rules/general.md` Migrations rule).
- **Abort on error** — `set -euo pipefail` in every bash block; verification step (`verify_all_agents`) returns non-zero on any missing marker, aborting the migration before `bootstrap-state.json` update. Post-install amendment sweep (Step 6) returns exit 3 on any pre-amendment placeholder hit, also aborting.
- **Scope lock** — touches only: `.claude/agents/proj-researcher.md`, `.claude/agents/proj-plan-writer.md`, `.claude/agents/proj-debugger.md`, `.claude/agents/proj-code-reviewer.md`, `.claude/agents/code-writer-*.md`, `.claude/agents/proj-code-writer-*.md`, `.claude/agents/test-writer-*.md`, `.claude/agents/proj-test-writer-*.md`, `.claude/bootstrap-state.json`. No hook changes, no settings edits, no rule-file edits. `migrations/index.json` is appended BY MAIN THREAD outside this migration body (per `.claude/rules/agent-scope-lock.md`).
- **9-U §3 amendment baked in** — heredocs in Step 1 carry the corrected escalation log placeholder format. Step 6 sweep confirms no agent body retains pre-amendment text after install.

---

## Verify

```bash
#!/usr/bin/env bash
set +e
fail=0

NEW_SENTINEL="wave-gap-mcp-agnostic-installed"
VALIDATION_MARKER="Tool routing per mcp-routing.md Lead-With Order"

# 1. proj-researcher carries new sentinel + Wave Protocol heading + MCP routing marker
for marker in "$NEW_SENTINEL" "### Wave Protocol (codebase exploration)" "$VALIDATION_MARKER"; do
  if grep -qF "$marker" .claude/agents/proj-researcher.md 2>/dev/null; then
    printf "PASS: proj-researcher.md contains '%s'\n" "$marker"
  else
    printf "FAIL: proj-researcher.md missing '%s'\n" "$marker"
    fail=1
  fi
done

# 2. proj-plan-writer carries new sentinel + Wave Protocol heading + MCP routing marker
for marker in "$NEW_SENTINEL" "### Wave Protocol (spec-to-codebase verification)" "$VALIDATION_MARKER"; do
  if grep -qF "$marker" .claude/agents/proj-plan-writer.md 2>/dev/null; then
    printf "PASS: proj-plan-writer.md contains '%s'\n" "$marker"
  else
    printf "FAIL: proj-plan-writer.md missing '%s'\n" "$marker"
    fail=1
  fi
done

# 3. proj-debugger carries new sentinel + Wave Protocol heading + SOLVABLE-GATE + MCP routing marker
for marker in "$NEW_SENTINEL" "### Wave Protocol (root-cause hunt)" "## SOLVABLE-GATE" "$VALIDATION_MARKER"; do
  if grep -qF "$marker" .claude/agents/proj-debugger.md 2>/dev/null; then
    printf "PASS: proj-debugger.md contains '%s'\n" "$marker"
  else
    printf "FAIL: proj-debugger.md missing '%s'\n" "$marker"
    fail=1
  fi
done

# 4. proj-code-reviewer carries new sentinel + Wave Protocol heading + MCP routing marker
for marker in "$NEW_SENTINEL" "### Wave Protocol (caller + shared module reads)" "$VALIDATION_MARKER"; do
  if grep -qF "$marker" .claude/agents/proj-code-reviewer.md 2>/dev/null; then
    printf "PASS: proj-code-reviewer.md contains '%s'\n" "$marker"
  else
    printf "FAIL: proj-code-reviewer.md missing '%s'\n" "$marker"
    fail=1
  fi
done

# 5. code-writer-* glob: each present file carries new sentinel + code-writer Step 1 marker + MCP routing marker
cw_found=0
for agent in .claude/agents/code-writer-*.md .claude/agents/proj-code-writer-*.md; do
  [[ -f "$agent" ]] || continue
  cw_found=1
  for marker in "$NEW_SENTINEL" \
                "**Step 1 — Classify task shape:** code-writer shape = SINGLE_LAYER by default" \
                "$VALIDATION_MARKER"; do
    if grep -qF "$marker" "$agent" 2>/dev/null; then
      printf "PASS: %s contains '%s'\n" "$agent" "$marker"
    else
      printf "FAIL: %s missing '%s'\n" "$agent" "$marker"
      fail=1
    fi
  done
done
[[ $cw_found -eq 0 ]] && printf "SKIP (absent): no code-writer-*.md agents found\n"

# 6. test-writer-* glob: each present file carries new sentinel + test-writer Wave Protocol heading + MCP routing marker
tw_found=0
for agent in .claude/agents/test-writer-*.md .claude/agents/proj-test-writer-*.md; do
  [[ -f "$agent" ]] || continue
  tw_found=1
  for marker in "$NEW_SENTINEL" "### Wave Protocol (test discovery)" "$VALIDATION_MARKER"; do
    if grep -qF "$marker" "$agent" 2>/dev/null; then
      printf "PASS: %s contains '%s'\n" "$agent" "$marker"
    else
      printf "FAIL: %s missing '%s'\n" "$agent" "$marker"
      fail=1
    fi
  done
done
[[ $tw_found -eq 0 ]] && printf "SKIP (absent): no test-writer-*.md agents found\n"

# 7. 9-U §3 amendment verification — zero hits of old escalation log forms
for agent in \
  .claude/agents/proj-researcher.md \
  .claude/agents/proj-plan-writer.md \
  .claude/agents/proj-debugger.md \
  .claude/agents/proj-code-reviewer.md \
  .claude/agents/code-writer-*.md \
  .claude/agents/proj-code-writer-*.md \
  .claude/agents/test-writer-*.md \
  .claude/agents/proj-test-writer-*.md; do
  [[ -f "$agent" ]] || continue
  if grep -q "revealed {evidence}" "$agent" 2>/dev/null; then
    printf "FAIL: %s contains pre-amendment condensed placeholder ('revealed {evidence}')\n" "$agent"
    fail=1
  fi
  if grep -qE "^[[:space:]]*Log escalation\.[[:space:]]*$" "$agent" 2>/dev/null; then
    printf "FAIL: %s contains bare 'Log escalation.' without amended format\n" "$agent"
    fail=1
  fi
  if grep -qE "^[[:space:]]*Log escalation reason\.[[:space:]]*$" "$agent" 2>/dev/null; then
    printf "FAIL: %s contains bare 'Log escalation reason.' without amended format\n" "$agent"
    fail=1
  fi
done
[[ $fail -eq 0 ]] && printf "PASS: 9-U §3 amendment verification — no pre-amendment escalation placeholders\n"

# 8. bootstrap-state.json updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "054" ]]; then
  printf "PASS: last_migration = 054\n"
else
  printf "FAIL: last_migration = %s (expected 054)\n" "$last"
  fail=1
fi

printf -- "---\n"
if [[ $fail -eq 0 ]]; then
  printf "Migration 054 verification: ALL PASS\n"
  printf "\nOptional cleanup: remove .bak-054 backups once you've confirmed patches are correct:\n"
  printf "  find .claude/agents -name '*.bak-054' -delete\n"
else
  printf "Migration 054 verification: FAILURES — state NOT updated\n"
  exit 1
fi
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix.

---

## State Update

On success:
- `last_migration` → `"054"`
- append `{ "id": "054", "applied_at": "<ISO8601>", "description": "Install wave-protocol body blocks into 6 agent body types (researcher, plan-writer, debugger w/ extra SOLVABLE-GATE, code-reviewer, code-writer-* glob, test-writer-* glob). 4-state migration logic handles fresh / old-sentinel-only / new-sentinel-already-set / manual-edit. Sentinel: wave-gap-mcp-agnostic-installed. Prerequisite: composed-forms section in loopback-budget.md." }` to `applied[]`

---

## Idempotency

Re-running after success:
- Whole-migration top-level idempotency check — every agent already carries `wave-gap-mcp-agnostic-installed` sentinel → `SKIP: migration 054 already applied (all present agent files carry wave-gap-mcp-agnostic-installed sentinel)`.
- Per-agent: each `migrate_agent` call hits State 1 → `SKIP (State 1 — new sentinel present)`.
- Per-insertion (defense-in-depth): `apply_full_wave_section` and `apply_debugger_solvable_gate` both check the per-block idempotency marker before writing; both emit `SKIP_ALREADY_APPLIED` if the marker is present.
- `applied[]` dedup check (migration id == `'054'`) → no duplicate append.

No backups are rewritten on re-run. Files that were `SKIP_HAND_EDITED` on first apply remain `SKIP_HAND_EDITED` on re-run (anchor not found) — manual merge per `## Manual-Apply-Guide` is still required.

---

## Rollback

```bash
#!/usr/bin/env bash
set -euo pipefail

# Option A — restore from .bak-054 backups (written by the migration before each destructive edit)
for bak in \
  .claude/agents/proj-researcher.md.bak-054 \
  .claude/agents/proj-plan-writer.md.bak-054 \
  .claude/agents/proj-debugger.md.bak-054 \
  .claude/agents/proj-code-reviewer.md.bak-054 \
  .claude/agents/code-writer-*.md.bak-054 \
  .claude/agents/proj-code-writer-*.md.bak-054 \
  .claude/agents/test-writer-*.md.bak-054 \
  .claude/agents/proj-test-writer-*.md.bak-054; do
  [[ -f "$bak" ]] || continue
  orig="${bak%.bak-054}"
  mv "$bak" "$orig"
  printf "Restored: %s\n" "$orig"
done

# Option B — tracked strategy (if .claude/ is committed to project repo)
# git restore .claude/agents/

# Reset bootstrap-state.json
python3 <<'PY'
import json
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
if state.get('last_migration') == '054':
    state['last_migration'] = '053'
state['applied'] = [a for a in state.get('applied', []) if not (
    (isinstance(a, dict) and a.get('id') == '054') or a == '054'
)]
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State rolled back to last_migration=053')
PY
```

Notes:
- `.bak-054` restore is safe because the migration writes the backup before any destructive edit. Files that hit `SKIP_HAND_EDITED` (anchor not found) wrote a backup before reporting the skip — the rollback restores the original content.
- After rollback, the `<!-- wave-gap-mcp-agnostic-installed -->` sentinel appended at EOF on successfully-patched files is gone (the entire pre-migration content is restored from `.bak-054`). No manual sentinel removal needed.
- If no backup exists for a file, it was either `SKIP_ALREADY_APPLIED` (nothing to roll back — pre-existing post-migration state) or never touched (nothing to roll back).

---

## Post-Apply — Bootstrap Repo Self-Update

This migration targets client projects. The bootstrap repo's own `.claude/` copies are
generated output, not source of truth. To update the bootstrap repo's installed copies:
1. Run `/migrate-bootstrap` against the bootstrap repo itself, OR re-run each step manually against the bootstrap repo's `.claude/` (the templates at `templates/agents/proj-researcher.md`, `templates/agents/proj-plan-writer.md`, `templates/agents/proj-debugger.md`, `templates/agents/proj-code-reviewer.md`, `templates/agents/code-writer.template.md`, and `templates/agents/test-writer.template.md` are the source-of-truth templates — body changes go there, not into `.claude/`).
2. Do NOT directly edit any file in `.claude/agents/` in the bootstrap repo — direct edits bypass the templates and create drift.

Reference: `.claude/rules/general.md` §Process — "NEVER write to this repo's `.claude/` as implementation work."

---

## Manual-Apply-Guide

When a per-agent insertion reports `SKIP_HAND_EDITED: <path>`, the migration detected that the target file was customized post-bootstrap (anchor verbatim text not found) — automatic patching is unsafe. This guide provides the verbatim block content for each affected agent type plus merge instructions so you can manually integrate the wave protocol while preserving your customizations.

**General procedure per skipped step**:
1. Open the target agent file.
2. Locate the section / step described in the merge instructions for that agent type.
3. Copy the verbatim block content below for that agent type into the file at the specified location.
4. If you have customized the surrounding section (extra steps, custom comments, additional anchors), preserve your customizations and only insert the new wave block at the closest semantically-correct location.
5. Save the file.
6. Append the post-migration sentinel at EOF: `<!-- wave-gap-mcp-agnostic-installed -->`.
7. Re-run the migration's verification block to confirm all expected markers are present.
8. A `.bak-054` backup of the pre-migration file state exists at `<path>.bak-054`; use `diff <path>.bak-054 <path>` to see exactly what changed.

---

### §proj-researcher

**Target**: `.claude/agents/proj-researcher.md`
**Insertion side**: AFTER the line in Local Codebase Analysis numbered "6. No hard cap on tool calls — `.claude/rules/max-quality.md` §1 governs..." (or the equivalent line in your customized version that documents tool-cap policy in the codebase analysis section).

**New content (verbatim — insert as a new block on the line immediately after the anchor)**:

```markdown
### Wave Protocol (codebase exploration)

**Step 1 — Classify task shape** before reading (see wave-iterated-parallelism.md §Task Shape → Default Cap):

| Shape | Prompt signal | Cap |
|---|---|---|
| SOLVABLE_FACT | "look up", "does X exist" | wave does not apply |
| SINGLE_LAYER | "list all", "enumerate", "find all handlers" | 2 |
| CALL_GRAPH | "who calls X", "callers of X" | 3 |
| END_TO_END_FLOW | "trace full flow", "from UI to DB", "across layers" | adaptive min=5, ceiling=10 |
| OPEN_INVESTIGATION | no explicit signal / generic investigation | 3 |

Record shape + initial cap: `TASK_SHAPE: {shape} | WAVE_CAP: {cap}`

**Step 2 — Wave 1** — batch ALL entry-point reads in one parallel message:
- Framework resolution mechanism (Configure(), route-table, DI registration)
- Primary module file + one representative file per detected architectural layer
- Any file explicitly named in dispatch prompt

Tool routing per mcp-routing.md Lead-With Order (cmm.search_graph → cmm.get_code_snippet → serena.find_referencing_symbols → serena.find_symbol).
No MCP available: Read known paths directly + Glob for entry-point patterns.
Transparent fallback disclosure required if MCP attempted + 0 hits.

**Step 3 — Gap Enumeration** after Wave 1 (per wave-iterated-parallelism.md §Gap-Check Checkpoint):

a) Emit structured gaps (GAP Dedup Requirement applies — see §GAP Dedup Requirement):
   `GAP: {layer|subsystem|call-target} (target: {file_path | symbol_qname}) — {reason: zero reads | unresolved reference | cross-subsystem dependency}`
   Each `target:` must be unique across all prior waves' targets. Dedup explicitly before emitting.

b) Shape Escalation check (per wave-iterated-parallelism.md §Shape Escalation):
   - SINGLE_LAYER gaps reference callers/callees/inheritance → upgrade to CALL_GRAPH (cap=3)
   - SINGLE_LAYER or CALL_GRAPH gaps cross subsystem boundaries → upgrade to END_TO_END_FLOW (adaptive min=5)
   - Log: `Shape upgraded {FROM}→{TO} after Wave 1 revealed {trigger} at {evidence: file:line | symbol-qname | file1:line + file2:line (cross-subsystem)}`
   - END_TO_END_FLOW is terminal — no further upgrades

c) If END_TO_END_FLOW: new layers discovered → update `WAVE_CAP: max(cap, waves_completed + 2)`
d) If gap list empty → skip Wave 2

**Step 4 — Wave N** (repeat until cap or no gaps) — batch reads targeting ONLY enumerated gaps:
- Layers with zero reads (from gap list)
- Unresolved call targets or referenced files not yet read
- Cross-subsystem boundary files

After each wave: re-apply gap enumeration (Steps 3a–3d).
After cap reached → proceed to synthesis. Document unresolved gaps in `## Open Questions` with `disposition: AGENT_DECIDED`.

<!-- RESOURCE-BUDGET: ceiling=10 + CONVERGENCE-QUALITY: signal=new-layer-discovered -->
<!-- For END_TO_END_FLOW shape. Fixed-pass shapes (SINGLE_LAYER/CALL_GRAPH/OPEN_INVESTIGATION)
     use pure RESOURCE-BUDGET (cost-driven exit at cap). See wave-iterated-parallelism.md. -->
```

After insertion, append `<!-- wave-gap-mcp-agnostic-installed -->` at EOF.

---

### §proj-plan-writer

**Target**: `.claude/agents/proj-plan-writer.md`
**Insertion side**: AFTER the line in Process numbered "2. Scan codebase for affected files + patterns (Grep/Glob)" (or the equivalent line in your customized version).

**New content (verbatim)**:

```markdown
### Wave Protocol (spec-to-codebase verification)

**Step 1 — Classify task shape:** plan-writer shape = SINGLE_LAYER by default (cap=2) unless spec explicitly covers cross-layer flow, in which case → CALL_GRAPH (cap=3).
Record: `TASK_SHAPE: SINGLE_LAYER | WAVE_CAP: 2`

**Step 2 — Wave 1** — batch reads in one parallel message:
- The spec file (collect all `## Components` entries)
- Every file path listed in `## Components` that resolves to a concrete path

Tool routing per mcp-routing.md Lead-With Order: verify symbol existence via cmm.search_graph before assuming a file contains what the spec claims.
No MCP available: Glob for file paths listed in spec; Read each found file.
Transparent fallback disclosure required if MCP attempted + 0 hits.

**Step 3 — Gap Enumeration** after Wave 1 (GAP Dedup Requirement applies):
`GAP: {component-name} (target: {file_path | symbol_qname}) — {reason: file-not-found | path-ambiguous | not-yet-read}`
Each `target:` must be unique across all prior waves' targets. Dedup before emitting.

Shape Escalation check: if gaps reveal cross-subsystem spec references not anticipated by SINGLE_LAYER classification → upgrade to CALL_GRAPH (cap=3).
Log: `Shape upgraded {FROM}→{TO} after Wave 1 revealed {trigger: cross-subsystem refs} at {evidence: file:line | symbol-qname | file1:line + file2:line (cross-subsystem)}`
If gap list empty → proceed to task breakdown (Wave 2 skipped).

**Step 4 — Wave 2** — resolve gaps:
- `file-not-found`: Glob to find actual file; if found → read; if not → `INSUFFICIENT_CONTEXT` in task
- `path-ambiguous`: read most likely candidate + confirm matches component intent
- `not-yet-read`: read the file

NEVER write a task that references a file not read during Wave 1 or Wave 2.
Unresolvable gaps → `INSUFFICIENT_CONTEXT` flag in task `#### Context` section.

<!-- RESOURCE-BUDGET: wave re-scan cap=2 (SINGLE_LAYER) or cap=3 (CALL_GRAPH) — see loopback-budget.md and wave-iterated-parallelism.md -->
```

After insertion, append `<!-- wave-gap-mcp-agnostic-installed -->` at EOF.

---

### §proj-debugger (TWO insertions — Wave Protocol AND SOLVABLE-GATE)

**Target**: `.claude/agents/proj-debugger.md`
**Order**: insert Wave Protocol first, then SOLVABLE-GATE.

#### §proj-debugger — Insertion 1: Wave Protocol

**Insertion side**: AFTER the line in Process numbered "3. Grep for related patterns, trace type relationships + call chains".

**New content (verbatim)**:

```markdown
### Wave Protocol (root-cause hunt)

**Step 1 — Classify task shape:** debug tasks = CALL_GRAPH by default (cap=3). If error spans architectural layers (UI→service→DB) → classify END_TO_END_FLOW upfront (adaptive, min=5).
Record: `TASK_SHAPE: {shape} | WAVE_CAP: {cap}`

**Step 2 — Wave 1** — batch in one parallel message:
- Failing code file + immediate caller
- Error output / stack trace files (if available)
- Test file that surfaces the failure

MCP routing (3-state):
- State 1 (Full MCP — cmm+serena reachable): Lead-With cmm.search_graph → cmm.get_code_snippet
  → serena.find_referencing_symbols → serena.find_symbol (per mcp-routing.md Lead-With Order).
- State 2 (No MCP): Read failing file + Grep for error pattern in known directories.
- State 3 (Partial MCP — other servers present, no cmm/serena): text tools same as State 2.
Transparent fallback disclosure required if MCP attempted + 0 hits.

**Step 3 — Gap Enumeration** after Wave 1 (GAP Dedup Requirement applies):
- YES root cause identified → skip Wave N, proceed to diagnosis
- NO → emit gaps:
  `GAP: {call-chain node|shared dependency|config file} (target: {file_path | symbol_qname}) — not yet read, blocks root cause`
  Each `target:` must be unique across all prior waves' targets. Dedup before emitting.

Shape Escalation check (per wave-iterated-parallelism.md §Shape Escalation):
- CALL_GRAPH gaps cross subsystem boundary → upgrade to END_TO_END_FLOW (adaptive min=5).
  Log: `Shape upgraded CALL_GRAPH→END_TO_END_FLOW after Wave 1 revealed {trigger: cross-subsystem refs} at {evidence: file:line | symbol-qname | file1:line + file2:line (cross-subsystem)}`
- END_TO_END_FLOW is terminal.

If END_TO_END_FLOW: new layers discovered → update `WAVE_CAP: max(cap, waves_completed + 2)`.

**Step 4 — Wave N** (repeat until root cause identified or cap reached):
- Files in GAP list; shared utilities in failing call path; config files if misconfiguration indicated

After cap reached without root cause → apply SOLVABLE-GATE LSEC steps 4–5.
If still unresolved → return `UNRESOLVED: {read list, unknown gaps}`.

<!-- RESOURCE-BUDGET: ceiling=10 + CONVERGENCE-QUALITY: signal=new-layer-discovered -->
<!-- For END_TO_END_FLOW shape. CALL_GRAPH (cap=3) uses pure RESOURCE-BUDGET.
     See wave-iterated-parallelism.md and loopback-budget.md. -->
```

#### §proj-debugger — Insertion 2: SOLVABLE-GATE

**Insertion side**: BEFORE the heading `## Self-Fix Protocol`.

**New content (verbatim)**:

```markdown
## SOLVABLE-GATE
Before returning any blocker to the caller, classify it using the Local Source Exhaustion
Checklist (LSEC). Applies to root-cause diagnosis, not fix application (this agent is
diagnosis-only — fix application is the caller's responsibility). "SOLVABLE" = root cause
is DIAGNOSABLE, not fixable.

**DIAGNOSABLE (continue hypothesis-elimination):** root cause is reachable from local sources.
Local sources — exhaust ALL in order before classifying as USER_DECIDES:
1. Failing file + its direct imports/callers (Process steps 2–3)
   MCP routing (3-state):
   - State 1 (Full MCP — cmm+serena reachable): Lead-With cmm.search_graph → cmm.get_code_snippet
     → serena.find_referencing_symbols → serena.find_symbol.
     Full routing policy in mcp-routing.md Lead-With Order (loaded in STEP 0).
   - State 2 (No MCP): Read failing file + Grep for related patterns in known directories.
   - State 3 (Partial MCP — other servers present, no cmm/serena): text tools same as State 2
     for code discovery; other MCP servers may be used per their own purpose.
   Transparent fallback disclosure required if MCP attempted + 0 hits on Step 1 discovery.
2. `CLAUDE.md` Gotchas section — known project-specific traps
3. `.learnings/log.md` — prior logged instances of this error class
4. Relevant rule file (e.g., `mcp-routing.md` for MCP errors, `general.md` for build errors)
5. Web search (mandatory after 2 failed hypothesis passes per `general.md`: "2 failed fix
   attempts → search web"; in diagnosis context: 2 failed hypothesis-elimination passes)

**USER_DECIDES (escalate):** root cause requires a value or decision only the user can provide.
Escalate IMMEDIATELY (skip LSEC, do not attempt hypothesis-elimination):
- Root cause requires credentials, API keys, or user-specific env vars to surface
- Conflicting spec requirements — two authoritative sources disagree; cannot pick without user
- External service down (HTTP 429/503, network unreachable)
- Architectural decision required (two contradicting implementation approaches, no evidence favors either)

Return: `disposition=USER_DECIDES` + evidence of why diagnosis is externally blocked.

NEVER classify as USER_DECIDES to avoid a second or third hypothesis-elimination pass.
Classification requires evidence that the diagnosis is externally blocked, not merely that
you have not yet identified the root cause.
```

After BOTH insertions complete, append `<!-- wave-gap-mcp-agnostic-installed -->` at EOF.

---

### §proj-code-reviewer

**Target**: `.claude/agents/proj-code-reviewer.md`
**Insertion side**: AFTER the line in Pre-Review numbered "10. Read `.learnings/log.md` — extract recurring bug patterns" (or the equivalent line in your customized version).

**New content (verbatim)**:

```markdown
### Wave Protocol (caller + shared module reads)

After completing items 1–10 above (Wave 1), enumerate caller coverage.

**Step 1 — Classify task shape:** review tasks = CALL_GRAPH by default (cap=3). Cap covers: changed files (Wave 1 items 1–10) + callers + shared modules. If review reveals changes span multiple subsystems → upgrade to END_TO_END_FLOW (adaptive min=5). Log escalation.
Record: `TASK_SHAPE: CALL_GRAPH | WAVE_CAP: 3`

**Step 2 — Gap Enumeration** after Wave 1 (items 1–10) (GAP Dedup Requirement applies):
For each function/method/symbol MODIFIED in the target file:
`GAP: {symbol} (target: {caller_file_path | caller_symbol_qname}) — has callers in {file(s)} not yet read`
Each `target:` must be unique across all prior waves' targets. Dedup before emitting.

Shape Escalation check: if callers exist in a different subsystem than the modified file → upgrade CALL_GRAPH→END_TO_END_FLOW (adaptive min=5).
Log: `Shape upgraded CALL_GRAPH→END_TO_END_FLOW after Wave 1 revealed {trigger: cross-subsystem refs} at {evidence: file:line | symbol-qname | file1:line + file2:line (cross-subsystem)}`

Tool routing per mcp-routing.md: `serena.find_referencing_symbols` is the canonical caller-discovery tool.
No MCP available: Grep for symbol name in source directories.
Transparent fallback disclosure required if MCP attempted + 0 hits.
If no callers found OR all callers already in Wave 1 reads → Wave 2 skipped.

**Step 3 — Wave 2** — batch in one parallel message:
- Files that CALL the modified symbols (callers)
- Shared modules referenced in target file not covered by Wave 1 items 1–10

**Step 4 — Wave 3** (CALL_GRAPH cap=3; END_TO_END_FLOW adaptive):
If Wave 2 gap enumeration reveals additional uncovered layers → batch reads for those layers.
Apply GAP Dedup: no target from Wave 1 or Wave 2 may reappear.

Report caller incompatibilities found in Wave 2/3 as `MUST FIX` items in review report.
Wave findings feed directly into `## 3. Review Checklist` impact assessment.

<!-- RESOURCE-BUDGET: ceiling=10 + CONVERGENCE-QUALITY: signal=new-layer-discovered -->
<!-- For END_TO_END_FLOW escalated reviews. Default CALL_GRAPH (cap=3) uses pure RESOURCE-BUDGET.
     See wave-iterated-parallelism.md. -->
```

After insertion, append `<!-- wave-gap-mcp-agnostic-installed -->` at EOF.

---

### §code-writer-* (any language specialist)

**Target**: `.claude/agents/code-writer-{lang}.md` or `.claude/agents/proj-code-writer-{lang}.md` (any language: csharp, ts, python, etc.)
**Insertion side**: AFTER the line in Before Writing numbered "2. Read target file if modifying | 2-3 similar files if creating" (or the equivalent line in your customized version).

**New content (verbatim — note: NO `### Wave Protocol` heading; integrates directly into the Before Writing section flow)**:

```markdown
**Step 1 — Classify task shape:** code-writer shape = SINGLE_LAYER by default (cap=2). If task description mentions cross-layer impact (callers, shared module, interface change) → classify CALL_GRAPH (cap=3) immediately.
Record: `TASK_SHAPE: {shape} | WAVE_CAP: {cap}`

**Step 2 — Wave 1** — batch in one parallel message:
- Target file (if modifying) OR 2–3 most similar files (if creating)
- Direct imports/dependencies of the target file
- `.claude/rules/code-standards-{lang}.md` if present
- `.claude/skills/code-write/references/{lang}-analysis.md` for project patterns

Tool routing per mcp-routing.md Lead-With Order: use cmm.get_code_snippet for target symbol; serena.find_referencing_symbols for callers.
No MCP available: Read target file + 2–3 similar files + Grep for imports.
Transparent fallback disclosure required if MCP attempted + 0 hits.

**Step 3 — Gap Enumeration** after Wave 1 (GAP Dedup Requirement applies):
`GAP: {import|type|method} (target: {file_path | symbol_qname}) — unresolved: not found in Wave 1 reads`
Each `target:` must be unique across all prior waves' targets. Dedup before emitting.

Shape Escalation check: if gaps reveal callers/callees/inheritance of changed symbols → upgrade SINGLE_LAYER→CALL_GRAPH (cap=3). If gaps cross subsystem boundary → upgrade to END_TO_END_FLOW (adaptive min=5).
Log: `Shape upgraded {FROM}→{TO} after Wave 1 revealed {trigger: inheritance depth | cross-subsystem refs} at {evidence: file:line | symbol-qname | file1:line + file2:line (cross-subsystem)}`
If gap list empty → proceed to writing (Wave 2 skipped).

**Step 4 — Wave 2** — batch in one parallel message:
- Transitive dependencies: files defining unresolved types/methods from Wave 1
- Callers of function being modified (must remain compatible)

After Wave 2 → write. If type/method still unresolved → STOP:
`SCOPE EXPANSION NEEDED: {type/file} — cannot verify API without reading {path}`

<!-- RESOURCE-BUDGET: ceiling=10 + CONVERGENCE-QUALITY: signal=new-layer-discovered -->
<!-- For END_TO_END_FLOW only. SINGLE_LAYER (cap=2) and CALL_GRAPH (cap=3) use pure RESOURCE-BUDGET.
     See wave-iterated-parallelism.md. -->
```

After insertion, append `<!-- wave-gap-mcp-agnostic-installed -->` at EOF.

---

### §test-writer-* (any language specialist)

**Target**: `.claude/agents/test-writer-{lang}.md` or `.claude/agents/proj-test-writer-{lang}.md`
**Insertion side**: AFTER the line in Before Writing numbered "5. Verify implementation code exists before writing tests against it" (or the equivalent line in your customized version).

**New content (verbatim)**:

```markdown
### Wave Protocol (test discovery)

**Step 1 — Classify task shape:** test-writer shape = SINGLE_LAYER (cap=2). Test tasks enumerate an existing implementation's API surface — one layer.
Record: `TASK_SHAPE: SINGLE_LAYER | WAVE_CAP: 2`

**Step 2 — Wave 1** — batch in one parallel message:
- Implementation file under test (verify public API surface + branches)
- 3–5 existing test files for the same module or adjacent modules
- `.claude/skills/code-write/references/{lang}-analysis.md` test-patterns section

Tool routing per mcp-routing.md Lead-With Order: cmm.search_graph for implementation symbols; serena.find_referencing_symbols to find existing test files that reference the implementation.
No MCP available: Read implementation file + Glob `tests/**/*{module_name}*` for test files.
Transparent fallback disclosure required if MCP attempted + 0 hits.

**Step 3 — Gap Enumeration** after Wave 1 (GAP Dedup Requirement applies):
`GAP: {pattern} (target: {file_path | symbol_qname}) — not yet seen in read tests (mocking | parametrize | fixture | async)`
Each `target:` must be unique across all prior waves' targets. Dedup before emitting.

Shape Escalation check: if gaps reveal that the implementation under test calls across subsystem boundaries → upgrade SINGLE_LAYER→CALL_GRAPH (cap=3).
Log: `Shape upgraded SINGLE_LAYER→CALL_GRAPH after Wave 1 revealed {trigger: cross-subsystem refs} at {evidence: file:line | symbol-qname | file1:line + file2:line (cross-subsystem)}` (END_TO_END_FLOW rare for test-writer; escalate only if implementation reaches multiple external services.)
If gap list empty → proceed to writing (Wave 2 skipped).

**Step 4 — Wave 2** — batch in one parallel message:
- Test files demonstrating each gap pattern (Glob test directory if needed)
- Additional branches/edge cases in implementation file not covered by Wave 1 read

After Wave 2 → write tests. NEVER mock a type not verified to exist in implementation.
If implementation file absent → STOP: `SCOPE EXPANSION NEEDED: {path} — source not found`

<!-- RESOURCE-BUDGET: wave re-scan cap=2 (SINGLE_LAYER) — see loopback-budget.md and wave-iterated-parallelism.md -->
```

After insertion, append `<!-- wave-gap-mcp-agnostic-installed -->` at EOF.

---

### Verification (after manual apply)

Re-run the migration's verification block (`## Verify` section above) to confirm all expected markers landed. The verification greps each agent file for `wave-gap-mcp-agnostic-installed`, the per-agent Wave Protocol heading, and `Tool routing per mcp-routing.md Lead-With Order`. Debugger additionally requires `## SOLVABLE-GATE`. Any FAIL line indicates a still-missing marker — re-check the merge.

---

## Post-Migration (main-thread only per agent-scope-lock.md)

Append to `migrations/index.json`:
```json
{
  "id": "054",
  "file": "054-wave-protocol-agent-blocks.md",
  "description": "Install wave-protocol body blocks into 6 agent body types (researcher, plan-writer, debugger w/ extra SOLVABLE-GATE, code-reviewer, code-writer-* glob, test-writer-* glob). 4-state migration logic handles fresh / old-sentinel-only / new-sentinel-already-set / manual-edit. Sentinel: wave-gap-mcp-agnostic-installed. Prerequisite: composed-forms section in loopback-budget.md.",
  "breaking": false
}
```
