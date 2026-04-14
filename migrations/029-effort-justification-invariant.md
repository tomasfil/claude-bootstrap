# Migration 029 — Effort justification invariant (`# high:` / `# medium:` comments)

> Establish the `effort: <token>` justification invariant across all agents and the `audit-agents` skill. For every agent declaring `effort: high` or `effort: medium`, the immediately following frontmatter line must be a `# high: <TOKEN>` or `# medium: <TOKEN>` justification comment. This migration fetches the updated agent templates (with justification comments added in the bootstrap repo) into the client project, installs the updated `audit-agents/SKILL.md` which now includes the `A7` presence check, and backfills the comment on already-installed `code-writer-<lang>` / `test-writer-<lang>` sub-specialists via an idempotent in-place awk patch. Sentinel-guarded for idempotency. Self-contained — no inlined agent bodies; templates are the source of truth and are fetched live via `gh api`.

---

## Metadata

```yaml
id: "029"
breaking: false
affects: [agents, skills]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

Fields:
- `id`: `"029"`
- `breaking`: `false` — additive frontmatter comment only. No change to `model:`, `effort:`, `tools:`, body content, or dispatch contracts. All agents continue to function identically. `subagent_type="proj-<name>"` calls work without modification.
- `affects`: `[agents, skills]` — touches 11 `.claude/agents/proj-*.md` files, any installed `.claude/agents/code-writer-*.md` + `.claude/agents/test-writer-*.md` sub-specialists (glob-patched), and `.claude/skills/audit-agents/SKILL.md`. No techniques, modules, hooks, or settings changed.
- `requires_mcp_json`: `false` — justification comments are independent of MCP wiring.
- `min_bootstrap_version`: `"6.0"` — earliest bootstrap version with the full `proj-*` agent set installed via Module 05.

---

## Problem

After the Phase B–D reclassifications landed (migrations 026 + 027 + intermediate template edits), every agent in the bootstrap repo had its `model:` + `effort:` frontmatter re-audited against the `techniques/agent-design.md` Skill Class → Model Binding table. The audit surfaced a reliability gap: **there is no enforcement mechanism** that catches a future agent added with `effort: high` (or `effort: medium` where the medium choice is load-bearing against the v2.1.94+ session default) without a justification trail.

The fix is a two-layer invariant:
1. **Data layer** — every agent declaring `effort: high` or `effort: medium` carries a `# high: <TOKEN>` / `# medium: <TOKEN>` comment immediately after the `effort:` line. Tokens are free-text (presence-only check — NOT validated against an enum vocabulary). Writers document why the non-default effort level is load-bearing.
2. **Audit layer** — `/audit-agents` skill gains an `A7` check that grep-verifies the presence of the `# high:` / `# medium:` comment on every effort:high/effort:medium agent, and applies the skill-side rule (effort:high skills are self-justified if `# Skill Class:` contains `dispatch` / `orchestrat` / `synthesis`, otherwise require a `# high:` comment).

Migration 026 already shipped the `# high:` comment on `proj-debugger` and `proj-code-reviewer` (as part of the sonnet reclassification). Migration 027 already shipped `# medium:` comments on `proj-verifier` and `proj-consistency-checker` (as part of the procedural-effort correction). **This migration (029) backfills the remaining agents and installs the `A7` audit rule.** It also fetches the 2 already-migrated agents defensively so a client project that skipped 026/027 and jumped to 029 still lands in a consistent state (the `cmp -s` gate guarantees zero churn when the file is already up to date).

### Prerequisite: Migration 026

Migration 026 (`agents-analyze-class-sonnet`) MUST apply before this migration. The `proj-debugger` and `proj-code-reviewer` `# high:` comments first land in 026 as part of the opus→sonnet reclassification; this migration re-fetches those same templates defensively but relies on 026 having established the model swap. If a client project runs `/migrate-bootstrap` in sequence (026 → 027 → 028 → 029) the prerequisite is automatically satisfied. If a client project jumps directly to 029, migration 026 is applied first by the `/migrate-bootstrap` runner (it walks `migrations/index.json` in order and refuses to skip entries).

Migration 027 (`procedural-effort-medium`) is similarly a soft-prerequisite — it establishes the `# medium:` comment on `proj-verifier` and `proj-consistency-checker`. This migration re-fetches both templates defensively; the `cmp -s` gate produces `SKIP` when 027 already ran.

---

## Changes

- `.claude/agents/proj-code-writer-markdown.md` (client project, OVERWRITE):
  - Adds `# high: GENERATES_CODE` justification comment immediately after `effort: high`.
  - Body unchanged.
- `.claude/agents/proj-code-writer-bash.md` (client project, OVERWRITE):
  - Adds `# high: GENERATES_CODE` justification comment immediately after `effort: high`.
  - Body unchanged.
- `.claude/agents/proj-tdd-runner.md` (client project, OVERWRITE):
  - Adds `# high: GENERATES_CODE` justification comment (TDD runner writes failing tests + production code via red-green-refactor).
  - Body unchanged.
- `.claude/agents/proj-reflector.md` (client project, OVERWRITE):
  - Adds `# high: MULTI_STEP_SYNTHESIS` justification comment (reflector synthesizes learnings + proposals across sessions, `memory: project` preserved).
  - Body unchanged.
- `.claude/agents/proj-researcher.md` (client project, OVERWRITE):
  - Adds `# high: MULTI_STEP_SYNTHESIS` justification comment (deep investigation across multiple sources).
  - Body unchanged.
- `.claude/agents/proj-plan-writer.md` (client project, OVERWRITE):
  - Adds `# high: MULTI_STEP_SYNTHESIS` justification comment (plan synthesis w/ tier classification + FFD packing + risk analysis).
  - Body unchanged.
- `.claude/agents/proj-quick-check.md` (client project, OVERWRITE):
  - Adds `# high: INHERITED_DEFAULT` tracked-debt marker (quick-check is a fast lookup agent; `effort: high` is the session-default from v2.1.94 — not load-bearing. Tracked as follow-up per spec §Follow-Up Work #3).
  - `A7` audit check emits `WARN` on `INHERITED_DEFAULT` rather than `FAIL` so this case surfaces as visible debt without blocking audits.
  - Body unchanged.
- `.claude/agents/code-writer-<lang>.md` (every installed sub-specialist, IN-PLACE PATCH via awk):
  - Adds `# high: GENERATES_CODE` justification comment immediately after `effort: high` in YAML frontmatter.
  - Uses glob loop per `.claude/rules/general.md` §Migrations ("Migrations must glob agent filenames").
  - Body unchanged.
- `.claude/agents/test-writer-<lang>.md` (every installed sub-specialist, IN-PLACE PATCH via awk):
  - Adds `# high: GENERATES_CODE` justification comment immediately after `effort: high` in YAML frontmatter.
  - Uses glob loop.
  - Body unchanged.
- `.claude/agents/proj-debugger.md` (client project, OVERWRITE, defensive):
  - Already carries `# high: ANALYZES_SUBTLE` comment from migration 026. Re-fetched here to keep client state consistent if 026 was somehow bypassed. The `cmp -s` gate produces `SKIP` when 026 already applied.
- `.claude/agents/proj-code-reviewer.md` (client project, OVERWRITE, defensive):
  - Already carries `# high: STRUCTURAL_REVIEW` comment from migration 026. Re-fetched defensively; `cmp -s` → SKIP when 026 applied.
- `.claude/agents/proj-verifier.md` (client project, OVERWRITE, defensive):
  - Already carries `# medium: PROCEDURAL_TOOL_USE` comment from migration 027. Re-fetched defensively; `cmp -s` → SKIP when 027 applied. `effort: medium` is preserved — this is NOT a reclassification, it is a backfill of the justification invariant.
- `.claude/agents/proj-consistency-checker.md` (client project, OVERWRITE, defensive):
  - Already carries `# medium: PROCEDURAL_TOOL_USE` comment from migration 027. Re-fetched defensively; `cmp -s` → SKIP when 027 applied.
- `.claude/skills/audit-agents/SKILL.md` (client project, OVERWRITE):
  - Adds `### A7: effort:high justification presence check` section with agent + skill check logic (per spec §E.3).
  - Adds `A7_effort_high_justified` row to the audit report YAML format.
  - Adds `A7 FAIL` / `A7 WARN` fix recommendations to the post-agent response section.
  - Body otherwise unchanged.

Idempotency: per-file sentinel guard. The overwrite steps compare upstream to local via `cmp -s` and emit `SKIP` on byte match. The awk backfill for `code-writer-*.md` / `test-writer-*.md` greps for `# high: GENERATES_CODE` first and exits `SKIP` when already applied. Re-run on a migrated project produces zero modifications.

Bootstrap self-alignment: `templates/agents/proj-code-writer-markdown.md` + the other 10 `templates/agents/proj-*.md` files + `templates/agents/code-writer.template.md` + `templates/agents/test-writer.template.md` + `templates/skills/audit-agents/SKILL.md` were updated in the same change set (Phase E of the model-effort-selection plan). Fresh client-project bootstraps will install the justification comments directly from templates; this migration brings already-bootstrapped projects forward without a full refresh. The bootstrap repo's own installed `.claude/` copies are generated output — see Post-Apply note below.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }

command -v gh >/dev/null 2>&1 || { echo "ERROR: gh required for template fetch"; exit 1; }
command -v base64 >/dev/null 2>&1 || { echo "ERROR: base64 required"; exit 1; }
command -v awk >/dev/null 2>&1 || { echo "ERROR: awk required"; exit 1; }
command -v cmp >/dev/null 2>&1 || { echo "ERROR: cmp required"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "ERROR: gh not authenticated — run gh auth login"; exit 1; }

# Resolve bootstrap source (precedence: env var → state file → canonical default).
BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-$(jq -r '.bootstrap_repo // "tomasfil/claude-bootstrap"' .claude/bootstrap-state.json 2>/dev/null || echo tomasfil/claude-bootstrap)}"
printf 'Using bootstrap repo: %s\n' "$BOOTSTRAP_REPO"

# Verify migration 026 has been applied (proj-debugger already carries # high: comment).
# This is an advisory check — the migration runner already walks index.json in order,
# so 026 runs before 029 automatically. This block surfaces a clear error if a client
# has somehow jumped ahead.
if [[ -f ".claude/agents/proj-debugger.md" ]]; then
  if ! grep -qF 'model: sonnet' ".claude/agents/proj-debugger.md"; then
    printf 'ERROR: migration 026 has not been applied — .claude/agents/proj-debugger.md still declares opus. Run /migrate-bootstrap to apply 026 first.\n' >&2
    exit 1
  fi
fi
```

---

### Step 1 — Fetch and install `proj-code-writer-markdown` (`# high: GENERATES_CODE`)

Fetch the updated `templates/agents/proj-code-writer-markdown.md` from the bootstrap repo via `gh api`, verify the fetched body declares `# high: GENERATES_CODE`, then overwrite `.claude/agents/proj-code-writer-markdown.md` in the client project. Idempotent: if the local file already matches the upstream copy byte-for-byte, the step logs `SKIP` and exits 0.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/agents/proj-code-writer-markdown.md"
SOURCE_PATH="templates/agents/proj-code-writer-markdown.md"
SENTINEL='# high: GENERATES_CODE'

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present — agent not installed in this project\n' "$TARGET"
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! gh api "repos/${BOOTSTRAP_REPO}/contents/${SOURCE_PATH}?ref=main" --jq '.content' 2>/dev/null | base64 -d > "$TMP"; then
  printf 'ERROR: gh fetch of %s failed\n' "$SOURCE_PATH" >&2
  exit 1
fi

[[ -s "$TMP" ]] || { printf 'ERROR: fetched %s is empty\n' "$SOURCE_PATH" >&2; exit 1; }

if ! grep -qF "$SENTINEL" "$TMP"; then
  printf 'ERROR: upstream %s does not declare %s — migration 029 not yet published at %s\n' "$SOURCE_PATH" "$SENTINEL" "$BOOTSTRAP_REPO" >&2
  exit 1
fi

if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date (matches upstream)\n' "$TARGET"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak-029"
mv "$TMP" "$TARGET"
trap - EXIT

grep -qF "$SENTINEL" "$TARGET" || { printf 'ERROR: overwrite failed — %s missing %s\n' "$TARGET" "$SENTINEL" >&2; exit 1; }

printf 'PATCHED: %s (backup: %s.bak-029)\n' "$TARGET" "$TARGET"
```

---

### Step 2 — Fetch and install `proj-code-writer-bash` (`# high: GENERATES_CODE`)

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/agents/proj-code-writer-bash.md"
SOURCE_PATH="templates/agents/proj-code-writer-bash.md"
SENTINEL='# high: GENERATES_CODE'

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present\n' "$TARGET"
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! gh api "repos/${BOOTSTRAP_REPO}/contents/${SOURCE_PATH}?ref=main" --jq '.content' 2>/dev/null | base64 -d > "$TMP"; then
  printf 'ERROR: gh fetch of %s failed\n' "$SOURCE_PATH" >&2
  exit 1
fi

[[ -s "$TMP" ]] || { printf 'ERROR: fetched %s is empty\n' "$SOURCE_PATH" >&2; exit 1; }

if ! grep -qF "$SENTINEL" "$TMP"; then
  printf 'ERROR: upstream %s does not declare %s\n' "$SOURCE_PATH" "$SENTINEL" >&2
  exit 1
fi

if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date\n' "$TARGET"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak-029"
mv "$TMP" "$TARGET"
trap - EXIT

grep -qF "$SENTINEL" "$TARGET" || { printf 'ERROR: overwrite failed — %s missing %s\n' "$TARGET" "$SENTINEL" >&2; exit 1; }

printf 'PATCHED: %s (backup: %s.bak-029)\n' "$TARGET" "$TARGET"
```

---

### Step 3 — Fetch and install `proj-tdd-runner` (`# high: GENERATES_CODE`)

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/agents/proj-tdd-runner.md"
SOURCE_PATH="templates/agents/proj-tdd-runner.md"
SENTINEL='# high: GENERATES_CODE'

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present\n' "$TARGET"
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! gh api "repos/${BOOTSTRAP_REPO}/contents/${SOURCE_PATH}?ref=main" --jq '.content' 2>/dev/null | base64 -d > "$TMP"; then
  printf 'ERROR: gh fetch of %s failed\n' "$SOURCE_PATH" >&2
  exit 1
fi

[[ -s "$TMP" ]] || { printf 'ERROR: fetched %s is empty\n' "$SOURCE_PATH" >&2; exit 1; }

if ! grep -qF "$SENTINEL" "$TMP"; then
  printf 'ERROR: upstream %s does not declare %s\n' "$SOURCE_PATH" "$SENTINEL" >&2
  exit 1
fi

if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date\n' "$TARGET"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak-029"
mv "$TMP" "$TARGET"
trap - EXIT

grep -qF "$SENTINEL" "$TARGET" || { printf 'ERROR: overwrite failed — %s missing %s\n' "$TARGET" "$SENTINEL" >&2; exit 1; }

printf 'PATCHED: %s (backup: %s.bak-029)\n' "$TARGET" "$TARGET"
```

---

### Step 4 — Fetch and install `proj-reflector` (`# high: MULTI_STEP_SYNTHESIS`)

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/agents/proj-reflector.md"
SOURCE_PATH="templates/agents/proj-reflector.md"
SENTINEL='# high: MULTI_STEP_SYNTHESIS'

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present\n' "$TARGET"
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! gh api "repos/${BOOTSTRAP_REPO}/contents/${SOURCE_PATH}?ref=main" --jq '.content' 2>/dev/null | base64 -d > "$TMP"; then
  printf 'ERROR: gh fetch of %s failed\n' "$SOURCE_PATH" >&2
  exit 1
fi

[[ -s "$TMP" ]] || { printf 'ERROR: fetched %s is empty\n' "$SOURCE_PATH" >&2; exit 1; }

if ! grep -qF "$SENTINEL" "$TMP"; then
  printf 'ERROR: upstream %s does not declare %s\n' "$SOURCE_PATH" "$SENTINEL" >&2
  exit 1
fi

if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date\n' "$TARGET"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak-029"
mv "$TMP" "$TARGET"
trap - EXIT

grep -qF "$SENTINEL" "$TARGET" || { printf 'ERROR: overwrite failed — %s missing %s\n' "$TARGET" "$SENTINEL" >&2; exit 1; }

printf 'PATCHED: %s (backup: %s.bak-029)\n' "$TARGET" "$TARGET"
```

---

### Step 5 — Fetch and install `proj-researcher` (`# high: MULTI_STEP_SYNTHESIS`)

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/agents/proj-researcher.md"
SOURCE_PATH="templates/agents/proj-researcher.md"
SENTINEL='# high: MULTI_STEP_SYNTHESIS'

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present\n' "$TARGET"
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! gh api "repos/${BOOTSTRAP_REPO}/contents/${SOURCE_PATH}?ref=main" --jq '.content' 2>/dev/null | base64 -d > "$TMP"; then
  printf 'ERROR: gh fetch of %s failed\n' "$SOURCE_PATH" >&2
  exit 1
fi

[[ -s "$TMP" ]] || { printf 'ERROR: fetched %s is empty\n' "$SOURCE_PATH" >&2; exit 1; }

if ! grep -qF "$SENTINEL" "$TMP"; then
  printf 'ERROR: upstream %s does not declare %s\n' "$SOURCE_PATH" "$SENTINEL" >&2
  exit 1
fi

if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date\n' "$TARGET"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak-029"
mv "$TMP" "$TARGET"
trap - EXIT

grep -qF "$SENTINEL" "$TARGET" || { printf 'ERROR: overwrite failed — %s missing %s\n' "$TARGET" "$SENTINEL" >&2; exit 1; }

printf 'PATCHED: %s (backup: %s.bak-029)\n' "$TARGET" "$TARGET"
```

---

### Step 6 — Fetch and install `proj-plan-writer` (`# high: MULTI_STEP_SYNTHESIS`)

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/agents/proj-plan-writer.md"
SOURCE_PATH="templates/agents/proj-plan-writer.md"
SENTINEL='# high: MULTI_STEP_SYNTHESIS'

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present\n' "$TARGET"
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! gh api "repos/${BOOTSTRAP_REPO}/contents/${SOURCE_PATH}?ref=main" --jq '.content' 2>/dev/null | base64 -d > "$TMP"; then
  printf 'ERROR: gh fetch of %s failed\n' "$SOURCE_PATH" >&2
  exit 1
fi

[[ -s "$TMP" ]] || { printf 'ERROR: fetched %s is empty\n' "$SOURCE_PATH" >&2; exit 1; }

if ! grep -qF "$SENTINEL" "$TMP"; then
  printf 'ERROR: upstream %s does not declare %s\n' "$SOURCE_PATH" "$SENTINEL" >&2
  exit 1
fi

if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date\n' "$TARGET"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak-029"
mv "$TMP" "$TARGET"
trap - EXIT

grep -qF "$SENTINEL" "$TARGET" || { printf 'ERROR: overwrite failed — %s missing %s\n' "$TARGET" "$SENTINEL" >&2; exit 1; }

printf 'PATCHED: %s (backup: %s.bak-029)\n' "$TARGET" "$TARGET"
```

---

### Step 7 — Fetch and install `proj-quick-check` (`# high: INHERITED_DEFAULT` tracked-debt marker)

`proj-quick-check` is a fast lookup agent — its `effort: high` is inherited from the v2.1.94 session default and is **not load-bearing**. The justification comment uses the literal token `INHERITED_DEFAULT` which the `A7` audit check treats as a `WARN` (not a `FAIL`) so the tracked debt remains visible without blocking audits. Follow-up per spec §Follow-Up Work #3 will revisit whether the intent ("high effort = careful lookup") has merit or whether the classification should move to `effort: low`.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/agents/proj-quick-check.md"
SOURCE_PATH="templates/agents/proj-quick-check.md"
SENTINEL='# high: INHERITED_DEFAULT'

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present\n' "$TARGET"
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! gh api "repos/${BOOTSTRAP_REPO}/contents/${SOURCE_PATH}?ref=main" --jq '.content' 2>/dev/null | base64 -d > "$TMP"; then
  printf 'ERROR: gh fetch of %s failed\n' "$SOURCE_PATH" >&2
  exit 1
fi

[[ -s "$TMP" ]] || { printf 'ERROR: fetched %s is empty\n' "$SOURCE_PATH" >&2; exit 1; }

if ! grep -qF "$SENTINEL" "$TMP"; then
  printf 'ERROR: upstream %s does not declare %s\n' "$SOURCE_PATH" "$SENTINEL" >&2
  exit 1
fi

if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date\n' "$TARGET"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak-029"
mv "$TMP" "$TARGET"
trap - EXIT

grep -qF "$SENTINEL" "$TARGET" || { printf 'ERROR: overwrite failed — %s missing %s\n' "$TARGET" "$SENTINEL" >&2; exit 1; }

printf 'PATCHED: %s (backup: %s.bak-029)\n' "$TARGET" "$TARGET"
```

---

### Step 8 — Backfill `code-writer-<lang>` sub-specialists via awk glob loop

`templates/agents/code-writer.template.md` is a **template file** — it is NOT copied to `.claude/agents/` as-is. Instead, `/evolve-agents` materializes one `code-writer-<lang>.md` per language detected in the project (e.g., `code-writer-typescript.md`, `code-writer-rust.md`). Per `.claude/rules/general.md` §Migrations, migrations MUST glob these filenames — they cannot be enumerated statically.

This step iterates every `.claude/agents/code-writer-*.md` in the client project and adds `# high: GENERATES_CODE` immediately after `effort: high` in the YAML frontmatter via awk (literal-string match, no regex). Idempotent: skips any file that already contains the sentinel. Leaves a `.bak-029` per file patched.

When `/evolve-agents` regenerates these files from the updated `code-writer.template.md` in a future session, the template already contains the `# high: GENERATES_CODE` comment and fresh sub-specialists carry it natively. This step is the backfill path for already-materialized files.

```bash
#!/usr/bin/env bash
set -euo pipefail

SENTINEL='# high: GENERATES_CODE'
PATCHED=0
SKIPPED=0

shopt -s nullglob
for agent in .claude/agents/code-writer-*.md; do
  [[ -f "$agent" ]] || continue

  # Skip if already applied.
  if grep -qF "$SENTINEL" "$agent"; then
    printf 'SKIP: %s already has %s\n' "$agent" "$SENTINEL"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Skip if no effort: high in frontmatter (unexpected but safe).
  if ! grep -qF 'effort: high' "$agent"; then
    printf 'SKIP: %s does not declare effort: high — not in scope for A7\n' "$agent"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Backup.
  cp "$agent" "${agent}.bak-029"

  # Insert "# high: GENERATES_CODE" line immediately after the first line matching
  # literal "effort: high" (awk literal match via index, no regex).
  TMP="$(mktemp)"
  awk -v sentinel="$SENTINEL" '
    {
      print
      if (!done && index($0, "effort: high") > 0) {
        print sentinel
        done = 1
      }
    }
  ' "$agent" > "$TMP"

  if ! grep -qF "$SENTINEL" "$TMP"; then
    rm -f "$TMP"
    printf 'ERROR: awk insert failed for %s — sentinel not found in output\n' "$agent" >&2
    exit 1
  fi

  mv "$TMP" "$agent"
  printf 'PATCHED: %s (backup: %s.bak-029)\n' "$agent" "$agent"
  PATCHED=$((PATCHED + 1))
done
shopt -u nullglob

printf 'code-writer-*.md backfill complete: patched=%d skipped=%d\n' "$PATCHED" "$SKIPPED"
```

---

### Step 9 — Backfill `test-writer-<lang>` sub-specialists via awk glob loop

Same pattern as Step 8, applied to `.claude/agents/test-writer-*.md` sub-specialists materialized by `/evolve-agents` from `templates/agents/test-writer.template.md`. Test-writer agents produce test code — `GENERATES_CODE` is the correct justification token.

```bash
#!/usr/bin/env bash
set -euo pipefail

SENTINEL='# high: GENERATES_CODE'
PATCHED=0
SKIPPED=0

shopt -s nullglob
for agent in .claude/agents/test-writer-*.md; do
  [[ -f "$agent" ]] || continue

  if grep -qF "$SENTINEL" "$agent"; then
    printf 'SKIP: %s already has %s\n' "$agent" "$SENTINEL"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  if ! grep -qF 'effort: high' "$agent"; then
    printf 'SKIP: %s does not declare effort: high — not in scope for A7\n' "$agent"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  cp "$agent" "${agent}.bak-029"

  TMP="$(mktemp)"
  awk -v sentinel="$SENTINEL" '
    {
      print
      if (!done && index($0, "effort: high") > 0) {
        print sentinel
        done = 1
      }
    }
  ' "$agent" > "$TMP"

  if ! grep -qF "$SENTINEL" "$TMP"; then
    rm -f "$TMP"
    printf 'ERROR: awk insert failed for %s\n' "$agent" >&2
    exit 1
  fi

  mv "$TMP" "$agent"
  printf 'PATCHED: %s (backup: %s.bak-029)\n' "$agent" "$agent"
  PATCHED=$((PATCHED + 1))
done
shopt -u nullglob

printf 'test-writer-*.md backfill complete: patched=%d skipped=%d\n' "$PATCHED" "$SKIPPED"
```

---

### Step 10 — Defensive re-fetch `proj-debugger` (idempotent with migration 026)

`proj-debugger` already carries `# high: ANALYZES_SUBTLE` from migration 026. This step defensively re-fetches the upstream template and overwrites only on diff. When migration 026 has already applied, `cmp -s` produces `SKIP` with zero modifications.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/agents/proj-debugger.md"
SOURCE_PATH="templates/agents/proj-debugger.md"
SENTINEL='# high: ANALYZES_SUBTLE'

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present\n' "$TARGET"
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! gh api "repos/${BOOTSTRAP_REPO}/contents/${SOURCE_PATH}?ref=main" --jq '.content' 2>/dev/null | base64 -d > "$TMP"; then
  printf 'ERROR: gh fetch of %s failed\n' "$SOURCE_PATH" >&2
  exit 1
fi

[[ -s "$TMP" ]] || { printf 'ERROR: fetched %s is empty\n' "$SOURCE_PATH" >&2; exit 1; }

if ! grep -qF "$SENTINEL" "$TMP"; then
  printf 'ERROR: upstream %s does not declare %s\n' "$SOURCE_PATH" "$SENTINEL" >&2
  exit 1
fi

if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date (matches upstream, likely from migration 026)\n' "$TARGET"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak-029"
mv "$TMP" "$TARGET"
trap - EXIT

grep -qF "$SENTINEL" "$TARGET" || { printf 'ERROR: overwrite failed — %s missing %s\n' "$TARGET" "$SENTINEL" >&2; exit 1; }

printf 'PATCHED: %s (backup: %s.bak-029)\n' "$TARGET" "$TARGET"
```

---

### Step 11 — Defensive re-fetch `proj-code-reviewer` (idempotent with migration 026)

`proj-code-reviewer` already carries `# high: STRUCTURAL_REVIEW` from migration 026 and preserves `memory: project`. Defensive re-fetch; `cmp -s` → SKIP when 026 applied.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/agents/proj-code-reviewer.md"
SOURCE_PATH="templates/agents/proj-code-reviewer.md"
SENTINEL='# high: STRUCTURAL_REVIEW'

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present\n' "$TARGET"
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! gh api "repos/${BOOTSTRAP_REPO}/contents/${SOURCE_PATH}?ref=main" --jq '.content' 2>/dev/null | base64 -d > "$TMP"; then
  printf 'ERROR: gh fetch of %s failed\n' "$SOURCE_PATH" >&2
  exit 1
fi

[[ -s "$TMP" ]] || { printf 'ERROR: fetched %s is empty\n' "$SOURCE_PATH" >&2; exit 1; }

if ! grep -qF "$SENTINEL" "$TMP"; then
  printf 'ERROR: upstream %s does not declare %s\n' "$SOURCE_PATH" "$SENTINEL" >&2
  exit 1
fi

if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date (matches upstream, likely from migration 026)\n' "$TARGET"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak-029"
mv "$TMP" "$TARGET"
trap - EXIT

grep -qF "$SENTINEL" "$TARGET" || { printf 'ERROR: overwrite failed — %s missing %s\n' "$TARGET" "$SENTINEL" >&2; exit 1; }

# Sanity: memory: project must still be present (preserved from migration 026).
if ! grep -qF 'memory: project' "$TARGET"; then
  printf 'ERROR: %s lost memory: project after overwrite\n' "$TARGET" >&2
  exit 1
fi

printf 'PATCHED: %s (backup: %s.bak-029)\n' "$TARGET" "$TARGET"
```

---

### Step 12 — Defensive re-fetch `proj-verifier` (idempotent with migration 027)

`proj-verifier` carries `# medium: PROCEDURAL_TOOL_USE` from migration 027. The comment uses `# medium:` (not `# high:`) because the agent is `effort: medium` per the procedural-tool-use classification — still in scope for the invariant. Defensive re-fetch.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/agents/proj-verifier.md"
SOURCE_PATH="templates/agents/proj-verifier.md"
SENTINEL='# medium: PROCEDURAL_TOOL_USE'

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present\n' "$TARGET"
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! gh api "repos/${BOOTSTRAP_REPO}/contents/${SOURCE_PATH}?ref=main" --jq '.content' 2>/dev/null | base64 -d > "$TMP"; then
  printf 'ERROR: gh fetch of %s failed\n' "$SOURCE_PATH" >&2
  exit 1
fi

[[ -s "$TMP" ]] || { printf 'ERROR: fetched %s is empty\n' "$SOURCE_PATH" >&2; exit 1; }

if ! grep -qF "$SENTINEL" "$TMP"; then
  printf 'ERROR: upstream %s does not declare %s\n' "$SOURCE_PATH" "$SENTINEL" >&2
  exit 1
fi

if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date (matches upstream, likely from migration 027)\n' "$TARGET"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak-029"
mv "$TMP" "$TARGET"
trap - EXIT

grep -qF "$SENTINEL" "$TARGET" || { printf 'ERROR: overwrite failed — %s missing %s\n' "$TARGET" "$SENTINEL" >&2; exit 1; }

# Sanity: effort: medium must still be present (preserved from migration 027).
if ! grep -qF 'effort: medium' "$TARGET"; then
  printf 'ERROR: %s lost effort: medium after overwrite\n' "$TARGET" >&2
  exit 1
fi

printf 'PATCHED: %s (backup: %s.bak-029)\n' "$TARGET" "$TARGET"
```

---

### Step 13 — Defensive re-fetch `proj-consistency-checker` (idempotent with migration 027)

`proj-consistency-checker` carries `# medium: PROCEDURAL_TOOL_USE` from migration 027. Defensive re-fetch.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/agents/proj-consistency-checker.md"
SOURCE_PATH="templates/agents/proj-consistency-checker.md"
SENTINEL='# medium: PROCEDURAL_TOOL_USE'

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present\n' "$TARGET"
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! gh api "repos/${BOOTSTRAP_REPO}/contents/${SOURCE_PATH}?ref=main" --jq '.content' 2>/dev/null | base64 -d > "$TMP"; then
  printf 'ERROR: gh fetch of %s failed\n' "$SOURCE_PATH" >&2
  exit 1
fi

[[ -s "$TMP" ]] || { printf 'ERROR: fetched %s is empty\n' "$SOURCE_PATH" >&2; exit 1; }

if ! grep -qF "$SENTINEL" "$TMP"; then
  printf 'ERROR: upstream %s does not declare %s\n' "$SOURCE_PATH" "$SENTINEL" >&2
  exit 1
fi

if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date (matches upstream, likely from migration 027)\n' "$TARGET"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak-029"
mv "$TMP" "$TARGET"
trap - EXIT

grep -qF "$SENTINEL" "$TARGET" || { printf 'ERROR: overwrite failed — %s missing %s\n' "$TARGET" "$SENTINEL" >&2; exit 1; }

if ! grep -qF 'effort: medium' "$TARGET"; then
  printf 'ERROR: %s lost effort: medium after overwrite\n' "$TARGET" >&2
  exit 1
fi

printf 'PATCHED: %s (backup: %s.bak-029)\n' "$TARGET" "$TARGET"
```

---

### Step 14 — Fetch and install updated `audit-agents/SKILL.md` (A7 check)

Fetch the updated `templates/skills/audit-agents/SKILL.md` which now includes the `A7: effort:high justification presence check` section. Overwrites the client-project skill file. Idempotent: `cmp -s` gate produces `SKIP` on byte match.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/skills/audit-agents/SKILL.md"
SOURCE_PATH="templates/skills/audit-agents/SKILL.md"
SENTINEL='A7: effort:high justification presence check'

if [[ ! -f "$TARGET" ]]; then
  printf 'SKIP: %s not present — audit-agents skill not installed in this project\n' "$TARGET"
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! gh api "repos/${BOOTSTRAP_REPO}/contents/${SOURCE_PATH}?ref=main" --jq '.content' 2>/dev/null | base64 -d > "$TMP"; then
  printf 'ERROR: gh fetch of %s failed\n' "$SOURCE_PATH" >&2
  exit 1
fi

[[ -s "$TMP" ]] || { printf 'ERROR: fetched %s is empty\n' "$SOURCE_PATH" >&2; exit 1; }

if ! grep -qF "$SENTINEL" "$TMP"; then
  printf 'ERROR: upstream %s does not contain A7 check section — migration 029 not yet published at %s\n' "$SOURCE_PATH" "$BOOTSTRAP_REPO" >&2
  exit 1
fi

if cmp -s "$TARGET" "$TMP"; then
  printf 'SKIP: %s already up to date\n' "$TARGET"
  exit 0
fi

cp "$TARGET" "${TARGET}.bak-029"
mv "$TMP" "$TARGET"
trap - EXIT

grep -qF "$SENTINEL" "$TARGET" || { printf 'ERROR: overwrite failed — %s missing A7 section\n' "$TARGET" >&2; exit 1; }

printf 'PATCHED: %s (backup: %s.bak-029)\n' "$TARGET" "$TARGET"
```

---

### Rules for migration scripts

- **Literal anchors only** — every `grep` / `cmp` check uses `grep -qF` (literal string) or byte comparison. No regex `.*` patterns. awk inserts use `index()` for literal substring match, not `match()` or `/regex/`.
- **Idempotent** — per-file `cmp -s` gate against upstream tempfile, or per-line `grep -qF` sentinel check before awk patching. Re-run on an already-migrated project produces zero modifications.
- **Read-before-write** — fetch to tempfile, validate, compare, overwrite via `mv`. No in-place edits. `.bak-029` backups left in place after successful patches.
- **MINGW64-safe** — `mktemp` + `mv` only. No `sed -i`. No process substitution. No `readarray`. awk invocations use `-v` for variable passing, not heredoc injection.
- **Abort on error** — `set -euo pipefail` at the top of every step. Failed fetches, empty files, missing sentinels → explicit `exit 1` with a manual-patch message. Partially patched files are never silently left behind.
- **Self-contained** — no inlined agent bodies or skill bodies. Templates are the source of truth, fetched live from the bootstrap repo via `gh api`. No curl fallback.
- **Glob agent filenames** — per `.claude/rules/general.md` §Migrations, `code-writer-*.md` and `test-writer-*.md` are iterated via `shopt -s nullglob` loop, never enumerated statically. Sub-specialists materialized by `/evolve-agents` receive the backfill automatically.
- **Presence-only A7 check** — the `A7` audit rule installed in Step 14 does NOT validate tokens against an enum. Token vocabulary is free-text documentation; any string after `# high: ` / `# medium: ` satisfies the check. `INHERITED_DEFAULT` is the only reserved token (triggers `WARN` instead of `FAIL`).

---

## Verify

```bash
#!/usr/bin/env bash
set -euo pipefail

FAIL=0

check_agent_sentinel() {
  local target="$1"
  local sentinel="$2"
  if [[ -f "$target" ]]; then
    if grep -qF "$sentinel" "$target"; then
      echo "PASS: $target contains $sentinel"
    else
      echo "FAIL: $target missing $sentinel"
      FAIL=1
    fi
  else
    echo "SKIP-VERIFY: $target not present"
  fi
}

# 1. All 7 primary agents carry the # high: justification
check_agent_sentinel ".claude/agents/proj-code-writer-markdown.md" '# high: GENERATES_CODE'
check_agent_sentinel ".claude/agents/proj-code-writer-bash.md"     '# high: GENERATES_CODE'
check_agent_sentinel ".claude/agents/proj-tdd-runner.md"           '# high: GENERATES_CODE'
check_agent_sentinel ".claude/agents/proj-reflector.md"            '# high: MULTI_STEP_SYNTHESIS'
check_agent_sentinel ".claude/agents/proj-researcher.md"           '# high: MULTI_STEP_SYNTHESIS'
check_agent_sentinel ".claude/agents/proj-plan-writer.md"          '# high: MULTI_STEP_SYNTHESIS'
check_agent_sentinel ".claude/agents/proj-quick-check.md"          '# high: INHERITED_DEFAULT'

# 2. Defensive re-fetch agents (shipped by 026/027 — must still carry the comment after 029)
check_agent_sentinel ".claude/agents/proj-debugger.md"             '# high: ANALYZES_SUBTLE'
check_agent_sentinel ".claude/agents/proj-code-reviewer.md"        '# high: STRUCTURAL_REVIEW'
check_agent_sentinel ".claude/agents/proj-verifier.md"             '# medium: PROCEDURAL_TOOL_USE'
check_agent_sentinel ".claude/agents/proj-consistency-checker.md"  '# medium: PROCEDURAL_TOOL_USE'

# 3. Glob sub-specialists — every effort:high code-writer / test-writer carries GENERATES_CODE
shopt -s nullglob
for agent in .claude/agents/code-writer-*.md .claude/agents/test-writer-*.md; do
  [[ -f "$agent" ]] || continue
  if grep -qF 'effort: high' "$agent"; then
    if grep -qF '# high: GENERATES_CODE' "$agent"; then
      echo "PASS: $agent contains # high: GENERATES_CODE"
    else
      echo "FAIL: $agent declares effort: high but missing # high: GENERATES_CODE"
      FAIL=1
    fi
  fi
done
shopt -u nullglob

# 4. proj-code-reviewer still preserves memory: project
TARGET=".claude/agents/proj-code-reviewer.md"
if [[ -f "$TARGET" ]]; then
  if grep -qF 'memory: project' "$TARGET"; then
    echo "PASS: $TARGET preserves memory: project"
  else
    echo "FAIL: $TARGET lost memory: project"
    FAIL=1
  fi
fi

# 5. audit-agents skill carries A7 check
TARGET=".claude/skills/audit-agents/SKILL.md"
if [[ -f "$TARGET" ]]; then
  if grep -qF 'A7: effort:high justification presence check' "$TARGET"; then
    echo "PASS: $TARGET contains A7 check section"
  else
    echo "FAIL: $TARGET missing A7 check section"
    FAIL=1
  fi
fi

# 6. migrations/index.json contains the 029 entry
if grep -qF '"id": "029"' migrations/index.json; then
  echo "PASS: migrations/index.json contains 029 entry"
else
  echo "FAIL: migrations/index.json missing 029 entry"
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
2. Do NOT directly edit `.claude/agents/proj-*.md` or `.claude/skills/audit-agents/SKILL.md`
   in the bootstrap repo — direct edits bypass the template and create drift
Reference: `.claude/rules/general.md` §Process — "NEVER write to this repo's `.claude/`
as implementation work."

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → `"029"`
- append `{ "id": "029", "applied_at": "<ISO8601>", "description": "Effort justification invariant (# high: / # medium: comments)" }` to `applied[]`

---

## Rollback

Reversible via `git restore` of the affected files in the client project (if the project tracks `.claude/agents/` and `.claude/skills/`). Otherwise: restore the `.bak-029` backups left by each patching step:

```bash
for bak in .claude/agents/*.bak-029 .claude/skills/audit-agents/SKILL.md.bak-029; do
  [[ -f "$bak" ]] || continue
  target="${bak%.bak-029}"
  mv "$bak" "$target"
done
```

No cascading dependencies — removing the `# high:` / `# medium:` justification comments restores the agents to their pre-029 state. Agents continue to function with the same body, tools, model, effort, and dispatch contracts (justification comments are documentation, not behavior). The `A7` audit rule in `audit-agents/SKILL.md` would no longer be enforced post-rollback; re-running the `audit-agents` check against a non-migrated state produces `FAIL` on every agent that lost its comment — expected behavior, not a migration defect.

Note: rolling back 029 does NOT roll back migrations 026/027 — the `# high: ANALYZES_SUBTLE`, `# high: STRUCTURAL_REVIEW`, and `# medium: PROCEDURAL_TOOL_USE` comments remain on `proj-debugger`, `proj-code-reviewer`, `proj-verifier`, and `proj-consistency-checker` because those comments shipped in the earlier migrations. To fully revert, roll back 029 → 027 → 026 in reverse order.
