# Migration: Fix Hook Base Paths

> Hook scripts using relative `bash .claude/scripts/json-val.sh` fail when cwd != project root. Fix all hooks to resolve paths via `dirname "$0"`.

---

```yaml
# --- Migration Metadata ---
id: "015"
name: "Fix Hook Base Paths"
description: >
  Hook scripts called json-val.sh via relative path, breaking when working
  directory differs from project root. Adds PROJECT_DIR/SCRIPT_DIR resolution
  using dirname "$0" and replaces all relative json-val.sh references.
base_commit: "647c50bdf7ca5dc0dde18c1e87154380f028c619"
date: "2026-04-01"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| modify | `.claude/hooks/guard-git.sh` | Replace relative json-val.sh path w/ SCRIPT_DIR |
| modify | `.claude/hooks/track-agent.sh` | Replace relative json-val.sh path w/ SCRIPT_DIR |
| modify | `.claude/hooks/observe.sh` | Replace relative json-val.sh path w/ SCRIPT_DIR |
| modify | `.claude/hooks/log-failures.sh` | Replace relative json-val.sh path w/ SCRIPT_DIR |
| modify | `.claude/hooks/auto-format.sh` | Replace relative json-val.sh path w/ SCRIPT_DIR |

---

## Actions

### Step 1 — Identify affected files

Grep all `.sh` files in `.claude/hooks/` for the literal string `bash .claude/scripts/json-val.sh`:

```bash
grep -rl 'bash \.claude/scripts/json-val\.sh' .claude/hooks/*.sh
```

If no files match, skip remaining steps — hooks already use the fixed pattern.

### Step 2 — Patch each affected file

For each file from Step 1, apply two changes:

**2a — Add path resolution block.** Insert these lines after `INPUT=$(cat)` (or after `set -euo pipefail` if no `INPUT` line):

```bash
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
SCRIPT_DIR="$PROJECT_DIR/.claude/scripts"
```

**2b — Replace relative calls.** In the same file, replace every occurrence of:

```bash
bash .claude/scripts/json-val.sh
```

with:

```bash
bash "$SCRIPT_DIR/json-val.sh"
```

Scripts that may need this fix (only if they exist and match the old pattern):
- `.claude/hooks/guard-git.sh`
- `.claude/hooks/track-agent.sh`
- `.claude/hooks/observe.sh`
- `.claude/hooks/log-failures.sh`
- `.claude/hooks/auto-format.sh`

Scripts that do NOT call json-val.sh (skip):
- `.claude/hooks/detect-env.sh`
- `.claude/hooks/stop-verify.sh`
- `.claude/hooks/sync-companion.sh`
- `.claude/hooks/pre-compact.sh`
- `.claude/hooks/session-summary.sh`

### Step 3 — Verify fix

Grep again for the old pattern:

```bash
grep -rn 'bash \.claude/scripts/json-val\.sh' .claude/hooks/*.sh
```

Must return zero matches (excluding comments). If any remain, repeat Step 2 for those files.

---

## Verify

- [ ] `grep -rl 'bash \.claude/scripts/json-val\.sh' .claude/hooks/*.sh` returns no matches
- [ ] All patched files contain `PROJECT_DIR=` and `SCRIPT_DIR=` lines
- [ ] All patched files use `bash "$SCRIPT_DIR/json-val.sh"` for json-val calls
- [ ] All patched scripts still parse: `bash -n .claude/hooks/{script}.sh` exits 0

---

Migration complete: `015` — Fix hook base paths to use dirname-resolved SCRIPT_DIR instead of relative paths
