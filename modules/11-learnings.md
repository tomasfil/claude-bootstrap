# Module 11 — Initialize Self-Improvement Log

> Create `.learnings/` directory with structured learnings system, instinct schema, and session tracking.

---

## Idempotency

```
IF .learnings/ exists → PRESERVE all entries, don't overwrite
IF missing → CREATE with templates
IF instincts/ missing → CREATE directory
IF new files missing (patterns.md, decisions.md, environment.md) → CREATE templates
```

## Create Directory

```bash
mkdir -p .learnings/instincts
```

## Directory Structure

```
.learnings/
├── log.md                 # Raw capture (ephemeral — corrections, failures, discoveries)
├── observations.jsonl     # Hook-captured tool usage patterns (auto-generated)
├── instincts/             # Atomic behaviors with confidence scores (.md files with YAML frontmatter)
├── patterns.md            # Recurring coding patterns (consolidated from log.md)
├── decisions.md           # Architectural decisions with rationale
├── environment.md         # Platform/tool discoveries
├── .session-count         # Session counter (auto-incremented by SessionStart hook)
├── .last-dream            # Timestamp of last /consolidate run
└── .last-reflect-lines    # Line count of log.md at last /reflect run
```

---

## 1. Create `.learnings/log.md`

Only create if it doesn't exist:

```markdown
# Learnings Log

> Corrections, discoveries, and patterns. Managed by Self-Improvement triggers in CLAUDE.md.
> Run `/reflect` to promote pending entries to rules/CLAUDE.md or instincts.

## Format

Entries use compressed telegraphic notation (Claude-facing file, not human-facing).
Each entry:
```
### {date} — {category}: {summary}
Status: pending review | promoted ({destination}) | dismissed ({reason})
{Compressed details — no articles, telegraphic style, use → | + symbols}
Domain: {tag1} | {tag2}
```

## Categories
- correction — user corrected approach
- failure — cmd/tool failed, root cause identified
- gotcha — non-obvious behavior
- agent-candidate — task needing dedicated agent
- environment — OS/tool/platform discovery

---

{Entries will be added here by the Self-Improvement triggers}
```

## 2. Create `.learnings/observations.jsonl`

Only create if it doesn't exist:

```
```

This file is auto-populated by hooks. Each line is a JSON object with tool usage data.

## 3. Create `.learnings/patterns.md`

Only create if it doesn't exist:

```markdown
# Recurring Patterns

> Consolidated from log.md by `/reflect`. Patterns that appear 2+ times become instincts.

---

{Patterns will be added here by /reflect}
```

## 4. Create `.learnings/decisions.md`

Only create if it doesn't exist:

```markdown
# Architectural Decisions

> Record significant design choices and their rationale.

## Format

Each entry:
```
### {date} — {decision summary}
Context: {what prompted this decision}
Decision: {what was decided}
Rationale: {why}
Alternatives: {what was considered and rejected}
```

---

{Decisions will be added here}
```

## 5. Create `.learnings/environment.md`

Only create if it doesn't exist:

```markdown
# Environment Discoveries

> Platform, tool, and runtime-specific findings.

---

{Discoveries will be added here}
```

## 6. Create tracking files

Only create each if it doesn't exist:

`.learnings/.session-count`:
```
0
```

`.learnings/.last-dream`:
```
0
```

`.learnings/.last-reflect-lines`:
```
0
```

---

## Instinct System

Instincts are atomic, confidence-scored behaviors stored as `.md` files with YAML frontmatter in `.learnings/instincts/`.

**Important:** Instincts use `.md` files with YAML frontmatter, NOT pure `.yaml` files. Pure YAML has proven parsing bugs in Claude Code environments.

### Schema

Each instinct file (e.g., `.learnings/instincts/guard-clauses.md`):

```yaml
---
id: guard-clauses
trigger: "When writing conditional logic"
action: "Use guard clauses / early returns instead of nested if-else"
confidence: 0.7
domain: code-style
source: "User correction on 2026-03-15"
scope: project
evidence:
  - "User said 'always use guard clauses' — 2026-03-15"
  - "Reinforced when reviewing PR #42 — 2026-03-20"
---
```

### Fields

| Field | Required | Description |
|-------|----------|-------------|
| id | Yes | Kebab-case identifier matching filename |
| trigger | Yes | When this instinct activates |
| action | Yes | What to do when triggered |
| confidence | Yes | 0.3-0.9 score |
| domain | Yes | code-style, testing, git, debugging, security, architecture, tooling |
| source | Yes | How this instinct was learned |
| scope | Yes | project (this project only) or global (all projects) |
| evidence | No | List of reinforcement/contradiction events |

### Confidence Mechanics

- **Initial**: 0.5 (learned from single correction)
- **Reinforcement**: +0.1 when same pattern confirmed (cap at 0.9)
- **Contradiction**: -0.05 when pattern contradicted
- **Promotion**: At 0.8+ confidence, propose promotion to `.claude/rules/` (via /reflect)
- **Pruning**: Below 0.3, archive or delete (via /reflect)
- **Never 1.0**: Even strong instincts can be wrong — always allow contradiction

### Lifecycle

1. **Born**: User correction or repeated observation creates instinct at 0.5
2. **Reinforced**: Same pattern confirmed — confidence +0.1
3. **Contradicted**: Conflicting evidence — confidence -0.05
4. **Promoted**: High confidence (0.8+) — /reflect proposes rule in `.claude/rules/`
5. **Pruned**: Low confidence (<0.3) — /reflect archives or removes

---

## Self-Improvement Integration

The three triggers defined in CLAUDE.md feed into this system:

1. **User correction** — Log to `log.md`, then create or reinforce an instinct in `instincts/`
2. **Command/tool failure** — Log to `log.md`, add to `environment.md` if platform-specific
3. **Agent-candidate** — Log to `log.md` with `agent-candidate` category

> **Note:** Bash command failures (non-zero exit code) are auto-logged by the `log-failures.sh` PostToolUse hook (Module 04). Claude only needs to manually log: user corrections, gotchas, and agent-candidates.

The `/reflect` skill reads `log.md`, promotes recurring patterns to instincts, adjusts confidence scores on existing instincts, and proposes high-confidence instincts for promotion to `.claude/rules/`.

---

## Checkpoint

```
✅ Module 11 complete — .learnings/ initialized with log, patterns, decisions, environment, instincts directory, and session tracking
```
