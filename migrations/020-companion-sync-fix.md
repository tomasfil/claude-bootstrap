# Migration 020 — Companion Repo Sync Deletion Semantics Fix

> Patch four client-project files (`sync-config.sh`, `sync-companion.sh`, `detect-env.sh`, `.claude/skills/sync/SKILL.md`) to fix the long-standing "companion never loses files" deletion-semantics bug, add a `--force`/`reset` safety-gate override to `/sync export`, correct the three-category status classification, and stop the auto-import from silently clobbering project config with machine-specific `settings.local.json` / `CLAUDE.local.md`.

---

## Metadata

```yaml
id: "020"
breaking: false
affects: [scripts, hooks, skills]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

The companion repo sync subsystem (git strategy `companion`) has five distinct bugs that compound into a single user-visible failure mode: **the companion repo slowly accumulates stale files that never get pruned, while machine-specific files (`settings.local.json`, `CLAUDE.local.md`) leak into the sync set and overwrite teammates' config on auto-import**.

Bug 1 — `sync-config.sh export` is additive-only. The original implementation runs `cp -r .claude/$d/. $COMPANION/.claude/$d/` per sync dir. New/changed files land correctly, but files deleted from the project NEVER get removed from the companion. Over time the companion diverges.

Bug 2 — `sync-config.sh` has no safety-gate override. When a user legitimately deletes many files (e.g. a refactor), any delete-aware implementation would need a way to say "yes, really, delete them". The current script has no such flag, and no `reset` action for "wipe companion and rebuild from scratch".

Bug 3 — `sync-config.sh status` miscounts the three categories (new / diff / stale). It runs `diff -rq` once and greps for `Only in .*`, but does not distinguish `Only in project` (new) from `Only in companion` (stale), and its `Common subdirectories:` lines either inflate counts or get silently absorbed into the wrong bucket.

Bug 4 — `sync-companion.sh` (the Stop hook variant) `rsync --delete` line and `cp -r` fallback both copy `settings.local.json` into the companion on every Stop hook fire. `settings.local.json` is explicitly marked DO NOT SYNC in `modules/09-companion.md` — it is the machine-specific override file that must never cross machines. Likewise the hook copies `CLAUDE.local.md` (also machine-specific).

Bug 5 — `detect-env.sh` auto-import does a wholesale `cp -r "$COMPANION/.claude/"*` into `$PROJECT/.claude/`. This ignores `SYNC_DIRS` scope (it copies whatever happens to be in the companion, including `.learnings/` from a different machine, `settings.local.json`, `CLAUDE.local.md`), and it copies EVERYTHING rather than only directories the project lacks — so it blows away a half-configured project with the companion's old state.

Root cause (all five): the sync subsystem was written as "additive copy", not "mirror", and the auto-import side was written as "wholesale clobber", not "additive restore". A correct implementation needs:

- `mirror_delete()` helper in `sync-config.sh` — delete files present in dst but absent in src, with a 50% safety gate and a `--force` override.
- `reset` action in `sync-config.sh` — nuke companion and rebuild from scratch.
- `_POSITIONAL` / `_FLAGS` pre-parse in `sync-config.sh` — so `--force` is not mistaken for `PROJECT_NAME`.
- Three-category classification in `status` action — `new`, `diff`, `stale` counted via anchored greps on a single captured `diff -rq`.
- `--exclude='settings.local.json'` on the rsync branch of `sync-companion.sh`, plus nuke-and-repave cp-r fallback that excludes the same.
- Remove the `CLAUDE.local.md` copy from `sync-companion.sh` entirely.
- Per-`SYNC_DIR` additive restore loop in `detect-env.sh` — only copy dirs the project lacks, never settings.local.json, never CLAUDE.local.md.

This migration applies all seven changes, each guarded by an idempotency sentinel so the migration is safe to re-run.

---

## Changes

- `sync-config.sh`: _POSITIONAL/_FLAGS pre-parse, `mirror_delete()` helper, `export` case rewritten with safety gate, new `reset` action, three-category `status`, corrected USAGE line.
- `sync-companion.sh` (Stop hook): `rsync --exclude='settings.local.json'`, cp-r fallback replaced with nuke-and-repave block, removal of `CLAUDE.local.md` copy. Escape hatch `FIX2_SKIP` if anchor not found (manual patch required — migration does NOT fail).
- `detect-env.sh` (SessionStart hook): wholesale `cp -r "$COMPANION/.claude/"*` replaced with explicit per-`SYNC_DIR` additive restore loop; `settings.json` and `.learnings/` individually guarded; `CLAUDE.local.md` never restored.
- `.claude/skills/sync/SKILL.md`: `argument-hint` frontmatter updated for `export [--prune]`; status description rewritten to mention the three categories (NEW / DIFF / STALE) and the prune hint.
- Bootstrap self-check: if the migration is running in the bootstrap repo itself (`modules/06-skills.md` present), a final check confirms the module source-of-truth is aligned with the patches.

Every patch is guarded by a `grep -q` anchor check. Already-patched files print `SKIP`; not-patched files print `PATCHED`. Run twice → identical final state.

**FIX2_SKIP escape hatch**: `sync-companion.sh` is the only file where the upstream line numbers have drifted repeatedly across bootstrap versions. If the anchor `cp -r "$PROJECT_ROOT/.claude/"*` is not found, the migration prints `FIX2_SKIP: anchor not found in sync-companion.sh — manual patch required` and continues (does NOT fail). All other fixes still run. The user fixes `sync-companion.sh` by hand using the block printed in the migration footer.

**MINGW64 notes**: every `sed -i` uses the explicit `sed -i.bak '...' FILE && rm -f FILE.bak` pattern (strict MINGW64 git bash rejects bare `sed -i`). No process substitution (`< <(...)`) — using `while read` with tmp files or explicit variable captures. No `readarray` / `mapfile`. `awk` is used wherever a pattern contains literal `|` characters (sed delimiter collision).

---

## Actions

### Prerequisites

```bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }

# This migration targets projects with git_strategy: companion.
# Projects without companion sync will have missing target files — each FIX section
# prints SKIP and continues. The migration does not fail.
GIT_STRATEGY=""
if [[ -f ".claude/bootstrap-state.json" ]]; then
  GIT_STRATEGY=$(grep -oE '"git_strategy"[[:space:]]*:[[:space:]]*"[^"]*"' .claude/bootstrap-state.json 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/') || GIT_STRATEGY=""
fi
printf 'Detected git_strategy: %s\n' "${GIT_STRATEGY:-unknown}"
```

---

### FIX1 — sync-config.sh (five sub-patches)

Target: `.claude/scripts/sync-config.sh`. Applied in order: (1) `_POSITIONAL` pre-parse, (2) `mirror_delete` helper insertion, (3) `export` case awk replace, (4) new `reset` case awk insert, (5) `status` case awk replace, plus USAGE line sed, and finally `bash -n` syntax check.

```bash
SCRIPT=".claude/scripts/sync-config.sh"

if [[ ! -f "$SCRIPT" ]]; then
  printf 'SKIP: %s not found (git_strategy != companion)\n' "$SCRIPT"
else
  printf '== FIX1: patching %s ==\n' "$SCRIPT"

  # ---- FIX1.1 — _POSITIONAL / _FLAGS pre-parse block ----
  # Anchor: existing ACTION="${1:-status}" line. Replace the old 3-line block
  # (ACTION / PROJECT_ROOT / PROJECT_NAME) with the pre-parse block + new
  # assignments that read from $_POSITIONAL.
  if grep -q '_POSITIONAL' "$SCRIPT"; then
    printf 'SKIP: FIX1.1 _POSITIONAL pre-parse already present\n'
  elif ! grep -q 'ACTION="\${1:-status}"' "$SCRIPT"; then
    printf 'SKIP: FIX1.1 anchor ACTION="${1:-status}" not found — already patched or custom script\n'
  else
    awk '
      BEGIN { patched = 0 }
      /^ACTION="\$\{1:-status\}"/ && !patched {
        print "# Pre-parse: separate flags (--*) from positional args."
        print "# Prevents PROJECT_NAME from being set to a flag like \"--force\"."
        print "_POSITIONAL=()"
        print "_FLAGS=()"
        print "for _arg in \"$@\"; do"
        print "  if [[ \"$_arg\" == --* ]]; then"
        print "    _FLAGS+=(\"$_arg\")"
        print "  else"
        print "    _POSITIONAL+=(\"$_arg\")"
        print "  fi"
        print "done"
        print "unset _arg"
        print ""
        print "ACTION=\"${_POSITIONAL[0]:-status}\""
        patched = 1
        next
      }
      /^PROJECT_ROOT=/ && patched == 1 {
        print "PROJECT_ROOT=\"$(git rev-parse --show-toplevel 2>/dev/null || pwd)\""
        next
      }
      /^PROJECT_NAME=/ && patched == 1 {
        print "PROJECT_NAME=\"${_POSITIONAL[1]:-$(basename \"$PROJECT_ROOT\")}\""
        patched = 2
        next
      }
      { print }
    ' "$SCRIPT" > "${SCRIPT}.tmp" && mv "${SCRIPT}.tmp" "$SCRIPT"
    printf 'PATCHED: FIX1.1 _POSITIONAL pre-parse inserted\n'
  fi

  # ---- FIX1.2 — mirror_delete helper ----
  # Insert after abort_if_nested() function definition.
  if grep -q 'mirror_delete' "$SCRIPT"; then
    printf 'SKIP: FIX1.2 mirror_delete already present\n'
  elif ! grep -q '^abort_if_nested()' "$SCRIPT"; then
    printf 'SKIP: FIX1.2 anchor abort_if_nested() not found — script layout unexpected\n'
  else
    awk '
      BEGIN { in_fn = 0; done = 0 }
      /^abort_if_nested\(\)/ { in_fn = 1 }
      { print }
      in_fn == 1 && /^}/ && done == 0 {
        print ""
        print "# mirror_delete SRC DST [force]"
        print "# Deletes files from DST that are not present in SRC."
        print "# force: pass literal \"force\" to bypass the 50% safety gate."
        print "# SAFETY: only touches files under DST. Never touches files outside DST scope."
        print "# SAFETY: even with force, never deletes .git directories."
        print "mirror_delete() {"
        print "  local src=\"$1\""
        print "  local dst=\"$2\""
        print "  local force_mode=\"${3:-}\"    # pass \"force\" to bypass 50% gate"
        print ""
        print "  [[ -d \"$src\" ]] || { printf '"'"'mirror_delete: src not found: %s\\n'"'"' \"$src\" >&2; return 1; }"
        print "  [[ -d \"$dst\" ]] || { printf '"'"'mirror_delete: dst not found: %s\\n'"'"' \"$dst\" >&2; return 1; }"
        print ""
        print "  local scratch"
        print "  scratch=\"${dst}/.sync-tmp-$$\""
        print "  mkdir -p \"$scratch\" || { printf '"'"'mirror_delete: cannot create scratch dir %s\\n'"'"' \"$scratch\" >&2; return 1; }"
        print "  trap '"'"'rm -rf \"$scratch\"'"'"' RETURN"
        print ""
        print "  (cd \"$src\" && find . -type f -not -path '"'"'*/.git/*'"'"') \\"
        print "    | LC_ALL=C sort > \"$scratch/src.txt\" \\"
        print "    || { printf '"'"'mirror_delete: find src failed\\n'"'"' >&2; return 1; }"
        print ""
        print "  (cd \"$dst\" && find . -type f -not -path '"'"'*/.git/*'"'"') \\"
        print "    | LC_ALL=C sort > \"$scratch/dst.txt\" \\"
        print "    || { printf '"'"'mirror_delete: find dst failed\\n'"'"' >&2; return 1; }"
        print ""
        print "  # Safety gate: refuse if files-to-delete > 50% of dst total (unless force_mode)"
        print "  local dst_total to_delete_count delete_pct"
        print "  dst_total=$(wc -l < \"$scratch/dst.txt\")"
        print "  to_delete_count=$(comm -23 \"$scratch/dst.txt\" \"$scratch/src.txt\" | wc -l)"
        print ""
        print "  if [[ $dst_total -gt 0 && -z \"$force_mode\" ]]; then"
        print "    delete_pct=$(( to_delete_count * 100 / dst_total ))"
        print "    if [[ $delete_pct -gt 50 ]]; then"
        print "      printf '"'"'mirror_delete: SAFETY GATE — %d%% of dst files (%d/%d) flagged for deletion (>50%%).\\n'"'"' \\"
        print "        \"$delete_pct\" \"$to_delete_count\" \"$dst_total\" >&2"
        print "      printf '"'"'mirror_delete: Run with --force to proceed, or use: bash .claude/scripts/sync-config.sh reset\\n'"'"' >&2"
        print "      return 2    # exit code 2 = gate fired (distinguishable from exit 1 = setup error)"
        print "    fi"
        print "  fi"
        print ""
        print "  # Delete stale files. comm -23: lines only in file1 (dst) NOT in file2 (src) → stale in dst."
        print "  # Argument order: comm -23 DST SRC (lines in DST not in SRC)."
        print "  comm -23 \"$scratch/dst.txt\" \"$scratch/src.txt\" \\"
        print "    | while IFS= read -r rel; do"
        print "        relpath=\"${rel#./}\""
        print "        rm -f \"$dst/$relpath\" \\"
        print "          || printf '"'"'mirror_delete: failed to delete %s\\n'"'"' \"$dst/$relpath\" >&2"
        print "      done"
        print "}"
        in_fn = 0
        done = 1
      }
    ' "$SCRIPT" > "${SCRIPT}.tmp" && mv "${SCRIPT}.tmp" "$SCRIPT"
    printf 'PATCHED: FIX1.2 mirror_delete helper inserted\n'
  fi

  # ---- FIX1.3 — export case replacement ----
  # Replace the block between "export)" and the next ";;" with the revised
  # export case that uses mirror_delete + --force flag parsing.
  if grep -q 'gate_blocked' "$SCRIPT"; then
    printf 'SKIP: FIX1.3 export case already patched\n'
  elif ! grep -q '^[[:space:]]*export)' "$SCRIPT"; then
    printf 'SKIP: FIX1.3 anchor "export)" not found\n'
  else
    awk '
      BEGIN { in_export = 0; skipped = 0 }
      /^[[:space:]]*export\)/ && in_export == 0 && skipped == 0 {
        print "    export)"
        print "        # Check for --force in pre-parsed _FLAGS array (set at script top)"
        print "        FORCE_MODE=\"\""
        print "        for _f in \"${_FLAGS[@]+\"${_FLAGS[@]}\"}\"; do"
        print "          [[ \"$_f\" == \"--force\" ]] && FORCE_MODE=\"force\""
        print "        done"
        print "        unset _f"
        print ""
        print "        abort_if_nested"
        print "        mkdir -p \"$COMPANION_DIR/.claude\" \"$COMPANION_DIR/.learnings\""
        print "        gate_blocked=0"
        print "        for d in \"${SYNC_DIRS[@]}\"; do"
        print "            if [[ -d \".claude/$d\" ]]; then"
        print "                mkdir -p \"$COMPANION_DIR/.claude/$d\""
        print "                mirror_delete \".claude/$d\" \"$COMPANION_DIR/.claude/$d\" \"$FORCE_MODE\" || {"
        print "                    rc=$?"
        print "                    if [[ $rc -eq 2 ]]; then"
        print "                        gate_blocked=1"
        print "                        printf '"'"'  [gate] .claude/%s: stale files NOT removed — run with --force to override\\n'"'"' \"$d\" >&2"
        print "                    else"
        print "                        printf '"'"'mirror_delete failed for .claude/%s (exit %d)\\n'"'"' \"$d\" \"$rc\" >&2"
        print "                        exit 1"
        print "                    fi"
        print "                }"
        print "                cp -r \".claude/$d/.\" \"$COMPANION_DIR/.claude/$d/\""
        print "            fi"
        print "        done"
        print "        if [[ -f \".claude/settings.json\" ]]; then"
        print "            cp \".claude/settings.json\" \"$COMPANION_DIR/.claude/settings.json\""
        print "        fi"
        print "        if [[ -f \"CLAUDE.md\" ]]; then"
        print "            cp \"CLAUDE.md\" \"$COMPANION_DIR/CLAUDE.md\""
        print "        fi"
        print "        if [[ -f \".learnings/log.md\" ]]; then"
        print "            cp \".learnings/log.md\" \"$COMPANION_DIR/.learnings/log.md\""
        print "        fi"
        print "        if [[ $gate_blocked -eq 1 ]]; then"
        print "            printf '"'"'\\nWARN: safety gate blocked deletion in one or more dirs. Companion may contain stale files.\\n'"'"'"
        print "            printf '"'"'To force removal: bash .claude/scripts/sync-config.sh export --force\\n'"'"'"
        print "            printf '"'"'To rebuild from scratch: bash .claude/scripts/sync-config.sh reset\\n'"'"'"
        print "        else"
        print "            printf '"'"'Exported %s to %s\\n'"'"' \"$PROJECT_NAME\" \"$COMPANION_DIR\""
        print "        fi"
        print "        ;;"
        in_export = 1
        next
      }
      in_export == 1 && /^[[:space:]]*;;[[:space:]]*$/ {
        in_export = 0
        skipped = 1
        next
      }
      in_export == 1 { next }
      { print }
    ' "$SCRIPT" > "${SCRIPT}.tmp" && mv "${SCRIPT}.tmp" "$SCRIPT"
    printf 'PATCHED: FIX1.3 export case replaced\n'
  fi

  # ---- FIX1.4 — reset case insertion ----
  # Insert a new "reset)" case block BEFORE the "*)" default case.
  if grep -q '^[[:space:]]*reset)' "$SCRIPT"; then
    printf 'SKIP: FIX1.4 reset case already present\n'
  elif ! grep -q '^[[:space:]]*\*)' "$SCRIPT"; then
    printf 'SKIP: FIX1.4 default "*)" case not found\n'
  else
    awk '
      BEGIN { inserted = 0 }
      /^[[:space:]]*\*\)/ && inserted == 0 {
        print "    reset)"
        print "        abort_if_nested"
        print "        printf '"'"'Resetting companion for %s — this will delete all companion files and rebuild from scratch.\\n'"'"' \"$PROJECT_NAME\""
        print "        printf '"'"'Companion dir: %s\\n'"'"' \"$COMPANION_DIR\""
        print "        printf '"'"'Press Ctrl-C within 5 seconds to cancel...\\n'"'"'"
        print "        sleep 5"
        print "        rm -rf \"$COMPANION_DIR/.claude\""
        print "        rm -rf \"$COMPANION_DIR/.learnings\""
        print "        mkdir -p \"$COMPANION_DIR/.claude\" \"$COMPANION_DIR/.learnings\""
        print "        for d in \"${SYNC_DIRS[@]}\"; do"
        print "            if [[ -d \".claude/$d\" ]]; then"
        print "                mkdir -p \"$COMPANION_DIR/.claude/$d\""
        print "                cp -r \".claude/$d/.\" \"$COMPANION_DIR/.claude/$d/\""
        print "            fi"
        print "        done"
        print "        if [[ -f \".claude/settings.json\" ]]; then"
        print "            cp \".claude/settings.json\" \"$COMPANION_DIR/.claude/settings.json\""
        print "        fi"
        print "        if [[ -f \"CLAUDE.md\" ]]; then"
        print "            cp \"CLAUDE.md\" \"$COMPANION_DIR/CLAUDE.md\""
        print "        fi"
        print "        if [[ -f \".learnings/log.md\" ]]; then"
        print "            cp \".learnings/log.md\" \"$COMPANION_DIR/.learnings/log.md\""
        print "        fi"
        print "        printf '"'"'Reset complete. Exported %s to %s\\n'"'"' \"$PROJECT_NAME\" \"$COMPANION_DIR\""
        print "        ;;"
        inserted = 1
      }
      { print }
    ' "$SCRIPT" > "${SCRIPT}.tmp" && mv "${SCRIPT}.tmp" "$SCRIPT"
    printf 'PATCHED: FIX1.4 reset case inserted\n'
  fi

  # ---- FIX1.5 — status case three-category classification ----
  # Replace the block between "status)" and the next ";;" with a three-category
  # grep on a single captured diff output. Produces new/diff/stale counts.
  if grep -q 'total_stale' "$SCRIPT"; then
    printf 'SKIP: FIX1.5 status case already patched\n'
  elif ! grep -q '^[[:space:]]*status)' "$SCRIPT"; then
    printf 'SKIP: FIX1.5 anchor "status)" not found\n'
  else
    awk '
      BEGIN { in_status = 0; skipped = 0 }
      /^[[:space:]]*status\)/ && in_status == 0 && skipped == 0 {
        print "    status)"
        print "        abort_if_nested"
        print "        [[ -d \"$COMPANION_DIR\" ]] || { printf '"'"'No companion at %s\\n'"'"' \"$COMPANION_DIR\"; exit 0; }"
        print "        printf '"'"'Companion: %s\\n'"'"' \"$COMPANION_DIR\""
        print "        total_diff=0"
        print "        total_stale=0"
        print "        total_new=0"
        print "        for d in \"${SYNC_DIRS[@]}\"; do"
        print "            if [[ -d \".claude/$d\" ]] && [[ -d \"$COMPANION_DIR/.claude/$d\" ]]; then"
        print "                # Capture raw diff output once; filter Common subdirectories lines explicitly"
        print "                raw_diff=$({ diff -rq \".claude/$d\" \"$COMPANION_DIR/.claude/$d\" 2>/dev/null || true; })"
        print "                new_count=$(printf '"'"'%s\\n'"'"' \"$raw_diff\" | grep -c \"^Only in \\.claude/$d\" || true)"
        print "                stale_count=$(printf '"'"'%s\\n'"'"' \"$raw_diff\" | grep -c \"^Only in $COMPANION_DIR\" || true)"
        print "                diff_count=$(printf '"'"'%s\\n'"'"' \"$raw_diff\" | grep -c \"^Files \" || true)"
        print "                printf '"'"'  %-12s %s diff, %s stale, %s new\\n'"'"' \"$d\" \"$diff_count\" \"$stale_count\" \"$new_count\""
        print "                total_diff=$((total_diff + diff_count))"
        print "                total_stale=$((total_stale + stale_count))"
        print "                total_new=$((total_new + new_count))"
        print "            elif [[ -d \".claude/$d\" ]]; then"
        print "                only_count=$(find \".claude/$d\" -type f 2>/dev/null | wc -l | tr -d '"'"' '"'"')"
        print "                printf '"'"'  %-12s (project only: %s files)\\n'"'"' \"$d\" \"$only_count\""
        print "                total_new=$((total_new + only_count))"
        print "            elif [[ -d \"$COMPANION_DIR/.claude/$d\" ]]; then"
        print "                only_count=$(find \"$COMPANION_DIR/.claude/$d\" -type f 2>/dev/null | wc -l | tr -d '"'"' '"'"')"
        print "                printf '"'"'  %-12s (companion only: %s files)\\n'"'"' \"$d\" \"$only_count\""
        print "                total_stale=$((total_stale + only_count))"
        print "            fi"
        print "        done"
        print "        printf '"'"'Total: %s diff, %s stale, %s new\\n'"'"' \"$total_diff\" \"$total_stale\" \"$total_new\""
        print "        [[ $total_stale -gt 0 ]] && printf '"'"'To prune stale files: /sync export --prune\\n'"'"'"
        print "        ;;"
        in_status = 1
        next
      }
      in_status == 1 && /^[[:space:]]*;;[[:space:]]*$/ {
        in_status = 0
        skipped = 1
        next
      }
      in_status == 1 { next }
      { print }
    ' "$SCRIPT" > "${SCRIPT}.tmp" && mv "${SCRIPT}.tmp" "$SCRIPT"
    printf 'PATCHED: FIX1.5 status case replaced\n'
  fi

  # ---- FIX1.6 — USAGE line ----
  if grep -q 'export \[--force\]' "$SCRIPT"; then
    printf 'SKIP: FIX1.6 USAGE already updated\n'
  else
    sed -i.bak "s|USAGE: bash .claude/scripts/sync-config.sh \[[^]]*\]|USAGE: bash .claude/scripts/sync-config.sh [init\|export [--force]\|import\|status\|push\|pull\|reset]|" "$SCRIPT" || true
    rm -f "${SCRIPT}.bak"
    if grep -q 'export \[--force\]' "$SCRIPT"; then
      printf 'PATCHED: FIX1.6 USAGE updated\n'
    else
      printf 'WARN: FIX1.6 USAGE pattern not found — inspect %s manually\n' "$SCRIPT"
    fi
  fi

  # ---- FIX1.7 — bash -n syntax check ----
  if bash -n "$SCRIPT" 2>/dev/null; then
    printf 'PASS: %s bash -n syntax OK\n' "$SCRIPT"
  else
    printf 'FAIL: %s bash -n syntax error after FIX1 — aborting migration\n' "$SCRIPT" >&2
    bash -n "$SCRIPT" || true
    exit 1
  fi
fi
```

---

### FIX2 — sync-companion.sh (Stop hook)

Target: `.claude/hooks/sync-companion.sh`. Three sub-patches: (1) rsync `--exclude='settings.local.json'`, (2) cp-r fallback replaced with nuke-and-repave block, (3) `CLAUDE.local.md` copy line removed. Escape hatch `FIX2_SKIP` if anchor not found.

```bash
HOOK=".claude/hooks/sync-companion.sh"

if [[ ! -f "$HOOK" ]]; then
  printf 'SKIP: %s not found (git_strategy != companion)\n' "$HOOK"
else
  printf '== FIX2: patching %s ==\n' "$HOOK"

  # Anchor check — if the cp -r fallback anchor is not found, the hook layout
  # has drifted from the upstream template. Print FIX2_SKIP and continue.
  if ! grep -q 'cp -r "\$PROJECT_ROOT/.claude/"\*' "$HOOK"; then
    printf 'FIX2_SKIP: anchor not found in sync-companion.sh — manual patch required.\n'
    printf '           Replace cp -r fallback block with the nuke-and-repave block\n'
    printf '           shown in the migration footer. Run migration 020 again after\n'
    printf '           the manual patch is applied. All other FIX sections still run.\n'
  else
    # ---- FIX2.1 — rsync exclude settings.local.json ----
    if grep -q "exclude='settings.local.json'" "$HOOK"; then
      printf 'SKIP: FIX2.1 rsync --exclude already present\n'
    else
      sed -i.bak "s|rsync -a --delete --exclude='.git'|rsync -a --delete --exclude='.git' --exclude='settings.local.json'|" "$HOOK"
      rm -f "${HOOK}.bak"
      if grep -q "exclude='settings.local.json'" "$HOOK"; then
        printf 'PATCHED: FIX2.1 rsync --exclude settings.local.json\n'
      else
        printf 'WARN: FIX2.1 rsync anchor not matched — check %s manually\n' "$HOOK"
      fi
    fi

    # ---- FIX2.2 — cp -r fallback replaced with nuke-and-repave block ----
    if grep -q 'nuke-and-repave\|rm -rf "\${COMPANION:?}/.claude/"' "$HOOK"; then
      printf 'SKIP: FIX2.2 nuke-and-repave block already present\n'
    else
      awk '
        BEGIN { in_else = 0; done = 0 }
        /^[[:space:]]*else[[:space:]]*$/ && done == 0 {
          in_else = 1
          print
          print "  # Nuke-and-repave: wipe companion .claude/, repave from project."
          print "  # rm -rf targets $COMPANION/.claude/ — cannot reach $COMPANION_ROOT/.git (two levels above)."
          print "  # cp -r with trailing /. copies dotfiles (unlike /* glob which misses them)."
          print "  rm -rf \"${COMPANION:?}/.claude/\""
          print "  mkdir -p \"$COMPANION/.claude\""
          print "  cp -r \"$PROJECT_ROOT/.claude/.\" \"$COMPANION/.claude/\""
          print "  # settings.local.json is machine-specific (modules/09 DO NOT SYNC). Remove if copied."
          print "  rm -f \"$COMPANION/.claude/settings.local.json\" 2>/dev/null || true"
          print ""
          print "  if [[ -d \"$PROJECT_ROOT/.learnings\" ]]; then"
          print "    rm -rf \"${COMPANION:?}/.learnings/\""
          print "    mkdir -p \"$COMPANION/.learnings\""
          print "    cp -r \"$PROJECT_ROOT/.learnings/.\" \"$COMPANION/.learnings/\""
          print "  fi"
          next
        }
        in_else == 1 && /^[[:space:]]*fi[[:space:]]*$/ {
          print
          in_else = 0
          done = 1
          next
        }
        in_else == 1 { next }
        { print }
      ' "$HOOK" > "${HOOK}.tmp" && mv "${HOOK}.tmp" "$HOOK"
      printf 'PATCHED: FIX2.2 cp -r fallback replaced with nuke-and-repave\n'
    fi

    # ---- FIX2.3 — remove CLAUDE.local.md copy line ----
    if grep -q 'CLAUDE.local.md: machine-specific' "$HOOK" || ! grep -q 'cp "\$PROJECT_ROOT/CLAUDE.local.md"' "$HOOK"; then
      printf 'SKIP: FIX2.3 CLAUDE.local.md already removed\n'
    else
      sed -i.bak '\|cp "\$PROJECT_ROOT/CLAUDE.local.md"|c\
# CLAUDE.local.md: machine-specific, in DO NOT SYNC (modules/09) — never copy to companion' "$HOOK"
      rm -f "${HOOK}.bak"
      printf 'PATCHED: FIX2.3 CLAUDE.local.md copy removed\n'
    fi

    # ---- FIX2.4 — bash -n syntax check ----
    if bash -n "$HOOK" 2>/dev/null; then
      printf 'PASS: %s bash -n syntax OK\n' "$HOOK"
    else
      printf 'FAIL: %s bash -n syntax error after FIX2 — aborting migration\n' "$HOOK" >&2
      bash -n "$HOOK" || true
      exit 1
    fi
  fi
fi
```

---

### FIX3 — detect-env.sh (SessionStart hook)

Target: `.claude/hooks/detect-env.sh`. Replace the wholesale `cp -r "$COMPANION_DIR/.claude/"*` block with an explicit per-`SYNC_DIR` additive restore loop that only touches dirs the project lacks, guards `settings.json` and `.learnings/` individually, and never restores `CLAUDE.local.md`.

```bash
HOOK=".claude/hooks/detect-env.sh"

if [[ ! -f "$HOOK" ]]; then
  printf 'SKIP: %s not found\n' "$HOOK"
else
  printf '== FIX3: patching %s ==\n' "$HOOK"

  if grep -q 'CLAUDE.local.md: NEVER restored' "$HOOK"; then
    printf 'SKIP: FIX3 per-SYNC_DIR additive restore loop already present\n'
  elif ! grep -q 'cp -r "\$COMPANION_DIR/.claude/"\*' "$HOOK"; then
    printf 'SKIP: FIX3 anchor cp -r "$COMPANION_DIR/.claude/"* not found — already patched or drift\n'
  else
    # Replace the block starting at the anchor line through the end of the
    # companion-import if-block. The original block is roughly:
    #     cp -r "$COMPANION_DIR/.claude/"* "$PROJECT_DIR/.claude/" 2>/dev/null || true
    #     [[ -d "$COMPANION_DIR/.learnings" ]] && cp -r "$COMPANION_DIR/.learnings" "$PROJECT_DIR/" 2>/dev/null || true
    #     [[ -f "$COMPANION_DIR/CLAUDE.md" ]] && cp "$COMPANION_DIR/CLAUDE.md" "$PROJECT_DIR/" 2>/dev/null || true
    #     [[ -f "$COMPANION_DIR/CLAUDE.local.md" ]] && cp "$COMPANION_DIR/CLAUDE.local.md" "$PROJECT_DIR/" 2>/dev/null || true
    # Replace with explicit per-SYNC_DIR additive restore + per-file guards.
    awk '
      BEGIN { in_block = 0; done = 0 }
      /cp -r "\$COMPANION_DIR\/\.claude\/"\*/ && done == 0 {
        in_block = 1
        print "      # Per-SYNC_DIR additive restore: only copy dirs the project lacks."
        print "      # Matches SYNC_DIRS scope from modules/09. CLAUDE.local.md: NEVER restored — machine-specific."
        print "      for d in rules skills agents hooks scripts specs references; do"
        print "        if [[ -d \"$COMPANION_DIR/.claude/$d\" ]] && [[ ! -d \"$PROJECT_DIR/.claude/$d\" ]]; then"
        print "          mkdir -p \"$PROJECT_DIR/.claude/$d\""
        print "          cp -r \"$COMPANION_DIR/.claude/$d/.\" \"$PROJECT_DIR/.claude/$d/\""
        print "        fi"
        print "      done"
        print "      # Copy settings.json if missing (never settings.local.json)"
        print "      if [[ -f \"$COMPANION_DIR/.claude/settings.json\" ]] && [[ ! -f \"$PROJECT_DIR/.claude/settings.json\" ]]; then"
        print "        cp \"$COMPANION_DIR/.claude/settings.json\" \"$PROJECT_DIR/.claude/settings.json\""
        print "      fi"
        print "      # Copy .learnings/ directory if missing"
        print "      if [[ -d \"$COMPANION_DIR/.learnings\" ]] && [[ ! -d \"$PROJECT_DIR/.learnings\" ]]; then"
        print "        cp -r \"$COMPANION_DIR/.learnings\" \"$PROJECT_DIR/\""
        print "      fi"
        print "      # Copy CLAUDE.md if missing (NEVER CLAUDE.local.md — machine-specific)"
        print "      if [[ -f \"$COMPANION_DIR/CLAUDE.md\" ]] && [[ ! -f \"$PROJECT_DIR/CLAUDE.md\" ]]; then"
        print "        cp \"$COMPANION_DIR/CLAUDE.md\" \"$PROJECT_DIR/\""
        print "      fi"
        next
      }
      in_block == 1 && /CLAUDE\.local\.md/ {
        # Skip the CLAUDE.local.md copy line entirely
        in_block = 0
        done = 1
        next
      }
      in_block == 1 { next }
      { print }
    ' "$HOOK" > "${HOOK}.tmp" && mv "${HOOK}.tmp" "$HOOK"
    printf 'PATCHED: FIX3 per-SYNC_DIR additive restore loop inserted\n'
  fi

  # ---- FIX3 bash -n syntax check ----
  if bash -n "$HOOK" 2>/dev/null; then
    printf 'PASS: %s bash -n syntax OK\n' "$HOOK"
  else
    printf 'FAIL: %s bash -n syntax error after FIX3 — aborting migration\n' "$HOOK" >&2
    bash -n "$HOOK" || true
    exit 1
  fi
fi
```

---

### FIX4 — SKILL.md (sync skill)

Target: `.claude/skills/sync/SKILL.md`. Two sub-patches: (1) `argument-hint` frontmatter via awk (sed forbidden — `|` delimiter collision), (2) `status` description via sed.

```bash
SKILL=".claude/skills/sync/SKILL.md"

if [[ ! -f "$SKILL" ]]; then
  printf 'SKIP: %s not found (git_strategy != companion)\n' "$SKILL"
else
  printf '== FIX4: patching %s ==\n' "$SKILL"

  # ---- FIX4.1 — argument-hint (awk only; | delimiter collision rules out sed) ----
  if grep -q 'export \[--prune\]' "$SKILL"; then
    printf 'SKIP: FIX4.1 argument-hint already patched\n'
  else
    awk '
      /argument-hint:.*push.*pull.*status.*export.*import/ {
        print "argument-hint: \"[push|pull|status|export [--prune]|import]\""
        next
      }
      { print }
    ' "$SKILL" > "${SKILL}.tmp" && mv "${SKILL}.tmp" "$SKILL"
    if grep -q 'export \[--prune\]' "$SKILL"; then
      printf 'PATCHED: FIX4.1 argument-hint updated\n'
    else
      printf 'WARN: FIX4.1 argument-hint pattern not matched — inspect %s manually\n' "$SKILL"
    fi
  fi

  # ---- FIX4.2 — status description (sed; pattern is unique and has no | ) ----
  if grep -q 'three categories\|NEW.*DIFF.*STALE' "$SKILL"; then
    printf 'SKIP: FIX4.2 status description already patched\n'
  else
    sed -i.bak 's|- status: show sync state.*|- status: show per-directory sync state — three categories: NEW (project-only), DIFF (content differs), STALE (companion-only). Appends prune hint when STALE > 0|' "$SKILL"
    rm -f "${SKILL}.bak"
    if grep -q 'three categories' "$SKILL"; then
      printf 'PATCHED: FIX4.2 status description updated\n'
    else
      printf 'WARN: FIX4.2 status description pattern not matched — inspect %s manually\n' "$SKILL"
    fi
  fi

  # No bash -n on SKILL.md — it is markdown, not a shell script.
fi
```

---

### FIX5 — Bootstrap self-check (runs only in bootstrap repo)

If the migration is running inside the bootstrap repo itself (detected by presence of `modules/06-skills.md`), verify the module source-of-truth is aligned with the patches above. This catches drift between client-side migrations and server-side templates.

```bash
if [[ -f "modules/06-skills.md" ]]; then
  printf '== FIX5: bootstrap self-check ==\n'
  drift_n=0
  if grep -q 'three categories\|NEW.*DIFF.*STALE' modules/06-skills.md; then
    printf 'PASS: modules/06-skills.md contains three-category status description\n'
  else
    printf 'FAIL: modules/06-skills.md does NOT mention three-category status — module template drift. Update modules/06-skills.md Dispatch 07 to match the sync SKILL.md description patched in FIX4.2.\n' >&2
    drift_n=$((drift_n + 1))
  fi
  if [[ -f "modules/09-companion.md" ]]; then
    if grep -q 'mirror_delete\|--force\|reset' modules/09-companion.md; then
      printf 'PASS: modules/09-companion.md references mirror_delete / --force / reset\n'
    else
      printf 'FAIL: modules/09-companion.md does NOT reference the new sync-config.sh features — module template drift. Rewrite modules/09-companion.md Step 1 (code-writer-bash dispatch spec) to include _POSITIONAL pre-parse, mirror_delete helper, --force safety gate, reset subcommand, and three-category status.\n' >&2
      drift_n=$((drift_n + 1))
    fi
  fi
  if [[ "$drift_n" -gt 0 ]]; then
    printf 'FIX5: %d module template drift(s) detected — bootstrap regeneration would revert migration 020. Fix modules/ before running /module-write.\n' "$drift_n" >&2
    exit 1
  fi
  printf 'FIX5: bootstrap self-check PASS\n'
else
  printf 'SKIP: FIX5 bootstrap self-check (not running in bootstrap repo)\n'
fi
```

---

## Verify

```bash
set -euo pipefail

PASS=0
FAIL=0

check() {
  local label="$1"
  local cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    printf 'PASS: %s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf 'FAIL: %s\n' "$label" >&2
    FAIL=$((FAIL + 1))
  fi
}

# FIX1 checks — sync-config.sh
if [[ -f .claude/scripts/sync-config.sh ]]; then
  check "sync-config.sh has _POSITIONAL pre-parse"         "grep -q '_POSITIONAL'      .claude/scripts/sync-config.sh"
  check "sync-config.sh has mirror_delete helper"          "grep -q 'mirror_delete'    .claude/scripts/sync-config.sh"
  check "sync-config.sh has reset case"                    "grep -q '^[[:space:]]*reset)' .claude/scripts/sync-config.sh"
  check "sync-config.sh has three-category status"         "grep -q 'total_stale'      .claude/scripts/sync-config.sh"
  check "sync-config.sh USAGE mentions --force"            "grep -q 'export \[--force\]' .claude/scripts/sync-config.sh"
  check "sync-config.sh bash -n clean"                     "bash -n .claude/scripts/sync-config.sh"
fi

# FIX2 checks — sync-companion.sh (only if anchor was found / patch applied)
if [[ -f .claude/hooks/sync-companion.sh ]]; then
  if grep -q "exclude='settings.local.json'" .claude/hooks/sync-companion.sh; then
    check "sync-companion.sh rsync excludes settings.local.json" "grep -q \"exclude='settings.local.json'\" .claude/hooks/sync-companion.sh"
    check "sync-companion.sh has nuke-and-repave cp-r fallback"  "grep -q 'nuke-and-repave\\|rm -rf \"\${COMPANION:?}/.claude/\"' .claude/hooks/sync-companion.sh"
    check "sync-companion.sh does NOT copy CLAUDE.local.md"      "! grep -q 'cp \"\$PROJECT_ROOT/CLAUDE.local.md\"' .claude/hooks/sync-companion.sh"
    check "sync-companion.sh bash -n clean"                      "bash -n .claude/hooks/sync-companion.sh"
  else
    printf 'NOTE: FIX2 was skipped (FIX2_SKIP anchor miss) — manual patch required before this migration completes.\n'
  fi
fi

# FIX3 checks — detect-env.sh
if [[ -f .claude/hooks/detect-env.sh ]]; then
  check "detect-env.sh has per-SYNC_DIR additive restore" "grep -q 'CLAUDE.local.md: NEVER restored' .claude/hooks/detect-env.sh"
  check "detect-env.sh does NOT wholesale cp \\.claude/*" "! grep -q 'cp -r \"\$COMPANION_DIR/.claude/\"\\*' .claude/hooks/detect-env.sh"
  check "detect-env.sh bash -n clean"                     "bash -n .claude/hooks/detect-env.sh"
fi

# FIX4 checks — SKILL.md
if [[ -f .claude/skills/sync/SKILL.md ]]; then
  check "sync SKILL.md argument-hint updated"  "grep -q 'export \[--prune\]' .claude/skills/sync/SKILL.md"
  check "sync SKILL.md status description updated" "grep -q 'three categories' .claude/skills/sync/SKILL.md"
fi

printf '\nSummary: %d PASS, %d FAIL\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || { printf 'Migration 020 verify FAILED\n' >&2; exit 1; }
printf 'PASS: migration 020 verified\n'
```

Failure of any verify step → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after fixing the reported failure(s).

---

## Required: register in migrations/index.json

```json
{
  "id": "020",
  "file": "020-companion-sync-fix.md",
  "description": "Companion repo sync deletion semantics fix — mirror_delete + --force/reset in sync-config.sh, settings.local.json exclusion + nuke-and-repave fallback in sync-companion.sh, per-SYNC_DIR additive restore in detect-env.sh, three-category status + argument-hint update in sync SKILL.md.",
  "breaking": false
}
```

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → "020"
- append `{ "id": "020", "applied_at": "{ISO8601}", "description": "companion repo sync deletion semantics fix — mirror_delete + --force/reset + three-category status + settings.local.json/CLAUDE.local.md exclusion" }` to `applied[]`

---

## Rollback

Each patched file has a numbered sentinel in this migration. Full rollback requires reverting the source of truth (`modules/06-skills.md`, `modules/09-companion.md`, `modules/03-hooks.md`) and re-running full bootstrap. Partial rollback (single fix):

- FIX1 (`sync-config.sh`) → git checkout the prior version of `.claude/scripts/sync-config.sh` from before migration 020.
- FIX2 (`sync-companion.sh`) → git checkout the prior version of `.claude/hooks/sync-companion.sh`.
- FIX3 (`detect-env.sh`) → git checkout the prior version of `.claude/hooks/detect-env.sh` (or fall back to migration 019's bulletproof version, then re-apply FIX3 from this migration).
- FIX4 (`SKILL.md`) → git checkout the prior version of `.claude/skills/sync/SKILL.md`.

Note: rolling back reintroduces the stale-file accumulation, settings.local.json leakage, and wholesale-clobber auto-import bugs. The preferred recovery path is to fix-forward by patching the failing spot and re-running `/migrate-bootstrap`.

---

## Post-migration notes

After this migration applies successfully:

1. **Prune accumulated stale files on the companion** — run once per project that had companion sync enabled before migration 020:
   ```bash
   bash .claude/scripts/sync-config.sh export --force
   ```
   The `--force` flag bypasses the 50% safety gate, which would otherwise refuse to delete the stale files that accumulated across previous bootstrap versions.

2. **If the companion is wildly out of sync** (e.g. major refactor, large file renames, many deleted skills), use the new `reset` action to wipe and rebuild:
   ```bash
   bash .claude/scripts/sync-config.sh reset
   ```
   This prints a 5-second abort countdown before deleting the companion and repaving from the project. Use this when `--force` would fire the 50% gate but you know the deletions are intentional.

3. **If FIX2 printed `FIX2_SKIP`** (the `sync-companion.sh` anchor drifted), manually replace the `cp -r "$PROJECT_ROOT/.claude/"*` fallback block with:

   ```bash
   else
     # Nuke-and-repave: wipe companion .claude/, repave from project.
     rm -rf "${COMPANION:?}/.claude/"
     mkdir -p "$COMPANION/.claude"
     cp -r "$PROJECT_ROOT/.claude/." "$COMPANION/.claude/"
     rm -f "$COMPANION/.claude/settings.local.json" 2>/dev/null || true

     if [[ -d "$PROJECT_ROOT/.learnings" ]]; then
       rm -rf "${COMPANION:?}/.learnings/"
       mkdir -p "$COMPANION/.learnings"
       cp -r "$PROJECT_ROOT/.learnings/." "$COMPANION/.learnings/"
     fi
   fi
   ```

   And delete the `cp "$PROJECT_ROOT/CLAUDE.local.md"` line entirely. Re-run `/migrate-bootstrap` afterwards.

4. **Check for leaked machine-specific files on the companion** — these should no longer exist after migration 020 + a clean `--force` export:
   ```bash
   ls -la "$HOME/.claude-configs/$(basename "$(pwd)")/.claude/settings.local.json" 2>/dev/null && echo "WARN: settings.local.json still on companion — prune manually"
   ls -la "$HOME/.claude-configs/$(basename "$(pwd)")/CLAUDE.local.md"             2>/dev/null && echo "WARN: CLAUDE.local.md still on companion — prune manually"
   ```

---

## Rules for migration scripts

- **Read-before-write** — every FIX section greps for an anchor BEFORE editing; skips the edit if already patched.
- **Idempotent** — every sub-patch guarded by `grep -q` sentinel; run twice → identical final state.
- **Self-contained** — all bash content inlined verbatim; no remote fetch, no reference to gitignored paths.
- **Pure bash/sed/awk** — zero Python3 dependency; every `sed -i` uses the explicit `.bak` + cleanup pattern for MINGW64 git bash compatibility; no process substitution; `awk` is used wherever a pattern would collide with sed delimiters.
- **Syntax-checked** — every patched shell script is validated with `bash -n` after patching; migration aborts on syntax regression.
- **FIX2_SKIP escape hatch** — the one file with historically drifting anchors (`sync-companion.sh`) has an explicit SKIP path that prints a manual-patch recipe and continues, rather than hard-failing the migration.
- **Scope-locked** — only writes to `.claude/scripts/sync-config.sh`, `.claude/hooks/sync-companion.sh`, `.claude/hooks/detect-env.sh`, `.claude/skills/sync/SKILL.md`. Does NOT touch any other file.
