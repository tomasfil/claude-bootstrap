# Module 04 — Learnings System

> Initialize `.learnings/` directory w/ structured log, instinct schema, session tracking. Inline module — mkdir + touch, no agent dispatch.

---

## Idempotency

```
IF .learnings/ exists → PRESERVE all entries; never overwrite
IF missing → CREATE w/ templates
IF instincts/ missing → CREATE directory
IF individual files missing → CREATE only those files
```

## Actions

### 1. Create directory structure

```bash
mkdir -p .learnings/instincts
```

### 2. Create `.learnings/log.md`

Skip if exists:

```markdown
# Learnings Log

> Corrections, discoveries, patterns. Managed by Self-Improvement triggers in CLAUDE.md.
> Run `/reflect` to promote pending entries to rules/CLAUDE.md or instincts.

## Format

Entries use compressed telegraphic notation (Claude-facing, not human-facing).
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
- review-finding — code review identified systematic issue; tag: agent:{specialist-name}

---

{Entries added by Self-Improvement triggers}
```

### 3. Create `.learnings/observations.jsonl`

Skip if exists. Create empty file — auto-populated by hooks (each line = JSON object w/ tool usage data).

### 4. Create `.learnings/patterns.md`

Skip if exists:

```markdown
# Recurring Patterns

> Consolidated from log.md by `/reflect`. Patterns appearing 2+ times become instincts.

---

{Patterns added by /reflect}
```

### 5. Create `.learnings/decisions.md`

Skip if exists:

```markdown
# Architectural Decisions

> Record significant design choices + rationale.

## Format

Each entry:
```
### {date} — {decision summary}
Context: {what prompted this}
Decision: {what was decided}
Rationale: {why}
Alternatives: {considered + rejected}
```

---

{Decisions added here}
```

### 6. Create `.learnings/environment.md`

Skip if exists:

```markdown
# Environment Discoveries

> Platform, tool, runtime-specific findings.

---

{Discoveries added here}
```

### 7. Create tracking files

Skip each if exists:

| File | Initial value | Purpose |
|------|--------------|---------|
| `.learnings/.session-count` | `0` | Session counter — auto-incremented by SessionStart hook |
| `.learnings/.last-dream` | `0` | Timestamp of last `/consolidate` run |
| `.learnings/.last-reflect-lines` | `0` | Line count of log.md at last `/reflect` run |

---

## Instinct System

Instincts = atomic, confidence-scored behaviors stored as `.md` files w/ YAML frontmatter in `.learnings/instincts/`.

**Format:** `.md` w/ YAML frontmatter, NOT pure `.yaml`. Pure YAML has parsing bugs in Claude Code environments.

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
  - "Reinforced reviewing PR #42 — 2026-03-20"
---
```

### Fields

| Field | Req | Description |
|-------|-----|-------------|
| id | Y | Kebab-case identifier matching filename |
| trigger | Y | When this instinct activates |
| action | Y | What to do when triggered |
| confidence | Y | 0.3–0.9 score |
| domain | Y | code-style \| testing \| git \| debugging \| security \| architecture \| tooling |
| source | Y | How instinct was learned |
| scope | Y | project (this project) \| global (all projects) |
| evidence | N | List of reinforcement/contradiction events |

### Confidence Mechanics

- **Initial**: 0.5 (single correction)
- **Reinforcement**: +0.1 when pattern confirmed (cap 0.9)
- **Contradiction**: -0.05 when pattern contradicted
- **Promotion**: 0.8+ → propose promotion to `.claude/rules/` via /reflect
- **Pruning**: <0.3 → archive or delete via /reflect
- **Never 1.0**: strong instincts can be wrong — always allow contradiction

### Lifecycle

1. **Born** — correction or repeated observation → instinct at 0.5
2. **Reinforced** — same pattern confirmed → confidence +0.1
3. **Contradicted** — conflicting evidence → confidence -0.05
4. **Promoted** — 0.8+ confidence → /reflect proposes rule in `.claude/rules/`
5. **Pruned** — <0.3 confidence → /reflect archives or removes

---

## Self-Improvement Integration

Three triggers from CLAUDE.md feed this system:

1. **User correction** → log to `log.md` + create/reinforce instinct in `instincts/`
2. **Command/tool failure** → log to `log.md` + add to `environment.md` if platform-specific
3. **Agent-candidate** → log to `log.md` w/ `agent-candidate` category

> Bash failures (non-zero exit) auto-logged by `log-failures.sh` PostToolUse hook (Module 03). Manual logging only needed for: corrections, gotchas, agent-candidates.

`/reflect` reads `log.md`, promotes recurring patterns → instincts, adjusts confidence on existing instincts, proposes high-confidence instincts for `.claude/rules/` promotion.

---

## Checkpoint

```
✅ Module 04 complete — .learnings/ initialized with log, patterns, decisions, environment, instincts directory, and session tracking
```
