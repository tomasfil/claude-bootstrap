# Module 02 — Create CLAUDE.md

> Create the root CLAUDE.md file. Must be <120 lines. Every line must earn its place.
> This file is loaded into EVERY conversation — keep it lean, use @imports for details.

---

## Idempotency

```
IF CLAUDE.md exists AND has project-specific customizations → READ it, MERGE new sections, PRESERVE customizations
IF CLAUDE.md exists AND matches old bootstrap template → UPDATE to v5 template
IF CLAUDE.md doesn't exist → CREATE from template below
```

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

## Template

Generate CLAUDE.md using this template. Fill in `{placeholders}` from Module 01 discovery.
Keep total under 120 lines. Cut sections that don't apply.

```markdown
# {Project Name}

## Architecture
- Language: {language} {version}
- Framework: {framework} {version}
- Database: {database} (if applicable)
- Key dependencies: {top 3-5 dependencies}
@import .claude/rules/code-standards-{lang}.md for detailed conventions

## Key Files
{5-10 most important paths — entry points, configs, core modules}
{Use @import for detailed docs rather than inlining content}

## Commands
{Per-language commands from discovery. Use Unix syntax (works in bash on all platforms).}
- Build: `{build_command}`
- Test (single): `{test_single_command}`
- Test (suite): `{test_suite_command}`
- Lint: `{lint_command}`
- Format: `{format_command}`
{Add dev server, migration, or other project-specific commands}

## Workflow
- Read before write — always read existing code/patterns before generating new code
- Run single test file for changed code, not the full suite
- Proactive compaction at ~70% context — don't wait until forced
- Commit format: {detected convention or "conventional commits"}
- For complex features: write spec first (in .claude/specs/), implement second
- Use `/code-write` for feature implementation (auto-invoked via skill routing hook)

## Conventions
{3-10 project-specific rules from discovery — only non-obvious ones}
{Examples:}
{- All entities extend DomainEntity<Guid> — never create standalone entities}
{- Use guard clauses / early returns over nested if-else}
{- Max function size: 50 lines — split if longer}
{- Use ErrorOr<T> for business logic errors, exceptions only for truly exceptional conditions}
{- Never inject DbContext directly — use IDataService<Context>}

## Gotchas
{Things that catch Claude off guard — from discovery + .learnings/}
{Examples:}
{- .razor.cs LSP errors are often false positives — verify with dotnet build}
{- Owned entities (OwnsMany/OwnsOne) still need .AsNoTracking() even in projections}
{- Firebase JWT: email lives in firebase.identities.email[0], not a simple claim}

## Compact Instructions
When context is compacted, PRESERVE:
- List of modified files and their purpose
- Current implementation plan / spec
- Test results (which passed, which failed, why)
- Active branch and what it's for
- Any unresolved errors or blockers

## Effort Scaling
Model selection is automatic per-agent (see `techniques/agent-design.md`).
- Trivial (typo, rename, config): effort=low
- Standard (feature, bugfix, test): effort=medium
- Complex (architecture, refactor): effort=high

## Communication
{User preference: "Direct — no fluff, lead with the answer" or "Diplomatic — explain reasoning"}

## Self-Improvement
Three triggers — ALL logged to `.learnings/log.md`:

1. **User correction** → Log the correction BEFORE continuing the task. If the same mistake would recur this session, update rules immediately.
2. **Command/tool failure** → Diagnose root cause. If environment/syntax: log AND update CLAUDE.md or rules immediately. If logic: log for `/reflect` review. After 2 failed fix attempts, search the web.
3. **Agent-candidate** → When a task would benefit from a dedicated subagent, tag it `agent-candidate` in the log. `/reflect` creates agents when the pattern appears 2+ times.
```

## Critical Wiring Verification

After creating CLAUDE.md, verify these are present (exact text not required, but concept must be there):
- [ ] `.learnings/log.md` mentioned by name in Self-Improvement section
- [ ] "BEFORE continuing" (or equivalent) for Trigger 1
- [ ] "search the web" for Trigger 2
- [ ] Compact Instructions section exists with preservation list
- [ ] Proactive compaction at ~70% mentioned in Workflow
- [ ] `@import` or `@` reference used for detailed docs
- [ ] Total line count < 120

```
✅ Module 02 complete — CLAUDE.md created ({N} lines)
```
