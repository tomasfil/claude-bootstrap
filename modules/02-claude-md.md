# Step 2 — Create CLAUDE.md

> **Mode C**: If CLAUDE.md exists, read it first. Only add missing sections — preserve existing customizations.

## Constraints

- **120 lines max** — every line must earn its place
- Structured lists > narrative paragraphs (compaction preserves lists at ~92% vs ~71%)
- Use `@import` pointers, not inline content
- Don't duplicate what linters already enforce

## Template Structure

```markdown
# {Project Name}

## Architecture
{framework, major patterns, key abstractions — 2-5 lines}

## Environment
{auto-detected by SessionStart hook — OS, shell, package manager, runtime versions}
{line endings, path conventions}

## Key Files
@import .claude/rules/code-standards.md
@import {other key docs as needed}

## Commands
- Build: `{cmd}`
- Test: `{cmd}` | Single: `{cmd} -- {path}`
- Lint: `{cmd}` | Fix: `{cmd}`
- Typecheck: `{cmd}`
- Format: `{cmd}`

## Workflow
- Branch from main, PR when done
- Run lint+typecheck+test before committing
- Compact proactively at ~70% context usage (`/compact`)
{project-specific workflow notes}

## Conventions
{3-8 lines of project-specific conventions not covered by linters}

## Gotchas
{known footguns, platform quirks, non-obvious behaviors — bulleted}

## Compact Instructions
When compacting, ALWAYS preserve: Architecture, Commands, Conventions, Self-Improvement (especially .learnings triggers). Drop verbose Gotchas first.

## Self-Improvement
When the user corrects you or a command/tool fails:
1. Log to `.learnings/log.md` BEFORE continuing (format: date, trigger, lesson, status:pending)
2. Do NOT silently retry failed commands — diagnose the root cause first
3. After 2 failed attempts, search the web for solutions
4. Tag recurring patterns for `/reflect` review

Trigger types:
- **User correction** → immediate log + adjust behavior
- **Command/tool failure** → diagnose, log, DON'T silently retry, search web after 2 attempts
- **Agent-candidate task** → tag for /reflect review (repetitive, multi-step, domain-specific)

Note: Claude Code's Auto Memory (~/.claude/projects/<project>/memory/) handles session-to-session learnings automatically. The `.learnings/log.md` system is for structured, reviewable corrections that feed `/reflect` — they complement each other.
```

## Guidelines for Writing CLAUDE.md (Context Engineering)

- **Use @imports** for detailed docs — don't inline large content
- **Don't duplicate linter rules** — if ESLint/Biome/ruff enforces it, skip it
- **Structured > narrative** — bullet lists, tables, short headers
- **Be specific** — "Use `pnpm`" not "Use the project's package manager"
- **Signal critical rules** — prefix with IMPORTANT, NEVER, ALWAYS
- **Skills > CLAUDE.md** for domain knowledge — progressive disclosure keeps base context lean

## Wiring Verification

Before completing, verify Self-Improvement section contains ALL of:
- [ ] References `.learnings/log.md`
- [ ] Says "log BEFORE continuing"
- [ ] Trigger 2 (command/tool failure) is present
- [ ] Trigger 3 (agent-candidate tasks) is present
- [ ] Contains "Do NOT silently retry"
- [ ] Contains "search the web" after 2 attempts

If any are missing, fix before proceeding.

## Checkpoint

Print: `Step 2 complete — CLAUDE.md created ({N} lines)`
Verify line count is <=120. If over, trim Gotchas or Conventions first.
