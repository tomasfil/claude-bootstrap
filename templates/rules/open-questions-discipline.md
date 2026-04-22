# Open Questions Discipline

## Rule
Surface every unresolved user-decidable question between research output and next step (design proposal, approach selection, spec, plan). Silent disposition = contract violation. Orchestrator MUST classify + state each question before advancing; deciding unilaterally without transparent classification is worse failure mode than asking.

## Disposition Vocabulary
- `USER_DECIDES` — blocking; no sane default; orchestrator MUST ask; forward progress halts until resolved
- `AGENT_RECOMMENDS` — default + rationale stated; user can veto in next turn; proceed if no veto
- `AGENT_DECIDED` — mechanical / previously-settled / constrained by other rules; stated transparently, never hidden

## Research Output Contract
`proj-researcher` findings MUST include `## Open Questions` section. Per-entry fields:
- `id` — stable identifier (OQ1, OQ2, ...)
- `question` — one-line statement of the judgment call
- `disposition` — one of USER_DECIDES | AGENT_RECOMMENDS | AGENT_DECIDED
- `evidence` — file:line citations OR "no prior art" if novel
- `recommendation?` — required if AGENT_RECOMMENDS; optional otherwise

No Open Questions identified → write `## Open Questions` section w/ "None identified" explicitly; empty omission = violation.

## Orchestrator Obligation
Before next step (Step 4 in /brainstorm, final-handoff in /deep-think, spec emission, plan write):
1. Read `## Open Questions` from research findings
2. Surface each verbatim w/ disposition classification
3. USER_DECIDES → BLOCK; ask user; no forward progress until resolved
4. AGENT_RECOMMENDS → state default + rationale; user vetoes in next turn or confirms by silence
5. AGENT_DECIDED → state transparently w/ reason; never omit
6. Legacy findings (no Open Questions section) → extract candidates yourself + classify per vocab; do NOT proceed w/ hidden triage

## Relationship to max-quality.md §6
"No hedging" ≠ "never ask". Silent disposition of user-decidable question is worse failure than asking. Heuristic:
- Solvable without user input → solve (no permission-seeking; §6 applies)
- Needs user judgment → ask explicitly w/ disposition classification (this rule applies)
Permission-seeking mid-task on solvable work = hedge. Surfacing a classified open question = healthy escalation.

## Relationship to techniques/agent-design.md
Inter-Agent Handoff Format carries `open_questions` field alongside existing `unresolved` — different semantics:
- `unresolved` — research-side failure (could not find answer; research-gap signal)
- `open_questions` — user-judgment required (healthy artefact; feeds orchestrator triage)
Both coexist. Writer agents consume `open_questions` post-triage; researchers originate it.

## Enforcement
- Force-read: STEP 0 of `proj-researcher`, `/brainstorm`, `/deep-think` (originators of research findings + orchestrators that consume them)
- Review-time catch: `/review` flags forward-progress (spec emission, plan write, code dispatch) after research findings without a preceding triage turn
- `.learnings/log.md`: violations logged as `correction` category → `/reflect` promotes recurring patterns into rule tightening
- No hook enforcement — too hard to detect mechanically; doctrine + force-read + review catch cover the failure mode
