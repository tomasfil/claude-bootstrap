# Migration 024 — Plan-writer risk classification + Failure Modes section

> Retrofit already-bootstrapped client projects by patching `.claude/agents/proj-plan-writer.md` to add a `## Risk Classification` section, a `#### Risk: {low|medium|high|critical}` line in the task template, and a `#### Failure Modes` sub-section in the task template. Idempotent per-file; safe to re-run. Sentinel-guarded via a literal-string check on the risk template line.

---

## Metadata

```yaml
id: "024"
breaking: false
affects: [agents]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

Fields:
- `id`: `"024"`
- `breaking`: `false` — additive patches, no existing behavior removed. Existing plans and batch files continue to render correctly; the new sections only affect plan-writer output going forward.
- `affects`: `[agents]` — touches one agent file only (`.claude/agents/proj-plan-writer.md`). No skills, modules, hooks, settings, or techniques changed.
- `requires_mcp_json`: `false` — no MCP dependency; the patch is pure markdown content insertion.
- `min_bootstrap_version`: `"6.0"` — earliest bootstrap version that contains the `proj-plan-writer` agent with the `## Tier Classification` + `## Dispatch Unit Packing` sections this migration anchors against.

---

## Problem

The `proj-plan-writer` agent ships tier-classified, dependency-ordered task plans but does not emit a risk classification or a failure-mode analysis per task. Two consequences:

1. Downstream harness gates (e.g. a `TaskCompleted` completion gate introduced alongside this migration in 025) cannot read a risk marker out of task subject/description text — the marker does not exist. The gate defaults to "no marker = low risk" and never fires, silently degrading into a no-op.
2. Plans carry no visible failure-mode discipline. Plan-writer is a senior-architect role — failure-mode thinking is expected — but the output format never forced the think-step onto paper. Plans ship without concrete production-failure / detection / rollback / invalidation / uncertainty answers per task, which also means plan-review cannot cheaply audit whether the thinking was done.

Root cause: the plan-writer template (`templates/agents/proj-plan-writer.md` in the bootstrap repo, which generates `.claude/agents/proj-plan-writer.md` in client projects) had only a `## Tier Classification` section; no `## Risk Classification` section existed, and the `## Output Format — Batch Files` task template block had only `#### Tier:` and `#### Dep set:` fields, no `#### Risk:` and no `#### Failure Modes`. This migration retrofits client projects with the same additions applied to the bootstrap template.

---

## Changes

- `.claude/agents/proj-plan-writer.md` (client project):
  - Insert a new `## Risk Classification` section immediately after the `## Tier Classification` section ends (specifically after the literal line `**FORBIDDEN in tier classification:** MUST NOT estimate LOC, token counts, or tool-call counts to tier a task. Plan-writer sees intent only, not generated code. Use intent-level signals ONLY (dep topology, step count, verb, file count, layer). Output size is not a planning-time signal.`) and before the `## Dispatch Unit Packing` heading. Four risk levels `low | medium | high | critical` with intent-level criteria, explicit scope rule for when `#### Failure Modes` is required, and the "bump down or flag insufficient context" fallback.
  - Insert `#### Risk: {low|medium|high|critical}` line immediately after the existing `#### Tier: {micro|moderate|complex}` line inside the `## Output Format — Batch Files` task template block.
  - Insert `#### Failure Modes` sub-section with the five numbered one-line questions immediately after the existing `#### Dep set: {files+symbols this specific task touches}` line in the same task template block.

Idempotency: every patch is gated by a literal-string `grep -qF '#### Risk: {low|medium|high|critical}'` sentinel check against the target file. If the sentinel is already present the patch is skipped with a `SKIP` log line. A second run produces zero modifications. **No regex with `.*` anywhere** — all anchor matches use `grep -qF` or awk exact-string equality (`$0 == "..."`).

Bootstrap self-alignment: the corresponding additions were already made to `templates/agents/proj-plan-writer.md` in the bootstrap repo. Client-project bootstrap refreshes (via `/migrate-bootstrap` or a fresh bootstrap) will regenerate `.claude/agents/proj-plan-writer.md` with the Risk Classification section and the `#### Risk:` / `#### Failure Modes` template entries in place; this migration brings already-bootstrapped client projects forward without a full refresh.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }

TARGET=".claude/agents/proj-plan-writer.md"

if [[ ! -f "$TARGET" ]]; then
  echo "SKIP: $TARGET not present — plan-writer agent not installed in this project"
  exit 0
fi

# Sentinel: literal string that marks the risk classification template line as applied.
# Match must be exact — no regex, no interpolation surprises.
SENTINEL='#### Risk: {low|medium|high|critical}'
```

---

### Step A — Verify literal anchors before patching

Every anchor used by the awk passes must exist in the current file as a literal line. If any anchor is missing the file has drifted from the bootstrap template (hand-edited, partially migrated, older bootstrap version) and this migration bails with a clear error rather than corrupt it. Literal-anchor checks use `grep -qF` only — no regex.

```bash
if grep -qF "$SENTINEL" "$TARGET"; then
  echo "SKIP: 024 already applied to $TARGET (sentinel present)"
  exit 0
fi

ANCHOR_TIER_CLOSING='**FORBIDDEN in tier classification:** MUST NOT estimate LOC, token counts, or tool-call counts to tier a task. Plan-writer sees intent only, not generated code. Use intent-level signals ONLY (dep topology, step count, verb, file count, layer). Output size is not a planning-time signal.'
ANCHOR_DISPATCH_HEADING='## Dispatch Unit Packing'
ANCHOR_TIER_TEMPLATE='#### Tier: {micro|moderate|complex}'
ANCHOR_DEPSET_TEMPLATE='#### Dep set: {files+symbols this specific task touches}'

for anchor in "$ANCHOR_TIER_CLOSING" "$ANCHOR_DISPATCH_HEADING" "$ANCHOR_TIER_TEMPLATE" "$ANCHOR_DEPSET_TEMPLATE"; do
  if ! grep -qF "$anchor" "$TARGET"; then
    echo "ERROR: anchor not found in $TARGET: $anchor"
    echo "Manual patch required — the file has drifted from the bootstrap template."
    exit 1
  fi
done
```

---

### Step B — Insert `## Risk Classification` section after `## Tier Classification`

Awk pass 1: after the literal closing line of `## Tier Classification` (`**FORBIDDEN in tier classification:** ... Output size is not a planning-time signal.`), emit the complete `## Risk Classification` section body. Matches via exact-string equality (`$0 == "..."`) — no regex. Writes via `mktemp` + `mv` (MINGW64-safe, no `sed -i`).

```bash
TMP_A="$(mktemp)"
awk -v anchor="$ANCHOR_TIER_CLOSING" '
  BEGIN { inserted = 0 }
  {
    print
    if (!inserted && $0 == anchor) {
      print ""
      print "## Risk Classification"
      print "Informal risk labels assigned during Tier Classification. Distinct from Tier — Tier measures planning-primitive size (step/file count, dep topology); Risk measures blast radius of a production failure. Plan-writer emits `#### Risk: {level}` immediately after `#### Tier: {tier}` on every task sub-section."
      print ""
      print "Four levels (intent-level criteria — plan-writer judges at planning time, not at execution time):"
      print ""
      print "1. **low** — isolated change, no cross-file impact, trivially reversible via `git restore`, no user-facing surface. Examples: one-file doc typo fix, add a rule line to an existing rules file, rename a local variable in a leaf module, add a test for an already-tested function. Failure mode is obvious in review; rollback cost near zero."
      print ""
      print "2. **medium** — changes a contract, convention, or template consumed by multiple downstream files; rollback requires touching more than the edited file; subtle silent-failure potential if the change is wrong. Examples: add a new section to an agent template that downstream migrations read; change a hook script'"'"'s exit code semantics; add a new field to a task format consumed by skills; modify a shared rule file. Requires `#### Failure Modes` section."
      print ""
      print "3. **high** — migration, schema change, hook event wiring, settings.json merge, or any change that runs inside client projects via `/migrate-bootstrap` and cannot be rolled back by a single `git restore` in the bootstrap repo. Examples: new hook event registered in settings.json, migration that edits `.claude/agents/*.md` in client projects, payload-schema assumption for a hook input, new Claude Code hook event integration. Requires `#### Failure Modes` section with detection + rollback explicit."
      print ""
      print "4. **critical** — any change to authentication, credentials, secret handling, git-destructive commands (force push, reset --hard, clean -f), or a change that could silently disable an existing safety gate (verify, review, guard-git). Also: any change to shell scripts that run during bootstrap with elevated trust (companion-repo sync, settings merge). Requires `#### Failure Modes` section and an explicit \"blast radius bound\" note in rationale."
      print ""
      print "Scope rule: `#### Failure Modes` section is REQUIRED iff risk ∈ {medium, high, critical}; OMIT for low."
      print ""
      print "If plan-writer cannot answer any of the 5 failure-mode questions concretely → bump risk DOWN one level (the concrete analysis produced did not justify the higher classification) OR flag \"insufficient context — ask user\" in the Risks section of the master plan and stop. Never fabricate a Failure Modes answer to satisfy the scope rule."
      inserted = 1
    }
  }
' "$TARGET" > "$TMP_A"
mv "$TMP_A" "$TARGET"

if ! grep -qF '## Risk Classification' "$TARGET"; then
  echo "ERROR: Step B patch completed but '## Risk Classification' heading missing from $TARGET"
  exit 1
fi
```

---

### Step C — Insert `#### Risk:` and `#### Failure Modes` into the task template

Awk pass 2: in a single pass, insert `#### Risk: {low|medium|high|critical}` immediately after the `#### Tier: {micro|moderate|complex}` line, and insert the `#### Failure Modes` sub-section immediately after the `#### Dep set: {files+symbols this specific task touches}` line. Both matches use exact-string equality (`$0 == "..."`) — no regex.

Both insertions target the task template block inside `## Output Format — Batch Files` (the only place in the file where `#### Tier: {micro|moderate|complex}` and `#### Dep set: {files+symbols this specific task touches}` appear as literal lines — the Task Classification Table uses pipe-delimited rows, not headings, and the task sub-section headings contain only the placeholder values, not the pipe-separated option set). Each awk block runs exactly once (`inserted_*` flags) to guarantee idempotency within the same pass even if future file drift duplicates the anchor.

```bash
TMP_C="$(mktemp)"
awk -v tier_anchor="$ANCHOR_TIER_TEMPLATE" -v depset_anchor="$ANCHOR_DEPSET_TEMPLATE" '
  BEGIN {
    inserted_risk = 0
    inserted_failure_modes = 0
  }
  {
    print
    if (!inserted_risk && $0 == tier_anchor) {
      print "#### Risk: {low|medium|high|critical}"
      inserted_risk = 1
    }
    if (!inserted_failure_modes && $0 == depset_anchor) {
      print "#### Failure Modes"
      print "REQUIRED iff risk ∈ {medium, high, critical}; OMIT for low. Five numbered one-line answers:"
      print "1. What could fail in production?"
      print "2. How would we detect it quickly?"
      print "3. What is the fastest safe rollback?"
      print "4. What dependency could invalidate this plan?"
      print "5. What assumption is least certain?"
      inserted_failure_modes = 1
    }
  }
' "$TARGET" > "$TMP_C"
mv "$TMP_C" "$TARGET"

# Sentinel verify after both patches.
if grep -qF "$SENTINEL" "$TARGET"; then
  echo "PATCHED: $TARGET — Risk Classification section + Risk template line + Failure Modes sub-section"
else
  echo "ERROR: $TARGET patch completed but sentinel missing — manual review required"
  exit 1
fi

if ! grep -qF '#### Failure Modes' "$TARGET"; then
  echo "ERROR: '#### Failure Modes' sub-section not present in $TARGET after patch"
  exit 1
fi
```

---

### Step D — Register in `migrations/index.json`

The migration runner (`/migrate-bootstrap`) discovers migrations via `migrations/index.json`, not the directory listing. An entry must be present in the array before this migration can be applied by a client project.

```json
{
  "id": "024",
  "file": "024-plan-writer-failure-modes.md",
  "description": "Plan-writer risk classification + Failure Modes section — idempotent awk patches inject a '## Risk Classification' section (four levels: low | medium | high | critical with intent-level criteria and explicit scope rule) after the '## Tier Classification' section, plus a '#### Risk: {low|medium|high|critical}' line and a '#### Failure Modes' sub-section (five numbered one-line questions) into the '## Output Format — Batch Files' task template block of '.claude/agents/proj-plan-writer.md'. Sentinel-guarded (literal '#### Risk: {low|medium|high|critical}'), re-run safe, no regex with '.*' anywhere. Enables downstream TaskCompleted completion gate (migration 025) to read risk level from task descriptions and enforces concrete failure-mode analysis on every medium/high/critical task.",
  "breaking": false
}
```

Add this entry to the `migrations` array in `migrations/index.json`, immediately after the `023` entry.

---

### Rules for migration scripts

- **Literal anchors only** — every `grep` / `awk` match uses `grep -qF` or `awk` exact-string equality (`$0 == "..."`). No regex `.*` patterns. Anchor drift detection fails fast with a clear error.
- **Idempotent** — literal-string sentinel `#### Risk: {low|medium|high|critical}` gates every patch. Re-run produces zero modifications.
- **Read-before-write** — each patch block reads the file, verifies all anchors, then writes to a temp file before `mv` replacing. No in-place edits.
- **MINGW64-safe** — uses `mktemp` + `mv` (no `sed -i` in-place edits, which have known MINGW64 quirks). No process substitution. No `readarray`.
- **Abort on error** — `set -euo pipefail` at the top. Missing anchors → explicit `exit 1` with a manual-patch message; partially patched files are never silently left behind.
- **Self-contained** — no remote fetches, no references to gitignored paths. The Risk Classification section content and the Failure Modes question list are inlined here in full.

---

## Verify

```bash
#!/usr/bin/env bash
set -euo pipefail

SENTINEL='#### Risk: {low|medium|high|critical}'
TARGET=".claude/agents/proj-plan-writer.md"
FAIL=0

if [[ ! -f "$TARGET" ]]; then
  echo "SKIP-VERIFY: $TARGET not present (plan-writer agent not installed in this project)"
else
  if grep -qF "$SENTINEL" "$TARGET"; then
    echo "PASS: $TARGET contains Risk template sentinel"
  else
    echo "FAIL: $TARGET missing Risk template sentinel after migration"
    FAIL=1
  fi

  if grep -qF '## Risk Classification' "$TARGET"; then
    echo "PASS: $TARGET contains '## Risk Classification' section heading"
  else
    echo "FAIL: $TARGET missing '## Risk Classification' section after migration"
    FAIL=1
  fi

  if grep -qF '#### Failure Modes' "$TARGET"; then
    echo "PASS: $TARGET contains '#### Failure Modes' template entry"
  else
    echo "FAIL: $TARGET missing '#### Failure Modes' template entry after migration"
    FAIL=1
  fi
fi

# Verify the index.json entry exists.
if grep -qF '"id": "024"' migrations/index.json; then
  echo "PASS: migrations/index.json contains 024 entry"
else
  echo "FAIL: migrations/index.json missing 024 entry"
  FAIL=1
fi

[[ $FAIL -eq 0 ]] || exit 1
```

Failure of any verify step → `/migrate-bootstrap` aborts and does NOT update `bootstrap-state.json`. Safe to retry after fixing the failure.

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → `"024"`
- append `{ "id": "024", "applied_at": "<ISO8601>", "description": "Plan-writer risk classification + Failure Modes section" }` to `applied[]`

---

## Rollback

Reversible via literal-anchor deletion: remove the `## Risk Classification` section, the `#### Risk: {low|medium|high|critical}` template line, and the `#### Failure Modes` sub-section from `.claude/agents/proj-plan-writer.md`. Easier: `git restore .claude/agents/proj-plan-writer.md` from the pre-migration commit (if the client project tracks the agents directory) or re-run `/migrate-bootstrap` after reverting the bootstrap template. No cascading dependencies — removing the additions restores the original plan-writer behavior; already-generated plans and batch files are unaffected because they are static markdown artifacts.
