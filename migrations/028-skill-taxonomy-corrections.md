# Migration 028 — Skill taxonomy corrections (Skill Class comments + model/effort binding)

> Sync the updated `techniques/agent-design.md` (adds `Skill Class → Model Binding` section) into `.claude/references/techniques/agent-design.md`, and fetch the three skill templates whose frontmatter + `# Skill Class:` comment changed in Phase C of the model-effort-selection plan (`write-prompt`, `audit-file`, `deep-think`) into client `.claude/skills/`. Sentinel-guarded for idempotency. Self-contained — no inlined skill bodies; `templates/skills/{name}/SKILL.md` are the source of truth and are fetched live via `gh api`.

---

## Metadata

```yaml
id: "028"
breaking: false
affects: [skills, techniques]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

Fields:
- `id`: `"028"`
- `breaking`: `false` — skill-body refresh + technique sync only. The three affected skills continue to dispatch the same agents with the same contracts; model/effort frontmatter changes are additive (consequential inline generators get `effort: high`; bounded forkable probes get `effort: medium`; iterative orchestrators get `effort: high`) and do not break any caller.
- `affects`: `[skills, techniques]` — touches `.claude/skills/write-prompt/SKILL.md`, `.claude/skills/audit-file/SKILL.md`, `.claude/skills/deep-think/SKILL.md`, and `.claude/references/techniques/agent-design.md`. No agents, modules, hooks, or settings changed.
- `requires_mcp_json`: `false` — skill taxonomy is independent of MCP wiring.
- `min_bootstrap_version`: `"6.0"` — earliest bootstrap version with `write-prompt`, `audit-file`, and `deep-think` skills installed via Module 06.

---

## Problem

Phase C of the `2026-04-14-model-effort-selection` plan introduced a formal Skill Class taxonomy to `techniques/agent-design.md` — four classes with explicit dispatch constraints:

1. **main-thread inline** (no agent dispatch, synchronous file writes — e.g. `commit`, `write-prompt`)
2. **main-thread orchestrator** (dispatches agents, interactive user gates — e.g. `deep-think`, `brainstorm`, `execute-plan`)
3. **forkable bounded** (single autonomous dispatch, no user interaction — e.g. `verify`, `coverage`, `audit-file`)
4. **forkable analysis** (read-only analysis forked to background — e.g. `test-fork`)

The Skill Class determines **model** and **effort** frontmatter binding: inline generators of consequential prompts (write-prompt) need `effort: high`; bounded forkable probes (audit-file) get `effort: medium` per the procedural tool-use precedent from migration 027; multi-phase adversarial orchestrators (deep-think) keep `effort: high` because iterative synthesis quality scales with reasoning depth.

Three skill templates were updated in the bootstrap repo during Phase C of the plan:

- `templates/skills/write-prompt/SKILL.md` — added `# Skill Class: main-thread — inline generator (consequential) [latency: interactive]` after the YAML fence; frontmatter confirmed `model: opus` + `effort: high` (prompt-generation quality floor).
- `templates/skills/audit-file/SKILL.md` — added `# Skill Class: forkable — bounded autonomous task [latency: interactive]`; frontmatter set to `model: sonnet` + `effort: medium` per migration 027 procedural-tool-use precedent.
- `templates/skills/deep-think/SKILL.md` — added `# Skill Class: main-thread — multi-dispatch iterative orchestrator w/ interactive user-gate`; frontmatter confirmed `model: opus` + `effort: high` (adversarial synthesis requires maximum reasoning budget).

`techniques/agent-design.md` was updated in the same change set to include the `## Skill Class → Model Binding` section documenting the taxonomy, the required `# Skill Class:` comment convention (every skill MUST include this comment immediately after the closing YAML frontmatter fence), and the model/effort selection rules per class.

Client projects bootstrapped before Phase C have skill files without the `# Skill Class:` comment and may have stale frontmatter. This migration brings them forward without a full Module 06 refresh.

Note on `.claude/rules/code-standards-markdown.md`: Phase D of the plan also intended to add a `## Skill Class Convention` section to the markdown code standards rule file, pointing at `techniques/agent-design.md` §Skill Class → Model Binding. During Phase D tracing, no source template for `code-standards-markdown.md` was found in `modules/` or `templates/rules/` — the file is created ad-hoc during Module 02 dispatch from a generic language-template prompt, and the markdown-specific content appears to be a direct edit in the bootstrap repo's own gitignored `.claude/rules/`. This migration therefore does NOT sync `code-standards-markdown.md`; that sync is deferred to a follow-up migration after the source-template gap is resolved (either by creating `templates/rules/code-standards-markdown.md` and threading it through Module 02, or by documenting the file as a direct-edit deliverable not covered by migrations).

---

## Changes

- `.claude/references/techniques/agent-design.md` (client project, OVERWRITE):
  - Adds `## Skill Class → Model Binding` section with the four-class taxonomy, required `# Skill Class:` comment convention, and model/effort selection rules per class.
  - Adds `## Skill Classification` section with class definitions and dispatch constraints.
  - No prior content removed — additive only.
- `.claude/skills/write-prompt/SKILL.md` (client project, OVERWRITE):
  - Adds `# Skill Class: main-thread — inline generator (consequential) [latency: interactive]` comment after the closing YAML fence.
  - Frontmatter `model: opus` + `effort: high` confirmed — consequential inline prompt generator warrants maximum reasoning budget.
  - Body refresh from upstream template; no breaking contract changes.
- `.claude/skills/audit-file/SKILL.md` (client project, OVERWRITE):
  - Adds `# Skill Class: forkable — bounded autonomous task [latency: interactive]` comment after the closing YAML fence.
  - Frontmatter `model: sonnet` + `effort: medium` per migration 027 procedural-tool-use precedent (bounded autonomous audit is structured checklist work, not subtle-error code synthesis).
  - Body refresh from upstream template; no breaking contract changes.
- `.claude/skills/deep-think/SKILL.md` (client project, OVERWRITE):
  - Adds `# Skill Class: main-thread — multi-dispatch iterative orchestrator w/ interactive user-gate` comment after the closing YAML fence.
  - Frontmatter `model: opus` + `effort: high` confirmed — adversarial multi-phase synthesis with 15-dispatch cap requires maximum reasoning depth.
  - Body refresh from upstream template; preserves the Phase-7 artifact contract (proposals.md + spec.md dual output).
- `.claude/skills/deep-think/references/` subdirectory (personas.md, dispatch-templates.md) is NOT touched by this migration — only `SKILL.md` is fetched. The reference files are unchanged from migration 017 and remain installed.

Idempotency: per-file sentinel guard. If the fetched upstream template is byte-identical to the local copy (`cmp -s`), the step logs `SKIP` and exits 0. Re-run on an already-migrated project produces zero modifications. The technique sync uses the same `cmp -s` pattern against a `.new` tempfile and replaces only on diff (precedent: migrations 026, 027, 015, 011, 008).

Bootstrap self-alignment: `templates/skills/write-prompt/SKILL.md`, `templates/skills/audit-file/SKILL.md`, `templates/skills/deep-think/SKILL.md`, and `techniques/agent-design.md` were updated in Phase C of the model-effort-selection plan. Fresh client-project bootstraps will install the updated skills directly from the templates via Module 06; this migration brings already-bootstrapped projects forward without a full refresh. The bootstrap repo's own installed `.claude/` copies are generated output — see Post-Apply note below.

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

### Step 1 — Sync `techniques/agent-design.md` → `.claude/references/techniques/agent-design.md`

Fetch the updated `techniques/agent-design.md` from the bootstrap repo and write to the **client project layout path** `.claude/references/techniques/agent-design.md` — NOT `techniques/` at the project root. Bootstrap repo stores techniques at root `techniques/`; client projects store them at `.claude/references/techniques/` (see `modules/02-project-config.md` Step 5 and `CLAUDE.md` gotchas — migrations 001/005/007 had this bug, fixed 2026-04-10).

Guard: upstream MUST contain the `Skill Class → Model Binding` sentinel string (proves we fetched the post-Phase-C commit). Idempotent: fetch to `.new` tempfile, `cmp -s` against existing, replace only on diff. Precedent: migrations 026, 027, 015, 011, 008.

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

# Guard: upstream MUST contain the Skill Class → Model Binding section (proves we fetched the post-Phase-C commit).
if ! grep -qF 'Skill Class → Model Binding' "$TMP"; then
  printf 'ERROR: upstream techniques/agent-design.md does not contain the Skill Class → Model Binding section — migration 028 not yet published at %s\n' "$BOOTSTRAP_REPO" >&2
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

### Step 2 — Fetch and install `write-prompt/SKILL.md`

Fetch the updated `templates/skills/write-prompt/SKILL.md` from the bootstrap repo via `gh api`, verify the fetched body contains the `# Skill Class: main-thread — inline generator` sentinel (guard against fetching an older commit), then overwrite `.claude/skills/write-prompt/SKILL.md` in the client project. Idempotent: if the local file is byte-identical to the upstream copy, the step logs `SKIP` and exits 0.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/skills/write-prompt/SKILL.md"
SOURCE_PATH="templates/skills/write-prompt/SKILL.md"

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present — write-prompt skill not installed in this project\n' "$TARGET"
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

# Guard: upstream MUST declare the Skill Class comment (proves we fetched the post-Phase-C commit).
if ! grep -qF '# Skill Class: main-thread — inline generator' "$TMP"; then
  printf 'ERROR: upstream %s does not declare the expected Skill Class comment — migration 028 not yet published at %s\n' "$SOURCE_PATH" "$BOOTSTRAP_REPO" >&2
  exit 1
fi

if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date (matches upstream)\n' "$TARGET"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak-028"
mv "$TMP" "$TARGET"
trap - EXIT

# Confirm the overwrite landed and declares the expected Skill Class.
if ! grep -qF '# Skill Class: main-thread — inline generator' "$TARGET"; then
  printf 'ERROR: overwrite failed — %s still does not declare the Skill Class comment\n' "$TARGET" >&2
  exit 1
fi

printf 'PATCHED: %s (backup: %s.bak-028)\n' "$TARGET" "$TARGET"
```

---

### Step 3 — Fetch and install `audit-file/SKILL.md`

Same pattern as Step 2 for `audit-file`. Sentinel: `# Skill Class: forkable — bounded autonomous task`. Frontmatter confirms `model: sonnet` + `effort: medium` per the procedural tool-use precedent from migration 027.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/skills/audit-file/SKILL.md"
SOURCE_PATH="templates/skills/audit-file/SKILL.md"

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present — audit-file skill not installed in this project\n' "$TARGET"
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

if ! grep -qF '# Skill Class: forkable — bounded autonomous task' "$TMP"; then
  printf 'ERROR: upstream %s does not declare the expected Skill Class comment — migration 028 not yet published at %s\n' "$SOURCE_PATH" "$BOOTSTRAP_REPO" >&2
  exit 1
fi

if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date (matches upstream)\n' "$TARGET"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak-028"
mv "$TMP" "$TARGET"
trap - EXIT

if ! grep -qF '# Skill Class: forkable — bounded autonomous task' "$TARGET"; then
  printf 'ERROR: overwrite failed — %s still does not declare the Skill Class comment\n' "$TARGET" >&2
  exit 1
fi

printf 'PATCHED: %s (backup: %s.bak-028)\n' "$TARGET" "$TARGET"
```

---

### Step 4 — Fetch and install `deep-think/SKILL.md`

Same pattern as Steps 2 and 3 for `deep-think`. Sentinel: `# Skill Class: main-thread — multi-dispatch iterative orchestrator`. Frontmatter confirms `model: opus` + `effort: high` — adversarial multi-phase synthesis with 15-dispatch cap requires maximum reasoning depth.

Only `SKILL.md` is fetched; the `references/personas.md` and `references/dispatch-templates.md` files installed by migration 017 are unchanged and are NOT touched here.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/skills/deep-think/SKILL.md"
SOURCE_PATH="templates/skills/deep-think/SKILL.md"

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present — deep-think skill not installed in this project\n' "$TARGET"
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

if ! grep -qF '# Skill Class: main-thread — multi-dispatch iterative orchestrator' "$TMP"; then
  printf 'ERROR: upstream %s does not declare the expected Skill Class comment — migration 028 not yet published at %s\n' "$SOURCE_PATH" "$BOOTSTRAP_REPO" >&2
  exit 1
fi

if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date (matches upstream)\n' "$TARGET"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak-028"
mv "$TMP" "$TARGET"
trap - EXIT

if ! grep -qF '# Skill Class: main-thread — multi-dispatch iterative orchestrator' "$TARGET"; then
  printf 'ERROR: overwrite failed — %s still does not declare the Skill Class comment\n' "$TARGET" >&2
  exit 1
fi

printf 'PATCHED: %s (backup: %s.bak-028)\n' "$TARGET" "$TARGET"
```

---

### Step 5 — code-standards-markdown.md sync (PENDING FOLLOW-UP — NOT APPLIED BY THIS MIGRATION)

Phase D of the model-effort-selection plan intended to add a `## Skill Class Convention` section to `.claude/rules/code-standards-markdown.md` pointing at `techniques/agent-design.md` §Skill Class → Model Binding. During Phase D source tracing, no template source for this rule file was located in `modules/` or `templates/rules/` — the file is created ad-hoc during Module 02 Step 3 via a generic language-template dispatch prompt (`code-standards-{lang}.md`), and the markdown-specific content (Naming / Structure / Content / Verification sections) is a direct edit in the bootstrap repo's own gitignored `.claude/rules/` that is not templated anywhere.

**This migration does NOT sync `code-standards-markdown.md`.** Surfacing the gap here so follow-up work can close it:

1. **Preferred resolution**: create `templates/rules/code-standards-markdown.md` in the bootstrap repo with the full markdown-specific ruleset, thread it through Module 02 Step 3 as a named fetch (similar to how `mcp-routing.md` is embedded verbatim in that step), then issue a follow-up migration that does a sentinel-guarded `gh api` fetch into `.claude/rules/code-standards-markdown.md` with a `# Skill Class Convention` section sentinel.
2. **Alternative resolution**: document `code-standards-markdown.md` as a direct-edit deliverable not covered by migrations, and add the `## Skill Class Convention` section via a manual one-off edit in each client project.

Tracker entry: `.learnings/log.md` 2026-04-14 — "gotcha: code-standards-markdown.md source template not found in modules/ or templates/rules/. Follow-up needed: either create templates/rules/ or document as direct-edit only."

No bash action runs for this step — the migration verify phase does not check for `## Skill Class Convention` in `.claude/rules/code-standards-markdown.md`.

---

### Rules for migration scripts

- **Literal anchors only** — every `grep` / `cmp` check uses `grep -qF` (literal string) or byte comparison. No regex `.*` patterns.
- **Idempotent** — per-file `cmp -s` gate against the upstream tempfile. Re-run on an already-migrated project produces zero modifications.
- **Read-before-write** — fetch to tempfile, validate, compare, then overwrite via `mv`. No in-place edits. `.bak-028` backups left in place after a successful patch so users can diff before committing.
- **MINGW64-safe** — `mktemp` + `mv` only. No `sed -i`. No process substitution. No `readarray`.
- **Abort on error** — `set -euo pipefail` at the top of every step. Failed fetches, empty files, missing sentinels → explicit `exit 1` with a manual-patch message; partially patched files are never silently left behind.
- **Self-contained** — no inlined skill bodies. Templates are the source of truth and are fetched live from the bootstrap repo via `gh api`. Falls back to explicit error if `gh` is unavailable (no silent curl-fallback that could fetch from the wrong repo).
- **Technique sync to client layout** — `techniques/agent-design.md` is fetched into `.claude/references/techniques/agent-design.md`, never `techniques/` at the project root. This is the client project layout and the only path that downstream code reads.

---

## Verify

```bash
#!/usr/bin/env bash
set -euo pipefail

FAIL=0

# 1. agent-design.md technique reference contains the Skill Class → Model Binding section
TARGET=".claude/references/techniques/agent-design.md"
if [[ -f "$TARGET" ]]; then
  if grep -qF 'Skill Class → Model Binding' "$TARGET"; then
    echo "PASS: $TARGET contains Skill Class → Model Binding section"
  else
    echo "FAIL: $TARGET missing Skill Class → Model Binding section"
    FAIL=1
  fi
else
  echo "FAIL: $TARGET not present after sync step"
  FAIL=1
fi

# 2. write-prompt/SKILL.md declares the main-thread inline generator Skill Class
TARGET=".claude/skills/write-prompt/SKILL.md"
if [[ -f "$TARGET" ]]; then
  if grep -qF '# Skill Class: main-thread — inline generator' "$TARGET"; then
    echo "PASS: $TARGET declares Skill Class: main-thread inline generator"
  else
    echo "FAIL: $TARGET does not declare the expected Skill Class comment"
    FAIL=1
  fi
else
  echo "SKIP-VERIFY: $TARGET not present"
fi

# 3. audit-file/SKILL.md declares the forkable bounded autonomous Skill Class
TARGET=".claude/skills/audit-file/SKILL.md"
if [[ -f "$TARGET" ]]; then
  if grep -qF '# Skill Class: forkable — bounded autonomous task' "$TARGET"; then
    echo "PASS: $TARGET declares Skill Class: forkable bounded autonomous task"
  else
    echo "FAIL: $TARGET does not declare the expected Skill Class comment"
    FAIL=1
  fi
else
  echo "SKIP-VERIFY: $TARGET not present"
fi

# 4. deep-think/SKILL.md declares the main-thread multi-dispatch iterative orchestrator Skill Class
TARGET=".claude/skills/deep-think/SKILL.md"
if [[ -f "$TARGET" ]]; then
  if grep -qF '# Skill Class: main-thread — multi-dispatch iterative orchestrator' "$TARGET"; then
    echo "PASS: $TARGET declares Skill Class: main-thread multi-dispatch iterative orchestrator"
  else
    echo "FAIL: $TARGET does not declare the expected Skill Class comment"
    FAIL=1
  fi
else
  echo "SKIP-VERIFY: $TARGET not present"
fi

# 5. migrations/index.json contains the 028 entry
if grep -qF '"id": "028"' migrations/index.json; then
  echo "PASS: migrations/index.json contains 028 entry"
else
  echo "FAIL: migrations/index.json missing 028 entry"
  FAIL=1
fi

[[ $FAIL -eq 0 ]] || exit 1
```

Failure of any verify step → `/migrate-bootstrap` aborts and does NOT update `bootstrap-state.json`. Safe to retry after fixing.

---

## Post-Apply — Bootstrap Repo Self-Update

This migration targets client projects. The bootstrap repo's own `.claude/` copies are
generated output, not source of truth. To update the bootstrap repo's installed copies:
1. Run `/migrate-bootstrap` against the bootstrap repo itself, OR re-run Module 06
2. Do NOT directly edit `.claude/skills/write-prompt/SKILL.md`, `.claude/skills/audit-file/SKILL.md`,
   or `.claude/skills/deep-think/SKILL.md` in the bootstrap repo — direct edits bypass the
   template and create drift
Reference: `.claude/rules/general.md` §Process — "NEVER write to this repo's `.claude/`
as implementation work."

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → `"028"`
- append `{ "id": "028", "applied_at": "<ISO8601>", "description": "Skill taxonomy corrections (Skill Class comments + model/effort binding)" }` to `applied[]`

---

## Rollback

Reversible via `git restore` of the affected files in the client project (if the project tracks `.claude/skills/` and `.claude/references/techniques/`). Otherwise: restore the `.bak-028` backups left by Steps 2, 3, and 4:

```bash
mv .claude/skills/write-prompt/SKILL.md.bak-028 .claude/skills/write-prompt/SKILL.md
mv .claude/skills/audit-file/SKILL.md.bak-028 .claude/skills/audit-file/SKILL.md
mv .claude/skills/deep-think/SKILL.md.bak-028 .claude/skills/deep-think/SKILL.md
```

The technique reference sync (Step 1) does not leave a backup — restore from git or re-fetch the prior version manually. No cascading dependencies — reverting the Skill Class comments and frontmatter restores the pre-Phase-C behavior; the skills continue to function with the same body and dispatch contracts.
