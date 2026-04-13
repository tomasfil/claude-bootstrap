---
name: verify
description: >
  Use before committing, creating PRs, or claiming work is done. Runs build,
  tests, cross-references, and consistency checks via proj-verifier.
context: fork
agent: proj-verifier
allowed-tools: Read Bash Grep Glob
model: sonnet
effort: medium
# Skill Class: forkable — bounded verification run, no user interaction
---

## /verify — Pre-Completion Verification

Run ALL checks — never claim completion until all pass.

### Phase 1: Build + Test verification
Dispatch agent via `subagent_type="proj-verifier"` w/:
- Build command: {build_command}
- Lint command: {lint_command}
- Test suite command: {test_suite_command}
- Write report to `.claude/reports/verification.md`
- Return path + summary

### Phase 2: Cross-reference + consistency (parallel w/ Phase 1)
Dispatch agent via `subagent_type="proj-consistency-checker"` w/:
- Scan: CLAUDE.md references, skill→agent dependencies, rule file integrity
- Write report to `.claude/reports/consistency.md`
- Return path + summary

### Phase 3: Migration check (bootstrap repo only)
If `modules/` files appear in `git diff` AND no `migrations/` file is new/modified:
- BLOCK verification — do not return PASS
- Ask: "Module templates changed but no migration was created. If this affects client projects, create one via `migrations/_template.md`. If docs-only, confirm to skip."
- Skip if project has no `migrations/` directory

### Phase 4: Merge results
Read both reports → unified assessment:
```
Build: {pass/fail}
Lint: {pass/fail/N/A}
Tests: {N passed, M failed}
Consistency: {pass/fail}
Cross-refs: {N checked, M broken}

Common issues scanned:
- [ ] No hardcoded secrets/credentials
- [ ] No console.log/print debug statements
- [ ] No commented-out code
- [ ] New files follow naming conventions

Verification: {PASS / FAIL}
Issues found: {list or "none"}
```

ANY check fails → fix before claiming done.
