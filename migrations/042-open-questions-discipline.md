# Migration 042 — Open Questions Discipline

> Propagate the open-questions triage discipline to client projects already bootstrapped before migration 042. Closes a 4-layer gap in the main-thread orchestrator pipeline that lets user-decidable questions get silently disposed of (unilateral recommendation, assumption, or omission) instead of surfaced to the user for triage. Adds a new rule file (`open-questions-discipline.md`) with the canonical disposition vocabulary (USER_DECIDES / AGENT_RECOMMENDS / AGENT_DECIDED), updates the technique reference, patches the researcher agent + brainstorm skill + deep-think skill to surface and triage open questions in their handoff output, and updates `max-quality.md` §6 to clarify that the No-Hedging rule forbids mid-task permission-seeking but does NOT forbid surfacing genuinely user-decidable questions at the triage phase. Wires the new rule into `CLAUDE.md` via `@import` and adds it to the STEP 0 force-read list of `proj-plan-writer` (researcher is refreshed via template fetch in Step 2). Sentinel-guarded per step so re-runs on already-patched projects no-op.

---

## Metadata

```yaml
id: "042"
breaking: false
affects: [rules, skills, agents, techniques]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

The main-thread orchestrator in bootstrapped Claude Code environments has no structural channel for surfacing user-decidable questions during the brainstorm → research → plan handoff pipeline. The practical effect observed in the field: when a user's initial request contains ambiguity that the agent could in principle resolve autonomously (pick a library, pick a retention window, pick a naming convention, pick a threshold value), the main thread disposes of the ambiguity unilaterally — either by making the call itself without flagging it, by recommending one option in prose without labelling the decision as user-facing, or by simply omitting the ambiguity from the handoff artefact entirely. Downstream phases (plan-writer, code-writer, execute-plan) then inherit a decision the user never saw. When the user later reviews the output, they discover a choice was made on their behalf that they would have preferred to weigh in on — and the cost of rolling back that choice is higher than the cost of asking would have been at the triage phase.

The failure mode has four compounding layers, each independently load-bearing:

1. **`proj-researcher` Output Template has no `Open Questions` section.** The researcher agent produces a findings file consumed by downstream dispatches. The template lists sections like Evidence, Summary, and Recommendations — but has no structural slot for open questions with dispositions. A researcher who encounters a genuinely user-decidable question has nowhere in the template to put it, so the question gets collapsed into a Recommendations bullet (which the downstream plan-writer treats as a settled decision) or dropped entirely.

2. **`/brainstorm` skill has no triage step.** The brainstorm skill walks from problem statement → exploration → spec, but has no explicit step where open questions get listed, categorised by disposition vocabulary, and surfaced to the user before the spec is committed. Questions raised during exploration get absorbed into the spec's Requirements section as assumptions rather than elevated to a user-visible triage artefact.

3. **`techniques/agent-design.md` handoff-format documentation has no `open_questions` field.** The technique document is the reference for what fields an agent handoff should contain. Without an `open_questions` field alongside the existing `unresolved` field, downstream agent authors building new agents have no pattern to copy. The gap propagates.

4. **`max-quality.md` §6 "No Hedging" rule is misread as "never ask".** The rule's actual content forbids *mid-task permission-seeking* ("should I continue?", "want me to keep going?") — a hedge that interrupts flow on solvable problems. But the rule has been interpreted more broadly in practice to forbid surfacing genuinely user-decidable questions at the triage phase, which is a different class of question entirely. The rule needs an explicit clarification that "No Hedging" ≠ "never ask" — the triage-phase surfacing of user-decidable choices is not a hedge, it is a handoff.

Each layer reinforces the others. A researcher with no `Open Questions` template slot (layer 1) has no output shape to produce even if they wanted to surface a question. A brainstorm skill with no triage step (layer 2) has no phase in which the question would be gathered. A technique document with no documented field (layer 3) gives new agents no pattern to follow. And a max-quality doctrine misread as "never ask" (layer 4) gives the agent an active disincentive to surface anything that looks like a question.

The fix closes all four layers in one migration, plus wires the new rule file into `CLAUDE.md` so it loads on every main-thread session, plus adds it to the STEP 0 force-read list of agents that originate handoff artefacts (researcher, plan-writer). Agents that consume handoffs (code-writers, test-writers, tdd-runner) are exempt — they operate downstream of the triage phase and should not be re-opening disposition questions mid-implementation.

---

## Changes

| File | Change |
|---|---|
| `.claude/references/techniques/agent-design.md` | Fetch updated — `open_questions` field documented alongside existing `unresolved` field in handoff format + disposition vocabulary (USER_DECIDES / AGENT_RECOMMENDS / AGENT_DECIDED) |
| `.claude/agents/proj-researcher.md` | Fetch updated — `## Open Questions` section added to Output Template + force-read `open-questions-discipline.md` added to STEP 0 |
| `.claude/skills/brainstorm/SKILL.md` | Fetch updated — Step 3.5 Triage block added (gather open questions, assign disposition, surface to user before spec commit) + Spec Output Format Open Questions structure |
| `.claude/skills/deep-think/SKILL.md` | Fetch updated — Open Questions triage added to Phase 7 handoff |
| `.claude/rules/open-questions-discipline.md` | Fetch NEW — full rule body (disposition vocabulary, when to surface, handoff format, relationship to max-quality §6) |
| `.claude/rules/max-quality.md` | Fetch updated — existing body preserved + §6 clarification that "No Hedging" ≠ "never ask" (mid-task permission-seeking is the hedge; triage-phase surfacing of user-decidable choices is a handoff, not a hedge) |
| `CLAUDE.md` | Patch: add `@import .claude/rules/open-questions-discipline.md` after the last existing `@import` line |
| `.claude/agents/proj-plan-writer.md` | Patch: add `open-questions-discipline.md` bullet to STEP 0 force-read list (researcher is refreshed via Step 2 template fetch, so no separate patch needed for it) |
| `.claude/agents/proj-reflector.md` | Patch: add `open-questions-discipline.md` bullet to STEP 0 force-read list — reflector originates proposals (promote-to-rule, create-agent, update-existing) that are classic USER_DECIDES / AGENT_RECOMMENDS items and must classify them |
| `.claude/skills/review/SKILL.md` | Fetch updated — new Step 5.5 Open Questions Discipline check (structural grep over recent research + spec files, flags missing `## Open Questions` sections and missing disposition labels) |

---

## Actions

### Prerequisites

```bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -f "CLAUDE.md" ]] || { echo "ERROR: CLAUDE.md missing — run full bootstrap first"; exit 1; }
[[ -d ".claude/rules" ]] || { echo "ERROR: .claude/rules/ missing — run full bootstrap first"; exit 1; }
[[ -d ".claude/agents" ]] || { echo "ERROR: .claude/agents/ missing — run full bootstrap first"; exit 1; }
[[ -d ".claude/skills" ]] || { echo "ERROR: .claude/skills/ missing — run full bootstrap first"; exit 1; }
[[ -d ".claude/references/techniques" ]] || { echo "ERROR: .claude/references/techniques/ missing — run full bootstrap first (migration 008 creates this)"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI required"; exit 1; }

BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-tomasfil/claude-bootstrap}"
```

### Step 1 — Fetch updated `techniques/agent-design.md` → `.claude/references/techniques/agent-design.md`

Sentinel: target file already contains the literal `open_questions`. If present → SKIP. Otherwise → fetch via `gh api`, verify sentinel in fetched content, write to destination.

```bash
set -euo pipefail

TARGET=".claude/references/techniques/agent-design.md"

if [[ -f "$TARGET" ]] && grep -q "open_questions" "$TARGET"; then
  echo "SKIP: $TARGET already contains open_questions sentinel"
else
  TMP=$(mktemp)
  trap 'rm -f "$TMP"' EXIT
  gh api "repos/${BOOTSTRAP_REPO}/contents/techniques/agent-design.md" --jq '.content' | base64 -d > "$TMP"
  grep -q "open_questions" "$TMP" || { echo "FAIL: fetched agent-design.md does not contain open_questions sentinel — bootstrap repo may not have Batch 2 merged"; exit 1; }
  mv "$TMP" "$TARGET"
  trap - EXIT
  echo "WROTE: $TARGET"
fi
```

### Step 2 — Fetch updated `templates/agents/proj-researcher.md` → `.claude/agents/proj-researcher.md`

Sentinel: target file already contains the literal `Open Questions`. If present → SKIP. Otherwise → fetch, verify sentinel, write.

```bash
set -euo pipefail

TARGET=".claude/agents/proj-researcher.md"

if [[ -f "$TARGET" ]] && grep -q "Open Questions" "$TARGET"; then
  echo "SKIP: $TARGET already contains Open Questions sentinel"
else
  TMP=$(mktemp)
  trap 'rm -f "$TMP"' EXIT
  gh api "repos/${BOOTSTRAP_REPO}/contents/templates/agents/proj-researcher.md" --jq '.content' | base64 -d > "$TMP"
  grep -q "Open Questions" "$TMP" || { echo "FAIL: fetched proj-researcher.md does not contain Open Questions sentinel — bootstrap repo may not have Batch 2 merged"; exit 1; }
  mv "$TMP" "$TARGET"
  trap - EXIT
  echo "WROTE: $TARGET"
fi
```

### Step 3 — Fetch updated `templates/skills/brainstorm/SKILL.md` → `.claude/skills/brainstorm/SKILL.md`

Sentinel: target file already contains the literal `3.5 Triage`. If present → SKIP. Otherwise → fetch, verify sentinel, write.

```bash
set -euo pipefail

TARGET=".claude/skills/brainstorm/SKILL.md"

[[ -d ".claude/skills/brainstorm" ]] || { echo "ERROR: .claude/skills/brainstorm/ directory missing — cannot proceed"; exit 1; }

if [[ -f "$TARGET" ]] && grep -q "3.5 Triage" "$TARGET"; then
  echo "SKIP: $TARGET already contains 3.5 Triage sentinel"
else
  TMP=$(mktemp)
  trap 'rm -f "$TMP"' EXIT
  gh api "repos/${BOOTSTRAP_REPO}/contents/templates/skills/brainstorm/SKILL.md" --jq '.content' | base64 -d > "$TMP"
  grep -q "3.5 Triage" "$TMP" || { echo "FAIL: fetched brainstorm/SKILL.md does not contain 3.5 Triage sentinel — bootstrap repo may not have Batch 2 merged"; exit 1; }
  mv "$TMP" "$TARGET"
  trap - EXIT
  echo "WROTE: $TARGET"
fi
```

### Step 4 — Fetch updated `templates/skills/deep-think/SKILL.md` → `.claude/skills/deep-think/SKILL.md`

Sentinel: target file already contains `open_questions` OR `Open Questions`. If present → SKIP. Otherwise → fetch, verify sentinel, write.

```bash
set -euo pipefail

TARGET=".claude/skills/deep-think/SKILL.md"

[[ -d ".claude/skills/deep-think" ]] || { echo "ERROR: .claude/skills/deep-think/ directory missing — cannot proceed"; exit 1; }

if [[ -f "$TARGET" ]] && grep -qE "open_questions|Open Questions" "$TARGET"; then
  echo "SKIP: $TARGET already contains Open Questions sentinel"
else
  TMP=$(mktemp)
  trap 'rm -f "$TMP"' EXIT
  gh api "repos/${BOOTSTRAP_REPO}/contents/templates/skills/deep-think/SKILL.md" --jq '.content' | base64 -d > "$TMP"
  grep -qE "open_questions|Open Questions" "$TMP" || { echo "FAIL: fetched deep-think/SKILL.md does not contain Open Questions sentinel — bootstrap repo may not have Batch 2 merged"; exit 1; }
  mv "$TMP" "$TARGET"
  trap - EXIT
  echo "WROTE: $TARGET"
fi
```

### Step 5 — Fetch NEW `templates/rules/open-questions-discipline.md` → `.claude/rules/open-questions-discipline.md`

Sentinel: target file already contains the literal `USER_DECIDES`. If present → SKIP. Otherwise → fetch, verify sentinel, write.

```bash
set -euo pipefail

TARGET=".claude/rules/open-questions-discipline.md"

if [[ -f "$TARGET" ]] && grep -q "USER_DECIDES" "$TARGET"; then
  echo "SKIP: $TARGET already contains USER_DECIDES sentinel"
else
  TMP=$(mktemp)
  trap 'rm -f "$TMP"' EXIT
  gh api "repos/${BOOTSTRAP_REPO}/contents/templates/rules/open-questions-discipline.md" --jq '.content' | base64 -d > "$TMP"
  grep -q "USER_DECIDES" "$TMP" || { echo "FAIL: fetched open-questions-discipline.md does not contain USER_DECIDES sentinel — bootstrap repo may not have Batch 1 merged"; exit 1; }
  mv "$TMP" "$TARGET"
  trap - EXIT
  echo "WROTE: $TARGET"
fi
```

### Step 6 — Fetch updated `templates/rules/max-quality.md` → `.claude/rules/max-quality.md`

Sentinel: target file already contains the literal `never ask`. If present → SKIP. Otherwise → fetch, verify sentinel, write.

```bash
set -euo pipefail

TARGET=".claude/rules/max-quality.md"

if [[ -f "$TARGET" ]] && grep -q "never ask" "$TARGET"; then
  echo "SKIP: $TARGET already contains 'never ask' clarification sentinel"
else
  TMP=$(mktemp)
  trap 'rm -f "$TMP"' EXIT
  gh api "repos/${BOOTSTRAP_REPO}/contents/templates/rules/max-quality.md" --jq '.content' | base64 -d > "$TMP"
  grep -q "never ask" "$TMP" || { echo "FAIL: fetched max-quality.md does not contain 'never ask' clarification sentinel — bootstrap repo may not have Batch 1 merged"; exit 1; }
  mv "$TMP" "$TARGET"
  trap - EXIT
  echo "WROTE: $TARGET"
fi
```

### Step 7 — Fetch updated `templates/skills/review/SKILL.md` → `.claude/skills/review/SKILL.md`

Sentinel: target file already contains the literal `5.5 Open Questions Discipline check`. If present → SKIP. Otherwise → fetch, verify sentinel, write.

```bash
set -euo pipefail

TARGET=".claude/skills/review/SKILL.md"

[[ -d ".claude/skills/review" ]] || { echo "ERROR: .claude/skills/review/ directory missing — cannot proceed"; exit 1; }

if [[ -f "$TARGET" ]] && grep -q "5.5 Open Questions Discipline check" "$TARGET"; then
  echo "SKIP: $TARGET already contains 5.5 Open Questions Discipline check sentinel"
else
  TMP=$(mktemp)
  trap 'rm -f "$TMP"' EXIT
  gh api "repos/${BOOTSTRAP_REPO}/contents/templates/skills/review/SKILL.md" --jq '.content' | base64 -d > "$TMP"
  grep -q "5.5 Open Questions Discipline check" "$TMP" || { echo "FAIL: fetched review/SKILL.md does not contain 5.5 Open Questions Discipline check sentinel — bootstrap repo may not have F8 fix merged"; exit 1; }
  mv "$TMP" "$TARGET"
  trap - EXIT
  echo "WROTE: $TARGET"
fi
```

### Step 8 — Patch `CLAUDE.md` — add `@import .claude/rules/open-questions-discipline.md`

Sentinel: `CLAUDE.md` already contains the literal `@import .claude/rules/open-questions-discipline.md`. If present → SKIP. Otherwise → insert the new `@import` line immediately after the last existing `@import` line via a Python round-trip (no regex on the markdown body).

```bash
set -euo pipefail

python3 <<'PY'
import sys

PATH = "CLAUDE.md"
SENTINEL = "@import .claude/rules/open-questions-discipline.md"

with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

if SENTINEL in content:
    print("SKIP: CLAUDE.md already contains open-questions-discipline @import")
    sys.exit(0)

# Insert immediately after the last existing @import line.
last_import = content.rfind("@import")
if last_import == -1:
    print("FAIL: CLAUDE.md contains no existing @import line — cannot anchor insertion")
    sys.exit(1)

insert_after = content.index("\n", last_import) + 1
content = content[:insert_after] + SENTINEL + "\n" + content[insert_after:]

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)
print("PATCHED: CLAUDE.md @import added")
PY
```

### Step 9 — Patch `proj-plan-writer.md` + `proj-reflector.md` STEP 0 force-read list (researcher already handled via Step 2 fetch)

The `proj-researcher` agent is refreshed in Step 2 via template fetch, which already includes the rule file in its STEP 0 list — so no separate patch is needed for researcher. This step patches two agents that ORIGINATE handoff artefacts with user-decidable questions:

1. `proj-plan-writer.md` — plans routinely surface open questions (e.g. "pack this batch aggressively or split?", "migrate in one pass or two?") that need disposition classification
2. `proj-reflector.md` — reflection proposals (promote-to-rule, create-agent, update-existing, archive, automate) are classic USER_DECIDES / AGENT_RECOMMENDS items and must classify by disposition

For each: insert the `open-questions-discipline.md` bullet immediately after the `max-quality.md` bullet in the STEP 0 force-read list. Writer agents (code-writer-*, test-writer-*, tdd-runner) are exempt — they consume handoffs, not originate them, so they do not need the rule file in their STEP 0 list. `proj-debugger` and `proj-code-reviewer` are borderline candidates deferred to a future migration if evidence accumulates that they need the discipline.

Anchor-missing handling: if the target agent does not contain the expected anchor (`- \`.claude/rules/max-quality.md\``) — e.g. because the agent has been hand-edited with a different STEP 0 structure — the step reports `ANCHOR MISSING` for that agent and continues without failing the migration (non-fatal, per migration 031/039 precedent). The operator can then hand-patch the agent.

```bash
set -euo pipefail

for agent in .claude/agents/proj-plan-writer.md .claude/agents/proj-reflector.md; do
  [[ -f "$agent" ]] || { echo "SKIP: $agent not present"; continue; }
  if grep -q "open-questions-discipline" "$agent"; then
    echo "SKIP: $agent already contains open-questions-discipline bullet"
    continue
  fi

  python3 - "$agent" <<'PY'
import sys

path = sys.argv[1]
BULLETS = {
    "proj-plan-writer.md": "- `.claude/rules/open-questions-discipline.md` (if present — open questions surfacing + disposition vocabulary)\n",
    "proj-reflector.md": "- `.claude/rules/open-questions-discipline.md` (if present — open questions surfacing + disposition vocabulary; reflector proposals MUST classify by disposition)\n",
}
ANCHOR = "- `.claude/rules/max-quality.md`"

# Determine bullet by filename match
bullet = next((v for k, v in BULLETS.items() if path.endswith(k)), None)
if bullet is None:
    print(f"UNEXPECTED PATH: {path} — manual patch needed (non-fatal, continuing)")
    sys.exit(0)

with open(path, "r", encoding="utf-8") as f:
    body = f.read()

if bullet in body:
    print(f"SKIP: {path} already contains bullet")
    sys.exit(0)

idx = body.find(ANCHOR)
if idx == -1:
    print(f"ANCHOR MISSING in {path} — manual patch needed (non-fatal, continuing)")
    sys.exit(0)

# Insert the new bullet on the line immediately after the anchor line.
end_of_anchor_line = body.index("\n", idx) + 1
body = body[:end_of_anchor_line] + bullet + body[end_of_anchor_line:]

with open(path, "w", encoding="utf-8") as f:
    f.write(body)
print(f"PATCHED: {path} STEP 0 force-read updated")
PY
done
```

### Rules for migration scripts

- **Read-before-write** — every fetch step writes to a tempfile first, checks the expected sentinel, and only renames into place when the fetched content passes the sentinel check. The `CLAUDE.md` patch reads the file, computes the new content in memory, and writes the round-trip.
- **Idempotent** — every step is sentinel-guarded. Re-running on an already-patched project emits `SKIP` lines and exits 0 without writing.
- **Self-contained** — all logic inlined via quoted heredocs; remote fetches use only the public `gh api` surface; no reference to gitignored paths beyond the in-project write targets.
- **Abort on error** — `set -euo pipefail` on every step wrapper; Python heredocs `sys.exit(1)` on parse or anchor failures (Step 8); Step 9 anchor-missing is deliberately non-fatal per migration 031/039 precedent (the operator needs the migration to complete so subsequent steps land; the ANCHOR MISSING message tells them which file to hand-patch).
- **Bootstrap-repo prereq** — Steps 1–7 require the bootstrap repo to have merged the corresponding template updates (templates/rules/open-questions-discipline.md + templates/rules/max-quality.md + templates/agents/proj-researcher.md + templates/skills/brainstorm/SKILL.md + templates/skills/deep-think/SKILL.md + templates/skills/review/SKILL.md + techniques/agent-design.md). If the bootstrap repo has not been updated, the fetched content will fail the sentinel check and the step will fail loudly — no silent partial application.
- **Technique sync path** — Step 1 writes to `.claude/references/techniques/agent-design.md`, NOT to `techniques/agent-design.md` at the client project root (per `.claude/rules/general.md` §Migrations: "Technique update = sync step in migration" with the destination being the client layout).

### Required: register in migrations/index.json

Main thread applies this entry — do not attempt to edit `migrations/index.json` from inside the migration script. Append to the `migrations` array:

```json
{
  "id": "042",
  "file": "042-open-questions-discipline.md",
  "description": "Propagate the open-questions triage discipline to client projects already bootstrapped before migration 042. Closes a 4-layer gap in the main-thread orchestrator pipeline that lets user-decidable questions get silently disposed of (unilateral recommendation, assumption, or omission) instead of surfaced for triage: (1) proj-researcher Output Template had no Open Questions section, (2) /brainstorm skill had no triage step, (3) techniques/agent-design.md had no open_questions field documented, (4) max-quality.md §6 No Hedging was misread as 'never ask' instead of 'no mid-task permission-seeking'. Fix: fetch 7 updated artefacts (techniques/agent-design.md, templates/agents/proj-researcher.md, templates/skills/brainstorm/SKILL.md, templates/skills/deep-think/SKILL.md, templates/rules/open-questions-discipline.md [NEW], templates/rules/max-quality.md, templates/skills/review/SKILL.md) from bootstrap repo via gh api, verify each has its expected sentinel before writing, then patch CLAUDE.md to @import the new rule file (Python round-trip, anchored on last existing @import line) and patch proj-plan-writer.md + proj-reflector.md STEP 0 force-read lists to add the new rule bullet (non-fatal ANCHOR MISSING per migration 031/039 precedent). /review skill gains Step 5.5 Open Questions Discipline check — structural grep that flags research/spec files missing `## Open Questions` sections or disposition labels, making the open-questions-discipline.md `/review flags forward-progress...` enforcement claim true. Canonical disposition vocabulary: USER_DECIDES (blocking, no sane default) / AGENT_RECOMMENDS (default + rationale, user can veto) / AGENT_DECIDED (mechanical/settled, stated transparently). Writer agents (code-writer-*, test-writer-*, tdd-runner) are exempt — they consume handoffs, not originate them. Borderline candidates (proj-debugger, proj-code-reviewer) deferred to a future migration if evidence accumulates. Sentinel-guarded idempotent (every step SKIPs on re-run). bootstrap-state.json advances to last_migration=042.",
  "breaking": false
}
```

---

## Verify

```bash
set -euo pipefail

# Rule files present + contain expected sentinels
[[ -f ".claude/rules/open-questions-discipline.md" ]] || { echo "FAIL: .claude/rules/open-questions-discipline.md missing"; exit 1; }
grep -q "USER_DECIDES" .claude/rules/open-questions-discipline.md \
  || { echo "FAIL: open-questions-discipline.md missing USER_DECIDES sentinel"; exit 1; }

[[ -f ".claude/rules/max-quality.md" ]] || { echo "FAIL: .claude/rules/max-quality.md missing"; exit 1; }
grep -q "never ask" .claude/rules/max-quality.md \
  || { echo "FAIL: max-quality.md missing 'never ask' clarification"; exit 1; }

# Technique sync landed in the client layout path
[[ -f ".claude/references/techniques/agent-design.md" ]] || { echo "FAIL: .claude/references/techniques/agent-design.md missing"; exit 1; }
grep -q "open_questions" .claude/references/techniques/agent-design.md \
  || { echo "FAIL: agent-design.md missing open_questions field documentation"; exit 1; }

# Researcher agent has Open Questions section
[[ -f ".claude/agents/proj-researcher.md" ]] || { echo "FAIL: .claude/agents/proj-researcher.md missing"; exit 1; }
grep -q "Open Questions" .claude/agents/proj-researcher.md \
  || { echo "FAIL: proj-researcher.md missing Open Questions sentinel"; exit 1; }

# Brainstorm skill has Step 3.5 Triage
[[ -f ".claude/skills/brainstorm/SKILL.md" ]] || { echo "FAIL: .claude/skills/brainstorm/SKILL.md missing"; exit 1; }
grep -q "3.5 Triage" .claude/skills/brainstorm/SKILL.md \
  || { echo "FAIL: brainstorm/SKILL.md missing 3.5 Triage sentinel"; exit 1; }
grep -q "USER_DECIDES" .claude/skills/brainstorm/SKILL.md \
  || { echo "FAIL: brainstorm/SKILL.md missing USER_DECIDES disposition vocabulary"; exit 1; }

# Review skill has 5.5 Open Questions Discipline check
[[ -f ".claude/skills/review/SKILL.md" ]] || { echo "FAIL: .claude/skills/review/SKILL.md missing"; exit 1; }
grep -q "5.5 Open Questions Discipline check" .claude/skills/review/SKILL.md \
  || { echo "FAIL: review/SKILL.md missing 5.5 Open Questions Discipline check sentinel"; exit 1; }

# Deep-think skill has Open Questions triage
[[ -f ".claude/skills/deep-think/SKILL.md" ]] || { echo "FAIL: .claude/skills/deep-think/SKILL.md missing"; exit 1; }
grep -qE "open_questions|Open Questions" .claude/skills/deep-think/SKILL.md \
  || { echo "FAIL: deep-think/SKILL.md missing Open Questions sentinel"; exit 1; }

# CLAUDE.md has the @import line
grep -q "@import .claude/rules/open-questions-discipline.md" CLAUDE.md \
  || { echo "FAIL: CLAUDE.md missing @import for open-questions-discipline"; exit 1; }

# proj-plan-writer.md + proj-reflector.md have the force-read bullet (non-fatal if ANCHOR MISSING was reported in Step 8)
for agent in .claude/agents/proj-plan-writer.md .claude/agents/proj-reflector.md; do
  if [[ -f "$agent" ]]; then
    if grep -q "open-questions-discipline" "$agent"; then
      echo "OK: $agent force-read bullet present"
    else
      echo "WARN: $agent force-read bullet missing — if Step 9 reported ANCHOR MISSING, hand-patch needed; otherwise investigate"
    fi
  fi
done

echo "PASS: migration 042 verified"
```

Failure of any verify step → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after fixing.

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → "042"
- append `{ "id": "042", "applied_at": "{ISO8601}", "description": "Open questions discipline — new .claude/rules/open-questions-discipline.md with USER_DECIDES/AGENT_RECOMMENDS/AGENT_DECIDED disposition vocabulary; max-quality.md §6 clarified (No Hedging ≠ never ask); proj-researcher Output Template gains Open Questions section; /brainstorm Step 3.5 Triage added; /deep-think Phase 7 handoff includes open_questions field; agent-design.md technique documents open_questions alongside unresolved; CLAUDE.md @imports the new rule; proj-plan-writer + proj-reflector STEP 0 force-read the new rule (researcher STEP 0 refreshed via template fetch); /review Step 5.5 Open Questions Discipline check added" }` to `applied[]`

---

## Idempotency

Re-running after success: every step's sentinel passes, so every step emits `SKIP` and exits 0 without writing.

- Step 1 — `grep -q "open_questions" .claude/references/techniques/agent-design.md` → present → SKIP
- Step 2 — `grep -q "Open Questions" .claude/agents/proj-researcher.md` → present → SKIP
- Step 3 — `grep -q "3.5 Triage" .claude/skills/brainstorm/SKILL.md` → present → SKIP
- Step 4 — `grep -qE "open_questions|Open Questions" .claude/skills/deep-think/SKILL.md` → present → SKIP
- Step 5 — `grep -q "USER_DECIDES" .claude/rules/open-questions-discipline.md` → present → SKIP
- Step 6 — `grep -q "never ask" .claude/rules/max-quality.md` → present → SKIP
- Step 7 — `grep -q "5.5 Open Questions Discipline check" .claude/skills/review/SKILL.md` → present → SKIP
- Step 8 — `SENTINEL in content` check in the Python block → present → SKIP
- Step 9 — `grep -q "open-questions-discipline" "$agent"` → present → SKIP (or `ANCHOR MISSING` if the agent has been hand-edited; in either case the step exits 0)

No backups are created on re-runs (every fetch step writes to a tempfile that gets unlinked on SKIP; every Python patch step guards its write on the sentinel-absent path).

Running on a partially hand-edited project (e.g. some targets already contain the sentinel, others do not): each step independently evaluates its sentinel and either writes or SKIPs. The migration does not depend on all-or-nothing state.

---

## Rollback

```bash
set -euo pipefail

# Remove the new rule file (did not exist pre-migration)
rm -f .claude/rules/open-questions-discipline.md

# Restore previously-existing files from git (no per-migration .bak files are written)
git restore .claude/rules/max-quality.md 2>/dev/null || echo "WARN: no git tracking for .claude/rules/max-quality.md"
git restore .claude/references/techniques/agent-design.md 2>/dev/null || echo "WARN: no git tracking for .claude/references/techniques/agent-design.md"
git restore .claude/agents/proj-researcher.md 2>/dev/null || echo "WARN: no git tracking for .claude/agents/proj-researcher.md"
git restore .claude/agents/proj-plan-writer.md 2>/dev/null || echo "WARN: no git tracking for .claude/agents/proj-plan-writer.md"
git restore .claude/agents/proj-reflector.md 2>/dev/null || echo "WARN: no git tracking for .claude/agents/proj-reflector.md"
git restore .claude/skills/brainstorm/SKILL.md 2>/dev/null || echo "WARN: no git tracking for .claude/skills/brainstorm/SKILL.md"
git restore .claude/skills/review/SKILL.md 2>/dev/null || echo "WARN: no git tracking for .claude/skills/review/SKILL.md"
git restore .claude/skills/deep-think/SKILL.md 2>/dev/null || echo "WARN: no git tracking for .claude/skills/deep-think/SKILL.md"
git restore CLAUDE.md 2>/dev/null || {
  # If CLAUDE.md is not tracked (gitignored in many projects), strip the @import line by hand.
  python3 <<'PY'
PATH = "CLAUDE.md"
SENTINEL = "@import .claude/rules/open-questions-discipline.md"
with open(PATH, "r", encoding="utf-8") as f:
    lines = f.readlines()
with open(PATH, "w", encoding="utf-8") as f:
    for line in lines:
        if line.rstrip("\n") != SENTINEL:
            f.write(line)
print("STRIPPED: CLAUDE.md @import line removed (CLAUDE.md not git-tracked)")
PY
}
```

---

## Post-Apply — Bootstrap Repo Self-Update

This migration targets client projects. The bootstrap repo's own `.claude/` copies are
generated output, not source of truth. To update the bootstrap repo's installed copies:
1. Run `/migrate-bootstrap` against the bootstrap repo itself, OR re-run each step manually against the bootstrap repo's `.claude/` (the fetched content comes from `templates/`, which is already in the target state after Batches 1 and 2 of the open-questions-discipline plan merge).
2. Do NOT directly edit `.claude/rules/open-questions-discipline.md`, `.claude/rules/max-quality.md`, `.claude/agents/proj-researcher.md`, `.claude/agents/proj-plan-writer.md`, `.claude/skills/brainstorm/SKILL.md`, `.claude/skills/deep-think/SKILL.md`, `.claude/skills/review/SKILL.md`, or `.claude/references/techniques/agent-design.md` in the bootstrap repo — direct edits bypass the templates and create drift.

Reference: `.claude/rules/general.md` §Process — "NEVER write to this repo's `.claude/` as implementation work."
