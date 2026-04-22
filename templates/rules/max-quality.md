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

Clarification: "No hedging" ≠ "never ask". Silent disposition of a user-decidable
question is a worse failure mode than asking. Rule: solvable without user input →
solve; needs user decision → ask explicitly with disposition classification (see
`open-questions-discipline.md`). Permission-seeking mid-task ≠ asking a classified
open question; the former hedges on work you could do, the latter surfaces a judgment
call only the user can make.

## §7 Token Efficiency = INSTRUCTIONS only
`token-efficiency.md` applies to INSTRUCTIONS (agent bodies, rules, specs, plans,
memory files). It NEVER applies to OUTPUT (generated code, spec content, plan task
bodies, review findings, diagnosis reports, file contents written to disk).
Output completeness > token efficiency. A shorter-but-incomplete output is a worse
output, regardless of token savings. If forced to choose between fidelity and brevity
in deliverables → choose fidelity every time.
