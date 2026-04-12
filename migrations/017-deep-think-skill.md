# Migration 017 — /deep-think Skill

<!-- migration-id: 017-deep-think-skill -->

> Ships the `/deep-think` multi-pass adversarial ideation skill to client projects: creates `SKILL.md` + two reference files, and adds a routing trigger bullet to `brainstorm/SKILL.md`.

---

## Metadata

```yaml
id: "017"
breaking: false
affects: [skills]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

`/brainstorm` is single-pass: one researcher, one spec, one round of proposals. It is well-suited to requirements-clear or single-layer decisions. It is insufficient when a topic spans ≥2 architectural layers, is genuinely uncertain / innovative / upgrade-class, or needs external prior-art validation with adversarial critique. No existing skill fills this gap.

`/deep-think` fills it: parallel divergent ideation across 5 persona angles, evidence-gated shortlisting, Reflexion-style targeted deepening, and an adversarial critic loop that iterates until zero HIGH-severity gaps remain. The skill dispatches `proj-researcher` across 7 phases (Phases 0–6) with a convergence criterion of "0 HIGH gaps from critic for 1 consecutive round" — not "user approves shortlist".

This migration retrofits existing bootstrapped client projects. New projects bootstrapped after this migration will generate the finalized form directly from the updated modules template.

---

## Changes

1. Creates `.claude/skills/deep-think/` skill directory with a `references/` subdirectory.
2. Writes `.claude/skills/deep-think/SKILL.md` — full 779-line skill body (frontmatter + 14 sections, no numeric prefixes).
3. Writes `.claude/skills/deep-think/references/personas.md` — 5 default personas + 5 generic fallback personas + topic-override table + extension instructions.
4. Writes `.claude/skills/deep-think/references/dispatch-templates.md` — all 6 researcher dispatch prompt templates fully parameterized (Phases 0–5).
5. Appends routing trigger bullet to `.claude/skills/brainstorm/SKILL.md` Decision Tree section (idempotent — grep-guarded so re-runs do not duplicate).
6. Updates `brainstorm/SKILL.md` frontmatter `description:` to mention `/deep-think` routing (idempotent — grep-guarded on "deep-think" inside description block).
7. Advances `.claude/bootstrap-state.json` → `last_migration: "017"` + appends `"017"` to `applied[]`.

Idempotent: file-write steps check existence and overwrite from source; brainstorm routing edit guarded by grep; brainstorm description patch guarded by grep on "deep-think" inside description block; bootstrap-state advance guarded by `applied[]` membership check.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { printf "ERROR: not a bootstrapped project — run full bootstrap first\n"; exit 1; }
[[ -d ".claude/skills" ]] || { printf "ERROR: no .claude/skills directory — run modules 05+06 first\n"; exit 1; }
[[ -f ".claude/agents/proj-researcher.md" ]] || { printf "ERROR: proj-researcher agent missing — migration 017 requires proj-researcher (run full bootstrap first)\n"; exit 1; }

# Probe for python (python3 → python → py) — needed for bootstrap-state JSON update.
PY=""
for cand in python3 python py; do
  if command -v "$cand" >/dev/null 2>&1; then
    PY="$cand"
    break
  fi
done
[[ -n "$PY" ]] || { printf "ERROR: no python interpreter found (need one of python3, python, py)\n"; exit 1; }
printf "OK: python found — %s\n" "$PY"
printf "OK: prerequisites satisfied\n"
```

---

### Step 1 — Create skill directory

```bash
#!/usr/bin/env bash
set -euo pipefail

mkdir -p .claude/skills/deep-think/references
printf "OK: .claude/skills/deep-think/references/ created (or already existed)\n"
```

---

### Step 2 — Write SKILL.md

```bash
#!/usr/bin/env bash
set -euo pipefail

cat > .claude/skills/deep-think/SKILL.md << 'HEREDOC'
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
For any code exploration inside this skill: use Read/Grep/Glob directly OR dispatch `proj-quick-check` (simple) / `proj-researcher` (deep) — never built-in.
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

Return ONLY: {path} — {1-sentence summary}
```

**After the dispatch returns:** read `round-0-evidence.md`. Assess complexity:
- topic spans 1 file OR 1 rule AND has an obvious answer → print:
  `Topic appears trivial — /brainstorm may be more appropriate. Continue /deep-think's full loop or switch? (continue/switch)`
  and wait for user reply. If `switch` → STOP, suggest running `/brainstorm` manually.
- otherwise → proceed to Phase 1.

---

## Phase 1 — Parallel Divergent Ideation

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
HEREDOC

printf "OK: .claude/skills/deep-think/SKILL.md written\n"
```

---

### Step 3 — Write references/personas.md

```bash
#!/usr/bin/env bash
set -euo pipefail

cat > .claude/skills/deep-think/references/personas.md << 'HEREDOC'
# /deep-think — Persona Library

> Progressive disclosure reference for Phase 1 parallel divergent ideation.
> SKILL.md injects `{persona_name}` + `{persona_role}` + `{prompt_stem}` into the
> Phase 1 dispatch prompt template (see `dispatch-templates.md` § Phase 1).
> Five default personas cover the bootstrap-repo problem space; a generic
> fallback set ships for non-bootstrap projects; topic-specific overrides are
> documented inline.

---

## Default Persona Set (5 branches — bootstrap repo)

Source: `.claude/specs/main/2026-04-12-deep-think-phase-mechanics.md` §Q5 — refined persona set after evaluating 6 candidates (rule engineer, agent designer, skill author, token-compression purist, migration author, hook surgeon). Skeptic replaces token-compression purist (too narrow) and hook surgeon (topic-dependent). Skeptic grounds the Self-Refine "circular reasoning plateau" finding — divergence stalls unless at least one branch attacks the topic adversarially from inside Phase 1 itself.

---

### Persona 1: rule-engineer

**Name:** rule engineer
**Role:** Focuses on constraints, enforcement gates, anti-patterns. Reads `.claude/rules/*.md`, identifies which existing rule the topic intersects, proposes new rules where enforcement is missing, surfaces the "what stops the wrong thing from happening" angle. Treats every proposal as a policy statement, not just a mechanism.
**Prompt stem:**
- You identify which existing rule files in `.claude/rules/` the topic intersects; cite file:line.
- You propose new rules, not new mechanisms — your proposals are constraint-shaped (STOP, FORBIDDEN, REQUIRED, MUST).
- You name the enforcement gate explicitly: pre-flight check, hook, skill-body clause, agent force-read, review-time catch.
- You surface anti-patterns the topic enables if left unconstrained; ground each in `.learnings/log.md` entries or `.claude/rules/` if present.
- You do NOT propose agent redesigns or skill rewrites — that is other personas' turf. Stay in rule-shaped output.
**Best for topics:** scope discipline, quality doctrine, linting, pre-commit hooks, permission boundaries, convention enforcement, anti-pattern prevention, governance.

---

### Persona 2: agent-designer

**Name:** agent designer
**Role:** Focuses on dispatch shapes, scope contracts, subagent boundaries, MCP propagation, tool whitelists. Reads `.claude/agents/*.md` and `techniques/agent-design.md`. Proposes new agents only when an existing one cannot cover the work under scope lock; proposes sub-specialist splits when a writer agent's knowledge span is too wide.
**Prompt stem:**
- You propose in agent-shape: agent name, dispatch target, scope contract, force-read list, tool whitelist.
- You check whether an existing `proj-*` agent already covers the work before proposing a new one; cite the agent file.
- You model dispatch shape: how many parallel instances, which skill dispatches it, what files are in-scope, what belongs on the main thread.
- You name the MCP tools that must propagate (omit `tools:` or literal list) per `.claude/rules/mcp-routing.md`.
- You surface scope-lock implications: what file sets become off-limits, what "SCOPE EXPANSION NEEDED" return-messages become possible.
- You do NOT propose skill bodies, rules, or migration plumbing — those are other personas' turf.
**Best for topics:** new workflows requiring a writer/analyst agent, cross-layer orchestration, evidence tracking, dispatch parallelism, scope-lock design, MCP tool routing, agent sub-specialization.

---

### Persona 3: skill-author

**Name:** skill author
**Role:** Focuses on user-facing flow, argument hints, phase structure, frontmatter shape, pre-flight gate placement, conversational gates vs AskUserQuestion, disclosure layering between SKILL.md and `references/`. Reads `.claude/skills/*/SKILL.md` and `techniques/prompt-engineering.md`. Owns the UX of invocation — when does the skill fire, what does the user type, what does the skill print back.
**Prompt stem:**
- You propose in skill-shape: skill name, description (starting "Use when..."), argument-hint, allowed-tools (space-separated), model, effort, phase list.
- You design the user's first-2-minutes: what prompt fires the skill, what pre-flight gate prints, what the first user-visible phase output looks like.
- You map progressive disclosure: what lives in `SKILL.md` body vs `references/*.md` subfiles. Body ≤500 lines is the hard ceiling.
- You write imperative user-facing copy — no permission-seeking ("should I continue?" banned), no hedging. Follow `.claude/rules/max-quality.md` §6.
- You surface routing triggers: keywords that should auto-activate the skill, sibling skills whose descriptions must cross-reference this one.
- You do NOT write rules, migrations, or agent bodies — those are other personas' turf.
**Best for topics:** new slash commands, skill UX, argument parsing, phase structuring, progressive disclosure design, skill-to-skill routing, conversational gates, user-gate design.

---

### Persona 4: migration-author

**Name:** migration author
**Role:** Focuses on how a bootstrap-repo change propagates to client projects. Reads `migrations/*.md`, `migrations/index.json`, `migrations/_template.md`. Owns backward compatibility, idempotency, state management, read-before-write patterns, self-contained inlining vs tracked-file fetch. Every proposal must answer "how does a pre-migration client project arrive at the new state without breaking?"
**Prompt stem:**
- You propose in migration-shape: migration id, `breaking` flag, `affects` list, `requires_mcp_json`, `min_bootstrap_version`, Actions steps, Verify block, State Update, Rollback.
- You enforce the inseparable pair: module edit + migration. No module change ships without a migration. See `.claude/rules/general.md` Migrations section.
- You verify idempotency: running the migration twice must leave the same state. Read-before-write; `cmp` checks for content sync; `grep -q` before append.
- You honor the technique-path split: bootstrap-repo layout `techniques/*.md` at root vs client layout `.claude/references/techniques/*.md`. Migrations target client layout.
- You glob agent filenames (`for f in .claude/agents/code-writer-*.md`), never hardcode — sub-specialists from `/evolve-agents` must inherit.
- You list the Verify block as shell commands that would return non-zero on failure.
- You do NOT design the feature itself — you design its propagation path. Feature-shape is other personas' turf.
**Best for topics:** bootstrap-to-client propagation, backward compat, state-file updates, index.json entries, agent/skill retrofit passes, idempotency design, rollback planning, versioned migration chains.

---

### Persona 5: skeptic

**Name:** skeptic
**Role:** Adversarial angle inside Phase 1. Assumes every angle the other four personas will suggest is already wrong in some way. Identifies what will fail, what is over-engineered, what existing pattern already solves this partially, what the user's framing itself is hiding. Prevents Phase 1 from being a 5-branch echo chamber agreeing that the topic needs a new thing. Grounded in Self-Refine plateau finding (`research-web.md` §circular reasoning): divergence dies unless at least one branch attacks the framing.
**Prompt stem:**
- You assume every other branch is going to say "build a new X for this topic." You attack that assumption.
- For each proposal, you name a failure mode, an over-engineering risk, or an existing pattern that already covers 60%+ of the need.
- You propose STOP-WORK outcomes: "this is already solved by {existing skill/agent/rule} — extend, don't add." Cite the existing thing.
- You identify where the topic framing itself is wrong: user asked "how do I build X", but the real problem is "why does the existing workflow not surface X's absence?"
- You propose at least one NEGATIVE proposal: "do not build anything, instead delete {X}" or "do not add, instead document in {existing doc}".
- You cite `.learnings/log.md` entries that contradict the topic's premise, if any.
- You are allowed to violate the "6 distinct proposals" count down to 4 if two of your proposals would be "do nothing, solved by Y" and "do nothing, solved by Z" — but you must still produce ≥4 genuine ones.
**Best for topics:** ALL topics — the skeptic runs every pass regardless of topic domain. The skeptic is the only persona that is never swapped out by topic-specific overrides; it is structurally required.

---

## Topic-Specific Override Examples

When the topic clearly belongs to a specialized domain, swap ONE of personas 1–4 (never persona 5 skeptic) for a topic-matched specialist. Document the swap in `shortlist.md` iteration log so the explored-angles tracker records which persona set ran.

| Topic domain | Swap out | Swap in | Role |
|---|---|---|---|
| hooks (settings.json, stdin-driven hooks, PreToolUse/PostToolUse) | migration-author (4) | **hook-surgeon** | stdin JSON handling, hook ordering, nested `{ hooks: [...] }` format, script correctness, exit-code semantics, `.claude/settings.json` merge rules |
| UI / UX / terminal output | agent-designer (2) | **ux-critic** | user-visible output shape, imperative vs permission-seeking copy, table formatting, progress signalling, error messages, first-2-minutes flow |
| performance / latency / token budget | rule-engineer (1) | **perf-analyst** | measurement plan, observable units, before/after deltas, cache warmth, parallel-dispatch math, Phase-N wall-clock estimates, rate-limit mitigation |
| testing / coverage / TDD | skill-author (3) | **test-architect** | red-green-refactor cycle, test-writer agent mix, coverage gate placement, verification command authoring, mocking vs integration strategy |
| security / permission / secrets | rule-engineer (1) | **threat-modeler** | attack surface, credential leakage, allowed-tools whitelist audit, hook execution sandbox, committing-secrets risk, scope escalation paths |

**Override mechanics in SKILL.md:**
1. Main thread classifies topic domain after Phase 0 evidence scan.
2. If domain matches an override row → swap persona.
3. Dispatch still runs 5 researchers — just with the swapped persona slotted in place of the original.
4. Skeptic (persona 5) is never swapped — structural requirement.

---

## Generic Fallback Set (non-bootstrap-repo topics)

Used when `/deep-think` runs on a project whose topic does not map to bootstrap-repo concerns (rules/agents/skills/migrations). Detection: Phase 0 evidence scan finds no `.claude/rules/`, no `.claude/agents/`, or the topic does not touch any `.claude/` surface. Main thread substitutes this 5-persona set for Phase 1 dispatches.

---

### Persona G1: architect

**Name:** architect
**Role:** Focuses on structural fit — module boundaries, dependency graphs, layering, data flow, separation of concerns. Reads top-level project structure (README, manifest files, high-level directories). Proposes in architecture-shape: where does the change live, which layer owns it, how does data flow to and from it.
**Prompt stem:**
- You propose in architecture-shape: name the layer, name the module, name the data flow.
- You check existing layering before proposing new layers; cite module boundaries via file paths.
- You surface coupling risks: which modules become dependent on which, and whether that dependency is acyclic.
- You name the interface contract: function signature, message shape, file-format, API endpoint.
- You do NOT propose security, ops, product, or user-advocacy angles — those are other fallback personas' turf.
**Best for topics:** new subsystems, cross-module refactors, interface design, layering decisions, dependency inversion, module extraction.

---

### Persona G2: security-reviewer

**Name:** security reviewer
**Role:** Focuses on threat surface — what can an attacker abuse, what secrets leak, what privilege escalation exists, what input sanitization is missing. Reads authentication, authorization, input-validation, and secret-storage points. Proposes in threat-shape: threat description + exploit path + mitigation.
**Prompt stem:**
- You propose in threat-shape: threat → exploit path → mitigation.
- You check existing secret storage, credential handling, and input validation; cite file:line.
- You name the attack: injection, traversal, unauthorized access, replay, race condition, supply-chain.
- You rank proposals by exploitability × impact, not by ease of implementation.
- You surface "just document it" as a valid mitigation where a fix is unreasonable, but NEVER for credential leaks or injection vectors.
- You do NOT propose feature mechanics or UX — those are other personas' turf.
**Best for topics:** authentication, authorization, secret handling, input validation, dependency audits, permission boundaries, audit logging.

---

### Persona G3: ops-engineer

**Name:** ops engineer
**Role:** Focuses on runtime behavior — deployment, observability, error recovery, configuration management, rollback, capacity, logging, metrics. Reads CI/CD config, deployment scripts, logging setup, monitoring integration. Proposes in ops-shape: how it deploys, how it fails, how it recovers, how you know.
**Prompt stem:**
- You propose in ops-shape: deploy path + failure mode + recovery path + observability hook.
- You check existing logging, metrics, and alerting; cite config files.
- You name the rollback: how to undo the change in production without a rebuild.
- You surface capacity risk: resource limits, scaling behavior, concurrent-request handling.
- You propose at least one proposal that is a NON-CODE change: dashboard, runbook, alert rule, SLO definition.
- You do NOT propose feature mechanics or code refactors — those are other personas' turf.
**Best for topics:** deployment, monitoring, logging, incident response, capacity planning, config management, CI/CD pipelines, feature flags.

---

### Persona G4: product-skeptic

**Name:** product skeptic
**Role:** Adversarial angle for the generic fallback set. Equivalent to default Persona 5 skeptic but angled toward product-value challenges instead of bootstrap-repo specifics. Asks "does the user actually need this?" and "what user problem does this solve, in the user's words?"
**Prompt stem:**
- You assume the topic is partially or fully a solution in search of a problem. You attack that assumption.
- For each proposal, you name which user pain it resolves in one sentence of the user's language (not developer language).
- You propose at least one "do not build, solve differently" outcome: documentation, training, process change, removal.
- You cite evidence that the assumed pain exists: user request, bug report, feature ticket, usage metric. If no evidence exists, name that absence as a HIGH-severity gap.
- You surface scope creep: features the topic will accumulate if unconstrained, and where the scope creep will come from.
- You are structurally required for every generic-fallback run. Do not swap out.
**Best for topics:** ALL topics in the generic fallback set — runs every pass.

---

### Persona G5: end-user-advocate

**Name:** end-user advocate
**Role:** Focuses on the perspective of the person using the product, not the person building it. Reads user-facing docs, help text, error messages, onboarding flows. Proposes in experience-shape: what the user sees, what the user types, what the user misunderstands, what the user abandons.
**Prompt stem:**
- You propose in experience-shape: first-encounter moment + point-of-confusion + point-of-success + abandonment risk.
- You cite user-facing strings — error messages, help text, button labels, command output. Grep for them.
- You name the user persona (new / returning / expert) and design for the weakest of the three.
- You propose at least one "reduce, don't add" outcome: remove an option, simplify a workflow, default a setting.
- You surface accessibility, localization, and discoverability gaps.
- You do NOT propose infrastructure, security, or architecture — those are other personas' turf.
**Best for topics:** onboarding flows, CLI UX, error-message clarity, accessibility, help text, documentation IA, discoverability.

---

## Extension Instructions

To add project-specific personas to a bootstrap-derived project without modifying `SKILL.md`:

1. Append a new `### Persona N: {slug}` section to THIS file (`.claude/skills/deep-think/references/personas.md`), matching the 5-field structure (Name / Role / Prompt stem / Best for topics).
2. SKILL.md reads this file during Phase 1 setup — new personas become immediately available for topic-override selection without a code change.
3. Document the persona in the Topic-Specific Override Examples table above if the persona is meant to swap for a default slot on specific topics.
4. Do NOT delete personas 1–4 — `/deep-think` SKILL.md expects those four slots to exist. If you want a project-specific persona to REPLACE a default one unconditionally, prefer topic-specific override rather than deletion.
5. Persona 5 skeptic (default set) and Persona G4 product-skeptic (fallback set) are structurally required — deleting them disables the Phase 1 echo-chamber defense. Do not delete.
6. After adding a persona, run `/deep-think` on a small test topic to confirm the new persona is dispatched; check `round-1-branch-*.md` output to verify persona discipline held.
7. If the project wants a completely different persona set (e.g., for a narrow domain like a compiler frontend or a trading system), add a new `## Custom Persona Set — {domain}` heading below the fallback set, then update SKILL.md Phase 1 persona-selection logic to route that domain to the custom set.

Extension is append-only. The five default personas + five fallback personas + any topic-specific override rows remain the stable core; project-specific additions live below.
HEREDOC

printf "OK: .claude/skills/deep-think/references/personas.md written\n"
```

---

### Step 4 — Write references/dispatch-templates.md

```bash
#!/usr/bin/env bash
set -euo pipefail

cat > .claude/skills/deep-think/references/dispatch-templates.md << 'HEREDOC'
# /deep-think — Dispatch Templates

> All 6 researcher dispatch prompt templates, fully parameterized.
> SKILL.md embeds the full prompts verbatim; this file is the maintenance reference + single-source for template variables.
> **Maintenance rule:** edit this file AND SKILL.md in lockstep. Any divergence between the two is a bug — SKILL.md §13 (convergence rule) is authoritative on conflict.
> Variables use `{curly_brace}` notation. All variables documented per template.
> Source: `.claude/specs/main/2026-04-12-deep-think-skill-spec.md` Phase-by-Phase Design section.

---

## Template Variables (shared across phases)

Global variables resolved once per `/deep-think` invocation:

- `{topic}` — user-provided topic string (verbatim from skill arg)
- `{branch}` — git branch name at invocation
- `{date}` — ISO date at invocation (YYYY-MM-DD)
- `{base_path}` — `.claude/specs/{branch}/{date}-{topic}-deep-think/` — all iteration artifacts
- `{output_path}` — alias for `{base_path}` used inside dispatch prompts
- `{round0_path}` — `{base_path}/round-0-evidence.md`
- `{shortlist_path}` — `{base_path}/shortlist.md`
- `{explored_angles_log}` — `{base_path}/explored-angles-log.md` (running log of which persona × cluster combos have been tried across all iterations; empty on iteration 1)
- `{iteration_n}` — current Phase-4/5 critic iteration counter (starts at 1)

Phase-specific variables are documented in each phase's **Variables** subsection below.

---

## Canonical Dispatch Form

Every dispatch in this skill uses the canonical form from `modules/06-skills.md:74–104`:

```
Dispatch agent via subagent_type="proj-researcher" w/:
  <prompt text from the template below>
```

All 6 templates below are designed to be pasted directly into the prompt slot after argument substitution. No paraphrasing; literal verbatim text is the contract with `proj-researcher`.

---

## Phase 0 — Evidence-First Local Scan

**Purpose:** Ground-truth scan before any ideas exist. Prevents anchoring on hallucinated context.
**Dispatch count:** 1 × `proj-researcher` (serial, no parallelism).
**File written:** `{output_path}/round-0-evidence.md`
**Variables:**
- `{topic}` — from user invocation
- `{output_path}` — base artifact directory

**Template:**
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

OUTPUT FILE: {output_path}/round-0-evidence.md
FORMAT: standard proj-researcher output (Summary / Patterns Detected / Conventions / Recommendations / Sources).

CRITICAL: Recommendations section contains ONLY investigation directions, NOT proposed solutions. Do not pre-empt Phase 1 ideation.

Return ONLY: {path} — {1-sentence summary}
```

**Post-dispatch main-thread actions:**
1. Read `round-0-evidence.md`.
2. Trivial-topic complexity assessment: if topic spans 1 file OR 1 rule AND has an obvious answer, print: `Topic appears trivial — /brainstorm may be more appropriate. Continue /deep-think's full loop or switch? (continue/switch)` and wait for user response.
3. Otherwise proceed to Phase 1.

---

## Phase 1 — Parallel Divergent Ideation (per branch)

**Purpose:** Generate 30 diverse candidate proposals across 5 persona angles. Maximize divergence. No scoring.
**Dispatch count:** 5 × `proj-researcher` in parallel (ONE message, 5 Agent calls); or sequential if `--sequential` flag set.
**File written:** `{output_path}/round-1-branch-{branch_n}.md` (one per branch)
**Variables:**
- `{topic}` — from user invocation
- `{persona_name}` — from `personas.md` (rule engineer | agent designer | skill author | migration author | skeptic, or topic-override swap)
- `{persona_role}` — from `personas.md` Role field
- `{prompt_stem}` — from `personas.md` Prompt stem field
- `{round0_path}` — `{base_path}/round-0-evidence.md`
- `{output_path}` — base artifact directory
- `{branch_n}` — integer 1..5
- `{reflexion_critique_prior}` — omitted on iteration 1; on iteration >1, main thread inserts Phase 2 weakness text per branch
- `{explored_angles}` — omitted on iteration 1; on iteration >1, main thread inserts `{explored_angles_log}` file content verbatim

**Template:**
```
You are proj-researcher acting as {persona_name}.
PERSONA ROLE: {persona_role}

PROMPT STEM (follow these bullets strictly — they define your persona discipline):
{prompt_stem}

TOPIC: {topic}
PRIOR EVIDENCE (read BEFORE generating): {round0_path}
{if iteration > 1: PRIOR REFLEXION CRITIQUE: {reflexion_critique_prior}}
{if iteration > 1: EXPLORED ANGLES LOG (do NOT revisit): {explored_angles}}

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

OUTPUT FILE: {output_path}/round-1-branch-{branch_n}.md
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

**Parallel dispatch synchronization (main thread, after all 5 return):**
1. For each returned summary, check:
   - Output file exists (Glob check on `{output_path}/round-1-branch-{N}.md`).
   - Summary does NOT contain `error:` keyword.
   - File contains ≥1 `## Proposal` marker.
2. If a branch failed: log as `branch {N} failed: {reason}` in iteration state, re-dispatch that one branch solo once.
3. If the solo retry also fails: proceed with remaining branches.
4. If fewer than 3 branches succeed: STOP, report to user, do not proceed to Phase 2.

**Rate-limit mitigation:** if `--sequential` flag was passed, dispatch branches one at a time instead of parallel (higher latency, lower concurrent pressure).

---

## Phase 2 — Evaluator Scoring + Clustering + Shortlist

**Purpose:** Score 30 proposals without echo-chamber (separate evaluator researcher), produce ranked shortlist for user gate.
**Dispatch count:** 1 × `proj-researcher` in EVALUATOR role (separate from Phase 1 generators — GPT-Researcher Reviewer/Revisor pattern).
**File written:** `{output_path}/evaluator-scores.md`
**Variables:**
- `{round1_branch_paths}` — bulleted list of the 5 (or fewer, if retries failed) `round-1-branch-{N}.md` file paths
- `{round0_path}` — `{base_path}/round-0-evidence.md`
- `{output_path}` — base artifact directory
- `{explored_angles_log}` — `{base_path}/explored-angles-log.md` (empty on iteration 1; populated on iteration >1 with prior-iteration title list)
- `{iteration_n}` — current Phase-1 pass counter (for novelty penalty cumulative check)

**Template:**
```
You are proj-researcher in EVALUATOR ROLE. Your job: score, not generate.

INPUTS — read all branch files:
{round1_branch_paths}

ALSO read: {round0_path} for ground-truth context.

SCORING RUBRIC per proposal (apply to every proposal across all branches):

local_score  = min(5, count(distinct_local_citations))
external_score = min(5, 3 × count(distinct_external_URLs))   # 1 URL = 3/5
novelty_score:
  - Read all 30 proposal titles.
  - For each proposal, count how many OTHER proposals share ≥3 consecutive words in title.
  - novelty_score = max(0, 5 - 2 × overlap_count).
  - Additionally: if this is iteration >1, also compare against prior-iteration titles from {explored_angles_log} — cumulative overlap increases penalty.
feasibility_score (rubric-anchored judgment):
  5 = change contained to files already identified in round-0 evidence; no new agents/tools
  4 = 1 new file (skill or agent); no new MCP tools
  3 = 2-3 new files; touches 2+ existing skills; or requires new rule
  2 = new migration + module update + backport; multi-file coordinated change
  1 = new external dependency or unconfirmed Claude Code feature
  0 = outside topic scope OR requires something confirmed absent

total = (0.3 × local) + (0.2 × external) + (0.2 × novelty) + (0.3 × feasibility)
Range: 0–5.

EVIDENCE GATE (scoring, NOT hard-kill — critique §2.1):
- NO LOCAL EVIDENCE + NO EXTERNAL URL → local_score=0, external_score=0, and ADD penalty −0.5 to total
- Proposals with penalty total < 0.5 after scoring → flagged as "disqualified" but NOT removed from output (user may still see them in full report)

CITATION FAITHFULNESS SPOT-CHECK (critique §2.2):
- For the TOP-SCORING proposal after initial scoring, spot-check:
  - Read the cited local file; does it actually support the proposal's claim?
  - If URL cited: check URL format validity + domain plausibility.
- If spot-check fails (cited file does not support claim): downgrade total by −1.0; add "FAITHFULNESS FAIL" flag.
- 1 spot-check per evaluation pass is sufficient for v1.

OUTPUT FILE: {output_path}/evaluator-scores.md
FORMAT:
# Evaluator Scores — Iteration {N}
## Scored Proposals (sorted by total desc)
| # | Branch | Title | Local | Ext | Nov | Feas | Total | Flags |
|---|---|---|---|---|---|---|---|---|
(one row per proposal, all 30)
## Faithfulness Spot-Check
- Proposal checked: {title}
- Result: PASS / FAIL ({reason})
## Notes
- Any scoring edge cases or uncertainty flags

Return ONLY: {path} — {N scored, K flagged, M disqualified}
```

**Post-dispatch main-thread clustering:**
1. Read `evaluator-scores.md`.
2. Group proposals where `local_file` path shares ≥2 path components (e.g., all `.claude/skills/*/SKILL.md` → cluster `skill-authoring`).
3. Proposals with NO LOCAL EVIDENCE → cluster `novel/unanchored`.
4. Within each cluster, detect duplicates: titles differing by ≤3 words → keep higher-scored, merge citations from duplicate into winner, increment merge count.
5. Assign cluster label to each surviving proposal.
6. **Compaction checkpoint:** write `shortlist.md` to `{shortlist_path}` BEFORE any Phase-3 dispatch. This is the recovery point.
7. Shortlist selection: top 3 proposals by total score that pass evidence gate (not disqualified). If fewer than 3 survive → trigger T1 loop (re-run Phase 1 with broadened scope).
8. Print shortlist table to user with imperative framing (not a question):
   ```
   ## Phase 2 Shortlist — {topic}
   Iteration {N} | 30 proposals scored | {K} cluster-surviving | {M} in shortlist

   | # | Title | Local Evidence | External | Score | Cluster |
   |---|---|---|---|---|---|
   | 1 | ... | ... | ... | 4.2/5 | skill-authoring |
   | 2 | ... | ... | ... | 3.9/5 | rule-enforcement |
   | 3 | ... | ... | ... | 3.7/5 | migration |

   Disqualified: {N} proposals (below evidence threshold)
   Merged duplicates: {M} pairs

   Review the shortlist. Remove any proposal by number (e.g. "drop 2") or approve all ("all").
   I will proceed with the approved subset to Phase 3 deepening. If fewer than 2 remain, I will loop back to Phase 1 automatically.
   ```
9. Wait for natural turn-based user response. Do NOT use `AskUserQuestion` — conversational gate per brainstorm precedent.

---

## Phase 3 — Targeted Deep-Dive (per candidate)

**Purpose:** Targeted evidence expansion per shortlisted candidate. Find integration points, hidden risks, prior art specifics. Reflexion-style critique from Phase 2 injected.
**Dispatch count:** 1–3 × `proj-researcher` in parallel (one per shortlisted candidate).
**File written:** `{output_path}/deepen-{candidate_slug}.md` (one per candidate)
**Variables:**
- `{topic}` — from user invocation
- `{proposal_title}` — from shortlist entry
- `{proposal_summary}` — 2–3 sentence summary from the originating round-1 branch file
- `{cluster_label}` — assigned during Phase 2 clustering
- `{round0_path}` — `{base_path}/round-0-evidence.md`
- `{round1_branch_path}` — path to the branch file this proposal came from (for §proposal_section anchor)
- `{proposal_section}` — anchor heading inside the branch file (e.g., `## Proposal 3.2: ...`)
- `{critique_text}` — main-thread-generated Reflexion critique from Phase 2 score breakdown (see rules below)
- `{open_q}` — the proposal's Open Question field from Phase 1
- `{output_path}` — base artifact directory
- `{candidate_slug}` — kebab-case derivation of proposal title, max 40 chars

**Reflexion critique construction (main thread, before dispatch) — apply per candidate:**
- If `local_score < 3/5` → append: `weakness: local_score was {X}; strengthen by finding ≥3 additional citing files in {cluster_label} cluster`
- If `external_score < 3/5` → append: `weakness: external_score was {X}; strengthen with ≥1 targeted URL on the specific technique named`
- If `feasibility_score < 3` → append: `weakness: feasibility was {X}; name specific unclear integration points and resolve them`
- If `novelty_score < 3` → append: `weakness: novelty was {X}; overlap with proposals [{list}]; differentiate or merge`

**Template:**
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

OUTPUT FILE: {output_path}/deepen-{candidate_slug}.md
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

**Post-dispatch main-thread actions:**
1. Read all `deepen-*.md` files.
2. Merge revised feasibility into shortlist.md (update `shortlist.md` in place).
3. Proceed to Phase 4 adversarial critic.

---

## Phase 4 — Adversarial Critic (Gap Hunt)

**Purpose:** Core identity of `/deep-think`. Find edge cases, failure modes, hidden assumptions, unstated dependencies, structural breakage. Assume each proposal is WRONG until proven right.
**Dispatch count:** 1 × `proj-researcher` in ADVERSARIAL-CRITIC role.
**File written:** `{output_path}/gap-register-{iteration_n}.md`
**Variables:**
- `{round0_path}` — `{base_path}/round-0-evidence.md`
- `{shortlist_path}` — `{base_path}/shortlist.md`
- `{deepen_file_list}` — bulleted list of all `deepen-*.md` file paths from Phase 3 (merged across iterations if this is critic round >1)
- `{explored_angles_log}` — `{base_path}/explored-angles-log.md` (populated from prior iterations; empty on critic round 1)
- `{output_path}` — base artifact directory
- `{iteration_n}` — current critic round counter (starts at 1)

**Template:**
```
You are proj-researcher — ADVERSARIAL CRITIC role. You are a skeptical reviewer
looking for gaps. Assume each proposal is WRONG until proven right. Find what the
prior analysis MISSED.

INPUTS — read all:
- Round 0 evidence: {round0_path}
- Phase 2 shortlist: {shortlist_path}
- Phase 3 deepen files: {deepen_file_list}
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
7. TOOL HALLUCINATION RISK: any citation in the proposal that could be fabricated? (Spot-check top 2 citations — Read/Glob to verify the cited file exists and supports the claim.)
8. CIRCULAR REASONING: does this proposal restate the original framing without challenging it?
9. MISSING ANGLES: what angles from the explored_angles_log does this proposal NOT cover? Are those angles still relevant?
10. INTEGRATION GAPS: does the Phase 3 integration map miss any required change?

OUTPUT FILE: {output_path}/gap-register-{iteration_n}.md
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

**Post-dispatch main-thread actions (convergence check):**
- `gap-register.HIGH == 0` → **CONVERGED**, advance to Phase 6. (MEDIUM/LOW gaps logged as open risks but do not block convergence — matches SKILL.md §13 convergence rule.)
- `gap-register.HIGH > 0` AND verdict = `continue_to_gap_resolution` → enter Phase 5.
- verdict = `structural_rethink_needed` OR `iteration_n >= MAX_CRITIC (default 5)` → STOP, report partial results with BELOW-THRESHOLD marker, advance to Phase 6 with remaining gaps flagged.

---

## Phase 5 — Gap Resolution (per gap)

**Purpose:** Resolve every HIGH-severity gap via targeted research. One dispatch per resolvable gap. Loop re-dispatches Phase 4 until zero new HIGH gaps OR cap hit.
**Dispatch count:** 1 × `proj-researcher` per resolvable-by-research HIGH gap, parallel ≤3 at a time, total ≤15 per run (warning at 10).
**File written:** `{output_path}/gap-resolution-{iteration}-{gap_id}.md` (one per gap dispatched)
**Variables:**
- `{proposal_title}` — from the proposal the gap applies to
- `{slug}` — the kebab slug from Phase 3 matching the parent `deepen-{slug}.md` file
- `{gap_description}` — gap text from `gap-register-{iteration_n}.md`
- `{gap_severity}` — always `HIGH` for Phase 5 dispatches (MEDIUM/LOW flow into deferred list without dispatch)
- `{critic_evidence}` — file:line or URL cited by the critic for this gap
- `{suggested_query}` — optional; from the critic's "Resolvable by research?" column if YES
- `{output_path}` — base artifact directory
- `{iteration}` — current Phase-5 round counter (matches `{iteration_n}` from the feeding Phase-4 round)
- `{gap_id}` — sequential gap identifier within the register (e.g., `p2-g3` for proposal 2 gap 3)

**Template:**
```
You are proj-researcher — GAP RESOLUTION role.

PARENT PROPOSAL: {proposal_title} (from deepen-{slug}.md)
GAP TO RESOLVE: {gap_description}
GAP SEVERITY: {gap_severity}
EVIDENCE CITED BY CRITIC: {critic_evidence}
SUGGESTED QUERY (if any): {suggested_query}

YOUR TASK:
1. Read the parent proposal + deepen file.
2. Investigate the gap using the most specific tool available:
   - Code structure → MCP code-search OR Grep/Glob
   - External technique → WebSearch (max 2 rounds)
   - Prior art in this project → .learnings/log.md + .claude/specs/
3. Produce ONE of:
   (a) RESOLUTION: concrete fix for the proposal that eliminates the gap. Include updated integration-map entry or risk-register entry.
   (b) PARTIAL: partial fix + remaining unknowns.
   (c) UNRESOLVABLE: evidence that the gap cannot be closed without a design change. Cite the evidence.

OUTPUT FILE: {output_path}/gap-resolution-{iteration}-{gap_id}.md
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

**Post-dispatch main-thread actions (per Phase-5 round, after all parallel gap-resolution dispatches return):**
1. Read every `gap-resolution-{iteration}-{gap_id}.md` produced this round.
2. For each RESOLVED verdict: merge finding into the parent proposal's integration map or risk register (update the relevant `deepen-{slug}.md` or append to a new `deepen-{slug}-revised.md`).
3. For each PARTIAL verdict: downgrade parent proposal's feasibility score, add a remediation note to the proposal body.
4. For each UNRESOLVABLE verdict: flag the parent proposal as `gap: {gap_id} unresolved`; if all shortlisted proposals share the gap, spawn a Phase-1 mini-pass with focused persona to address the gap directly.
5. For each design-flaw gap from the feeding gap-register (resolvable_by_research = NO): downgrade affected proposal by severity; if all proposals affected, spawn a new Phase-1 mini-pass with narrow scope `address gap {X}`.
6. Append resolved-angle entries to `{explored_angles_log}`.
7. Re-dispatch Phase 4 adversarial critic on the revised proposal set (increment `{iteration_n}`).
8. Read the new gap register:
   - New HIGH gaps == 0 AND no regressions → CONVERGED, exit loop, advance to Phase 6.
   - New HIGH gaps == old HIGH gaps (no progress) → HARD-FAIL, report structural issue, advance to Phase 6 with BELOW-THRESHOLD marker.
   - New HIGH gaps < old HIGH gaps → progress, continue loop.
9. Increment `{iteration_n}`. If `{iteration_n} > MAX_CRITIC` (default 5, user-overridable via `--max-critic=N` up to 10) → STOP, advance to Phase 6 with BELOW-THRESHOLD marker.

**Hard-fail conditions:**
- Phase-5 round produces 0 RESOLVED verdicts AND ≥1 HIGH gap remains → structural design flaw, stop the loop, advance to Phase 6 with BELOW-THRESHOLD marker.
- Explored-angle log saturates (every persona × every cluster tried) AND HIGH gaps remain → STOP.
- Total Phase-5 dispatches across all rounds exceeds 15 (warning printed at 10) → STOP.

---

## Cross-Template Invariants

All 6 templates above share these properties — verify after any edit:

1. **Canonical dispatch form:** every template is wrapped in `Dispatch agent via subagent_type="proj-researcher" w/:` at the SKILL.md call site (not repeated inside the template body).
2. **Return contract:** every template ends with `Return ONLY: {path} — {...}` — `proj-researcher` must write its findings to disk and return only the path + one-line summary. Main thread reads the file for any further work.
3. **Read-before-write:** every template that generates content reads input files first (round-0, prior branches, shortlist, deepen files, rules) before producing output.
4. **Output-file path:** every template specifies `OUTPUT FILE: {output_path}/...` explicitly — `proj-researcher` never picks its own filename.
5. **No permission-seeking:** no template contains `should I continue?`, `want me to keep going?`, `is this okay?` — imperative framing per `.claude/rules/max-quality.md` §6.
6. **Token-efficiency carve-out:** these templates are OUTPUT (copied verbatim into dispatch prompts), NOT instructions — do not compress, do not elide, do not substitute placeholders for content. See `.claude/rules/max-quality.md` §7.
7. **MCP preference:** Phase 0 and Phase 5 investigation steps explicitly mention `codebase-memory-mcp` and `serena` as preferred over raw Grep/Glob, per `.claude/rules/mcp-routing.md`.

---

## Template Maintenance

When editing any template in this file:

1. Read the authoritative source first: `.claude/specs/main/2026-04-12-deep-think-skill-spec.md` Phase-by-Phase Design section. The spec is upstream; this file is the progressive-disclosure mirror.
2. Preserve variable placeholders exactly (`{curly_brace}` notation); do not rename without updating SKILL.md call-site substitution logic.
3. Preserve FORMAT blocks verbatim — `proj-researcher` uses them as literal output templates.
4. Preserve RULES blocks (Phase 1) and numbered adversarial questions (Phase 4) verbatim — numeric order is load-bearing for gap-register indexing.
5. After editing, grep-verify all 6 phase headers still present: `grep -c "^## Phase" .claude/skills/deep-think/references/dispatch-templates.md` must return 6.
6. Sync any template content change back into the upstream spec file in the same commit. Do not let the templates drift from the spec.
HEREDOC

printf "OK: .claude/skills/deep-think/references/dispatch-templates.md written\n"
```

---

### Step 5 — Update brainstorm/SKILL.md routing trigger

Adds a routing bullet to the Decision Tree section of `brainstorm/SKILL.md`. Idempotent: skipped if the `deep-think` trigger is already present.

```bash
#!/usr/bin/env bash
set -euo pipefail

BRAINSTORM=".claude/skills/brainstorm/SKILL.md"

[[ -f "$BRAINSTORM" ]] || { printf "WARN: %s not found — skipping routing trigger update\n" "$BRAINSTORM"; exit 0; }

if grep -q "deep-think" "$BRAINSTORM"; then
  printf "SKIP: brainstorm/SKILL.md already contains 'deep-think' routing reference — idempotent, no change made\n"
  exit 0
fi

# Locate the Decision Tree section and find the line that starts the list.
# Insert new bullet after the existing "Problem spans ≥2 architectural layers" line.
PY=""
for cand in python3 python py; do
  command -v "$cand" >/dev/null 2>&1 && { PY="$cand"; break; }
done
[[ -n "$PY" ]] || { printf "ERROR: no python interpreter\n"; exit 1; }

"$PY" - <<'PY'
import sys

path = ".claude/skills/brainstorm/SKILL.md"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Idempotency double-check inside python (belt + suspenders)
if "deep-think" in content:
    print("SKIP (python check): deep-think already present")
    sys.exit(0)

# Find the Decision Tree section and its existing routing bullet about ≥2 architectural layers.
# Append the new bullet directly after that line.
target_line = "- Problem spans ≥2 architectural layers OR needs adversarial gap-hunting → use `/deep-think` instead"
old_line    = "- Problem spans ≥2 architectural layers OR needs adversarial gap-hunting"

if target_line in content:
    print("SKIP: routing trigger line already present verbatim")
    sys.exit(0)

if old_line in content:
    # The line exists but does not include the deep-think pointer yet — add it
    new_content = content.replace(
        old_line,
        "- Problem spans ≥2 architectural layers OR needs adversarial gap-hunting → use `/deep-think` instead"
    )
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("PATCHED: updated existing '≥2 architectural layers' bullet to include /deep-think pointer")
    sys.exit(0)

# Fallback: old_line not found — append a new routing bullet at the end of the Decision Tree block.
# Find the Decision Tree heading and insert after its last bullet.
dt_marker = "### Decision Tree"
if dt_marker not in content:
    print("WARN: '### Decision Tree' not found in brainstorm/SKILL.md — cannot locate insertion point; appending to end of Decision Tree section heuristically")
    # Find "### Full Exploration Flow" as the section boundary
    boundary = "### Full Exploration Flow"
    if boundary in content:
        idx = content.index(boundary)
        insert_at = content.rfind("\n", 0, idx) + 1
        new_bullet = "- Problem spans ≥2 architectural layers OR needs adversarial gap-hunting → use `/deep-think` instead\n"
        new_content = content[:insert_at] + new_bullet + content[insert_at:]
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_content)
        print("PATCHED: inserted /deep-think routing bullet before '### Full Exploration Flow'")
        sys.exit(0)
    print("WARN: cannot locate insertion point; brainstorm/SKILL.md not modified")
    sys.exit(0)

# Decision Tree section found; insert before the next ### or ## heading after it
dt_idx = content.index(dt_marker)
# Find end of Decision Tree block
import re
next_section = re.search(r"\n###? ", content[dt_idx + len(dt_marker):])
if next_section:
    insert_at = dt_idx + len(dt_marker) + next_section.start()
    new_bullet = "- Problem spans ≥2 architectural layers OR needs adversarial gap-hunting → use `/deep-think` instead\n"
    # Insert before the blank line + next heading
    new_content = content[:insert_at] + new_bullet + content[insert_at:]
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("PATCHED: inserted /deep-think routing bullet into Decision Tree section")
else:
    print("WARN: could not find end of Decision Tree section; brainstorm/SKILL.md not modified")
PY
```

---

### Step 6 — Update brainstorm/SKILL.md description frontmatter

Updates the `description:` block in `brainstorm/SKILL.md` frontmatter to include a `/deep-think` routing note. Idempotent: skipped if "deep-think" already appears in the description block.

```bash
#!/usr/bin/env bash
set -euo pipefail

BRAINSTORM=".claude/skills/brainstorm/SKILL.md"

[[ -f "$BRAINSTORM" ]] || { printf "WARN: %s not found — skipping description update\n" "$BRAINSTORM"; exit 0; }

PY=""
for cand in python3 python py; do
  command -v "$cand" >/dev/null 2>&1 && { PY="$cand"; break; }
done
[[ -n "$PY" ]] || { printf "ERROR: no python interpreter\n"; exit 1; }

"$PY" - <<'PY'
import sys, re

path = ".claude/skills/brainstorm/SKILL.md"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Idempotency: if description block already mentions deep-think, skip.
# Check inside the YAML frontmatter description block only.
# Frontmatter is between the first two --- delimiters.
fm_match = re.match(r'^(---\n.*?---\n)', content, re.DOTALL)
if fm_match:
    frontmatter = fm_match.group(1)
    if "deep-think" in frontmatter:
        print("SKIP: description block already mentions deep-think")
        sys.exit(0)

# Locate the description: block in the frontmatter.
# The description is a YAML block scalar ('>') that may span multiple lines.
# We replace the existing description value with the updated one that
# appends the three new lines about /deep-think routing.
old_description = (
    "description: >\n"
    "  Use when asked to design, plan, explore, think through, or brainstorm a\n"
    "  feature, component, or change. Always brainstorm before implementing\n"
    "  non-trivial changes. Absorbs /spec — when requirements clear, skips\n"
    "  exploration and produces spec directly. Dispatches proj-researcher."
)
new_description = (
    "description: >\n"
    "  Use when asked to design, plan, explore, think through, or brainstorm a\n"
    "  feature, component, or change. Always brainstorm before implementing\n"
    "  non-trivial changes. Absorbs /spec — when requirements clear, skips\n"
    "  exploration and produces spec directly. Dispatches proj-researcher.\n"
    "  For problems needing multi-pass adversarial gap-hunting (spans ≥2\n"
    "  architectural layers, unclear constraints, iterative refinement until\n"
    "  no HIGH-severity critiques remain) → use /deep-think instead."
)

if old_description in content:
    new_content = content.replace(old_description, new_description, 1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("PATCHED: appended /deep-think routing lines to brainstorm description frontmatter")
    sys.exit(0)

# Fallback: old_description not found verbatim.
# Try a pattern-based approach: find the description: block and append the new lines.
desc_pattern = re.compile(
    r'(description: >\n(?:  [^\n]*\n)*  [^\n]*(?:\n|$))',
    re.MULTILINE
)
m = desc_pattern.search(content)
if m:
    existing_desc = m.group(1)
    if "deep-think" in existing_desc:
        print("SKIP (pattern): description block already mentions deep-think")
        sys.exit(0)
    # Strip trailing newline from existing_desc block, then append new lines.
    appended = existing_desc.rstrip('\n') + (
        "\n"
        "  For problems needing multi-pass adversarial gap-hunting (spans ≥2\n"
        "  architectural layers, unclear constraints, iterative refinement until\n"
        "  no HIGH-severity critiques remain) → use /deep-think instead.\n"
    )
    new_content = content[:m.start()] + appended + content[m.end():]
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("PATCHED (pattern): appended /deep-think routing lines to brainstorm description frontmatter")
    sys.exit(0)

print("WARN: could not locate description: block in brainstorm/SKILL.md — not modified")
PY
```

---

### Step 7 — Advance bootstrap state

Updates `.claude/bootstrap-state.json` → `last_migration: "017"` + appends `"017"` entry to `applied[]`. Idempotent — skips if `017` already present.

```bash
#!/usr/bin/env bash
set -euo pipefail

PY=""
for cand in python3 python py; do
  command -v "$cand" >/dev/null 2>&1 && { PY="$cand"; break; }
done
[[ -n "$PY" ]] || { printf "ERROR: no python interpreter\n"; exit 1; }

"$PY" - <<'PY'
import json, sys
from datetime import datetime, timezone

path = '.claude/bootstrap-state.json'
with open(path, 'r', encoding='utf-8') as f:
    state = json.load(f)

applied = state.get('applied', [])
already = any(
    (isinstance(a, dict) and a.get('id') == '017') or a == '017'
    for a in applied
)
if already:
    print("SKIP: 017 already in applied[]")
    sys.exit(0)

state['last_migration'] = '017'
applied.append({
    'id': '017',
    'applied_at': datetime.now(timezone.utc).isoformat(),
    'description': '/deep-think skill — ships multi-pass adversarial ideation skill (SKILL.md + personas.md + dispatch-templates.md) to client project; adds routing trigger to brainstorm/SKILL.md Decision Tree.'
})
state['applied'] = applied

with open(path, 'w', encoding='utf-8') as f:
    json.dump(state, f, indent=2)
    f.write('\n')

print("OK: bootstrap-state.json advanced to last_migration=017")
PY
```

---

## Verify

```bash
#!/usr/bin/env bash
set -euo pipefail

fail=0

# File existence checks
[[ -f ".claude/skills/deep-think/SKILL.md" ]] \
  && printf "PASS: SKILL.md exists\n" \
  || { printf "FAIL: .claude/skills/deep-think/SKILL.md missing\n"; fail=1; }

[[ -f ".claude/skills/deep-think/references/personas.md" ]] \
  && printf "PASS: references/personas.md exists\n" \
  || { printf "FAIL: .claude/skills/deep-think/references/personas.md missing\n"; fail=1; }

[[ -f ".claude/skills/deep-think/references/dispatch-templates.md" ]] \
  && printf "PASS: references/dispatch-templates.md exists\n" \
  || { printf "FAIL: .claude/skills/deep-think/references/dispatch-templates.md missing\n"; fail=1; }

# SKILL.md content checks
grep -q 'name: deep-think' ".claude/skills/deep-think/SKILL.md" \
  && printf "PASS: SKILL.md has correct name frontmatter\n" \
  || { printf "FAIL: SKILL.md missing 'name: deep-think'\n"; fail=1; }

grep -q "Pre-flight" ".claude/skills/deep-think/SKILL.md" \
  && printf "PASS: SKILL.md has Pre-flight section\n" \
  || { printf "FAIL: SKILL.md missing Pre-flight section\n"; fail=1; }

researcher_count=$(grep -c 'subagent_type="proj-researcher"' ".claude/skills/deep-think/SKILL.md" || true)
if [[ "$researcher_count" -ge 6 ]]; then
  printf "PASS: SKILL.md has %s subagent_type=proj-researcher dispatches (need >= 6)\n" "$researcher_count"
else
  printf "FAIL: SKILL.md has only %s subagent_type=proj-researcher dispatches, need >= 6\n" "$researcher_count"
  fail=1
fi

# dispatch-templates.md phase header count
phase_count=$(grep -c "^## Phase" ".claude/skills/deep-think/references/dispatch-templates.md" || true)
if [[ "$phase_count" -ge 6 ]]; then
  printf "PASS: dispatch-templates.md has %s Phase headers (need >= 6)\n" "$phase_count"
else
  printf "FAIL: dispatch-templates.md has only %s Phase headers, need >= 6\n" "$phase_count"
  fail=1
fi

# brainstorm routing trigger (Step 5)
if [[ -f ".claude/skills/brainstorm/SKILL.md" ]]; then
  grep -q "deep-think" ".claude/skills/brainstorm/SKILL.md" \
    && printf "PASS: brainstorm/SKILL.md contains deep-think routing reference\n" \
    || { printf "FAIL: brainstorm/SKILL.md missing deep-think routing reference\n"; fail=1; }
else
  printf "WARN: .claude/skills/brainstorm/SKILL.md not found — cannot verify routing trigger\n"
fi

# brainstorm description frontmatter patch (Step 6)
if [[ -f ".claude/skills/brainstorm/SKILL.md" ]]; then
  grep -q "no HIGH-severity critiques remain" ".claude/skills/brainstorm/SKILL.md" \
    && printf "PASS: brainstorm/SKILL.md description contains /deep-think routing note\n" \
    || { printf "WARN: brainstorm/SKILL.md description may not contain /deep-think routing note (Step 6)\n"; }
fi

# bootstrap-state advanced
PY=""
for cand in python3 python py; do
  command -v "$cand" >/dev/null 2>&1 && { PY="$cand"; break; }
done
if [[ -n "$PY" ]]; then
  "$PY" - <<'PY' || fail=1
import json, sys
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
if state.get('last_migration') != '017':
    print(f"FAIL: last_migration={state.get('last_migration')}, expected 017")
    sys.exit(1)
applied = state.get('applied', [])
has_017 = any(
    (isinstance(a, dict) and a.get('id') == '017') or a == '017'
    for a in applied
)
if not has_017:
    print("FAIL: 017 not in applied[]")
    sys.exit(1)
print("PASS: bootstrap-state.json reflects 017")
PY
fi

if [[ $fail -ne 0 ]]; then
  printf "FAIL: verify found issues\n"
  exit 1
fi
printf "PASS: migration 017 verified\n"
```

---

## Rollback

No automated rollback. Manual steps:

1. Remove the skill directory: `rm -rf .claude/skills/deep-think`
2. Restore `brainstorm/SKILL.md` from git: `git checkout HEAD -- .claude/skills/brainstorm/SKILL.md` — or manually remove the `/deep-think` routing bullet added by Step 5 and the description lines added by Step 6.
3. Reset bootstrap-state: edit `.claude/bootstrap-state.json` to remove the `017` entry from `applied[]` and reset `last_migration` to its previous value (e.g., `"016"`).
