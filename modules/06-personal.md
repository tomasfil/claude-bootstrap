# Step 8 — CLAUDE.local.md (Personal Preferences)

> Mode C: if CLAUDE.local.md exists, skip entirely.

Create `CLAUDE.local.md` in the project root for personal, non-shared preferences.

## Template

```markdown
# Personal Preferences (CLAUDE.local.md)

## Style Preferences
- {preferred_indentation}
- {naming_conventions}
- {comment_style}

## Workflow
- {preferred_test_runner_flags}
- {editor_integration_notes}
- {custom_aliases}
```

### What goes where

| File | Purpose | Shared? |
|------|---------|---------|
| `CLAUDE.md` | Project standards, team conventions, workflow | Yes (committed) |
| `CLAUDE.local.md` | Personal style, local env quirks | No (gitignored) |
| `.claude/rules/` | Enforceable rules (code standards, safety) | Yes (committed) |
| `.claude/settings.local.json` | Personal tool/permission settings | No (gitignored) |

## Gitignore Check

Ensure `.gitignore` includes:
```
CLAUDE.local.md
.claude/settings.local.json
```

If missing, append them.

**Checkpoint**: CLAUDE.local.md exists (or was skipped in Mode C). `.gitignore` updated.

---

# Step 9 — Scoped CLAUDE.md Files

Create subdirectory `CLAUDE.md` files ONLY where genuinely needed.

Good candidates: `tests/`, `src/`, `scripts/` — directories with distinct conventions.

- Keep each under 30 lines
- Skipping is valid — most projects need zero scoped files
- Only add if the subdirectory has rules that conflict with or extend the root CLAUDE.md

**Checkpoint**: Scoped CLAUDE.md files created where needed, or explicitly skipped.
