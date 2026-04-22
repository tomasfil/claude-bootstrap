---
name: deep-think
description: >
  Use when a problem requires multi-pass adversarial ideation: parallel
  divergent exploration, evidence-gated shortlisting, deepening of top
  candidates, and iterative gap-hunting until no HIGH-severity critiques
  remain. Trigger on keywords "deeply think", "innovate", "improve",
  "upgrade", "research X thoroughly", or when /brainstorm feels
  insufficient for a genuinely uncertain/multi-layer problem. Dispatches
  proj-researcher across 7 phases including an adversarial critic loop.
argument-hint: "[topic] [--passes=N] [--max-critic=N] [--sequential] [--no-critic] [--quick]"
allowed-tools: Agent Read Write
model: opus
effort: high
# Skill Class: main-thread — multi-dispatch iterative orchestrator w/ interactive user-gate
---

## /deep-think — Multi-Pass Adversarial Gap-Hunting Ideation

Iteration IS the point. This skill finds edge cases, surfaces gaps, challenges assumptions, and researches those gaps until the solution is robust — not merely presentable. "Happy path shortlist" is a failure mode. Convergence = "adversarial critic found zero new HIGH-severity gaps for 1 consecutive round", not "user likes the shortlist".

Use `/brainstorm` for single-layer, requirements-clear, time-pressured work. Use `/deep-think` when the topic spans ≥2 architectural layers, is genuinely uncertain / innovative / upgrade-class, needs external prior-art validation, or `/brainstorm` already ran and was unsatisfying.

---

## Pre-flight (REQUIRED — before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

---

## Dispatch Map

| Phase | Role | Agent | Count |
|---|---|---|---|
| 0 | Evidence-first local scan | `proj-researcher` | 1 |
| 1 | Parallel divergent ideation (persona rotation) | `proj-researcher` | 5 (3 if `--quick`) |
| 2 | Evaluator scoring (separate context) | `proj-researcher` | 1 |
| 3 | Deepen top-N (Reflexion critique injected) | `proj-researcher` | 1–3 |
| 4 | Adversarial critic (gap hunt) | `proj-researcher` | 1 |
| 5 | Gap resolution (per resolvable HIGH gap) | `proj-researcher` | ≤3/round |

All dispatches use canonical form: `Dispatch agent via subagent_type="proj-researcher" w/ {task}`.

---

**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: dispatch `proj-quick-check` (simple) | `proj-researcher` (deep). Read directly ONLY for known exact path (Tier 1 per main-thread-orchestrator.md). MCP-indexed projects: named-symbol lookups MUST go through cmm.search_graph (see mcp-routing.md). Never built-in `Explore` / `general-purpose` / plugin.
See `techniques/agent-design.md § Agent Dispatch Policy`.

---

## Pre-flight Capability Checks

Before Phase 0, detect environment capability and set mode flags. Main thread performs these checks inline (no dispatch).

- **WebSearch available?** If `WebSearch` tool not present → set `WEB_AVAILABLE=false`. Phase 1/3/5 researchers will be told to operate in local-only mode and the external_score dimension of the evaluator rubric is zeroed (novelty penalty absorbed into feasibility).
- **MCP code-search available?** Check for `mcp__codebase-memory-mcp__*` or `mcp__serena__*` tools. If present → `MCP_SEARCH=true` and dispatch prompts instruct researchers to prefer MCP tools over raw Grep/Glob per `.claude/rules/mcp-routing.md`.
- **`.learnings/log.md` present?** If yes → include path in Phase 4 critic inputs. If no → omit from critic inputs.

Print detected mode to user in one line before Phase 0:
`Mode: web={on|off} mcp-search={on|off} learnings-log={on|off}`

---

## Argument Parsing

Parse args from `$ARGUMENTS` (topic string + flags). Defaults:

| Flag | Default | Effect |
|---|---|---|
| `--passes=N` | 1 | N extra Phase-1 passes with cumulative Reflexion critique (T5 trigger). Hard upper bound 3. |
| `--max-critic=N` | 5 | Override Phase 4 critic iteration cap. Hard upper bound 10. |
| `--sequential` | off | Phase 1 dispatches branches one at a time instead of parallel (rate-limit mitigation). |
| `--no-critic` | off | Skip Phase 4/5 entirely. WARNING: breaks core identity — print warning to user and require `yes` confirmation before proceeding. |
| `--quick` | off | 3 personas instead of 5; 4 proposals per branch instead of 6; skip web research in Phase 1; still run Phase 4 once. |

Topic = all non-flag arguments joined. If topic empty → ask user one question: "What topic should /deep-think explore?" and wait for reply.

---

## Iteration State Initialization

Main thread computes and remembers (no disk write — state lives in conversation):

```
topic         = {parsed topic}
branch        = {git branch name, default "main"}
date          = {YYYY-MM-DD today}
topic_slug    = {topic lowercased, spaces→-, strip punctuation, max 40 chars}
base_path     = .claude/specs/{branch}/{date}-{topic_slug}-deep-think/
proposals_path= .claude/specs/{branch}/{date}-{topic_slug}-proposals.md
spec_path     = .claude/specs/{branch}/{date}-{topic_slug}-spec.md

phase1_pass            = 0
critic_iteration       = 0
gap_resolution_total   = 0
MAX_PHASE1_PASSES      = 3
MAX_CRITIC             = {from --max-critic, default 5, hard cap 10}
MAX_GAP_PARALLEL       = 3
MAX_GAP_TOTAL          = 15

explored_angles_log    = []   # cumulative (persona, cluster) pairs from all Phase-1 passes
reflexion_critique     = ""   # populated from Phase 2 score breakdown before Phase 3 dispatch + cumulative after Phase 5
shortlist              = []   # populated after Phase 2
gap_register_path      = ""   # latest gap register path
```

Create `{base_path}` directory before Phase 0 via the Write tool (no bash `mkdir` — use Write with a placeholder `README.md` if directory creation needed, or rely on Write tool auto-creating parents).

---

## TaskCreate Gate (TASKCREATE_GATE_BLOCK)

Make the deep-think run observable in the harness task list before entering Phase 0. This gate runs ONCE per skill invocation, after iteration state is set and before any dispatch.

Run `ToolSearch("select:TaskCreate,TaskUpdate")` to load the TaskCreate / TaskUpdate schemas on demand.

If the ToolSearch returns matching tools:
- Compute `{phase_count}` = 7 (Phases 0 through 6 fully execute; Phase 7 is handoff-only). If `--no-critic` was passed, note `phase_count=5` (Phases 4 and 5 skipped).
- Compute `{persona_count}` = 5 by default, or 3 if `--quick` was passed, or whatever override comes from `references/personas.md`.
- Call `TaskCreate(subject=f"deep-think: {topic_slug}", description=f"Deep-think on {topic} — {phase_count} phases, {persona_count} personas")`.
- Then call `TaskUpdate(taskId=<returned-id>, status="in_progress", description=f"Phase 0: Evidence-First Local Scan")`.
- Remember the returned taskId in conversation state (`deepthink_task_id`) for the remainder of this skill run — it is referenced at the start of every subsequent phase and in the Phase 6 closeout.
- Set `TASK_TRACKING=true`.

If ToolSearch returns no schemas OR TaskCreate raises InputValidationError:
- Set `TASK_TRACKING=false`.
- Print one warning line: `TaskCreate unavailable — continuing without harness task tracking`.
- Continue to Phase 0 without creating any task entry.

Do NOT fail the skill run on ToolSearch failure; the gate is observability, not a blocker. On any mid-run abort / user-cancel / hard-fail (T7 structural flaw, critic cap reached, dispatch budget exhausted, user stop at Phase 2 gate, etc.), call `TaskUpdate(taskId=<id>, status="in_progress", description=f"Phase {N}: {phase-name}\n\nBLOCKED: {reason}")` instead of marking completed — leaving the status in_progress with a BLOCKED suffix surfaces the failure in the harness task list.

---

## Phase 0 — Evidence-First Local Scan

**Goal:** Ground truth before ideation. Prevent anchoring on hallucinated context.

**Dispatch:** 1 × `proj-researcher`, local-only (explicitly forbid WebSearch this phase).

Dispatch agent via `subagent_type="proj-researcher"` w/ the following prompt (fill `{topic}` and `{round0_path}` = `{base_path}/round-0-evidence.md`):

```
You are proj-researcher. Evidence-first local codebase analysis for:

TOPIC: {topic}

SCOPE: LOCAL CODEBASE ONLY. Do NOT perform web searches. This is a ground-truth
scan — the goal is to understand what already exists before any proposals exist.

REQUIRED READS (parallel where possible):
1. Architecture overview: CLAUDE.md, README, .claude/rules/*.md (skim — understand project type)
2. Topic-related files: Glob patterns matching the topic domain (read top 5 most relevant)
3. Related skills/agents: Grep for topic keywords in .claude/skills/ and .claude/agents/
4. Existing patterns: Grep for topic-related tooling in manifest files (package.json, *.csproj, pyproject.toml)

Prefer MCP code-search tools if available (codebase-memory-mcp, serena) over raw Grep/Glob — see .claude/rules/mcp-routing.md.

EXTRACT:
- What exists (cite file:line)
- What is absent (cite absence with evidence of negative search)
- Naming conventions, architectural patterns
- Investigation DIRECTIONS (not solutions) — angles worth exploring in Phase 1

OUTPUT FILE: {round0_path}
FORMAT: standard proj-researcher output (Summary / Patterns Detected / Conventions / Recommendations / Sources).

CRITICAL: Recommendations section contains ONLY investigation directions, NOT proposed solutions. Do not pre-empt Phase 1 ideation.

This is a bounded local scan only. Scope constraint: do not perform web searches; do not synthesize across multiple evidence sources; report factual findings only (file paths, frontmatter field values, line numbers, verbatim text). No synthesis, no inference.

Note: effort:high harness setting is preserved and continues to govern generation thoroughness. This instruction narrows task scope; it does not alter the effort level. Path verification and frontmatter integrity checks should be performed carefully.

Return ONLY: {path} — {1-sentence summary}
```

**After the dispatch returns:** read `round-0-evidence.md`. Assess complexity:
- topic spans 1 file OR 1 rule AND has an obvious answer → print:
  `Topic appears trivial — /brainstorm may be more appropriate. Continue /deep-think's full loop or switch? (continue/switch)`
  and wait for user reply. If `switch` → STOP, suggest running `/brainstorm` manually.
- otherwise → proceed to Phase 1.

---

## Phase 1 — Parallel Divergent Ideation

(TASK_TRACKING=true) `TaskUpdate(taskId=<id>, status="in_progress", description="Phase 1: Parallel Divergent Ideation")`

**Goal:** Generate 30 diverse candidate proposals across 5 persona angles (6 proposals × 5 personas). Maximize divergence. No scoring.

**Personas (default set — see `references/personas.md` for extended list):**
1. **rule engineer** — constraints, enforcement gates, anti-patterns
2. **agent designer** — dispatch shapes, scope contracts, new-agent needs
3. **skill author** — user-facing flow, argument hints, phase structure, UX
4. **migration author** — backward compat, idempotency, state, propagation
5. **skeptic** — what will fail, what is over-engineered, what existing pattern already solves this partially

Topic override: if topic touches hooks → swap persona 4 for "hook surgeon". Projects may extend the persona list via `.claude/skills/deep-think/references/personas.md`.

**Dispatch:** 5 × `proj-researcher` in **ONE message** (5 Agent calls in a single tool-use block — parallel-safe per `modules/07` local-research pattern). If `--sequential` flag → dispatch one at a time.

For each persona `branch_n ∈ 1..5`, dispatch agent via `subagent_type="proj-researcher"` w/ the per-branch prompt below (fill `{topic}`, `{persona_name}`, `{persona_role}`, `{round0_path}`, `{output_path}` = `{base_path}/round-1-branch-{N}.md`, `{branch_n}`, `{reflexion_critique_prior}`, `{explored_angles}`):

```
You are proj-researcher acting as {persona_name}.
PERSONA ROLE: {persona_role}

TOPIC: {topic}
PRIOR EVIDENCE (read BEFORE generating): {round0_path}
{if phase1_pass > 1: PRIOR REFLEXION CRITIQUE: {reflexion_critique_prior}}
{if phase1_pass > 1: EXPLORED ANGLES LOG (do NOT revisit): {explored_angles}}

DIVERGENT IDEATION TASK — Phase 1 Branch {branch_n}:
Generate EXACTLY 6 distinct proposals for the topic, approached exclusively from your persona angle.

RULES:
1. Read evidence file first. Do not propose what is already confirmed present.
2. Generate EXACTLY 6 proposals — not fewer, not more.
3. Each proposal MUST include:
   a. LOCAL EVIDENCE: codebase file path most relevant (or "NO LOCAL EVIDENCE")
   b. EXTERNAL URL: one URL supporting the technique (or "NO EXTERNAL URL")
   c. OPEN QUESTION: one thing this proposal does not yet resolve
4. Do NOT evaluate or rank. Diverge — maximize category spread.
5. Persona discipline: stay in your angle. Do not drift.
6. If this is iteration >1, address the reflexion critique and avoid explored angles.

OUTPUT FILE: {output_path}
FORMAT per proposal:
---
## Proposal {branch_n}.{i}: {short title}
**Angle:** {persona_name}
**Summary:** 2-3 sentences
**Mechanism:** logical steps (no pseudocode)
**Local evidence:** {file:line or "NO LOCAL EVIDENCE"}
**External evidence:** {URL or "NO EXTERNAL URL"}
**Open question:** {one unresolved thing}
---

Return ONLY: {path} — {N proposals, persona: {persona_name}}
```

**Error handling (per-branch, after all 5 return):** for each returned summary, main thread checks:
1. Does the output file exist? (Glob / Read check)
2. Does the summary contain `error:` keyword?
3. Does the file contain ≥1 `## Proposal` marker?

If a branch fails any check → log `branch {N} failed: {reason}` in iteration state and re-dispatch that ONE branch solo once (same prompt, same persona). If solo retry fails → proceed with remaining branches. If **fewer than 3 branches succeed** after retries → STOP, print the failure summary to the user, do not proceed to Phase 2.

Increment `phase1_pass += 1`. `--quick` mode: 3 personas (rule engineer, skill author, skeptic) × 4 proposals = 12 candidates.

**Output artifacts:** `round-1-branch-{1..5}.md` (30 proposals total in default mode).

---

## Phase 2 — Evaluator Scoring + Clustering + Shortlist

(TASK_TRACKING=true) `TaskUpdate(taskId=<id>, status="in_progress", description="Phase 2: Evaluator Scoring + Clustering + Shortlist")`

**Goal:** Score all proposals without echo-chamber, cluster to detect duplicates, produce ranked shortlist for user gate.

**Echo-chamber mitigation:** dispatch a **SEPARATE evaluator researcher**. The evaluator reads branch files and scores WITHOUT reading main-thread analysis. Main thread reconciles evaluator output with its own cluster assessment.

Dispatch agent via `subagent_type="proj-researcher"` w/ the following EVALUATOR ROLE prompt (fill `{round0_path}`, branch-file list, `{output_path}` = `{base_path}/evaluator-scores.md`):

```
You are proj-researcher in EVALUATOR ROLE. Your job: score, not generate.

INPUTS — read all branch files:
{list of round-1-branch-{1..5}.md paths}

ALSO read: {round0_path} for ground-truth context.

SCORING RUBRIC per proposal (apply to every proposal across all branches):

local_score     = min(5, count(distinct_local_citations))
external_score  = min(5, 3 × count(distinct_external_URLs))   # 1 URL = 3/5
novelty_score:
  - Read all proposal titles.
  - For each proposal, count how many OTHER proposals share ≥3 consecutive words in title.
  - novelty_score = max(0, 5 − 2 × overlap_count).
  - If iteration >1, also compare against prior-iteration titles from {explored_angles_log} — cumulative overlap increases penalty.
feasibility_score (rubric-anchored judgment):
  5 = change contained to files already identified in round-0 evidence; no new agents/tools
  4 = 1 new file (skill or agent); no new MCP tools
  3 = 2-3 new files; touches 2+ existing skills; or requires new rule
  2 = new migration + module update + backport; multi-file coordinated change
  1 = new external dependency or unconfirmed Claude Code feature
  0 = outside topic scope OR requires something confirmed absent

total = (0.3 × local) + (0.2 × external) + (0.2 × novelty) + (0.3 × feasibility)
Range: 0–5.

EVIDENCE GATE (scoring, NOT hard-kill):
- NO LOCAL EVIDENCE + NO EXTERNAL URL → local_score=0, external_score=0, ADD penalty −0.5 to total.
- Proposals with penalty total < 0.5 after scoring → flagged as "disqualified" but NOT removed from output.

CITATION FAITHFULNESS SPOT-CHECK:
- For the TOP-SCORING proposal after initial scoring:
  - Read the cited local file; does it actually support the proposal's claim?
  - If URL cited: check URL format validity + domain plausibility.
- If spot-check fails: downgrade total by −1.0; add "FAITHFULNESS FAIL" flag.
- 1 spot-check per evaluation pass is sufficient.

OUTPUT FILE: {output_path}
FORMAT:
# Evaluator Scores — Iteration {N}
## Scored Proposals (sorted by total desc)
| # | Branch | Title | Local | Ext | Nov | Feas | Total | Flags |
|---|---|---|---|---|---|---|---|---|
(one row per proposal — score every proposal, do not skip)
## Faithfulness Spot-Check
- Proposal checked: {title}
- Result: PASS / FAIL ({reason})
## Notes
- Any scoring edge cases or uncertainty flags

Return ONLY: {path} — {N scored, K flagged, M disqualified}
```

**Main-thread clustering (after evaluator returns, no dispatch):**

1. Read `evaluator-scores.md`.
2. Group proposals where local_file path shares ≥2 path components (e.g., all `.claude/skills/*/SKILL.md` → cluster `skill-authoring`).
3. Proposals with NO LOCAL EVIDENCE → cluster `novel/unanchored`.
4. Within each cluster, detect duplicates: titles differing by ≤3 words → keep the higher-scored proposal, merge citations from the duplicate into the winner, increment merge count.
5. Assign a cluster label to each surviving proposal.

**Shortlist selection:** top 3 proposals by total score that pass the evidence gate (not disqualified). If fewer than 3 survive → trigger T1 loop (see loop-trigger table in §12).

**Compaction checkpoint — write `shortlist.md` to disk BEFORE any further dispatch.** This is the recovery point if the session compacts mid-run. Write via the `Write` tool to `{base_path}/shortlist.md`:

```
# Phase 2 Shortlist — {topic}
**Iteration:** {N} | **Scored:** {total} | **Clusters surviving:** {K} | **Shortlist size:** {M}
**Source:** evaluator-scores.md
**Saved:** {date}

## Shortlisted Proposals
| # | Title | Cluster | Total | Local | External | Origin |
|---|---|---|---|---|---|---|
| 1 | ... | ... | 4.2 | 5 | 3 | round-1-branch-2.md §2.4 |
| 2 | ... | ... | 3.9 | ... | ... | ... |
| 3 | ... | ... | 3.7 | ... | ... | ... |

## Disqualified
- {N} proposals below evidence gate
## Merged Duplicates
- {M} pairs — list with winner / loser titles
## Next
- Awaiting user approval before Phase 3 dispatch.
```

**User gate — imperative framing, not permission-seeking.** Print to conversation (not as AskUserQuestion — conversational gate per `/brainstorm` precedent):

```
## Phase 2 Shortlist — {topic}
Iteration {N} | {total} proposals scored | {K} cluster-surviving | {M} in shortlist

| # | Title | Local Evidence | External | Score | Cluster |
|---|---|---|---|---|---|
| 1 | ... | ... | ... | 4.2/5 | skill-authoring |
| 2 | ... | ... | ... | 3.9/5 | rule-enforcement |
| 3 | ... | ... | ... | 3.7/5 | migration |

Disqualified: {N} (below evidence threshold)
Merged duplicates: {M} pairs
Recovery checkpoint: {base_path}/shortlist.md

Review the shortlist. Remove any proposal by number (e.g. "drop 2") or approve all ("all").
I will proceed with the approved subset to Phase 3 deepening. If fewer than 2 remain, I will loop back to Phase 1 automatically.
```

Wait for natural turn-based user reply. Parse drop list, update `shortlist`, proceed.

**Loop trigger checks after Phase 2 (before Phase 3 dispatch):**

| Trigger | Fires if | Action |
|---|---|---|
| T1 | `len(shortlist) < 2` after evidence gate | Re-run Phase 1 with broadened scope (`phase1_pass += 1`, up to `MAX_PHASE1_PASSES`) |
| T2 | `max(scores) < 2.5/5` | Re-run Phase 1 with critique injection (notify user first) |
| T3 | All shortlisted cluster-identical (0 diversity) | Re-run Phase 1 excluding dominant cluster |
| T4 | Evidence density < floor after Phase 3 (checked later) | Re-run Phase 0 with broader scope |
| T5 | User passed `--passes=N` | Extra Phase-1 passes with cumulative Reflexion critique |

Priority: T1 > T2 > T3. If `phase1_pass >= MAX_PHASE1_PASSES` → proceed with what survives.

**Output artifacts:** `evaluator-scores.md`, `shortlist.md`.

---

## Phase 3 — Deepen Top-N (Reflexion-style)

(TASK_TRACKING=true) `TaskUpdate(taskId=<id>, status="in_progress", description="Phase 3: Deepen Top-N (Reflexion-style)")`

**Goal:** Targeted evidence expansion per shortlisted candidate. Find integration points, hidden risks, prior-art specifics.

**Reflexion critique construction (main thread, before dispatch, per candidate):** derived from Phase 2 score breakdown. Rules:
- Score < 3/5 in any dimension → append: `weakness: {dimension} scored {X}; strengthen by {targeted action}`
- Feasibility < 3 → name specific unclear integration points from the cluster label
- Novelty < 3 → note which other proposals overlap (by title)

Store the per-candidate critique string into `reflexion_critique[candidate_id]`.

**Dispatch:** 1–3 parallel `proj-researcher` (one per shortlisted candidate — parallel-safe, ONE message, N Agent calls).

For each shortlisted candidate, dispatch agent via `subagent_type="proj-researcher"` w/ the per-candidate prompt below (fill `{topic}`, `{proposal_title}`, `{proposal_summary}`, `{cluster_label}`, `{round0_path}`, `{round1_branch_path}`, `{proposal_section}`, `{critique_text}`, `{open_q}`, `{output_path}` = `{base_path}/deepen-{candidate_slug}.md`):

```
You are proj-researcher — TARGETED DEEP-DIVE role.

TOPIC: {topic}
CANDIDATE: {proposal_title}
CANDIDATE SUMMARY: {proposal_summary}
CLUSTER: {cluster_label}

CONTEXT (read before starting):
- Prior evidence: {round0_path}
- Proposal origin: {round1_branch_path} §{proposal_section}

REFLEXION CRITIQUE FROM PHASE 2:
{critique_text}

YOUR TASK — deepen this candidate. Concrete sub-questions:
1. LOCAL EVIDENCE EXPANSION: find 3+ distinct file paths confirming or contextualizing the proposal. Read them.
2. INTEGRATION MAP: every file that must change if the proposal is implemented. Include: call sites, shared conventions, rule files, agent frontmatter, skill dispatch maps, CLAUDE.md gotchas, migration-list entries.
3. HIDDEN RISKS: what could break? Check: existing tests, rule conflicts, scope-lock violations, convention mismatches. file:line for each risk.
4. PRIOR ART (web, targeted): search for the specific technique named. Max 2 search rounds. Implementation examples, known pitfalls, version requirements.
5. OPEN QUESTION RESOLUTION: the proposal's open question was "{open_q}" — resolve it with evidence.

OUTPUT FILE: {output_path}
FORMAT (extends standard researcher output):
# Deepen: {candidate title}
**Phase 2 score:** {score}/5 | local:{x} ext:{y} nov:{z} feas:{w}

## Summary (3–5 bullets — what found, what resolved, what remains uncertain)
## Local Evidence (expanded) — ≥3 entries with file:line
## Integration Map — table: file | required change | dependency
## Risk Register — table: risk | severity | file:line
## External Evidence (targeted) — URL | finding
## Open Question Resolution — answered OR "UNRESOLVED: {why}"
## Feasibility Revised — {new score}/5 | justification

Return ONLY: {path} — {N local citations, M risks, open-q status}
```

After all deepen researchers return, main thread reads each `deepen-*.md`. If T4 fires (evidence density below floor: < 3 local citations across all deepen files combined) → loop back to Phase 0 with broader scope.

**Output artifacts:** `deepen-{slug}.md` per shortlisted candidate.

---

## Phase 4 — Adversarial Gap Hunt

(TASK_TRACKING=true) `TaskUpdate(taskId=<id>, status="in_progress", description="Phase 4: Adversarial Gap Hunt")`

**Goal:** Core identity of this skill. Find edge cases, failure modes, hidden assumptions, unstated dependencies, and structural breakage in each deepened proposal. Not just "does it work on happy path" — "what breaks it".

**Dispatch:** 1 × `proj-researcher` in ADVERSARIAL-CRITIC role.

Dispatch agent via `subagent_type="proj-researcher"` w/ the following prompt (fill `{round0_path}`, `{shortlist_path}`, deepen-file list, `{explored_angles_log}`, `{iteration_n}` = `critic_iteration + 1`, `{output_path}` = `{base_path}/gap-register-{iteration_n}.md`):

```
You are proj-researcher — ADVERSARIAL CRITIC role. You are a skeptical reviewer
looking for gaps. Assume each proposal is WRONG until proven right. Find what the
prior analysis MISSED.

INPUTS — read all:
- Round 0 evidence: {round0_path}
- Phase 2 shortlist: {shortlist_path}
- Phase 3 deepen files: {list of deepen-*.md}
- Relevant rules: .claude/rules/max-quality.md, .claude/rules/agent-scope-lock.md, .claude/rules/mcp-routing.md
- This project's anti-pattern memory: .learnings/log.md (if exists)
- Explored angles log (prior iterations): {explored_angles_log}

FOR EACH shortlisted proposal, answer these adversarial questions:

1. EDGE CASES: what inputs/conditions break this proposal? Name 3 concrete edge cases with file:line or scenario evidence.
2. HIDDEN ASSUMPTIONS: what is this proposal assuming without verification? (e.g. "assumes agent X exists", "assumes WebSearch available", "assumes no concurrent write")
3. UNSTATED DEPENDENCIES: what other files, tools, rules, migrations must also change but the proposal doesn't mention?
4. FAILURE MODES: how does this fail silently? How does it fail loudly? What recovery is defined?
5. CONVENTION VIOLATIONS: does this break any existing rule in .claude/rules/? Any documented pattern in CLAUDE.md? Any gotcha in .learnings/?
6. SCOPE CREEP: does implementing this require changes outside the proposal's stated scope?
7. TOOL HALLUCINATION RISK: any citation in the proposal that could be fabricated? (Spot-check top 2 citations — Read/Glob to verify.)
8. CIRCULAR REASONING: does this proposal restate the original framing without challenging it?
9. MISSING ANGLES: what angles from the explored_angles_log does this proposal NOT cover? Are those angles still relevant?
10. INTEGRATION GAPS: does the Phase 3 integration map miss any required change?

OUTPUT FILE: {output_path}
FORMAT:
# Adversarial Gap Register — Iteration {N}
## Per-Proposal Gaps

### Proposal {i}: {title}
#### Gaps Found ({count_high} HIGH / {count_med} MEDIUM / {count_low} LOW)
| # | Gap | Severity | Evidence | Resolvable by research? |
|---|---|---|---|---|
| 1 | {1-sentence gap description} | HIGH | {file:line or URL} | YES (suggest query) / NO (design flaw) |

## Cross-Proposal Structural Gaps
(gaps that apply to multiple proposals or the approach overall)

## Faithfulness Spot-Checks Performed
- Cited file: {path} — VERIFIED / FAILED ({reason})

## Summary
- Total HIGH: {N}, MEDIUM: {M}, LOW: {K}
- Fully-resolvable by more research: {count}
- Design-flaws requiring proposal rework: {count}
- Overall critique verdict: {continue_to_gap_resolution | proposals_converged | structural_rethink_needed}

Return ONLY: {path} — {N HIGH, M MEDIUM, K LOW gaps; verdict: {...}}
```

Increment `critic_iteration += 1`. Store return path as `gap_register_path`.

**Convergence check (read the new gap register):**
- `HIGH == 0` → **CONVERGED**. Convergence signal for this skill: 0 HIGH gaps from critic for 1 consecutive round. Advance to Phase 6.
- `HIGH > 0` AND verdict == `continue_to_gap_resolution` → enter Phase 5.
- verdict == `structural_rethink_needed` → STOP, write partial `proposals.md` with `BELOW-THRESHOLD — structural rethink recommended` marker, report to user, suggest rescoping.
- `critic_iteration >= MAX_CRITIC` AND `HIGH > 0` → STOP, write partial `proposals.md` with `BELOW-THRESHOLD — critic cap reached` marker.

If user passed `--no-critic` → skip this entire phase (print warning, proceed to Phase 6 with unchecked shortlist).

**Output artifact:** `gap-register-{iteration}.md`.

---

## Phase 5 — Gap Resolution Loop

(TASK_TRACKING=true) `TaskUpdate(taskId=<id>, status="in_progress", description="Phase 5: Gap Resolution Loop")`

**Goal:** Resolve every HIGH-severity gap via targeted research. Loop until critic finds zero new HIGH gaps OR cap hit.

**Loop structure (main thread orchestrates, dispatches as needed):**

```
while gap_register.HIGH > 0 AND critic_iteration < MAX_CRITIC:
  1. Partition gaps: resolvable-by-research (YES column) vs. design-flaw (NO column)
  2. For each resolvable gap in parallel batches of ≤3 per message:
       dispatch proj-researcher w/ gap-resolution prompt (template below)
       → writes gap-resolution-{critic_iteration}-{gap_id}.md
  3. Main thread reads all resolution files:
       - RESOLVED → merge finding into proposal's integration map / risk register
       - PARTIAL  → downgrade proposal score, add remediation note to proposal
       - UNRESOLVABLE → flag proposal "gap: {gap_id} unresolved", optionally spawn a
         narrow Phase-1 mini-pass with a persona focused on that gap
  4. For each design-flaw gap (NO column):
       - downgrade affected proposal by severity
       - if all proposals affected → spawn narrow Phase-1 mini-pass ("address gap {X}")
  5. Append resolved-angle entries to explored_angles_log
  6. Re-dispatch Phase 4 adversarial critic on the revised proposal set
  7. Read new gap register:
       - new HIGH == 0 AND no regressions → CONVERGED, exit loop → Phase 6
       - new HIGH == old HIGH AND 0 resolutions this round → HARD-FAIL (T7), report structural issue
       - new HIGH < old HIGH → progress, continue loop
  8. gap_resolution_total += N_dispatches_this_round
  9. if gap_resolution_total >= 10 → print warning "approaching 15-dispatch ceiling"
 10. if gap_resolution_total >= MAX_GAP_TOTAL → STOP, write BELOW-THRESHOLD partial
```

For each resolvable gap in the partition (parallel batches of ≤3 per message), dispatch agent via `subagent_type="proj-researcher"` w/ the gap-resolution prompt below (fill `{proposal_title}`, `{gap_description}`, `{severity}`, `{evidence}`, `{suggested_query}`, `{output_path}` = `{base_path}/gap-resolution-{critic_iteration}-{gap_id}.md`):

```
You are proj-researcher — GAP RESOLUTION role.

PARENT PROPOSAL: {proposal_title} (from deepen-{slug}.md)
GAP TO RESOLVE: {gap_description}
GAP SEVERITY: {severity}
EVIDENCE CITED BY CRITIC: {evidence}
SUGGESTED QUERY (if any): {suggested_query}

YOUR TASK:
1. Read the parent proposal + deepen file.
2. Investigate the gap using the most specific tool available:
   - Code structure → MCP code-search (codebase-memory / serena) OR Grep/Glob
   - External technique → WebSearch (max 2 rounds)
   - Prior art in this project → .learnings/log.md + .claude/specs/
3. Produce ONE of:
   (a) RESOLUTION: concrete fix for the proposal that eliminates the gap. Include updated integration-map entry or risk-register entry.
   (b) PARTIAL: partial fix + remaining unknowns.
   (c) UNRESOLVABLE: evidence that the gap cannot be closed without a design change. Cite the evidence.

OUTPUT FILE: {output_path}
FORMAT:
# Gap Resolution — Gap {gap_id}, Iteration {N}
## Gap (restated)
## Investigation
- Sources consulted (file:line or URL)
## Verdict
- RESOLVED | PARTIAL | UNRESOLVABLE
## Proposal Update
(if RESOLVED: concrete update to integration map / risk register / proposal body)
(if PARTIAL: what's resolved + what remains)
(if UNRESOLVABLE: evidence + design-change recommendation)

Return ONLY: {path} — {verdict: RESOLVED/PARTIAL/UNRESOLVABLE, summary}
```

**Convergence caps (observable units — NOT time):**

| Cap | Value | Enforced where |
|---|---|---|
| Phase 1 auto-retries (T1/T2/T3) | max 2 extra passes, 3 total | `MAX_PHASE1_PASSES = 3` |
| Phase 4 critic iterations | max 5 (override via `--max-critic`, hard ceiling 10) | `MAX_CRITIC` |
| Phase 5 parallel gap-resolution per round | max 3 | `MAX_GAP_PARALLEL = 3` |
| Phase 5 total gap-resolution dispatches per run | max 15 (warn at 10) | `MAX_GAP_TOTAL = 15` |

**Hard-fail conditions (all → STOP + partial artifact):**
- Critic iteration 5 reached with HIGH > 0 → `BELOW-THRESHOLD — critic cap reached`.
- Phase 5 round produces 0 RESOLVED verdicts AND ≥1 HIGH gap remains → T7 hard-fail: structural design flaw, report to user.
- Explored-angle log saturates (every persona × every cluster tried) AND HIGH gaps remain → `BELOW-THRESHOLD — angles exhausted`.
- `gap_resolution_total >= MAX_GAP_TOTAL` → `BELOW-THRESHOLD — dispatch budget exhausted`.

**Loop triggers (complete table, including Phase-5-specific):**

| Trigger | Auto-fire? | Action |
|---|---|---|
| T1: shortlist survivors < 2 after evidence gate | YES | Re-run Phase 1 with broadened scope |
| T2: max(scores) < 2.5/5 | YES (user notified) | Re-run Phase 1 with critique injection |
| T3: all shortlisted cluster-identical | YES | Re-run Phase 1, exclude dominant cluster |
| T4: evidence density < floor after Phase 3 | YES | Re-run Phase 0 with broader scope, then Phase 1 |
| T5: `--passes=N` flag | YES | N extra Phase-1 passes with cumulative Reflexion critique |
| T6: Phase 4 HIGH gaps > 0 | YES (core identity) | Enter Phase 5 loop |
| T7: Phase 5 resolution count = 0 AND HIGH remains | YES | HARD-FAIL structural flaw |

Priority: T1 > T2 > T3. T6 runs every iteration regardless of T1–T5 state. T7 is a kill switch.

**Output artifacts per round:** `gap-register-{N}.md`, `gap-resolution-{N}-{gap}.md`, `explored-angles-log.md` (running log, rewritten each round).

---

## Phase 6 — Dual-Artifact Synthesis

(TASK_TRACKING=true) `TaskUpdate(taskId=<id>, status="in_progress", description="Phase 6: Dual-Artifact Synthesis")`

**Main thread only. No dispatch.** Writes both a rich multi-proposal file and a brainstorm-compatible spec so `/write-plan` can consume the output unchanged.

**Artifact 1: `proposals.md` (rich, multi-candidate, primary output)** — write to `{proposals_path}`:

```
# /deep-think Proposals — {topic}
**Date:** {date} | **Iterations:** {phase1_pass Phase-1 passes} | **Critic rounds:** {critic_iteration}
**Total proposals generated:** {total} | **Survived evidence gate:** {K} | **Final shortlist:** {F}

## Executive Summary
- Top recommendation: {winner title} (score: {X}/5, {N} HIGH gaps resolved)
- 2–3 bullet rationale

## Proposals (ranked by total score)

### Proposal 1 — {title} [RECOMMENDED]
**Score:** {X}/5 (local:{a} external:{b} novelty:{c} feasibility:{d})
**Cluster:** {label}
**Origin:** round-1-branch-{N}.md §{proposal_section} | deepened: deepen-{slug}.md | critic rounds survived: {M}
**Summary:** 2–3 sentences
**Mechanism:** logical steps
**Integration Map:**
  | File | Required change | Notes |
**Risk Register:**
  | Risk | Severity | Status (resolved/mitigated/accepted) |
**Local evidence:** {file:line list}
**External evidence:** {URL list}
**Gaps resolved:** {N HIGH, M MEDIUM}
**Gaps remaining:** {any MEDIUM/LOW not fatal}

### Proposal 2 — {title}
### Proposal 3 — {title}

## Discarded
- {N} disqualified for evidence penalty
- {M} merged as duplicates
- {K} killed by structural gap (unresolvable design flaw)

## Iteration Log
- Round 0: evidence scan → {key findings}
- Round 1 (pass 1): 5 branches × 6 proposals = 30 candidates, {K} survived gate
- [Round 1 (pass 2): triggered by {T1|T2|T3|T4}, {new} proposals]
- Phase 3: deepened top {F}
- Phase 4 critic round 1: {N HIGH, M MEDIUM gaps found}
- Phase 5 gap resolution round 1: {R resolved, P partial, U unresolvable}
- Phase 4 critic round 2: {...}
- (repeat per critic iteration)
- Convergence: {reason — 0 new HIGH gaps OR cap reached}

## Explored Angles Log
{persona × cluster matrix showing which angles were explored, cumulative across iterations}

## Handoff
Run `/write-plan` with: {spec_path}
(or pass {proposals_path} if /write-plan supports proposals format)
```

**Artifact 2: `spec.md` (brainstorm-compatible, single-approach, pipeline-feeding)** — write to `{spec_path}`. Converts the TOP proposal to brainstorm-spec format:

```
# {topic} Spec

## Problem / Goal
{from proposals.md Executive Summary + Proposal 1 rationale}

## Constraints
{from Proposal 1 integration map + risk register; list hard constraints inline}

## Approach (approved)
{Proposal 1 title, mechanism, and brief rationale}

## Components (files, interfaces, data flow)
{from Proposal 1 integration map — one bullet per file with what changes}

## Open Questions
{from Proposal 1 remaining gaps + "see proposals.md for alternatives 2, 3"}
```

**Verification checklist (main thread self-checks before declaring completion — all 8 items):**
- [ ] `proposals.md` exists at `{proposals_path}`
- [ ] Contains ≥ `len(shortlist)` proposals in ranked order
- [ ] Every surviving proposal has ≥1 local OR ≥1 external citation
- [ ] `spec.md` exists at `{spec_path}` in brainstorm format (all 5 required sections present)
- [ ] `gap-register-{final}.md` shows 0 HIGH gaps OR an explicit `BELOW-THRESHOLD` marker
- [ ] Iteration log present in `proposals.md`
- [ ] Explored-angles log present in `proposals.md`
- [ ] All artifact files referenced in `proposals.md` exist (cross-reference check via Read/Glob)

If any checklist item fails → fix before Phase 7. If uncheckable → note explicitly in the handoff message. Do not claim PASS on unrun checks (`max-quality.md §3`).

---

## Phase 7 — Handoff

(TASK_TRACKING=true) **TaskCreate closeout** — call `TaskUpdate(taskId=<id>, status="completed")`. This is the successful-completion closeout call for the deep-think run. After this call, the harness task list closes the entry. If the run is aborting mid-Phase-7 for any reason (user cancels handoff, artifacts missing, verification checklist failure deferred from Phase 6), call `TaskUpdate(taskId=<id>, status="in_progress", description=<original-description> + "\n\nBLOCKED: {reason}")` instead — never mark the task completed on abort.

**Open Questions triage (before handoff — reads `open_questions` field from researcher handoffs + `## Open Questions` section from `spec.md`):**
- Read `spec.md` `## Open Questions` section (Proposal 1 remaining gaps from Phase 6)
- Present each with disposition (USER_DECIDES / AGENT_RECOMMENDS / AGENT_DECIDED)
- USER_DECIDES items: surface explicitly; do not suggest /write-plan until addressed
- AGENT_RECOMMENDS items: state default + rationale; user may veto
- AGENT_DECIDED items: state transparently in handoff message
- If none: state "No open questions — ready for /write-plan."

Suggest `/write-plan`, do NOT auto-invoke. Print to user:

```
/deep-think complete.

Artifacts:
- Proposals (rich, multi-candidate): {proposals_path}
- Spec (brainstorm-format, top proposal): {spec_path}
- All working artifacts: {base_path}/

Top recommendation: {title} (score {X}/5, {HIGH}/0 critical gaps remaining)

Next: review proposals.md, then run `/write-plan {spec_path}` to generate an implementation plan.
(Or: `/write-plan {proposals_path}` if you want to plan multiple proposals — may require proposals→spec extraction.)
```

End skill. Do not call `/write-plan` directly — user confirms before plan generation.

---

## Iteration Log Format (reference)

Every run appends to `proposals.md` an iteration log with the format above. Main thread also writes a running `explored-angles-log.md` during Phase 5 updated per round:

```
# Explored Angles — {topic}
## Cumulative (persona × cluster)
| Pass | Persona | Cluster | Outcome |
|---|---|---|---|
| 1.1 | rule engineer | skill-authoring | shortlisted |
| 1.2 | skeptic | rule-enforcement | disqualified (no evidence) |
| 1.3 | agent designer | dispatch-shape | merged into 1.1 |
```

This log feeds the Phase 1 `{explored_angles}` variable on subsequent passes so researchers do not revisit exhausted angles.

---

## Anti-Hallucination Directives

- Verify every artifact path exists before writing cross-references (use Read/Glob).
- Read before proposing — never reference a file/API/pattern not confirmed in round-0 evidence or deepen files.
- Every proposal citation must be verifiable; the Phase 2 and Phase 4 spot-checks are the enforcement layer.
- When uncertain if something exists → say "UNRESOLVED" in the open-question slot, do not fabricate.
- Cite file:line for every local-evidence claim.
- Never substitute built-in `Explore` / `general-purpose` agents — only `proj-researcher` / `proj-quick-check` per the dispatch policy above.
- Never silently absorb work outside this skill's scope (see `.claude/rules/agent-scope-lock.md`); if a gap resolution discovers a fix belongs in a different file → note it in the proposal update, do not apply it here.
- If WebSearch unavailable → set mode flag, adjust rubric, and explicitly note `EXTERNAL: unavailable — local-only mode` in every researcher prompt that would otherwise request web research.

### Anti-Patterns Table (10 HIGH-severity gaps addressed by this design)

| Failure mode | Mitigation in this skill |
|---|---|
| Hallucinated novelty | Evidence gate as soft scoring penalty + faithfulness spot-check (Phase 2) |
| Echo chamber / self-bias | Separate evaluator researcher (Phase 2); persona rotation (Phase 1); skeptic persona built in |
| Circular reasoning | Phase 4 adversarial critic as first-class phase + Phase 5 gap-resolution loop + Reflexion critique injection (Phase 3) |
| Premature convergence | Convergence = "0 HIGH gaps from critic for 1 consecutive round", not "user happy with shortlist" |
| Reward hacking | 4-dim multi-dim rubric (local/ext/nov/feas) + separate evaluator context |
| Procedure omission | Explored-angles log enforced — each pass must cover angles not yet in log |
| Tool hallucination | Faithfulness spot-check Phase 2 + Phase 4 critic spot-checks top 2 citations |
| Partial researcher failure (silent loss) | Explicit error-summary detection + solo re-dispatch + ≥3-branch floor |
| Mid-skill compaction state loss | `shortlist.md` written before Phase 3 dispatch = recovery point |
| Trivial-topic over-engineering | Phase 0 complexity assessment → suggest `/brainstorm` if topic trivial |

---

## Known Limitations (v2 deferrals)

- **Cosine-similarity convergence detection** — no embedding tool on main thread. v2 when embedding tool available.
- **GoT Aggregation merge step** — v2: "merge top-2 proposals into a third candidate".
- **Embedding-based novelty scoring** — current novelty score is lexical overlap; v2 if embedding tool becomes available.
- **`--resume` recovery protocol** — if a session compacts mid-run, user must restart from `shortlist.md` manually. v2: `--resume {base_path}` flag.
- **`/cleanup-specs` retention policy** — working artifacts accumulate under `{base_path}/`. v2: retention sweep.

These limitations are deliberate scope cuts for v1. Do not attempt to work around them inline — note and defer.

---

## Exit

End of skill body. Final output to user is the Phase 7 handoff message above. Do NOT auto-invoke `/write-plan`. Do NOT create new agents. Do NOT modify any file outside `{base_path}/`, `{proposals_path}`, `{spec_path}`.
