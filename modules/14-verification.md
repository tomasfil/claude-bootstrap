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
for skill in reflect audit-file audit-memory write-prompt brainstorm spec write-plan execute-plan tdd debug verify commit pr review module-write check-consistency write-ticket ci-triage consolidate; do
  [ -f ".claude/skills/$skill/SKILL.md" ] && echo "✅ /skill $skill" || echo "❌ /$skill MISSING"
done

# Agents
ls .claude/agents/*.md 2>/dev/null && echo "✅ Agents exist" || echo "❌ No agent files"

# Learnings
[ -f ".learnings/log.md" ] && echo "✅ learnings/log.md" || echo "❌ learnings/log.md MISSING"
[ -f ".learnings/agent-usage.log" ] && echo "✅ learnings/agent-usage.log" || echo "❌ agent-usage.log MISSING"

# Instinct system
[ -d ".learnings/instincts" ] && echo "✅ instincts directory" || echo "❌ .learnings/instincts/ MISSING"

# Observation hook
[ -f ".claude/hooks/observe.sh" ] && echo "✅ observe.sh" || echo "❌ observe.sh MISSING"

# Tracking files (created on first session, warn if missing)
for tf in .learnings/.session-count .learnings/.last-dream .learnings/.last-reflect-lines; do
  [ -f "$tf" ] && echo "✅ $tf" || echo "⚠️ $tf not yet created (will be created on first session)"
done
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

### Generate Skill Routing Hook (MANDATORY — do this now, do not skip)

The UserPromptSubmit hook was NOT created in Module 04 because it depends on what
Modules 05-18 actually created. Generate it NOW by scanning what exists.

⚠️ **This hook is NOT redundant with Claude Code's native skill detection.**
Native `user-invocable: true` only triggers when users type the exact `/slash-command`.
The routing hook catches **natural language** ("add a field to Division", "debug this test failure")
and nudges toward the matching skill. Without it, users must remember exact slash command
names, and Claude will often do the work directly instead of dispatching to the specialist skill.

⚠️ **MUST use `"type": "command"` with `echo`, NOT `"type": "prompt"`.**
Prompt-type hooks are evaluated by a small fast model that misinterprets routing
instructions and BLOCKS normal messages. Command-type hooks with `echo` simply
prepend the output text to the conversation — they never block (exit 0).

**Step 1: Discover all created skills and agents**
```bash
echo "=== SKILLS ==="
for d in .claude/skills/*/SKILL.md; do
  name=$(echo "$d" | sed 's|.claude/skills/||;s|/SKILL.md||')
  desc=$(head -10 "$d" 2>/dev/null | grep "description:" | sed 's/.*description: *//')
  echo "- /$name: $desc"
done

echo "=== AGENTS ==="
for f in .claude/agents/*.md; do
  name=$(head -5 "$f" 2>/dev/null | grep "name:" | head -1 | sed 's/.*name: *//')
  desc=$(head -10 "$f" 2>/dev/null | grep "description:" | head -1 | sed 's/.*description: *//')
  echo "- $name: $desc"
done
```

**Step 2: Build the routing text**

Using the discovered skills and agents, build a single echo command. Format:
```
- /skill-name → trigger words extracted from description (dispatches agent-name if applicable)
```

**Step 3: Inject the hook into `.claude/settings.json`**

Add this to the hooks object. The `echo` command outputs routing text that gets
prepended to the user's message. The main Claude model sees it and routes accordingly.

```json
"UserPromptSubmit": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "echo 'SKILL ROUTING: Check if any skill below applies to this message. If one applies, invoke it via the Skill tool BEFORE doing any work yourself. Skills orchestrate specialized agents — do NOT bypass them by doing the work directly.\n\nSkills:\n{GENERATED_SKILLS_LIST}\n\nAgents (dispatched by skills, not directly):\n{GENERATED_AGENTS_LIST}\n\nIf NO skill matches, respond normally. NEVER refuse or block — just answer directly.'"
      }
    ]
  }
]
```

Replace `{GENERATED_SKILLS_LIST}` with one line per skill discovered in Step 1:
```
- /reflect → review learnings, improve environment, audit config, evolve agents
- /audit-file → review, audit, check a file for quality or conventions
- /audit-memory → check memory health, review learnings, clean up stale entries
- /write-prompt → create new skills, agents, CI prompts, instruction files
- /brainstorm → design, explore, plan, think through a feature or change
- /spec → write structured implementation spec before coding
- /write-plan → create implementation plan from design or requirements
- /execute-plan → execute a written plan with review checkpoints
- /tdd → test-driven development, red-green-refactor cycle
- /debug → investigate bug, test failure, unexpected behavior
- /verify → verify work complete before committing or claiming done
- /commit → commit changes with project conventions
- /pr → create pull request with project template
- /review → request code review on current changes
- /module-write → create or edit bootstrap modules, techniques, skills, agents
- /check-consistency → verify cross-reference integrity across the project
- /write-ticket → write structured ticket with INVEST+C criteria
- /ci-triage → triage CI/CD failures, classify by priority
- /consolidate → consolidate learnings into instincts, clean up learning system
...etc for every skill found
```

Replace `{GENERATED_AGENTS_LIST}` with one line per agent discovered in Step 1:
```
- quick-check (haiku): fast lookups, file searches, existence checks
- researcher (sonnet): deep codebase exploration, pattern analysis, tracing
- module-writer (opus): bootstrap content writing specialist
- project-code-reviewer (opus): deep review of modules, skills, agents for quality
- plan-writer (sonnet): create implementation plans from specs
- debugger (opus): trace and diagnose bugs
- verifier (sonnet): verify build, tests, cross-references
- reflector (opus): analyze learnings, propose improvements
- consistency-checker (sonnet): cross-reference validation
- tdd-runner (opus): test-driven development cycles
...etc for every agent found
```

**Step 4: Verify**
```bash
grep -q "UserPromptSubmit" .claude/settings.json && echo "✅ Routing hook injected" || echo "❌ MISSING"
grep -q '"type": "command"' .claude/settings.json && echo "✅ Uses command type" || echo "❌ Wrong hook type"
```

- [ ] UserPromptSubmit hook exists with `"type": "command"` (NOT "prompt")
- [ ] Echo text lists every skill found in Step 1
- [ ] Echo text lists every agent found in Step 1
- [ ] Hook output includes "NEVER refuse or block"

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
Skills: ~20 skills ({list})
Agents: 10 agents ({list})
Hooks: {N} hooks (SessionStart, PreToolUse, SubagentStop, UserPromptSubmit, PostToolUse, PreCompact)
Rules: {N} rule files
Plugins: {N} kept (connectors), {N} replaced (methodology)
Anti-hallucination: {coverage}% of code-writing agents covered
Companion repo: {configured / not applicable}
Git strategy: {track / companion / ephemeral}

{Any warnings or failed checks listed here}

🎉 Bootstrap complete. Run /reflect periodically to evolve the setup.

Continuing to Module 15 (companion sync), then Module 16 (code writer), Module 17 (test writer).
```
