# Markdown Content Analysis — claude-bootstrap

> Local codebase analysis of markdown content types in this meta-bootstrap repo.
> Source of truth for proj-code-writer-markdown + proj-test-writer-markdown agents.
> Last analyzed: 2026-04-10.

---

## Project Shape

```yaml
project: claude-bootstrap
type: documentation / prompt-engineering
primary_language: markdown (~6400 lines across modules + techniques)
secondary_language: bash (hooks, scripts)
frameworks: none (markdown + YAML frontmatter only)
build_system: none (no compile step)
test_system: none (validation via bash structure checks)
package_manifest: none
```

Layer map:
- `modules/` → sequential bootstrap instructions (01-09), source of truth for client projects
- `techniques/` → reference knowledge, never executed as steps
- `.claude/rules/` → contextual rule loads (file-type triggered)
- `.claude/skills/` → slash-command procedures (orchestrators + forkables)
- `.claude/agents/` → subagent definitions
- `.claude/hooks/` → bash lifecycle scripts
- `.learnings/` → correction log + instincts + patterns
- `migrations/` → client-project update scripts
- `claude-bootstrap.md` → root orchestrator + master checklist

---

## Component Types

### 1. Module

```yaml
type: module
path: modules/NN-kebab-case.md
naming: zero-padded two-digit sequential (01-09 current range)
frontmatter: none (plain markdown)
required_sections:
  - "# Module NN — Title" (H1 w/ em-dash)
  - "> blockquote summary" (1-3 lines)
  - "## Idempotency" (how re-runs behave)
  - "## Actions" (main instruction body)
  - "## Checkpoint" (`✅ Module N complete — {summary}`)
optional_sections:
  - "## What This Produces" (output table)
  - "## Pipeline Overview" (phase table)
  - "## Integration" (produces/consumes from other modules)
  - "## Verification Checklist"
length_target: 100-900 lines
cross_refs:
  - claude-bootstrap.md master checklist (MUST stay in sync)
  - other modules by number + title
  - techniques/*.md for RCCF + patterns
compression: telegraphic — imperative voice, symbols → | + ~ w/, bullets over prose
code_fidelity: bash blocks + YAML blocks full fidelity (no compression)
```

### 2. Technique

```yaml
type: technique
path: techniques/{name}.md           # bootstrap repo layout
client_path: .claude/references/techniques/{name}.md  # client project layout — different!
naming: kebab-case.md
frontmatter:
  type: research-knowledge
  status: curated-starting-point
  warning: ">" block
  see-also: list
required_sections:
  - "# Title Techniques Reference" H1
  - "> blockquote cross-references"
  - "---" separators between major sections
  - "## Sources" at bottom (for research docs)
template_placeholders: "{curly_braces}" — always documented
length_target: 100-600 lines
execution: NEVER — reference-only, templates w/ placeholders
cross_refs: other techniques via see-also block; modules that reference them
compression: prose+tables mix — research-knowledge can include narrative context
```

### 3. Skill

```yaml
type: skill
path: .claude/skills/{name}/SKILL.md
directory: one folder per skill; references/ subdirectory for progressive disclosure
naming: kebab-case directory name matches skill name
frontmatter:
  name: kebab-case (required)
  description: "Use when..." (required, third-person, <1024 chars, drives native routing)
  allowed-tools: SPACE-separated (`allowed-tools: Read Write Grep`)  # CRITICAL: differs from agent tools:
  model: opus | sonnet | haiku (optional, inherit)
  effort: low | medium | high (match task weight)
  context: fork (forkable skills only)
  agent: proj-<specialist> (forkable skills only)
  paths: glob for auto-activation (optional)
  argument-hint: CLI discovery hint (optional)
  user-invocable: true (triggers only on exact /slash-command)
required_sections:
  - "# /skill-name" H1 title
  - Pre-flight gate (main-thread orchestrators — verify dispatched agents exist)
  - Dispatch Map (agents this skill dispatches, at top of body)
  - AGENT_DISPATCH_POLICY_BLOCK (dispatching skills)
  - Numbered procedural steps
  - Anti-hallucination section
length_target: under 500 lines body; split to references/ if longer
classification:
  - main-thread: interactive + multi-dispatch — NO context:fork, NO agent:
  - forkable: single bounded autonomous task — context:fork + agent:
dispatch_form: literal `subagent_type="proj-<name>"` — never prose
compression: telegraphic; numbered steps; few-shot examples full fidelity
```

### 4. Agent

```yaml
type: agent
path: .claude/agents/{name}.md
naming: proj-{role}[-{lang}][-{fw}].md  # proj- prefix mandatory (defense vs built-in Explore capture)
frontmatter:
  name: matches filename w/o .md (required)
  description: ">" block, pushy trigger words (required)
  tools: COMMA-separated (`tools: Read, Write, Edit`)  # CRITICAL: differs from skill allowed-tools:
  model: opus | sonnet | haiku (required)
  effort: xhigh (mandatory per project convention — medium worse)
  maxTurns: 25-150 per role table (agent-design.md)
  color: CLI output color
  memory: project (stateful agents only)
  skills: preloaded skill list (optional)
  scope: "comma-separated concern list" (sub-specialists + routing-aware agents)
  parent: "parent-agent-name" (sub-specialists only; prevents re-splitting)
tools_whitelist:
  read_only_agents: OMIT tools: entirely — inherit parent + MCP (reviewer, researcher, verifier, quick-check, consistency-checker, reflector)
  markdown_writer: "Read, Write, Edit, Grep, Glob" (NO Bash — markdown writer never needs shell)
  bash_writer: "Read, Write, Edit, Bash, Grep, Glob"
  plan_writer: "Read, Write, Grep, Glob" (NO Edit, NO Bash — discipline per migration 004)
  heredoc_writer: "Read, Grep, Glob, Bash" (debugger, tdd-runner — heredoc via Bash for pass-by-ref)
  mcp_injection: add `mcp__<server>__*` per .mcp.json top-level keys
required_sections:
  - "## Role" (RCCF R)
  - "## Pass-by-Reference Contract" (write to target path; return path + 1-line summary)
  - "## Before Writing" (read-before-write mandate)
  - "## Anti-Hallucination" (DO NOT / NEVER rules)
  - "## Scope Lock"
  - "<use_parallel_tool_calls>" XML block for tool batching
length_target: 100-300 lines ideal; split to .claude/agents/references/ if 500+
cross_refs:
  - techniques/agent-design.md → constraints, MCP propagation, maxTurns table
  - techniques/prompt-engineering.md → RCCF framework
  - techniques/anti-hallucination.md → verification patterns
  - .claude/rules/*.md → domain rules
compression: heavy telegraphic; code + YAML full fidelity
```

### 5. Rule

```yaml
type: rule
path: .claude/rules/{name}.md
naming: kebab-case.md, topic-specific
frontmatter: none
required_sections: "# Title" H1 + bullet lists
length_target: under 40 lines
loading: contextual — by file type or manual @import in CLAUDE.md
cross_refs: rarely; rules are terminal leaves
compression: maximum telegraphic — imperative, no prose
examples: code-standards-markdown.md, shell-standards.md, general.md, skill-routing.md, token-efficiency.md
```

### 6. CLAUDE.md

```yaml
type: project_instructions
path: CLAUDE.md
frontmatter: none
required_sections:
  - "# Project Name"
  - "## Architecture" (stack, structure, languages, git strategy)
  - "## Key Files"
  - "## Conventions"
  - "## Gotchas"
  - "## Compact Instructions"
length_target: under 120 lines — use @import for details
compression: telegraphic; @import for deep content
cross_refs: @import .claude/rules/*.md for rule imports
companion: "CLAUDE.md + CLAUDE.local.md gitignored; synced via companion repo"
```

### 7. Learning Log

```yaml
type: learning_log
path: .learnings/log.md
frontmatter: none
format_per_entry: "### {YYYY-MM-DD} — {category}: {summary}"
categories: correction | failure | gotcha | agent-candidate | environment
length_per_entry: 1-15 lines telegraphic
rotation: managed by /consolidate (5+ sessions + 24h) and /reflect (3+ new entries)
cross_refs: referenced by proj-reflector + /consolidate skills
```

---

## Cross-Reference Patterns

- `@import .claude/rules/{name}.md` — CLAUDE.md imports rules contextually
- `modules/NN-name.md` — exact path from project root
- `techniques/name.md` — bootstrap repo uses root path; client projects use `.claude/references/techniques/{name}.md`
- `.claude/agents/proj-name.md` — proj- prefix always
- Master checklist sync: every module MUST appear in `claude-bootstrap.md` checklist w/ matching number + title

Pipeline sync (what changes together):
- new-module → modules/NN + claude-bootstrap.md checklist + settings.json (if new skills)
- new-skill → .claude/skills/{name}/SKILL.md + .claude/rules/skill-routing.md + settings.json UserPromptSubmit nudge + CLAUDE.md automation section
- new-agent → .claude/agents/{name}.md + .claude/agents/agent-index.yaml + settings.json routing
- new-technique → techniques/{name}.md + modules referencing it (verify paths)
- new-hook → .claude/hooks/{name}.sh + .claude/settings.json hooks block
- promote-learning → .claude/rules/{topic}.md + .learnings/log.md mark + CLAUDE.md (if convention-affecting)

---

## RCCF Structure Application

Per content type:

- **Module** — R:reader role implicit (orchestrator); C:project state via Discovery; C:rules 1-12 per module; F:checkpoint string
- **Technique** — R:expert area framing; C:research warning + see-also; C:none (reference); F:templates w/ `{placeholders}`
- **Skill** — R:implicit (user); C:pipeline context; C:dispatch policy + anti-hallucination; F:numbered steps + checkpoints
- **Agent** — R:explicit `## Role` section; C:read-before-write mandates; C:anti-hallucination + scope-lock; F:pass-by-reference output contract
- **Rule** — R:implicit; C:topic scope via filename; C:bulleted constraints; F:N/A (no output)

---

## Telegraphic Compression Patterns Per Type

- Module: imperative voice ("Create X" not "You should create X"), bash blocks full fidelity, phase tables over prose
- Technique: section-separated; prose OK for rationale; code examples full fidelity
- Skill: numbered steps; telegraphic procedures; few-shot examples full fidelity
- Agent: heaviest compression — key:value, bullets, symbols → | + ~ w/; code examples full fidelity
- Rule: maximum compression — one bullet per rule; merge related w/ `;`
- CLAUDE.md: telegraphic + @import for depth
- Learning log: 1-5 line bullets per entry; pattern/recurrence/fix structure

---

## Build/Lint/Test

- Build: **N/A** — no compile step (markdown + bash only)
- Lint: **N/A** — no markdown linter configured
- Test: **N/A** — no test framework; validation via bash structure checks in `.claude/tests/` (if created by Module 07 test-writer)
- Verification primitives: `head -1` + `grep -q` for YAML fence/sections; `grep -c` for counts; `python3 -m json.tool` for JSON; `bash -n` for shell syntax
- Authoritative checks: module numbering sequential, cross-refs exist, YAML frontmatter valid, no orphan techniques at client-project root, checklist in claude-bootstrap.md in sync

---

## Pipeline Traces — Summary

See `.claude/skills/code-write/references/pipeline-traces.md` for full traces. Key patterns:
- edit-module: source module → master checklist → dependent modules → affected skills/agents generated by module
- edit-technique: technique file → migration to sync to client projects (`.claude/references/techniques/` NEVER `techniques/`)
- edit-skill: SKILL.md → routing rule → settings.json nudge → CLAUDE.md automation list
- edit-agent: agent.md → agent-index.yaml → dispatching skills that reference it
- edit-rule: rule file → CLAUDE.md @import chain → skills/agents that consume the rule

---

## Project-Specific Gotchas

- `allowed-tools` (skills) SPACE-separated; `tools` (agents) COMMA-separated — spec inconsistent, do not unify
- `context: fork` subagents CANNOT use AskUserQuestion — interactive skills MUST run main-thread
- Techniques path differs bootstrap repo (root `techniques/`) vs client projects (`.claude/references/techniques/`) — migration sync steps MUST target client layout
- Bootstrap repo `.claude/` is gitignored — edit `modules/` as source of truth, not `.claude/` directly
- Windows MINGW64 bash: Unix syntax throughout, watch path separator edge cases
- Hook JSON arrives on **stdin** via `cat` — never env vars
- Settings hooks use nested `{ hooks: [...] }` format, not flat arrays
- `user-invocable: true` triggers only on exact `/slash-command` — not natural language
- CLAUDE.md under 120 lines hard cap — use @import for detail

---

## References

- `modules/01-discovery.md` → project detection, foundation agents
- `modules/06-skills.md` → skill authoring requirements, frontmatter spec
- `modules/07-code-specialists.md` → this module (code specialist pipeline)
- `techniques/prompt-engineering.md` → RCCF framework
- `techniques/agent-design.md` → subagent constraints, MCP propagation, role table
- `techniques/anti-hallucination.md` → verification patterns
- `techniques/token-efficiency.md` → compression rules
- `.claude/rules/code-standards-markdown.md` → markdown conventions
- `.claude/agents/proj-code-writer-markdown.md` → canonical markdown writer agent
