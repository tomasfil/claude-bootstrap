# Module 14 — Wiring Verification

> Run comprehensive verification checklist. Every item must pass.
> Fix failures before reporting completion.

---

## Verification Checklist

Run through EVERY check below. Print pass/fail for each.

### File Existence

```bash
# Core files
[ -f "CLAUDE.md" ] && echo "✅ CLAUDE.md" || echo "❌ CLAUDE.md MISSING"
[ -f "CLAUDE.local.md" ] && echo "✅ CLAUDE.local.md" || echo "❌ CLAUDE.local.md MISSING"
[ -f ".claude/settings.json" ] && echo "✅ settings.json" || echo "❌ settings.json MISSING"

# Scripts
[ -f ".claude/scripts/json-val.sh" ] && echo "✅ json-val.sh" || echo "❌ json-val.sh MISSING"
[ -f ".claude/hooks/detect-env.sh" ] && echo "✅ detect-env.sh" || echo "❌ detect-env.sh MISSING"
[ -f ".claude/hooks/guard-git.sh" ] && echo "✅ guard-git.sh" || echo "❌ guard-git.sh MISSING"
[ -f ".claude/hooks/track-agent.sh" ] && echo "✅ track-agent.sh" || echo "❌ track-agent.sh MISSING"

# Rules
ls .claude/rules/*.md 2>/dev/null && echo "✅ Rules exist" || echo "❌ No rule files"

# Skills
for skill in reflect audit-file audit-memory write-prompt brainstorm write-plan execute-plan tdd debug verify commit pr review; do
  [ -f ".claude/skills/$skill/SKILL.md" ] && echo "✅ /skill $skill" || echo "❌ /$skill MISSING"
done

# Agents
ls .claude/agents/*.md 2>/dev/null && echo "✅ Agents exist" || echo "❌ No agent files"

# Learnings
[ -f ".learnings/log.md" ] && echo "✅ learnings/log.md" || echo "❌ learnings/log.md MISSING"
[ -f ".learnings/agent-usage.log" ] && echo "✅ learnings/agent-usage.log" || echo "❌ agent-usage.log MISSING"
```

### YAML Frontmatter Validation

For every skill and agent file, verify YAML frontmatter exists:

```bash
for f in .claude/skills/*/SKILL.md .claude/agents/*.md; do
  if [ -f "$f" ]; then
    head -1 "$f" | grep -q "^---" && echo "✅ Frontmatter: $f" || echo "❌ Missing frontmatter: $f"
  fi
done
```

### CLAUDE.md Wiring

Read CLAUDE.md and verify these concepts are present:

- [ ] `.learnings/log.md` mentioned by name in Self-Improvement
- [ ] "BEFORE continuing" (or equivalent) for user correction trigger
- [ ] "search the web" for command failure trigger
- [ ] Compact Instructions section exists
- [ ] Proactive compaction at ~70% mentioned
- [ ] `@import` or `@` reference used for at least one detailed doc
- [ ] Total line count < 120: `wc -l CLAUDE.md`

### Hook Wiring

Read `.claude/settings.json` and verify deterministic hooks:

- [ ] SessionStart hook references `detect-env.sh`
- [ ] PreToolUse hook references `guard-git.sh` with matcher "Bash"
- [ ] SubagentStop hook references `track-agent.sh`

### Generate Skill Routing Hook (CRITICAL — do this now)

The UserPromptSubmit skill routing hook was intentionally NOT created in Module 04 because
it depends on what was actually created in Modules 05-18. Generate it NOW by scanning
what exists:

**Step 1: Discover all created skills**
```bash
# List all skills that actually exist
ls -d .claude/skills/*/SKILL.md 2>/dev/null | sed 's|.claude/skills/||;s|/SKILL.md||' | sort
```

**Step 2: Discover all created agents**
```bash
# List all agents that actually exist
ls .claude/agents/*.md 2>/dev/null | sed 's|.claude/agents/||;s|\.md||' | sort
```

**Step 3: Read each skill's description to build trigger words**
For each skill found, read its YAML frontmatter `description` field to extract what triggers it.

**Step 4: Generate and inject the routing hook**

Add the `UserPromptSubmit` hook to `.claude/settings.json` using this template.
Replace `{SKILLS_LIST}` and `{AGENTS_LIST}` with what was actually discovered:

⚠️ **CRITICAL: This MUST be `"type": "prompt"`, NOT `"type": "command"`.
A prompt hook PREPENDS text to the user's message — it NEVER blocks.
A command hook RUNS A SCRIPT that can BLOCK messages (exit code 2).
Using "command" type here will block normal conversations. NEVER do that.**

⚠️ **Also check for OTHER UserPromptSubmit hooks** (e.g., from the superpowers plugin).
If another hook exists with `"type": "command"` that evaluates skill applicability,
it WILL block normal messages. Remove or disable it:
```bash
# Check for conflicting hooks
cat .claude/settings.json | grep -A5 "UserPromptSubmit"
# Also check plugin hooks
find ~/.claude/plugins/cache/ -name "*.json" -exec grep -l "UserPromptSubmit" {} \; 2>/dev/null
```

```json
"UserPromptSubmit": [
  {
    "type": "prompt",
    "matcher": "",
    "prompt": "SKILL ROUTING: Before responding, check if any skill below applies to this message. If one applies, invoke it via the Skill tool BEFORE any other action.\n\nSkills and triggers:\n{SKILLS_LIST}\n\nAgents available for dispatch:\n{AGENTS_LIST}\n\nIf NO skill applies (git status, simple questions, file reads), respond normally.\nIf UNSURE, invoke the skill — false positives are cheap, false negatives waste time."
  }
]
```

**Format for {SKILLS_LIST}** — one line per skill, extracted from its description:
```
- /code-write → implement, create, build, add, write code/feature/component/endpoint/service/entity
- /reflect → review learnings, improve setup, audit config, evolve agents
- /brainstorm → design a feature, explore an idea, think through architecture
- /tdd → write tests first then implementation (red-green-refactor)
- /debug → investigate a bug, test failure, or unexpected behavior
- /verify → verify work is complete before claiming done, run build+tests+checks
- /review → review code for quality/security/standards
- /commit → commit changes with project conventions
- /pr → create pull request with project template
- /sync → save config, backup, export/import claude setup
- /audit-file → review/audit a specific source file against code standards
- /audit-memory → check project memory health
- /write-prompt → create new skills, agents, or LLM instruction files
- /write-plan → create implementation plan from a design or spec
- /execute-plan → execute a written plan with review checkpoints
```
(The above is an EXAMPLE. Use the ACTUAL skills discovered in Step 1. Each skill's
trigger words come from its YAML `description` field.)

**Format for {AGENTS_LIST}** — one line per agent:
```
- quick-check: fast lookups (haiku) — file search, existence checks, simple questions
- researcher: deep exploration (sonnet) — trace execution paths, analyze dependencies
- project-code-reviewer: deep review (sonnet) — pipeline completeness, security, architecture
- code-writer-{lang}: code writing (sonnet) — dispatched by /code-write orchestrator
- test-writer: test writing (sonnet) — dispatched when writing tests
```
(The above is an EXAMPLE. Use the ACTUAL agents discovered in Step 2. Each agent's
description comes from its YAML `description` field.)

**Step 5: Verify the hook was injected correctly**
```bash
# Confirm UserPromptSubmit exists in settings.json
grep -q "UserPromptSubmit" .claude/settings.json && echo "✅ Skill routing hook injected" || echo "❌ Skill routing hook MISSING"
```

- [ ] UserPromptSubmit hook exists with dynamically generated skill/agent list
- [ ] Every skill found in Step 1 is listed in the routing prompt
- [ ] Every agent found in Step 2 is listed in the routing prompt

### Anti-Hallucination Coverage

For every agent that writes code, verify these sections exist:

```bash
for f in .claude/agents/*.md; do
  echo "=== $f ==="
  grep -l "Read-Before-Write\|read.*before.*writ\|BEFORE writing" "$f" >/dev/null 2>&1 && echo "✅ Read-before-write" || echo "❌ Missing read-before-write"
  grep -l "DO NOT\|NEVER.*invent\|NEVER.*fabricat" "$f" >/dev/null 2>&1 && echo "✅ Negative instructions" || echo "❌ Missing negative instructions"
  grep -l "build\|Build\|dotnet build\|npm run build" "$f" >/dev/null 2>&1 && echo "✅ Build verification" || echo "❌ Missing build verification"
done
```

### Plugin Collision Check

```bash
# Check agent names against installed plugin agents
PLUGIN_AGENTS=$(find ~/.claude/plugins/cache/ -name "*.md" -path "*/agents/*" 2>/dev/null | xargs head -5 2>/dev/null | grep "name:" | awk '{print $2}' | sort -u)
PROJECT_AGENTS=$(head -5 .claude/agents/*.md 2>/dev/null | grep "name:" | awk '{print $2}' | sort -u)

for agent in $PROJECT_AGENTS; do
  echo "$PLUGIN_AGENTS" | grep -q "^$agent$" && echo "⚠️ COLLISION: $agent exists in both project and plugin" || true
done
```

### Command Verification

```bash
# Verify build command works
{build_command} 2>&1 | tail -3
echo "Build exit code: $?"

# Verify lint command works (if applicable)
{lint_command} 2>&1 | tail -3
echo "Lint exit code: $?"
```

### Gitignore Verification

```bash
if [ "{git_strategy}" = "track" ]; then
  # Personal project: only machine-specific files ignored
  grep -q "CLAUDE.local.md" .gitignore && echo "✅ CLAUDE.local.md ignored" || echo "❌ CLAUDE.local.md not ignored"
  grep -q ".claude/settings.local.json" .gitignore && echo "✅ settings.local.json ignored" || echo "❌ settings.local.json not ignored"
  grep -q "^\.claude/$" .gitignore && echo "⚠️ .claude/ is ignored but git_strategy is 'track'" || echo "✅ .claude/ is tracked"
elif [ "{git_strategy}" = "companion" ] || [ "{git_strategy}" = "ephemeral" ]; then
  # Work project: all claude files ignored
  grep -q "CLAUDE.md" .gitignore && echo "✅ CLAUDE.md ignored" || echo "❌ CLAUDE.md not ignored"
  grep -q "\.claude" .gitignore && echo "✅ .claude ignored" || echo "❌ .claude not ignored"
  grep -q "\.learnings" .gitignore && echo "✅ .learnings ignored" || echo "❌ .learnings not ignored"
fi
```

### Companion Repo Checks (only if git_strategy == "companion")

```bash
PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
COMPANION="$HOME/.claude-configs/$PROJECT_NAME"

[ -d "$COMPANION" ] && echo "✅ Companion dir exists" || echo "❌ Companion dir missing"
[ -d "$COMPANION/.claude" ] && echo "✅ Companion has .claude/" || echo "❌ Companion missing .claude/"
[ -f ".claude/skills/sync/SKILL.md" ] && echo "✅ /sync skill exists" || echo "❌ /sync skill missing"
[ -f ".claude/scripts/sync-config.sh" ] && echo "✅ sync script exists" || echo "❌ sync script missing"

# Check user-level hook
grep -q "claude-configs" ~/.claude/settings.json 2>/dev/null && echo "✅ User-level auto-import hook" || echo "⚠️ User-level auto-import hook not found (optional)"
```

## Final Report

```
✅ Module 14 complete — Wiring Verification

Files: {created} created, {updated} updated, {preserved} preserved
Skills: {N} skills ({list})
Agents: {N} agents ({list})
Hooks: {N} hooks (SessionStart, PreToolUse, SubagentStop, UserPromptSubmit{, PostToolUse})
Rules: {N} rule files
Plugins: {N} kept (connectors), {N} replaced (methodology)
Anti-hallucination: {coverage}% of code-writing agents covered
Companion repo: {configured / not applicable}
Git strategy: {track / companion / ephemeral}

{Any warnings or failed checks listed here}

🎉 Bootstrap complete. Run /reflect periodically to evolve the setup.

Continuing to Module 15 (companion sync), then Module 16 (code writer), Module 17 (test writer).
```
