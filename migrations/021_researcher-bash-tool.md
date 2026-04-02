# Migration: researcher-bash-tool

> Add Bash to researcher agent's tool allowlist so it can run `gh api` and other CLI commands during research

---

```yaml
# --- Migration Metadata ---
id: "021"
name: "Add Bash Tool to Researcher Agent"
description: >
  Researcher agent lacked Bash access, preventing it from running CLI tools
  like `gh api` for GitHub repo exploration. Adds Bash to tool allowlist.
base_commit: "b8e5836d35a4c5a1ae06a72b6ce0902df973fe7d"
date: "2026-04-02"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| modify | `.claude/agents/researcher.md` | Add `Bash` to tools list |

---

## Actions

### Step 1 — Update researcher agent tools

Read `.claude/agents/researcher.md`. In the YAML frontmatter, find the `tools:` line and add `Bash` if not already present.

Change:
```yaml
tools: Read, Grep, Glob, LSP, WebSearch
```

To:
```yaml
tools: Read, Grep, Glob, LSP, WebSearch, Bash
```

If the tools line already contains `Bash`, skip this step.

### Step 2 — Verify

1. Confirm `.claude/agents/researcher.md` frontmatter has `Bash` in tools list
2. No other files affected — no cross-reference or wiring changes needed

---

## Verify

- [ ] `.claude/agents/researcher.md` exists and has `Bash` in tools list
- [ ] YAML frontmatter parses correctly (no syntax errors)
- [ ] No duplicate tool entries

---

Migration complete: `021` — Add Bash to researcher agent tool allowlist
