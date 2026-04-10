# Migration 008 — Fix misplaced technique files at project root

> Detect and relocate orphan technique files at `techniques/` (project root) into the canonical client-project location `.claude/references/techniques/`. Fixes damage from migrations 001/005/007 which wrote to the wrong path.

---

## Metadata

```yaml
id: "008"
breaking: false
affects: [techniques]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Migrations 001, 005, and 007 all included a "technique sync" step that fetched `techniques/agent-design.md` from the bootstrap repo and wrote it to `techniques/agent-design.md` at the CLIENT PROJECT ROOT. That path is wrong.

Per `modules/02-project-config.md` Step 5 ("Copy Technique References"), client projects store technique files at **`.claude/references/techniques/*.md`** — inside `.claude/`, not at the project root. The bootstrap REPO layout has `techniques/` at root, but client projects do not.

Effect on affected projects:
- An orphan `techniques/` directory exists at the client project root, containing `agent-design.md` (and possibly other files if a user manually copied them).
- The orphan file is stale relative to the copy that actually gets read (`.claude/references/techniques/agent-design.md`).
- Nothing reads the root `techniques/` path — skills, agents, and prompts all reference `.claude/references/techniques/`.
- If `.claude/` is gitignored, the good copy is also excluded from git, and the stale orphan may be the only tracked copy, causing confusion on clone.

Projects affected: any project that applied migration 001, 005, or 007 before this fix.

The source bugs in migrations 001/005/007 have been fixed in the bootstrap repo in the same changeset that ships this migration. Migration 008 cleans up the damage on already-affected client projects.

---

## Changes

1. **Detect orphan technique files** at `techniques/*.md` in the project root (NOT the bootstrap repo layout — migrations run inside client projects).
2. **Ensure `.claude/references/techniques/` exists** (mkdir -p).
3. **For each root technique file**: compare to the canonical copy at `.claude/references/techniques/{name}.md`:
   - If canonical copy is missing → move root file into canonical location.
   - If canonical copy exists and is identical → delete the root orphan.
   - If canonical copy exists and differs → the canonical copy is authoritative (it is what actually gets read); delete the root orphan and warn. The root file is an orphan by definition and cannot be authoritative.
4. **Remove empty `techniques/` directory** at project root if it becomes empty after the sweep. If it still contains non-`.md` files or subdirectories, leave it alone (may be unrelated user content).
5. **Advance `bootstrap-state.json`** → `last_migration: "008"`.

Idempotent: on re-run, no orphan files exist → all steps are no-ops.

---

## Actions

### Prerequisites

```bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }
```

### Step 1 — Detect and relocate orphan technique files

Walks `techniques/*.md` at the project root. Skips the directory entirely if it does not exist (clean project). For each file, decides move-vs-delete-vs-warn based on canonical copy state.

```bash
python3 <<'PY'
import os, sys, filecmp, shutil

ROOT_TECH = "techniques"
CANON_TECH = ".claude/references/techniques"

if not os.path.isdir(ROOT_TECH):
    print(f"SKIP: no {ROOT_TECH}/ directory at project root — nothing to fix")
    sys.exit(0)

os.makedirs(CANON_TECH, exist_ok=True)

orphans = sorted(
    f for f in os.listdir(ROOT_TECH)
    if f.endswith(".md") and os.path.isfile(os.path.join(ROOT_TECH, f))
)

if not orphans:
    print(f"SKIP: no .md files in {ROOT_TECH}/ — nothing to relocate")
else:
    print(f"Found {len(orphans)} orphan technique file(s) at {ROOT_TECH}/")

relocated = 0
deleted_duplicate = 0
deleted_stale = 0

for name in orphans:
    src = os.path.join(ROOT_TECH, name)
    dst = os.path.join(CANON_TECH, name)

    if not os.path.exists(dst):
        # Canonical missing → move orphan into place.
        shutil.move(src, dst)
        print(f"MOVED: {src} → {dst}")
        relocated += 1
        continue

    if filecmp.cmp(src, dst, shallow=False):
        # Identical content → just remove the orphan.
        os.remove(src)
        print(f"DELETED (duplicate): {src}")
        deleted_duplicate += 1
        continue

    # Canonical exists and differs. Canonical is authoritative because it is
    # what every skill/agent/prompt actually reads. The root orphan is
    # unreachable and therefore stale — remove it regardless of mtime.
    os.remove(src)
    print(f"DELETED (stale orphan, canonical differs): {src}")
    deleted_stale += 1

# Remove empty techniques/ directory if possible. Only remove if it contains
# no remaining entries at all — leave subdirs and non-md files alone (may be
# unrelated user content).
try:
    remaining = os.listdir(ROOT_TECH)
except FileNotFoundError:
    remaining = None

if remaining is not None and len(remaining) == 0:
    os.rmdir(ROOT_TECH)
    print(f"REMOVED empty directory: {ROOT_TECH}/")
elif remaining:
    print(f"KEPT: {ROOT_TECH}/ still contains {len(remaining)} non-technique entry(ies) — left in place")

print(f"SUMMARY: relocated={relocated} deleted_duplicate={deleted_duplicate} deleted_stale={deleted_stale}")
PY
```

### Step 2 — Re-sync canonical technique files from bootstrap repo

After relocation, ensure the canonical `.claude/references/techniques/` copies match the current bootstrap repo state. This guards against the case where the orphan was stale AND the canonical copy was also stale (never updated because migrations 001/005/007 wrote to the wrong place, so the canonical copy may pre-date those migrations).

Idempotent: fetches to a `.new` tempfile, compares to existing, only replaces on diff.

```bash
set -euo pipefail

TECH_DIR=".claude/references/techniques"
mkdir -p "$TECH_DIR"

BOOTSTRAP_REPO=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['bootstrap_repo'])" 2>/dev/null || echo "tomasfil/claude-bootstrap")

# Normalize bootstrap repo spec to raw base URL for curl fallback
RAW_BASE=$(python3 -c "
repo = '${BOOTSTRAP_REPO}'.rstrip('/')
if 'github.com' in repo:
    parts = repo.replace('https://github.com/', '')
    print(f'https://raw.githubusercontent.com/{parts}/main')
else:
    print(repo)
")

for name in INDEX prompt-engineering anti-hallucination agent-design token-efficiency; do
  dest="${TECH_DIR}/${name}.md"
  tmp="${dest}.new"

  if command -v gh >/dev/null 2>&1; then
    if ! gh api "repos/${BOOTSTRAP_REPO}/contents/techniques/${name}.md" --jq '.content' 2>/dev/null | base64 -d > "$tmp"; then
      rm -f "$tmp"
      echo "WARN: gh fetch of techniques/${name}.md failed — skipping"
      continue
    fi
  elif command -v curl >/dev/null 2>&1; then
    if ! curl -fsSL "${RAW_BASE}/techniques/${name}.md" -o "$tmp"; then
      rm -f "$tmp"
      echo "WARN: curl fetch of techniques/${name}.md failed — skipping"
      continue
    fi
  else
    echo "ERROR: neither gh nor curl available — cannot sync techniques"
    exit 1
  fi

  # Guard against fetch returning an empty or HTML error page
  if [[ ! -s "$tmp" ]]; then
    rm -f "$tmp"
    echo "WARN: fetched ${name}.md is empty — skipping"
    continue
  fi

  if [[ -f "$dest" ]] && cmp -s "$dest" "$tmp"; then
    rm "$tmp"
    echo "SKIP: ${dest} already up to date"
  else
    mv "$tmp" "$dest"
    echo "UPDATED: ${dest}"
  fi
done
```

### Step 3 — Update bootstrap-state.json

```bash
python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '008'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '008') or a == '008' for a in applied):
    applied.append({
        'id': '008',
        'applied_at': state['last_applied'],
        'description': 'fix misplaced technique files at project root — relocate to .claude/references/techniques/'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=008')
PY
```

### Rules for migration scripts

- **Read-before-write** — python3 reads each orphan file's content and compares to the canonical copy via `filecmp.cmp(..., shallow=False)` before deleting.
- **Idempotent** — running twice is a no-op: after first run, `techniques/` root directory is gone (or empty) so Step 1 short-circuits.
- **Canonical is authoritative** — if canonical and orphan differ, the canonical copy wins because it is the path every skill/agent/prompt actually reads. The orphan has been unreachable by construction.
- **Directory removal is conservative** — only remove `techniques/` if it is completely empty after the sweep. Non-.md files or subdirectories are user content; leave them.
- **Self-contained** — Step 2 fetches only tracked files from the bootstrap repo (`techniques/*.md`). No fetch from gitignored paths.
- **Abort on error** — `set -euo pipefail` in bash blocks; python3 blocks exit non-zero on failure.
- **No agent renames or skill rewrites** — this migration is scoped strictly to the path fix. Do not bundle unrelated cleanup.

### Required: register in migrations/index.json

Add an entry to the `migrations` array:

```json
{
  "id": "008",
  "file": "008-fix-techniques-path.md",
  "description": "Detect and relocate orphan technique files from techniques/ at project root into .claude/references/techniques/. Fixes damage from migrations 001/005/007 which wrote to the wrong path.",
  "breaking": false
}
```

---

## Verify

```bash
set +e
fail=0

# 1. No orphan technique files remain at project root
if [[ -d "techniques" ]]; then
  orphans=$(find techniques -maxdepth 1 -type f -name '*.md' 2>/dev/null)
  if [[ -z "$orphans" ]]; then
    echo "PASS: no orphan .md files in techniques/ at project root"
  else
    echo "FAIL: orphan .md files still present at techniques/:"
    echo "$orphans"
    fail=1
  fi
else
  echo "PASS: no techniques/ directory at project root"
fi

# 2. Canonical technique directory exists and contains agent-design.md
if [[ -f ".claude/references/techniques/agent-design.md" ]]; then
  echo "PASS: .claude/references/techniques/agent-design.md present"
else
  echo "FAIL: .claude/references/techniques/agent-design.md missing"
  fail=1
fi

# 3. State file updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "008" ]]; then
  echo "PASS: last_migration = 008"
else
  echo "FAIL: last_migration = $last (expected 008)"
  fail=1
fi

echo "---"
[[ $fail -eq 0 ]] && echo "Migration 008 verification: ALL PASS" || { echo "Migration 008 verification: FAILURES — state NOT updated"; exit 1; }
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix.

---

## State Update

On success:
- `last_migration` → "008"
- append `{ "id": "008", "applied_at": "<ISO8601>", "description": "fix misplaced technique files at project root — relocate to .claude/references/techniques/" }` to `applied[]`

---

## Rollback

Not automatically reversible. The migration deletes orphan files at `techniques/` that were never read by any tooling. If a user had manually added unique content to a root `techniques/*.md` file that differed from the canonical copy, that content is gone.

Recover from git: `git checkout -- techniques/` (if the project tracked the orphan file) or restore from backup.

Because the orphan was unreachable by design, data loss here is equivalent to deleting a file nothing read — but the caveat is stated explicitly.
