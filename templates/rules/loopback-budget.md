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

## Usage
- Annotate cap statement w/ HTML comment (canonical): `<!-- LOOPBACK-AUDIT: canonical label — see .claude/rules/loopback-budget.md -->` on the line above the cap statement
- Inline `# {LABEL}` comment form also passes A8 (substring match on label token) but HTML form is preferred — it survives prose rendering and does not collide w/ code-block `#` comments
- New retry/convergence logic in a skill MUST pick one of the 4 labels — do not invent a 5th
- `/audit-agents` scans `.claude/skills/*/SKILL.md` for retry/convergence prose w/o a canonical label → FAIL w/ file:line
- Extending policy (e.g. raising a cap) → keep the label; change the numeric value

## Rationale
Field observation: skill pack accumulated ad-hoc retry caps w/ inconsistent vocabulary ("cap 2", "loopback ≤2", "max retries", "convergence signal"). Single vocabulary lets `/audit-agents` enforce consistency mechanically, lets `/reflect` cluster loopback events by label, and gives skill authors a known palette when adding new loops.
