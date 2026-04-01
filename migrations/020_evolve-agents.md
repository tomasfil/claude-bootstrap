# Migration: Evolve-Agents Sub-Specialist Support

> Add /evolve-agents skill for splitting bloated per-language agents into framework sub-specialists + audit existing for version drift

---

```yaml
# --- Migration Metadata ---
id: "020"
name: "Evolve-Agents Sub-Specialist Support"
description: >
  Adds /evolve-agents skill for splitting bloated per-language code-writer/test-writer agents
  into framework sub-specialists, and auditing existing sub-specialists for version drift.
  Also documents scope/parent frontmatter fields and adds evolution detection to /reflect.
base_commit: "76e7bc3"
date: "2026-04-01"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| add | `.claude/skills/evolve-agents/SKILL.md` | New /evolve-agents skill |
| modify | `.claude/references/techniques/agent-design.md` | Add scope/parent frontmatter field docs |
| modify | `.claude/skills/reflect/SKILL.md` | Add agent evolution detection heuristics |
| modify | `.claude/rules/general.md` | Add migration glob rule for agent filenames |
| modify | `.claude/settings.json` | Add /evolve-agents to routing hook |

---

## Actions

### Step 1 — Generate /evolve-agents skill

Fetch Module 18 from bootstrap repo and execute its skill generation section:

```bash
gh api repos/tomasfil/claude-bootstrap/contents/modules/18-evolve-agents.md \
  --jq '.content' | base64 -d > /tmp/18-evolve-agents.md
```

Read `/tmp/18-evolve-agents.md` → extract the skill content between the `## Create Skill` section's code fences → write to `.claude/skills/evolve-agents/SKILL.md`.

```bash
mkdir -p .claude/skills/evolve-agents
```

Verify: file exists + has YAML frontmatter w/ `name: evolve-agents`.

### Step 2 — Sync updated agent-design technique

Technique now documents `scope` + `parent` frontmatter fields.

```bash
gh api repos/tomasfil/claude-bootstrap/contents/techniques/agent-design.md \
  --jq '.content' | base64 -d > .claude/references/techniques/agent-design.md
```

Target is `.claude/references/techniques/` — NOT root `techniques/` (doesn't exist in client projects).

### Step 3 — Update /reflect w/ evolution detection

Read `.claude/skills/reflect/SKILL.md`. In Step 1 (Dispatch Agent) section, after bullet about `.claude/agents/`, add:

```markdown
- For each `code-writer-*` + `test-writer-*` agent: check evolution heuristics:
  1. Line count (`wc -l`) — >500 = evolution candidate
  2. Classification tree branches — 3+ top-level framework branches = candidate
  3. Framework-specific corrections in `.learnings/log.md` — 3+ for same framework = candidate
  4. Dispatch count from `.learnings/agent-usage.log` — 10+ dispatches = mature enough
  5. Sub-specialists (agents w/ `parent` field): check version drift vs project manifests
  6. Sub-specialist research staleness — reference files older than 90 days
```

In Step 2 (Present Proposals), after `- [ ] Improve agent:` line, add:

```markdown
**Agent evolution candidates** (detect only — user runs /evolve-agents):
- [ ] Evolve: {name} — {reason: >500 lines | 3+ framework branches | 3+ corrections | 10+ dispatches}
      → Recommend: run `/evolve-agents` to split into framework sub-specialists
- [ ] Update: {name} — {reason: version drift | research >90 days stale | 3+ new corrections}
      → Recommend: run `/evolve-agents` to refresh research + update agent
```

In Gotchas section, add:

```markdown
- Reflect proposes agent evolution/updates — NEVER auto-splits; user must run `/evolve-agents`
```

### Step 4 — Add migration glob rule

Read `.claude/rules/general.md`. In `## Migrations` section, add:

```markdown
- Migrations must glob agent filenames — never hardcode `code-writer-{lang}.md`. Use `for agent in .claude/agents/code-writer-*.md; do ... done` so sub-specialists receive same updates. Same for `test-writer-*.md`.
```

### Step 5 — Update routing hook

Read `.claude/settings.json`. In UserPromptSubmit hook echo string, add `/evolve-agents` to Skills list:

```
- /evolve-agents → split bloated per-language agents into framework sub-specialists, audit existing for version drift
```

### Step 6 — Wire + sync

1. Verify `.claude/skills/evolve-agents/SKILL.md` exists + has correct frontmatter
2. Verify `.claude/references/techniques/agent-design.md` contains `scope` row
3. Verify `.claude/settings.json` parses as valid JSON: `cat .claude/settings.json | python -m json.tool > /dev/null`
4. Verify routing hook contains `evolve-agents`: `grep -q 'evolve-agents' .claude/settings.json`

---

## Verify

- [ ] `.claude/skills/evolve-agents/SKILL.md` exists w/ `name: evolve-agents` frontmatter
- [ ] `.claude/references/techniques/agent-design.md` has `scope` and `parent` in frontmatter table
- [ ] `.claude/skills/reflect/SKILL.md` contains "Evolve:" proposal format
- [ ] `.claude/rules/general.md` contains migration glob rule
- [ ] `.claude/settings.json` valid JSON w/ `evolve-agents` in routing hook
- [ ] No broken cross-references

---

Migration complete: `020` — /evolve-agents skill + reflect integration + scope/parent frontmatter docs
