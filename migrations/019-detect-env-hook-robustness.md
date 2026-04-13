# Migration 019 — detect-env.sh hook robustness (grep -c / arithmetic landmines)

> Rewrite `.claude/hooks/detect-env.sh` with bulletproof numeric reads — fixes `SessionStart:startup hook error ... detect-env.sh: line 87: 0` failures caused by `grep -c` stdout concatenation and unvalidated `$((...))` arithmetic.

---

## Metadata

```yaml
id: "019"
breaking: false
affects: [hooks]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

`.claude/hooks/detect-env.sh` runs on every SessionStart. Two latent bugs in the numeric-read paths cause the hook to crash with `syntax error: operand expected` (or similar bash arithmetic errors), which Claude Code surfaces as `SessionStart:startup hook error / Failed with non-blocking status code`. The session still starts, but none of the hook's output is injected — no environment context, no `CONSOLIDATE_DUE` / `REFLECT_DUE` signals, no companion auto-import.

Bug class A — `grep -c` stdout concatenation:

```bash
# BROKEN — observed in blazedex 2026-04-13
current_entries="$(grep -cE '^## [0-9]{4}-' "$log_file" 2>/dev/null || printf '0')"
```

`grep -c` is quirky: on **zero matches** it prints `0` to stdout AND exits 1. Combined with `|| printf '0'` INSIDE the command substitution, both stdouts concatenate. Result:

- grep prints `0\n`, exits 1 (no matches)
- `|| printf '0'` fires, appends `0`
- `$()` captures `0\n0` → trailing newline stripped → `current_entries="0\n0"` (3 bytes)
- `$(( current_entries - last_entries ))` → bash arithmetic chokes on the embedded newline → `line 87: 0: syntax error: operand expected` (or similar)

Bug class B — unvalidated numeric variables:

```bash
# Also brittle — empty/CRLF/garbage file content breaks arithmetic
count=$(cat "$count_file" 2>/dev/null | tr -d '\r' || printf '0')
count=$((count + 1))  # fails if $count is "" or "5\r" or non-numeric
```

Root cause (both): fallback placed INSIDE `$()` means any command's stdout on the failure path concatenates to whatever the primary command already emitted. The canonical fix is `VAR=$(cmd) || VAR=0` OUTSIDE the command substitution, followed by a regex guard before arithmetic.

---

## Changes

- Rewrites `.claude/hooks/detect-env.sh` in-place with the bulletproof version from `modules/03-hooks.md` (updated in the same bootstrap change-set).
- Backs up any prior version to `.claude/hooks/detect-env.sh.bak`.
- Introduces two shell helpers inside the hook — `read_int` and `count_matches` — that encapsulate the safe pattern so future edits cannot reintroduce the bug.
- Idempotent: detects the bulletproof sentinel (`read_int()` function definition) and skips rewrite if already present.
- Self-contained: inlines the full hook content — no remote fetch, no reference to gitignored paths.

---

## Actions

### Prerequisites

```bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -d ".claude/hooks" ]] || { echo "ERROR: .claude/hooks missing — run full bootstrap first"; exit 1; }
```

### Step 1 — Detect prior version

```bash
HOOK=".claude/hooks/detect-env.sh"

if [[ ! -f "$HOOK" ]]; then
  echo "NOTE: $HOOK missing — will create fresh (Module 03 may not have run)"
  NEEDS_REWRITE=1
elif grep -q '^read_int() {' "$HOOK" && grep -q '^count_matches() {' "$HOOK"; then
  echo "SKIP: $HOOK already has bulletproof helpers"
  NEEDS_REWRITE=0
else
  echo "REWRITE: $HOOK present but lacks bulletproof helpers"
  NEEDS_REWRITE=1
fi
```

### Step 2 — Backup and rewrite

Back up the old hook (if any) and write the bulletproof version via heredoc. The heredoc uses a quoted sentinel (`'DETECT_ENV_SH'`) so `$VAR` expressions inside the hook body stay literal and don't get interpolated at migration-apply time.

```bash
if [[ "$NEEDS_REWRITE" -eq 1 ]]; then
  if [[ -f "$HOOK" ]]; then
    cp "$HOOK" "$HOOK.bak"
    echo "BACKUP: $HOOK.bak"
  fi

  cat > "$HOOK" <<'DETECT_ENV_SH'
#!/usr/bin/env bash
# detect-env.sh — SessionStart hook
# Outputs environment context + runs session maintenance checks.
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

# OS detection
OS="unknown"
case "$(uname -s 2>/dev/null)" in
  Linux*)  OS="Linux" ;;
  Darwin*) OS="macOS" ;;
  MINGW*|MSYS*|CYGWIN*) OS="Windows" ;;
  *) OS="$(uname -s 2>/dev/null || printf 'Windows')" ;;
esac

SHELL_NAME=$(basename "${SHELL:-bash}")
BRANCH=$(git branch --show-current 2>/dev/null) || BRANCH="unknown"
[[ -n "$BRANCH" ]] || BRANCH="unknown"
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ') || UNCOMMITTED=0
[[ "$UNCOMMITTED" =~ ^[0-9]+$ ]] || UNCOMMITTED=0
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT_NAME=$(basename "$PROJECT_ROOT")

# Branch-aware hints
BRANCH_HINT=""
case "$BRANCH" in
  main|master) BRANCH_HINT="— on main, create feature branch for non-trivial work" ;;
  hotfix/*)    BRANCH_HINT="— hotfix branch, minimal changes only" ;;
  release/*)   BRANCH_HINT="— release branch, bugfixes and version bumps only" ;;
  feature/*)   BRANCH_HINT="— feature branch, normal development" ;;
esac

# Docker availability
DOCKER_STATUS="unavailable"
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  DOCKER_STATUS="available"
fi

# Companion repo auto-import (nested layout: ~/.claude-configs/{project}/.claude/)
COMPANION_DIR="$HOME/.claude-configs/$PROJECT_NAME"
COMPANION_STATUS=""
if [[ -d "$HOME/.claude-configs/.git" ]]; then
  if [[ ! -f "$PROJECT_DIR/.claude/settings.json" ]] && [[ -f "$COMPANION_DIR/.claude/settings.json" ]]; then
    mkdir -p "$PROJECT_DIR/.claude"
    cp -r "$COMPANION_DIR/.claude/"* "$PROJECT_DIR/.claude/" 2>/dev/null || true
    [[ -d "$COMPANION_DIR/.learnings" ]] && cp -r "$COMPANION_DIR/.learnings" "$PROJECT_DIR/" 2>/dev/null || true
    [[ -f "$COMPANION_DIR/CLAUDE.md" ]] && cp "$COMPANION_DIR/CLAUDE.md" "$PROJECT_DIR/" 2>/dev/null || true
    [[ -f "$COMPANION_DIR/CLAUDE.local.md" ]] && cp "$COMPANION_DIR/CLAUDE.local.md" "$PROJECT_DIR/" 2>/dev/null || true
    COMPANION_STATUS="COMPANION_IMPORTED=true"
  fi
fi

# Spec cleanup — delete specs older than 30 days
if [[ -d "$PROJECT_DIR/.claude/specs" ]]; then
  find "$PROJECT_DIR/.claude/specs" -mtime +30 -type f -delete 2>/dev/null || true
fi

cat <<EOF
Environment:
  OS: $OS
  Shell: $SHELL_NAME
  Project: $PROJECT_NAME
  Branch: $BRANCH $BRANCH_HINT
  Uncommitted files: $UNCOMMITTED
  Docker: $DOCKER_STATUS
EOF

[[ -n "$COMPANION_STATUS" ]] && printf '%s\n' "$COMPANION_STATUS"

# --- Session maintenance: bulletproof numeric reads ---
SESSION_COUNT_FILE="$PROJECT_DIR/.learnings/.session-count"
LAST_DREAM_FILE="$PROJECT_DIR/.learnings/.last-dream"
LAST_REFLECT_FILE="$PROJECT_DIR/.learnings/.last-reflect-lines"
LOG_FILE="$PROJECT_DIR/.learnings/log.md"

mkdir -p "$PROJECT_DIR/.learnings"

# read_int: return a validated integer from a file, 0 on any failure/missing/garbage.
# NEVER inline this as `VAR=$(cat f || printf 0)` — output concatenation corrupts the value.
read_int() {
  local file="$1"
  local val=0
  if [[ -f "$file" ]]; then
    val=$(tr -d '\r\n ' < "$file" 2>/dev/null) || val=0
  fi
  [[ "$val" =~ ^[0-9]+$ ]] || val=0
  printf '%s' "$val"
}

# count_matches: return a validated match count, 0 on any failure/missing/zero-match.
# grep -c prints "0" AND exits 1 on zero matches — that is the landmine.
# `VAR=$(grep -c ...) || VAR=0` is the canonical fix: the `|| VAR=0` sits OUTSIDE
# the command substitution, so the fallback does not concatenate to grep's stdout.
count_matches() {
  local pattern="$1"
  local file="$2"
  local n=0
  [[ -f "$file" ]] || { printf '0'; return; }
  n=$(grep -cE "$pattern" "$file" 2>/dev/null) || n=0
  [[ "$n" =~ ^[0-9]+$ ]] || n=0
  printf '%s' "$n"
}

# Increment session count
COUNT=$(read_int "$SESSION_COUNT_FILE")
COUNT=$((COUNT + 1))
printf '%s\n' "$COUNT" > "$SESSION_COUNT_FILE"

# Consolidate: 5+ sessions AND 24h since last dream
if [[ "$COUNT" -ge 5 ]]; then
  LAST_DREAM=$(read_int "$LAST_DREAM_FILE")
  NOW=$(date +%s)
  ELAPSED=$(( NOW - LAST_DREAM ))
  if [[ "$ELAPSED" -gt 86400 ]]; then
    printf 'CONSOLIDATE_DUE=true\n'
  fi
fi

# Reflect: 3+ new dated entries in log.md since last reflect
CURRENT_ENTRIES=$(count_matches '^##+ [0-9]{4}-' "$LOG_FILE")
LAST_ENTRIES=$(read_int "$LAST_REFLECT_FILE")
NEW_ENTRIES=$(( CURRENT_ENTRIES - LAST_ENTRIES ))
if [[ "$NEW_ENTRIES" -ge 3 ]]; then
  printf 'REFLECT_DUE=true\n'
fi
DETECT_ENV_SH

  chmod +x "$HOOK"
  echo "REWROTE: $HOOK"
fi
```

### Step 3 — Smoke test the rewritten hook

Run the hook in-place with `.learnings/` temporarily empty-ish to force the zero-match branch that triggered the bug. Hook MUST exit 0 and MUST NOT emit bash syntax errors.

```bash
TEST_OUT=$(bash .claude/hooks/detect-env.sh 2>&1) || {
  echo "FAIL: hook exited non-zero after rewrite"
  echo "---"
  echo "$TEST_OUT"
  exit 1
}
if printf '%s' "$TEST_OUT" | grep -qiE 'syntax error|operand expected|integer expression'; then
  echo "FAIL: bash arithmetic error in hook output:"
  echo "$TEST_OUT"
  exit 1
fi
echo "PASS: hook smoke test"
```

### Step 4 — Idempotency

Re-running after success:
- Step 1 sees `read_int()` + `count_matches()` sentinels → `NEEDS_REWRITE=0`
- Step 2 is skipped
- Step 3 smoke-tests the already-good hook → still passes

### Rules for migration scripts

- **Read-before-write** — Step 1 reads the existing hook and checks sentinels before rewriting
- **Idempotent** — sentinel-guarded rewrite, safe to re-run
- **Self-contained** — full hook content inlined via heredoc, no remote fetch
- **Abort on error** — `set -euo pipefail`; smoke test hard-fails migration on syntax regression
- **No gitignored-path reference** — only writes to `.claude/hooks/` in the client project

### Required: register in migrations/index.json

```json
{
  "id": "019",
  "file": "019-detect-env-hook-robustness.md",
  "description": "Rewrite .claude/hooks/detect-env.sh with bulletproof numeric reads — fixes SessionStart:startup hook error caused by grep -c stdout concatenation and unvalidated bash arithmetic on .learnings/ counter files.",
  "breaking": false
}
```

---

## Verify

```bash
set -euo pipefail

# Hook exists and is executable
[[ -x .claude/hooks/detect-env.sh ]] || { echo "FAIL: detect-env.sh missing or not executable"; exit 1; }

# Bulletproof sentinels present
grep -q '^read_int() {' .claude/hooks/detect-env.sh || { echo "FAIL: read_int helper missing"; exit 1; }
grep -q '^count_matches() {' .claude/hooks/detect-env.sh || { echo "FAIL: count_matches helper missing"; exit 1; }

# No lingering buggy pattern
if grep -qE '\$\(cat [^)]*\|\| printf' .claude/hooks/detect-env.sh || \
   grep -qE '\$\(grep -c[^)]*\|\| printf' .claude/hooks/detect-env.sh; then
  echo "FAIL: fallback-inside-\$() pattern still present in detect-env.sh"
  exit 1
fi

# Hook runs clean
OUT=$(bash .claude/hooks/detect-env.sh 2>&1) || { echo "FAIL: hook exited non-zero"; echo "$OUT"; exit 1; }
if printf '%s' "$OUT" | grep -qiE 'syntax error|operand expected|integer expression'; then
  echo "FAIL: bash error in hook output"
  echo "$OUT"
  exit 1
fi

echo "PASS: migration 019 verified"
```

Failure of any verify step → `/migrate-bootstrap` aborts + does NOT update bootstrap-state.json. Safe to retry after fixing.

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → "019"
- append `{ "id": "019", "applied_at": "{ISO8601}", "description": "detect-env.sh hook robustness — bulletproof numeric reads" }` to `applied[]`

---

## Rollback

Restore the backup: `mv .claude/hooks/detect-env.sh.bak .claude/hooks/detect-env.sh`. Note: the backup contains the buggy pattern, so rollback reintroduces the SessionStart hook failure. Git history of this repo is the preferred recovery path.
