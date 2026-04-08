# Migration: review-findings-pipeline

> Wire project-code-reviewer output into learnings pipeline w/ new `review-finding` category + /consolidate clustering pass

---

```yaml
# --- Migration Metadata ---
id: "022"
name: "Review Pipeline + Techniques + Plan Batching"
description: >
  Three coupled updates: (1) wires project-code-reviewer to learnings pipeline
  via review-finding log category + /consolidate Phase 2b clustering;
  (2) syncs improved technique files (prompt-engineering, agent-design,
  glyph-notation, token-efficiency); (3) adds batch-dispatch support to
  /write-plan + /execute-plan + plan-writer for token/turn efficiency.
base_commit: "ce4711c"
date: "2026-04-05"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| modify | `.claude/agents/project-code-reviewer.md` | Add Edit to tools; Phase 6 log-emit; Section 7b schema |
| modify | `.claude/skills/consolidate/SKILL.md` | Add Phase 2b clustering + Phase 3 promotion proposals |
| modify | `CLAUDE.md` | Append `review-finding` to Self-Improvement categories line |
| modify | `.learnings/log.md` | Append `review-finding` to categories list (if file exists) |
| modify | `techniques/prompt-engineering.md` | Add Modern LLM Guidance section (scope locks, compression ranges, RCCF caveat, eval harness) |
| modify | `techniques/agent-design.md` | Add Inter-Agent Handoff Formats section (production patterns, essential fields, design rules) |
| add | `techniques/glyph-notation.md` | NEW — compression notation reference (symbols, tiers, retention floors, protected regions, handoff schema) |
| add | `techniques/token-efficiency.md` | NEW — compression rules, turn reduction, tiers, retention floors, algorithmic tools |
| modify | `techniques/INDEX.md` | Add 2 rows to Files table + 3 rows to Canonical Ownership table |
| modify | `.claude/skills/write-plan/SKILL.md` | Add Dispatch Plan output section + Batching rules + Batch field |
| modify | `.claude/skills/execute-plan/SKILL.md` | Add Batch Dispatch Protocol section; batch-by-batch execution |
| modify | `.claude/agents/plan-writer.md` | Add Dispatch Plan to Output Format + Batch field per task |

---

## Actions

### Step 1 — Update project-code-reviewer agent

Read `.claude/agents/project-code-reviewer.md`. Skip entire step if file missing.

**(a) Add `Edit` to tools line in YAML frontmatter.** Find `tools:` line, append `, Edit` if not already present. Example:

```yaml
tools: Read, Grep, Glob, LSP
```

Becomes:

```yaml
tools: Read, Grep, Glob, LSP, Edit
```

**(b) Insert Section 7b after Report Format (Section 7) closing fence.** If agent lacks numbered Section 7, insert this block immediately before the Anti-Hallucination section:

````markdown
#### 7b. Log-Ready Finding Schema

For each MUST FIX or SHOULD FIX finding that is systematic (recurring pattern or missing rule, not a one-off typo), produce a log entry:

```
### {YYYY-MM-DD} — review-finding: {concise pattern name}
Status: pending review
Agent: {agent-name-that-produced-the-code}
Pattern: {compressed — what rule was violated}
Evidence: {file}:{line} — {one-line description}
Domain: {code-style | security | architecture | testing | tooling}
```

Rules:
- One entry per finding pattern per review — not one per occurrence
- `Agent:` must name the specialist that wrote the code; use `agent:unknown` if not determinable
- Systematic = recurring pattern or missing rule; one-off typos and trivial naming do NOT qualify
````

**(c) Insert Phase 6 block after Anti-Hallucination section.** If agent uses Phase structure, insert as `## Phase 6 — Emit Findings to Learnings` before Checkpoint. If agent lacks Phase structure, insert at end of agent body titled `## Emit Findings to Learnings`:

````markdown
## Phase 6 — Emit Findings to Learnings

After producing the report, append systematic findings to `.learnings/log.md`.

1. Check `.learnings/log.md` exists — if missing, skip Phase 6 entirely
2. Read `.learnings/log.md` — extract all `review-finding` entries w/ `Status: pending review`
3. For each MUST FIX / SHOULD FIX finding that qualifies as systematic:
   - Build entry using schema from Section 7b
   - Skip if entry w/ same `Pattern:` value already exists w/ `Status: pending review`
   - Use Edit to append entry to `.learnings/log.md`
4. Do NOT append: one-off typos, trivial formatting, variable naming
5. Do NOT edit any file except `.learnings/log.md` — Edit tool is restricted to log append only
6. Report: "Logged {N} systematic finding(s) to .learnings/log.md" (N may be 0)
````

### Step 2 — Update /consolidate skill

Read `.claude/skills/consolidate/SKILL.md`. Skip entire step if file missing.

**(a) Insert Phase 2b between Phase 2 and Phase 3.** Find `### Phase 3` heading, insert immediately before it:

```markdown
### Phase 2b: Cluster Review Findings
- Filter log: category == `review-finding`, status == `pending review`
- Group by `Agent:` tag value
- Within each group, cluster entries by `Pattern:` similarity (same rule, same component type)
- Cluster w/ 2+ entries → **promotion candidate**
  - Target: agent's Known Gotchas section in `.claude/agents/{name}.md`
  - Pattern framework-specific + agent has sub-specialists → also flag as `/evolve-agents` candidate (note only — do not run)
- Single-entry findings → flag as one-off, schedule for pruning this cycle
- Output: promotion candidates list + one-offs list
```

**(b) Extend Phase 3 w/ new bullet.** INSERT (do not replace) after existing Phase 3 bullets, before any `Apply approved changes.` line:

```markdown
- **Review-finding promotions** (from Phase 2b): for each promotion candidate:
  - Show: agent name, pattern, evidence count, proposed text addition
  - Choices: promote to agent prompt (add to Known Gotchas) | dismiss | defer
  - If `/evolve-agents` flagged: surface recommendation alongside — do not auto-execute
  - If user approves: use Edit to add to agent's Known Gotchas section
```

### Step 3 — Update CLAUDE.md categories

Read `CLAUDE.md`. Find line matching:

```
Categories: correction | failure | gotcha | agent-candidate | environment
```

Append ` | review-finding`:

```
Categories: correction | failure | gotcha | agent-candidate | environment | review-finding
```

Skip if `review-finding` already present.

### Step 4 — Update .learnings/log.md categories

Check `.learnings/log.md` exists. If missing, skip step.

If present, find `## Categories` section, append line after last existing category entry:

```
- review-finding — code review identified systematic issue; tag format: agent:{specialist-name}
```

Skip if `review-finding` entry already present.

### Step 5 — Sync technique files from bootstrap repo

Fetch updated technique files from bootstrap repo into project's `.claude/references/techniques/` directory. Per the rule "Technique update = sync step in migration", client projects need these files copied.

```bash
mkdir -p .claude/references/techniques

for file in prompt-engineering.md agent-design.md glyph-notation.md token-efficiency.md INDEX.md; do
  gh api repos/{owner}/{repo}/contents/techniques/$file \
    --jq '.content' | base64 -d > .claude/references/techniques/$file
done
```

### Step 6 — Add batching to /write-plan skill

Read `.claude/skills/write-plan/SKILL.md`. Skip step if file missing. In skill body (inside ```markdown fence):

**(a)** Add a "Compute dispatch batches" step before the save step in the numbered list.

**(b)** Insert new section BEFORE `### Task Format`:

````markdown
### Batching (token + turn efficiency)
Group tasks into dispatch batches:
- Same `Agent:` field → batch candidate
- Inter-task dependency blocks batching (B depends on A → different batches)
- Related scope (same subsystem | same file-type) preferred within batch
- Batch = single agent dispatch w/ merged prompt listing all task details
- Parallel batches (no inter-batch deps) → dispatch in ONE message (multiple Agent calls)

Output `### Dispatch Plan` section BEFORE task list:
- **Batch 1** (agent: {name}) — Tasks: 1,2,3. Depends on: none. Parallel w/: Batch 2.
- **Batch 2** (agent: {name}) — Tasks: 4. Depends on: Batch 1. Parallel w/: none.
````

**(c)** Add `Batch: {batch-id}` line to Task Format between `Agent:` and blank line.

### Step 7 — Add batch dispatch to /execute-plan skill

Read `.claude/skills/execute-plan/SKILL.md`. Skip step if file missing. Apply:

**(a)** Change "Execute task by task in dependency order" → "Execute batch by batch in dependency order (see Batch Dispatch Protocol)"

**(b)** Change "Checkpoint after each task" → "Checkpoint after each batch"

**(c)** Insert new section BEFORE `### Per-Task Protocol`:

````markdown
### Batch Dispatch Protocol
- Read batch's tasks from Dispatch Plan
- Single agent call per batch w/ merged prompt: include ALL batch's tasks w/ full details
- Parallel batches (no inter-batch deps) → dispatch as multiple Agent calls in ONE message
- Sequential batches → complete batch N, verify, then dispatch batch N+1
- Agent reports per-task status — verify each before marking batch complete
````

**(d)** Rename `### Per-Task Protocol` → `### Per-Task Protocol (within batch)`

### Step 8 — Update plan-writer agent output format

Read `.claude/agents/plan-writer.md`. Skip step if file missing. In Output Format section:

**(a)** Add Dispatch Plan block before Tasks list:

```
### Dispatch Plan
- **Batch 1** (agent: {name}) — Tasks: {list}. Depends on: {batches|none}. Parallel w/: {batches|none}.
```

**(b)** Add per-task fields `Agent: {specialist}` + `Batch: {batch-id}` to each task in output format template.

**(c)** Add anti-hallucination rule:

```
- Only batch tasks w/ verified same Agent + no inter-task deps between them
```

### Step 9 — Wire + verify

1. Confirm `Edit` in `.claude/agents/project-code-reviewer.md` tools line
2. Confirm log-emit section (Phase 6 or "Emit Findings to Learnings") in reviewer body
3. Confirm Section 7b finding schema in reviewer body
4. Confirm Phase 2b block in `.claude/skills/consolidate/SKILL.md`
5. Confirm `review-finding` in CLAUDE.md categories line
6. Confirm `.claude/references/techniques/` has 5 files (INDEX + 4 technique files)
7. Confirm `.claude/references/techniques/prompt-engineering.md` has "Modern LLM Guidance" section
8. Confirm `.claude/references/techniques/agent-design.md` has "Inter-Agent Handoff Formats" section
9. Confirm `.claude/skills/write-plan/SKILL.md` has "Dispatch Plan" + "Batching" content
10. Confirm `.claude/skills/execute-plan/SKILL.md` has "Batch Dispatch Protocol"
11. Confirm `.claude/agents/plan-writer.md` has "Dispatch Plan" in Output Format
12. No broken cross-references introduced

---

## Verify

- [ ] `.claude/agents/project-code-reviewer.md` has `Edit` in tools list
- [ ] `.claude/agents/project-code-reviewer.md` contains finding schema + log-emit instructions
- [ ] `.claude/skills/consolidate/SKILL.md` contains Phase 2b clustering block
- [ ] `.claude/skills/consolidate/SKILL.md` Phase 3 contains Review-finding promotions bullet
- [ ] `CLAUDE.md` categories line includes `review-finding`
- [ ] `.learnings/log.md` categories list includes `review-finding` entry (if file exists)
- [ ] No duplicate entries introduced

---

Migration complete: `022` — Wire reviewer findings into learnings pipeline w/ clustering promotion
