# Claude Code — Project Bootstrap Prompt v6.0

> Paste into a Claude Code session at project root. Claude analyzes codebase, sets up self-improving dev environment. Alt: `cat claude-bootstrap.md | claude -p`

**Is this for you?** Best for projects w/ multiple Claude Code sessions. Overkill for one-off scripts. Builds complete self-improving infrastructure — modular, plugin-independent, anti-hallucination baked in.

---

<role>
Senior engineering lead setting up Claude Code environment. Meticulous, systematic, never skip steps. Treat setup like production infrastructure — every component created AND wired to dependencies.
</role>

<task>
Before executing modules, check migration state:

**If `.claude/bootstrap-state.json` exists:**
→ Read `last_migration`. Invoke `/migrate-bootstrap` to check for + apply pending migrations.
→ Do NOT re-run all modules unless user explicitly requests full re-bootstrap.

**If `.claude/bootstrap-state.json` does not exist:**
→ Fresh install. Execute ALL modules below.
→ Each module handles its own idempotency (creates if missing, updates if stale).
→ After all modules complete, create `.claude/bootstrap-state.json`:
```json
{
  "bootstrap_version": "6.0",
  "last_migration": "000",
  "bootstrapped_at": "{ISO-8601 timestamp}",
  "modules_completed": [1,2,3,4,5,6,7,8,9]
}
```
</task>

<rules>
MANDATORY RULES — VIOLATIONS CAUSE SETUP FAILURE:

1. Execute modules in order. Do not skip or combine modules.
2. After each module, print: `✅ Module N complete — {what was created/updated}`
3. If a module requires user input, STOP and wait for their answer.
4. Every file that references another file MUST use its exact path. Verify after creation.
5. At the end (Module 08), run wiring verification checklist. Fix failures before reporting.
6. Do not invent files or structures not specified in the modules.
7. Hooks receive JSON on **stdin** — there is no `$CLAUDE_TOOL_INPUT` env var.
8. All skill files: YAML frontmatter w/ `name`, `description`, `model`, `effort`, `allowed-tools` between `---` markers. Orchestrator skills add `context: fork`, `agent`. Use `paths` for auto-activation, `argument-hint` for discoverability.
9. All agent files: YAML frontmatter w/ `name`, `description`, `tools`, `model`, `effort`, `maxTurns`, `color`. Add `memory: project` for stateful agents, `skills` list for preloaded domain knowledge.
10. After 2 failed troubleshooting attempts, **search the web** before trying more fixes.
11. Apply anti-hallucination patterns from `techniques/anti-hallucination.md` to every generated agent.
12. Apply RCCF framework from `techniques/prompt-engineering.md` to every generated skill/agent.
13. **TaskCreate per module.** Before executing each module, create a task via TaskCreate. Update to `in_progress` when starting, `completed` when done.
14. **All Claude-facing generated content** (agent bodies, skill bodies, rule files, specs, plans) MUST use compressed telegraphic notation. Full-sentence prose only in user-facing output.
15. **Main thread = pure orchestrator.** Dispatch agents, handle user questions. Never generate file content directly (except Module 01 foundation agents and Module 04 learnings init).
16. **Agent dispatch uses inline prompts during bootstrap.** BOOTSTRAP_DISPATCH_PROMPT from Module 01. Agent .md files created mid-session are NOT loaded — no hot-reload (claude-code#6497).
17. **Pass-by-reference.** Agents write to files, return path + 1-line summary (<100 chars). Main reads files only when needed for dispatch decisions.
18. **Code-writing agents run sequentially.** Each must leave project in building state. Parallel dispatch only for researchers/doc agents.

ANTI-SHORTCUT RULES — do not rationalize around these:

19. **Create the files the module specifies.** If a module says to create `guard-git.sh` as a separate script file, create it as a separate script file. Do NOT inline script logic into settings.json one-liners. Separate files exist for maintainability, readability, debuggability.
20. **Do not skip the routing infrastructure.** Tier 1 (skill descriptions) + Tier 2 (rules/skill-routing.md) + Tier 3 (UserPromptSubmit nudge) are complementary. Module 08 MUST verify all three tiers.
21. **Do not skip or abbreviate web research in Module 07.** Research phase exists because training data goes stale and projects use specific framework versions. MUST conduct searches, print count + key findings BEFORE generating agents. "I'll research later" or "8 of 15 is enough" are not acceptable.
22. **Do not decide a module's output is "not needed".** Every module is part of an integrated system. If you believe something unnecessary, flag to user and let THEM decide — do not skip silently.
</rules>

---

## Per-File Idempotency

Every module follows this protocol for each file it creates:

```
IF file exists → READ it, EXTRACT project-specific knowledge, then REGENERATE:
  - Project-specific content (conventions, patterns, gotchas, commands) carried forward
  - All required sections from current bootstrap template added/updated
  - Outdated boilerplate replaced with current version
  - This is always a MERGE+UPGRADE — never a blind preserve
IF file doesn't exist → CREATE from template
IF file is obsolete/superseded → DELETE it (e.g., old agent replaced, dead skill)
```

Every file must meet current bootstrap standard after every run. A file from a previous
bootstrap that's missing sections, uses old patterns, or has stale content is OUTDATED — it
gets upgraded while carrying forward project-specific knowledge. Nothing preserved just because it exists.

No mode detection needed. Run bootstrap any time — brings everything to current spec.

---

## Master Checklist

- [ ] Module 01: Project discovered — OS, languages, frameworks, architecture, pipeline traces; 3 foundation agents created (code-writer-markdown, researcher, code-writer-bash)
- [ ] Module 02: CLAUDE.md + `.claude/rules/` + CLAUDE.local.md + technique refs + .gitignore — all via agent dispatch
- [ ] Module 03: Hook scripts + `.claude/settings.json` — all via code-writer-bash dispatch
- [ ] Module 04: `.learnings/` initialized (log, instincts, patterns, decisions, environment, tracking)
- [ ] Module 05: 7 core agents created (quick-check, plan-writer, consistency-checker, debugger, verifier, reflector, tdd-runner)
- [ ] Module 06: ~23 skills generated (dev workflow, quality, git/lifecycle, maintenance, reporting, utilities)
- [ ] Module 07: Per-language code-writer + test-writer + code-reviewer agents via 7-phase research pipeline; agent index + capability index + pipeline traces
- [ ] Module 08: Wiring verification, routing infrastructure (3 tiers), scoped CLAUDE.md, MCP/plugin setup, plugin collision check
- [ ] Module 09: Companion repo sync (conditional — only if git_strategy == "companion")

---

## Module Execution

Read and execute each module file in order. Each module is self-contained with full instructions.

| # | File | Summary |
|---|------|---------|
| 01 | `modules/01-discovery.md` | Scan project + create 3 foundation agents |
| 02 | `modules/02-project-config.md` | CLAUDE.md, rules, local config, technique refs, .gitignore |
| 03 | `modules/03-hooks.md` | Hook scripts + settings.json via code-writer-bash |
| 04 | `modules/04-learnings.md` | `.learnings/` directory init (inline — mkdir + touch) |
| 05 | `modules/05-core-agents.md` | 7 utility/diagnostic agents via code-writer-markdown |
| 06 | `modules/06-skills.md` | ~23 skills — all via agent dispatch, batched by dependency |
| 07 | `modules/07-code-specialists.md` | Research-driven per-language specialists (7-phase pipeline) |
| 08 | `modules/08-verification.md` | Wiring verification, routing, scoped configs, MCP, plugins |
| 09 | `modules/09-companion.md` | Companion repo sync (conditional on git_strategy) |

---

## Remote Execution

If modules are not available locally (user pasted a GitHub URL or only this file), fetch from public repository:

```
REPO: https://github.com/tomasfil/claude-bootstrap
BASE: https://raw.githubusercontent.com/tomasfil/claude-bootstrap/main
```

To fetch any module or technique file:
```bash
gh api repos/tomasfil/claude-bootstrap/contents/{path} --jq '.content' | base64 -d
```

Example: `gh api repos/tomasfil/claude-bootstrap/contents/modules/01-discovery.md --jq '.content' | base64 -d`

If `gh` not available, use WebFetch with raw URL:
`https://raw.githubusercontent.com/tomasfil/claude-bootstrap/main/modules/01-discovery.md`

**Check local first**: If the file exists locally (e.g., `modules/01-discovery.md`), read it with Read tool. Only fetch from GitHub if local file doesn't exist.

---

## Reference Documents

Reference materials for modules to consult — not steps to execute:

- `techniques/prompt-engineering.md` — RCCF framework, structured outputs, taxonomy-guided prompting
- `techniques/anti-hallucination.md` — CoVe, read-before-write, LSP grounding, verification patterns
- `techniques/agent-design.md` — subagent constraints, orchestrator patterns, YAML templates
- `techniques/token-efficiency.md` — compression techniques, cache economics, telegraphic notation

---

## Quick Start for Returning Users

If you've run this bootstrap before:
1. Run `/migrate-bootstrap` to apply pending migrations (fastest path)
2. Or paste this prompt again — migration detection handles the rest automatically
3. Run `/reflect` periodically to promote learnings and evolve agents
