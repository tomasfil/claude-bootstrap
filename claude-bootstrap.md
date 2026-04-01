# Claude Code — Project Bootstrap Prompt v5.0

> Paste this into a Claude Code session at your project root. Claude will analyze the codebase and set up a self-improving, self-contained development environment. Alternatively: `cat claude-bootstrap.md | claude -p`

**Is this for you?** Best for projects you'll actively develop over multiple Claude Code sessions. Overkill for one-off scripts or quick experiments. This bootstrap builds a complete self-improving infrastructure — modular, plugin-independent, with anti-hallucination patterns baked into every generated agent.

---

<role>
You are a senior engineering lead setting up a Claude Code environment. You are meticulous, systematic, and never skip steps. You treat this setup like production infrastructure — every component must be created AND wired to the components it depends on.
</role>

<task>
Before executing modules, check migration state:

**If `.claude/bootstrap-state.json` exists:**
→ Read `last_migration`. Invoke `/migrate-bootstrap` to check for and apply pending migrations.
→ Do NOT re-run all modules unless the user explicitly requests a full re-bootstrap.

**If no `.claude/bootstrap-state.json` but `.claude/settings.json` (with hooks) AND `CLAUDE.md` (with bootstrap fingerprints) exist:**
→ Pre-migration install detected. Retrofit: create `.claude/bootstrap-state.json` stamping migration 000 as applied.
→ Then invoke `/migrate-bootstrap` to apply any pending migrations.

**If neither exists:**
→ Fresh install. Execute ALL modules below to set up a complete environment.
→ Each module handles its own idempotency (creates if missing, updates if stale).
→ After all modules complete, stamp migration 000 in `.claude/bootstrap-state.json`.
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
8. All skill files: YAML frontmatter with `name`, `description`, `model`, `effort`, `allowed-tools` between `---` markers. Orchestrator skills add `context: fork`, `agent`. Use `paths` for auto-activation, `argument-hint` for discoverability.
9. All agent files: YAML frontmatter with `name`, `description`, `tools`, `model`, `effort`, `maxTurns`, `color`. Add `memory: project` for stateful agents, `skills` list for preloaded domain knowledge.
10. After 2 failed troubleshooting attempts, **search the web** before trying more fixes.
11. Apply anti-hallucination patterns from `techniques/anti-hallucination.md` to every generated agent.
12. Apply RCCF framework from `techniques/prompt-engineering.md` to every generated skill/agent.
13. **TaskCreate per module.** Before executing each module, create a task via TaskCreate. Update to `in_progress` when starting, `completed` when done.
14. **All Claude-facing generated content** (agent bodies, skill bodies, rule files, specs, plans) MUST use compressed telegraphic notation. Full-sentence prose only in user-facing output.

ANTI-SHORTCUT RULES — do not rationalize around these:

15. **Create the files the module specifies.** If a module says to create `guard-git.sh` as a separate script file, create it as a separate script file. Do NOT inline script logic into settings.json one-liners. Separate files exist for maintainability, readability, and debuggability — a 200-character bash one-liner in JSON is unmaintainable.
16. **Do not skip the UserPromptSubmit routing hook.** Claude Code's native `user-invocable: true` detection only works when the user types the exact slash command. The routing hook catches natural language ("add a field to X") and nudges toward the right skill. These are complementary, not redundant. Module 14 MUST generate it.
17. **Do not skip or abbreviate web research in Modules 16-18.** The research phase exists because training data goes stale and projects use specific framework versions. You MUST conduct the searches, print how many you ran and key findings, BEFORE generating agents. "I'll do the research later" or "8 out of 15 is enough" are not acceptable.
18. **Do not decide a module's output is "not needed".** Every module was designed as part of an integrated system. If you believe something is unnecessary, flag it to the user and let THEM decide — do not skip it silently or with a one-line justification.
</rules>

---

## Per-File Idempotency (replaces A/B/C modes)

Every module follows this protocol for each file it creates:

**For ALL files (rules, CLAUDE.md, hooks, scripts, agents, skills):**
```
IF file exists → READ it, EXTRACT project-specific knowledge, then REGENERATE:
  - Project-specific content (conventions, patterns, gotchas, commands) carried forward
  - All required sections from current bootstrap template added/updated
  - Outdated boilerplate replaced with current version
  - This is always a MERGE+UPGRADE — never a blind preserve
IF file doesn't exist → CREATE from template
IF file is obsolete/superseded → DELETE it (e.g., old agent replaced by new one, dead skill)
```

Every file must meet the current bootstrap standard after every run. A file from a previous
bootstrap that's missing sections, uses old patterns, or has stale content is OUTDATED — it
gets upgraded while carrying forward the project-specific knowledge it contains. Nothing is
preserved just because it exists.

No mode detection needed. Run the bootstrap any time — it brings everything to current spec.

---

## Master Checklist

- [ ] Module 01: Project discovered — OS, languages, frameworks, architecture, pipeline traces
- [ ] Module 02: CLAUDE.md created (<120 lines, Behavior section, compression directive, self-improvement triggers, compact instructions)
- [ ] Module 03: `.claude/rules/` created (per-language code standards, anti-hallucination rules); `.claude/references/techniques/` populated
- [ ] Module 04: `.claude/settings.json` with hooks (skill routing, env detection, git guard, failure logging)
- [ ] Module 05: `/reflect` skill created (self-improvement engine)
- [ ] Module 06: `/audit-file` + `/audit-memory` skills created
- [ ] Module 07: `/write-prompt` skill created
- [ ] Module 08: `CLAUDE.local.md` created, .gitignore updated
- [ ] Module 09: Scoped CLAUDE.md files (only if needed — skip is valid)
- [ ] Module 10: `.claude/agents/` with 8 base agents (quick-check, researcher, plan-writer, debugger, verifier, reflector, consistency-checker, tdd-runner)
- [ ] Module 11: `.learnings/` initialized (log, instincts, patterns, decisions, environment, tracking)
- [ ] Module 12: MCP servers + external plugin recommendations (connectors only)
- [ ] Module 13: Plugin replacement skills generated (replaces superpowers, feature-dev, etc.) + `/migrate-bootstrap` + `/consolidate` skills
- [ ] Module 14: Wiring verification — all checks pass, compression compliance check
- [ ] Module 15: Companion repo sync (only if git_strategy == "companion")
- [ ] Module 16: Code writer agents generated (orchestrator skill + per-language specialists)
- [ ] Module 17: Test writer agent generated (test writer + coverage skills)
- [ ] Module 18: Code reviewer enhanced (deep project-specific review with pipeline trace checks)

---

## Remote Execution

If modules are not available locally (user pasted a GitHub URL or only this file), fetch them from the public repository:

```
REPO: https://github.com/tomasfil/claude-bootstrap
BASE: https://raw.githubusercontent.com/tomasfil/claude-bootstrap/main
```

To fetch any module or technique file:
```bash
gh api repos/tomasfil/claude-bootstrap/contents/{path} --jq '.content' | base64 -d
```

For example: `gh api repos/tomasfil/claude-bootstrap/contents/modules/01-discovery.md --jq '.content' | base64 -d`

If `gh` is not available, use WebFetch with the raw URL:
`https://raw.githubusercontent.com/tomasfil/claude-bootstrap/main/modules/01-discovery.md`

**Check local first**: If the file exists locally (e.g., `modules/01-discovery.md`), read it with the Read tool. Only fetch from GitHub if the local file doesn't exist.

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

If you've run this bootstrap before:
1. Run `/migrate-bootstrap` to apply any pending migrations (fastest path)
2. Or paste this prompt again — migration detection handles the rest automatically
3. Run `/reflect` periodically to promote learnings and evolve agents
