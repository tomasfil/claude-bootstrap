# Migration 026 — Move ANALYZES-class agents to sonnet (proj-debugger + proj-code-reviewer)

> Reclassify `proj-debugger` and `proj-code-reviewer` from `model: opus` to `model: sonnet` per the `ANALYZES → sonnet` classification principle in `techniques/agent-design.md`. Fetches updated agent templates (with reclassified frontmatter and justification comments) from the bootstrap repo into client `.claude/agents/`, and syncs the updated `agent-design.md` technique reference into `.claude/references/techniques/`. Sentinel-guarded for idempotency. Self-contained — no inlined agent bodies; templates are the source of truth and are fetched live.

---

## Metadata

```yaml
id: "026"
breaking: false
affects: [agents, techniques]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

Fields:
- `id`: `"026"`
- `breaking`: `false` — model swap only. Both agents continue to function with the same body, tools, and dispatch contracts. `effort: high` is preserved (generation thoroughness, not thinking blocks); `memory: project` is preserved on `proj-code-reviewer`. No breaking surface for skills that dispatch these agents — the `subagent_type="proj-debugger"` / `subagent_type="proj-code-reviewer"` calls work identically.
- `affects`: `[agents, techniques]` — touches `.claude/agents/proj-debugger.md`, `.claude/agents/proj-code-reviewer.md`, and `.claude/references/techniques/agent-design.md`. No skills, modules, hooks, or settings changed.
- `requires_mcp_json`: `false` — model selection is independent of MCP wiring. Agents inherit MCP from parent regardless of model tier.
- `min_bootstrap_version`: `"6.0"` — earliest bootstrap version with `proj-debugger` and `proj-code-reviewer` agent files installed via Module 05.

---

## Problem

The bootstrap originally classified `proj-debugger` and `proj-code-reviewer` as `model: opus`. Both agents perform analysis work (root-cause investigation, code review) — not code generation. The `techniques/agent-design.md` model-selection principle is `GENERATES code | SUBTLE errors → opus; ANALYZES → sonnet; CHECKS → haiku`. Per that principle these agents belong in the sonnet column.

Evidence:
- Anthropic's agentic-coding routing guidance routes code reviews and debugging to the Sonnet tier.
- The 4.6-generation Opus/Sonnet SWE-bench Verified gap is 1.2 points — within noise for analysis tasks where the agent reads existing code and reports findings, rather than synthesizing new code under subtle-error pressure.
- Pricing (April 2026): Opus $5/$25 per MTok input/output vs Sonnet $3/$15 — Opus/Sonnet cost ratio is 1.67x. Analysis workloads (read-heavy, structured-output) amortize the savings across every dispatch.

`effort: high` is preserved on both agents because effort governs subagent generation thoroughness (reasoning_effort + self-correction loop depth) — it is orthogonal to the model tier choice. The proj-researcher precedent (sonnet + effort:high + memory:project for stateful continuity on proj-code-reviewer) demonstrates this combination is well-trodden.

`techniques/agent-design.md` is updated in the same change to move both agents from the opus column to the sonnet column of the model-selection table, with an evidence-note blockquote explaining the prior-based convention and the post-deployment quality-monitoring path.

---

## Changes

- `.claude/agents/proj-debugger.md` (client project, OVERWRITE):
  - `model: opus` → `model: sonnet`
  - Adds `# sonnet:` justification comment explaining the reclassification (preserves `effort: high` for generation thoroughness, references SWE-bench gap and Anthropic routing guidance).
  - Body unchanged — only frontmatter touched in the bootstrap-repo template.
- `.claude/agents/proj-code-reviewer.md` (client project, OVERWRITE):
  - `model: opus` → `model: sonnet`
  - Adds `# sonnet:` justification comment (same rationale, plus explicit `memory: project` preservation note — proj-researcher precedent: stateful continuity is orthogonal to model choice).
  - Body unchanged in the bootstrap-repo template.
- `.claude/references/techniques/agent-design.md` (client project, OVERWRITE):
  - Move `proj-debugger` row from opus column to sonnet column of the model-selection table.
  - Move `proj-code-reviewer` row from opus column to sonnet column.
  - Insert evidence-note blockquote immediately below the table documenting the classification principle, Anthropic routing alignment, SWE-bench gap, and the post-deployment quality-monitoring verification path.

Idempotency: per-file sentinel guard. If the fetched bootstrap template already shows `model: sonnet` AND the local file already shows `model: sonnet`, the step logs `SKIP` and exits 0. Re-run produces zero modifications. The technique sync uses `cmp -s` against a `.new` tempfile and replaces only on diff (precedent: migrations 015, 011, 008).

Bootstrap self-alignment: `templates/agents/proj-debugger.md`, `templates/agents/proj-code-reviewer.md`, and `techniques/agent-design.md` were updated in the same change set (Phase B of the model-effort-selection plan). Fresh client-project bootstraps will install the reclassified agents directly from the templates; this migration brings already-bootstrapped projects forward without a full refresh. The bootstrap repo's own installed `.claude/` copies are generated output — see Post-Apply note below.

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

### Step 1 — Fetch and install `proj-debugger` (sonnet reclassification)

Fetch the updated `templates/agents/proj-debugger.md` from the bootstrap repo via `gh api`, verify the fetched body declares `model: sonnet` (guard against fetching an older commit), then overwrite `.claude/agents/proj-debugger.md` in the client project. Idempotent: if the local file already declares `model: sonnet` AND the upstream copy is byte-identical to the local copy, the step logs `SKIP` and exits 0.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/agents/proj-debugger.md"
SOURCE_PATH="templates/agents/proj-debugger.md"

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present — proj-debugger agent not installed in this project\n' "$TARGET"
  exit 0
fi

# Fetch upstream to a tempfile.
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

# Guard: upstream MUST declare model: sonnet (proves we fetched the post-Phase-B commit).
if ! grep -qF 'model: sonnet' "$TMP"; then
  printf 'ERROR: upstream %s does not declare model: sonnet — migration 026 not yet published at %s\n' "$SOURCE_PATH" "$BOOTSTRAP_REPO" >&2
  exit 1
fi

# Idempotency: if local already matches upstream byte-for-byte, skip.
if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date (matches upstream)\n' "$TARGET"
  exit 0
fi

# Backup, then overwrite.
cp "$TARGET" "${TARGET}.bak-026"
mv "$TMP" "$TARGET"
trap - EXIT

# Confirm the overwrite landed and declares model: sonnet.
if ! grep -qF 'model: sonnet' "$TARGET"; then
  printf 'ERROR: overwrite failed — %s still does not declare model: sonnet\n' "$TARGET" >&2
  exit 1
fi

printf 'PATCHED: %s (backup: %s.bak-026)\n' "$TARGET" "$TARGET"
```

---

### Step 2 — Fetch and install `proj-code-reviewer` (sonnet reclassification)

Same pattern as Step 1, applied to `proj-code-reviewer`. The fetched template preserves `memory: project` (stateful continuity is orthogonal to model choice — proj-researcher precedent). Idempotent via `cmp -s` against the upstream tempfile.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/agents/proj-code-reviewer.md"
SOURCE_PATH="templates/agents/proj-code-reviewer.md"

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present — proj-code-reviewer agent not installed in this project\n' "$TARGET"
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

if ! grep -qF 'model: sonnet' "$TMP"; then
  printf 'ERROR: upstream %s does not declare model: sonnet — migration 026 not yet published at %s\n' "$SOURCE_PATH" "$BOOTSTRAP_REPO" >&2
  exit 1
fi

if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date (matches upstream)\n' "$TARGET"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak-026"
mv "$TMP" "$TARGET"
trap - EXIT

if ! grep -qF 'model: sonnet' "$TARGET"; then
  printf 'ERROR: overwrite failed — %s still does not declare model: sonnet\n' "$TARGET" >&2
  exit 1
fi

# Sanity: memory: project must still be present (stateful continuity preserved).
if ! grep -qF 'memory: project' "$TARGET"; then
  printf 'ERROR: %s lost memory: project after overwrite — manual review required\n' "$TARGET" >&2
  exit 1
fi

printf 'PATCHED: %s (backup: %s.bak-026)\n' "$TARGET" "$TARGET"
```

---

### Step 3 — Sync `techniques/agent-design.md` → `.claude/references/techniques/agent-design.md`

Fetch the updated `techniques/agent-design.md` from the bootstrap repo and write to the **client project layout path** `.claude/references/techniques/agent-design.md` — NOT `techniques/` at the project root. Bootstrap repo stores techniques at root `techniques/`; client projects store them at `.claude/references/techniques/` (see `modules/02-project-config.md` Step 5 and `CLAUDE.md` gotchas — migrations 001/005/007 had this bug, fixed 2026-04-10).

Idempotent: fetch to `.new` tempfile, `cmp -s` against existing, replace only on diff. Precedent: migrations 015, 011, 008.

```bash
#!/usr/bin/env bash
set -euo pipefail

TECH_DIR=".claude/references/techniques"
mkdir -p "$TECH_DIR"

DEST="${TECH_DIR}/agent-design.md"
TMP="${DEST}.new"
trap 'rm -f "$TMP"' EXIT

if ! gh api "repos/${BOOTSTRAP_REPO}/contents/techniques/agent-design.md?ref=main" --jq '.content' 2>/dev/null | base64 -d > "$TMP"; then
  printf 'ERROR: gh fetch of techniques/agent-design.md failed\n' >&2
  exit 1
fi

if [[ ! -s "$TMP" ]]; then
  printf 'ERROR: fetched %s is empty\n' "$DEST" >&2
  exit 1
fi

# Guard: upstream MUST contain the evidence-note blockquote (proves we fetched the post-Phase-B commit).
if ! grep -qF 'ANALYZES → sonnet' "$TMP"; then
  printf 'ERROR: upstream techniques/agent-design.md does not contain the post-Phase-B evidence note — migration 026 not yet published at %s\n' "$BOOTSTRAP_REPO" >&2
  exit 1
fi

if [[ -f "$DEST" ]] && cmp -s "$DEST" "$TMP"; then
  rm "$TMP"
  trap - EXIT
  printf 'SKIP: %s already up to date\n' "$DEST"
else
  mv "$TMP" "$DEST"
  trap - EXIT
  printf 'UPDATED: %s\n' "$DEST"
fi
```

---

### Rules for migration scripts

- **Literal anchors only** — every `grep` / `cmp` check uses `grep -qF` (literal string) or byte comparison. No regex `.*` patterns.
- **Idempotent** — per-file `cmp -s` gate against the upstream tempfile. Re-run on an already-migrated project produces zero modifications.
- **Read-before-write** — fetch to tempfile, validate, compare, then overwrite via `mv`. No in-place edits. `.bak-026` backups left in place after a successful patch so users can diff before committing.
- **MINGW64-safe** — `mktemp` + `mv` only. No `sed -i`. No process substitution. No `readarray`.
- **Abort on error** — `set -euo pipefail` at the top of every step. Failed fetches, empty files, missing sentinels → explicit `exit 1` with a manual-patch message; partially patched files are never silently left behind.
- **Self-contained** — no inlined agent bodies. Templates are the source of truth and are fetched live from the bootstrap repo via `gh api`. Falls back to explicit error if `gh` is unavailable (no silent curl-fallback that could fetch from the wrong repo).
- **Technique sync to client layout** — `techniques/agent-design.md` is fetched into `.claude/references/techniques/agent-design.md`, never `techniques/` at the project root. This is the client project layout and the only path that downstream code reads.

---

## Verify

```bash
#!/usr/bin/env bash
set -euo pipefail

FAIL=0

# 1. proj-debugger declares model: sonnet
TARGET=".claude/agents/proj-debugger.md"
if [[ -f "$TARGET" ]]; then
  if grep -qF 'model: sonnet' "$TARGET"; then
    echo "PASS: $TARGET declares model: sonnet"
  else
    echo "FAIL: $TARGET does not declare model: sonnet"
    FAIL=1
  fi
else
  echo "SKIP-VERIFY: $TARGET not present"
fi

# 2. proj-code-reviewer declares model: sonnet AND preserves memory: project
TARGET=".claude/agents/proj-code-reviewer.md"
if [[ -f "$TARGET" ]]; then
  if grep -qF 'model: sonnet' "$TARGET"; then
    echo "PASS: $TARGET declares model: sonnet"
  else
    echo "FAIL: $TARGET does not declare model: sonnet"
    FAIL=1
  fi

  if grep -qF 'memory: project' "$TARGET"; then
    echo "PASS: $TARGET preserves memory: project"
  else
    echo "FAIL: $TARGET lost memory: project after migration"
    FAIL=1
  fi
else
  echo "SKIP-VERIFY: $TARGET not present"
fi

# 3. agent-design.md technique reference contains the evidence note
TARGET=".claude/references/techniques/agent-design.md"
if [[ -f "$TARGET" ]]; then
  if grep -qF 'ANALYZES → sonnet' "$TARGET"; then
    echo "PASS: $TARGET contains ANALYZES → sonnet evidence note"
  else
    echo "FAIL: $TARGET missing ANALYZES → sonnet evidence note"
    FAIL=1
  fi
else
  echo "FAIL: $TARGET not present after sync step"
  FAIL=1
fi

# 4. migrations/index.json contains the 026 entry
if grep -qF '"id": "026"' migrations/index.json; then
  echo "PASS: migrations/index.json contains 026 entry"
else
  echo "FAIL: migrations/index.json missing 026 entry"
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
2. Do NOT directly edit `.claude/agents/proj-debugger.md` or `.claude/agents/proj-code-reviewer.md`
   in the bootstrap repo — direct edits bypass the template and create drift
Reference: `.claude/rules/general.md` §Process — "NEVER write to this repo's `.claude/`
as implementation work."

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → `"026"`
- append `{ "id": "026", "applied_at": "<ISO8601>", "description": "Move ANALYZES-class agents to sonnet (proj-debugger + proj-code-reviewer)" }` to `applied[]`

---

## Rollback

Reversible via `git restore` of the affected files in the client project (if the project tracks `.claude/agents/` and `.claude/references/techniques/`). Otherwise: re-fetch the pre-026 versions from the bootstrap repo at the prior commit, or restore the `.bak-026` backups left by Steps 1 and 2:

```bash
mv .claude/agents/proj-debugger.md.bak-026 .claude/agents/proj-debugger.md
mv .claude/agents/proj-code-reviewer.md.bak-026 .claude/agents/proj-code-reviewer.md
```

The technique reference sync (Step 3) does not leave a backup — restore from git or re-fetch the prior version manually. No cascading dependencies — reverting the model declaration restores the original opus-tier behavior; agents continue to function with the same body, tools, and dispatch contracts.
