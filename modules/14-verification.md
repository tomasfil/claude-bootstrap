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

### Generate/Regenerate Skill Routing Hook (MANDATORY — always regenerate, never skip)

The UserPromptSubmit routing hook MUST be regenerated every time Module 14 runs.
It is built by scanning what actually exists on disk — not from a static list.
This ensures new agents/skills added during Modules 16-18 (or by /reflect) are
always included. **Never build the hook early and assume it stays current.**

⚠️ **This hook is NOT redundant with Claude Code's native skill detection.**
Native `user-invocable: true` only triggers when users type the exact `/slash-command`.
The routing hook catches **natural language** ("add a field to X", "debug this test failure")
and nudges toward the matching skill. Without it, users must remember exact slash command
names, and Claude will often do the work directly instead of dispatching to the specialist.

⚠️ **MUST use `"type": "command"` with `echo`, NOT `"type": "prompt"`.**
Prompt-type hooks are evaluated by a small fast model that misinterprets routing
instructions and BLOCKS normal messages. Command-type echo hooks simply prepend
text to the conversation — they never block (exit 0).

**Step 1: Discover ALL skills and agents on disk**
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
  model=$(head -10 "$f" 2>/dev/null | grep "model:" | head -1 | sed 's/.*model: *//')
  desc=$(head -10 "$f" 2>/dev/null | grep "description:" | head -1 | sed 's/.*description: *//')
  echo "- $name ($model): $desc"
done
```

**Step 2: Detect drift — compare disk vs hook**

If a UserPromptSubmit hook already exists, check if it lists every skill and agent
found in Step 1. If ANY are missing, the hook is stale and MUST be regenerated.

```bash
SKILLS_ON_DISK=$(ls -d .claude/skills/*/SKILL.md 2>/dev/null | sed 's|.claude/skills/||;s|/SKILL.md||' | sort)
AGENTS_ON_DISK=$(head -5 .claude/agents/*.md 2>/dev/null | grep "name:" | awk '{print $2}' | sort -u)

MISSING=0
for skill in $SKILLS_ON_DISK; do
  grep -q "/$skill" .claude/settings.json 2>/dev/null || { echo "⚠️ DRIFT: /$skill missing from routing hook"; MISSING=$((MISSING+1)); }
done
for agent in $AGENTS_ON_DISK; do
  grep -q "$agent" .claude/settings.json 2>/dev/null || { echo "⚠️ DRIFT: agent $agent missing from routing hook"; MISSING=$((MISSING+1)); }
done

[ "$MISSING" -eq 0 ] && echo "✅ Routing hook is current" || echo "❌ Routing hook is STALE — regenerating"
```

**Step 3: Build and inject the routing hook**

Using the discovered skills and agents from Step 1, build a single echo command.
If the hook already exists, REPLACE it entirely (don't patch — regenerate from scratch).

Format for skills: `- /skill-name → trigger words from description`
Format for agents: `- agent-name (model): brief description`

Include a capabilities note after the agents list to guide Claude on specialized features:
```
\n\nCapabilities:\n- Token optimization: /write-prompt covers compressed notation for Claude-facing files; token-optimizer agent (if exists) audits for waste\n- Format selection: YAML for hierarchical data, TSV/TOON for flat arrays, JSON only when tooling requires — see techniques/prompt-engineering.md\n- TDD migration: use /tdd for gradual JSON→YAML format migration in code-consumed data
```

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

**Step 4: Verify completeness**
```bash
grep -q "UserPromptSubmit" .claude/settings.json && echo "✅ Routing hook exists" || echo "❌ MISSING"
grep -q '"type": "command"' .claude/settings.json && echo "✅ Uses command type" || echo "❌ Wrong hook type"

# Re-run drift check — must pass now
for skill in $SKILLS_ON_DISK; do
  grep -q "/$skill" .claude/settings.json || echo "❌ STILL MISSING: /$skill"
done
for agent in $AGENTS_ON_DISK; do
  grep -q "$agent" .claude/settings.json || echo "❌ STILL MISSING: $agent"
done
```

- [ ] UserPromptSubmit hook exists with `"type": "command"` (NOT "prompt")
- [ ] Hook lists EVERY skill found on disk (zero drift)
- [ ] Hook lists EVERY agent found on disk (zero drift)
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

Files: {created} created, {upgraded} upgraded, {deleted} obsolete removed
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
