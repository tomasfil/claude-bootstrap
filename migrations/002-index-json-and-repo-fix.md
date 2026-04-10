# Migration 002 — migrations/index.json + bootstrap_repo fix

> Switch `/migrate-bootstrap` skill to use `migrations/index.json` for discovery, and fix `bootstrap_repo` field in `.claude/bootstrap-state.json` that was left as an unresolved `{bootstrap_repo}` placeholder by v6 Module 08.

---

## Metadata

```yaml
id: "002"
breaking: false
affects: [skills, settings]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Two bugs found after v6 migration 001 shipped:

1. **`/migrate-bootstrap` used GitHub directory listing.** The skill fetched `repos/{bootstrap_repo}/contents/migrations` and parsed the directory listing. This is fragile (rate-limited, no breaking flag available upfront, requires a second fetch per file) and makes it impossible for the bootstrap repo to gate migrations on an explicit registry. Replacement: `migrations/index.json` — authoritative list of migrations with id, file, description, and breaking flag.

2. **`bootstrap_repo` placeholder never resolved.** `modules/08-verification.md` emitted `.claude/bootstrap-state.json` with literal `"bootstrap_repo": "{bootstrap_repo}"` — the placeholder was never substituted during bootstrap. Child projects ended up with the literal string `{bootstrap_repo}`, so every `/migrate-bootstrap` invocation hit a 404 trying to fetch from `github.com/{bootstrap_repo}/...`. Fix: hardcode `tomasfil/claude-bootstrap` in the template (this repo IS the source).

---

## Changes

1. Overwrite `.claude/bootstrap-state.json` `bootstrap_repo` field to `"tomasfil/claude-bootstrap"` (idempotent — skip if already correct).
2. Regenerate `.claude/skills/migrate-bootstrap/SKILL.md` inline (self-contained per `rules/general.md` — do not fetch from bootstrap repo because `.claude/` is gitignored in many child projects).

---

## Actions

### Prerequisites

```bash
set -euo pipefail
[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -d ".claude/skills" ]] || { echo "ERROR: no .claude/skills directory"; exit 1; }
```

### Step 1 — Fix bootstrap_repo in state file

```bash
# Idempotent: only rewrite if current value is placeholder or empty
if command -v python3 >/dev/null 2>&1; then
  python3 <<'PY'
import json
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
current = state.get('bootstrap_repo', '')
if current in ('{bootstrap_repo}', '', None):
    state['bootstrap_repo'] = 'tomasfil/claude-bootstrap'
    with open('.claude/bootstrap-state.json', 'w') as f:
        json.dump(state, f, indent=2)
    print(f'FIXED: bootstrap_repo {current!r} -> tomasfil/claude-bootstrap')
else:
    print(f'SKIP: bootstrap_repo already set to {current!r}')
PY
elif command -v jq >/dev/null 2>&1; then
  current=$(jq -r '.bootstrap_repo // ""' .claude/bootstrap-state.json)
  if [[ "$current" == "{bootstrap_repo}" || -z "$current" ]]; then
    tmp=$(mktemp)
    jq '.bootstrap_repo = "tomasfil/claude-bootstrap"' .claude/bootstrap-state.json > "$tmp"
    mv "$tmp" .claude/bootstrap-state.json
    echo "FIXED: bootstrap_repo -> tomasfil/claude-bootstrap"
  else
    echo "SKIP: bootstrap_repo already set to $current"
  fi
else
  echo "ERROR: need python3 or jq to safely patch JSON"
  exit 1
fi
```

### Step 2 — Regenerate migrate-bootstrap skill (inline, self-contained)

```bash
mkdir -p .claude/skills/migrate-bootstrap
cat > .claude/skills/migrate-bootstrap/SKILL.md <<'SKILL_EOF'
---
name: migrate-bootstrap
description: >
  Use when applying bootstrap updates to this project from the bootstrap
  repo. Fetches migrations/index.json, applies pending migrations in order,
  updates state.
argument-hint: "[migration-id]"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, WebFetch
model: sonnet
effort: high
---

## /migrate-bootstrap — Apply Pending Migrations

- Step 1: Read migration state
  Read .claude/bootstrap-state.json
  Exists → extract bootstrap_repo + last_migration + applied[] → Step 2
  Missing — retrofit detection:
    .claude/settings.json exists + contains "hooks"
    CLAUDE.md exists + contains fingerprints ("self-improvement" | ".learnings/log.md")
    Both pass → pre-migration bootstrap, create bootstrap-state.json:
    { bootstrap_repo: "tomasfil/claude-bootstrap", last_migration: "000", last_applied, applied: [{ id: "000", ... }] }
    Don't pass → not bootstrapped, tell user to run full bootstrap

- Step 2: Fetch migrations/index.json
  Primary: gh api repos/${bootstrap_repo}/contents/migrations/index.json --jq '.content' | base64 -d > /tmp/mig-index.json
  Fallback (no gh): curl -sSL https://raw.githubusercontent.com/${bootstrap_repo}/main/migrations/index.json -o /tmp/mig-index.json
  Parse JSON → extract .migrations array (each entry: { id, file, description, breaking })
  Empty array → "No migrations defined in bootstrap repo" → STOP

- Step 3: Identify pending
  Filter entries where id > last_migration (string compare works for zero-padded IDs)
  Sort ascending by id
  None pending → "Already up to date" → STOP

- Step 4: Apply each in order
  1. Use entry.breaking flag from index — true → warn + STOP, wait for confirmation
  2. Fetch migration content: gh api repos/${bootstrap_repo}/contents/migrations/${entry.file} --jq '.content' | base64 -d
     Fallback: curl -sSL https://raw.githubusercontent.com/${bootstrap_repo}/main/migrations/${entry.file}
  3. Print Changes summary (parse Changes section from fetched file)
  4. Execute Actions — read-before-write for all modifications
  5. Run Verify — any fail → STOP, do NOT update state
  6. Update state: append to applied[], update last_migration + last_applied
  7. Print: Migration {id} applied — {description}

- Step 5: Report
  Migrations complete: applied {N} ({id_list})
  Current state: migration {last_migration}

- Gotchas:
  Strict numeric order — never skip
  Retrofit requires BOTH settings.json w/ hooks AND CLAUDE.md w/ fingerprints
  Fail mid-apply → state NOT updated — safe to retry
  .claude/bootstrap-state.json always tracked, never gitignored
  index.json is the source of truth — directory listings are not used
SKILL_EOF

echo "REGENERATED: .claude/skills/migrate-bootstrap/SKILL.md"
```

### Rules for migration scripts

- **Glob agent filenames, never hardcode** — N/A for this migration
- **Read-before-write** every modification — this migration rewrites two specific files with idempotency checks
- **Idempotent** — running twice must be safe: Step 1 skips if already correct, Step 2 regenerates unconditionally (body is deterministic)
- **Self-contained** — skill body is inlined in this file, not fetched from bootstrap repo (avoids dependency on `.claude/` paths in the bootstrap repo)
- **Abort on error** — `set -euo pipefail` at top of every bash block

---

## Verify

```bash
set +e
fail=0

# 1. bootstrap_repo is correct
if command -v python3 >/dev/null 2>&1; then
  repo=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['bootstrap_repo'])")
else
  repo=$(jq -r '.bootstrap_repo' .claude/bootstrap-state.json)
fi
if [[ "$repo" == "tomasfil/claude-bootstrap" ]]; then
  echo "PASS: bootstrap_repo = tomasfil/claude-bootstrap"
else
  echo "FAIL: bootstrap_repo = '$repo' (expected tomasfil/claude-bootstrap)"
  fail=1
fi

# 2. migrate-bootstrap skill exists + references index.json
if [[ -f ".claude/skills/migrate-bootstrap/SKILL.md" ]]; then
  if grep -q "migrations/index.json" ".claude/skills/migrate-bootstrap/SKILL.md"; then
    echo "PASS: migrate-bootstrap skill references index.json"
  else
    echo "FAIL: migrate-bootstrap skill missing index.json reference"
    fail=1
  fi
else
  echo "FAIL: .claude/skills/migrate-bootstrap/SKILL.md missing"
  fail=1
fi

# 3. Skill no longer references the old directory-listing approach
if grep -q "contents/migrations --jq" .claude/skills/migrate-bootstrap/SKILL.md; then
  echo "FAIL: skill still uses directory listing approach"
  fail=1
else
  echo "PASS: skill does not use directory listing"
fi

echo "---"
[[ $fail -eq 0 ]] && echo "Migration 002 verification: ALL PASS" || { echo "Migration 002 verification: FAILURES — state NOT updated"; exit 1; }
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix.

---

## State Update

On success:
- `last_migration` → "002"
- append `{ "id": "002", "applied_at": "<ISO8601>", "description": "migrations/index.json + bootstrap_repo fix" }` to `applied[]`

---

## Rollback

Not automatic. Restore from git: `.claude/bootstrap-state.json` and `.claude/skills/migrate-bootstrap/SKILL.md`. If `.claude/` is gitignored, restore from companion repo.
