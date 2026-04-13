# Module 09 — Companion Repo

> Conditional on git_strategy == "companion" from Module 01.
> Sets up companion repo sync infrastructure — script, skill verification, first export, cold-start hook.
> If git_strategy is "track" or "ephemeral", SKIP entirely.

---

## Idempotency

```
IF git_strategy != "companion" → SKIP module. Print:
  "✅ Module 09 skipped — git_strategy is {strategy}, companion repo not needed"
IF ~/.claude-configs/{project}/ exists + sync-config.sh exists → verify /sync skill wiring, skip creation
IF sync-config.sh missing → dispatch code-writer-bash to create
IF companion dir exists but stale → run export to refresh
```

---

## Actions

### 0. Skip Check

```
IF git_strategy != "companion" → print skip message, STOP.
```

---

### 1. Dispatch: code-writer-bash (sync-config.sh)

Dispatch `code-writer-bash` agent (inline BOOTSTRAP_DISPATCH_PROMPT from Module 01):

```
Agent(
  description: "Create companion repo sync script",
  prompt: "{BOOTSTRAP_DISPATCH_PROMPT from Module 01, code-writer-bash section}

Write .claude/scripts/sync-config.sh — companion repo sync utility.
Shell standards: #!/usr/bin/env bash, set -euo pipefail, quote all vars, [[ ]] conditionals.

USAGE: bash .claude/scripts/sync-config.sh [init|export [--force] [--prune]|import|status|push|pull|reset] [project-name]

ARG PARSING (critical — pre-parse flags before positional, BEFORE computing ACTION/PROJECT_NAME):
- Declare `_POSITIONAL=()` and `_FLAGS=()` arrays. Loop over `"$@"`: items starting with `--` → `_FLAGS`, others → `_POSITIONAL`.
- Without this pre-parse, `PROJECT_NAME="${2:-...}"` would literally capture `--force` or `--prune` when the user runs `/sync export --force`, corrupting every subsequent `"$PROJECT_NAME"` expansion.
- Canonical block (emit verbatim):
    ```
    _POSITIONAL=(); _FLAGS=()
    for arg in "$@"; do
      case "$arg" in --*) _FLAGS+=("$arg") ;; *) _POSITIONAL+=("$arg") ;; esac
    done
    ```

VARIABLES (after pre-parse):
- `ACTION="${_POSITIONAL[0]:-status}"`
- `PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"`
- `PROJECT_NAME="${_POSITIONAL[1]:-$(basename "$PROJECT_ROOT")}"`
- `COMPANION_ROOT="$HOME/.claude-configs"`
- `COMPANION_DIR="$COMPANION_ROOT/$PROJECT_NAME"`
- `FORCE_MODE=0; PRUNE_MODE=0`
- Loop over `"${_FLAGS[@]+"${_FLAGS[@]}"}"` (safe empty-array expansion under `set -u`): `--force` → `FORCE_MODE=1`; `--prune` → `PRUNE_MODE=1`; unknown flag → print warning to stderr.

LAYER INVARIANT (critical — do not violate):
- The umbrella repo lives ONLY at "$COMPANION_ROOT/.git"
- NEVER run `git init` inside "$COMPANION_DIR" — creates nested repo bug (migration 006)
- NEVER `cd "$COMPANION_DIR"` to run `git add/commit/push` — use `git -C "$COMPANION_ROOT" … -- "$PROJECT_NAME"` to scope commits to the project subdir
- All git operations use path-scoped form so the umbrella stays the single source of truth

SYNC TARGETS (project-specific, machine-independent):
- `SYNC_DIRS=(rules skills agents hooks scripts specs references)` — declare as an array so every subcommand iterates identically.
- Files: `.claude/settings.json`, `CLAUDE.md`
- Learnings: `.learnings/log.md`

DO NOT SYNC (machine-specific — NEVER emit copy commands for these, from ANY subcommand):
- `.claude/settings.local.json` — excluded from rsync branches, `rm -f` after any cp -r, never restored by import/detect-env
- `CLAUDE.local.md` — see line 65 DO NOT SYNC list; no copy command anywhere in the generated script
- `.learnings/agent-usage.log`
- `.claude/reports/`

HELPERS (define above the `case "$ACTION" in` block):

**`abort_if_nested()`** — guards every destructive command against the migration 006 nested-repo bug.
- If `[[ -d "$COMPANION_DIR/.git" ]]` → print error `"nested .git detected at $COMPANION_DIR/.git — run /migrate-bootstrap (migration 006) to flatten"` + `exit 1`.

**`mirror_delete()`** — bash-native set-difference with 50% safety gate. POSIX portable, MINGW64-safe (no rsync, no process substitution, no Python3).
- Signature: `mirror_delete <src_dir> <dst_dir> <force_flag>` — force_flag=1 bypasses the safety gate.
- Exit codes: `0` = ok (deletions applied or no-op), `1` = setup error, `2` = safety gate blocked (caller branches on `$?==2`).
- Algorithm (emit verbatim inside the function body):
  1. `[[ -d "$dst" ]]` guard → `return 0` if dst missing (nothing to mirror).
  2. `local scratch="$dst/.sync-tmp-$$"; mkdir -p "$scratch"; trap 'rm -rf "$scratch"' RETURN` — cleanup on all exit paths.
  3. Collect file lists using subshell-cd form (MANDATORY — prevents MINGW64 `C:/...` vs POSIX-path mismatch when `git rev-parse` and `find` disagree):
     - `( cd "$src" && find . -type f ) | LC_ALL=C sort > "$scratch/src.list"`
     - `( cd "$dst" && find . -type f -not -path './.sync-tmp-*/*' ) | LC_ALL=C sort > "$scratch/dst.list"`
  4. `comm -23 "$scratch/dst.list" "$scratch/src.list" > "$scratch/stale.list"` — lines only in dst (stale files to remove).
  5. `local stale_n dst_n; stale_n=$(wc -l < "$scratch/stale.list"); dst_n=$(wc -l < "$scratch/dst.list")`.
  6. Safety gate: if `stale_n -eq 0` → `return 0`. If `dst_n -gt 0 && stale_n * 100 / dst_n -ge 50 && force_flag -ne 1` → `printf 'SAFETY GATE: %d/%d files (%d%%) would be deleted from %s. Re-run with --force to override.\n' "$stale_n" "$dst_n" "$((stale_n * 100 / dst_n))" "$dst" >&2; return 2`.
  7. Apply deletions: `while IFS= read -r rel; do rm -f "$dst/${rel#./}"; done < "$scratch/stale.list"`.
  8. `return 0`.
- `LC_ALL=C sort` is **non-negotiable**: `comm` requires byte-order input on both sides; locale variance silently breaks the set-diff.
- The `.sync-tmp-*` find exclusion prevents the scratch dir from listing itself as "stale".

COMMANDS:

init:
  - `abort_if_nested`
  - `mkdir -p "$COMPANION_ROOT"`
  - `cd "$COMPANION_ROOT"`; `git init` if `.git` missing (umbrella ONLY — never inside "$COMPANION_DIR")
  - Create `README.md` ('# Claude Code Configs'), `.gitignore` ('*.log', 'agent-usage.log')
  - `git -C "$COMPANION_ROOT" add -A && git -C "$COMPANION_ROOT" commit -q -m 'Initialize companion config repo' || true`
  - `mkdir -p "$COMPANION_DIR"`
  - Print remote setup instructions

export:
  - `abort_if_nested`
  - `mkdir -p "$COMPANION_DIR/.claude" "$COMPANION_DIR/.learnings"`
  - `local gate_blocked=0`
  - For each `d` in `"${SYNC_DIRS[@]}"`:
      - `src="$PROJECT_ROOT/.claude/$d"; dst="$COMPANION_DIR/.claude/$d"`
      - `[[ -d "$src" ]] || continue`
      - `mkdir -p "$dst"`
      - If `PRUNE_MODE -eq 1`: `mirror_delete "$src" "$dst" "$FORCE_MODE" || { rc=$?; [[ $rc -eq 2 ]] && gate_blocked=1; [[ $rc -eq 2 ]] && continue; [[ $rc -ne 0 ]] && { echo "mirror_delete failed for $d: rc=$rc" >&2; exit 1; }; }`
      - `cp -r "$src/." "$dst/"`
  - Individual files (guarded; skip if source missing; NEVER emit copies for `CLAUDE.local.md` or `settings.local.json`):
      - `[[ -f "$PROJECT_ROOT/.claude/settings.json" ]] && cp "$PROJECT_ROOT/.claude/settings.json" "$COMPANION_DIR/.claude/settings.json"`
      - `[[ -f "$PROJECT_ROOT/CLAUDE.md" ]] && cp "$PROJECT_ROOT/CLAUDE.md" "$COMPANION_DIR/CLAUDE.md"`
      - `[[ -f "$PROJECT_ROOT/.learnings/log.md" ]] && mkdir -p "$COMPANION_DIR/.learnings" && cp "$PROJECT_ROOT/.learnings/log.md" "$COMPANION_DIR/.learnings/log.md"`
  - Post-copy defense-in-depth: `rm -f "$COMPANION_DIR/.claude/settings.local.json"` (catches any legacy leak).
  - If `gate_blocked -eq 1`: `printf "\nOne or more directories blocked by 50%% safety gate. Re-run with '/sync export --force --prune' to override.\n" >&2; exit 2`.
  - Print summary; `exit 0`.
  - Default (no `--prune`) is **additive only** — matches legacy behavior so callers that don't opt in don't lose data. `--prune` switches to mirror semantics. `--force` bypasses the safety gate.

import:
  - `[[ -d "$COMPANION_DIR" ]] || { echo "companion not initialized at $COMPANION_DIR" >&2; exit 1; }`
  - `abort_if_nested`
  - Reverse of export, **additive-only** (NEVER delete project files; companion is a restore source, not a destructive authority):
      - For each `d` in `"${SYNC_DIRS[@]}"`: `[[ -d "$COMPANION_DIR/.claude/$d" ]] && { mkdir -p "$PROJECT_ROOT/.claude/$d"; cp -r "$COMPANION_DIR/.claude/$d/." "$PROJECT_ROOT/.claude/$d/"; }`
      - Individual files: `settings.json`, `CLAUDE.md`, `.learnings/log.md` — guarded cp if source file exists. NEVER copy `.claude/settings.local.json` or `CLAUDE.local.md` even if they somehow exist in the companion (defense-in-depth).
  - Import **ignores** `--prune` and `--force`. Additive semantics are non-negotiable by design — see § Export/Import Asymmetry. Print a warning if `--prune` or `--force` was passed with `import`.

status:
  - `[[ -d "$COMPANION_DIR" ]] || { echo "Companion not initialized at $COMPANION_DIR — run '/sync init'"; exit 0; }`
  - If `[[ -d "$COMPANION_DIR/.git" ]]` → warn: `"nested .git detected — run /migrate-bootstrap (migration 006)"`
  - **Three-category classification** per sync directory (do NOT collapse into a single count — that was the pre-migration-020 bug that inflated totals by also counting `Common subdirectories:` lines):
      - `local new_n=0 diff_n=0 stale_n=0`
      - For each `d` in `"${SYNC_DIRS[@]}"`:
        - `src="$PROJECT_ROOT/.claude/$d"; dst="$COMPANION_DIR/.claude/$d"`
        - Handle edge cases: if src exists but dst missing → everything in src is NEW; if dst exists but src missing → everything in dst is STALE; if both missing → skip.
        - If both exist: capture `diff -rq "$src" "$dst" 2>/dev/null` output, filter out `^Common subdirectories:` lines (POSIX `diff -rq` emits FOUR line types, not three — without this filter `wc -l` inflates every count), then bucket the surviving lines:
          - `^Only in $src` → NEW (project-only, not yet exported)
          - `^Only in $dst` → STALE (companion-only, deletion propagation candidate)
          - `^Files .* differ$` → DIFF (content differs between project and companion)
        - Print per-directory line: `printf "  %-12s NEW=%d DIFF=%d STALE=%d\n" "$d" "$dir_new" "$dir_diff" "$dir_stale"` and accumulate totals.
      - Print totals line: `printf "\nTotals: NEW=%d DIFF=%d STALE=%d\n" "$new_n" "$diff_n" "$stale_n"`
      - If `stale_n -gt 0`: `printf "\nTo prune stale files: /sync export --prune\n"`
  - NEW/DIFF/STALE wording is canonical and must match the `/sync` SKILL.md status description (see `modules/06-skills.md` Dispatch 07).

push:
  - `[[ -d "$COMPANION_ROOT/.git" ]] || { echo "umbrella repo missing — run '/sync init'" >&2; exit 1; }`
  - `git -C "$COMPANION_ROOT" add -- "$PROJECT_NAME"`
  - `git -C "$COMPANION_ROOT" diff --cached --quiet -- "$PROJECT_NAME" && { echo 'Nothing to push'; exit 0; }`
  - `git -C "$COMPANION_ROOT" commit -q -m "Sync $PROJECT_NAME configs $(date -Iseconds)" -- "$PROJECT_NAME"`
  - `git -C "$COMPANION_ROOT" push || echo 'warn: no remote configured or push failed' >&2`

pull:
  - `[[ -d "$COMPANION_ROOT/.git" ]] || { echo "umbrella repo missing — run '/sync init'" >&2; exit 1; }`
  - `git -C "$COMPANION_ROOT" pull || echo 'warn: pull failed' >&2`

reset:
  - `abort_if_nested`
  - `printf "WARNING: /sync reset will WIPE and REBUILD %s/.claude and %s/.learnings from scratch.\n" "$COMPANION_DIR" "$COMPANION_DIR"`
  - `printf "Press Ctrl-C within 5 seconds to cancel...\n"`
  - `sleep 5`
  - `rm -rf "${COMPANION_DIR:?}/.claude" "${COMPANION_DIR:?}/.learnings"` — the `:?` modifier is **mandatory**: it prevents catastrophic `rm -rf /.claude/` if `$COMPANION_DIR` is ever empty-expanded.
  - `mkdir -p "$COMPANION_DIR/.claude" "$COMPANION_DIR/.learnings"`
  - Re-run the export subcommand logic with `PRUNE_MODE=1 FORCE_MODE=1` to repopulate from a clean slate — fresh rebuild bypasses the safety gate (there's nothing to delete after the `rm -rf`).
  - Print `"Reset complete — companion rebuilt from scratch."`

*:
  - `printf 'Usage: %s [init|export [--force] [--prune]|import|status|push|pull|reset] [project-name]\n' "$0" >&2`
  - `exit 1`

CONSTRAINTS (non-negotiable — emit code that respects all of these):
- Windows MINGW64 is the primary environment: rsync not bundled; process substitution `<(...)` unsupported in strict MINGW64 sed/bash; `sed -i` without backup extension fails → helpers use temp files and subshell-cd form.
- `LC_ALL=C sort` for every `comm` input — locale variance silently breaks set-diff.
- Zero Python3 dependency. Pure bash + sed + awk + find + comm + diff.
- Every destructive operation (`mirror_delete`, `reset`, any `rm -rf`) gated by `abort_if_nested` + `"${COMPANION_DIR:?}"` expansion safety.
- Helpers (`abort_if_nested`, `mirror_delete`) defined BEFORE the `case "$ACTION" in` dispatch block so all cases can invoke them.

EXPORT/IMPORT ASYMMETRY (design doctrine):
- Export = **mirror** (with `--prune`), additive (without `--prune`). `--force` bypasses the 50% safety gate.
- Import = **additive-only**, never destructive. Companion is a restore source, not a deletion authority. This asymmetry is intentional — deletion-on-import risks data loss when a fresh machine has local files the companion doesn't know about.

Make file executable (chmod +x).
Write file to .claude/scripts/sync-config.sh. Return path + 1-line summary.
"
)
```

---

### 2. Verify /sync Skill

`/sync` skill created in Module 06 (modules/06-skills.md Dispatch 07). If Module 06 is re-run, SKILL.md is regenerated from that spec — both modules must be kept in sync.
Verify wiring:

```bash
[[ -f ".claude/skills/sync/SKILL.md" ]] || echo "MISSING: /sync skill — should exist from Module 06"
```

If missing → create minimal `/sync` skill inline:

```bash
mkdir -p .claude/skills/sync
```

Write `.claude/skills/sync/SKILL.md`:

```yaml
---
name: sync
description: >
  Use when asked to sync config, backup settings, export/import claude setup,
  push/pull companion repo, check sync status, or restore config on new machine.
  Commands: /sync export, /sync import, /sync status, /sync init, /sync push, /sync pull.
---
```

```markdown
## /sync — Companion Repo Sync

Manage .claude/ config persistence across machines via companion repo at ~/.claude-configs/.

### Commands

| Command | Action |
|---------|--------|
| `/sync init` | Initialize companion repo at ~/.claude-configs/ |
| `/sync export` | Copy project .claude/ → companion (additive). Use `--prune` to also delete companion-only stale files. |
| `/sync import` | Copy companion → project .claude/ |
| `/sync status` | Show per-directory sync state: NEW (project-only), DIFF (content differs), STALE (companion-only) |
| `/sync push` | git add + commit + push companion |
| `/sync pull` | git pull companion from remote |

### Step 1: Run sync-config.sh

```bash
bash .claude/scripts/sync-config.sh {command} {project-name}
```

Project name auto-detected from git root directory name.

### What Syncs
.claude/{rules,skills,agents,hooks,scripts,specs,references}/, .claude/settings.json, CLAUDE.md, .learnings/log.md

### What Does NOT Sync
.claude/settings.local.json, CLAUDE.local.md, .learnings/agent-usage.log, .claude/reports/
```

Verify description contains "Use when" trigger phrase.

---

### 3. Run First Export

```bash
# Ensure scripts dir exists
mkdir -p .claude/scripts

# Initialize companion repo
bash .claude/scripts/sync-config.sh init

# First export
bash .claude/scripts/sync-config.sh export
```

Verify export succeeded:

```bash
PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
[[ -d "$HOME/.claude-configs/$PROJECT_NAME/.claude" ]] && echo "PASS: First export complete" || echo "FAIL: Export did not create companion directory"
```

---

### 4. Cold-Start Auto-Import Hook (user-level)

Solves chicken-and-egg: on new machine, `.claude/` is gitignored + missing → no hooks → no auto-import. User-level hook at `~/.claude/settings.json` bridges the gap.

**Ask the user:**

> Would you like me to add a cold-start auto-import hook to your user-level settings (`~/.claude/settings.json`)? This enables automatic config restoration on any machine that has your companion repo cloned. Without it, you'd need to manually run `bash ~/.claude-configs/{project}/sync-config.sh import` on first use.

**If user accepts:**

Read existing `~/.claude/settings.json` (if any). Merge the following SessionStart hook — preserve all existing hooks:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "bash -c 'P=$(basename \"$(git rev-parse --show-toplevel 2>/dev/null || pwd)\"); C=\"$HOME/.claude-configs/$P\"; if [ ! -f \".claude/settings.json\" ] && [ -d \"$C/.claude\" ]; then for d in rules skills agents hooks scripts specs references; do [ -d \"$C/.claude/$d\" ] && mkdir -p \".claude/$d\" && cp -r \"$C/.claude/$d/.\" \".claude/$d/\" 2>/dev/null; done; [ -f \"$C/.claude/settings.json\" ] && cp \"$C/.claude/settings.json\" .claude/settings.json 2>/dev/null; [ -f \"$C/CLAUDE.md\" ] && cp \"$C/CLAUDE.md\" CLAUDE.md 2>/dev/null; [ -f \"$C/.learnings/log.md\" ] && mkdir -p .learnings && cp \"$C/.learnings/log.md\" .learnings/log.md 2>/dev/null; echo \"Auto-imported .claude/ from companion repo\"; fi'"
      }
    ]
  }
}
```

Hook logic: if `.claude/settings.json` missing AND companion dir exists → copy all sync targets from companion → project. Runs on every session start, no-ops if `.claude/` already present.

**If user declines:** Note in checkpoint. User can always run manual import:

```bash
bash ~/.claude-configs/{project}/sync-config.sh import
```

---

## Checkpoint

```
✅ Module 09 complete — Companion repo sync configured
  sync-config.sh: created at .claude/scripts/sync-config.sh
  /sync skill: {created | verified from Module 06}
  Companion repo: ~/.claude-configs/{project-name}/
  First export: {complete | failed — reason}
  Cold-start hook: {installed in ~/.claude/settings.json | user declined}
  Multi-machine: run '/sync push' after changes, '/sync pull' on other machines
```
