# Migration: Agent Effort High

> Set effort: high on all agents — medium effort produces noticeably worse output

---

```yaml
# --- Migration Metadata ---
id: "023"
name: "Agent Effort High"
description: >
  All agent effort levels standardized to high. Medium effort produces lower
  quality output across all agent types. Applies to base agents and evolved
  sub-specialists (code-writer-*, test-writer-*).
base_commit: "80915be03736b27aedc3ca3a587b1033de7a5fff"
date: "2026-04-08"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| modify | `.claude/agents/*.md` | Set effort: high on all agents |

---

## Actions

### Step 1 — Update all agent effort levels to high

For every agent file (including evolved sub-specialists), replace any `effort: low` or `effort: medium` with `effort: high`:

```bash
for agent in .claude/agents/*.md; do
  if [[ -f "$agent" ]]; then
    sed -i 's/^effort: low$/effort: high/' "$agent"
    sed -i 's/^effort: medium$/effort: high/' "$agent"
  fi
done
```

### Step 2 — Verify

Confirm no agents remain with low or medium effort:

```bash
grep -l "^effort: \(low\|medium\)$" .claude/agents/*.md && echo "FAIL: agents still have non-high effort" || echo "PASS: all agents set to effort: high"
```

---

## Verify

- [ ] `grep -c "^effort: high$" .claude/agents/*.md` returns a count for every agent file
- [ ] `grep -l "^effort: \(low\|medium\)$" .claude/agents/*.md` returns no matches
- [ ] Evolved agents (code-writer-*, test-writer-*) included in the update

---

Migration complete: `023` — All agent effort levels set to high
