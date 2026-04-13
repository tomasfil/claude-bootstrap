# Code Writer Capability Index

> Agent + skill inventory for the claude-bootstrap meta-project.
> Read by `/code-write` orchestrator for dispatch decisions.
> Last updated: 2026-04-10.

---

## Language Manifest

| Language | Version | Framework(s) | Fw Count | Test Framework | Files | Sub-Specialist? |
|----------|---------|--------------|----------|----------------|-------|-----------------|
| markdown | CommonMark + YAML frontmatter | none (docs + prompts) | 0 | none — bash structural validators | ~68 | no |
| bash | POSIX / bash 4+ | none (hooks + utilities) | 0 | none — `bash -n` syntax + structural checks | ~10 | no |
| JSON | strict JSON | none | 0 | `python3 -m json.tool` | ~2 (settings.json, .mcp.json if present) | covered by bash writer |

Note: no compile step; no runtime test framework. Validation = bash scripts checking file structure, YAML frontmatter, cross-reference integrity.

---

## Existing Agents

### Code Writers (type: code-writer)
- `proj-code-writer-markdown` — markdown content (modules, skills, agents, techniques, rules, CLAUDE.md) — model: opus, last-updated: 2026-04-10
- `proj-code-writer-bash` — bash scripts, hooks, JSON/YAML configs — model: sonnet, last-updated: 2026-04-10

### Test Writers (type: test-writer)
- `proj-test-writer-markdown` — bash validation tests for markdown content — model: opus, last-updated: 2026-04-10

### Reviewer (type: review)
- `proj-code-reviewer` — all content types, architecture, prompt quality, cross-refs — model: opus, last-updated: 2026-04-10

### Utility (type: utility)
- `proj-researcher` — deep research, codebase + web, evidence tracking — sonnet
- `proj-quick-check` — fast file lookups, existence checks — haiku
- `proj-consistency-checker` — cross-reference integrity validation — sonnet
- `proj-verifier` — pre-commit verification of file structure + paths — sonnet
- `proj-reflector` — learning analysis, pattern extraction, rule promotion — opus
- `proj-plan-writer` — implementation plan creation from specs — sonnet
- `proj-debugger` — bug diagnosis, root cause tracing — opus
- `proj-tdd-runner` — TDD red-green-refactor cycles — opus

Total: 12 agents (2 code-writer, 1 test-writer, 1 review, 8 utility).

---

## Existing Skills

Active development skills (from Module 06):
- `/code-write` — orchestrator: classifies request, maps pipeline, dispatches specialist
- `/coverage` — structural validation + bootstrap completeness reporting
- `/coverage-gaps` — gap analysis across skills/agents/rules
- `/review` — dispatch to `proj-code-reviewer`
- `/evolve-agents` — post-bootstrap audit + framework sub-specialist creation

Support skills: `/brainstorm`, `/spec` (absorbed into /brainstorm), `/write-plan`, `/execute-plan`, `/tdd`, `/debug`, `/commit`, `/pr`, `/write-ticket`, `/ci-triage`, `/write-prompt`, `/module-write`, `/verify`, `/consolidate`, `/reflect`, `/audit-file`, `/audit-memory`, `/migrate-bootstrap`, `/sync`, `/check-consistency`.

---

## Coverage

- **Markdown content** — fully covered by `proj-code-writer-markdown` (modules, techniques, skills, agents, rules, CLAUDE.md, learning log, migrations)
- **Bash scripts** — fully covered by `proj-code-writer-bash` (hooks, utility scripts)
- **JSON config** — covered via `proj-code-writer-bash` (settings.json nested hook schema, .mcp.json)
- **YAML frontmatter** — covered via `proj-code-writer-markdown` (embedded in markdown files, agent-index.yaml)
- **Validation tests** — covered by `proj-test-writer-markdown` (bash structural checks against markdown content)
- **Review** — covered by `proj-code-reviewer` (cross-type architecture + prompt quality)

---

## Below Threshold (skipped)

N/A — all project languages above the 3-file threshold are fully covered. No languages skipped.

---

## Evolution Support

- `/evolve-agents` — framework sub-specialist creation + staleness audit
- Sub-specialist format: `proj-code-writer-{lang}-{framework}.md` with `scope:` + `parent:` frontmatter
- Sub-specialists generated on-demand when a language crosses the 3-framework threshold; listed here upon creation
- Current state: no sub-specialists (markdown + bash each have 0 frameworks, single-agent configuration)

---

## Supersedes

- `module-writer` agent → replaced by `proj-code-writer-markdown` (broader scope, same knowledge)
- legacy unprefixed `code-writer.md` / `test-writer.md` / `code-writer-{lang}.md` → replaced by `proj-*` prefix convention (per Module 07 negative guard)
