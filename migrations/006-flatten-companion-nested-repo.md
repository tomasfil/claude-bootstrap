# Migration 006 — Flatten companion nested-repo bug

> Detect and remove `$COMPANION_ROOT/$PROJECT_NAME/.git`, re-stage as files in the umbrella, and rewrite `.claude/hooks/sync-companion.sh` to use path-scoped `git -C` instead of `cd` into the subdir.

---

## Metadata

```yaml
id: "006"
breaking: false
affects: [hooks, scripts]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Module 03's sync-companion.sh spec was ambiguous about where the git repo lives. The hook
created a nested `.git/` at `$HOME/.claude-configs/$PROJECT_NAME/` (the project subdir),
while Module 09's `/sync` skill expects the umbrella repo at `$HOME/.claude-configs/` to
track the subdir as files. Symptoms:

- Umbrella stores `$PROJECT_NAME` as a gitlink (commit SHA) instead of tracked files
- Nested repo has no remote → pushes are silent no-ops → sync appears to work, actually broken
- `/sync push` reports success but remote never receives updates
- All v6 companion-strategy projects affected

---

## Changes

- Detects `.git/` inside `$HOME/.claude-configs/$PROJECT_NAME/` and removes it (preserving files)
- Drops gitlink entry from umbrella index and re-stages `$PROJECT_NAME` as files
- Rewrites `.claude/hooks/sync-companion.sh` to use path-scoped `git -C "$COMPANION_ROOT"` form
- Backs up old hook to `.claude/hooks/sync-companion.sh.bak`
- Idempotent: re-running after success detects flat layout and new hook pattern, skips work

---

## Actions

### Prerequisites

```bash
set -euo pipefail

# Verify bootstrap state exists
[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }

# Only applies to companion strategy
STRATEGY=$(grep -o '"git_strategy":[[:space:]]*"[^"]*"' .claude/bootstrap-state.json | sed 's/.*"\([^"]*\)"$/\1/')
[[ "$STRATEGY" == "companion" ]] || { echo "SKIP: git_strategy=$STRATEGY — migration 006 only applies to companion"; exit 0; }

# Require umbrella repo exists
[[ -d "$HOME/.claude-configs/.git" ]] || { echo "SKIP: umbrella repo $HOME/.claude-configs/.git missing — nothing to flatten"; exit 0; }
```

### Step 1 — Detect nested repo

```bash
PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel)")
COMPANION_ROOT="$HOME/.claude-configs"
COMPANION="$COMPANION_ROOT/$PROJECT_NAME"

[[ -d "$COMPANION" ]] || { echo "SKIP: no companion dir at $COMPANION"; exit 0; }

NESTED=0
[[ -d "$COMPANION/.git" ]] && NESTED=1
echo "NESTED=$NESTED at $COMPANION"
```

### Step 2 — Safety checks (only if NESTED=1)

Abort if the nested repo has a remote — user must resolve manually to avoid silent loss of
pushed commits. Informational warning only if working tree dirty (files stay in place, only
`.git/` is removed).

```bash
if [[ "$NESTED" -eq 1 ]]; then
  REMOTES=$(git -C "$COMPANION" remote -v 2>/dev/null || true)
  if [[ -n "$REMOTES" ]]; then
    echo "ERROR: nested repo at $COMPANION has remotes:"
    echo "$REMOTES"
    echo "Resolve manually — push any unique commits to the umbrella remote, then delete $COMPANION/.git"
    exit 1
  fi

  DIRTY=$(git -C "$COMPANION" status --porcelain 2>/dev/null || true)
  if [[ -n "$DIRTY" ]]; then
    echo "WARN: nested repo has uncommitted changes (files preserved, only .git/ will be removed)"
  fi
fi
```

### Step 3 — Flatten nested repo (only if NESTED=1)

```bash
if [[ "$NESTED" -eq 1 ]]; then
  rm -rf "$COMPANION/.git"

  # Drop gitlink entry in umbrella if present — mode 160000 == gitlink (submodule/commit)
  GITLINK=$(git -C "$COMPANION_ROOT" ls-files -s -- "$PROJECT_NAME" 2>/dev/null | awk '$1=="160000"{print $4; exit}')
  if [[ -n "$GITLINK" ]]; then
    git -C "$COMPANION_ROOT" rm --cached -- "$PROJECT_NAME" 2>/dev/null || true
  fi

  git -C "$COMPANION_ROOT" add -- "$PROJECT_NAME"
  if ! git -C "$COMPANION_ROOT" diff --cached --quiet -- "$PROJECT_NAME"; then
    git -C "$COMPANION_ROOT" commit -q -m "migration 006: flatten $PROJECT_NAME nested repo" -- "$PROJECT_NAME"
  fi
  echo "FLATTENED: $COMPANION/.git removed, umbrella re-indexed"
fi
```

### Step 4 — Rewrite `.claude/hooks/sync-companion.sh`

Read-before-write: detect broken pattern (absence of `git -C "$COMPANION_ROOT"` form, or
presence of `cd "$COMPANION"` / `cd "$HOME/.claude-configs/$"`). Back up and rewrite.

```bash
HOOK=".claude/hooks/sync-companion.sh"
if [[ -f "$HOOK" ]]; then
  REWRITE=0
  if ! grep -q 'git -C "\$COMPANION_ROOT"' "$HOOK"; then
    REWRITE=1
  fi
  if grep -qE 'cd +"?\$COMPANION"?[^_R]|git +-C +"?\$COMPANION"? ' "$HOOK"; then
    # either `cd "$COMPANION"` (not `$COMPANION_ROOT`) or `git -C "$COMPANION"` → nested-repo form
    REWRITE=1
  fi

  if [[ "$REWRITE" -eq 1 ]]; then
    cp "$HOOK" "$HOOK.bak"
    cat > "$HOOK" <<'SYNC_HOOK'
#!/usr/bin/env bash
set -euo pipefail

COMPANION_ROOT="$HOME/.claude-configs"
[[ -d "$COMPANION_ROOT/.git" ]] || exit 0

PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
COMPANION="$COMPANION_ROOT/$PROJECT_NAME"

# NEVER run `git init` inside "$COMPANION" — umbrella is the only repo
mkdir -p "$COMPANION/.claude" "$COMPANION/.learnings"

if command -v rsync >/dev/null 2>&1; then
  [[ -d .claude ]]    && rsync -a --delete .claude/    "$COMPANION/.claude/"
  [[ -d .learnings ]] && rsync -a --delete .learnings/ "$COMPANION/.learnings/"
else
  [[ -d .claude ]]    && { rm -rf "$COMPANION/.claude";    cp -r .claude    "$COMPANION/.claude"; }
  [[ -d .learnings ]] && { rm -rf "$COMPANION/.learnings"; cp -r .learnings "$COMPANION/.learnings"; }
fi

[[ -f CLAUDE.md ]]       && cp CLAUDE.md       "$COMPANION/CLAUDE.md"       || true
[[ -f CLAUDE.local.md ]] && cp CLAUDE.local.md "$COMPANION/CLAUDE.local.md" || true

# Stage + commit via umbrella ONLY, path-scoped to this project
git -C "$COMPANION_ROOT" add -- "$PROJECT_NAME"
git -C "$COMPANION_ROOT" diff --cached --quiet -- "$PROJECT_NAME" && exit 0
git -C "$COMPANION_ROOT" commit -q -m "sync $PROJECT_NAME: $(date -Iseconds)" -- "$PROJECT_NAME"
git -C "$COMPANION_ROOT" push -q 2>/dev/null || true
# NEVER `cd "$COMPANION"` and run `git add -A` — creates nested repo
SYNC_HOOK
    chmod +x "$HOOK"
    echo "REWROTE: $HOOK (backup at $HOOK.bak)"
  else
    echo "SKIP: $HOOK already uses path-scoped form"
  fi
else
  echo "WARN: $HOOK not found — module 03 may not have generated it"
fi
```

### Step 5 — Idempotency

Re-running after success is safe:
- NESTED=0 → Steps 2–3 skipped (nothing to flatten)
- Step 4 detects new pattern already present → skip rewrite

### Rules for migration scripts

- **Glob agent filenames, never hardcode**
- **Read-before-write** every modification
- **Idempotent** — running twice must be safe
- **Self-contained** — no gitignored path references for remote fetch
- **Abort on error** — `set -euo pipefail`

### Required: register in migrations/index.json

Entry:

```json
{
  "id": "006",
  "file": "006-flatten-companion-nested-repo.md",
  "description": "Flatten companion nested-repo bug — detect and remove $COMPANION_ROOT/$PROJECT_NAME/.git, re-stage as files in the umbrella, and rewrite .claude/hooks/sync-companion.sh to use path-scoped git -C instead of cd into the subdir.",
  "breaking": false
}
```

---

## Verify

```bash
PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel)")
COMPANION_ROOT="$HOME/.claude-configs"
COMPANION="$COMPANION_ROOT/$PROJECT_NAME"

[[ ! -d "$COMPANION/.git" ]] && echo "PASS: no nested .git" || { echo "FAIL: nested .git still present"; exit 1; }

grep -q 'git -C "\$COMPANION_ROOT"' .claude/hooks/sync-companion.sh && echo "PASS: hook rewritten" || { echo "FAIL: hook not rewritten"; exit 1; }

first=$(git -C "$COMPANION_ROOT" ls-files "$PROJECT_NAME" 2>/dev/null | head -1)
if [[ -n "$first" && "$first" != "$PROJECT_NAME" ]]; then
  echo "PASS: tracked as files ($first)"
else
  echo "WARN: umbrella has no tracked files yet for $PROJECT_NAME — run sync hook to populate"
fi
```

Failure of any verify step → `/migrate-bootstrap` aborts + does NOT update bootstrap-state.json.
Safe to retry after fixing.

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → "006"
- append `{ "id": "006", "applied_at": "{ISO8601}", "description": "Flatten companion nested-repo bug" }` to `applied[]`

---

## Rollback

Not rollback-able for the flatten step — the nested `.git/` is discarded, and since it had
no remote there is no authoritative source to restore from. Files under `$COMPANION` are
preserved throughout. The old hook is backed up to `.claude/hooks/sync-companion.sh.bak`
for hook rollback if needed.
