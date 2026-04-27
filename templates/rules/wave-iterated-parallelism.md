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
