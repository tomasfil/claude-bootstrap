---
name: migrate-bootstrap
description: >
  Apply pending bootstrap migrations. Use when the bootstrap repo has been
  updated and you need to bring this project to the latest migration level.
  Also handles retrofit for pre-migration bootstrapped projects.
argument-hint: "[migration-id]"
allowed-tools: Read Write Edit Bash Grep Glob WebFetch
model: sonnet
effort: high
# Skill Class: main-thread — inline migration executor, no custom agent dispatch (exempt from pre-flight gate)
---

## /migrate-bootstrap — Apply Pending Migrations

### Step 0: Resolve bootstrap source repo

Resolve `BOOTSTRAP_REPO` (the `{owner}/{repo}` slug used for every `gh api` / WebFetch call below). Precedence:

1. Env var `BOOTSTRAP_REPO` if set.
2. `.claude/bootstrap-state.json` field `bootstrap_repo`.
3. Canonical default `tomasfil/claude-bootstrap`.

```bash
BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-$(jq -r '.bootstrap_repo // "tomasfil/claude-bootstrap"' .claude/bootstrap-state.json 2>/dev/null || echo tomasfil/claude-bootstrap)}"
```

Every `gh api repos/<slug>/...` URL in the steps below uses `${BOOTSTRAP_REPO}` in place of `tomasfil/claude-bootstrap` — forks that run their own migration track set `bootstrap_repo` in state (or export the env var) and the skill routes accordingly.

### Step 1: Read migration state

Read `.claude/bootstrap-state.json`.

**File exists:** extract `last_migration` + `applied[]`. Continue to Step 2.

**File missing — retrofit detection:**
- Check `.claude/settings.json` exists AND contains `"hooks"`
- Check `CLAUDE.md` exists AND contains bootstrap fingerprints (any of: "self-improvement", ".learnings/log.md", "Module")
- BOTH pass → project bootstrapped pre-migration. Create `.claude/bootstrap-state.json`:
```json
{
  "bootstrap_repo": "tomasfil/claude-bootstrap",
  "github_username": "tomasfil",
  "last_migration": "000",
  "last_applied": "{current ISO-8601 timestamp}",
  "applied": [
    { "id": "000", "applied_at": "{current ISO-8601 timestamp}", "commit": "b622344" }
  ]
}
```
- Conditions DON'T pass → not bootstrapped. Tell user: "This project has not been bootstrapped yet. Run the full bootstrap first by executing `claude-bootstrap.md`."

### Step 2: Fetch migration index

Fetch available migrations from `${BOOTSTRAP_REPO}`:

```bash
gh api "repos/${BOOTSTRAP_REPO}/contents/migrations" --jq '[.[] | select(.name != "_template.md") | .name] | sort'
```

**Fallback if `gh` unavailable:** WebFetch:
```
https://api.github.com/repos/${BOOTSTRAP_REPO}/contents/migrations
```
Filter out `_template.md`, sort by filename.

### Step 3: Identify pending migrations

Compare fetched list against `applied[].id` from state file.
- Extract numeric IDs from filenames (e.g., `001_best-practices-and-migrations.md` → `"001"`)
- Filter to migrations where id > `last_migration`
- Sort numerically ascending
- None pending → print "Already up to date at migration {last_migration}" and STOP

### Step 4: Apply each pending migration

For each pending migration in order:

1. **Fetch** migration file:
   ```bash
   gh api "repos/${BOOTSTRAP_REPO}/contents/migrations/{filename}" --jq '.content' | base64 -d
   ```
   Fallback: `https://raw.githubusercontent.com/${BOOTSTRAP_REPO}/main/migrations/{filename}`

2. **Read YAML frontmatter.** If `breaking: true` → warn user + STOP. Wait for explicit confirmation before applying.

3. **Print** `## Changes` section as summary to user.

4. **Execute** `## Actions` section — follow each step as imperative instructions. Read-before-write for all file modifications.

5. **Run** `## Verify` checks. Any check fails → STOP + report. Do NOT update state file.

6. **Update state** (only if all verify checks pass):
   - Append to `applied[]`: `{ "id": "{migration_id}", "applied_at": "{timestamp}", "commit": "{base_commit from frontmatter}" }`
   - Set `last_migration` to new id
   - Set `last_applied` to current timestamp

7. **Print** `Migration {id} applied — {description from frontmatter}`

### Step 5: Report summary

After all pending migrations applied:
```
Migrations complete: applied {N} migrations ({id_list})
Current state: migration {last_migration}
```

### bootstrap-state.json Schema

```json
{
  "bootstrap_repo": "string — source repo (tomasfil/claude-bootstrap)",
  "last_migration": "string — highest applied migration id",
  "last_applied": "string — ISO-8601 timestamp of most recent apply",
  "applied": [
    {
      "id": "string — migration id (e.g. '001')",
      "applied_at": "string — ISO-8601 timestamp",
      "commit": "string — short commit hash from migration's base_commit"
    }
  ]
}
```

### Gotchas
- Migrations apply in strict numeric order — never skip
- Retrofit requires BOTH `.claude/settings.json` w/ hooks AND `CLAUDE.md` w/ bootstrap fingerprints — project w/ just `CLAUDE.md` (no hooks) is not bootstrapped
- `gh` preferred for fetching; fallback to WebFetch w/ `api.github.com` (directory) + `raw.githubusercontent.com` (file content)
- Migration fails mid-apply → state NOT updated — safe to retry
- `[migration-id]` argument applies specific migration; default applies ALL pending
- `.claude/bootstrap-state.json` always tracked (committed | synced) — never gitignored

### Anti-Hallucination
- Read-before-write for every file modification during migration apply
- Never assume migration content — always fetch from bootstrap repo
- Verify each migration's `## Verify` section passes before updating state
- If `gh` or WebFetch fails, report error — never fabricate migration content
