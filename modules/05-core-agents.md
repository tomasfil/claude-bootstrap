# Module 05 — Core Agents

> Install tracked agent templates from `templates/agents/` into `.claude/agents/` via `gh api` fetch loop.
> Sources of truth are `templates/manifest.json` (inventory + SHA) + the per-agent files. This module contains NO inline agent bodies — edit `templates/agents/{name}.md` directly to change an agent.
> Foundation agents (`proj-code-writer-markdown`, `proj-researcher`, `proj-code-writer-bash`) are already installed by Module 01; the fetch loop is idempotent and will re-sync them from `templates/` if their on-disk SHA drifts from the manifest.

---

## Idempotency

Per agent: compare on-disk `sha256` against `templates/manifest.json` entry. Match → skip. Mismatch or missing → fetch from `templates/agents/{source}` and overwrite. Never hand-edit `.claude/agents/*.md` in client projects — those files are generated output; edit `templates/agents/` in the bootstrap repo instead.

---

## Pre-Flight

1. Verify `gh` is authenticated (the fetch loop uses `gh api` against the public bootstrap repo):

```bash
gh auth status >/dev/null 2>&1 || {
  echo "ERROR: gh not authenticated. Run: gh auth login"
  exit 1
}
```

2. Create the agents directory:

```bash
mkdir -p .claude/agents
```

3. Verify foundation agents from Module 01 exist (these are required before any dispatch-based module runs — the fetch loop will still re-sync them from templates if present and out-of-date):

```bash
for agent in proj-code-writer-markdown proj-researcher proj-code-writer-bash; do
  [[ -f ".claude/agents/${agent}.md" ]] || echo "WARN: ${agent}.md missing — Module 01 should have created it; fetch loop will install from templates/"
done
```

---

## Actions

### Step 1 — Fetch Manifest

Resolve `{owner}` from `.claude/bootstrap-state.json` `github_username` (Module 01 persists this field after detecting the GitHub handle via `gh api user` or `git config user.name`, default `tomasfil`). The `BOOTSTRAP_OWNER` env var, if set, takes precedence.

```bash
set -euo pipefail

OWNER="${BOOTSTRAP_OWNER:-$(jq -r '.github_username // "tomasfil"' .claude/bootstrap-state.json 2>/dev/null || echo tomasfil)}"
REPO="claude-bootstrap"
BRANCH="main"

# Fetch manifest.json via gh api (local copy used when running inside the bootstrap repo itself)
if [[ -f templates/manifest.json ]]; then
  MANIFEST_JSON="$(cat templates/manifest.json)"
else
  MANIFEST_JSON="$(gh api "repos/${OWNER}/${REPO}/contents/templates/manifest.json?ref=${BRANCH}" --jq '.content' | base64 -d)"
fi

echo "$MANIFEST_JSON" | jq -e '.agents | length > 0' >/dev/null || {
  echo "ERROR: manifest.json has no agents entry"
  exit 1
}
```

### Step 2 — Fetch Loop (per agent)

Iterate the `agents` array. For each entry: compute on-disk sha256 (if the target exists), compare against manifest, skip or fetch accordingly. Every write uses `gh api ... | base64 -d > {target}` exactly — no WebFetch, no raw URL fallback unless `gh` is unavailable.

```bash
set -euo pipefail

# Process substitution (not jq | while) — keeps the loop in the current shell so `exit 1` propagates.
while IFS= read -r entry; do
  name=$(echo "$entry" | jq -r '.name')
  source=$(echo "$entry" | jq -r '.source')
  target=$(echo "$entry" | jq -r '.target')
  expected_sha=$(echo "$entry" | jq -r '.sha256')

  if [[ -f "$target" ]]; then
    actual_sha=$(sha256sum "$target" | awk '{print $1}')
    if [[ "$actual_sha" == "$expected_sha" ]]; then
      printf '  SKIP %-40s (sha match)\n' "$name"
      continue
    fi
    printf '  UPDATE %-38s (sha drift)\n' "$name"
  else
    printf '  FETCH %-39s (missing)\n' "$name"
  fi

  # Fetch from templates/agents/ via gh api; local copy used inside bootstrap repo
  if [[ -f "$source" ]]; then
    cp "$source" "$target"
  else
    gh api "repos/${OWNER}/${REPO}/contents/${source}?ref=${BRANCH}" --jq '.content' | base64 -d > "$target"
  fi

  # Post-write verification — fail loud if the written file does not match the manifest SHA
  written_sha=$(sha256sum "$target" | awk '{print $1}')
  if [[ "$written_sha" != "$expected_sha" ]]; then
    printf 'ERROR: %s sha mismatch after fetch — expected %s, got %s\n' "$target" "$expected_sha" "$written_sha" >&2
    exit 1
  fi
done < <(echo "$MANIFEST_JSON" | jq -c '.agents[]')
```

### Step 3 — Post-Fetch Verification

Confirm every agent listed in the manifest is now present on disk:

```bash
set -euo pipefail

while IFS= read -r target; do
  [[ -f "$target" ]] || { printf 'MISSING: %s\n' "$target" >&2; exit 1; }
done < <(echo "$MANIFEST_JSON" | jq -r '.agents[].target')
echo "All manifest agents present in .claude/agents/"
```

---

## Checkpoint

Count installed agents and emit the completion line:

```bash
N=$(echo "$MANIFEST_JSON" | jq '.agents | length')
echo "✅ Module 05 complete — ${N} core agents installed via template fetch"
```
