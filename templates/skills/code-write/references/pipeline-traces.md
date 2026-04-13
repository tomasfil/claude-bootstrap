# Pipeline Traces — Bootstrap Project

> Which files change together for each feature type.
> Used by /code-write to map the full change set before dispatching specialists.
> Module range: 01-09 (v6 bootstrap).

---

## new-module

Files (in order):
1. `modules/NN-kebab-case.md` — create module w/ standard structure
2. `claude-bootstrap.md` — add module to master checklist
3. `.claude/settings.json` — update routing hook if module creates new skills

Verification:
- Module file exists + starts w/ `# Module NN — Title`
- Checklist entry in claude-bootstrap.md matches
- Module number sequential (no gaps), range 01-09

---

## new-skill

Files (in order):
1. `.claude/skills/{name}/SKILL.md` — create skill w/ YAML frontmatter
2. `.claude/rules/skill-routing.md` — add skill to routing rules
3. `.claude/settings.json` — UserPromptSubmit nudge hook (3-tier routing)
4. `CLAUDE.md` — add skill to Skill Automation section (if applicable)

Optional:
5. `.claude/skills/{name}/references/*.md` — reference docs for progressive disclosure

Routing (3-tier):
- Tier 1: skill `description` field in YAML frontmatter → native Claude Code matching
- Tier 2: `.claude/rules/skill-routing.md` → contextual rule-based routing
- Tier 3: UserPromptSubmit nudge hook in settings.json → fallback prompt injection

Verification:
- Skill has YAML frontmatter w/ name + description
- Description starts w/ "Use when..."
- Listed in `.claude/rules/skill-routing.md`
- UserPromptSubmit nudge hook references skill
- Anti-hallucination section present

---

## new-agent

Files (in order):
1. `.claude/agents/{name}.md` — create agent w/ YAML frontmatter
2. `.claude/agents/agent-index.yaml` — register agent in index
3. `.claude/settings.json` — UserPromptSubmit routing hook (agents list)

Optional:
4. `.claude/agents/references/{name}-*.md` — reference docs for large agents
5. `.claude/skills/{dispatching-skill}/SKILL.md` — update skill that dispatches this agent

Verification:
- YAML frontmatter: name, description, tools, model, effort, maxTurns
- Agent registered in agent-index.yaml
- Tools list minimal (only what's needed)
- Model matches purpose (haiku=lookups, sonnet=generation, opus=complex)
- Anti-hallucination section present

---

## new-technique

Files (in order):
1. `techniques/{name}.md` — create technique doc
2. Modules that reference it — verify path references

Verification:
- Has blockquote summary
- Has `---` separators between sections
- Templates use `{curly_brace}` placeholders

---

## new-hook

Files (in order):
1. `.claude/hooks/{name}.sh` — create hook script
2. `.claude/settings.json` — register hook under appropriate lifecycle event
3. `.claude/rules/shell-standards.md` — verify hook follows conventions

Verification:
- Starts w/ `#!/usr/bin/env bash`
- Has `set -euo pipefail`
- Reads JSON from stdin via `cat` (not env vars)
- Uses `.claude/scripts/json-val.sh` for JSON extraction
- settings.json uses nested `{ "hooks": [...] }` format

---

## edit-module

Files that may change:
1. `modules/NN-*.md` — the module being edited (range 01-09)
2. `claude-bootstrap.md` — if module title or scope changed
3. Other modules — if cross-references changed
4. Skills/agents created by the module — if template changed

Verification:
- Cross-references still valid after edit
- Checkpoint format preserved
- Idempotency section preserved

---

## promote-learning

Files that change:
1. `.claude/rules/{topic}.md` — add new rule (or create new rule file)
2. `.learnings/log.md` — mark entry as promoted
3. `CLAUDE.md` — update if rule affects conventions or gotchas
4. `.learnings/instincts/{id}.md` — create or update instinct file

Verification:
- Rule doesn't contradict existing rules
- Learning entry marked w/ promotion destination
- CLAUDE.md still under 120 lines

---

## split-plan

Files (in order):
1. `.claude/specs/{branch}/{date}-{topic}-plan.md` — master plan (index + execution order)
2. `.claude/specs/{branch}/{date}-{topic}-plan/task-NN-{name}.md` — per-task files
3. `.claude/specs/{branch}/{date}-{topic}-plan/batch-{name}.md` — per-batch files (parallel tasks)

Verification:
- Master plan exists w/ execution order
- Each task file self-contained w/ steps, verification, anti-hallucination
- Task files match entries in master plan

---

## evolve-agent-audit

Files (in order):
1. `.claude/agents/{name}.md` — agent under audit
2. `.claude/skills/code-write/references/{lang}-{framework}-*.md` — reference files reviewed
3. `.claude/agents/agent-index.yaml` — verify agent metadata current

Pattern:
- Agents born right-sized → no splitting needed
- Audit reviews: scope alignment, tool minimality, anti-hallucination coverage
- Output: findings + recommended edits (no automatic restructuring)

Verification:
- Agent scope matches actual usage patterns
- Tools list minimal; no unused tools
- Anti-hallucination patterns present + current
- Reference files accurate + non-stale

---

## bootstrap-dispatch

Files:
1. `modules/01-discovery.md` — BOOTSTRAP_DISPATCH_PROMPT sections define inline prompts
2. `modules/02-09-*.md` — modules reference inline prompts for Agent() dispatch

Pattern:
Agent(description: "...", prompt: "{BOOTSTRAP_DISPATCH_PROMPT} + task instructions")
Agent writes to target path → returns path + 1-line summary

Verification:
- Dispatch prompt includes full context (no assumed state)
- Agent returns path + summary (not raw content)
- Target path exists after dispatch completes
