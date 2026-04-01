# Module 02 — Create CLAUDE.md

> Create the root CLAUDE.md file. Must be <120 lines. Every line must earn its place.
> This file is loaded into EVERY conversation — keep it lean, use @imports for details.

---

## Idempotency

```
IF CLAUDE.md exists → READ it, EXTRACT all project-specific content (gotchas, conventions, commands, architecture), MERGE with bootstrap template, REGENERATE with both project knowledge and bootstrap improvements
IF CLAUDE.md doesn't exist → CREATE from template below
```

The goal is never "preserve the old file" — it's "carry forward all project-specific knowledge into the improved template." Generic boilerplate gets replaced; project-specific rules, gotchas, and conventions survive.

## Instruction Placement Framework

Where to put each type of instruction:

| Instruction Type | Where | Why |
|-----------------|-------|-----|
| Always-on broad rules | CLAUDE.md | Loaded every conversation (~80% adherence) |
| File-type constraints | `.claude/rules/` | Loaded contextually by file type |
| Domain workflows | Skills | Loaded only when triggered (saves context) |
| Must-happen-100% | Hooks | Deterministic — not subject to LLM interpretation |
| Reusable references | `@import` files | Loaded on demand, not always |

Budget: CLAUDE.md has ~100-150 effective instruction slots (system prompt uses ~50).
If a linter or formatter can enforce it, use a hook instead of a CLAUDE.md rule.

## Token Efficiency Principle

CLAUDE.md, rules, skills, agents, and memory files are read by Claude, not humans.
Only the conversation output needs to be human-readable. All Claude-facing content
should use compressed notation to minimize token cost on every load.

**Compression rules for Claude-facing files:**
- Strip articles (a, an, the), filler words, and unnecessary prepositions
- Use telegraphic style: `READ_BEFORE_WRITE: modules,techniques` not `Always read existing modules and techniques before editing`
- Use symbols: `→` not "results in", `|` not "or", `+` not "and", `~` for "approximately"
- Key:value and bullet lists over prose paragraphs
- Abbreviate repeated terms with a legend at top if needed
- YAML/markdown over JSON where possible (11-20% fewer tokens)
- Merge small related rules into single lines with `;` separators

**What stays readable:** conversation output, commit messages, PR descriptions, user-facing docs.

**Impact:** Always-loaded files (CLAUDE.md + rules + memory index) typically save 30-50% tokens
with compressed notation. This compounds across every conversation and every subagent invocation.

## Template

Generate CLAUDE.md using this template. Fill in `{placeholders}` from Module 01 discovery.
Keep total under 120 lines. Cut sections that don't apply.

**IMPORTANT:** This file loads every conversation. Write it in compressed telegraphic notation —
Claude parses it identically, but at 30-50% fewer tokens. See Token Efficiency Principle above.

```markdown
# {Project Name}

## Architecture
- Lang: {language} {version} | Framework: {framework} {version}
- DB: {database} (if applicable)
- Deps: {top 3-5 dependencies}
@import .claude/rules/code-standards-{lang}.md

## Key Files
{5-10 most important paths — entry points, configs, core modules}

## Commands
- Build: `{build_command}`
- Test1: `{test_single_command}`
- TestAll: `{test_suite_command}`
- Lint: `{lint_command}`
- Fmt: `{format_command}`
{Add dev server, migration, or other project-specific commands}

## Workflow
- Test: single file for changed code, not full suite
- COMPACT@~70%: proactive, don't wait
- Commits: {detected convention or "conventional commits"}
- Complex features → spec first (.claude/specs/), implement second
- `/code-write` for feature impl (auto-invoked via skill routing)
- TaskCreate for multi-step work (3+ steps); update status across compaction

## Conventions
{3-10 project-specific rules — only non-obvious ones, telegraphic style}
{Examples:}
{- Entities: extend DomainEntity<Guid>, never standalone}
{- Guard clauses + early returns over nested if-else}
{- Max fn: 50 lines → split}
{- Errors: ErrorOr<T> for business logic; exceptions = truly exceptional only}
{- DB access: IDataService<Context>, never raw DbContext}

## Gotchas
{Known traps — from discovery + .learnings/}
{Examples:}
{- .razor.cs LSP errors → often false positive, verify w/ dotnet build}
{- OwnsMany/OwnsOne → still needs .AsNoTracking() in projections}
{- Firebase JWT → email at firebase.identities.email[0], not simple claim}
{- `context: fork` in skill frontmatter broken (claude-code#16803) — skills run inline, `agent:` field ignored; use `agent: general-purpose` for Pattern B until fixed}

## Compact Instructions
PRESERVE on compaction:
- Modified files + purpose
- Current plan/spec
- Test results (pass/fail/why)
- Active branch + purpose
- Unresolved errors/blockers

SessionStart CONSOLIDATE_DUE=true → run /consolidate first
SessionStart REFLECT_DUE=true → run /reflect first

## Skill Automation
Auto (never manual unless forcing):
- /verify, /review → before /commit
- /consolidate → session start when due (5+ sessions, 24h elapsed)
- /reflect → session start when due (3+ new learnings)

Active dev:
- /brainstorm, /write-plan, /execute-plan, /tdd, /debug
- /commit, /pr, /write-prompt, /review (manual override)

## Effort
Auto per-agent (see techniques/agent-design.md):
- Trivial (typo, rename, config): effort=low
- Standard (feature, bugfix, test): effort=medium
- Complex (architecture, refactor): effort=high

## Communication
Direct — lead w/ answer, no filler. Concise code.

## Behavior
- READ_BEFORE_WRITE: read existing code/patterns before generating | modifying
- Verify before done: run build+test before claiming complete; if can't verify, say so
- No false claims: if tests fail say so; if unverified say so; never fabricate results
- Collaborator not executor: push back on bad ideas; flag adjacent bugs; use judgment
- Comments: WHY only; no redundant; no commented-out code
- Output: lead w/ answer|action; 1 sentence > 3; skip filler/preamble/transitions
- Claude-facing = compressed telegraphic (specs, plans, skills, agents, rules, memory, learnings, reasoning); human-facing = normal prose (answers, commits, PRs, questions)

## Self-Improvement
BEFORE fixing any error or continuing after user correction:
1. Append to `.learnings/log.md`: `### {date} — {category}: {summary}` + compressed details
2. THEN proceed with fix/task

Format: telegraphic compressed (log.md is Claude-facing, not human-facing)
Categories: correction | failure | gotcha | agent-candidate | environment
Hook auto-logs Bash failures (exit≠0) → manual log only: corrections, gotchas, agent-candidates
Recurs this session → update `.claude/rules/` immediately
2 failed fix attempts → search web
```

## Critical Wiring Verification

After creating CLAUDE.md, verify these are present (exact text not required, but concept must be there):
- [ ] `.learnings/log.md` mentioned by name in Self-Improvement section
- [ ] "BEFORE fixing" (or equivalent) for Self-Improvement gate
- [ ] "search web" (or equivalent) for failed fix attempts
- [ ] Compact Instructions section exists with preservation list
- [ ] Proactive compaction at ~70% mentioned in Workflow
- [ ] `@import` or `@` reference used for detailed docs
- [ ] Total line count < 120

```
✅ Module 02 complete — CLAUDE.md created ({N} lines)
```
