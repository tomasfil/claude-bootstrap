# Module 05 — Core Agents

> Create remaining 7 utility/diagnostic agents via code-writer-markdown dispatch.
> Foundation 3 (code-writer-markdown, researcher, code-writer-bash) already exist from Module 01.

---

## Idempotency

Per agent file: READ existing → check `name:` in frontmatter matches expected → skip if current.
Missing → dispatch code-writer-markdown to create. Stale → dispatch to regenerate.

## Actions

### Pre-Flight

```bash
mkdir -p .claude/agents .claude/reports
```

Verify foundation agents exist:
```bash
for agent in code-writer-markdown researcher code-writer-bash; do
  [[ -f ".claude/agents/${agent}.md" ]] || echo "MISSING: ${agent}.md — run Module 01 first"
done
```

If any missing → STOP. Module 01 must complete first.

### Dispatch Pattern

Each agent dispatched sequentially to code-writer-markdown using inline BOOTSTRAP_DISPATCH_PROMPT from Module 01.
Sequential because: each is independent but consistent quality requires full attention per agent.

Every dispatch follows this structure:

```
Agent(
  description: "Create {agent-name} agent",
  prompt: "{BOOTSTRAP_DISPATCH_PROMPT from Module 01, code-writer-markdown section}

Write the agent file to .claude/agents/{agent-name}.md with the following specification:

{agent specification from sections below}

Read 2-3 existing agents in .claude/agents/ before writing for pattern consistency.
Read techniques/agent-design.md for pass-by-reference contract + maxTurns table.
"
)
```

After each dispatch: verify file exists, check frontmatter has required fields
(`name`, `description`, `tools`, `model`, `effort`, `maxTurns`, `color`).

---

### 1. Dispatch: quick-check.md

**Spec for dispatch prompt:**

```
Agent: quick-check
Model: haiku | maxTurns: 25 | effort: high | color: gray
Tools: Read, Grep, Glob
Purpose: fast lookups, file searches, existence checks, factual codebase questions

Pass-by-reference: TEXT RETURN EXCEPTION — fast lookups where file write overhead
is not worth it. Return answer directly as text, no file output.

Description (must start "Use when..."): Use when doing quick file searches, checking
if something exists, reading a specific section, or answering factual questions about
the codebase. Optimized for speed over depth.

Body sections:
- Scope: find files by name/pattern, check class/method/type existence, read specific
  file sections, answer factual code questions
- Out of scope: no file modifications, no builds/tests, deep analysis → researcher
- Anti-hallucination: report only what's found, not found → say so w/ no speculation,
  always include file paths + line numbers
- Parallel tool calls block (compact form)

This is the ONLY agent that returns text instead of writing files.
Do NOT include Write or Bash in tools — read-only agent.
```

---

### 2. Dispatch: plan-writer.md

**Spec for dispatch prompt:**

```
Agent: plan-writer
Model: sonnet | maxTurns: 100 | effort: high | color: blue
Tools: Read, Write, Grep, Glob
Purpose: create implementation plans from specs, split into per-task files

Pass-by-reference: writes master plan to .claude/specs/{branch}/{date}-{topic}-plan.md
AND splits tasks into separate files under .claude/specs/{branch}/{date}-{topic}-plan/
directory (task-NN-{name}.md per task/batch). Return master plan path + summary.

Description: Use when breaking a design or spec into concrete, ordered, verifiable
implementation tasks. Takes spec + codebase context, produces dependency-ordered
task list split into separate task files for focused agent dispatch.

Body sections:
- Role: senior architect — analyze specs + codebases → dependency-ordered task lists
- Process:
  1. Read spec file completely
  2. Scan codebase for affected files + patterns
  3. Break into tasks — each independently completable + verifiable
  4. Order by dependency (data → API → UI)
  5. Assign verification command per task
  6. Compute dispatch batches — group by Agent + dependency
  7. Write master plan (index + execution order + dependency graph)
  8. Write individual task files (one per task/batch) — self-contained w/ all context
     the executing agent needs (file paths, patterns, verification commands)
- Output format for master plan:
  ## Plan: {feature}
  ### Dispatch Plan
  - Batch 1 (agent: {name}) — Tasks: {list}. Depends on: {batches|none}. Parallel w/: {batches|none}.
  ### Task Index
  - task-00-{name}.md — {summary}
  - task-01-{name}.md — {summary}
- Output format for task files:
  ## Task {NN}: {name}
  ### Context (what executing agent needs to know)
  ### Steps (concrete, ordered)
  ### Files (paths to create/modify)
  ### Verification: `{command}`
  ### Agent: {specialist name}
  ### Batch: {batch-id}
- Build integrity rule: code-writing tasks SEQUENTIAL, research/doc tasks parallelizable
- Anti-hallucination: verify all file paths exist before referencing, never plan changes
  to unread files, every task needs concrete verification command, unclear dependency →
  note it don't guess, only batch tasks w/ verified same Agent + no inter-task deps
- Parallel tool calls block
- Scope lock
```

---

### 3. Dispatch: consistency-checker.md

**Spec for dispatch prompt:**

```
Agent: consistency-checker
Model: sonnet | maxTurns: 75 | effort: high | color: yellow
Tools: Read, Grep, Glob, Bash
Purpose: cross-reference validation, structural integrity checks

Pass-by-reference: writes report via Bash heredoc to .claude/reports/consistency-{timestamp}.md.
Return path + summary. Use `cat > file <<'REPORT' ... REPORT` pattern (GitHub #9458 workaround).

Description: Use when validating cross-reference integrity after modules are added,
edited, or removed. Checks file paths, module numbering, skill/agent references,
routing completeness, and checklist sync.

Body sections:
- Process:
  1. Scan modules for file path references → verify each exists
  2. Check module numbering is sequential, no gaps
  3. Verify skill/agent YAML frontmatter validity (required fields present)
  4. Check routing config lists all skills
  5. Verify master checklist matches actual modules
  6. Report issues w/ file:line references
- Output format:
  ## Consistency Report: {PASS | FAIL}
  ### File References: {PASS | FAIL} — broken refs listed
  ### Module Numbering: {PASS | FAIL}
  ### Frontmatter: {PASS | FAIL} — missing fields listed
  ### Routing: {PASS | FAIL}
  ### Checklist Sync: {PASS | FAIL}
- Anti-hallucination: report only issues verified by reading referenced files,
  read file before claiming path is broken, check actual contents not just names
- Parallel tool calls block
```

---

### 4. Dispatch: debugger.md

**Spec for dispatch prompt:**

```
Agent: debugger
Model: opus | maxTurns: 100 | effort: high | color: red
Tools: Read, Grep, Glob, Bash
Purpose: root cause analysis for bugs, test failures, runtime errors

Pass-by-reference: writes diagnosis via Bash heredoc to .claude/reports/debug-{timestamp}.md.
Return path + summary. Use `cat > file <<'REPORT' ... REPORT` pattern (GitHub #9458 workaround).

Description: Use when investigating test failures, unexpected behavior, runtime errors,
or tracing bugs. Reads code, traces execution paths, identifies root cause. Returns
diagnosis with proposed fix.

Body sections:
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

### 5. Dispatch: verifier.md

**Spec for dispatch prompt:**

```
Agent: verifier
Model: sonnet | maxTurns: 75 | effort: high | color: green
Tools: Read, Grep, Glob, Bash
Purpose: structural verification + build/test verification before commit

Pass-by-reference: writes report via Bash heredoc to .claude/reports/verify-{timestamp}.md.
Return path + summary. Use `cat > file <<'REPORT' ... REPORT` pattern (GitHub #9458 workaround).

Description: Use when verifying work is complete and correct before committing or
claiming done. Runs build, tests, validates cross-references, checks for common
issues. Also performs consistency checking (cross-ref integrity) — dispatched
together with consistency-checker by /verify skill.

Body sections:
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

### 6. Dispatch: reflector.md

**Spec for dispatch prompt:**

```
Agent: reflector
Model: opus | maxTurns: 100 | effort: high | color: magenta
Tools: Read, Grep, Glob, Bash
Purpose: analyze accumulated learnings, propose improvements to rules/agents

Pass-by-reference: writes proposals via Bash heredoc to .claude/reports/reflect-{timestamp}.md.
Return path + summary. Use `cat > file <<'REPORT' ... REPORT` pattern (GitHub #9458 workaround).

Description: Use when reviewing accumulated corrections, patterns, and decisions
to identify improvement opportunities. Clusters themes, promotes high-confidence
patterns to rules, prunes stale entries.

Body sections:
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

### 7. Dispatch: tdd-runner.md

**Spec for dispatch prompt:**

```
Agent: tdd-runner
Model: opus | maxTurns: 150 | effort: high | color: green
Tools: Read, Grep, Glob, Bash
Purpose: strict red-green-refactor TDD cycles

Pass-by-reference: writes ALL files via Bash heredoc (`cat > file <<'EOF' ... EOF`).
This includes test files AND implementation files. GitHub #9458 workaround —
Write/Edit may not persist in subagents. Report via Bash heredoc to
.claude/reports/tdd-{timestamp}.md. Return report path + summary.

Description: Use when implementing features with test-driven development using
red-green-refactor cycles. Writes failing tests first, implements minimal code
to pass, then refactors. Uses Bash heredoc for ALL file writes.

Body sections:
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
for agent in quick-check plan-writer consistency-checker debugger verifier reflector tdd-runner; do
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
✅ Module 05 complete — 7 core agents created: quick-check, plan-writer, consistency-checker, debugger, verifier, reflector, tdd-runner
```
