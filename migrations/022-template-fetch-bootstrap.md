# Migration 022 — Template-fetch bootstrap

> Bring existing client projects to the template-fetch bootstrap model. Fetches every skill + agent listed in `templates/manifest.json` from the bootstrap repo into `.claude/skills/` + `.claude/agents/` using `gh api`, with per-file SHA-compare idempotency. Missing files (`INSTALL`) are byte-downloaded verbatim. Files that already exist but differ from upstream (`MERGE`) are **hand-merged by the LLM orchestrator** running the migration — preserving any project-specific customizations while incorporating upstream improvements. Dry-run preview + explicit user confirmation before any writes. Re-run safe.

---

## Metadata

```yaml
id: "022"
breaking: false
affects: [skills, agents]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

Fields:
- `id`: `"022"`
- `breaking`: `false` — additive + idempotent. Dry-run by default; overwrite is an explicit opt-in. Never deletes files not in the manifest.
- `affects`: `[skills, agents]` — writes to `.claude/skills/<name>/SKILL.md` and `.claude/agents/<name>.md` only.
- `requires_mcp_json`: `false` — no MCP dependency. `gh` + `sha256sum` + `base64` are the only external binaries.
- `min_bootstrap_version`: `"6.0"` — earliest bootstrap version with a populated `templates/manifest.json` in the upstream repo.

---

## Problem

Prior to the P2 cutover, modules 05 (skills) and 06 (agents) contained inline heredoc spec blocks that the bootstrap LLM rendered into `.claude/skills/<name>/SKILL.md` and `.claude/agents/<name>.md` at bootstrap time. That approach had three failure modes:

1. **Context blowout** — each module loaded every skill/agent spec into context before rendering, exhausting the window on larger bootstraps.
2. **Silent drift** — LLM rendering introduced small variations between client projects. Two projects bootstrapped from the same module could end up with subtly different skill bodies. No diff surface existed.
3. **No update path** — once a skill was rendered, re-running the module re-rendered it from scratch. Incremental updates to a single skill required a full module re-run and context reload.

The P2 cutover moves skill + agent bodies to tracked `templates/skills/<name>/SKILL.md` and `templates/agents/<name>.md` files in the bootstrap repo itself. Modules 05 + 06 are now thin fetch loops that iterate `templates/manifest.json` and copy bytes verbatim. Client projects bootstrapped after the cutover get byte-identical installs; updates are per-file SHA-compare diffs.

This migration brings **already-bootstrapped** client projects forward to the template-fetch model without forcing a full re-bootstrap. Existing skill/agent files are compared by SHA-256 against the upstream manifest; any mismatches are listed in a dry-run preview and overwritten only on explicit confirmation.

Root cause of the problem being fixed: modules 05 + 06 historically embedded skill/agent content inline, and no mechanism existed to propagate upstream template edits into existing client projects. This migration is the one-time bridge between the old (LLM-rendered) and new (template-fetched) installation models.

---

## Changes

- **No source modifications.** This migration only writes to `.claude/skills/` and `.claude/agents/` inside the client project. It does not edit modules, rules, techniques, hooks, or settings.
- **Per-file SHA-compare classification.** For every entry in `templates/manifest.json` (27 skills + 10 agents as of migration 022 author date), the migration computes `sha256sum .claude/<target>` locally and compares against the manifest `sha256` field. Three outcomes per file:
  - `[SKIP]` — local SHA matches manifest SHA. No action.
  - `[MERGE]` — local file exists but SHA differs. Queued for **hand-merge** by the LLM orchestrator (see Step 3b). Local customizations are preserved; upstream improvements are incorporated.
  - `[INSTALL]` — local file absent. Queued for fresh byte-download from upstream (no local customizations to preserve).
- **INSTALL is byte-exact; MERGE is hand-crafted.** The distinction matters: a missing file has no local state to lose, so a verbatim copy from upstream is correct. An existing file may contain project-specific edits (custom frontmatter fields, added rules, tweaked prose, extra references) — silently overwriting those regressions project-local work. Step 3b delegates MERGE operations to the LLM running `/migrate-bootstrap` so merges can be reasoned about semantically, not mechanically.
- **Dry-run by default.** Step 2 prints the full action list (`[SKIP]`/`[MERGE]`/`[INSTALL]` per file) and prompts the user to confirm before any writes happen. `--force` flag or `FORCE=1` environment variable skip the prompt. Force applies to **confirmation only** — it does NOT downgrade `[MERGE]` to a byte-overwrite. MERGE always hand-merges.
- **Does NOT fetch agent-templates.** `templates/manifest.json` has a third array `agent-templates` (containing `code-writer.template.md` + `test-writer.template.md`). Those are rendered per-language by Module 07 sed-substitution and produce files like `proj-code-writer-markdown.md` that are NOT in the `agents` array. This migration iterates `skills` + `agents` only. Users needing updated per-language writer/test-writer specialists must re-run `/module-write 07` or equivalent — see Notes below.
- **Does NOT install `proj-code-reviewer`.** The project-specific code reviewer is generated by Module 07 Phase 5 with project-aware context; it is not in `templates/manifest.json` and this migration correctly does not touch it.
- **MINGW64 CR-safe.** The action list is NOT persisted via TSV tempfile. Each step re-iterates the manifest directly through `jq` and computes classifications inline, eliminating the `read -r` trailing-`\r` hazard observed on Windows MINGW64 where file-open text-mode translation can inject CR bytes into tab-separated sidecar files.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }

# Required binaries.
command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI required — install from https://cli.github.com"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required — install from https://jqlang.github.io/jq"; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "ERROR: sha256sum required (coreutils)"; exit 1; }
command -v base64 >/dev/null 2>&1 || { echo "ERROR: base64 required"; exit 1; }

# Resolve bootstrap repo owner. The canonical bootstrap repo is
# <owner>/claude-bootstrap — replace <owner> below with your GitHub username,
# or export BOOTSTRAP_OWNER in the environment before running the migration.
# Example: export BOOTSTRAP_OWNER=tfpt
BOOTSTRAP_OWNER="${BOOTSTRAP_OWNER:-<owner>}"
BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-claude-bootstrap}"
BOOTSTRAP_REF="${BOOTSTRAP_REF:-main}"

if [[ "$BOOTSTRAP_OWNER" == "<owner>" ]]; then
  echo "ERROR: BOOTSTRAP_OWNER not set — edit the migration or export BOOTSTRAP_OWNER=<your-github-username> before running"
  exit 1
fi

# Force / no-prompt control.
FORCE="${FORCE:-0}"
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
  esac
done
```

### Pre-flight — verify `gh` authenticated

```bash
if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh not authenticated — run 'gh auth login' first"
  echo "       Alternative: offline fallback documented in Notes section of this migration"
  exit 1
fi
echo "PASS: gh authenticated"
```

---

### Step 1 — Fetch manifest

Download `templates/manifest.json` from the bootstrap repo into a temp file. The manifest is the authoritative source for which skills + agents this migration installs and their expected SHAs.

```bash
MANIFEST_TMP="$(mktemp -t bootstrap-manifest.XXXXXX.json)"
trap 'rm -f "$MANIFEST_TMP"' EXIT

echo "Fetching manifest from ${BOOTSTRAP_OWNER}/${BOOTSTRAP_REPO}@${BOOTSTRAP_REF} ..."
if ! gh api "repos/${BOOTSTRAP_OWNER}/${BOOTSTRAP_REPO}/contents/templates/manifest.json?ref=${BOOTSTRAP_REF}" --jq .content | base64 -d > "$MANIFEST_TMP"; then
  echo "ERROR: failed to fetch templates/manifest.json from ${BOOTSTRAP_OWNER}/${BOOTSTRAP_REPO}"
  exit 1
fi

# Validate the manifest is well-formed JSON with the expected shape.
if ! jq -e '.version == 1 and (.skills | type == "array") and (.agents | type == "array")' "$MANIFEST_TMP" >/dev/null; then
  echo "ERROR: manifest at $MANIFEST_TMP is malformed or missing required fields (version/skills/agents)"
  exit 1
fi

SKILL_COUNT="$(jq '.skills | length' "$MANIFEST_TMP")"
AGENT_COUNT="$(jq '.agents | length' "$MANIFEST_TMP")"
echo "PASS: manifest fetched — ${SKILL_COUNT} skills + ${AGENT_COUNT} agents"
```

---

### Step 2 — Dry-run preview

For every entry in `skills` and `agents`, compare local SHA against manifest SHA and classify as `[SKIP]`, `[MERGE]`, or `[INSTALL]`. Print the full action list. If no actions would be taken, exit success. Otherwise prompt the user to confirm before proceeding (unless `FORCE=1` or `--force`).

**Design note — no tempfile action list.** Earlier drafts of this migration persisted the classification as a TSV sidecar and re-read it in Steps 3 and 4 via `while IFS=$'\t' read -r ...`. On Windows MINGW64 this pattern intermittently injected trailing `\r` into the last read field (the SHA), causing every subsequent comparison to mismatch and producing bogus "UPDATE all 37 files" output. The fix is structural: steps 2, 3a, and 4 each re-iterate the manifest directly through `jq` (which is CR-clean) and re-classify inline. The manifest is small (~37 entries) and `sha256sum` is cheap, so re-computation cost is negligible. No TSV round-trip = no CR hazard class.

```bash
SKIP_COUNT=0
MERGE_COUNT=0
INSTALL_COUNT=0
PREVIEW_LINES=""

# classify_and_preview <source> <target> <expected_sha>
#   Writes one preview line to $PREVIEW_LINES and increments the matching counter.
#   No persistent sidecar — each step re-iterates the manifest.
classify_and_preview() {
  local source="$1"
  local target="$2"
  local expected="$3"
  local action

  if [[ ! -f "$target" || ! -s "$target" ]]; then
    # Missing OR zero-byte local → INSTALL. Zero-byte files carry no
    # preservable state (placeholder leftover, truncation from a prior
    # aborted run, touch by another tool) — treat identically to missing.
    action="INSTALL"
    INSTALL_COUNT=$((INSTALL_COUNT + 1))
  else
    local local_sha
    local_sha="$(sha256sum "$target" | awk '{print $1}')"
    if [[ "$local_sha" == "$expected" ]]; then
      action="SKIP"
      SKIP_COUNT=$((SKIP_COUNT + 1))
    else
      action="MERGE"
      MERGE_COUNT=$((MERGE_COUNT + 1))
    fi
  fi

  PREVIEW_LINES+="  [${action}]	${target}"$'\n'
}

# Iterate skills + agents. jq emits tab-separated rows; read inline without
# persisting to a tempfile. Strip any stray \r from fields defensively in case
# a future manifest source introduces CRLF line endings — cheap insurance on
# top of the structural no-tempfile fix.
classify_from_array() {
  local array_name="$1"
  local source target sha
  while IFS=$'\t' read -r source target sha; do
    source="${source%$'\r'}"
    target="${target%$'\r'}"
    sha="${sha%$'\r'}"
    [[ -z "$source" ]] && continue
    classify_and_preview "$source" "$target" "$sha"
  done < <(jq -r ".${array_name}[] | [.source, .target, .sha256] | @tsv" "$MANIFEST_TMP")
}

classify_from_array skills
classify_from_array agents

echo ""
echo "=== Migration 022 Dry-Run Preview ==="
echo ""
printf '%s' "$PREVIEW_LINES" | sort
echo ""
echo "Summary: ${SKIP_COUNT} skip / ${MERGE_COUNT} merge / ${INSTALL_COUNT} install"
echo ""

# Nothing to do? Exit success before prompting.
if [[ "$MERGE_COUNT" -eq 0 && "$INSTALL_COUNT" -eq 0 ]]; then
  echo "PASS: all skills + agents already match the manifest — nothing to apply"
  exit 0
fi

# Prompt unless forced.
if [[ "$FORCE" -ne 1 ]]; then
  echo "Apply ${MERGE_COUNT} merge(s) + ${INSTALL_COUNT} install(s)?"
  echo "  INSTALL  = byte-download from upstream (missing files, no local state to preserve)"
  echo "  MERGE    = LLM hand-merge (existing files, local customizations preserved)"
  echo "[y/N]"
  read -r confirm < /dev/tty
  confirm="${confirm%$'\r'}"
  case "$confirm" in
    y|Y|yes|YES) ;;
    *) echo "ABORT: user declined — no files written"; exit 0 ;;
  esac
else
  echo "FORCE=1 — skipping confirmation prompt (MERGE still hand-merges, not byte-overwrites)"
fi
```

---

### Step 3a — Apply INSTALL actions (bash)

For each `[INSTALL]` entry (missing local file): fetch the upstream file from the bootstrap repo via `gh api`, verify fetched SHA matches the manifest expectation (catches upstream-moved-mid-run), create the target directory, and atomically replace the target with `mv`. Byte-download is correct here because there is no local state to preserve.

```bash
INSTALL_FAILURES=0
declare -A INSTALLED_TARGETS=()

install_from_array() {
  local array_name="$1"
  local source target sha
  while IFS=$'\t' read -r source target sha; do
    source="${source%$'\r'}"
    target="${target%$'\r'}"
    sha="${sha%$'\r'}"
    [[ -z "$source" ]] && continue

    # Only INSTALL — skip files that already exist AND are non-empty. Their SHA
    # was either SKIP or MERGE; Step 3b handles MERGE, SKIP needs no action.
    # Zero-byte files fall through to INSTALL: they carry no preservable state.
    [[ -f "$target" && -s "$target" ]] && continue

    local target_dir
    target_dir="$(dirname "$target")"
    mkdir -p "$target_dir"

    # Fetch file from bootstrap repo. gh api returns the file contents as a
    # base64-encoded "content" field inside a JSON envelope. --jq .content
    # extracts it; base64 -d decodes to the raw file bytes.
    local tmp_file
    tmp_file="$(mktemp -t bootstrap-fetch.XXXXXX)"
    if ! gh api "repos/${BOOTSTRAP_OWNER}/${BOOTSTRAP_REPO}/contents/${source}?ref=${BOOTSTRAP_REF}" --jq .content | base64 -d > "$tmp_file"; then
      echo "FAIL: could not fetch ${source} from ${BOOTSTRAP_OWNER}/${BOOTSTRAP_REPO}"
      rm -f "$tmp_file"
      INSTALL_FAILURES=$((INSTALL_FAILURES + 1))
      continue
    fi

    # Verify fetched-file SHA matches manifest expected SHA. If the upstream
    # moved between Step 1 (manifest fetch) and Step 3a (file fetch), bail on
    # this file rather than writing a SHA that doesn't match the manifest we
    # validated against.
    local fetched_sha
    fetched_sha="$(sha256sum "$tmp_file" | awk '{print $1}')"
    if [[ "$fetched_sha" != "$sha" ]]; then
      echo "FAIL: fetched SHA mismatch for ${source} (got ${fetched_sha}, expected ${sha}) — upstream changed between manifest fetch and file fetch; re-run migration"
      rm -f "$tmp_file"
      INSTALL_FAILURES=$((INSTALL_FAILURES + 1))
      continue
    fi

    # Atomic replace: move the tmp file into place. mv within the same
    # filesystem is atomic; the target either has the old content or the new
    # content at any observable moment.
    mv "$tmp_file" "$target"
    INSTALLED_TARGETS["$target"]="$sha"
    echo "  INSTALL: ${target}"
  done < <(jq -r ".${array_name}[] | [.source, .target, .sha256] | @tsv" "$MANIFEST_TMP")
}

install_from_array skills
install_from_array agents

if [[ "$INSTALL_FAILURES" -gt 0 ]]; then
  echo "ERROR: ${INSTALL_FAILURES} INSTALL file(s) failed — see failures above. Bootstrap state NOT updated. Safe to re-run after resolving."
  exit 1
fi

echo "PASS: all INSTALL actions applied"
```

---

### Step 3b — Apply MERGE actions (LLM-driven hand-merge)

**This step is instructions to the LLM orchestrator running `/migrate-bootstrap`. It is NOT a bash block that runs on its own.** The reason: mechanical byte-overwrite of an existing skill/agent file silently regresses any project-specific customizations the user has made (custom `allowed-tools` entries, added force-read rules, extra body sections, tweaked descriptions, project-tuned effort levels). The only way to apply upstream improvements without losing local work is to read both versions and reason about the merge.

#### Enumerate MERGE targets

First, the LLM runs this bash block to produce a newline-separated list of MERGE targets (one line per file: `source<TAB>target<TAB>expected_sha`). The list is printed to stdout so the LLM can read it from the tool result — no tempfile persistence required.

```bash
echo "=== Migration 022 MERGE Targets ==="
merge_from_array() {
  local array_name="$1"
  local source target sha
  while IFS=$'\t' read -r source target sha; do
    source="${source%$'\r'}"
    target="${target%$'\r'}"
    sha="${sha%$'\r'}"
    [[ -z "$source" ]] && continue
    [[ ! -f "$target" || ! -s "$target" ]] && continue   # INSTALL handled by Step 3a (includes zero-byte)

    local local_sha
    local_sha="$(sha256sum "$target" | awk '{print $1}')"
    if [[ "$local_sha" != "$sha" ]]; then
      printf 'MERGE\t%s\t%s\t%s\n' "$source" "$target" "$sha"
    fi
  done < <(jq -r ".${array_name}[] | [.source, .target, .sha256] | @tsv" "$MANIFEST_TMP")
}

merge_from_array skills
merge_from_array agents
echo "=== End MERGE Targets ==="
```

If the output contains zero `MERGE\t...` lines, skip to Step 4 — there is nothing to hand-merge. Otherwise, for every `MERGE\t<source>\t<target>\t<sha>` line, the LLM performs the hand-merge procedure below.

#### Per-file hand-merge procedure

For each `MERGE` target, the LLM orchestrator:

1. **Fetch the upstream template to a tmp file** via `gh api`, without overwriting the local file. Verify the fetched SHA matches the manifest SHA (same TOCTOU guard as Step 3a) — if upstream changed between Step 2 preview and this fetch, abort this target rather than merging against content the user never saw in the preview:

   ```bash
   TMP_UPSTREAM="$(mktemp -t bootstrap-upstream.XXXXXX.md)"
   if ! gh api "repos/${BOOTSTRAP_OWNER}/${BOOTSTRAP_REPO}/contents/${source}?ref=${BOOTSTRAP_REF}" --jq .content | base64 -d > "$TMP_UPSTREAM"; then
     echo "FAIL-MERGE: ${target} — upstream fetch failed"
     rm -f "$TMP_UPSTREAM"
     continue   # to next MERGE target
   fi
   fetched_sha="$(sha256sum "$TMP_UPSTREAM" | awk '{print $1}')"
   if [[ "$fetched_sha" != "$sha" ]]; then
     echo "FAIL-MERGE: ${target} — upstream fetch SHA mismatch (got ${fetched_sha}, expected ${sha}) — upstream changed between manifest fetch and merge fetch; re-run migration"
     rm -f "$TMP_UPSTREAM"
     continue   # to next MERGE target
   fi
   ```

2. **Read the local file** using the `Read` tool on the target path. This gives the current state of the file including any project-specific customizations.

3. **Read the upstream template** using the `Read` tool on `$TMP_UPSTREAM`. This gives the latest upstream intent.

4. **Produce a hand-merged result.** Apply the merge rubric below to reconcile the two. The output is a complete file body — not a patch, not a diff, the full final contents ready to write.

5. **Write the merged result** using the `Edit` tool (for surgical section replacements) or the `Write` tool (for full-file rewrites where the entire body is restructured). Target path is the local file, not the tmp file.

6. **Report the outcome** as one line to the user summary, using this format:

   ```
   MERGE: <target> — <N> upstream change(s) incorporated, <M> local customization(s) preserved[, <K> conflict(s) resolved: <resolution>]
   ```

   Example:
   ```
   MERGE: .claude/skills/commit/SKILL.md — 3 upstream changes incorporated, 2 local customizations preserved
   MERGE: .claude/agents/proj-debugger.md — 1 upstream change incorporated, 4 local customizations preserved, 1 conflict resolved: local STEP 0 force-read list kept; upstream reordering of sections 4-6 applied
   ```

7. **Clean up the tmp file**: `rm -f "$TMP_UPSTREAM"`.

#### Merge rubric

The merge goal is: **apply every non-conflicting upstream improvement while preserving every project-specific customization the local file has accrued.** In practice:

- **YAML frontmatter — field-by-field reconciliation.** For each key in the frontmatter block (between the opening and closing `---` lines):
  - Key present only upstream → add to merged output with upstream value.
  - Key present only locally → keep local value.
  - Key present in both with identical values → keep as-is.
  - Key present in both with different values → **prefer local** for project-tuning keys (`model`, `effort`, `allowed-tools`, `maxTurns`, `color`, any custom field the project added). **Prefer upstream** for structural keys where the upstream version reflects a schema improvement (`name` is always upstream since the filename is the key, `description` is upstream unless the local has obviously project-specific wording, `paths` is upstream if it reflects new auto-activation hooks).
  - When in doubt on a frontmatter conflict → prefer local, and flag it in the MERGE report as `1 conflict resolved: frontmatter key '<key>' kept local value`.

- **Body content — section-aware merge.** For each `##`/`###` section in the file:
  - Section present only upstream (new in template) → append to merged output in the upstream-relative position (before/after the anchor sections that exist in both).
  - Section present only locally (project addition) → keep in place.
  - Section present in both → diff the bodies. If upstream has added bullets/paragraphs without removing any local lines, incorporate the additions. If upstream has restructured the section prose, **prefer the upstream prose** unless the local has added project-specific substance (additional rules, project-tuned examples, references to project files). Never drop project-specific substance silently.
  - Section present locally but **removed upstream**, and local body differs from any known prior upstream (project has modified the content of a section upstream has since dropped) → **keep local**, and flag in the MERGE report as `1 conflict resolved: section '## <name>' preserved — removed upstream but local has project-specific content; review whether still needed`. Rationale: an upstream removal may reflect a refactor (feature moved elsewhere) or a deprecation — either case, local project-specific content in that section represents work that should not vanish silently. The user can manually drop the section later after reviewing why upstream dropped it.
  - Code blocks inside sections — if the upstream block has semantic changes (different flags, different commands, new error handling) and the local block is unchanged from a prior upstream version, take upstream. If the local block has project-specific substitutions (custom paths, project-specific commands), reconcile line-by-line.

- **Force-read lists, allowed-tools lists, dispatch-policy blocks — union-preserving.** If the local has added entries to any list-style section that the upstream didn't have, keep the local additions. If the upstream has added new entries, add them too. Result: the union of both, de-duplicated.

- **Red flags — preserve local on any of these.** Never let an upstream merge strip these without explicit reasoning:
  - Custom entries in STEP 0 force-read lists (project added a domain rule).
  - Custom entries in `allowed-tools` frontmatter (project granted access to a project-specific MCP server).
  - Project-specific prose in descriptions, bodies, or examples (mentions project name, project files, project conventions).
  - `memory: project` frontmatter flag (project enabled agent stateful memory).
  - `skills:` list in agent frontmatter (project preloads domain knowledge).
  - Entire sections named "Project-specific", "Local overrides", or similar.

- **When uncertain → keep local.** The upstream can always be re-merged in a future migration; regressing local customizations is harder to recover from. If the LLM cannot confidently reason about whether an upstream change would clobber meaningful local state, it keeps local and notes the uncertainty in the MERGE report: `1 conflict resolved: local kept pending review — upstream restructured § "Dispatch" ambiguously`.

- **Dry-run option for review-heavy projects.** If the project has extensive customizations and the user wants to inspect each merge before it lands, the LLM can write the merged output to `<target>.merge-proposed` instead of the target itself, list the proposed files, and prompt the user to review + accept. This is OFF by default (migration completes in one pass); enable only on request.

#### Failure handling

- Fetch failure (upstream unreachable, file moved) → report `FAIL-MERGE: <target> — upstream fetch failed: <reason>` and continue with the next target. At the end of Step 3b, if any MERGE failed, set the migration to FAIL and do NOT update bootstrap state.
- Merge impossible (local file is radically divergent, e.g. a completely different skill with the same filename) → report `FAIL-MERGE: <target> — divergence too large for safe merge; preserve local, require manual resolution` and continue. Migration does NOT overwrite the file.
- Write failure (Edit/Write tool error) → report `FAIL-MERGE: <target> — write error: <reason>` and continue.

At the end of Step 3b, if any MERGE ended in FAIL-MERGE, the migration exits non-zero without updating bootstrap state. The user can re-run after resolving individual conflicts manually.

---

### Step 4 — Verify

Re-run the classification pass from Step 2 to confirm the apply phase left the tree in a consistent state. The verify logic is intentionally looser than the dry-run classifier: merged files will NOT match the upstream SHA by design (that is the whole point of hand-merge — local customizations preserved). So the verify does not fail on SHA mismatch for files that were in the MERGE set; it fails only on:

- Missing files (INSTALL target didn't land)
- Empty files (merge or install produced a zero-byte artifact)
- Files lacking the YAML frontmatter opener (`---` at line 1) for skills/agents where one is required
- INSTALL targets whose post-write SHA does NOT match the manifest (byte-download should be exact)

Merged files are reported as `MERGED` (informational), not `DRIFT` (failure).

```bash
VERIFY_OK=0
VERIFY_MERGED=0
VERIFY_FAIL=0
VERIFY_FAILURES=""

verify_one() {
  local target="$1"
  local expected="$2"

  if [[ ! -f "$target" ]]; then
    VERIFY_FAIL=$((VERIFY_FAIL + 1))
    VERIFY_FAILURES+="  [MISSING] ${target}"$'\n'
    return
  fi
  if [[ ! -s "$target" ]]; then
    VERIFY_FAIL=$((VERIFY_FAIL + 1))
    VERIFY_FAILURES+="  [EMPTY] ${target}"$'\n'
    return
  fi

  # YAML frontmatter sanity: skills/agents must start with a --- fence.
  local first_line
  first_line="$(head -n1 "$target")"
  first_line="${first_line%$'\r'}"
  if [[ "$first_line" != "---" ]]; then
    VERIFY_FAIL=$((VERIFY_FAIL + 1))
    VERIFY_FAILURES+="  [NO-FRONTMATTER] ${target}"$'\n'
    return
  fi

  local local_sha
  local_sha="$(sha256sum "$target" | awk '{print $1}')"
  if [[ "$local_sha" == "$expected" ]]; then
    VERIFY_OK=$((VERIFY_OK + 1))
  elif [[ -n "${INSTALLED_TARGETS[$target]+x}" ]]; then
    # This target was byte-downloaded by Step 3a from upstream. Its on-disk SHA
    # must match the manifest SHA. Any drift here indicates post-mv corruption
    # (antivirus rewrite, power loss, disk full, permission issue) — NOT an
    # expected merge outcome. Hard fail.
    VERIFY_FAIL=$((VERIFY_FAIL + 1))
    VERIFY_FAILURES+="  [DRIFT-INSTALL] ${target} — post-install SHA does not match manifest"$'\n'
  else
    # SHA differs from upstream — expected for MERGE targets (local customizations
    # preserved). Treat as informational, not failure.
    VERIFY_MERGED=$((VERIFY_MERGED + 1))
  fi
}

verify_from_array() {
  local array_name="$1"
  local source target sha
  while IFS=$'\t' read -r source target sha; do
    source="${source%$'\r'}"
    target="${target%$'\r'}"
    sha="${sha%$'\r'}"
    [[ -z "$target" ]] && continue
    verify_one "$target" "$sha"
  done < <(jq -r ".${array_name}[] | [.source, .target, .sha256] | @tsv" "$MANIFEST_TMP")
}

verify_from_array skills
verify_from_array agents

echo ""
echo "=== Migration 022 Verify ==="
echo "OK (matches upstream): ${VERIFY_OK}   MERGED (local preserved): ${VERIFY_MERGED}   FAIL: ${VERIFY_FAIL}"

if [[ "$VERIFY_FAIL" -gt 0 ]]; then
  echo ""
  echo "Failures:"
  printf '%s' "$VERIFY_FAILURES"
  echo ""
  echo "ERROR: post-apply verification failed — bootstrap state NOT updated. Safe to re-run."
  exit 1
fi

echo "PASS: all files exist, non-empty, frontmatter-valid; ${VERIFY_MERGED} file(s) carry merged local customizations"
```

---

### Register in `migrations/index.json`

The migration runner (`/migrate-bootstrap`) discovers migrations via `migrations/index.json`, not the directory listing. An entry must be present in the array before this migration can be applied by a client project.

```json
{
  "id": "022",
  "file": "022-template-fetch-bootstrap.md",
  "description": "Replace LLM-rendered skill/agent bootstrap with template-fetch from tracked templates/ directory. Modules 05+06 become thin fetch loops. Per-file SHA classification: missing files INSTALL via byte-download from upstream (no local state to preserve); existing files that differ from upstream MERGE via LLM hand-merge (preserves project-specific customizations while incorporating upstream improvements); identical files SKIP. Dry-run preview + explicit confirmation before writes; --force skips prompt only, never downgrades MERGE to byte-overwrite. No TSV sidecar — each step re-iterates manifest through jq (MINGW64 CR-safe, no trailing-\\r hazard). Verify is loose for merged files (checks existence + non-empty + YAML frontmatter fence, not SHA match) since merged files differ from upstream by design.",
  "breaking": false
}
```

Add this entry to the `migrations` array in `migrations/index.json`, immediately after the `021` entry.

---

### Rules for migration scripts

- **`gh api` only for GitHub content fetch** — per `.claude/rules/general.md`, every remote fetch uses `gh api repos/{owner}/{repo}/contents/{path}?ref={ref} --jq .content | base64 -d`. No `WebFetch`, no `curl` to raw.githubusercontent.com, no general-purpose agents.
- **Self-contained** — the migration does not reference any gitignored path for remote fetch. Remote sources are all tracked files under `templates/` in the bootstrap repo; local destinations are `.claude/skills/` and `.claude/agents/` inside the client project (gitignored, which is fine — migrations write there by design).
- **Read-before-write** — Step 3a (INSTALL) only writes files that were absent at classification time. Step 3b (MERGE) explicitly reads both local and upstream copies before producing the merged output — hand-merge is the canonical read-before-write pattern, delegated to the LLM orchestrator because a semantic merge cannot be expressed in bash.
- **Idempotent** — per-file SHA-compare gate in Step 2. Running the migration twice with no intervening upstream changes and no local edits since the last run produces `SKIP_COUNT == total`, `MERGE_COUNT == 0`, `INSTALL_COUNT == 0`, and exits before the confirmation prompt. After a successful hand-merge, the local file will NOT match upstream SHA, so the second run will classify it as MERGE again — the LLM rubric should detect "no upstream changes since last merge" and produce a zero-change report.
- **Abort on error** — `set -euo pipefail` at the top. Any INSTALL fetch failure, INSTALL SHA mismatch, MERGE failure, or write error sets the failure counter and exits non-zero without updating bootstrap state. Safe to re-run.
- **Glob-safe agent paths** — the migration iterates the manifest `agents` array literally. It does NOT rely on shell globs, so files like `proj-code-writer-markdown.md` (which are NOT in the manifest) are never touched. Per `.claude/rules/general.md` migrations-must-glob-agent-filenames: that rule applies to migrations that patch per-language writer/test-writer specialists; this migration intentionally does not touch them (see Notes).
- **MINGW64-safe** — no TSV tempfile round-trip (CR hazard class eliminated structurally, see Step 2 design note). Each step re-iterates the manifest through `jq` directly. Defensive `${var%$'\r'}` strip after each `read` as belt-and-suspenders. Uses `mktemp` + `mv` (no `sed -i`), `awk` for counting, `jq` for JSON parsing. No `readarray`, no bashisms absent from 4.x.

---

## Verify

The top-level verify runs the same existence + non-empty + frontmatter check as Step 4, plus the index.json sentinel, against a fresh manifest fetch. SHA mismatches are informational (merged files), not failures — the only hard failures are missing, empty, or unreadable files.

```bash
#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP_OWNER="${BOOTSTRAP_OWNER:-<owner>}"
BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-claude-bootstrap}"
BOOTSTRAP_REF="${BOOTSTRAP_REF:-main}"

if [[ "$BOOTSTRAP_OWNER" == "<owner>" ]]; then
  echo "ERROR: BOOTSTRAP_OWNER not set for verify step"
  exit 1
fi

command -v gh >/dev/null 2>&1 || { echo "ERROR: gh required"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required"; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "ERROR: sha256sum required"; exit 1; }

MANIFEST_TMP="$(mktemp -t bootstrap-verify-manifest.XXXXXX.json)"
trap 'rm -f "$MANIFEST_TMP"' EXIT

gh api "repos/${BOOTSTRAP_OWNER}/${BOOTSTRAP_REPO}/contents/templates/manifest.json?ref=${BOOTSTRAP_REF}" --jq .content | base64 -d > "$MANIFEST_TMP"

FAIL=0
MERGED_COUNT=0
OK_COUNT=0

verify_one() {
  local target="$1"
  local expected="$2"

  if [[ ! -f "$target" ]]; then
    echo "FAIL-VERIFY: $target missing"
    FAIL=1
    return
  fi
  if [[ ! -s "$target" ]]; then
    echo "FAIL-VERIFY: $target empty"
    FAIL=1
    return
  fi

  local first_line
  first_line="$(head -n1 "$target")"
  first_line="${first_line%$'\r'}"
  if [[ "$first_line" != "---" ]]; then
    echo "FAIL-VERIFY: $target missing YAML frontmatter fence"
    FAIL=1
    return
  fi

  local local_sha
  local_sha="$(sha256sum "$target" | awk '{print $1}')"
  if [[ "$local_sha" == "$expected" ]]; then
    OK_COUNT=$((OK_COUNT + 1))
  else
    MERGED_COUNT=$((MERGED_COUNT + 1))
  fi
}

verify_from_array() {
  local array_name="$1"
  local target sha
  while IFS=$'\t' read -r target sha; do
    target="${target%$'\r'}"
    sha="${sha%$'\r'}"
    [[ -z "$target" ]] && continue
    verify_one "$target" "$sha"
  done < <(jq -r ".${array_name}[] | [.target, .sha256] | @tsv" "$MANIFEST_TMP")
}

verify_from_array skills
verify_from_array agents

# Verify the index.json entry exists.
if grep -qF '"id": "022"' migrations/index.json; then
  echo "PASS: migrations/index.json contains 022 entry"
else
  echo "FAIL-VERIFY: migrations/index.json missing 022 entry"
  FAIL=1
fi

[[ $FAIL -eq 0 ]] || exit 1
echo "PASS: ${OK_COUNT} files match upstream, ${MERGED_COUNT} files carry preserved local customizations"
```

Failure of any verify step → `/migrate-bootstrap` aborts and does NOT update `bootstrap-state.json`. Safe to retry after fixing the failure. SHA drift from upstream is NOT a failure — merged files are expected to differ from upstream (that is the explicit goal of hand-merge).

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → `"022"`
- append `{ "id": "022", "applied_at": "<ISO8601>", "description": "Template-fetch bootstrap" }` to `applied[]`

---

## Notes

### `{owner}` / `BOOTSTRAP_OWNER` resolution

The migration needs to know the GitHub owner of the bootstrap repo to build `gh api repos/{owner}/claude-bootstrap/...` URLs. Three options, in order of preference:

1. **Environment variable** — `export BOOTSTRAP_OWNER=your-github-username` before running the migration. This is the cleanest path for `/migrate-bootstrap` automation (the skill can set it from `.claude/bootstrap-state.json` `bootstrap_repo` field).
2. **Edit the migration in place** — replace the literal `<owner>` default in the Prerequisites section with your username. Not recommended because the migration file is version-controlled in the bootstrap repo itself; edits there propagate to every other client project.
3. **`.claude/bootstrap-state.json` read** — `/migrate-bootstrap` can extract `bootstrap_repo` (set by Module 00) and export `BOOTSTRAP_OWNER` automatically before shelling into the migration script. This is how migration 002 (`/migrate-bootstrap` switch to index.json discovery) intends the handoff to work.

### Agent-templates are NOT synced by this migration

`templates/manifest.json` has three arrays: `skills`, `agents`, `agent-templates`. The third array contains `code-writer.template.md` and `test-writer.template.md` — these are NOT copied verbatim. Module 07 renders them per-language with sed substitution of `{lang}`, `{build_cmd}`, `{test_cmd}`, `{lint_cmd}` placeholders, producing client-specific files like `proj-code-writer-markdown.md`, `proj-test-writer-python.md`, etc.

This migration does not touch the rendered per-language files. Two reasons:

1. **They're not in the manifest `agents` array**, so the iteration above correctly skips them.
2. **They're project-specific** — the placeholders have already been substituted with this project's build/test/lint commands. Overwriting them from the upstream template (which still contains `{lang}` literals) would break the agent specs.

If you need updated per-language writer/test-writer specialists after this migration:
- Re-run `/module-write 07` to regenerate them from the updated `agent-templates` entries.
- Or manually diff `templates/agents/code-writer.template.md` (fetched via `gh api`) against your `.claude/agents/proj-code-writer-<lang>.md` and merge relevant changes.

### `proj-code-reviewer` is NOT in the manifest

The project-specific code reviewer is generated by Module 07 Phase 5 with project-aware context (languages detected, frameworks in use, convention files discovered). It is not a static template and is not listed in `templates/manifest.json`. This migration correctly does not touch `.claude/agents/proj-code-reviewer.md`; Module 07 remains the source of truth for that file.

### Offline fallback

If `gh` is unavailable or unauthenticated and `gh auth login` is not an option, clone the bootstrap repo directly and copy the templates tree:

```bash
# One-time clone to a temp location.
git clone https://github.com/${BOOTSTRAP_OWNER}/claude-bootstrap.git /tmp/claude-bootstrap

# Copy skill bodies verbatim.
mkdir -p .claude/skills
cp -r /tmp/claude-bootstrap/templates/skills/* .claude/skills/

# Copy agent bodies verbatim.
mkdir -p .claude/agents
for f in /tmp/claude-bootstrap/templates/agents/*.md; do
  # Skip .template.md files — those are rendered per-language by Module 07.
  case "$(basename "$f")" in
    *.template.md) continue ;;
  esac
  cp "$f" .claude/agents/
done

# Clean up.
rm -rf /tmp/claude-bootstrap
```

The offline path bypasses SHA verification. After copying, run the Verify script above against a manually-placed manifest to confirm SHAs match.

### Why dry-run + confirmation

Overwriting user-edited skill/agent files silently is a footgun. Users may have locally patched a skill for project-specific behavior; the dry-run preview surfaces exactly which files will change before any writes happen. The `--force` flag and `FORCE=1` env var exist for automation (`/migrate-bootstrap` invoking the migration non-interactively after collecting user consent at the skill level). `--force` only skips the confirmation prompt — it does NOT downgrade `[MERGE]` to a byte-overwrite. Never remove the default-dry-run behavior without a corresponding user-facing affordance.

### Why hand-merge instead of byte-overwrite for existing files

The original draft of this migration (pre-fix, applied to the bootstrap repo itself 2026-04-14) used a single Step 3 that byte-overwrote every `[UPDATE]` entry via `mv` from a tmp file. That approach is correct for **initial bootstrap** (where the client project has no prior skill/agent content to regress) but wrong for **migration of an already-bootstrapped project** (where the user may have customized skills/agents for project-specific needs).

Concrete failure mode: a user adds a project-specific MCP server to `.claude/agents/proj-debugger.md`'s `allowed-tools`, customizes the STEP 0 force-read list to include a project domain rule, and adds a "Project-specific debugging playbook" section to the body. Running byte-overwrite migration 022 silently regresses all three. The user has no warning (the file shows as `[UPDATE]` in the preview, indistinguishable from a fresh install), no diff, and no recovery path except `git restore` — which does not help if the customizations were never committed.

Hand-merge fixes this by making the LLM orchestrator responsible for reconciling local and upstream. The trade-off is slower (each merge involves two Read calls, an LLM reasoning pass, and an Edit/Write call) and less deterministic (two runs may produce slightly different merge outcomes on the same inputs). The slowness is acceptable — a typical client project has 0-3 MERGE entries, not the full 37. The non-determinism is acceptable too — the merge rubric prefers local when in doubt, so re-runs converge on stable output.

**INSTALL stays byte-download.** Missing local files have no state to preserve. A missing file means either the project never had it (new skill/agent shipped upstream after bootstrap) or the user deleted it on purpose (unlikely, and if so they can delete it again). Either way, byte-download from upstream is the correct behavior.

### What if `--force` is set and the user wants mechanical overwrite?

They don't get it. `--force` skips the confirmation prompt; it does not change the MERGE semantics. If a user genuinely wants to discard local customizations and fall back to upstream verbatim, they run:

```bash
# From the project root, for a specific skill:
gh api "repos/${BOOTSTRAP_OWNER}/claude-bootstrap/contents/templates/skills/<name>/SKILL.md?ref=main" --jq .content | base64 -d > .claude/skills/<name>/SKILL.md
```

Or for a clean slate, delete `.claude/skills/` + `.claude/agents/` and re-run migration 022 — every entry will classify as `[INSTALL]` and byte-download from upstream.

---

## Rollback

`.claude/` is gitignored in most bootstrapped projects, so `git restore` is only useful if the project commits `.claude/` directly or has a companion repo mirror.

**With companion repo (recommended):** `/sync reset` pulls the last-known-good `.claude/skills/` + `.claude/agents/` from `~/.claude-configs/<project>/` back into the project, then rerun migration 022 if needed.

**Committed `.claude/`:** `git restore .claude/skills/ .claude/agents/` from a pre-migration commit. Any files that were `[INSTALL]` (absent before the migration) will not be present in the pre-migration commit and must be manually removed with `rm`. `[MERGE]` files revert to their pre-merge state.

**Gitignored `.claude/` with no companion:** Per-file manual rollback only. If the user did not snapshot `.claude/` before running the migration, the only recovery path for a regretted MERGE is to re-fetch from upstream (loses local customizations — the opposite of what the migration tried to preserve). Future: add a `/snapshot` skill that tars `.claude/` into `.claude/.snapshots/` before a migration runs.

No state-file rollback needed — `.claude/bootstrap-state.json` is only updated after Verify passes, and the migration is re-runnable from any consistent state.
