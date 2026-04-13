---
name: commit
description: >
  Use when asked to commit, save changes, or after completing a task.
  Creates conventional commits with project message style.
allowed-tools: Read Bash Grep Glob
model: sonnet
effort: medium
# Skill Class: main-thread — inline git operations, no agent dispatch
---

## /commit — Project-Aware Commit

> Assumes /review and /verify already ran per CLAUDE.md automation. Do not embed verify/review here.

### Steps
1. `git status` — see changes
2. `git diff --staged` + `git diff` — understand changes
3. `git log --oneline -5` — match message style
4. Draft conventional commit: `type(scope): description`
   - Types: feat | fix | refactor | test | docs | chore | style
   - Subject < 72 chars
   - Body explains WHY not WHAT
5. Stage specific files (never `git add .`)
6. Create commit
7. If `git_strategy == "companion"` → export to companion repo

### Do NOT commit
- `.env` files, credentials, secrets
- Large binary files
- Unrelated changes (split into separate commits)

### Gotchas
- `git add .` can stage secrets — always stage specific files
- Pre-commit hooks may fail silently — check exit code
- Amending after hook failure modifies PREVIOUS commit — always create NEW commits
- Windows line endings may show as changed in diff — ignore CRLF-only diffs

### Anti-Hallucination
- Read `git diff` carefully — don't describe changes you haven't verified
- Never commit files you haven't reviewed
- Verify staged files match intent before committing
