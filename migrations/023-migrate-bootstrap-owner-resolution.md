# Migration 023 — /migrate-bootstrap owner resolution

> Patches `.claude/skills/migrate-bootstrap/SKILL.md` so fork users can target their own repo. Resolves the `{owner}/{repo}` slug from `BOOTSTRAP_REPO` env var → `.claude/bootstrap-state.json` `bootstrap_repo` field → canonical `tomasfil/claude-bootstrap` default, instead of hardcoding the canonical slug. Purely additive + idempotent.

---

## Metadata

```yaml
id: "023"
breaking: false
affects: [skills]
requires_mcp_json: false
min_bootstrap_version: "6.0"
base_commit: HEAD
```

---

## Problem

Prior to this migration `templates/skills/migrate-bootstrap/SKILL.md` (and the installed client-project copy) hardcoded `tomasfil/claude-bootstrap` in every `gh api repos/...` and `raw.githubusercontent.com/...` URL. A fork that maintains its own migration track had no way to point `/migrate-bootstrap` at the fork — the skill would always fetch from the canonical repo regardless of the forker's actual source of truth.

The `bootstrap_repo` field already exists in `.claude/bootstrap-state.json` (set during initial bootstrap) but the `/migrate-bootstrap` skill ignored it. This migration wires the skill to read that field.

This is part of the broader CRITICAL-01 finding from the P2/P3 code review — owner resolution must be explicit, never hardcoded, in any template or module that fetches bootstrap content.

---

## Changes

- **One file touched**: `.claude/skills/migrate-bootstrap/SKILL.md`.
- Adds a new `Step 0: Resolve bootstrap source repo` section that exports `BOOTSTRAP_REPO` with the precedence chain env var → state file → canonical default.
- Rewrites every hardcoded `tomasfil/claude-bootstrap` URL inside Steps 2 and 4 to use `${BOOTSTRAP_REPO}`.
- Adds `github_username` to the retrofit-detection bootstrap-state.json template so fresh retrofits pick up the field Modules 05/06/07 now read.

No rules, no migrations, no other skills/agents, no settings, no hooks are modified.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

command -v gh >/dev/null 2>&1 || { printf 'ERROR: gh required\n' >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || {
  printf 'ERROR: sha256sum or shasum required\n' >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { printf 'ERROR: gh not authenticated — run gh auth login\n' >&2; exit 1; }

# Resolve bootstrap source (same precedence chain this migration patches into the skill).
BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-$(jq -r '.bootstrap_repo // "tomasfil/claude-bootstrap"' .claude/bootstrap-state.json 2>/dev/null || echo tomasfil/claude-bootstrap)}"
printf 'Using bootstrap repo: %s\n' "$BOOTSTRAP_REPO"
```

### Step 1 — Idempotency check

```bash
set -euo pipefail

TARGET=".claude/skills/migrate-bootstrap/SKILL.md"

if [[ ! -f "$TARGET" ]]; then
  printf 'ERROR: %s not found — /migrate-bootstrap skill is not installed; run /migrate-bootstrap 022 first\n' "$TARGET" >&2
  exit 1
fi

# Literal-string idempotency marker (NOT regex) — presence of this exact line means 023 already applied.
if grep -q '### Step 0: Resolve bootstrap source repo' "$TARGET"; then
  printf 'Migration 023 already applied (Step 0 present in %s) — skipping\n' "$TARGET"
  exit 0
fi
```

### Step 2 — Fetch updated template + overwrite

```bash
set -euo pipefail

TARGET=".claude/skills/migrate-bootstrap/SKILL.md"
SOURCE_PATH="templates/skills/migrate-bootstrap/SKILL.md"

# Fetch the updated template from the resolved bootstrap repo.
NEW_BODY="$(gh api "repos/${BOOTSTRAP_REPO}/contents/${SOURCE_PATH}?ref=main" --jq '.content' | base64 -d)"

# Verify the new body actually contains the Step 0 marker — guard against fetching an older commit.
if ! printf '%s' "$NEW_BODY" | grep -q '### Step 0: Resolve bootstrap source repo'; then
  printf 'ERROR: upstream %s does not contain Step 0 marker — not yet published at %s\n' "$SOURCE_PATH" "$BOOTSTRAP_REPO" >&2
  exit 1
fi

# Backup, then overwrite.
cp "$TARGET" "${TARGET}.bak-023"
printf '%s' "$NEW_BODY" > "$TARGET"

# Confirm the overwrite landed.
grep -q '### Step 0: Resolve bootstrap source repo' "$TARGET" || {
  printf 'ERROR: overwrite failed — %s still lacks the Step 0 marker\n' "$TARGET" >&2
  exit 1
}

printf 'Patched %s (backup: %s.bak-023)\n' "$TARGET" "$TARGET"
```

---

## Verify

```bash
set -euo pipefail

TARGET=".claude/skills/migrate-bootstrap/SKILL.md"

# 1. Step 0 resolution section present.
grep -q '### Step 0: Resolve bootstrap source repo' "$TARGET" || { printf 'FAIL: Step 0 section missing\n' >&2; exit 1; }

# 2. BOOTSTRAP_REPO variable reference present.
grep -q 'BOOTSTRAP_REPO="\${BOOTSTRAP_REPO:-' "$TARGET" || { printf 'FAIL: BOOTSTRAP_REPO assignment missing\n' >&2; exit 1; }

# 3. Zero hardcoded tomasfil/claude-bootstrap in gh api / raw.githubusercontent.com URLs.
# Only the retrofit JSON literal + canonical default fallback are allowed to contain the string.
#
# Tightened 2026-04-14 to match command-position usages only. The prior pattern
# 'gh api.*tomasfil/claude-bootstrap' false-positived on prose lines like
#   Every `gh api repos/<slug>/...` URL ... uses `${BOOTSTRAP_REPO}` in place of `tomasfil/claude-bootstrap`
# because both `gh api` (in the first code span) and `tomasfil/claude-bootstrap` (in the last code span)
# coexist on the same line. The fix: require the literal command form `gh api "repos/tomasfil/claude-bootstrap`
# (with the opening double-quote and the literal owner/repo after `repos/`), which cannot appear in prose
# that uses placeholder text like `repos/<slug>/` or `${BOOTSTRAP_REPO}`. Same treatment for raw.githubusercontent.com —
# require the https:// scheme prefix + literal owner, since prose references typically omit the scheme.
bad="$(grep -nE 'gh api "repos/tomasfil/claude-bootstrap|https://raw\.githubusercontent\.com/tomasfil/claude-bootstrap' "$TARGET" || true)"
if [[ -n "$bad" ]]; then
  printf 'FAIL: hardcoded tomasfil/claude-bootstrap in fetch URL:\n%s\n' "$bad" >&2
  exit 1
fi

# 4. github_username field added to retrofit JSON template.
grep -q '"github_username"' "$TARGET" || { printf 'FAIL: github_username missing from retrofit template\n' >&2; exit 1; }

printf 'PASS: migration 023 verified\n'
```

---

## Notes

- The backup `.claude/skills/migrate-bootstrap/SKILL.md.bak-023` is left in place after a successful patch so users can diff before committing. Delete it manually or leave it for the next housekeeping pass.
- Clients who bootstrap-state.json does not contain `bootstrap_repo` fall through to the canonical default (`tomasfil/claude-bootstrap`) — no behavior change for non-forkers.
- Fork users: set `BOOTSTRAP_REPO=your-handle/claude-bootstrap` in your shell profile, or add `"bootstrap_repo": "your-handle/claude-bootstrap"` to `.claude/bootstrap-state.json`, before running `/migrate-bootstrap` so the skill fetches from your fork.
- This migration does NOT touch the manifest SHA for `migrate-bootstrap/SKILL.md` — that is handled by the next upstream commit which regenerates `templates/manifest.json` via `bash scripts/extract-templates.sh`. Clients that re-run the Module 06 fetch loop after this migration will sync the updated SHA automatically.
