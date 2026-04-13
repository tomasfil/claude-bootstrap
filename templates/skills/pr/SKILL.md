---
name: pr
description: >
  Use when asked to create a pull request, submit changes for review,
  or after finishing a feature branch. Creates PR with summary + test plan.
allowed-tools: Read Bash Grep Glob
model: sonnet
effort: medium
# Skill Class: main-thread — inline git/gh operations, no agent dispatch
---

## /pr — Create Pull Request

### Steps
1. `git status` + `git log main..HEAD` — understand all changes
2. Draft PR: title < 70 chars; body = summary bullets + test plan + migration notes
3. Push if needed: `git push -u origin {branch}`
4. `gh pr create --title "..." --body "..."`
5. Return PR URL

### PR Body Template
```
## Summary
- {1-3 bullet points}

## Test Plan
- [ ] {verification steps}

## Notes
- {migration steps, breaking changes, or "none"}
```

### Anti-Hallucination
- Verify all commits in the PR actually exist (`git log`)
- Don't describe changes that aren't in the diff
- Verify the target branch exists
