# Module 08 — Verification & Wiring

> Verify everything works. Generate routing infrastructure. Handle optional setup.
> Mix of agent dispatches + main thread work. Absorbs old modules 09, 12, 14.

---

## Idempotency

Per check: if `.claude/reports/verification.md` + `.claude/reports/consistency.md` exist w/ all PASS → skip agent dispatches, run main thread checks only. If any FAIL → re-dispatch relevant agent.

Per config: `.mcp.json` — read existing, add missing entries, preserve custom. Scoped CLAUDE.md — skip if exists + current.

---

## Actions

### Pre-Flight

```bash
mkdir -p .claude/reports
```

Verify Modules 01-07 complete — check key outputs:
```bash
[[ -f ".claude/agents/code-writer-markdown.md" ]] || echo "MISSING: foundation agents — run Module 01"
[[ -f "CLAUDE.md" ]] || echo "MISSING: CLAUDE.md — run Module 02"
[[ -f ".claude/settings.json" ]] || echo "MISSING: settings.json — run Module 03"
[[ -d ".learnings" ]] || echo "MISSING: learnings — run Module 04"
[[ -f ".claude/agents/verifier.md" ]] || echo "MISSING: verifier agent — run Module 05"
[[ -f ".claude/agents/consistency-checker.md" ]] || echo "MISSING: consistency-checker — run Module 05"
ls .claude/skills/*/SKILL.md >/dev/null 2>&1 || echo "MISSING: skills — run Module 06"
```

If any MISSING → STOP. Complete prerequisite modules first.

---

### 1. Dispatch: verifier (comprehensive wiring check)

Dispatch `verifier` agent (inline BOOTSTRAP_DISPATCH_PROMPT from Module 01):

```
Agent(
  description: "Comprehensive wiring verification",
  prompt: "{BOOTSTRAP_DISPATCH_PROMPT from Module 01, verifier section}

Run comprehensive wiring verification. Check ALL of the following:

FILE EXISTENCE:
- Core: CLAUDE.md, CLAUDE.local.md, .claude/settings.json
- Hook scripts: .claude/hooks/*.sh (detect-env.sh, guard-git.sh, track-agent.sh, stop-verify.sh, log-failures.sh, pre-compact.sh, auto-format.sh)
- Rules: .claude/rules/*.md
- Technique references: .claude/references/techniques/{prompt-engineering,anti-hallucination,agent-design}.md
- Skills: every SKILL.md in .claude/skills/*/
- Agents: every .md in .claude/agents/
- Learnings: .learnings/log.md, .learnings/observations.jsonl, .learnings/patterns.md, .learnings/decisions.md, .learnings/environment.md, .learnings/instincts/
- Agent index: .claude/agents/agent-index.yaml

YAML FRONTMATTER VALIDATION:
- Every skill SKILL.md has: name, description (starts 'Use when')
- Every agent .md has: name, description, tools, model, effort, maxTurns, color

CLAUDE.MD WIRING:
- .learnings/log.md mentioned in Self-Improvement section
- 'BEFORE continuing' (or equivalent) user-correction trigger
- Compact Instructions section exists
- Total lines < 120: wc -l CLAUDE.md
- @import used for at least one detailed doc

HOOK WIRING (in .claude/settings.json):
- SessionStart → detect-env.sh
- PreToolUse → guard-git.sh (matcher: Bash)
- SubagentStop → track-agent.sh
- PostToolUse → log-failures.sh (matcher: Bash)
- UserPromptSubmit → echo nudge exists
- Stop → stop-verify.sh
- PreCompact → pre-compact.sh

BUILD/LINT VERIFICATION:
- Run {build_command} — report exit code
- Run {lint_command} (if applicable) — report exit code

ANTI-HALLUCINATION COVERAGE:
- For every code-writing agent: verify read-before-write mandate, negative instructions (DO NOT/NEVER), build verification step

COMPRESSION COMPLIANCE:
- Scan all agent/skill files for prose indicators: lines starting with 'You are a', 'Your job is', 'This skill', 'The agent', 'Please note', 'In order to'
- Report violations

Write report to .claude/reports/verification.md via Bash heredoc.
Format: PASS/FAIL per check category, details for FAILs.
Return path + 1-line summary.
"
)
```

Read `.claude/reports/verification.md`. If FAIL items → fix each before continuing.

---

### 2. Dispatch: consistency-checker (cross-reference integrity)

Dispatch `consistency-checker` agent:

```
Agent(
  description: "Cross-reference integrity check",
  prompt: "{BOOTSTRAP_DISPATCH_PROMPT from Module 01, consistency-checker section}

Validate cross-reference integrity:

MODULE REFERENCES:
- Every file path referenced in module files exists on disk

SKILL-AGENT DEPENDENCIES:
- /review → project-code-reviewer agent exists
- /code-write → code-writer-{lang} agents exist for each detected language
- /verify → verifier + consistency-checker agents exist
- /tdd → tdd-runner agent exists
- /debug → debugger agent exists
- /reflect → reflector agent exists

AGENT INDEX:
- .claude/agents/agent-index.yaml entries match actual .claude/agents/*.md files
- No orphan entries (agent in index but file missing)
- No unlisted agents (file exists but not in index)

CODE-WRITE SKILL REFERENCES:
- .claude/skills/code-write/references/pipeline-traces.md exists
- .claude/skills/code-write/references/capability-index.md exists

ROUTING COMPLETENESS:
- .claude/rules/skill-routing.md mentions major skill categories (development, quality, git, maintenance)

Write report to .claude/reports/consistency.md via Bash heredoc.
Format: PASS/FAIL per check category, details for FAILs.
Return path + 1-line summary.
"
)
```

Read `.claude/reports/consistency.md`. If FAIL items → fix.

---

### 3. Process Reports

After both dispatches complete:

1. Read `.claude/reports/verification.md`
2. Read `.claude/reports/consistency.md`
3. For each FAIL item: fix directly (main thread for config edits, re-dispatch agent for content generation)
4. List any remaining issues for user attention

---

### 4. Verify Routing Infrastructure

**Tier 2 — skill-routing.md (behavioral guidance):**

Read `.claude/rules/skill-routing.md` (created in Module 02).

Verify:
- Exists
- Is behavioral guidance only (~150 tokens), NOT a routing table
- Contains: "check if a skill applies", "Skills orchestrate agents", when-to-check / when-NOT-to-check

If missing or is a routing table → regenerate:

```markdown
# Skill Routing

## Before Starting Work
- Check if a skill from the Skill tool applies BEFORE starting implementation
- Skills orchestrate specialized agents — bypassing them loses the quality layer

## When to Check
- Implementation requests (new features, bug fixes, refactoring)
- Git operations (commit, PR, review)
- Planning + design tasks
- Debugging + investigation

## When NOT to Check
- Simple questions about the codebase
- Clarification requests
- Conversation continuations where skill already active

## NEVER block a message because no skill matches — respond normally
```

**Tier 3 — UserPromptSubmit nudge (~30 tokens):**

Read `.claude/settings.json`. Verify UserPromptSubmit hook:
- Exists
- Uses `"type": "command"` (NOT `"type": "prompt"`)
- Echo content is ~30 tokens (single sentence)
- NOT a 2,500-token routing table

Expected content:
```json
{
  "type": "command",
  "command": "echo 'SKILL CHECK: Before starting work, evaluate if a skill from the Skill tool applies. Skills orchestrate agents — do not bypass.'"
}
```

If missing, wrong type, or bloated → fix.

**Skill descriptions:**

Verify all skill `description:` fields in `.claude/skills/*/SKILL.md` contain "Use when..." trigger phrases:

```bash
for f in .claude/skills/*/SKILL.md; do
  [[ -f "$f" ]] || continue
  name=$(echo "$f" | sed 's|.claude/skills/||;s|/SKILL.md||')
  if head -10 "$f" | grep -q "Use when"; then
    echo "PASS: /$name"
  else
    echo "FAIL: /$name — description missing 'Use when...' trigger"
  fi
done
```

Fix any FAIL items — update description field to include trigger phrases.

---

### 5. Scoped CLAUDE.md (conditional)

Scan project for directories w/ distinctly different conventions:
- Test directories — different assertion style, fixtures, naming
- Frontend directories — different framework than backend
- Script directories — shell scripts w/ different standards
- Generated/vendor directories — read-only, do not modify

**When to create:** directory has conventions that DIFFER from root CLAUDE.md + rules/.
**When NOT to create:** root coverage adequate, directory small (<10 files), same conventions.

If needed — dispatch `code-writer-markdown` per directory:

```
Agent(
  description: "Create scoped CLAUDE.md for {directory}",
  prompt: "Write {directory}/CLAUDE.md (<30 lines). Include ONLY rules specific to this directory — don't repeat root CLAUDE.md.

Template:
# {Directory} Context

## Purpose
{What this directory contains and why it's different}

## Conventions
{Only rules SPECIFIC to this directory}

## Commands
{Directory-specific commands if different from root}

Write file. Return path + summary.
"
)
```

If not needed → document: "Scoped CLAUDE.md: not needed — root coverage adequate."

---

### 6. MCP/Plugin Setup

**MCP Servers — configure `.mcp.json`:**

Always recommend context7 (library docs lookup — prevents hallucinated API calls).

Detect project signals → recommend additional:

| Signal | MCP Server |
|--------|-----------|
| Firebase SDK in dependencies | `firebase` MCP |
| GitHub remote | `github` MCP |
| PostgreSQL/MySQL connection strings | database-specific MCP |
| Jira/Linear references | `atlassian` or `linear` MCP |
| Slack integration | `slack` MCP |

If `.mcp.json` exists → read, add missing, preserve custom entries.
If missing → create:

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@context7/mcp-server"]
    }
  }
}
```

**Replaced methodology plugins — detect + recommend disabling:**

Check for installed plugins that overlap w/ generated skills:

```bash
REPLACED="superpowers claude-md-management feature-dev code-review commit-commands code-simplifier pr-review-toolkit frontend-design"

for plugin in $REPLACED; do
  if cat ~/.claude/plugins/installed_plugins.json 2>/dev/null | grep -q "\"$plugin"; then
    echo "FOUND: $plugin — replaced by project-local equivalent"
  fi
done
```

For each found, present user w/ recommendation:
- Default: `claude plugins disable {plugin} --scope project` (preserves for other projects)
- Alternative: `claude plugins uninstall {plugin}` (global removal)
- Wait for user confirmation before acting

**LSP prerequisites:**

```bash
# Verify language server binaries available for detected languages
command -v dotnet >/dev/null 2>&1 && echo "PASS: dotnet available"
command -v pyright >/dev/null 2>&1 || command -v npx >/dev/null 2>&1 && echo "PASS: pyright available via npx"
command -v npx >/dev/null 2>&1 && echo "PASS: tsserver available via npx"
```

Note missing prerequisites in output.

---

### 7. Plugin Collision Check

ONE check (not 3x as in v5). Compare project agent names vs installed plugin agents:

```bash
PLUGIN_AGENTS=$(find ~/.claude/plugins/cache/ -name "*.md" -path "*/agents/*" 2>/dev/null | xargs head -5 2>/dev/null | grep "name:" | awk '{print $2}' | sort -u)
PROJECT_AGENTS=$(head -5 .claude/agents/*.md 2>/dev/null | grep "name:" | awk '{print $2}' | sort -u)

COLLISIONS=0
for agent in $PROJECT_AGENTS; do
  if echo "$PLUGIN_AGENTS" | grep -q "^${agent}$"; then
    echo "COLLISION: $agent exists in both project and plugin"
    COLLISIONS=$((COLLISIONS+1))
  fi
done

[[ "$COLLISIONS" -eq 0 ]] && echo "PASS: No plugin collisions" || echo "WARN: $COLLISIONS collision(s) — project-local takes precedence, consider disabling plugin equivalents"
```

---

### 8. Gitignore Verification

Based on `{git_strategy}` from Module 01:

```bash
if [[ "{git_strategy}" == "track" ]]; then
  # Personal project: .claude/ tracked, only machine-specific ignored
  grep -q "CLAUDE.local.md" .gitignore && echo "PASS: CLAUDE.local.md ignored" || echo "FAIL: CLAUDE.local.md not ignored"
  grep -q ".claude/settings.local.json" .gitignore && echo "PASS: settings.local.json ignored" || echo "FAIL: settings.local.json not ignored"
  grep -q "^\.claude/$" .gitignore && echo "FAIL: .claude/ is ignored but git_strategy is track" || echo "PASS: .claude/ tracked"

elif [[ "{git_strategy}" == "companion" ]] || [[ "{git_strategy}" == "ephemeral" ]]; then
  # Work project: all claude files ignored
  grep -q "CLAUDE.md" .gitignore && echo "PASS: CLAUDE.md ignored" || echo "FAIL: CLAUDE.md not ignored"
  grep -q "\.claude" .gitignore && echo "PASS: .claude ignored" || echo "FAIL: .claude not ignored"
  grep -q "\.learnings" .gitignore && echo "PASS: .learnings ignored" || echo "FAIL: .learnings not ignored"
fi
```

Fix any FAIL items by editing `.gitignore`.

---

### 9. Bootstrap State

Create/update `.claude/bootstrap-state.json` w/ current migration stamp:

```bash
cat > .claude/bootstrap-state.json << 'EOF'
{
  "version": "6.0",
  "bootstrapped": "{date}",
  "last_migration": "v6-initial",
  "applied": ["v6-initial"],
  "git_strategy": "{git_strategy}",
  "modules_completed": [1, 2, 3, 4, 5, 6, 7, 8]
}
EOF
```

---

## Checkpoint

```
✅ Module 08 complete — Verification + Wiring
  Verification: {PASS / FAIL + items fixed}
  Consistency: {PASS / FAIL + items fixed}
  Routing: skill-routing.md verified ({N} tokens), UserPromptSubmit nudge verified (30 tokens)
  Scoped CLAUDE.md: {created N | not needed}
  MCP: {configured / not applicable}
  Plugin collisions: {N found | none}
  Git strategy: {track / companion / ephemeral}
  Compression: {N} clean, {M} violations
  Bootstrap state: v6-initial
```
