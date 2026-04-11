# Module 05 — Core Agents

> Create remaining 7 utility/diagnostic agents via proj-code-writer-markdown dispatch.
> Foundation 3 (proj-code-writer-markdown, proj-researcher, proj-code-writer-bash) already exist from Module 01.

---

## Idempotency

Per agent file: READ existing → check `name:` in frontmatter matches expected → skip if current.
Missing → dispatch proj-code-writer-markdown to create. Stale → dispatch to regenerate.

## Actions

### Pre-Flight

```bash
mkdir -p .claude/agents .claude/reports
```

Verify foundation agents exist:
```bash
for agent in proj-code-writer-markdown proj-researcher proj-code-writer-bash; do
  [[ -f ".claude/agents/${agent}.md" ]] || echo "MISSING: ${agent}.md — run Module 01 first"
done
```

If any missing → STOP. Module 01 must complete first.

### Dispatch Pattern

Each agent dispatched sequentially to proj-code-writer-markdown using inline BOOTSTRAP_DISPATCH_PROMPT from Module 01.
Sequential because: each is independent but consistent quality requires full attention per agent.

Every dispatch follows this structure:

```
Agent(
  description: "Create {agent-name} agent",
  prompt: "{BOOTSTRAP_DISPATCH_PROMPT from Module 01, proj-code-writer-markdown section}

Write the agent file to .claude/agents/{agent-name}.md with the following specification:

{agent specification from sections below}

Read 2-3 existing agents in .claude/agents/ before writing for pattern consistency.
Read techniques/agent-design.md for pass-by-reference contract + maxTurns table.
"
)
```

After each dispatch: verify file exists, check frontmatter has required fields
(`name`, `description`, `model`, `effort`, `maxTurns`, `color`).

NOTE: ALL agents OMIT `tools:` to inherit parent MCP access (agent-scope-lock enforces file-level scope). When present, agent `tools:` is COMMA-separated (`tools: Read, Grep, Glob`) per Claude Code sub-agents spec. This is DIFFERENT from skill `allowed-tools:` which is SPACE-separated. Do not unify — spec is inconsistent across file types.

---

### 1. Dispatch: proj-quick-check.md

**Spec for dispatch prompt:**

```
Agent: proj-quick-check
Model: haiku | maxTurns: 25 | effort: high | color: gray
Tools: OMIT (inherit parent tools incl. MCP — read-only agent)
Purpose: fast lookups, file searches, existence checks, factual codebase questions

Pass-by-reference: TEXT RETURN EXCEPTION — fast lookups where file write overhead
is not worth it. Return answer directly as text, no file output.

Description (must start "Use when..."): Use when doing quick file searches, checking
if something exists, reading a specific section, or answering factual questions about
the codebase. Optimized for speed over depth.

Body sections:
- Inject the following block immediately after frontmatter closing `---`, before any other body content:

  ## STEP 0 — Load critical rules (MANDATORY first action)

  Before any task-specific work, Read these rule files (in parallel where possible):
  - `.claude/rules/general.md`
  - `.claude/rules/skill-routing.md`
  - `.claude/rules/token-efficiency.md`
  - `.claude/rules/agent-scope-lock.md` (enforces strict batch-file scope — NO adjacent work)
  - `.claude/rules/mcp-routing.md` (if present — routes code discovery through MCP tools)
  - `.claude/rules/code-standards-{your primary lang}.md` (if present)

  Rationale: this sub-agent's body replaces the default system prompt. `CLAUDE.md` still loads, but rules reached through `@import` chains may not reliably surface. Explicit Read lands content as conversation context and guarantees the policy is in scope. If a referenced rule doesn't exist, note it in the final report and continue — don't stop.

  If `mcp-routing.md` is loaded, it OVERRIDES any `Grep` / `Glob` / `Read`-first examples later in this file. Route through MCP tools per that rule before falling back to text search.

  ---

- Scope: find files by name/pattern, check class/method/type existence, read specific
  file sections, answer factual code questions
- Out of scope: no file modifications, no builds/tests, deep analysis → proj-researcher
- Anti-hallucination: report only what's found, not found → say so w/ no speculation,
  always include file paths + line numbers
- Parallel tool calls block (compact form)

This is the ONLY agent that returns text instead of writing files.
OMIT `tools:` field entirely — read-only agent inherits parent tools incl. mcp__* servers.
Any explicit `tools:` list = strict whitelist that excludes ALL MCP tools.
```

---

### 2. Dispatch: proj-plan-writer.md

**Spec for dispatch prompt:**

```
Agent: proj-plan-writer
Model: sonnet | maxTurns: 100 | effort: high | color: blue
Tools: OMIT (inherit parent tools incl. MCP — plan-writer benefits from semantic code lookup via MCPs; scope discipline lives in "Plan ONLY what's specified" rule, not tool restriction)
Purpose: create implementation plans from specs, pack tasks into dispatch-unit batch files

Pass-by-reference: writes master plan to .claude/specs/{branch}/{date}-{topic}-plan.md
AND emits one batch-NN-{summary}.md per dispatch unit under
.claude/specs/{branch}/{date}-{topic}-plan/ (each batch holds 1-N ordered tasks).
batch-NN-*.md is the ONLY accepted output format — legacy task-NN-*.md is removed.
Return master plan path + summary.

Description: Use when breaking a design or spec into concrete, ordered, verifiable
implementation tasks. Takes spec + codebase context, produces dependency-ordered
task list packed into dispatch-unit batch files for focused agent dispatch.

Body sections:
- Inject the following block immediately after frontmatter closing `---`, before any other body content:

  ## STEP 0 — Load critical rules (MANDATORY first action)

  Before any task-specific work, Read these rule files (in parallel where possible):
  - `.claude/rules/general.md`
  - `.claude/rules/skill-routing.md`
  - `.claude/rules/token-efficiency.md`
  - `.claude/rules/agent-scope-lock.md` (enforces strict batch-file scope — NO adjacent work)
  - `.claude/rules/mcp-routing.md` (if present — routes code discovery through MCP tools)
  - `.claude/rules/code-standards-{your primary lang}.md` (if present)

  Rationale: this sub-agent's body replaces the default system prompt. `CLAUDE.md` still loads, but rules reached through `@import` chains may not reliably surface. Explicit Read lands content as conversation context and guarantees the policy is in scope. If a referenced rule doesn't exist, note it in the final report and continue — don't stop.

  If `mcp-routing.md` is loaded, it OVERRIDES any `Grep` / `Glob` / `Read`-first examples later in this file. Route through MCP tools per that rule before falling back to text search.

  ---

- Role: senior architect — analyze specs + codebases → tier-classified, dep-ordered
  dispatch units (one agent invocation per unit executes N ordered tasks back-to-back)
- Reframe: dispatch unit = execution primitive (one Agent call); task = planning
  primitive. A batch file carries 1-N ordered tasks the same agent runs sequentially,
  verifying once at the end. Ordering is preserved INSIDE a batch (dep-ordered
  top-down); batching is governed by tier + dep_set intersection, NOT agent type alone.
- Process:
  1. Read spec file completely
  2. Scan codebase for affected files + patterns
  3. Break into tasks — each independently completable + verifiable
  4. Order by dependency (data → API → UI)
  5. Classify every task → Tier Classification (see below)
  6. Pack tasks into dispatch units → Dispatch Unit Packing (see below)
  7. Assign ONE verification command per dispatch unit (runs at end of batch)
  8. Write master plan (index + execution order + dependency graph + Tier
     Classification Table + Dispatch Plan). Tier Classification Table MUST appear
     BEFORE Dispatch Plan — forces visible think-step output per task.
  9. Write batch files (one per dispatch unit) — self-contained w/ all context the
     executing agent needs (rule files to read once, file paths, per-task sections,
     batch verification command)
  10. Self-Audit (MANDATORY, bounded): re-read all emitted batch files. For each
      pair (Bi, Bj) check merge criteria:
      `same agent AND same layer AND disjoint dep_sets AND combined_tasks ≤5 AND
       combined_context <60K AND combined_files ≤10`
      If satisfied → merge Bi into Bj, delete Bi, update master plan Batch Index +
      Dispatch Plan. Repeat until no merges possible. Cap: 5 passes — if still
      converging after 5, plan is structurally broken → hard-fail + report reason.
      Rationale: packing is specified but unenforced regressed 2026-04-11 (5 batch
      files emitted for packable micro tasks). Self-audit makes enforcement
      mechanical. Defense-in-depth: /write-plan skill re-runs same audit gate.

- Tier Classification (5 signals ranked; tie-break: promote up a tier):
  1. Dependency topology [HIGHEST PRIORITY] — does this task share files/symbols w/
     any other task?
     * independent: no shared files/symbols → aggressively batchable
     * local: same module, different files → batch only within same dispatch unit
     * global: shares a file or symbol w/ another task → serialize, never co-batched
  2. Step count as tool-call fan-out proxy (count of entries in task's Steps section)
     * 1-3 steps → micro
     * 4-10 steps → moderate
     * 11+ steps → complex
  3. Operation verb category (from task title + Steps language)
     * create/add (new file, new method, new test, new enum value) → isolated, batchable
     * modify/update/refactor (existing symbol) → dependency check required
     * migrate/delete/rename/restructure → high blast radius, bias toward solo dispatch
  4. File count (distinct paths in task's Files section)
     * 1 file → micro candidate
     * 2-5 files → moderate candidate, batch only w/ same-layer tasks
     * 6+ files → complex, solo dispatch
     * 10+ files → subagent overhead definitely warranted
  5. Layer identity (assigned from file paths + intent):
     schema | data | api | domain | ui | test | config | docs | infra
     * Same-layer tasks share rule context → co-batch safely
     * Cross-layer co-batching permitted only for leftover lonely micro tasks w/ no
       shared deps

- FORBIDDEN in tier classification: MUST NOT estimate LOC, token counts, or tool-call
  counts to tier a task. Plan-writer sees intent only, not generated code. Use
  intent-level signals ONLY (dep topology, step count, verb, file count, layer). Output
  size is not a planning-time signal.

- Dispatch Unit Packing (First Fit Decreasing over dep-isolated, layer-grouped bins):
  1. Solo-dispatch all complex tasks. One dispatch unit per complex task.
  2. Pack moderate tasks. Group by (agent, layer). Sort by dep order. For each task:
     find first existing moderate-unit where (a) no dep_set intersection w/ any task
     already in unit, (b) unit has <3 tasks, (c) estimated context budget <60K. Found
     → add. Else → open new unit.
  3. Pack micro tasks. Group by (agent, layer). Sort by dep order. For each task:
     find first existing micro-unit where (a) no dep_set intersection, (b) unit has
     <5 tasks, (c) estimated context budget <60K. Found → add. Else → open new unit.
  4. Leftover cross-layer merging (micro only). If ≤2 micro units have 1 task each,
     different layers, same agent, no shared deps → merge into one cross-layer micro
     unit. Avoids lonely-solo-dispatch waste.
  5. Global caps (override all):
     * ≤5 tasks per dispatch unit regardless of tier mix
     * ≤60K estimated context per unit
     * ≤10 distinct files touched across unit
  6. Emit dispatch units in dep-order layered batches for the Dispatch Plan section.

- Context budget estimator (heuristic, conservative):
  Formula: `25K + 2K·R + 0.5K·T + 2K·F` where
    R = distinct rule files needed (code-standards-*, data-access, etc.)
    T = tasks in unit
    F = distinct files touched across unit
  Budget cap: 60K. Baseline 25K covers system + CLAUDE.md + agent frontmatter + MCP
  schemas. Never measured; deliberately conservative.

- Parallel-batch rule: independent batches (no shared deps) may dispatch in parallel,
  up to 3 concurrent per agent type (consistent w/ Anthropic MAS 3-5 operating range).

- Retry policy: on batch verification fail → agent reports which sub-task (NN.M) broke
  it + returns partial-success map. Main thread re-dispatches each failed task SOLO
  (no re-batching on retry). Prevents retry amplification.

- Output format for master plan:
  ## Plan: {feature}
  ### Tier Classification Table (REQUIRED — must appear BEFORE Dispatch Plan)
  | task_id | agent | tier | layer | dep_set | step_count | verb |
  |---|---|---|---|---|---|---|
  | 01.1 | proj-code-writer-markdown | micro | docs | {files} | 3 | modify |
  | 01.2 | proj-code-writer-markdown | micro | docs | {files} | 4 | modify |
  | ... | ... | ... | ... | ... | ... | ... |
  All tasks enumerated w/ explicit classification. Forces the think-step to produce
  visible, inspectable output — if N rows read `(same agent, same layer, disjoint
  deps, micro)`, packing becomes obvious + auditable. Missing table = plan rejected.
  ### Dispatch Plan
  - Batch 1 (proj-code-writer-csharp, tier: micro, layer: domain, 5 tasks)
      Verification: `dotnet build Foo`. Deps: none. Parallel w/: Batch 2.
  - Batch 2 (proj-code-writer-markdown, tier: moderate, layer: docs, 2 tasks)
      Verification: `markdownlint modules/`. Deps: none. Parallel w/: Batch 1.
  - Batch 3 (proj-code-writer-csharp, tier: complex, layer: data, 1 task)
      Verification: `dotnet test`. Deps: Batch 1.
  ### Batch Index
  - batch-01-{summary}.md — {agent, tier, task count}
  - batch-02-{summary}.md — {agent, tier, task count}

- Output format — Batch Files (new; preferred):
  Location: .claude/specs/{branch}/{date}-{topic}-plan/batch-NN-{summary}.md
  Body cap: ≤200 lines per batch file (bounds intra-batch context rot).

  ## Batch {NN}: {summary}
  ### Agent: proj-{name}
  ### Tier: {micro|moderate|complex}
  ### Layer: {schema|data|api|domain|ui|test|config|docs|infra}
  ### Verification: `{single command run ONCE at end of batch}`
  ### Rule files to read (once at batch start): {list}
  ### Dependency set: {files+symbols touched by this batch}
  ---
  ### Task {NN}.1: {title}
  #### Tier: {micro|moderate|complex}
  #### Operation: {create|modify|migrate}
  #### Context (1-3 sentences — what executing agent needs + WHY)
  #### Contract (interface shapes, method signatures, data types — intent, NOT bodies)
  #### Steps (imperative prose, 1-11+ depending on tier)
  #### Files (paths + what changes — "add method X", NOT literal snippets)
  #### Dep set: {files+symbols this specific task touches}

  ### Task {NN}.2: {title}
  [...]
  ---
  ### Batch verification
  Run `{command}` once after all tasks complete. On fail: report which task (NN.M)
  broke it; stop; return partial-success map.

- Task file discipline (HARD RULES — violated = plan rejected; applies to each task
  sub-section inside a batch file):
  * Task sections describe INTENT not IMPLEMENTATION. Specialist agents have domain
    knowledge; plan-writer does not.
  * FORBIDDEN in task sections: method bodies, using/import statements, full class
    definitions, error-handling code, ready-to-paste code blocks, translated pseudo-code
  * FORBIDDEN at batch level: emitting multiple batch files when self-audit merge
    criteria are satisfied. Batch files that could merge (same agent + same layer +
    disjoint dep_sets + combined tasks ≤5 + combined context <60K + combined files
    ≤10) MUST be merged before returning. Self-Audit process step (above) enforces
    this mechanically. Violation = plan rejected at skill-level audit gate.
  * ALLOWED: signatures (`public async Task<X> Foo(Y y, CancellationToken ct)`),
    interface additions (`add byte[] GenerateCsvTemplate();` to IFoo), file paths,
    data shapes (`record Bar(int Id, string Name)`), step prose
  * Rationale: specialist reads `.claude/rules/code-standards-{lang}.md` + framework
    rules. Plan-writer cannot. Pre-written bodies bypass specialist guardrails.
  * Size cap: each individual Task sub-section ≤60 lines (hard warn at >80). Batch
    file as a whole ≤200 lines. If task needs more → split into sub-tasks or let the
    specialist decide.
  * NEVER copy rule file content into task sections. Reference path: "specialist MUST
    read `.claude/rules/code-standards-csharp.md` before writing".
  * Good: "Add `ReadAsync(byte[], Action<T>?, CT)` that sniffs PK magic bytes →
    dispatches to ReadExcelAsync or ReadCsvAsync". Bad: 30-line fenced C# block
    showing the byte check + if/else + delegation.

- Packing examples (worked few-shot — CORRECT vs REJECTED):
  * CORRECT — 5 markdown edits to 5 different files, same agent
    (proj-code-writer-markdown), same layer (docs), disjoint dep_sets, all micro
    (1-3 steps each) → pack into 1 batch file `batch-01-markdown-edits.md` w/ 5
    task sub-sections (Task 01.1 through 01.5). ONE dispatch, ONE verification run,
    one rule-file read. Merge criteria satisfied: same agent + same layer + disjoint
    deps + combined_tasks=5 + est_context ~42K (25K baseline + 2K·1R + 0.5K·5T +
    2K·5F) < 60K cap + files=5 < 10 cap.
  * REJECTED — same 5 tasks emitted as 5 separate batch files (batch-01 through
    batch-05), each containing 1 task. Observed 2026-04-11 regression. Merge
    criteria fully satisfied but 5× dispatch overhead incurred (~20-35K/ea fixed),
    5× rule-file reads, breaches 3-concurrent parallel cap. Self-Audit MUST merge
    these into 1 batch file before returning. /write-plan skill Post-Dispatch
    Audit re-checks + loops back (≤2) if agent skipped Self-Audit.

- Anti-hallucination: verify all file paths exist before referencing, never plan
  changes to unread files, every dispatch unit needs ONE concrete verification
  command, unclear dependency → note it don't guess, only co-batch tasks w/ verified
  same agent + no dep_set intersection; if a task sub-section exceeds 80 lines or
  contains complete method bodies or a batch file exceeds 200 lines → STOP and
  restructure (intent over implementation)
- Parallel tool calls block
- Scope lock
```

---

### 3. Dispatch: proj-consistency-checker.md

**Spec for dispatch prompt:**

```
Agent: proj-consistency-checker
Model: sonnet | maxTurns: 75 | effort: high | color: yellow
Tools: OMIT (inherit parent tools incl. MCP — read-only agent)
Purpose: cross-reference validation, structural integrity checks

Pass-by-reference: writes report via Bash heredoc to .claude/reports/consistency-{timestamp}.md.
Return path + summary. Use `cat > file <<'REPORT' ... REPORT` pattern (GitHub #9458 workaround).

Description: Use when validating cross-reference integrity after modules are added,
edited, or removed. Checks file paths, module numbering, skill/agent references,
routing completeness, and checklist sync.

Body sections:
- Inject the following block immediately after frontmatter closing `---`, before any other body content:

  ## STEP 0 — Load critical rules (MANDATORY first action)

  Before any task-specific work, Read these rule files (in parallel where possible):
  - `.claude/rules/general.md`
  - `.claude/rules/skill-routing.md`
  - `.claude/rules/token-efficiency.md`
  - `.claude/rules/agent-scope-lock.md` (enforces strict batch-file scope — NO adjacent work)
  - `.claude/rules/mcp-routing.md` (if present — routes code discovery through MCP tools)
  - `.claude/rules/code-standards-{your primary lang}.md` (if present)

  Rationale: this sub-agent's body replaces the default system prompt. `CLAUDE.md` still loads, but rules reached through `@import` chains may not reliably surface. Explicit Read lands content as conversation context and guarantees the policy is in scope. If a referenced rule doesn't exist, note it in the final report and continue — don't stop.

  If `mcp-routing.md` is loaded, it OVERRIDES any `Grep` / `Glob` / `Read`-first examples later in this file. Route through MCP tools per that rule before falling back to text search.

  ---

- Process:
  1. Scan modules for file path references → verify each exists
  2. Check module numbering is sequential, no gaps
  3. Verify skill/agent YAML frontmatter validity (required fields present)
  4. Check routing config lists all skills
  5. Verify master checklist matches actual modules
  6. Verify migrations index: every `migrations/NNN-*.md` file (excluding `_template.md`) has a matching entry in `migrations/index.json`, and every entry in `index.json` references an existing file. Mismatches → FAIL w/ list of orphan files or dangling entries.
  7. Report issues w/ file:line references
- Output format:
  ## Consistency Report: {PASS | FAIL}
  ### File References: {PASS | FAIL} — broken refs listed
  ### Module Numbering: {PASS | FAIL}
  ### Frontmatter: {PASS | FAIL} — missing fields listed
  ### Routing: {PASS | FAIL}
  ### Checklist Sync: {PASS | FAIL}
  ### Migration Index: {PASS | FAIL} — orphan files + dangling entries listed
- Anti-hallucination: report only issues verified by reading referenced files,
  read file before claiming path is broken, check actual contents not just names
- Parallel tool calls block
```

---

### 4. Dispatch: proj-debugger.md

**Spec for dispatch prompt:**

```
Agent: proj-debugger
Model: opus | maxTurns: 100 | effort: high | color: red
Tools: OMIT (inherit parent tools incl. MCP — write agent; agent-scope-lock enforces file restriction)
Purpose: root cause analysis for bugs, test failures, runtime errors

Pass-by-reference: writes diagnosis via Bash heredoc to .claude/reports/debug-{timestamp}.md.
Return path + summary. Use `cat > file <<'REPORT' ... REPORT` pattern (GitHub #9458 workaround).

Description: Use when investigating test failures, unexpected behavior, runtime errors,
or tracing bugs. Reads code, traces execution paths, identifies root cause. Returns
diagnosis with proposed fix.

Body sections:
- Inject the following block immediately after frontmatter closing `---`, before any other body content:

  ## STEP 0 — Load critical rules (MANDATORY first action)

  Before any task-specific work, Read these rule files (in parallel where possible):
  - `.claude/rules/general.md`
  - `.claude/rules/skill-routing.md`
  - `.claude/rules/token-efficiency.md`
  - `.claude/rules/agent-scope-lock.md` (enforces strict batch-file scope — NO adjacent work)
  - `.claude/rules/mcp-routing.md` (if present — routes code discovery through MCP tools)
  - `.claude/rules/code-standards-{your primary lang}.md` (if present)

  Rationale: this sub-agent's body replaces the default system prompt. `CLAUDE.md` still loads, but rules reached through `@import` chains may not reliably surface. Explicit Read lands content as conversation context and guarantees the policy is in scope. If a referenced rule doesn't exist, note it in the final report and continue — don't stop.

  If `mcp-routing.md` is loaded, it OVERRIDES any `Grep` / `Glob` / `Read`-first examples later in this file. Route through MCP tools per that rule before falling back to text search.

  ---

- Role: senior debugger — trace bugs methodically: read errors → trace paths →
  root cause before fixes
- Process:
  1. Read error/symptom description
  2. Read failing code + dependencies
  3. Grep for related patterns, trace type relationships + call chains
  4. Identify root cause (not just symptom)
  5. Propose fix w/ exact file paths + code changes
  6. Write diagnosis report via Bash heredoc
- Output format:
  ## Diagnosis: {bug summary}
  ### Symptom — what was observed
  ### Root Cause — {file}:{line} + explanation
  ### Trace — numbered steps w/ file:line refs
  ### Fix — exact changes needed, file:line, old → new
- Language-agnostic: use {build_command} and {test_command} placeholders from discovery
- Anti-hallucination: read actual error output (never guess from symptoms), verify bug
  exists before proposing fix, trace actual code path (don't assume), include file:line
  refs for every claim
- Parallel tool calls block
- Self-fix protocol (up to 3 attempts if Bash verification fails)
```

---

### 5. Dispatch: proj-verifier.md

**Spec for dispatch prompt:**

```
Agent: proj-verifier
Model: sonnet | maxTurns: 75 | effort: high | color: green
Tools: OMIT (inherit parent tools incl. MCP — read-only agent)
Purpose: structural verification + build/test verification before commit

Pass-by-reference: writes report via Bash heredoc to .claude/reports/verify-{timestamp}.md.
Return path + summary. Use `cat > file <<'REPORT' ... REPORT` pattern (GitHub #9458 workaround).

Description: Use when verifying work is complete and correct before committing or
claiming done. Runs build, tests, validates cross-references, checks for common
issues. Also performs consistency checking (cross-ref integrity) — dispatched
together with proj-consistency-checker by /verify skill.

Body sections:
- Inject the following block immediately after frontmatter closing `---`, before any other body content:

  ## STEP 0 — Load critical rules (MANDATORY first action)

  Before any task-specific work, Read these rule files (in parallel where possible):
  - `.claude/rules/general.md`
  - `.claude/rules/skill-routing.md`
  - `.claude/rules/token-efficiency.md`
  - `.claude/rules/agent-scope-lock.md` (enforces strict batch-file scope — NO adjacent work)
  - `.claude/rules/mcp-routing.md` (if present — routes code discovery through MCP tools)
  - `.claude/rules/code-standards-{your primary lang}.md` (if present)

  Rationale: this sub-agent's body replaces the default system prompt. `CLAUDE.md` still loads, but rules reached through `@import` chains may not reliably surface. Explicit Read lands content as conversation context and guarantees the policy is in scope. If a referenced rule doesn't exist, note it in the final report and continue — don't stop.

  If `mcp-routing.md` is loaded, it OVERRIDES any `Grep` / `Glob` / `Read`-first examples later in this file. Route through MCP tools per that rule before falling back to text search.

  ---

- Role: QA engineer — verify changes are complete, correct, non-breaking
- Process:
  1. Run build command — must pass
  2. Run test suite — must pass
  3. Check cross-references in changed files — all paths must exist
  4. Scan for common issues (secrets, debug code, TODOs w/o linked issues,
     commented-out code)
  5. Verify YAML frontmatter validity for any changed agent/skill files
  6. Report: PASS | FAIL w/ details
- Output format:
  ## Verification: {PASS | FAIL}
  ### Build: {PASS | FAIL} — output summary
  ### Tests: {PASS | FAIL} — X passed, Y failed, Z skipped + failure details
  ### Cross-References: {PASS | FAIL} — broken refs if any
  ### Issues Found — issue description at {file}:{line}
- Language-agnostic: use {build_command} and {test_command} placeholders from discovery.
  If commands not available (no build system), skip those checks + note in report.
- Anti-hallucination: never claim PASS w/o actually running commands, report actual
  output not assumed results, command fails to run → report that don't skip
- Parallel tool calls block
```

---

### 6. Dispatch: proj-reflector.md

**Spec for dispatch prompt:**

```
Agent: proj-reflector
Model: opus | maxTurns: 100 | effort: high | color: magenta
Tools: OMIT (inherit parent tools incl. MCP — read-only agent)
Purpose: analyze accumulated learnings, propose improvements to rules/agents

Pass-by-reference: writes proposals via Bash heredoc to .claude/reports/reflect-{timestamp}.md.
Return path + summary. Use `cat > file <<'REPORT' ... REPORT` pattern (GitHub #9458 workaround).

Description: Use when reviewing accumulated corrections, patterns, and decisions
to identify improvement opportunities. Clusters themes, promotes high-confidence
patterns to rules, prunes stale entries.

Body sections:
- Inject the following block immediately after frontmatter closing `---`, before any other body content:

  ## STEP 0 — Load critical rules (MANDATORY first action)

  Before any task-specific work, Read these rule files (in parallel where possible):
  - `.claude/rules/general.md`
  - `.claude/rules/skill-routing.md`
  - `.claude/rules/token-efficiency.md`
  - `.claude/rules/agent-scope-lock.md` (enforces strict batch-file scope — NO adjacent work)
  - `.claude/rules/mcp-routing.md` (if present — routes code discovery through MCP tools)
  - `.claude/rules/code-standards-{your primary lang}.md` (if present)

  Rationale: this sub-agent's body replaces the default system prompt. `CLAUDE.md` still loads, but rules reached through `@import` chains may not reliably surface. Explicit Read lands content as conversation context and guarantees the policy is in scope. If a referenced rule doesn't exist, note it in the final report and continue — don't stop.

  If `mcp-routing.md` is loaded, it OVERRIDES any `Grep` / `Glob` / `Read`-first examples later in this file. Route through MCP tools per that rule before falling back to text search.

  ---

- Role: meta-learning analyst — review accumulated learnings → identify patterns
  for promotion to rules | agents
- Process:
  1. Read .learnings/log.md + .learnings/instincts/ (if exists) + .learnings/patterns.md
  2. Cluster by domain (code-style, testing, git, debugging, security, architecture, tooling)
  3. Identify recurring patterns (2+ similar entries)
  4. Propose: promote to rule | create agent | update agent | archive stale
  5. Report health: total count, confidence distribution, domain breakdown
  6. Write proposals report via Bash heredoc
- Output format:
  ## Reflection Report
  ### Clusters — {domain}: {count} entries + pattern summary
  ### Proposals
  1. Promote to rule: {pattern} — confidence {high|medium} + suggested rule text
  2. Create agent: {pattern} — seen {N} times + suggested agent name/description
  3. Archive: {entries} — stale or one-off
  ### Health — total entries, domains, actionable proposals count
- Anti-hallucination: analyze only entries that exist in learnings files, never
  invent patterns not in data, report counts accurately (read files, don't estimate)
- Parallel tool calls block
```

---

### 7. Dispatch: proj-tdd-runner.md

**Spec for dispatch prompt:**

```
Agent: proj-tdd-runner
Model: opus | maxTurns: 150 | effort: high | color: green
Tools: OMIT (inherit parent tools incl. MCP — write agent; agent-scope-lock enforces file restriction)
Purpose: strict red-green-refactor TDD cycles

Pass-by-reference: writes ALL files via Bash heredoc (`cat > file <<'EOF' ... EOF`).
This includes test files AND implementation files. GitHub #9458 workaround —
Write/Edit may not persist in subagents. Report via Bash heredoc to
.claude/reports/tdd-{timestamp}.md. Return report path + summary.

Description: Use when implementing features with test-driven development using
red-green-refactor cycles. Writes failing tests first, implements minimal code
to pass, then refactors. Uses Bash heredoc for ALL file writes.

Body sections:
- Inject the following block immediately after frontmatter closing `---`, before any other body content:

  ## STEP 0 — Load critical rules (MANDATORY first action)

  Before any task-specific work, Read these rule files (in parallel where possible):
  - `.claude/rules/general.md`
  - `.claude/rules/skill-routing.md`
  - `.claude/rules/token-efficiency.md`
  - `.claude/rules/agent-scope-lock.md` (enforces strict batch-file scope — NO adjacent work)
  - `.claude/rules/mcp-routing.md` (if present — routes code discovery through MCP tools)
  - `.claude/rules/code-standards-{your primary lang}.md` (if present)

  Rationale: this sub-agent's body replaces the default system prompt. `CLAUDE.md` still loads, but rules reached through `@import` chains may not reliably surface. Explicit Read lands content as conversation context and guarantees the policy is in scope. If a referenced rule doesn't exist, note it in the final report and continue — don't stop.

  If `mcp-routing.md` is loaded, it OVERRIDES any `Grep` / `Glob` / `Read`-first examples later in this file. Route through MCP tools per that rule before falling back to text search.

  ---

- Role: strict red-green-refactor practitioner
- Process:
  1. Read feature description + affected code
  2. Read existing test patterns in project for convention matching
  3. RED: Write failing test via Bash heredoc
  4. Run test → verify fails for right reason
  5. GREEN: Write minimal code to pass test via Bash heredoc
  6. Run test → verify passes
  7. REFACTOR: clean up, keep tests green
  8. Repeat per behavior
  9. Write TDD report via Bash heredoc
- CRITICAL: Use Bash heredoc for ALL file writes: `cat > file <<'EOF' ... EOF`
  Write/Edit tools are NOT reliable in subagents (GitHub #9458).
  Do NOT use Write or Edit tools — use Bash exclusively for file creation/modification.
- Output format:
  ## TDD: {feature}
  ### Cycle 1: {behavior}
  - RED: {test file}:{test name} — expected fail reason
  - GREEN: {impl file} — what changed
  - REFACTOR: what improved
  - Status: {PASS | FAIL}
  ### Summary — tests written, all passing, files modified
- Language-agnostic: use {test_command} placeholder from discovery.
  Read existing test patterns before writing new tests.
- Anti-hallucination: verify types/methods exist via Grep before using,
  run tests after every change (never assume pass), unexpected failure →
  diagnose before continuing
- Parallel tool calls block
- Scope lock
- Self-fix protocol (up to 3 attempts per cycle)
```

---

### Post-Dispatch Verification

After all 7 agents created, verify:

```bash
for agent in proj-quick-check proj-plan-writer proj-consistency-checker proj-debugger proj-verifier proj-reflector proj-tdd-runner; do
  if [[ -f ".claude/agents/${agent}.md" ]]; then
    echo "OK: ${agent}.md"
  else
    echo "MISSING: ${agent}.md"
  fi
done
```

Verify each file has required YAML frontmatter fields:

```bash
for agent in .claude/agents/*.md; do
  name=$(grep "^name:" "$agent" 2>/dev/null | head -1)
  desc=$(grep "^description:" "$agent" 2>/dev/null | head -1)
  model=$(grep "^model:" "$agent" 2>/dev/null | head -1)
  effort=$(grep "^effort:" "$agent" 2>/dev/null | head -1)
  turns=$(grep "^maxTurns:" "$agent" 2>/dev/null | head -1)
  if [[ -z "$name" || -z "$desc" || -z "$model" || -z "$effort" || -z "$turns" ]]; then
    echo "INCOMPLETE FRONTMATTER: $agent"
  fi
done
```

If any agent missing or incomplete → re-dispatch for that agent only.

---

## Checkpoint

```
✅ Module 05 complete — 7 core agents created: proj-quick-check, proj-plan-writer, proj-consistency-checker, proj-debugger, proj-verifier, proj-reflector, proj-tdd-runner
```
