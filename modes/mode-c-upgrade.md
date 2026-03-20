# Mode C — Incremental Enhancement of Existing .claude/ Setup

Select this mode when the project already has a .claude/ directory from a
previous bootstrap run or manual setup. This is the upgrade path.

## Core Principle

**Additive only.** Never remove or overwrite project-specific content.
When a conflict exists between the bootstrap template and an existing file,
PRESERVE the existing file and note the difference in the verification report.

## Decision Logic Per Step

### Step 1 — Discovery
Read ALL existing files: .claude/ directory contents, CLAUDE.md,
CLAUDE.local.md, .learnings/. Build a complete inventory. Compare each
file against the current bootstrap spec to identify gaps and additions.

### Step 2 — CLAUDE.md
Read existing CLAUDE.md. Only ADD missing sections. Specifically check for:
Environment section, Compact Instructions section, Self-Improvement section
with triple triggers. Never overwrite Architecture, Key Files, Commands,
Conventions, or Gotchas — these contain project-specific knowledge.

### Step 3 — Rules
Read existing rules in .claude/rules/. Only create files that are missing.
For code-standards.md, check if a Style section exists — add it if missing
but do not alter existing style rules.

### Step 4 — Hooks
Read existing settings.json. Check for each required hook event:
SessionStart, PreToolUse, SubagentStop. Only add missing hooks. If existing
hooks use inline commands, propose extracting them to scripts but do not
force the change.

### Step 5 — Skills
Read existing skills in .claude/skills/. Check specifically for the plugin
audit skill (step 6 in /reflect) — this was added in v3 and may be missing
from older setups. Add only missing skill sections.

### Step 6 — CLAUDE.local.md
If CLAUDE.local.md already exists, skip entirely. This file contains
personal preferences that must not be touched by an upgrade.

### Step 7 — Agents
Read existing agents in .claude/agents/. Only create agents that are
missing from the current spec. Before creating any agent, run a plugin
collision pre-flight: check if an installed plugin already provides
equivalent agent functionality.

### Step 8 — Learnings
If .learnings/ directory exists, preserve it completely. Only create the
directory and initial structure if it is missing.

### Step 9 — Plugins
Check for new plugin recommendations that were not available during the
previous bootstrap. Do not reinstall or reconfigure existing plugins.

### Step 10 — Verification
Full verification. Report results in three categories:
- **ADDED**: New files and sections created during this upgrade
- **UPDATED**: Existing files that received new sections
- **PRESERVED**: Existing files left untouched (with notes on any
  differences from the current template)
