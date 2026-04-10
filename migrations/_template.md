# Migration {ID} — {title}

> {1-sentence description of what this migration fixes}

---

## Metadata

```yaml
id: "{ID}"
breaking: false
affects: [agents, skills, techniques]   # which areas touched
requires_mcp_json: false                  # true → skip if project has no .mcp.json
min_bootstrap_version: "6.0"              # earliest bootstrap version supported
```

Fields:
- `id`: numeric string matching filename prefix (e.g., "001")
- `breaking`: true → `/migrate-bootstrap` warns + waits for confirmation
- `affects`: informational tags — agents, skills, modules, techniques, hooks, settings
- `requires_mcp_json`: if true, migration runner checks `.mcp.json` presence before applying
- `min_bootstrap_version`: semver — reject if project's `bootstrap-state.json` version lower

---

## Problem

{Description of the bug/issue/deficiency being fixed. Why this migration exists.
Include links to original brainstorm/plan if applicable: `.claude/specs/YYYY-MM-DD-*.md`}

---

## Changes

{What this migration does, in human-readable prose.
List files touched, files created, files deleted. Cross-reference techniques/modules updated in bootstrap.}

---

## Actions

### Prerequisites

```bash
# Verify bootstrap state exists — refuse to run on non-bootstrapped projects
[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }

# Conditional: require .mcp.json (only if requires_mcp_json=true)
# [[ -f ".mcp.json" ]] || { echo "SKIP: no .mcp.json — migration not applicable"; exit 0; }
```

### Step 1 — {description}

{Imperative instructions. Compressed telegraphic notation.}

```bash
# Implementation commands
```

### Step 2 — {description}

{...}

### Rules for migration scripts

- **Glob agent filenames, never hardcode** — `for agent in .claude/agents/proj-code-writer-*.md; do ... done`
- **Read-before-write** every modification — never clobber unknown state
- **Idempotent** — running twice must be safe (detect already-applied state, skip)
- **Self-contained** — do NOT reference gitignored paths (`.claude/`, `CLAUDE.md`) for remote fetch. Inline content or reference only tracked files from bootstrap repo
- **Technique sync** — if migration updates techniques, add a step to fetch updated technique files from bootstrap repo into `techniques/` (child projects copy at bootstrap time; updates don't auto-propagate)
- **Abort on error** — `set -euo pipefail` in any bash blocks; any failure → do NOT update state

### Required: register in migrations/index.json

Every migration file MUST have a matching entry in `migrations/index.json` — the `/migrate-bootstrap` skill reads this index to discover pending migrations (directory listing is not used).

Add an entry to the `migrations` array:

```json
{
  "id": "{ID}",
  "file": "{ID}-{slug}.md",
  "description": "{1-sentence description matching the migration's blockquote}",
  "breaking": false
}
```

- `id`: must match the migration's metadata `id` field and the filename prefix
- `file`: exact filename (e.g., `002-example.md`)
- `description`: short human-readable summary (shown by `/migrate-bootstrap` before applying)
- `breaking`: must match the metadata `breaking` flag (true → `/migrate-bootstrap` warns and waits for confirmation)

Missing index entry → `/check-consistency` fails + `/migrate-bootstrap` cannot discover the migration.

---

## Verify

```bash
# Final verification commands that prove migration succeeded
# Each must exit 0 on success
```

Failure of any verify step → `/migrate-bootstrap` aborts + does NOT update bootstrap-state.json.
Safe to retry after fixing.

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → "{ID}"
- append `{ "id": "{ID}", "applied_at": "{ISO8601}", "description": "{title}" }` to `applied[]`

---

## Rollback

{Optional. If this migration is safely reversible, describe how.
Many migrations are one-way — state that explicitly: "Not rollback-able. Restore from git."}
