---
name: module-write
description: >
  Use when editing bootstrap modules, techniques, or agents in the bootstrap
  repo itself. Dispatches proj-code-writer-markdown for content creation.
  Bootstrap repo only — not for client projects.
argument-hint: "[module-or-file-path]"
allowed-tools: Agent Read Write
model: opus
effort: xhigh
paths: "modules/**,techniques/**,.claude/skills/**,.claude/agents/**"
# Skill Class: main-thread — dispatches proj-code-writer-markdown, verifies cross-refs
---

## /module-write — Bootstrap Content Editing

## Pre-flight (REQUIRED — before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

## Dispatch Map
- Content generation: `proj-code-writer-markdown`

**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: dispatch `proj-quick-check` (simple) | `proj-researcher` (deep). Read directly ONLY for known exact path (Tier 1 per main-thread-orchestrator.md). MCP-indexed projects: named-symbol lookups MUST go through cmm.search_graph (see mcp-routing.md). Never built-in `Explore` / `general-purpose` / plugin.
See `techniques/agent-design.md § Agent Dispatch Policy`.

### Input
Target file path + change description.

### Steps
1. Read target file (if exists)
2. Read 2-3 similar files for pattern consistency
3. Read `claude-bootstrap.md` — verify module numbering, checklist
4. Dispatch agent via `subagent_type="proj-code-writer-markdown"` w/:
   - Target file path
   - Change description
   - Context: similar files read, conventions detected
   - Write output to target path
   - Return path + summary
5. Verify cross-references in written file exist
6. Check `claude-bootstrap.md` checklist stays in sync

### Content Type Classification
| Request | Type |
|---------|------|
| New/edit module | Module — Actions, idempotency, checkpoint |
| New technique doc | Reference material, not executable steps |
| New skill | YAML frontmatter + procedural steps |
| New agent | YAML frontmatter w/ tools/model/effort + role sections |

### Anti-Hallucination
- Never invent module numbers
- Verify all cross-refs exist
- Read before write — always
- Every cross-reference must be bidirectional — A references B → B discoverable from A
