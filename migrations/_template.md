# Migration: {migration-name}

> {One-line summary of what this migration does + why}

---

```yaml
# --- Migration Metadata ---
id: "{NNN}"                           # Zero-padded numeric ID; determines apply order
name: "{Human-Readable Name}"         # Short title shown in migration lists
description: >                        # What changed + motivation (1-3 lines)
  {Describe the change: what was added/removed/restructured and why}
base_commit: "{sha}"                  # Commit hash this migration targets (git log -1 --format=%H)
date: "YYYY-MM-DD"                    # Date migration was authored
breaking: false                       # true if existing bootstrapped projects need manual intervention
```

---

## Changes

<!-- List each file affected w/ action: add | modify | remove | rename -->

| Action | Path | Summary |
|--------|------|---------|
| {add\|modify\|remove\|rename} | `{path/to/file.md}` | {What changed} |
| {action} | `{path/to/other.md}` | {What changed} |

---

## Actions

<!-- Imperative steps Claude executes to apply migration.
     Each step: read target → apply change → verify.
     For large content, fetch from bootstrap repo rather than inlining. -->

### Step 1 — {action-title}

{Imperative instruction: "Read X", "Create Y", "Update Z"}

```
# For large file content, fetch from bootstrap repo:
# curl -sL "https://raw.githubusercontent.com/{owner}/{repo}/{commit}/path/to/file" -o "path/to/file"
# Or reference module for regeneration:
# Execute modules/{NN}-{name}.md Actions section against current project
```

### Step 2 — {action-title}

{Next imperative instruction}

### Step N — Wire + sync

<!-- Always end w/ wiring check -->

1. Verify cross-references: every path mentioned in changed files exists
2. Sync `claude-bootstrap.md` checklist if module list changed
3. Verify `settings.json` hooks reference correct script paths

---

## Verify

<!-- Post-migration checks; each must pass before marking complete -->

- [ ] All files in Changes table exist at specified paths
- [ ] No broken cross-references (grep for referenced paths, confirm they resolve)
- [ ] `claude-bootstrap.md` checklist matches actual module count
- [ ] `settings.json` parses as valid JSON
- [ ] {project-specific verification step}

---

Migration complete: `{id}` — {one-line summary}
