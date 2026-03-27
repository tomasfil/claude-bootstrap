# Claude Code — Project Bootstrap Prompt v5.0

> Paste this into a Claude Code session at your project root. Claude will analyze the codebase and set up a self-improving, self-contained development environment. Alternatively: `cat claude-bootstrap.md | claude -p`

**Is this for you?** Best for projects you'll actively develop over multiple Claude Code sessions. Overkill for one-off scripts or quick experiments. This bootstrap builds a complete self-improving infrastructure — modular, plugin-independent, with anti-hallucination patterns baked into every generated agent.

---

<role>
You are a senior engineering lead setting up a Claude Code environment. You are meticulous, systematic, and never skip steps. You treat this setup like production infrastructure — every component must be created AND wired to the components it depends on.
</role>

<task>
Analyze this project and execute ALL modules below to set up a complete, self-improving Claude Code environment. Always run a full sweep — each module handles its own idempotency (creates if missing, updates if stale, preserves if customized).
</task>

<rules>
MANDATORY RULES — VIOLATIONS CAUSE SETUP FAILURE:

1. Execute modules in order. Do not skip or combine modules.
2. After each module, print: `✅ Module N complete — {what was created/updated}`
3. If a module requires user input, STOP and wait for their answer.
4. Every file that references another file MUST use its exact path. Verify after creation.
5. At the end (Module 14), run the WIRING VERIFICATION checklist. Fix failures before reporting.
6. Do not invent files or structures not specified in the modules.
7. Hooks receive JSON on **stdin** — there is no `$CLAUDE_TOOL_INPUT` env var.
8. All skill files: YAML frontmatter with `name` and `description` between `---` markers.
9. All agent files: YAML frontmatter with `name`, `description`, `tools`, `model`, `effort`.
10. After 2 failed troubleshooting attempts, **search the web** before trying more fixes.
11. Apply anti-hallucination patterns from `techniques/anti-hallucination.md` to every generated agent.
12. Apply RCCF framework from `techniques/prompt-engineering.md` to every generated skill/agent.
</rules>

---

## Per-File Idempotency (replaces A/B/C modes)

Every module follows this protocol for each file it creates:

```
IF file exists AND has project-specific customizations → PRESERVE, note what's there
IF file exists AND matches a previous bootstrap template → UPDATE to current version
IF file doesn't exist → CREATE from template
```

No mode detection needed. Run the bootstrap any time — it brings everything to spec without destroying customizations.

---

## Master Checklist

- [ ] Module 01: Project discovered — OS, languages, frameworks, architecture, pipeline traces
- [ ] Module 02: CLAUDE.md created (<120 lines, self-improvement triggers, compact instructions)
- [ ] Module 03: `.claude/rules/` created (per-language code standards, anti-hallucination rules)
- [ ] Module 04: `.claude/settings.json` with hooks (skill routing, env detection, git guard)
- [ ] Module 05: `/reflect` skill created (self-improvement engine)
- [ ] Module 06: `/audit-file` + `/audit-memory` skills created
- [ ] Module 07: `/write-prompt` skill created
- [ ] Module 08: `CLAUDE.local.md` created, .gitignore updated
- [ ] Module 09: Scoped CLAUDE.md files (only if needed — skip is valid)
- [ ] Module 10: `.claude/agents/` with base agents (reviewer, quick-check, researcher)
- [ ] Module 11: `.learnings/` initialized
- [ ] Module 12: MCP servers + external plugin recommendations (connectors only)
- [ ] Module 13: Plugin replacement skills generated (replaces superpowers, feature-dev, etc.)
- [ ] Module 14: Wiring verification — all checks pass
- [ ] Module 15: Companion repo sync (only if git_strategy == "companion")
- [ ] Module 16: Code writer agents generated (orchestrator skill + per-language specialists)
- [ ] Module 17: Test writer agent generated (test writer + coverage skills)
- [ ] Module 18: Code reviewer enhanced (deep project-specific review with pipeline trace checks)

---

## Module Execution

Read and execute each module file in order. Each module is self-contained with full instructions.

**Foundation (must run first):**
1. Read and execute `modules/01-discovery.md` — project analysis
2. Read and execute `modules/02-claude-md.md` — root CLAUDE.md
3. Read and execute `modules/03-rules.md` — code standards and rules
4. Read and execute `modules/04-hooks.md` — hooks and skill routing

**Skills and agents:**
5. Read and execute `modules/05-skills-reflect.md` — /reflect skill
6. Read and execute `modules/06-skills-audit.md` — audit skills
7. Read and execute `modules/07-skills-write-prompt.md` — prompt writing skill
8. Read and execute `modules/08-local-config.md` — local configuration
9. Read and execute `modules/09-scoped-claude-md.md` — directory-scoped configs
10. Read and execute `modules/10-agents.md` — base subagents
11. Read and execute `modules/11-learnings.md` — self-improvement log

**Integration and verification:**
12. Read and execute `modules/12-mcp-plugins.md` — MCP and plugin recommendations
13. Read and execute `modules/13-plugin-replacements.md` — replace methodology plugins
14. Read and execute `modules/14-verification.md` — wiring verification
15. Read and execute `modules/15-companion-repo.md` — companion repo sync (conditional)

**Code generation agents (require web research — these take longer):**
16. Read and execute `modules/16-code-writer.md` — code writer orchestrator + language specialists
17. Read and execute `modules/17-test-writer.md` — test writer agent + coverage skills
18. Read and execute `modules/18-code-reviewer.md` — deep project-specific code reviewer

---

## Reference Documents

These are reference materials for modules to consult, not steps to execute:

- `techniques/prompt-engineering.md` — RCCF framework, structured outputs, taxonomy-guided prompting
- `techniques/anti-hallucination.md` — CoVe, read-before-write, LSP grounding, verification patterns
- `techniques/agent-design.md` — subagent constraints, orchestrator patterns, YAML templates

---

## Quick Start for Returning Users

If you've run this bootstrap before and want to refresh:
1. Just paste this prompt again — idempotency handles the rest
2. Customized files are preserved, outdated templates are updated, missing files are created
3. Run `/reflect` periodically to promote learnings and evolve agents
