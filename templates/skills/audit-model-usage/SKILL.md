---
name: audit-model-usage
description: >
  Use when auditing agent and skill frontmatter for model/effort compliance against
  the project's policy tables. Reports DRIFT, UNKNOWN, COMPLIANT counts. Read-only.
model: sonnet
effort: medium
allowed-tools: Read Grep Glob
---
# Skill Class: main-thread — inline reads (low consequence) [latency: interactive]
# medium: orchestrator-shell effort per techniques/agent-design.md footnote (inline reads class, low consequence)

## Actions

### Phase 1: Load policy
Check `.claude/rules/model-selection.md` exists.
IF present → read Agent Classification Table + Skill Classification Table.
IF absent → fallback mode (minimal 3-tier heuristic from CLAUDE.md only); emit WARN;
all classifications marked `[UNKNOWN-FALLBACK]`.

### Phase 2: Enumerate
Glob `.claude/agents/*.md` → agent list.
Glob `.claude/skills/*/SKILL.md` → skill list.

### Phase 3: Extract frontmatter
For each file: `grep -n "^model:\|^effort:\|^name:\|^# Skill Class:" {file}`
Parse the 3-4 key lines into {name, model, effort, skill_class}.

### Phase 4: Classify
For each agent:
  Find row in Agent Classification Table by exact name match first.
  IF no exact match → try prefix wildcard match (e.g., "proj-code-writer-*").
  IF row found → compare (actual_model, actual_effort) vs (expected_model, expected_effort):
    match → COMPLIANT
    mismatch → DRIFT (record expected vs actual)
  IF no row found → UNKNOWN

For each skill:
  Read `# Skill Class:` comment → match to Skill Classification Table.
  Same COMPLIANT/DRIFT/UNKNOWN logic.

Fallback (no model-selection.md): minimal 3-tier heuristic:
  name contains "code-writer" or "test-writer" or "tdd-runner" → expect opus
  name contains "quick-check" → expect haiku
  otherwise → expect sonnet
  mark all as [UNKNOWN-FALLBACK]

### Phase 5: Report
Write report to `.claude/reports/model-usage-audit.md` via Bash heredoc.
Report sections: COMPLIANT count, DRIFT list (with expected vs actual), UNKNOWN list, WARN for INHERITED_DEFAULT debt markers.
Return path + summary.
Next step text: "Run the bulk frontmatter patch migration" and "Run the model-selection
policy migration" if DRIFT detected. Do NOT hardcode migration numbers.
