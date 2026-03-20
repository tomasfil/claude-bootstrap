# Step 14 — Wiring Verification and Report

Run all checks below. Every item must pass before reporting success.

## Verification Checklist

### File Existence

All of these must exist:

- [ ] `CLAUDE.md`
- [ ] `CLAUDE.local.md`
- [ ] `.claude/rules/general.md`
- [ ] `.claude/rules/code-standards.md`
- [ ] `.claude/settings.json`
- [ ] `.claude/skills/reflect.md`
- [ ] `.claude/skills/audit-file.md`
- [ ] `.claude/skills/audit-memory.md`
- [ ] `.claude/skills/write-prompt.md`
- [ ] `.claude/agents/code-reviewer.md`
- [ ] `.claude/scripts/json-val.sh`
- [ ] `.claude/hooks/detect-env.sh`
- [ ] `.claude/hooks/guard-git.sh`
- [ ] `.claude/hooks/track-agent.sh`
- [ ] `.learnings/log.md`
- [ ] `.learnings/agent-usage.log`

### YAML Frontmatter

- [ ] Every skill `.md` has `name` + `description` in frontmatter
- [ ] Every agent `.md` has `name` + `description` in frontmatter
- [ ] Skill names are lowercase with hyphens only (no spaces, no underscores)

### Wiring (Feedback Loop)

The feedback loop must be fully connected:

- [ ] CLAUDE.md Self-Improvement section mentions `.learnings/log.md`
- [ ] CLAUDE.md contains the word `BEFORE` (pre-action check)
- [ ] CLAUDE.md references Trigger 2 (repeated corrections)
- [ ] CLAUDE.md references Trigger 3 (agent patterns)
- [ ] CLAUDE.md contains `Do NOT silently retry`
- [ ] CLAUDE.md contains `search the web`
- [ ] `/reflect` skill reads `log.md` and `agent-usage.log`
- [ ] `/reflect` covers agent evolution and plugin audit

### Context Management

- [ ] CLAUDE.md is under 120 lines
- [ ] CLAUDE.md has Compact Instructions section
- [ ] Workflow section mentions ~70% compaction target
- [ ] CLAUDE.md uses `@import` directives for rules/references

### Hooks

- [ ] Scripts use `json-val.sh` (not raw `jq`)
- [ ] PreToolUse guard scripts use `exit 2` to block
- [ ] SubagentStop hook logs to `agent-usage.log`
- [ ] SessionStart hook runs `detect-env.sh`
- [ ] All scripts in `.claude/scripts/` and `.claude/hooks/` are executable (`chmod +x`)

### Plugins

- [ ] No agent name collisions with installed plugins
- [ ] No hook type overlaps with installed plugins
- [ ] LSP guidance rules exist if LSP plugins are installed

### Commands

- [ ] Build command runs successfully (if applicable)
- [ ] Lint command runs successfully (if applicable)

### Gitignore

- [ ] `.gitignore` includes `CLAUDE.local.md`
- [ ] `.gitignore` includes `.claude/settings.local.json`

---

## Final Report

Print on successful verification:

```
========================================
 BOOTSTRAP COMPLETE
========================================
 Mode:          {A/B/C}
 Files created: {list}
 Feedback loop: CLAUDE.md -> .learnings/log.md -> /reflect -> CLAUDE.md
 Hooks:         {list with types, e.g. PreToolUse: guard-git.sh, ...}
 Skills:        /reflect, /audit-file, /audit-memory, /write-prompt
 Agents:        {list, e.g. code-reviewer, test-writer}
 Plugins:       {installed count / recommended count / conflicts count}
========================================
```

## Follow-up Questions

After reporting, ask:

1. Run `/audit-file` on an existing source file to test the audit skill?
2. Run `code-reviewer` agent on recent changes?
3. Create additional project-specific skills or agents?
4. Install any recommended plugins that were deferred?

**Checkpoint**: All verification checks pass. Final report printed. Follow-up questions presented.
