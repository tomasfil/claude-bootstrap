# Migration 030 — Install `/audit-model-usage` skill + `model-selection.md` policy rule

> Install the new `/audit-model-usage` read-only audit skill and the `model-selection.md` machine-readable policy rule file that the skill reads. Fetches both artifacts from the bootstrap repo via `gh api` with sentinel-guarded idempotency. Completes the model-effort-selection deep-think implementation — the policy file is the source of truth for subsequent audits of agent and skill frontmatter against expected model/effort bindings.

---

## Metadata

```yaml
id: "030"
breaking: false
affects: [skills, rules]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

Fields:
- `id`: `"030"`
- `breaking`: `false` — additive only. Installs one new skill directory and one new rule file. No existing agents, skills, modules, hooks, or settings are modified.
- `affects`: `[skills, rules]` — touches `.claude/skills/audit-model-usage/SKILL.md` (new) and `.claude/rules/model-selection.md` (new). No techniques or modules synced by this migration.
- `requires_mcp_json`: `false` — the audit skill uses only `Read`, `Grep`, `Glob` and reads local files under `.claude/`.
- `min_bootstrap_version`: `"6.0"` — earliest bootstrap version with the project layout (`.claude/skills/`, `.claude/rules/`) supported by this migration.

---

## Problem

The model-effort-selection deep-think (2026-04-14) produced a project-wide policy for agent and skill model/effort bindings, but there was no tooling to continuously audit whether client-project `.claude/agents/` and `.claude/skills/` frontmatter matched that policy. Migrations 026, 027, 028, and 029 updated the individual agent and skill templates to the new policy, but drift can accumulate over time as new specialists are spawned via `/evolve-agents`, as `/reflect` rewrites agent bodies, or as hand edits happen outside the template→migration workflow.

The missing pieces:

1. **Machine-readable policy:** `techniques/agent-design.md` describes the classification principles in prose, but there is no separate single-file data table that tooling can parse row-by-row. `/audit-model-usage` needs a stable policy source of truth that is not intermixed with narrative explanation.
2. **Audit skill:** no skill exists that enumerates `.claude/agents/*.md` and `.claude/skills/*/SKILL.md`, extracts frontmatter, matches against a classification table, and reports COMPLIANT / DRIFT / UNKNOWN counts. Without this skill, every audit is an ad-hoc manual inspection.

This migration closes both gaps. It installs:

- `.claude/rules/model-selection.md` — an Agent Classification Table (11 rows) + Skill Classification Table (7 rows) in markdown-pipe-table form, machine-parseable, kept in sync with `techniques/agent-design.md` by convention.
- `.claude/skills/audit-model-usage/SKILL.md` — a read-only main-thread skill (`model: sonnet`, `effort: medium`, `allowed-tools: Read Grep Glob`) that loads the policy file, enumerates agents and skills, classifies each file, and writes a report to `.claude/reports/model-usage-audit.md`.

The skill has a graceful fallback when `model-selection.md` is absent: it drops to a minimal 3-tier name-based heuristic (code-writer/test-writer/tdd-runner → opus; quick-check → haiku; other → sonnet) and marks every result `[UNKNOWN-FALLBACK]`. This means on pre-030 client projects the skill is still callable but clearly signals that its judgments are not authoritative.

Reference: `.claude/specs/main/2026-04-14-model-effort-selection-spec.md` §F.1, §F.2.

---

## Changes

- `.claude/skills/audit-model-usage/SKILL.md` (client project, CREATE):
  - New skill directory + `SKILL.md` containing frontmatter (name, description, model: sonnet, effort: medium, allowed-tools: `Read Grep Glob` space-separated per Claude Code skill spec) and a `## Actions` body with Phase 1 (load policy) through Phase 5 (write report).
  - `# Skill Class: main-thread — inline reads (low consequence) [latency: interactive]` comment line.
  - `# medium:` justification comment explaining orchestrator-shell effort for the inline-reads class.
- `.claude/rules/model-selection.md` (client project, CREATE):
  - New rule file with 11-row Agent Classification Table and 7-row Skill Classification Table.
  - Human-readable note explaining that `proj-reflector` is currently classified at `opus+high` (STATEFUL_MEMORY) and that a follow-up deep-think session (proposal 2.3-R) is planned to reassess the classification; the pending reassessment does not affect the current COMPLIANT state against this table.

Idempotency: per-file `cmp -s` gate against an upstream tempfile fetched via `gh api`. Re-running the migration on an already-030-applied project produces zero modifications. Sentinel guards verify the fetched upstream content declares the expected top-level markers before any write happens (`# Skill Class: main-thread — inline reads` for the skill, `## Agent Classification Table` for the rule) — this protects against fetching an older commit from the bootstrap repo.

Bootstrap self-alignment: `templates/skills/audit-model-usage/SKILL.md` and `templates/rules/model-selection.md` are created in the same change set (Phase F of the model-effort-selection plan). Fresh client-project bootstraps will install both artifacts directly from the templates via Module 05 / Module 06; this migration brings already-bootstrapped projects forward without a full refresh. The bootstrap repo's own installed `.claude/` copies are generated output — see Post-Apply note below.

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

### Step 1 — Fetch and install `audit-model-usage` skill

Fetch `templates/skills/audit-model-usage/SKILL.md` from the bootstrap repo via `gh api`, verify the fetched body declares the `# Skill Class: main-thread — inline reads (low consequence)` sentinel (guards against fetching a pre-030 commit), then write to `.claude/skills/audit-model-usage/SKILL.md` in the client project. Idempotent: if the local file exists and is byte-identical to upstream, the step logs `SKIP` and exits 0. Creates the skill directory if missing.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/skills/audit-model-usage/SKILL.md"
SOURCE_PATH="templates/skills/audit-model-usage/SKILL.md"

mkdir -p "$(dirname "$TARGET")"

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

# Guard: upstream MUST declare the Skill Class sentinel (proves we fetched the post-Phase-F commit).
if ! grep -qF '# Skill Class: main-thread — inline reads (low consequence)' "$TMP"; then
  printf 'ERROR: upstream %s does not declare the audit-model-usage Skill Class sentinel — migration 030 not yet published at %s\n' "$SOURCE_PATH" "$BOOTSTRAP_REPO" >&2
  exit 1
fi

# Guard: frontmatter must declare model: sonnet + effort: medium + allowed-tools: Read Grep Glob
if ! grep -qF 'model: sonnet' "$TMP"; then
  printf 'ERROR: upstream %s does not declare model: sonnet\n' "$SOURCE_PATH" >&2
  exit 1
fi
if ! grep -qF 'effort: medium' "$TMP"; then
  printf 'ERROR: upstream %s does not declare effort: medium\n' "$SOURCE_PATH" >&2
  exit 1
fi
if ! grep -qF 'allowed-tools: Read Grep Glob' "$TMP"; then
  printf 'ERROR: upstream %s does not declare allowed-tools: Read Grep Glob\n' "$SOURCE_PATH" >&2
  exit 1
fi

# Idempotency: if local already matches upstream byte-for-byte, skip.
if [[ -f "$TARGET" ]] && cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date (matches upstream)\n' "$TARGET"
  exit 0
fi

# Backup if present, then install.
if [[ -f "$TARGET" ]]; then
  cp "$TARGET" "${TARGET}.bak-030"
fi
mv "$TMP" "$TARGET"
trap - EXIT

# Confirm the install landed and declares the sentinel.
if ! grep -qF '# Skill Class: main-thread — inline reads (low consequence)' "$TARGET"; then
  printf 'ERROR: install failed — %s still does not declare the Skill Class sentinel\n' "$TARGET" >&2
  exit 1
fi

if [[ -f "${TARGET}.bak-030" ]]; then
  printf 'PATCHED: %s (backup: %s.bak-030)\n' "$TARGET" "$TARGET"
else
  printf 'CREATED: %s\n' "$TARGET"
fi
```

---

### Step 2 — Fetch and install `model-selection.md` rule

Fetch `templates/rules/model-selection.md` from the bootstrap repo and write to `.claude/rules/model-selection.md` in the client project. Guard: upstream MUST contain `## Agent Classification Table` AND a `proj-debugger` row with `sonnet` before any write happens. Idempotent via `cmp -s` against the upstream tempfile.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/rules/model-selection.md"
SOURCE_PATH="templates/rules/model-selection.md"

mkdir -p "$(dirname "$TARGET")"

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

# Guard: upstream MUST contain the Agent Classification Table heading.
if ! grep -qF '## Agent Classification Table' "$TMP"; then
  printf 'ERROR: upstream %s does not contain the Agent Classification Table — migration 030 not yet published at %s\n' "$SOURCE_PATH" "$BOOTSTRAP_REPO" >&2
  exit 1
fi

# Guard: upstream MUST contain the Skill Classification Table heading.
if ! grep -qF '## Skill Classification Table' "$TMP"; then
  printf 'ERROR: upstream %s does not contain the Skill Classification Table\n' "$SOURCE_PATH" >&2
  exit 1
fi

# Guard: proj-debugger row MUST declare sonnet (proves post-Phase-B state).
if ! grep -F 'proj-debugger' "$TMP" | grep -qF 'sonnet'; then
  printf 'ERROR: upstream %s does not classify proj-debugger as sonnet — refusing to install stale policy\n' "$SOURCE_PATH" >&2
  exit 1
fi

# Guard: proj-verifier row MUST declare sonnet + medium (proves post-Phase-C state).
if ! grep -F 'proj-verifier' "$TMP" | grep -qF 'sonnet'; then
  printf 'ERROR: upstream %s does not classify proj-verifier as sonnet\n' "$SOURCE_PATH" >&2
  exit 1
fi
if ! grep -F 'proj-verifier' "$TMP" | grep -qF 'medium'; then
  printf 'ERROR: upstream %s does not classify proj-verifier at effort:medium\n' "$SOURCE_PATH" >&2
  exit 1
fi

# Idempotency: if local already matches upstream byte-for-byte, skip.
if [[ -f "$TARGET" ]] && cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date (matches upstream)\n' "$TARGET"
  exit 0
fi

# Backup if present, then install.
if [[ -f "$TARGET" ]]; then
  cp "$TARGET" "${TARGET}.bak-030"
fi
mv "$TMP" "$TARGET"
trap - EXIT

# Confirm install landed and both table headings are present.
if ! grep -qF '## Agent Classification Table' "$TARGET"; then
  printf 'ERROR: install failed — %s missing Agent Classification Table\n' "$TARGET" >&2
  exit 1
fi
if ! grep -qF '## Skill Classification Table' "$TARGET"; then
  printf 'ERROR: install failed — %s missing Skill Classification Table\n' "$TARGET" >&2
  exit 1
fi

if [[ -f "${TARGET}.bak-030" ]]; then
  printf 'PATCHED: %s (backup: %s.bak-030)\n' "$TARGET" "$TARGET"
else
  printf 'CREATED: %s\n' "$TARGET"
fi
```

---

### Rules for migration scripts

- **Literal anchors only** — every `grep` / `cmp` check uses `grep -qF` (literal string) or byte comparison. No regex `.*` patterns.
- **Idempotent** — per-file `cmp -s` gate against the upstream tempfile. Re-run on an already-migrated project produces zero modifications.
- **Read-before-write** — fetch to tempfile, validate, compare, then install via `mv`. No in-place edits. `.bak-030` backups left in place after a successful patch of an existing file so users can diff before committing (fresh installs leave no backup because nothing was overwritten).
- **MINGW64-safe** — `mktemp` + `mv` only. No `sed -i`. No process substitution. No `readarray`.
- **Abort on error** — `set -euo pipefail` at the top of every step. Failed fetches, empty files, missing sentinels → explicit `exit 1` with a manual-patch message; partially installed files are never silently left behind.
- **Self-contained** — no inlined skill or rule bodies. Templates are the source of truth and are fetched live from the bootstrap repo via `gh api`. Falls back to explicit error if `gh` is unavailable (no silent curl-fallback that could fetch from the wrong repo).
- **Directory creation** — both steps use `mkdir -p "$(dirname "$TARGET")"` before fetching, so missing parent directories (`.claude/skills/audit-model-usage/`, `.claude/rules/`) are created on demand without error.

---

### Required: register in migrations/index.json

Every migration file MUST have a matching entry in `migrations/index.json`. Add:

```json
{
  "id": "030",
  "file": "030-audit-model-usage.md",
  "description": "Install /audit-model-usage skill + model-selection.md policy rule. Adds a read-only audit skill that enumerates .claude/agents/*.md and .claude/skills/*/SKILL.md, extracts frontmatter, matches against an 11-row Agent Classification Table + 7-row Skill Classification Table in .claude/rules/model-selection.md, and reports COMPLIANT / DRIFT / UNKNOWN counts to .claude/reports/model-usage-audit.md. Completes the model-effort-selection deep-think implementation. Sentinel-guarded fetches from templates/skills/audit-model-usage/SKILL.md and templates/rules/model-selection.md; .bak-030 backups left when overwriting pre-existing files.",
  "breaking": false
}
```

---

## Verify

```bash
#!/usr/bin/env bash
set -euo pipefail

FAIL=0

# 1. audit-model-usage skill installed with correct frontmatter + Skill Class comment
TARGET=".claude/skills/audit-model-usage/SKILL.md"
if [[ -f "$TARGET" ]]; then
  if grep -qF 'name: audit-model-usage' "$TARGET"; then
    echo "PASS: $TARGET declares name: audit-model-usage"
  else
    echo "FAIL: $TARGET missing name: audit-model-usage"
    FAIL=1
  fi

  if grep -qF 'model: sonnet' "$TARGET"; then
    echo "PASS: $TARGET declares model: sonnet"
  else
    echo "FAIL: $TARGET does not declare model: sonnet"
    FAIL=1
  fi

  if grep -qF 'effort: medium' "$TARGET"; then
    echo "PASS: $TARGET declares effort: medium"
  else
    echo "FAIL: $TARGET does not declare effort: medium"
    FAIL=1
  fi

  if grep -qF 'allowed-tools: Read Grep Glob' "$TARGET"; then
    echo "PASS: $TARGET declares allowed-tools: Read Grep Glob (space-separated)"
  else
    echo "FAIL: $TARGET does not declare allowed-tools: Read Grep Glob"
    FAIL=1
  fi

  if grep -qF '# Skill Class: main-thread — inline reads (low consequence)' "$TARGET"; then
    echo "PASS: $TARGET declares Skill Class sentinel"
  else
    echo "FAIL: $TARGET missing Skill Class sentinel"
    FAIL=1
  fi
else
  echo "FAIL: $TARGET not present after Step 1"
  FAIL=1
fi

# 2. model-selection.md rule installed with both classification tables
TARGET=".claude/rules/model-selection.md"
if [[ -f "$TARGET" ]]; then
  if grep -qF '## Agent Classification Table' "$TARGET"; then
    echo "PASS: $TARGET contains Agent Classification Table"
  else
    echo "FAIL: $TARGET missing Agent Classification Table"
    FAIL=1
  fi

  if grep -qF '## Skill Classification Table' "$TARGET"; then
    echo "PASS: $TARGET contains Skill Classification Table"
  else
    echo "FAIL: $TARGET missing Skill Classification Table"
    FAIL=1
  fi

  # Spot-check post-Phase-B/C classifications
  if grep -F 'proj-debugger' "$TARGET" | grep -qF 'sonnet'; then
    echo "PASS: $TARGET classifies proj-debugger as sonnet"
  else
    echo "FAIL: $TARGET does not classify proj-debugger as sonnet"
    FAIL=1
  fi

  if grep -F 'proj-verifier' "$TARGET" | grep -qF 'medium'; then
    echo "PASS: $TARGET classifies proj-verifier at effort:medium"
  else
    echo "FAIL: $TARGET does not classify proj-verifier at effort:medium"
    FAIL=1
  fi
else
  echo "FAIL: $TARGET not present after Step 2"
  FAIL=1
fi

# 3. migrations/index.json contains the 030 entry
if grep -qF '"id": "030"' migrations/index.json; then
  echo "PASS: migrations/index.json contains 030 entry"
else
  echo "FAIL: migrations/index.json missing 030 entry"
  FAIL=1
fi

[[ $FAIL -eq 0 ]] || exit 1
```

Failure of any verify step → `/migrate-bootstrap` aborts and does NOT update `bootstrap-state.json`. Safe to retry after fixing.

Run `/audit-model-usage` after applying — expect all agents COMPLIANT. Any DRIFT indicates the client-project agent frontmatter has not been synced to the post-2026-04-14 model-selection policy.

---

## Post-Apply — Bootstrap Repo Self-Update

This migration targets client projects. The bootstrap repo's own `.claude/` copies are
generated output, not source of truth. To update the bootstrap repo's installed copies:
1. Run `/migrate-bootstrap` against the bootstrap repo itself, OR re-run Module 05 / Module 06
2. Do NOT directly edit `.claude/skills/audit-model-usage/SKILL.md` or `.claude/rules/model-selection.md`
   in the bootstrap repo — direct edits bypass the template and create drift
Reference: `.claude/rules/general.md` §Process — "NEVER write to this repo's `.claude/`
as implementation work."

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → `"030"`
- append `{ "id": "030", "applied_at": "<ISO8601>", "description": "Install /audit-model-usage skill + model-selection.md policy rule" }` to `applied[]`

---

## Rollback

Reversible via `git restore` of the affected files in the client project (if the project tracks `.claude/skills/` and `.claude/rules/`). Otherwise: if `.bak-030` backups exist (only for pre-existing files that were overwritten), restore them:

```bash
for bak in .claude/skills/audit-model-usage/SKILL.md.bak-030 .claude/rules/model-selection.md.bak-030; do
  [[ -f "$bak" ]] || continue
  target="${bak%.bak-030}"
  mv "$bak" "$target"
done
```

If the files were freshly created by this migration (no backup was left), rollback is equivalent to deletion:

```bash
rm -f .claude/skills/audit-model-usage/SKILL.md
rmdir .claude/skills/audit-model-usage 2>/dev/null || true
rm -f .claude/rules/model-selection.md
```

No cascading dependencies — removing the skill disables only the `/audit-model-usage` invocation path; all other agents and skills continue to function. Removing the rule file causes any future `/audit-model-usage` invocation to fall back to the minimal 3-tier name-based heuristic (marking all results `[UNKNOWN-FALLBACK]`) rather than failing.
