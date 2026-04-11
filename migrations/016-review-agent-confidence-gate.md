# Migration 016 — Review Agent Confidence Gate

<!-- migration-id: 016-review-agent-confidence-gate -->

> Retrofit existing client-project `proj-code-reviewer*` agents with a confidence-gated anti-hallucination block: evidence-citation bullet + Confidence routing + Say I don't know + Web search trigger subsections. Reduces false-positive findings where reviewer asserts external API / library behavior from training-data priors without evidence. Reviewer must either cite concrete evidence (project source, official docs, web-search URL) or abstain via a `Suppressed (cannot verify)` note in Report Format §7.

---

## Metadata

```yaml
id: "016"
breaking: false
affects: [agents]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Observed 2026-04-11: `proj-code-reviewer` emits false-positive findings when asserting external API / library behavior from training-data priors. Agent inherits WebSearch but never decides to use it before asserting — no trigger rule, no confidence gate, no evidence-citation requirement for external claims. Current escape hatch ("label CONSIDER") softens severity but still emits the finding; false positives survive review.

Fix: three layered additions to reviewer §8 Anti-Hallucination (Confidence routing + Say I don't know + Web search trigger) + evidence-citation bullet + optional `Suppressed (cannot verify)` section in Report Format §7. Reviewer either cites concrete evidence for external-API claims or abstains.

This migration retrofits existing client-project reviewers. New projects bootstrapped after this migration will generate the finalized form directly from the updated `modules/07-code-specialists.md` template.

---

## Changes

1. Globs `.claude/agents/proj-code-reviewer*.md` (covers sub-specialists, excludes `references/`). For each agent, replaces the existing `## 8. Anti-Hallucination` block (up to but not including `## 9.`) with the updated block: 5 existing bullets + new evidence-citation bullet + Confidence routing subsection + Say I don't know subsection + Web search trigger subsection. Preserves any project-specific lines that sit between the stock §8 bullets and `## 9.` by capturing them and re-appending after the new §8 content.
2. Advances `.claude/bootstrap-state.json` → `last_migration: "016"` + appends `"016"` to `applied[]`.

Idempotent: each agent file is guarded by a marker check (`### Confidence routing`) and skipped on re-run.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { printf "ERROR: not a bootstrapped project — run full bootstrap first\n"; exit 1; }
[[ -d ".claude/agents" ]] || { printf "ERROR: no .claude/agents directory\n"; exit 1; }

# Probe for python (python3 → python → py) — needed for agent patching + JSON manipulation.
PY=""
for cand in python3 python py; do
  if command -v "$cand" >/dev/null 2>&1; then
    PY="$cand"
    break
  fi
done
[[ -n "$PY" ]] || { printf "ERROR: no python interpreter found (need one of python3, python, py)\n"; exit 1; }
printf "OK: python found — %s\n" "$PY"

# Migration 015 must be applied — 016 builds atop the Completeness Check §9 added by 015.
"$PY" - <<'PY'
import json, sys
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
applied = state.get('applied', [])
has_015 = any(
    (isinstance(a, dict) and a.get('id') == '015') or a == '015'
    for a in applied
)
if not has_015:
    print("ERROR: migration 015 not applied — cannot apply 016")
    sys.exit(1)
print("OK: migration 015 present in applied[]")
PY
```

### Pre-flight — Detect re-apply vs fresh apply

```bash
#!/usr/bin/env bash
set -euo pipefail

shopt -s nullglob
reviewers=(.claude/agents/proj-code-reviewer*.md)
shopt -u nullglob

if [[ ${#reviewers[@]} -eq 0 ]]; then
  printf "INFO: no proj-code-reviewer*.md agents present — migration will be a no-op\n"
  MIGRATION_MODE="noop"
else
  already=0
  for f in "${reviewers[@]}"; do
    if grep -q "### Confidence routing" "$f"; then
      already=$((already + 1))
    fi
  done
  if [[ $already -eq ${#reviewers[@]} ]]; then
    printf "INFO: all %d reviewer agent(s) already patched — this is a RE-APPLY (no-op)\n" "${#reviewers[@]}"
    MIGRATION_MODE="reapply"
  else
    printf "INFO: %d of %d reviewer agent(s) unpatched — FRESH apply\n" $((${#reviewers[@]} - already)) "${#reviewers[@]}"
    MIGRATION_MODE="fresh"
  fi
fi
printf "MIGRATION_MODE=%s\n" "$MIGRATION_MODE"
```

---

### Step 1 — Retrofit `proj-code-reviewer*.md` agents: replace §8 Anti-Hallucination block

Globs `.claude/agents/proj-code-reviewer*.md` EXCLUDING any path containing `references/`. For each matching agent:

1. Idempotency guard: if the marker `### Confidence routing` is already present → `SKIP: already patched` and continue.
2. Locate `## 8. Anti-Hallucination` heading.
3. Locate `## 9.` (start of the next section — `## 9. Completeness Check` in stock module-07 output, but any `## 9.` heading works for flexibility).
4. Extract any project-specific lines that sit between the last stock §8 bullet and the `## 9.` heading (captured for re-append — preserves customizations).
5. Replace the entire old §8 block with the new §8 block (5 existing bullets + evidence-citation bullet + 3 subsections, verbatim from `modules/07-code-specialists.md` / the spec).
6. Re-append the captured project-specific lines AFTER the new §8 block, BEFORE `## 9.`.
7. Write the file back.

```bash
#!/usr/bin/env bash
set -euo pipefail

PY=""
for cand in python3 python py; do
  command -v "$cand" >/dev/null 2>&1 && { PY="$cand"; break; }
done
[[ -n "$PY" ]] || { printf "ERROR: no python interpreter\n"; exit 1; }

"$PY" - <<'PY'
import glob, os, re, sys

MARKER = "### Confidence routing"

# Canonical stock §8 body (5 bullets only) — used to detect where stock ends and
# project-specific additions begin. Whitespace-tolerant match.
STOCK_BULLETS = [
    "Only cite rules that EXIST in .claude/rules/ — read them first",
    "Only report line numbers for lines that EXIST — read file first",
    "Never invent security issues not actually present",
    "Use LSP to verify type issues before reporting",
    "If unsure about standard → check rules before citing",
]

# New §8 block — verbatim from modules/07-code-specialists.md + spec Approach section.
NEW_SECTION_8 = """## 8. Anti-Hallucination
- Only cite rules that EXIST in .claude/rules/ — read them first
- Only report line numbers for lines that EXIST — read file first
- Never invent security issues not actually present
- Use LSP to verify type issues before reporting
- If unsure about standard → check rules before citing
- Only assert external API / library behavior w/ cited evidence: {file}:{line} from project source, official docs URL, or explicit "cannot verify" note. No evidence → OMIT.

### Confidence routing (external API / library behavior claims):
- HIGH: verified in project source OR official docs → include finding as MUST-FIX | SHOULD
- MEDIUM: pattern recognized but not verified in THIS project's version → label CONSIDER, flag uncertainty
- LOW: inferred from training data only, no verification → OMIT finding; document "cannot verify: {what}"

### Say I don't know (explicit permission):
You are explicitly permitted and encouraged to say "cannot verify" when uncertain about
external API / library behavior. A CONSIDER finding w/ flagged uncertainty is better than
a false MUST-FIX. A suppressed finding w/ "cannot verify" note is better than a fabricated
assertion. Unexplained suppression of uncertainty = spec violation.

### Web search trigger:
Web search trigger — fire ONLY when ALL true:
1. Finding asserts external library / API / framework behavior (NOT project-local pattern)
2. Grep/Glob/Read of project source returned no confirming evidence
3. Confidence per Layer 1 routing is LOW
\u2192 Search w/ specific query: {library-name} {version-if-known} {exact-method-or-pattern}
\u2192 If search returns authoritative source (official docs, well-known repo): cite URL,
  re-evaluate confidence per Layer 1, downgrade to CONSIDER unless now HIGH
\u2192 If search returns nothing useful OR only low-quality results: OMIT finding,
  document "cannot verify via search: {query}"

Anti-patterns — reviewer MUST NOT:
- Search for project-local conventions (rules/techniques are authoritative, not web)
- Accept first search result without evaluating source quality (under-search failure mode)
- Search for every uncertain flag (over-search failure mode — trigger is LOW confidence only)
"""

# Regex: §8 header to (but not including) §9 header. DOTALL so . matches newlines.
SECTION_8_RE = re.compile(
    r"(?P<head>^##\s*8\.\s*Anti-Hallucination[^\n]*\n)(?P<body>.*?)(?=^##\s*9\.)",
    re.MULTILINE | re.DOTALL,
)

candidates = sorted(glob.glob(".claude/agents/proj-code-reviewer*.md"))
candidates = [p for p in candidates if "references/" not in os.path.normpath(p).replace("\\", "/")]

if not candidates:
    print("SKIP: no proj-code-reviewer*.md agents found")
    sys.exit(0)

for path in candidates:
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    if MARKER in content:
        print(f"SKIP: {path} already patched (marker '{MARKER}' present)")
        continue

    m = SECTION_8_RE.search(content)
    if not m:
        print(f"WARN: {path} — could not locate '## 8. Anti-Hallucination' ... '## 9.' block; leaving untouched")
        continue

    old_body = m.group("body")

    # Extract project-specific lines: anything in old_body that is NOT one of the stock bullets
    # and not a blank line immediately surrounding stock bullets. Strategy: split into lines,
    # drop lines whose stripped form matches "- {stock bullet text}", then trim leading/trailing
    # blank lines from what remains.
    project_lines = []
    for line in old_body.splitlines():
        stripped = line.strip()
        is_stock = False
        for bullet in STOCK_BULLETS:
            if stripped == f"- {bullet}":
                is_stock = True
                break
        if not is_stock:
            project_lines.append(line)

    # Trim leading/trailing blank lines from captured project-specific content.
    while project_lines and project_lines[0].strip() == "":
        project_lines.pop(0)
    while project_lines and project_lines[-1].strip() == "":
        project_lines.pop()

    project_specific = "\n".join(project_lines)

    # Assemble replacement: NEW_SECTION_8 (includes its own trailing newline) + optional
    # project_specific block + single blank line before ## 9.
    if project_specific:
        replacement = NEW_SECTION_8 + "\n" + project_specific + "\n\n"
    else:
        replacement = NEW_SECTION_8 + "\n"

    new_content = content[: m.start()] + replacement + content[m.end():]

    with open(path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print(f"PATCHED: {path} — §8 Anti-Hallucination block replaced (confidence routing + say-I-don't-know + web search trigger added)")
PY
```

---

### Step 2 — Self-test

Verifies each patched reviewer file contains the new markers. Counts `Confidence routing` occurrences (must be ≥ 1 per file) and `cannot verify` occurrences (must be ≥ 2 per file — appears in Layer 1 LOW row + Web search trigger anti-patterns).

```bash
#!/usr/bin/env bash
set -euo pipefail

fail=0
pass=0
checks=0

shopt -s nullglob
reviewers=(.claude/agents/proj-code-reviewer*.md)
shopt -u nullglob

# Exclude references/ paths (glob above does not recurse, but guard anyway).
filtered=()
for f in "${reviewers[@]}"; do
  case "$f" in
    */references/*) ;;
    *) filtered+=("$f") ;;
  esac
done

if [[ ${#filtered[@]} -eq 0 ]]; then
  printf "SKIP: no proj-code-reviewer*.md agents found — nothing to self-test\n"
else
  for f in "${filtered[@]}"; do
    checks=$((checks + 2))

    cr=$(grep -c "Confidence routing" "$f" || true)
    if [[ "$cr" -ge 1 ]]; then
      printf "PASS: %s has 'Confidence routing' (count=%s)\n" "$f" "$cr"
      pass=$((pass + 1))
    else
      printf "FAIL: %s missing 'Confidence routing'\n" "$f"
      fail=1
    fi

    cv=$(grep -c "cannot verify" "$f" || true)
    if [[ "$cv" -ge 2 ]]; then
      printf "PASS: %s has 'cannot verify' (count=%s, need >= 2)\n" "$f" "$cv"
      pass=$((pass + 1))
    else
      printf "FAIL: %s has only %s 'cannot verify' occurrence(s), need >= 2\n" "$f" "$cv"
      fail=1
    fi
  done
fi

printf -- "---\n"
printf "016-review-agent-confidence-gate self-test — %d/%d checks passed\n" "$pass" "$checks"

if [[ $fail -ne 0 ]]; then
  printf "ABORT: failures detected — bootstrap-state.json NOT advanced\n"
  exit 1
fi
```

---

### Step 3 — Bootstrap-state advance

Updates `.claude/bootstrap-state.json` → `last_migration: "016"` + appends `"016"` entry to `applied[]`. Idempotent — skips if `016` already present.

```bash
#!/usr/bin/env bash
set -euo pipefail

PY=""
for cand in python3 python py; do
  command -v "$cand" >/dev/null 2>&1 && { PY="$cand"; break; }
done
[[ -n "$PY" ]] || { printf "ERROR: no python interpreter\n"; exit 1; }

"$PY" - <<'PY'
import json, sys
from datetime import datetime, timezone

path = '.claude/bootstrap-state.json'
with open(path, 'r', encoding='utf-8') as f:
    state = json.load(f)

applied = state.get('applied', [])
already = any(
    (isinstance(a, dict) and a.get('id') == '016') or a == '016'
    for a in applied
)
if already:
    print("SKIP: 016 already in applied[]")
    sys.exit(0)

state['last_migration'] = '016'
applied.append({
    'id': '016',
    'applied_at': datetime.now(timezone.utc).isoformat(),
    'description': 'Review Agent Confidence Gate — retrofits proj-code-reviewer*.md agents with confidence-gated anti-hallucination block (evidence-citation bullet + Confidence routing + Say I don\'t know + Web search trigger subsections). Reduces false-positive findings where reviewer asserts external API / library behavior from training-data priors without evidence.'
})
state['applied'] = applied

with open(path, 'w', encoding='utf-8') as f:
    json.dump(state, f, indent=2)
    f.write('\n')

print("OK: bootstrap-state.json advanced to last_migration=016")
PY
```

---

## Verify

```bash
#!/usr/bin/env bash
set -euo pipefail

fail=0

shopt -s nullglob
reviewers=(.claude/agents/proj-code-reviewer*.md)
shopt -u nullglob

filtered=()
for f in "${reviewers[@]}"; do
  case "$f" in
    */references/*) ;;
    *) filtered+=("$f") ;;
  esac
done

if [[ ${#filtered[@]} -eq 0 ]]; then
  printf "SKIP: no proj-code-reviewer*.md agents found\n"
else
  for f in "${filtered[@]}"; do
    grep -q "### Confidence routing" "$f" \
      && printf "PASS: %s has Confidence routing subsection\n" "$f" \
      || { printf "FAIL: %s missing Confidence routing\n" "$f"; fail=1; }

    grep -q "### Say I don't know" "$f" \
      && printf "PASS: %s has Say I don't know subsection\n" "$f" \
      || { printf "FAIL: %s missing Say I don't know\n" "$f"; fail=1; }

    grep -q "### Web search trigger" "$f" \
      && printf "PASS: %s has Web search trigger subsection\n" "$f" \
      || { printf "FAIL: %s missing Web search trigger\n" "$f"; fail=1; }

    cv=$(grep -c "cannot verify" "$f" || true)
    [[ "$cv" -ge 2 ]] \
      && printf "PASS: %s has 'cannot verify' (count=%s)\n" "$f" "$cv" \
      || { printf "FAIL: %s has only %s 'cannot verify' occurrences, need >= 2\n" "$f" "$cv"; fail=1; }
  done
fi

# bootstrap-state advanced
PY=""
for cand in python3 python py; do
  command -v "$cand" >/dev/null 2>&1 && { PY="$cand"; break; }
done
if [[ -n "$PY" ]]; then
  "$PY" - <<'PY' || fail=1
import json, sys
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
if state.get('last_migration') != '016':
    print(f"FAIL: last_migration={state.get('last_migration')}, expected 016")
    sys.exit(1)
applied = state.get('applied', [])
has_016 = any(
    (isinstance(a, dict) and a.get('id') == '016') or a == '016'
    for a in applied
)
if not has_016:
    print("FAIL: 016 not in applied[]")
    sys.exit(1)
print("PASS: bootstrap-state.json reflects 016")
PY
fi

if [[ $fail -ne 0 ]]; then
  printf "FAIL: verify found issues\n"
  exit 1
fi
printf "PASS: migration 016 verified\n"
```

---

## Rollback

No automated rollback. Manual steps:

1. For each `.claude/agents/proj-code-reviewer*.md` patched by this migration, manually remove the `### Confidence routing`, `### Say I don't know`, `### Web search trigger` subsections + the new evidence-citation bullet, restoring the original 5-bullet §8 block.
2. Then manually reset `last_migration` in `.claude/bootstrap-state.json` to `"015"` and remove the `016` entry from `applied[]`.
