# Loopback Budget

## Rule
Every retry / convergence / resource cap in a skill MUST carry one of the 4 canonical labels. Labels are the single source of truth for loopback semantics across the skill pack. New caps without a canonical label → `/audit-agents` FAIL.

## Canonical Labels

### LOOPBACK-AUDIT
- **Where**: `/write-plan` Post-Dispatch Audit
- **Policy**: cap = 2 loopback attempts; HARD-FAIL on 3rd violation
- **Semantics**: re-dispatch plan-writer w/ corrective prompt; trust agent Self-Audit; do NOT pass broken plan to user

### SINGLE-RETRY
- **Where**: `/execute-plan` Batch Failure Handling
- **Policy**: per-batch failed task gets 1 SOLO retry; stop on 2nd fail
- **Semantics**: no re-batching; each retry = fresh context; STOP + report on solo fail

### CONVERGENCE-QUALITY
- **Where**: `/deep-think` Phase 4 adversarial critic loop
- **Policy**: iterate until 0 HIGH-severity gaps for 1 consecutive round OR cap hit
- **Semantics**: quality-driven exit (not count-driven); default cap=5 rounds, hard ceiling=10 via `--max-critic`

### RESOURCE-BUDGET
- **Where**: `/deep-think` Phase 1 pass cap, Phase 5 parallel-per-round cap, Phase 5 total-gap-resolution cap
- **Policy**: `MAX_PHASE1_PASSES=3`, `MAX_GAP_PARALLEL=3`, `MAX_GAP_TOTAL=15` (warn at 10)
- **Semantics**: cost-driven exit (token/dispatch budget); writes BELOW-THRESHOLD partial on exhaustion

## Composed Forms

A single annotation comment may combine two canonical labels using the `+` operator:

```
<!-- RESOURCE-BUDGET: ceiling=10 + CONVERGENCE-QUALITY: signal=new-layer-discovered -->
```

**Grammar:**
```
LOOPBACK_ANNOTATION := "<!--" SP LABEL_BLOCK ("+" SP LABEL_BLOCK)? SP "-->"
LABEL_BLOCK         := CANONICAL_LABEL ":" SP VALUE_LIST
CANONICAL_LABEL     := "RESOURCE-BUDGET" | "CONVERGENCE-QUALITY"
                     | "LOOPBACK-AUDIT" | "SINGLE-RETRY"
VALUE_LIST          := KV_PAIR ("," SP KV_PAIR)*
KV_PAIR             := KEY "=" VALUE
KEY                 := [a-zA-Z][a-zA-Z0-9_-]*
VALUE               := [A-Za-z0-9][A-Za-z0-9_-]*
SP                  := " " SP | ""
```

**Semantics of `+`:** both labels' constraints are active simultaneously at the same control point. Each is evaluated independently at every loop boundary; whichever exit condition fires first governs.

**Permitted pairs:**
- `RESOURCE-BUDGET + CONVERGENCE-QUALITY` — cost-ceiling + quality-extension (use for `END_TO_END_FLOW` adaptive loops)
- `RESOURCE-BUDGET + LOOPBACK-AUDIT` — cost-ceiling + correction-retry (use when a correction loop is embedded inside a budgeted outer loop)

**Forbidden pairs:**
- `SINGLE-RETRY + any` — SINGLE-RETRY is semantically exclusive (hard stop)
- `LOOPBACK-AUDIT + CONVERGENCE-QUALITY` — ambiguous dual-quality-exit
- Any three-label combination — decompose the loop instead. The grammar's `?` quantifier (zero-or-one) on the optional `("+" SP LABEL_BLOCK)` group enforces the two-label maximum at parse time.

**Canonical-4 invariant preserved:** composition uses existing labels only. No 5th label is introduced.

## Usage
- Annotate cap statement w/ HTML comment (canonical): `<!-- LOOPBACK-AUDIT: canonical label — see .claude/rules/loopback-budget.md -->` on the line above the cap statement
- Inline `# {LABEL}` comment form also passes A8 (substring match on label token) but HTML form is preferred — it survives prose rendering and does not collide w/ code-block `#` comments
- New retry/convergence logic in a skill MUST pick one of the 4 labels — do not invent a 5th. Composing 2 canonical labels via "+" (see "## Composed Forms" above) is NOT inventing a 5th; the canonical-4 set remains closed.
- /audit-agents scan (check A8): scans ".claude/skills/*/SKILL.md" for retry/convergence prose w/o any canonical label token → FAIL w/ file:line. Scan uses independent substring match per token — a comment containing RESOURCE-BUDGET + CONVERGENCE-QUALITY joined by + passes both token checks. Scan does NOT require a particular composition pair; presence of at least one canonical token suffices for PASS.
- Extending policy (e.g. raising a cap) → keep the label; change the numeric value

## Rationale
Field observation: skill pack accumulated ad-hoc retry caps w/ inconsistent vocabulary ("cap 2", "loopback ≤2", "max retries", "convergence signal"). Single vocabulary lets `/audit-agents` enforce consistency mechanically, lets `/reflect` cluster loopback events by label, and gives skill authors a known palette when adding new loops.
