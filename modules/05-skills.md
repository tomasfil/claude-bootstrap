# Steps 5-7 — Create Skills

## Step 5 — reflect Skill

> **Mode C**: If reflect skill exists, read it first. Preserve customizations, fill gaps.

Create `.claude/skills/reflect/SKILL.md`:

### Frontmatter

```yaml
---
name: reflect
description: "USE THIS after every few sessions or when corrections pile up. Analyzes .learnings/log.md, evolves rules/agents/skills, audits plugins. Run with /reflect — this is how the project gets smarter over time."
---
```

### 12-Step Process (generate full content from these specs)

1. **Read learnings** — parse `.learnings/log.md`, categorize by trigger type
2. **Read agent usage** — parse `.learnings/agent-usage.log`, identify patterns (frequent agents, failures, unused agents)
3. **Review current config** — read CLAUDE.md, all rules in `.claude/rules/`, all agents in `.claude/agents/`
4. **Promote pending learnings** — for each `status: pending review` entry:
   - Style corrections → `.claude/rules/code-standards.md` Style section
   - Gotchas → CLAUDE.md Gotchas section
   - Workflow lessons → CLAUDE.md Workflow or relevant rule
   - Mark as `status: promoted` with destination
5. **Evolve subagents** — based on agent-usage.log and learnings:
   - Create new agents for recurring agent-candidate patterns
   - Retire unused agents (0 usage over multiple sessions)
   - Improve agent prompts based on failure patterns
   - Suggest parallelization opportunities
6. **Plugin audit** — scan marketplace cache, detect project signals:
   - 3-tier matching (LSP by extension, Framework by deps, Universal)
   - Conflict detection (agent names, hook overlaps, skill names)
   - LSP prerequisites check
   - Report: recommend new, flag outdated, note conflicts
7. **Identify gaps** — rules that should exist but don't (patterns in corrections with no matching rule)
8. **Check sizes** — CLAUDE.md <=120 lines, rules files reasonable length
9. **Mine git history** — check recent commits for patterns (repeated fix-ups suggest missing rules)
10. **Propose changes** — present all proposed modifications as a numbered list
11. **Wait for approval** — STOP and ask user to approve/reject each change
12. **Apply approved changes** — make modifications, mark learnings as promoted

### Meta-Rules for Writing Rules

- Rules must be falsifiable (testable, not vague aspirations)
- One concept per rule — no compound rules
- Include rationale inline when non-obvious
- Prefer positive ("use X") over negative ("don't use Y") unless it's a safety rule

### Meta-Rules for Proposing Agents

- Agent must have a clear, repeating use case (not a one-off)
- Scope tools minimally — read-only agents should not get Write/Edit
- Include expected input/output format in the agent prompt
- Model selection: sonnet for fast/simple, opus for complex reasoning

## Step 6 — audit-file Skill

> **Mode C**: If exists, preserve.

Create `.claude/skills/audit-file/SKILL.md`:

```yaml
---
name: audit-file
description: "Audit a file against project code standards. Usage: /audit-file path/to/file.ts"
---
```

**Spec**: Read `$ARGUMENTS` as file path. Read `.claude/rules/code-standards.md`. Audit the file against every applicable rule. Report findings in YAML format:

```yaml
file: path/to/file.ts
findings:
  - rule: "Functions < 40 lines"
    status: pass|fail|warning
    details: "..."
summary: {pass_count}/{total_count} rules passed
```

## Step 7 — audit-memory Skill

> **Mode C**: If exists, preserve.

Create `.claude/skills/audit-memory/SKILL.md`:

```yaml
---
name: audit-memory
description: "Audit project memory systems for staleness, conflicts, and optimization opportunities."
allowed-tools: Read, Glob, Grep, Bash
user-invocable: true
---
```

**Spec**: Audit both memory systems:
- **Auto Memory**: Read `~/.claude/projects/<project>/memory/` files
- **.learnings/**: Read `.learnings/log.md` and `.learnings/agent-usage.log`

Check for: stale entries (>30 days with no related activity), broken file references, duplicate entries across systems, contradictions between memory and current rules, pending learnings that should be promoted.

Output structured report with recommended actions.

## write-prompt Skill

> **Mode C**: If exists, preserve.

Create `.claude/skills/write-prompt/SKILL.md`:

```yaml
---
name: write-prompt
description: "Guide for writing effective skills, agents, and CI prompts. Reference for prompt engineering patterns."
---
```

### Skill Structure

```
.claude/skills/{skill-name}/
  SKILL.md          # Entry point (loaded on invocation, ~100 token metadata cost)
  context/          # Optional deep context (loaded via @import or context: fork)
    examples.md
    reference.md
```

Progressive disclosure — 3-level loading:
1. **Frontmatter only** (~100 tokens) — always loaded for matching
2. **SKILL.md body** — loaded on invocation
3. **context/** files — loaded on demand via @import

### YAML Frontmatter Fields

```yaml
name: skill-name                    # required
description: "..."                  # required — pushy, tells Claude WHEN to use it
disable-model-invocation: true      # optional — only via /skill-name
user-invocable: true                # optional — appears in / menu
context: fork                       # optional — runs in separate context window
allowed-tools: Read, Grep, Glob     # optional — restrict available tools
```

### Subagent Structure

```
.claude/agents/{agent-name}.md      # Single file with YAML frontmatter
```

### 7 Principles for Writing Prompts

1. **Be explicit** — state exactly what you want, format, constraints
2. **One task per prompt** — don't bundle unrelated work
3. **Provide context** — include relevant file paths, patterns, conventions
4. **Constrain output** — specify format (YAML, markdown, code), length limits
5. **Handle empty/error** — tell the prompt what to do when inputs are missing
6. **Match effort to complexity** — simple tasks get simple prompts
7. **Workflow patterns** — chain skills with agents; use skills for knowledge, agents for execution

### Complementary Plugins

- `superpowers/writing-skills` — templates and scaffolding for skill creation
- `skill-creator` — interactive skill builder

## Wiring Checks (reflect skill)

Verify reflect skill SKILL.md contains:
- [ ] References `.learnings/log.md`
- [ ] References `.learnings/agent-usage.log`
- [ ] Includes plugin audit step
- [ ] Has "wait for approval" before applying changes

## Checkpoints

Print: `Step 5 complete — reflect skill created`
Print: `Step 6 complete — audit-file skill created`
Print: `Step 7 complete — audit-memory + write-prompt skills created`
