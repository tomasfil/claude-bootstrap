# Module 06 — Skills

> Install tracked skill templates from `templates/skills/` into `.claude/skills/` via `gh api` fetch loop.
> Sources of truth are `templates/manifest.json` (inventory + SHA) + the per-skill `SKILL.md` files. This module contains NO inline skill bodies — edit `templates/skills/{name}/SKILL.md` directly to change a skill.
> Shared blocks (`AGENT_DISPATCH_POLICY_BLOCK`, `PRE_FLIGHT_GATE_BLOCK`, `TASKCREATE_GATE_BLOCK`) remain in this module because they are referenced verbatim by migrations and by client-project skills that inject them.

---

## Shared Blocks

### AGENT_DISPATCH_POLICY_BLOCK

Reusable block injected into every skill that dispatches agents. Content:

```
**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: use Read/Grep/Glob directly OR dispatch `proj-quick-check` (simple) / `proj-researcher` (deep) — never built-in.
See `techniques/agent-design.md § Agent Dispatch Policy`.
```

Skill specs reference this via `{AGENT_DISPATCH_POLICY_BLOCK — see top of module}` — the generator MUST expand the reference to the literal block above.

---

### PRE_FLIGHT_GATE_BLOCK

Reusable block injected as the FIRST executable section of every main-thread orchestrator skill body. Content:

```
## Pre-flight (REQUIRED — before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.
```

Skill specs reference this via `{PRE_FLIGHT_GATE_BLOCK — see top of module}` — the generator MUST expand the reference to the literal block above.

---

### TASKCREATE_GATE_BLOCK

Reusable block injected into long-running main-thread orchestrator skills (`/execute-plan`, `/deep-think`, and any future multi-phase skill) to create a harness-level task entry on start and close it on completion or abort. Purpose: make long skills observable in the harness task list, enabling cross-session tracking and allowing `/reflect` + `/consolidate` to correlate learning entries with the task that produced them.

**Parameters the skill must substitute at invocation site:**

- `{TASK_NAME_EXPR}` — short human-readable task subject (e.g., `f"execute-plan: {plan-basename}"`, `f"deep-think: {topic_slug}"`). MUST be a single line, ≤80 chars, no newlines.
- `{TASK_DESCRIPTION_EXPR}` — 1-sentence task description capturing scope (e.g., `"Execute plan {plan-path} — {batch-count} batches"`, `"Deep-think on {topic} — {phase_count} phases, {persona_count} personas"`). Free-form prose.

**Block body (4 numbered steps — execute top-down at the skill's first executable step):**

```
1. Load TaskCreate/TaskUpdate via `ToolSearch("select:TaskCreate,TaskUpdate")`.
   If the ToolSearch returns no schemas OR calling TaskCreate raises InputValidationError
   → set TASK_TRACKING=false, print one warning line
     (`TaskCreate unavailable — continuing without harness task tracking`), continue.
2. (TASK_TRACKING=true) Call `TaskCreate(subject={TASK_NAME_EXPR}, description={TASK_DESCRIPTION_EXPR})`,
   then immediately `TaskUpdate(taskId=<returned-id>, status="in_progress")`.
   Remember the returned taskId for the duration of the skill run (in-memory only; do
   not persist to disk — the harness owns the task-list state).
3. On successful skill completion (all phases/batches passed, review clean):
   `TaskUpdate(taskId=<id>, status="completed")`. This is the closeout call.
4. On error / abort / user-cancel / hard-fail:
   `TaskUpdate(taskId=<id>, status="in_progress", description={original_description} + "\n\nBLOCKED: {reason}")`.
   Do NOT mark completed. Leaving status=in_progress with a BLOCKED suffix lets the
   harness task list surface the failure instead of silently closing it.
```

**Idempotency marker:** presence of the literal string `ToolSearch("select:TaskCreate,TaskUpdate")` anywhere in a target file means this block has already been applied. Migrations and re-runs MUST `grep -q` for this literal before patching and skip if found. Do not use a regex with `.*` — the check is a literal-string match.

Skill specs reference this via `{TASKCREATE_GATE_BLOCK — see top of module}` — the generator MUST expand the reference to the literal block above, substituting `{TASK_NAME_EXPR}` and `{TASK_DESCRIPTION_EXPR}` with the skill-specific expressions defined in that skill's dispatch spec.

---

## Idempotency

Per skill: compare on-disk `sha256` of `SKILL.md` against `templates/manifest.json` entry. Match → skip. Mismatch or missing → fetch from `templates/skills/{name}/SKILL.md` (and any listed `references/` files) and overwrite. Never hand-edit `.claude/skills/**/SKILL.md` in client projects — those files are generated output; edit `templates/skills/{name}/SKILL.md` in the bootstrap repo instead.

---

## Pre-Flight

1. Verify `gh` is authenticated:

```bash
gh auth status >/dev/null 2>&1 || { echo "ERROR: gh not authenticated. Run: gh auth login"; exit 1; }
```

2. Create the skills directory:

```bash
mkdir -p .claude/skills
```

3. Verify foundation agents from Module 01 exist — skills that dispatch specialists rely on them:

```bash
for agent in proj-code-writer-markdown proj-researcher proj-code-writer-bash; do
  [[ -f ".claude/agents/${agent}.md" ]] || { echo "MISSING: ${agent}.md — run Module 01 first"; exit 1; }
done
```

---

## Actions

### Step 1 — Fetch Manifest

Resolve `{owner}` from `.claude/bootstrap-state.json` `github_username` (Module 01 persists this field; default `tomasfil`). `BOOTSTRAP_OWNER` env var, if set, takes precedence:

```bash
set -euo pipefail

OWNER="${BOOTSTRAP_OWNER:-$(jq -r '.github_username // "tomasfil"' .claude/bootstrap-state.json 2>/dev/null || echo tomasfil)}"
REPO="claude-bootstrap"
BRANCH="main"

if [[ -f templates/manifest.json ]]; then
  MANIFEST_JSON="$(cat templates/manifest.json)"
else
  MANIFEST_JSON="$(gh api "repos/${OWNER}/${REPO}/contents/templates/manifest.json?ref=${BRANCH}" --jq '.content' | base64 -d)"
fi

echo "$MANIFEST_JSON" | jq -e '.skills | length > 0' >/dev/null || { echo "ERROR: manifest has no skills"; exit 1; }
```

### Step 2 — Fetch Loop (per skill)

For each skill entry: resolve `source` + `target` + `sha256` + optional `references` list. Compare on-disk sha against manifest. Skip, update, or create as needed. Every reference file follows the same protocol.

```bash
set -euo pipefail

# Process substitution — keeps the outer loop in the current shell so `exit 1` propagates.
while IFS= read -r entry; do
  name=$(echo "$entry" | jq -r '.name')
  source=$(echo "$entry" | jq -r '.source')
  target=$(echo "$entry" | jq -r '.target')
  expected_sha=$(echo "$entry" | jq -r '.sha256')

  mkdir -p "$(dirname "$target")"

  if [[ -f "$target" ]]; then
    actual_sha=$(sha256sum "$target" | awk '{print $1}')
    if [[ "$actual_sha" == "$expected_sha" ]]; then
      printf '  SKIP %-36s (sha match)\n' "$name"
    else
      printf '  UPDATE %-34s (sha drift)\n' "$name"
      if [[ -f "$source" ]]; then cp "$source" "$target"
      else gh api "repos/${OWNER}/${REPO}/contents/${source}?ref=${BRANCH}" --jq '.content' | base64 -d > "$target"
      fi
    fi
  else
    printf '  FETCH %-35s (missing)\n' "$name"
    if [[ -f "$source" ]]; then cp "$source" "$target"
    else gh api "repos/${OWNER}/${REPO}/contents/${source}?ref=${BRANCH}" --jq '.content' | base64 -d > "$target"
    fi
  fi

  written_sha=$(sha256sum "$target" | awk '{print $1}')
  if [[ "$written_sha" != "$expected_sha" ]]; then
    printf 'ERROR: %s sha mismatch after fetch — expected %s, got %s\n' "$target" "$expected_sha" "$written_sha" >&2
    exit 1
  fi

  # References — progressive-disclosure docs under references/ subdirectory.
  # Inner loop ALSO uses process substitution — nested `jq | while` would swallow exit propagation.
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    ref_source=$(echo "$ref" | jq -r '.source')
    ref_target=$(echo "$ref" | jq -r '.target')
    ref_sha=$(echo "$ref" | jq -r '.sha256')
    mkdir -p "$(dirname "$ref_target")"
    if [[ -f "$ref_target" ]] && [[ "$(sha256sum "$ref_target" | awk '{print $1}')" == "$ref_sha" ]]; then
      continue
    fi
    if [[ -f "$ref_source" ]]; then cp "$ref_source" "$ref_target"
    else gh api "repos/${OWNER}/${REPO}/contents/${ref_source}?ref=${BRANCH}" --jq '.content' | base64 -d > "$ref_target"
    fi
    ref_written_sha=$(sha256sum "$ref_target" | awk '{print $1}')
    if [[ "$ref_written_sha" != "$ref_sha" ]]; then
      printf 'ERROR: %s sha mismatch after fetch — expected %s, got %s\n' "$ref_target" "$ref_sha" "$ref_written_sha" >&2
      exit 1
    fi
  done < <(echo "$entry" | jq -c '.references[]? // empty')
done < <(echo "$MANIFEST_JSON" | jq -c '.skills[]')
```

### Step 3 — Post-Fetch Verification

```bash
set -euo pipefail

while IFS= read -r target; do
  [[ -f "$target" ]] || { printf 'MISSING: %s\n' "$target" >&2; exit 1; }
done < <(echo "$MANIFEST_JSON" | jq -r '.skills[].target')
echo "All manifest skills present in .claude/skills/"
```

---

## Checkpoint

```bash
N=$(echo "$MANIFEST_JSON" | jq '.skills | length')
echo "✅ Module 06 complete — ${N} skills installed via template fetch"
```
