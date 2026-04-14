# Migration 027 — Procedural effort=medium for verifier + consistency-checker, scope signal in /verify

> Apply workload-proportional effort scaling to procedural tool-use agents. Reclassifies `proj-verifier` and `proj-consistency-checker` from `effort: high` to `effort: medium` per the CLAUDE.md §Effort Scaling procedural carve-out, and patches `/verify` skill to compute a `git diff --stat HEAD` scope signal pre-dispatch and forward `Scope: {N} files — {SMALL|LARGE}` to both agents so they can calibrate report depth. Fetches updated templates from the bootstrap repo into client `.claude/`. Sentinel-guarded for idempotency. Self-contained — no inlined bodies; templates are the source of truth and are fetched live.

---

## Metadata

```yaml
id: "027"
breaking: false
affects: [agents, skills]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

Fields:
- `id`: `"027"`
- `breaking`: `false` — effort downgrade is workload-proportional, not capability-removing. Both agents continue to run the same checklist (Build → Tests → Cross-refs → Frontmatter for proj-verifier; Module numbering → YAML validity → Routing config → Checklist sync → Migrations index for proj-consistency-checker). The medium effort setting reduces self-correction loop depth for procedural tool-use work where there is no open-ended reasoning to thoroughness-pad. The new `Scope:` signal is purely additive — agents that ignore it continue to function as before.
- `affects`: `[agents, skills]` — touches `.claude/agents/proj-verifier.md`, `.claude/agents/proj-consistency-checker.md`, `.claude/skills/verify/SKILL.md`. No modules, hooks, settings, or techniques changed. (The CLAUDE.md §Effort Scaling reconciliation is a bootstrap-repo-only change — client `CLAUDE.md` is user-maintained, not templated, so no client-side action is required.)
- `requires_mcp_json`: `false` — effort + scope-signal changes are independent of MCP wiring.
- `min_bootstrap_version`: `"6.0"` — earliest bootstrap version with `proj-verifier`, `proj-consistency-checker`, and `/verify` skill installed.

---

## Problem

Three coupled deficiencies in the procedural-verification path:

1. **Effort over-allocation.** `proj-verifier` and `proj-consistency-checker` shipped with `effort: high`. Both agents execute deterministic checklists (read file → run command → diff output → write report) — there is no open-ended reasoning surface for the high-effort self-correction loop to improve. High effort on procedural tool-use work produces longer reports without meaningfully improving correctness, and consumes turn budget that should be available for the agents that actually need it (proj-code-writer-*, proj-debugger).

2. **Missing scope signal.** `/verify` dispatches both agents without any indication of changeset size. A 1-file typo fix and a 50-file refactor receive identical dispatch prompts. Without a scope signal, agents cannot calibrate report depth — they default to maximally-thorough output on every run, regardless of whether the changeset warrants it. Combined with the effort downgrade (item 1), agents need a way to scale up or down based on actual workload.

3. **CLAUDE.md §Effort Scaling block contradiction.** The previous rule was `Agents: always effort=high — medium produces noticeably worse output`, which forbids the carve-out by policy. The reconciliation establishes the procedural carve-out (procedural tool-use agents may use `effort: medium`) and adds the evidence base (SWE-bench Verified gap, GPQA Diamond gap, pricing). This is a bootstrap-repo-only change and is NOT part of this migration — client projects do not template CLAUDE.md.

Root cause: the v2.1.94 session default switched to `effort: high`. Frontmatter overrides on agent files are now load-bearing — without an explicit `effort: medium` declaration in the agent's own frontmatter, the session default wins. This migration installs the explicit overrides on procedural agents and adds the scope signal to the dispatch path so agents have the information needed to calibrate.

The CLAUDE.md §Effort Scaling procedural carve-out (bootstrap-repo edit, not migrated) authorizes this exception:
> Exception: procedural tool-use agents (checklist execution, read-check-diff, no open-ended reasoning) may use effort=medium per Anthropic agentic-coding guidance. Applies to: proj-verifier, proj-consistency-checker. Requires `# high:` or `# medium:` justification comment.

---

## Changes

- `.claude/agents/proj-verifier.md` (client project, OVERWRITE):
  - `effort: high` → `effort: medium`
  - Adds `# medium:` justification comment explaining the procedural tool-use rationale (Build → Tests → Cross-refs → Frontmatter checklist, no open-ended reasoning, Anthropic agentic-coding guidance, CLAUDE.md §Effort Scaling carve-out, v2.1.94 session default override is load-bearing).
  - Body unchanged in the bootstrap-repo template.
- `.claude/agents/proj-consistency-checker.md` (client project, OVERWRITE):
  - `effort: high` → `effort: medium`
  - Adds `# medium:` justification comment with the appropriate procedural task list (Module numbering → YAML validity → Routing config → Checklist sync → Migrations index).
  - Body unchanged in the bootstrap-repo template.
- `.claude/skills/verify/SKILL.md` (client project, OVERWRITE):
  - Phase 1 renamed `Build + Test verification` → `Scope + Build + Test verification`.
  - Phase 1 inserts a pre-dispatch scope-signal computation: `git diff --stat HEAD` (or PR base ref), file-count extraction, SMALL/LARGE classification (`SMALL if ≤5 files; LARGE if >5`), and a new `Scope: {N} files changed — {SMALL|LARGE}` line in the `proj-verifier` dispatch block.
  - Phase 2 dispatch block adds a parallel `Scope: {N} files changed — {SMALL|LARGE} (from Phase 1)` line for `proj-consistency-checker`.
  - All other Phase 1/2/3/4 text is preserved verbatim.

Idempotency: per-file sentinel guard. For the agent files, the sentinel is the literal string `effort: medium` in the file content — combined with `cmp -s` against the upstream tempfile this guarantees re-run produces zero modifications. For the SKILL.md, the sentinel is the literal string `git diff --stat HEAD` in the file content. Re-run skips with a `SKIP` log line and exits 0.

Bootstrap self-alignment: `templates/agents/proj-verifier.md`, `templates/agents/proj-consistency-checker.md`, and `templates/skills/verify/SKILL.md` were updated in the same change set (Phase C of the model-effort-selection plan). Fresh client-project bootstraps will install the procedural-effort agents and scope-aware /verify directly from the templates; this migration brings already-bootstrapped projects forward without a full refresh. The bootstrap repo's own installed `.claude/` copies are generated output — see Post-Apply note below.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }

command -v gh >/dev/null 2>&1 || { echo "ERROR: gh required for template fetch"; exit 1; }
command -v base64 >/dev/null 2>&1 || { echo "ERROR: base64 required"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "ERROR: gh not authenticated — run gh auth login"; exit 1; }

# Resolve bootstrap source (precedence: env var → state file → canonical default).
BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-$(jq -r '.bootstrap_repo // "tomasfil/claude-bootstrap"' .claude/bootstrap-state.json 2>/dev/null || echo tomasfil/claude-bootstrap)}"
printf 'Using bootstrap repo: %s\n' "$BOOTSTRAP_REPO"
```

---

### Step 1 — Fetch and install `proj-verifier` (effort: medium)

Fetch the updated `templates/agents/proj-verifier.md` from the bootstrap repo via `gh api`, verify the fetched body declares `effort: medium` (guard against fetching an older commit), then overwrite `.claude/agents/proj-verifier.md` in the client project. Idempotent: if the local file already declares `effort: medium` AND the upstream copy is byte-identical to the local copy, the step logs `SKIP` and exits 0.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/agents/proj-verifier.md"
SOURCE_PATH="templates/agents/proj-verifier.md"

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present — proj-verifier agent not installed in this project\n' "$TARGET"
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! gh api "repos/${BOOTSTRAP_REPO}/contents/${SOURCE_PATH}?ref=main" --jq '.content' 2>/dev/null | base64 -d > "$TMP"; then
  printf 'ERROR: gh fetch of %s failed\n' "$SOURCE_PATH" >&2
  exit 1
fi

if [[ ! -s "$TMP" ]]; then
  printf 'ERROR: fetched %s is empty\n' "$SOURCE_PATH" >&2
  exit 1
fi

# Guard: upstream MUST declare effort: medium (proves we fetched the post-Phase-C commit).
if ! grep -qF 'effort: medium' "$TMP"; then
  printf 'ERROR: upstream %s does not declare effort: medium — migration 027 not yet published at %s\n' "$SOURCE_PATH" "$BOOTSTRAP_REPO" >&2
  exit 1
fi

# Idempotency: if local already matches upstream byte-for-byte, skip.
if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date (matches upstream)\n' "$TARGET"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak-027"
mv "$TMP" "$TARGET"
trap - EXIT

if ! grep -qF 'effort: medium' "$TARGET"; then
  printf 'ERROR: overwrite failed — %s still does not declare effort: medium\n' "$TARGET" >&2
  exit 1
fi

printf 'PATCHED: %s (backup: %s.bak-027)\n' "$TARGET" "$TARGET"
```

---

### Step 2 — Fetch and install `proj-consistency-checker` (effort: medium)

Same pattern as Step 1, applied to `proj-consistency-checker`. Idempotent via `cmp -s` against the upstream tempfile.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/agents/proj-consistency-checker.md"
SOURCE_PATH="templates/agents/proj-consistency-checker.md"

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present — proj-consistency-checker agent not installed in this project\n' "$TARGET"
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! gh api "repos/${BOOTSTRAP_REPO}/contents/${SOURCE_PATH}?ref=main" --jq '.content' 2>/dev/null | base64 -d > "$TMP"; then
  printf 'ERROR: gh fetch of %s failed\n' "$SOURCE_PATH" >&2
  exit 1
fi

if [[ ! -s "$TMP" ]]; then
  printf 'ERROR: fetched %s is empty\n' "$SOURCE_PATH" >&2
  exit 1
fi

if ! grep -qF 'effort: medium' "$TMP"; then
  printf 'ERROR: upstream %s does not declare effort: medium — migration 027 not yet published at %s\n' "$SOURCE_PATH" "$BOOTSTRAP_REPO" >&2
  exit 1
fi

if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date (matches upstream)\n' "$TARGET"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak-027"
mv "$TMP" "$TARGET"
trap - EXIT

if ! grep -qF 'effort: medium' "$TARGET"; then
  printf 'ERROR: overwrite failed — %s still does not declare effort: medium\n' "$TARGET" >&2
  exit 1
fi

printf 'PATCHED: %s (backup: %s.bak-027)\n' "$TARGET" "$TARGET"
```

---

### Step 3 — Fetch and install `verify/SKILL.md` (scope signal)

Fetch the updated `templates/skills/verify/SKILL.md` from the bootstrap repo and overwrite `.claude/skills/verify/SKILL.md`. The fetched body MUST contain the literal string `git diff --stat HEAD` (proves we fetched the post-Phase-C commit). Idempotent via `cmp -s` against the upstream tempfile.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/skills/verify/SKILL.md"
SOURCE_PATH="templates/skills/verify/SKILL.md"

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present — /verify skill not installed in this project\n' "$TARGET"
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! gh api "repos/${BOOTSTRAP_REPO}/contents/${SOURCE_PATH}?ref=main" --jq '.content' 2>/dev/null | base64 -d > "$TMP"; then
  printf 'ERROR: gh fetch of %s failed\n' "$SOURCE_PATH" >&2
  exit 1
fi

if [[ ! -s "$TMP" ]]; then
  printf 'ERROR: fetched %s is empty\n' "$SOURCE_PATH" >&2
  exit 1
fi

# Guard: upstream MUST contain the scope-signal pre-dispatch step.
if ! grep -qF 'git diff --stat HEAD' "$TMP"; then
  printf 'ERROR: upstream %s does not contain the scope signal — migration 027 not yet published at %s\n' "$SOURCE_PATH" "$BOOTSTRAP_REPO" >&2
  exit 1
fi

if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date (matches upstream)\n' "$TARGET"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak-027"
mv "$TMP" "$TARGET"
trap - EXIT

if ! grep -qF 'git diff --stat HEAD' "$TARGET"; then
  printf 'ERROR: overwrite failed — %s still does not contain the scope signal\n' "$TARGET" >&2
  exit 1
fi

printf 'PATCHED: %s (backup: %s.bak-027)\n' "$TARGET" "$TARGET"
```

---

### Rules for migration scripts

- **Literal anchors only** — every `grep` / `cmp` check uses `grep -qF` (literal string) or byte comparison. No regex `.*` patterns.
- **Idempotent** — per-file `cmp -s` gate against the upstream tempfile. Re-run on an already-migrated project produces zero modifications.
- **Read-before-write** — fetch to tempfile, validate, compare, then overwrite via `mv`. No in-place edits. `.bak-027` backups left in place after a successful patch so users can diff before committing.
- **MINGW64-safe** — `mktemp` + `mv` only. No `sed -i`. No process substitution. No `readarray`.
- **Abort on error** — `set -euo pipefail` at the top of every step. Failed fetches, empty files, missing sentinels → explicit `exit 1` with a manual-patch message; partially patched files are never silently left behind.
- **Self-contained** — no inlined bodies. Templates are the source of truth and are fetched live from the bootstrap repo via `gh api`. Falls back to explicit error if `gh` is unavailable (no silent curl-fallback that could fetch from the wrong repo).

---

## Verify

```bash
#!/usr/bin/env bash
set -euo pipefail

FAIL=0

# 1. proj-verifier declares effort: medium
TARGET=".claude/agents/proj-verifier.md"
if [[ -f "$TARGET" ]]; then
  if grep -qF 'effort: medium' "$TARGET"; then
    echo "PASS: $TARGET declares effort: medium"
  else
    echo "FAIL: $TARGET does not declare effort: medium"
    FAIL=1
  fi
else
  echo "SKIP-VERIFY: $TARGET not present"
fi

# 2. proj-consistency-checker declares effort: medium
TARGET=".claude/agents/proj-consistency-checker.md"
if [[ -f "$TARGET" ]]; then
  if grep -qF 'effort: medium' "$TARGET"; then
    echo "PASS: $TARGET declares effort: medium"
  else
    echo "FAIL: $TARGET does not declare effort: medium"
    FAIL=1
  fi
else
  echo "SKIP-VERIFY: $TARGET not present"
fi

# 3. verify/SKILL.md contains the git diff --stat scope signal
TARGET=".claude/skills/verify/SKILL.md"
if [[ -f "$TARGET" ]]; then
  if grep -qF 'git diff --stat HEAD' "$TARGET"; then
    echo "PASS: $TARGET contains scope signal pre-dispatch"
  else
    echo "FAIL: $TARGET missing scope signal pre-dispatch"
    FAIL=1
  fi
else
  echo "SKIP-VERIFY: $TARGET not present"
fi

# 4. migrations/index.json contains the 027 entry
if grep -qF '"id": "027"' migrations/index.json; then
  echo "PASS: migrations/index.json contains 027 entry"
else
  echo "FAIL: migrations/index.json missing 027 entry"
  FAIL=1
fi

[[ $FAIL -eq 0 ]] || exit 1
```

Failure of any verify step → `/migrate-bootstrap` aborts and does NOT update `bootstrap-state.json`. Safe to retry after fixing.

---

## Post-Apply — Bootstrap Repo Self-Update

This migration targets client projects. The bootstrap repo's own `.claude/` copies are
generated output, not source of truth. To update the bootstrap repo's installed copies:
1. Run `/migrate-bootstrap` against the bootstrap repo itself, OR re-run Module 05
2. Do NOT directly edit `.claude/agents/proj-verifier.md`, `.claude/agents/proj-consistency-checker.md`,
   or `.claude/skills/verify/SKILL.md` in the bootstrap repo — direct edits bypass the template
   and create drift
Reference: `.claude/rules/general.md` §Process — "NEVER write to this repo's `.claude/`
as implementation work."

Note: the CLAUDE.md §Effort Scaling reconciliation (procedural carve-out + evidence base) is a
bootstrap-repo-only change and is NOT part of this migration. Client project `CLAUDE.md` files
are user-maintained, not templated, so no client-side action is required for the policy text.
The agent frontmatter overrides installed by Steps 1 and 2 are the load-bearing enforcement —
the CLAUDE.md text is documentation of the policy that authorizes them.

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → `"027"`
- append `{ "id": "027", "applied_at": "<ISO8601>", "description": "Procedural effort=medium for verifier + consistency-checker, scope signal in /verify" }` to `applied[]`

---

## Rollback

Reversible via `git restore` of the affected files in the client project (if the project tracks `.claude/agents/` and `.claude/skills/`). Otherwise: restore the `.bak-027` backups left by Steps 1, 2, and 3:

```bash
mv .claude/agents/proj-verifier.md.bak-027 .claude/agents/proj-verifier.md
mv .claude/agents/proj-consistency-checker.md.bak-027 .claude/agents/proj-consistency-checker.md
mv .claude/skills/verify/SKILL.md.bak-027 .claude/skills/verify/SKILL.md
```

No cascading dependencies — reverting the effort declaration restores the original high-effort behavior; the skill continues to dispatch both agents identically except without the `Scope:` signal line. Agents that were already calibrating off the `Scope:` line will fall back to maximally-thorough output (the previous default).
