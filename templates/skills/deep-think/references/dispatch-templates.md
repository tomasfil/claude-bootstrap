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
